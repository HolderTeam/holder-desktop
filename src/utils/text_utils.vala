namespace HolderLinux {

public class TextUtils : Object {
    public static string ellipsize(string? value, int max_len) {
        if (value == null) {
            return "";
        }
        if (value.length <= max_len) {
            return value;
        }
        if (max_len <= 3) {
            return value.substring(0, max_len);
        }
        return value.substring(0, max_len - 3) + "...";
    }

    public static string title_from_content(string? text) {
        if (text == null) {
            return "Untitled";
        }
        var lines = text.split("\n");
        foreach (var raw_line in lines) {
            var line = raw_line.strip();
            if (line.length == 0) {
                continue;
            }
            if (line[0] == '#') {
                line = line.substring(1).strip();
            }
            return ellipsize(line, 80);
        }
        return "Untitled";
    }

    public static string format_relative_time(int64 now, int64 timestamp) {
        if (timestamp <= 0) {
            return "unknown";
        }

        var delta = now - timestamp;
        if (delta < 0) {
            return "just now";
        }
        if (delta < 60) {
            return "%llds ago".printf(delta);
        }
        if (delta < 3600) {
            return "%lldm ago".printf(delta / 60);
        }
        if (delta < 86400) {
            return "%lldh ago".printf(delta / 3600);
        }
        return "%lldd ago".printf(delta / 86400);
    }

    /**
     * Save-time cleanup of trailing whitespace, gated by three independent settings. Never
     * applied to the live editor buffer; see EditorSaveController.autosave_current_card and
     * EditorDraftState.has_unsaved_changes for why this must be applied consistently everywhere
     * the live buffer is compared against the last-saved text, not just at the literal save
     * call, or the "Unsaved" indicator gets stuck on permanently.
     *
     * Three independent decisions, most to least specific:
     *  1. [preserve] is the escape hatch: if true, the text is returned exactly as typed or
     *     pasted, and neither of the other two parameters has any effect.
     *  2. Otherwise every ordinary line has its meaningless trailing whitespace removed -- 0 or
     *     1 trailing spaces, any trailing tab, or a whitespace-only line collapses to nothing. A
     *     genuine hard-break run (2 or more literal spaces, no tab in the run) is instead
     *     canonicalized down to exactly 2, since CommonMark only ever distinguishes "two or
     *     more" from fewer -- unless [trim_two_space_hard_breaks] is true, in which case that
     *     run is stripped to 0 too, so the two-space hard-break convention can never survive a
     *     save.
     *  3. Lines inside a fenced code block (``` or ~~~, up to 3 leading spaces, matching
     *     CommonMark -- the same detection MarkdownResourceImageController.extract uses, though
     *     written independently here to avoid touching that already-working code) are exempt
     *     from both of the above by default, since trailing whitespace there may be literal
     *     pasted content (a diff, ASCII art) -- unless [trim_whitespace_in_code_blocks] opts
     *     back in, in which case every trailing space and tab on those lines, including the
     *     fence delimiter lines themselves, is stripped unconditionally; the hard-break
     *     distinction from rule 2 doesn't apply inside a code block, so there's nothing to
     *     canonicalize, just strip.
     */
    public static string trim_trailing_whitespace_for_save(
        string text,
        bool preserve,
        bool trim_two_space_hard_breaks,
        bool trim_whitespace_in_code_blocks
    ) {
        if (preserve) {
            return text;
        }

        var lines = text.split("\n");
        var out_lines = new string[lines.length];
        bool in_fence = false;
        char fence_character = '\0';
        int fence_length = 0;

        for (int index = 0; index < lines.length; index++) {
            var line = lines[index];
            char marker;
            int marker_length;
            bool closes_fence;
            if (fence_marker(line, in_fence, fence_character, fence_length,
                             out marker, out marker_length, out closes_fence)) {
                if (!in_fence) {
                    in_fence = true;
                    fence_character = marker;
                    fence_length = marker_length;
                } else if (closes_fence) {
                    in_fence = false;
                    fence_character = '\0';
                    fence_length = 0;
                }
                out_lines[index] = trim_code_line(line, trim_whitespace_in_code_blocks);
            } else if (in_fence) {
                out_lines[index] = trim_code_line(line, trim_whitespace_in_code_blocks);
            } else {
                out_lines[index] = trim_ordinary_line(line, trim_two_space_hard_breaks);
            }
        }
        return string.joinv("\n", out_lines);
    }

    private static string trim_ordinary_line(string line, bool trim_two_space_hard_breaks) {
        if (line.strip().length == 0) {
            return "";
        }
        var end = line.length;
        while (end > 0 && (line[end - 1] == ' ' || line[end - 1] == '\t')) {
            end--;
        }
        if (end == line.length) {
            return line;
        }
        var run = line.substring(end);
        var is_hard_break_run = run.length >= 2 && run.index_of_char('\t') < 0;
        string replacement;
        if (!is_hard_break_run) {
            replacement = "";
        } else if (trim_two_space_hard_breaks) {
            replacement = "";
        } else {
            replacement = "  ";
        }
        return line.substring(0, end) + replacement;
    }

    private static string trim_code_line(string line, bool trim_whitespace_in_code_blocks) {
        if (!trim_whitespace_in_code_blocks) {
            return line;
        }
        var end = line.length;
        while (end > 0 && (line[end - 1] == ' ' || line[end - 1] == '\t')) {
            end--;
        }
        return line.substring(0, end);
    }

    // Mirrors MarkdownResourceImageController's private fence_marker in
    // markdown_resource_images.vala byte-for-byte (up to 3 leading spaces, ``` or ~~~, 3+
    // repeats, a closing fence must match the opening character and be at least as long) --
    // duplicated rather than shared so this file has no dependency on that controller.
    private static bool fence_marker(string line,
                                     bool in_fence,
                                     char expected_character,
                                     int expected_length,
                                     out char marker,
                                     out int marker_length,
                                     out bool closes_fence) {
        marker = '\0';
        marker_length = 0;
        closes_fence = false;
        int position = 0;
        while (position < line.length && position < 3 && line[position] == ' ') {
            position++;
        }
        if (position >= line.length || (line[position] != '`' && line[position] != '~')) {
            return false;
        }
        marker = line[position];
        while (position < line.length && line[position] == marker) {
            marker_length++;
            position++;
        }
        if (marker_length < 3) {
            return false;
        }
        if (in_fence) {
            closes_fence = marker == expected_character && marker_length >= expected_length &&
                line.substring(position).strip().length == 0;
        }
        return true;
    }
}

}
