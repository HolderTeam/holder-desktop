using GLib;

namespace HolderLinuxTests {

// ---- WorkspacePane.handle_markdown_key / handle_markdown_return as they were written inline ----

private string reference_key_action(uint keyval, Gdk.ModifierType state) {
    var relevant = state & (
        Gdk.ModifierType.CONTROL_MASK |
        Gdk.ModifierType.SHIFT_MASK |
        Gdk.ModifierType.ALT_MASK |
        Gdk.ModifierType.SUPER_MASK
    );
    var control = (relevant & Gdk.ModifierType.CONTROL_MASK) != 0;
    var shift = (relevant & Gdk.ModifierType.SHIFT_MASK) != 0;
    var forbidden = relevant & (
        Gdk.ModifierType.ALT_MASK |
        Gdk.ModifierType.SUPER_MASK
    );
    if (!control || forbidden != 0) {
        return "none";
    }

    if (!shift) {
        if (keyval == Gdk.Key.b || keyval == Gdk.Key.B) return "inline:BOLD";
        if (keyval == Gdk.Key.i || keyval == Gdk.Key.I) return "inline:ITALIC";
        if (keyval == Gdk.Key.k || keyval == Gdk.Key.K) return "inline:LINK";
        if (keyval == Gdk.Key.l || keyval == Gdk.Key.L) return "inline:WIKILINK";
        if (keyval == Gdk.Key.bracketleft) return "line:OUTDENT";
        if (keyval == Gdk.Key.bracketright) return "line:INDENT";
        if (keyval == Gdk.Key.slash) return "line:CYCLE_HEADING";
        if (keyval == Gdk.Key.backslash) return "clear";
        return "none";
    }

    if (keyval == Gdk.Key.x || keyval == Gdk.Key.X) return "inline:STRIKETHROUGH";
    if (keyval == Gdk.Key.c || keyval == Gdk.Key.C) return "inline:CODE";
    if (keyval == Gdk.Key.ampersand || keyval == (uint) '7') return "line:NUMBERED_LIST";
    if (keyval == Gdk.Key.asterisk || keyval == (uint) '8') return "line:BULLETED_LIST";
    if (keyval == Gdk.Key.parenleft || keyval == (uint) '9') return "line:TODO_LIST";
    if (keyval == Gdk.Key.greater || keyval == Gdk.Key.period) return "line:BLOCKQUOTE";
    return "none";
}

private bool reference_is_plain_return(uint keyval, Gdk.ModifierType state) {
    if (keyval != Gdk.Key.Return && keyval != Gdk.Key.KP_Enter) {
        return false;
    }
    var disallowed_modifiers = Gdk.ModifierType.SHIFT_MASK |
        Gdk.ModifierType.CONTROL_MASK |
        Gdk.ModifierType.ALT_MASK |
        Gdk.ModifierType.SUPER_MASK;
    return (state & disallowed_modifiers) == 0;
}

private string inline_name(HolderLinux.MarkdownInlineCommand command) {
    switch (command) {
        case HolderLinux.MarkdownInlineCommand.BOLD: return "BOLD";
        case HolderLinux.MarkdownInlineCommand.ITALIC: return "ITALIC";
        case HolderLinux.MarkdownInlineCommand.STRIKETHROUGH: return "STRIKETHROUGH";
        case HolderLinux.MarkdownInlineCommand.CODE: return "CODE";
        case HolderLinux.MarkdownInlineCommand.LINK: return "LINK";
        case HolderLinux.MarkdownInlineCommand.WIKILINK: return "WIKILINK";
        default: return "CLEAR_FORMATTING";
    }
}

private string line_name(HolderLinux.MarkdownLineCommand command) {
    switch (command) {
        case HolderLinux.MarkdownLineCommand.INDENT: return "INDENT";
        case HolderLinux.MarkdownLineCommand.OUTDENT: return "OUTDENT";
        case HolderLinux.MarkdownLineCommand.CYCLE_HEADING: return "CYCLE_HEADING";
        case HolderLinux.MarkdownLineCommand.NUMBERED_LIST: return "NUMBERED_LIST";
        case HolderLinux.MarkdownLineCommand.BULLETED_LIST: return "BULLETED_LIST";
        case HolderLinux.MarkdownLineCommand.TODO_LIST: return "TODO_LIST";
        case HolderLinux.MarkdownLineCommand.BLOCKQUOTE: return "BLOCKQUOTE";
        default: return "CLEAR_STRUCTURE";
    }
}

private string describe_action(HolderLinux.MarkdownKeyAction action) {
    switch (action.kind) {
        case HolderLinux.MarkdownKeyActionKind.INLINE:
            return "inline:" + inline_name(action.inline_command);
        case HolderLinux.MarkdownKeyActionKind.LINE:
            return "line:" + line_name(action.line_command);
        case HolderLinux.MarkdownKeyActionKind.CLEAR_FORMATTING:
            return "clear";
        default:
            return "none";
    }
}

private Gdk.ModifierType[] all_relevant_modifier_combinations() {
    Gdk.ModifierType[] combos = {};
    for (int bits = 0; bits < 16; bits++) {
        var state = (Gdk.ModifierType) 0;
        if ((bits & 1) != 0) state |= Gdk.ModifierType.SHIFT_MASK;
        if ((bits & 2) != 0) state |= Gdk.ModifierType.CONTROL_MASK;
        if ((bits & 4) != 0) state |= Gdk.ModifierType.ALT_MASK;
        if ((bits & 8) != 0) state |= Gdk.ModifierType.SUPER_MASK;
        combos += state;
    }
    return combos;
}

private uint[] keyvals_to_probe() {
    uint[] keyvals = { Gdk.Key.Return, Gdk.Key.KP_Enter, Gdk.Key.Tab, Gdk.Key.Escape, 0xffff, 0x100, 0xfe03 };
    for (uint ascii = 0; ascii < 0x80; ascii++) {
        keyvals += ascii;
    }
    return keyvals;
}

private void test_key_constants_match_gdk() {
    assert(HolderLinux.MarkdownKeyMap.KEY_RETURN == Gdk.Key.Return);
    assert(HolderLinux.MarkdownKeyMap.KEY_KP_ENTER == Gdk.Key.KP_Enter);
    assert(HolderLinux.MarkdownKeyMap.KEY_LOWER_B == Gdk.Key.b);
    assert(HolderLinux.MarkdownKeyMap.KEY_UPPER_B == Gdk.Key.B);
    assert(HolderLinux.MarkdownKeyMap.KEY_LOWER_I == Gdk.Key.i);
    assert(HolderLinux.MarkdownKeyMap.KEY_UPPER_I == Gdk.Key.I);
    assert(HolderLinux.MarkdownKeyMap.KEY_LOWER_K == Gdk.Key.k);
    assert(HolderLinux.MarkdownKeyMap.KEY_UPPER_K == Gdk.Key.K);
    assert(HolderLinux.MarkdownKeyMap.KEY_LOWER_L == Gdk.Key.l);
    assert(HolderLinux.MarkdownKeyMap.KEY_UPPER_L == Gdk.Key.L);
    assert(HolderLinux.MarkdownKeyMap.KEY_LOWER_X == Gdk.Key.x);
    assert(HolderLinux.MarkdownKeyMap.KEY_UPPER_X == Gdk.Key.X);
    assert(HolderLinux.MarkdownKeyMap.KEY_LOWER_C == Gdk.Key.c);
    assert(HolderLinux.MarkdownKeyMap.KEY_UPPER_C == Gdk.Key.C);
    assert(HolderLinux.MarkdownKeyMap.KEY_BRACKET_LEFT == Gdk.Key.bracketleft);
    assert(HolderLinux.MarkdownKeyMap.KEY_BRACKET_RIGHT == Gdk.Key.bracketright);
    assert(HolderLinux.MarkdownKeyMap.KEY_SLASH == Gdk.Key.slash);
    assert(HolderLinux.MarkdownKeyMap.KEY_BACKSLASH == Gdk.Key.backslash);
    assert(HolderLinux.MarkdownKeyMap.KEY_AMPERSAND == Gdk.Key.ampersand);
    assert(HolderLinux.MarkdownKeyMap.KEY_ASTERISK == Gdk.Key.asterisk);
    assert(HolderLinux.MarkdownKeyMap.KEY_PAREN_LEFT == Gdk.Key.parenleft);
    assert(HolderLinux.MarkdownKeyMap.KEY_GREATER == Gdk.Key.greater);
    assert(HolderLinux.MarkdownKeyMap.KEY_PERIOD == Gdk.Key.period);
    assert(HolderLinux.MarkdownKeyMap.KEY_7 == (uint) '7');
    assert(HolderLinux.MarkdownKeyMap.KEY_8 == (uint) '8');
    assert(HolderLinux.MarkdownKeyMap.KEY_9 == (uint) '9');
}

private void test_modifier_bits_match_gdk() {
    assert((int) HolderLinux.MarkdownKeyModifiers.SHIFT == (int) Gdk.ModifierType.SHIFT_MASK);
    assert((int) HolderLinux.MarkdownKeyModifiers.CONTROL == (int) Gdk.ModifierType.CONTROL_MASK);
    assert((int) HolderLinux.MarkdownKeyModifiers.ALT == (int) Gdk.ModifierType.ALT_MASK);
    assert((int) HolderLinux.MarkdownKeyModifiers.SUPER == (int) Gdk.ModifierType.SUPER_MASK);
}

private void test_key_table_matches_the_original_for_every_key_and_modifier() {
    int shortcuts = 0;
    foreach (var state in all_relevant_modifier_combinations()) {
        var modifiers = (HolderLinux.MarkdownKeyModifiers) (int) state;
        foreach (var keyval in keyvals_to_probe()) {
            var expected = reference_key_action(keyval, state);
            var actual = describe_action(HolderLinux.MarkdownKeyMap.resolve(keyval, modifiers));
            if (actual != expected) {
                error("keyval 0x%x state 0x%x: expected %s but got %s",
                      keyval, (uint) state, expected, actual);
            }
            if (expected != "none") {
                shortcuts++;
            }
        }
    }
    // Ctrl alone maps 12 keys (b/B i/I k/K l/L, plus [ ] / \); Ctrl+Shift maps 12
    // (x/X c/C, & 7, * 8, ( 9, > .).
    assert(shortcuts == 12 + 12);
}

private void test_plain_return_matches_the_original() {
    foreach (var state in all_relevant_modifier_combinations()) {
        var modifiers = (HolderLinux.MarkdownKeyModifiers) (int) state;
        foreach (var keyval in keyvals_to_probe()) {
            assert(HolderLinux.MarkdownKeyMap.is_plain_return(keyval, modifiers)
                   == reference_is_plain_return(keyval, state));
        }
    }
    assert(HolderLinux.MarkdownKeyMap.is_plain_return(
        HolderLinux.MarkdownKeyMap.KEY_RETURN, (HolderLinux.MarkdownKeyModifiers) 0));
    assert(HolderLinux.MarkdownKeyMap.is_plain_return(
        HolderLinux.MarkdownKeyMap.KEY_KP_ENTER, (HolderLinux.MarkdownKeyModifiers) 0));
}

private void test_key_action_factories() {
    assert(HolderLinux.MarkdownKeyAction.none().kind == HolderLinux.MarkdownKeyActionKind.NONE);
    assert(HolderLinux.MarkdownKeyAction.clear_formatting().kind
           == HolderLinux.MarkdownKeyActionKind.CLEAR_FORMATTING);
    var inline = HolderLinux.MarkdownKeyAction.inline(HolderLinux.MarkdownInlineCommand.CODE);
    assert(inline.kind == HolderLinux.MarkdownKeyActionKind.INLINE);
    assert(inline.inline_command == HolderLinux.MarkdownInlineCommand.CODE);
    var line = HolderLinux.MarkdownKeyAction.line(HolderLinux.MarkdownLineCommand.BLOCKQUOTE);
    assert(line.kind == HolderLinux.MarkdownKeyActionKind.LINE);
    assert(line.line_command == HolderLinux.MarkdownLineCommand.BLOCKQUOTE);
}

// ---- shortcuts resolved by the key map drive the real editing controller ----

private string apply_shortcut_to_selection(uint keyval, bool shift, string selected) {
    var modifiers = HolderLinux.MarkdownKeyModifiers.CONTROL;
    if (shift) {
        modifiers |= HolderLinux.MarkdownKeyModifiers.SHIFT;
    }
    var action = HolderLinux.MarkdownKeyMap.resolve(keyval, modifiers);
    assert(action.kind == HolderLinux.MarkdownKeyActionKind.INLINE);
    return new HolderLinux.MarkdownEditingController()
        .decide_inline_edit(selected, true, action.inline_command).replacement;
}

private void test_shortcuts_drive_the_editing_controller() {
    assert(apply_shortcut_to_selection(HolderLinux.MarkdownKeyMap.KEY_LOWER_B, false, "word") == "**word**");
    assert(apply_shortcut_to_selection(HolderLinux.MarkdownKeyMap.KEY_UPPER_I, false, "word") == "*word*");
    assert(apply_shortcut_to_selection(HolderLinux.MarkdownKeyMap.KEY_LOWER_X, true, "word") == "~~word~~");
    assert(apply_shortcut_to_selection(HolderLinux.MarkdownKeyMap.KEY_LOWER_C, true, "word") == "`word`");

    var controller = new HolderLinux.MarkdownEditingController();

    var indent = HolderLinux.MarkdownKeyMap.resolve(
        HolderLinux.MarkdownKeyMap.KEY_BRACKET_RIGHT, HolderLinux.MarkdownKeyModifiers.CONTROL);
    assert(indent.kind == HolderLinux.MarkdownKeyActionKind.LINE);
    var indent_edits = controller.decide_line_edits({ "item" }, indent.line_command);
    assert(indent_edits.length == 1 && indent_edits[0].insertion == "    ");

    var bullets = HolderLinux.MarkdownKeyMap.resolve(
        HolderLinux.MarkdownKeyMap.KEY_ASTERISK,
        HolderLinux.MarkdownKeyModifiers.CONTROL | HolderLinux.MarkdownKeyModifiers.SHIFT);
    assert(bullets.line_command == HolderLinux.MarkdownLineCommand.BULLETED_LIST);
    assert(controller.decide_line_edits({ "item" }, bullets.line_command)[0].changed);

    // Toggling a quote off leaves blank lines inside it alone.
    var quote = HolderLinux.MarkdownKeyMap.resolve(
        HolderLinux.MarkdownKeyMap.KEY_GREATER,
        HolderLinux.MarkdownKeyModifiers.CONTROL | HolderLinux.MarkdownKeyModifiers.SHIFT);
    var quote_edits = controller.decide_line_edits({ "> a", "", "> b" }, quote.line_command);
    assert(quote_edits.length == 3);
    assert(quote_edits[0].remove_chars == 2);
    assert(!quote_edits[1].changed);
    assert(quote_edits[2].remove_chars == 2);

    // Plain Enter continues a list.
    assert(HolderLinux.MarkdownKeyMap.is_plain_return(
        HolderLinux.MarkdownKeyMap.KEY_RETURN, (HolderLinux.MarkdownKeyModifiers) 0));
    assert(controller.decide_return("- item").action == HolderLinux.MarkdownListAction.CONTINUE);
}

// ---- MarkdownSelectionRules ----

private void test_inline_marker_for_each_command() {
    assert(HolderLinux.MarkdownSelectionRules.inline_marker_for(HolderLinux.MarkdownInlineCommand.BOLD) == "**");
    assert(HolderLinux.MarkdownSelectionRules.inline_marker_for(HolderLinux.MarkdownInlineCommand.ITALIC) == "*");
    assert(HolderLinux.MarkdownSelectionRules.inline_marker_for(HolderLinux.MarkdownInlineCommand.STRIKETHROUGH) == "~~");
    assert(HolderLinux.MarkdownSelectionRules.inline_marker_for(HolderLinux.MarkdownInlineCommand.CODE) == "`");
    assert(HolderLinux.MarkdownSelectionRules.inline_marker_for(HolderLinux.MarkdownInlineCommand.LINK) == null);
    assert(HolderLinux.MarkdownSelectionRules.inline_marker_for(HolderLinux.MarkdownInlineCommand.WIKILINK) == null);
    assert(HolderLinux.MarkdownSelectionRules.inline_marker_for(HolderLinux.MarkdownInlineCommand.CLEAR_FORMATTING) == null);
}

private void test_last_line_index_matches_the_original_expression() {
    for (int first = 0; first < 4; first++) {
        for (int last = 0; last < 6; last++) {
            foreach (var has_selection in new bool[] { false, true }) {
                for (int offset = 0; offset < 3; offset++) {
                    var expected = last;
                    if (has_selection && offset == 0 && last > first) {
                        expected--;
                    }
                    assert(HolderLinux.MarkdownSelectionRules.last_line_index(first, last, has_selection, offset)
                           == expected);
                }
            }
        }
    }
}

private void test_should_expand_to_marker_rules() {
    assert(HolderLinux.MarkdownSelectionRules.should_expand_to_marker("**", "**", "**"));
    assert(HolderLinux.MarkdownSelectionRules.should_expand_to_marker("~~", "~~", "~~"));
    assert(HolderLinux.MarkdownSelectionRules.should_expand_to_marker("`", "x`", "`y"));
    assert(!HolderLinux.MarkdownSelectionRules.should_expand_to_marker("**", "*", "**"));
    assert(!HolderLinux.MarkdownSelectionRules.should_expand_to_marker("**", "**", "*"));
    assert(!HolderLinux.MarkdownSelectionRules.should_expand_to_marker("**", "", ""));

    assert(HolderLinux.MarkdownSelectionRules.should_expand_to_marker("*", "*", "*"));
    assert(HolderLinux.MarkdownSelectionRules.should_expand_to_marker("*", "x*", "*y"));
    // A single '*' next to a bold marker is part of the bold wrapper, not an italic wrapper.
    assert(!HolderLinux.MarkdownSelectionRules.should_expand_to_marker("*", "**", "*"));
    assert(!HolderLinux.MarkdownSelectionRules.should_expand_to_marker("*", "*", "**"));
    assert(!HolderLinux.MarkdownSelectionRules.should_expand_to_marker("*", "**", "**"));
}

// ---- expand_selection_to_surrounding_marker against a real Gtk.TextBuffer ----

// The algorithm exactly as it was written inline in WorkspacePane before the decision moved
// into MarkdownSelectionRules.
private bool original_expand(Gtk.TextBuffer buffer, ref Gtk.TextIter start, ref Gtk.TextIter end, string marker) {
    var marker_chars = marker.char_count();
    Gtk.TextIter before = start;
    Gtk.TextIter after = end;
    if (!before.backward_chars(marker_chars) || !after.forward_chars(marker_chars)) {
        return false;
    }
    if (buffer.get_text(before, start, false) != marker ||
        buffer.get_text(end, after, false) != marker) {
        return false;
    }
    if (marker == "*") {
        Gtk.TextIter two_before = start;
        Gtk.TextIter two_after = end;
        if ((two_before.backward_chars(2) &&
             buffer.get_text(two_before, start, false) == "**") ||
            (two_after.forward_chars(2) &&
             buffer.get_text(end, two_after, false) == "**")) {
            return false;
        }
    }
    start = before;
    end = after;
    return true;
}

// The view's current glue around MarkdownSelectionRules.should_expand_to_marker.
private bool new_expand(Gtk.TextBuffer buffer, ref Gtk.TextIter start, ref Gtk.TextIter end, string marker) {
    var marker_chars = marker.char_count();
    Gtk.TextIter before = start;
    Gtk.TextIter after = end;
    before.backward_chars(2);
    after.forward_chars(2);
    if (!HolderLinux.MarkdownSelectionRules.should_expand_to_marker(
            marker,
            buffer.get_text(before, start, false),
            buffer.get_text(end, after, false))) {
        return false;
    }
    before = start;
    after = end;
    before.backward_chars(marker_chars);
    after.forward_chars(marker_chars);
    start = before;
    end = after;
    return true;
}

private string[] expand_sample_texts() {
    return {
        "", "a", "**a**", "**a**\n", "*a*", "*a*x", "x*a*", "***a***", "*a**", "**a*", "~~a~~",
        "`a`", "`a`\n", "a`b`c", "**a** **b**", "é**ü**", "*é*", "\n**a**", "**", "*", "****"
    };
}

private void test_expansion_matches_the_original_except_when_a_marker_ends_the_document() {
    string[] markers = { "**", "*", "~~", "`" };
    int compared = 0;
    int quirk_cases = 0;
    foreach (var text in expand_sample_texts()) {
        var length = text.char_count();
        foreach (var marker in markers) {
            var marker_chars = marker.char_count();
            for (int s = 0; s <= length; s++) {
                for (int e = s; e <= length; e++) {
                    var buffer = new Gtk.TextBuffer(null);
                    buffer.set_text(text, -1);
                    Gtk.TextIter original_start, original_end, new_start, new_end;
                    buffer.get_iter_at_offset(out original_start, s);
                    buffer.get_iter_at_offset(out original_end, e);
                    buffer.get_iter_at_offset(out new_start, s);
                    buffer.get_iter_at_offset(out new_end, e);

                    var original_expanded = original_expand(buffer, ref original_start, ref original_end, marker);
                    var new_expanded = new_expand(buffer, ref new_start, ref new_end, marker);

                    // Gtk.TextIter.forward_chars() reports failure when it lands exactly on the end
                    // of the buffer, so the original gave up whenever the closing marker was the
                    // very last text in the document (or, for '*', a '**' check reached it).
                    var reaches_end = e + marker_chars == length || (marker == "*" && e + 2 == length);
                    if (original_expanded == new_expanded
                        && original_start.get_offset() == new_start.get_offset()
                        && original_end.get_offset() == new_end.get_offset()) {
                        compared++;
                        continue;
                    }
                    if (!reaches_end) {
                        error("text '%s' selection %d..%d marker '%s': original expanded=%s (%d..%d) but new expanded=%s (%d..%d)",
                              text, s, e, marker,
                              original_expanded.to_string(), original_start.get_offset(), original_end.get_offset(),
                              new_expanded.to_string(), new_start.get_offset(), new_end.get_offset());
                    }
                    quirk_cases++;

                    // Where they differ, the new result must be the string-level truth.
                    var before_text = s >= 2 ? text.substring(text.index_of_nth_char(s - 2), text.index_of_nth_char(s) - text.index_of_nth_char(s - 2))
                                             : text.substring(0, text.index_of_nth_char(s));
                    var after_end = int.min(e + 2, length);
                    var after_text = text.substring(text.index_of_nth_char(e), text.index_of_nth_char(after_end) - text.index_of_nth_char(e));
                    var should = HolderLinux.MarkdownSelectionRules.should_expand_to_marker(marker, before_text, after_text);
                    assert(new_expanded == should);
                    if (new_expanded) {
                        assert(new_start.get_offset() == s - marker_chars);
                        assert(new_end.get_offset() == e + marker_chars);
                    }
                }
            }
        }
    }
    assert(compared > 500);
    assert(quirk_cases > 0);
}

private void test_selection_wrapped_by_a_marker_at_the_end_of_the_document_is_unwrapped() {
    // Toggling bold/italic on selected text that is the last thing in the document used to
    // wrap it a second time instead of removing the wrapper, because of the end-of-buffer
    // quirk documented above. It now removes the wrapper like anywhere else in the document.
    var buffer = new Gtk.TextBuffer(null);
    buffer.set_text("**word**", -1);
    Gtk.TextIter start, end;
    buffer.get_iter_at_offset(out start, 2);
    buffer.get_iter_at_offset(out end, 6);
    Gtk.TextIter old_start = start, old_end = end;
    assert(!original_expand(buffer, ref old_start, ref old_end, "**"));
    assert(new_expand(buffer, ref start, ref end, "**"));
    assert(start.get_offset() == 0);
    assert(end.get_offset() == 8);

    buffer.set_text("*word*", -1);
    buffer.get_iter_at_offset(out start, 1);
    buffer.get_iter_at_offset(out end, 5);
    assert(new_expand(buffer, ref start, ref end, "*"));
    assert(start.get_offset() == 0 && end.get_offset() == 6);

    // The same text followed by a newline was already handled by the original.
    buffer.set_text("**word**\n", -1);
    buffer.get_iter_at_offset(out start, 2);
    buffer.get_iter_at_offset(out end, 6);
    assert(new_expand(buffer, ref start, ref end, "**"));
    assert(start.get_offset() == 0 && end.get_offset() == 8);

    // A lone '*' beside a bold marker is still not an italic wrapper, even at the document end.
    buffer.set_text("*a**", -1);
    buffer.get_iter_at_offset(out start, 1);
    buffer.get_iter_at_offset(out end, 2);
    assert(!new_expand(buffer, ref start, ref end, "*"));
    assert(start.get_offset() == 1 && end.get_offset() == 2);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/markdown-key-map/key-constants-match-gdk", test_key_constants_match_gdk);
    Test.add_func("/holder/markdown-key-map/modifier-bits-match-gdk", test_modifier_bits_match_gdk);
    Test.add_func("/holder/markdown-key-map/table-matches-original",
                  test_key_table_matches_the_original_for_every_key_and_modifier);
    Test.add_func("/holder/markdown-key-map/plain-return-matches-original", test_plain_return_matches_the_original);
    Test.add_func("/holder/markdown-key-map/action-factories", test_key_action_factories);
    Test.add_func("/holder/markdown-key-map/shortcuts-drive-editing-controller",
                  test_shortcuts_drive_the_editing_controller);
    Test.add_func("/holder/markdown-selection/inline-marker-for", test_inline_marker_for_each_command);
    Test.add_func("/holder/markdown-selection/last-line-index", test_last_line_index_matches_the_original_expression);
    Test.add_func("/holder/markdown-selection/should-expand-to-marker", test_should_expand_to_marker_rules);
    Test.add_func("/holder/markdown-selection/expansion-matches-original",
                  test_expansion_matches_the_original_except_when_a_marker_ends_the_document);
    Test.add_func("/holder/markdown-selection/unwraps-at-end-of-document",
                  test_selection_wrapped_by_a_marker_at_the_end_of_the_document_is_unwrapped);
    return Test.run();
}

}
