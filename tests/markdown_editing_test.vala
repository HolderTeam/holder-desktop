using GLib;

namespace HolderLinuxTests {

private string apply_line_command(string text, HolderLinux.MarkdownLineCommand command) {
    var controller = new HolderLinux.MarkdownEditingController();
    var lines = text.split("\n");
    var edits = controller.decide_line_edits(lines, command);
    var result = new StringBuilder();
    for (var index = 0; index < lines.length; index++) {
        if (index > 0) {
            result.append_c('\n');
        }
        result.append(edits[index].insertion);
        result.append(lines[index].substring(edits[index].remove_chars));
    }
    return result.str;
}

private void test_continues_bullets_and_preserves_indentation() {
    var controller = new HolderLinux.MarkdownEditingController();

    var dash = controller.decide_return("- first item");
    assert(dash.action == HolderLinux.MarkdownListAction.CONTINUE);
    assert(dash.continuation == "- ");

    var nested = controller.decide_return("    * nested item");
    assert(nested.action == HolderLinux.MarkdownListAction.CONTINUE);
    assert(nested.continuation == "    * ");
}

private void test_increments_ordered_lists_and_preserves_delimiter() {
    var controller = new HolderLinux.MarkdownEditingController();

    var dot = controller.decide_return("9. ninth item");
    assert(dot.action == HolderLinux.MarkdownListAction.CONTINUE);
    assert(dot.continuation == "10. ");

    var parenthesis = controller.decide_return("  41) answer");
    assert(parenthesis.action == HolderLinux.MarkdownListAction.CONTINUE);
    assert(parenthesis.continuation == "  42) ");
}

private void test_continues_tasks_as_unchecked() {
    var controller = new HolderLinux.MarkdownEditingController();

    var unchecked = controller.decide_return("- [ ] pending");
    assert(unchecked.action == HolderLinux.MarkdownListAction.CONTINUE);
    assert(unchecked.continuation == "- [ ] ");

    var checked = controller.decide_return("  * [x] complete");
    assert(checked.action == HolderLinux.MarkdownListAction.CONTINUE);
    assert(checked.continuation == "  * [ ] ");
}

private void test_empty_items_end_the_list() {
    var controller = new HolderLinux.MarkdownEditingController();

    assert(controller.decide_return("- ").action == HolderLinux.MarkdownListAction.END);
    assert(controller.decide_return("7.   ").action == HolderLinux.MarkdownListAction.END);
    assert(controller.decide_return("  + [ ] ").action == HolderLinux.MarkdownListAction.END);
}

private void test_plain_text_keeps_default_return_behavior() {
    var controller = new HolderLinux.MarkdownEditingController();

    assert(controller.decide_return("ordinary prose").action == HolderLinux.MarkdownListAction.NONE);
    assert(controller.decide_return("# Heading").action == HolderLinux.MarkdownListAction.NONE);
}

private void test_indents_and_outdents_affected_lines() {
    assert(apply_line_command(
        "one\n  two\n\tthree",
        HolderLinux.MarkdownLineCommand.INDENT
    ) == "    one\n      two\n    \tthree");
    assert(apply_line_command(
        "    one\n  two\n\tthree\nfour",
        HolderLinux.MarkdownLineCommand.OUTDENT
    ) == "one\ntwo\nthree\nfour");
}

private void test_cycles_common_heading_levels() {
    assert(apply_line_command("Title", HolderLinux.MarkdownLineCommand.CYCLE_HEADING) == "# Title");
    assert(apply_line_command("# Title", HolderLinux.MarkdownLineCommand.CYCLE_HEADING) == "## Title");
    assert(apply_line_command("## Title", HolderLinux.MarkdownLineCommand.CYCLE_HEADING) == "### Title");
    assert(apply_line_command("### Title", HolderLinux.MarkdownLineCommand.CYCLE_HEADING) == "Title");
    assert(apply_line_command("  #### Deep", HolderLinux.MarkdownLineCommand.CYCLE_HEADING) == "  Deep");
    assert(apply_line_command("#tag", HolderLinux.MarkdownLineCommand.CYCLE_HEADING) == "# #tag");
}

private void test_converts_and_toggles_lists() {
    assert(apply_line_command(
        "alpha\nbeta",
        HolderLinux.MarkdownLineCommand.NUMBERED_LIST
    ) == "1. alpha\n2. beta");
    assert(apply_line_command(
        "- alpha\n* beta",
        HolderLinux.MarkdownLineCommand.NUMBERED_LIST
    ) == "1. alpha\n2. beta");
    assert(apply_line_command(
        "1. alpha\n2. beta",
        HolderLinux.MarkdownLineCommand.NUMBERED_LIST
    ) == "alpha\nbeta");

    assert(apply_line_command(
        "1. alpha\n2. beta",
        HolderLinux.MarkdownLineCommand.BULLETED_LIST
    ) == "- alpha\n- beta");
    assert(apply_line_command(
        "- alpha\n- beta",
        HolderLinux.MarkdownLineCommand.BULLETED_LIST
    ) == "alpha\nbeta");
}

private void test_todo_conversion_preserves_existing_state() {
    assert(apply_line_command(
        "- [x] done\nplain",
        HolderLinux.MarkdownLineCommand.TODO_LIST
    ) == "- [x] done\n- [ ] plain");
    assert(apply_line_command(
        "- [x] done\n- [ ] later",
        HolderLinux.MarkdownLineCommand.TODO_LIST
    ) == "done\nlater");
}

private void test_toggles_one_blockquote_level() {
    assert(apply_line_command(
        "one\n  two",
        HolderLinux.MarkdownLineCommand.BLOCKQUOTE
    ) == "> one\n  > two");
    assert(apply_line_command(
        "> one\n  > two",
        HolderLinux.MarkdownLineCommand.BLOCKQUOTE
    ) == "one\n  two");
}

private void test_toggles_inline_formatting() {
    var controller = new HolderLinux.MarkdownEditingController();
    foreach (var command in new HolderLinux.MarkdownInlineCommand[] {
        HolderLinux.MarkdownInlineCommand.BOLD,
        HolderLinux.MarkdownInlineCommand.ITALIC,
        HolderLinux.MarkdownInlineCommand.STRIKETHROUGH
    }) {
        var edit = controller.decide_inline_edit("hello", true, command);
        assert(edit.changed);
        assert(edit.select_replacement);
        var toggled = controller.decide_inline_edit(edit.replacement, true, command);
        assert(toggled.replacement == "hello");
    }

    var empty = controller.decide_inline_edit(
        "",
        false,
        HolderLinux.MarkdownInlineCommand.BOLD
    );
    assert(empty.replacement == "****");
    assert(empty.selection_start == 2);
    assert(empty.selection_end == 2);
    assert(!empty.select_replacement);
}

private void test_code_uses_inline_or_fenced_form() {
    var controller = new HolderLinux.MarkdownEditingController();
    var inline_edit = controller.decide_inline_edit(
        "printf()",
        true,
        HolderLinux.MarkdownInlineCommand.CODE
    );
    assert(inline_edit.replacement == "`printf()`");

    var block = controller.decide_inline_edit(
        "first\nsecond",
        true,
        HolderLinux.MarkdownInlineCommand.CODE
    );
    assert(block.replacement == "```\nfirst\nsecond\n```");
    var restored = controller.decide_inline_edit(
        block.replacement,
        true,
        HolderLinux.MarkdownInlineCommand.CODE
    );
    assert(restored.replacement == "first\nsecond");
}

private void test_builds_links_and_avoids_nesting_existing_links() {
    var controller = new HolderLinux.MarkdownEditingController();
    var web = controller.decide_inline_edit(
        "Holder",
        true,
        HolderLinux.MarkdownInlineCommand.LINK
    );
    assert(web.replacement == "[Holder]()");
    assert(web.selection_start == 9);
    assert(!web.select_replacement);

    var wiki = controller.decide_inline_edit(
        "Card title",
        true,
        HolderLinux.MarkdownInlineCommand.WIKILINK
    );
    assert(wiki.replacement == "[[Card title]]");
    assert(wiki.select_replacement);

    var existing = controller.decide_inline_edit(
        "[Holder](https://holder.team)",
        true,
        HolderLinux.MarkdownInlineCommand.LINK
    );
    assert(!existing.changed);
}

private void test_clears_known_inline_and_structural_formatting() {
    var controller = new HolderLinux.MarkdownEditingController();
    foreach (var formatted in new string[] {"**hello**", "*hello*", "~~hello~~", "`hello`"}) {
        var edit = controller.decide_inline_edit(
            formatted,
            true,
            HolderLinux.MarkdownInlineCommand.CLEAR_FORMATTING
        );
        assert(edit.replacement == "hello");
    }
    assert(apply_line_command(
        "# Heading\n> Quote\n- item",
        HolderLinux.MarkdownLineCommand.CLEAR_STRUCTURE
    ) == "Heading\nQuote\nitem");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/markdown-editing/continues-bullets", test_continues_bullets_and_preserves_indentation);
    Test.add_func("/holder/markdown-editing/increments-ordered", test_increments_ordered_lists_and_preserves_delimiter);
    Test.add_func("/holder/markdown-editing/continues-tasks", test_continues_tasks_as_unchecked);
    Test.add_func("/holder/markdown-editing/ends-empty-list", test_empty_items_end_the_list);
    Test.add_func("/holder/markdown-editing/plain-text", test_plain_text_keeps_default_return_behavior);
    Test.add_func("/holder/markdown-editing/indent-outdent", test_indents_and_outdents_affected_lines);
    Test.add_func("/holder/markdown-editing/cycle-headings", test_cycles_common_heading_levels);
    Test.add_func("/holder/markdown-editing/lists", test_converts_and_toggles_lists);
    Test.add_func("/holder/markdown-editing/todo-state", test_todo_conversion_preserves_existing_state);
    Test.add_func("/holder/markdown-editing/blockquotes", test_toggles_one_blockquote_level);
    Test.add_func("/holder/markdown-editing/inline-formatting", test_toggles_inline_formatting);
    Test.add_func("/holder/markdown-editing/code", test_code_uses_inline_or_fenced_form);
    Test.add_func("/holder/markdown-editing/links", test_builds_links_and_avoids_nesting_existing_links);
    Test.add_func("/holder/markdown-editing/clear-formatting", test_clears_known_inline_and_structural_formatting);
    return Test.run();
}

}
