namespace HolderLinux {

internal enum MarkdownListAction {
    NONE,
    CONTINUE,
    END
}

internal class MarkdownListDecision : Object {
    public MarkdownListAction action { get; construct; }
    public string continuation { get; construct; }

    public MarkdownListDecision(MarkdownListAction action, string continuation = "") {
        Object(action: action, continuation: continuation);
    }
}

internal enum MarkdownLineCommand {
    INDENT,
    OUTDENT,
    CYCLE_HEADING,
    NUMBERED_LIST,
    BULLETED_LIST,
    TODO_LIST,
    BLOCKQUOTE,
    CLEAR_STRUCTURE
}

internal enum MarkdownInlineCommand {
    BOLD,
    ITALIC,
    STRIKETHROUGH,
    CODE,
    LINK,
    WIKILINK,
    CLEAR_FORMATTING
}

internal class MarkdownPrefixEdit : Object {
    public int remove_chars { get; construct; }
    public string insertion { get; construct; }

    public bool changed {
        get { return remove_chars > 0 || insertion.length > 0; }
    }

    public MarkdownPrefixEdit(int remove_chars = 0, string insertion = "") {
        Object(remove_chars: remove_chars, insertion: insertion);
    }
}

internal class MarkdownTextEdit : Object {
    public string replacement { get; construct; }
    public int selection_start { get; construct; }
    public int selection_end { get; construct; }
    public bool select_replacement { get; construct; }
    public bool changed { get; construct; }

    public MarkdownTextEdit(string replacement,
                            int selection_start,
                            int selection_end,
                            bool select_replacement,
                            bool changed = true) {
        Object(
            replacement: replacement,
            selection_start: selection_start,
            selection_end: selection_end,
            select_replacement: select_replacement,
            changed: changed
        );
    }

    public static MarkdownTextEdit unchanged(string text, bool selected) {
        var end = text.char_count();
        return new MarkdownTextEdit(text, selected ? 0 : end, end, selected, false);
    }
}

private enum MarkdownListKind {
    NONE,
    BULLET,
    ORDERED,
    TASK
}

private class MarkdownListLine : Object {
    public string indentation { get; construct; }
    public string content { get; construct; }
    public int prefix_chars { get; construct; }
    public MarkdownListKind kind { get; construct; }
    public string task_state { get; construct; }

    public MarkdownListLine(string indentation,
                            string content,
                            int prefix_chars,
                            MarkdownListKind kind,
                            string task_state = " ") {
        Object(
            indentation: indentation,
            content: content,
            prefix_chars: prefix_chars,
            kind: kind,
            task_state: task_state
        );
    }
}

internal class MarkdownEditingController : Object {
    public MarkdownListDecision decide_return(string line_prefix) {
        var task = match_line(
            line_prefix,
            "^([ \\t]*)([-+*])[ \\t]+\\[([ xX])\\][ \\t]*(.*)$"
        );
        if (task != null) {
            if (task.fetch(4).strip().length == 0) {
                return new MarkdownListDecision(MarkdownListAction.END);
            }
            return new MarkdownListDecision(
                MarkdownListAction.CONTINUE,
                "%s%s [ ] ".printf(task.fetch(1), task.fetch(2))
            );
        }

        var ordered = match_line(
            line_prefix,
            "^([ \\t]*)([0-9]+)([.)])[ \\t]+(.*)$"
        );
        if (ordered != null) {
            if (ordered.fetch(4).strip().length == 0) {
                return new MarkdownListDecision(MarkdownListAction.END);
            }
            var next_number = int64.parse(ordered.fetch(2)) + 1;
            return new MarkdownListDecision(
                MarkdownListAction.CONTINUE,
                "%s%s%s ".printf(
                    ordered.fetch(1),
                    next_number.to_string(),
                    ordered.fetch(3)
                )
            );
        }

        var bullet = match_line(
            line_prefix,
            "^([ \\t]*)([-+*])[ \\t]+(.*)$"
        );
        if (bullet != null) {
            if (bullet.fetch(3).strip().length == 0) {
                return new MarkdownListDecision(MarkdownListAction.END);
            }
            return new MarkdownListDecision(
                MarkdownListAction.CONTINUE,
                "%s%s ".printf(bullet.fetch(1), bullet.fetch(2))
            );
        }

        return new MarkdownListDecision(MarkdownListAction.NONE);
    }

    public MarkdownPrefixEdit[] decide_line_edits(string[] lines,
                                                   MarkdownLineCommand command) {
        var edits = new MarkdownPrefixEdit[lines.length];
        var remove_target = line_command_should_toggle_off(lines, command);
        var number = 1;
        for (var index = 0; index < lines.length; index++) {
            var line = lines[index];
            switch (command) {
                case MarkdownLineCommand.INDENT:
                    edits[index] = new MarkdownPrefixEdit(0, "    ");
                    break;
                case MarkdownLineCommand.OUTDENT:
                    edits[index] = decide_outdent(line);
                    break;
                case MarkdownLineCommand.CYCLE_HEADING:
                    edits[index] = decide_heading(line);
                    break;
                case MarkdownLineCommand.NUMBERED_LIST:
                    edits[index] = decide_list(
                        line,
                        MarkdownListKind.ORDERED,
                        remove_target,
                        "%d. ".printf(number)
                    );
                    if (line.strip().length > 0) {
                        number++;
                    }
                    break;
                case MarkdownLineCommand.BULLETED_LIST:
                    edits[index] = decide_list(
                        line,
                        MarkdownListKind.BULLET,
                        remove_target,
                        "- "
                    );
                    break;
                case MarkdownLineCommand.TODO_LIST:
                    var parsed = parse_list_line(line);
                    var state = parsed.kind == MarkdownListKind.TASK
                        ? parsed.task_state
                        : " ";
                    edits[index] = decide_list(
                        line,
                        MarkdownListKind.TASK,
                        remove_target,
                        "- [%s] ".printf(state)
                    );
                    break;
                case MarkdownLineCommand.BLOCKQUOTE:
                    edits[index] = decide_blockquote(line, remove_target);
                    break;
                case MarkdownLineCommand.CLEAR_STRUCTURE:
                    edits[index] = decide_clear_structure(line);
                    break;
            }
        }
        return edits;
    }

    public MarkdownTextEdit decide_inline_edit(string text,
                                                bool has_selection,
                                                MarkdownInlineCommand command) {
        switch (command) {
            case MarkdownInlineCommand.BOLD:
                return toggle_inline(text, has_selection, "**");
            case MarkdownInlineCommand.ITALIC:
                return toggle_inline(text, has_selection, "*");
            case MarkdownInlineCommand.STRIKETHROUGH:
                return toggle_inline(text, has_selection, "~~");
            case MarkdownInlineCommand.CODE:
                return toggle_code(text, has_selection);
            case MarkdownInlineCommand.LINK:
                return make_link(text, has_selection, false);
            case MarkdownInlineCommand.WIKILINK:
                return make_link(text, has_selection, true);
            case MarkdownInlineCommand.CLEAR_FORMATTING:
                return clear_inline_formatting(text, has_selection);
        }
        return MarkdownTextEdit.unchanged(text, has_selection);
    }

    private bool line_command_should_toggle_off(string[] lines,
                                                MarkdownLineCommand command) {
        MarkdownListKind wanted = MarkdownListKind.NONE;
        switch (command) {
            case MarkdownLineCommand.NUMBERED_LIST:
                wanted = MarkdownListKind.ORDERED;
                break;
            case MarkdownLineCommand.BULLETED_LIST:
                wanted = MarkdownListKind.BULLET;
                break;
            case MarkdownLineCommand.TODO_LIST:
                wanted = MarkdownListKind.TASK;
                break;
            case MarkdownLineCommand.BLOCKQUOTE:
                var saw_quote = false;
                foreach (var line in lines) {
                    if (line.strip().length == 0) {
                        continue;
                    }
                    saw_quote = true;
                    if (!line_is_blockquote(line)) {
                        return false;
                    }
                }
                return saw_quote;
            default:
                return false;
        }

        var saw_item = false;
        foreach (var line in lines) {
            if (line.strip().length == 0) {
                continue;
            }
            saw_item = true;
            if (parse_list_line(line).kind != wanted) {
                return false;
            }
        }
        return saw_item;
    }

    private MarkdownPrefixEdit decide_outdent(string line) {
        if (line.has_prefix("\t")) {
            return new MarkdownPrefixEdit(1, "");
        }
        var spaces = 0;
        while (spaces < 4 && spaces < line.length && line[spaces] == ' ') {
            spaces++;
        }
        return new MarkdownPrefixEdit(spaces, "");
    }

    private MarkdownPrefixEdit decide_heading(string line) {
        var heading = match_line(line, "^([ \\t]*)(#{1,6})(?:[ \\t]+(.*))?$");
        if (heading != null) {
            var indentation = heading.fetch(1);
            var marker = heading.fetch(2);
            var content = heading.fetch(3) ?? "";
            var prefix_chars = line.char_count() - content.char_count();
            var level = marker.length;
            var replacement = level >= 3 ? indentation : indentation + string.nfill(level + 1, '#') + " ";
            return new MarkdownPrefixEdit(prefix_chars, replacement);
        }

        var plain = parse_list_line(line);
        return new MarkdownPrefixEdit(
            plain.indentation.char_count(),
            plain.indentation + "# "
        );
    }

    private MarkdownPrefixEdit decide_list(string line,
                                           MarkdownListKind wanted,
                                           bool remove_target,
                                           string marker) {
        if (line.strip().length == 0) {
            return new MarkdownPrefixEdit();
        }
        var parsed = parse_list_line(line);
        if (remove_target && parsed.kind == wanted) {
            return new MarkdownPrefixEdit(parsed.prefix_chars, parsed.indentation);
        }
        return new MarkdownPrefixEdit(
            parsed.prefix_chars,
            parsed.indentation + marker
        );
    }

    private MarkdownPrefixEdit decide_blockquote(string line, bool remove_target) {
        MatchInfo? quote = match_line(line, "^([ \\t]*)(>[ \\t]?)(.*)$");
        if (quote != null) {
            var indentation = quote.fetch(1);
            var content = quote.fetch(3);
            var prefix_chars = line.char_count() - content.char_count();
            if (remove_target) {
                return new MarkdownPrefixEdit(prefix_chars, indentation);
            }
            return new MarkdownPrefixEdit(prefix_chars, indentation + "> > ");
        }

        var plain = parse_list_line(line);
        return new MarkdownPrefixEdit(
            plain.indentation.char_count(),
            plain.indentation + "> "
        );
    }

    private MarkdownPrefixEdit decide_clear_structure(string line) {
        var heading = match_line(line, "^([ \\t]*)(#{1,6})(?:[ \\t]+)(.*)$");
        if (heading != null) {
            var indentation = heading.fetch(1);
            var content = heading.fetch(3);
            return new MarkdownPrefixEdit(
                line.char_count() - content.char_count(),
                indentation
            );
        }

        var quote = match_line(line, "^([ \\t]*)(>[ \\t]?)(.*)$");
        if (quote != null) {
            var indentation = quote.fetch(1);
            var content = quote.fetch(3);
            return new MarkdownPrefixEdit(
                line.char_count() - content.char_count(),
                indentation
            );
        }

        var parsed = parse_list_line(line);
        if (parsed.kind != MarkdownListKind.NONE) {
            return new MarkdownPrefixEdit(parsed.prefix_chars, parsed.indentation);
        }
        return new MarkdownPrefixEdit();
    }

    private bool line_is_blockquote(string line) {
        return match_line(line, "^[ \\t]*>[ \\t]?.*$") != null;
    }

    private MarkdownListLine parse_list_line(string line) {
        var task = match_line(
            line,
            "^([ \\t]*)([-+*])[ \\t]+\\[([ xX])\\][ \\t]*(.*)$"
        );
        if (task != null) {
            var content = task.fetch(4);
            return new MarkdownListLine(
                task.fetch(1),
                content,
                line.char_count() - content.char_count(),
                MarkdownListKind.TASK,
                task.fetch(3)
            );
        }

        var ordered = match_line(
            line,
            "^([ \\t]*)([0-9]+)([.)])[ \\t]+(.*)$"
        );
        if (ordered != null) {
            var content = ordered.fetch(4);
            return new MarkdownListLine(
                ordered.fetch(1),
                content,
                line.char_count() - content.char_count(),
                MarkdownListKind.ORDERED
            );
        }

        var bullet = match_line(line, "^([ \\t]*)([-+*])[ \\t]+(.*)$");
        if (bullet != null) {
            var content = bullet.fetch(3);
            return new MarkdownListLine(
                bullet.fetch(1),
                content,
                line.char_count() - content.char_count(),
                MarkdownListKind.BULLET
            );
        }

        var plain = match_line(line, "^([ \\t]*)(.*)$");
        var indentation = plain != null ? plain.fetch(1) : "";
        var content = plain != null ? plain.fetch(2) : line;
        return new MarkdownListLine(
            indentation,
            content,
            indentation.char_count(),
            MarkdownListKind.NONE
        );
    }

    private MarkdownTextEdit toggle_inline(string text,
                                            bool has_selection,
                                            string marker) {
        var marker_chars = marker.char_count();
        if (!has_selection) {
            return new MarkdownTextEdit(
                marker + marker,
                marker_chars,
                marker_chars,
                false
            );
        }
        if (text.length >= marker.length * 2 &&
            text.has_prefix(marker) && text.has_suffix(marker)) {
            var inner = text.substring(
                marker.length,
                text.length - marker.length * 2
            );
            return new MarkdownTextEdit(inner, 0, inner.char_count(), true);
        }
        return new MarkdownTextEdit(
            marker + text + marker,
            marker_chars,
            marker_chars + text.char_count(),
            true
        );
    }

    private MarkdownTextEdit toggle_code(string text, bool has_selection) {
        if (!has_selection || text.index_of_char('\n') < 0) {
            return toggle_inline(text, has_selection, "`");
        }

        if (text.has_prefix("```\n") && text.has_suffix("\n```") && text.length >= 8) {
            var inner = text.substring(4, text.length - 8);
            return new MarkdownTextEdit(inner, 0, inner.char_count(), true);
        }

        var separator = text.has_suffix("\n") ? "" : "\n";
        var replacement = "```\n" + text + separator + "```";
        return new MarkdownTextEdit(
            replacement,
            4,
            4 + text.char_count(),
            true
        );
    }

    private MarkdownTextEdit make_link(string text,
                                       bool has_selection,
                                       bool wiki) {
        if (has_selection) {
            if ((wiki && text.has_prefix("[[") && text.has_suffix("]]")) ||
                (!wiki && markdown_link_is_complete(text))) {
                return MarkdownTextEdit.unchanged(text, true);
            }
            if (wiki) {
                return new MarkdownTextEdit(
                    "[[" + text + "]]",
                    2,
                    2 + text.char_count(),
                    true
                );
            }
            var replacement = "[" + text + "]()";
            var cursor = text.char_count() + 3;
            return new MarkdownTextEdit(replacement, cursor, cursor, false);
        }

        if (wiki) {
            return new MarkdownTextEdit("[[]]", 2, 2, false);
        }
        return new MarkdownTextEdit("[]()", 1, 1, false);
    }

    private bool markdown_link_is_complete(string text) {
        return match_line(text, "^\\[[^\\]]*\\]\\([^)]*\\)$") != null;
    }

    private MarkdownTextEdit clear_inline_formatting(string text,
                                                      bool has_selection) {
        if (!has_selection) {
            return MarkdownTextEdit.unchanged(text, false);
        }

        var link = match_line(text, "^\\[([^\\]]*)\\]\\([^)]*\\)$");
        if (link != null) {
            var label = link.fetch(1);
            return new MarkdownTextEdit(label, 0, label.char_count(), true);
        }
        if (text.has_prefix("[[") && text.has_suffix("]]")) {
            var inner = text.substring(2, text.length - 4);
            return new MarkdownTextEdit(inner, 0, inner.char_count(), true);
        }
        foreach (var marker in new string[] {"**", "~~", "`", "*"}) {
            if (text.length >= marker.length * 2 &&
                text.has_prefix(marker) && text.has_suffix(marker)) {
                var inner = text.substring(
                    marker.length,
                    text.length - marker.length * 2
                );
                return new MarkdownTextEdit(inner, 0, inner.char_count(), true);
            }
        }
        return MarkdownTextEdit.unchanged(text, true);
    }

    private MatchInfo? match_line(string text, string pattern) {
        try {
            var regex = new Regex(pattern);
            MatchInfo match_info;
            if (regex.match(text, 0, out match_info)) {
                return match_info;
            }
        } catch (RegexError e) {
            // A built-in expression failure should leave normal Return behavior intact.
        }
        return null;
    }
}

}
