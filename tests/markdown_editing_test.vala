using GLib;

namespace HolderLinuxTests {

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

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/markdown-editing/continues-bullets", test_continues_bullets_and_preserves_indentation);
    Test.add_func("/holder/markdown-editing/increments-ordered", test_increments_ordered_lists_and_preserves_delimiter);
    Test.add_func("/holder/markdown-editing/continues-tasks", test_continues_tasks_as_unchecked);
    Test.add_func("/holder/markdown-editing/ends-empty-list", test_empty_items_end_the_list);
    Test.add_func("/holder/markdown-editing/plain-text", test_plain_text_keeps_default_return_behavior);
    return Test.run();
}

}
