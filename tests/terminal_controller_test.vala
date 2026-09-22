namespace HolderLinux.Tests {

private void test_resolve_shell() {
    var controller = new TerminalController();
    assert(controller.resolve_shell(null) == "/bin/bash");
    assert(controller.resolve_shell("") == "/bin/bash");
    assert(controller.resolve_shell("  ") == "/bin/bash");
    assert(controller.resolve_shell("/bin/zsh") == "/bin/zsh");
}

private void test_fallback_title_for_index() {
    var controller = new TerminalController();
    assert(controller.fallback_title_for_index(1) == "Term 1");
    assert(controller.fallback_title_for_index(9) == "Term 9");
}

private void test_title_or_fallback() {
    var controller = new TerminalController();
    assert(controller.title_or_fallback(null, "Term 1") == "Term 1");
    assert(controller.title_or_fallback(" ", "Term 1") == "Term 1");
    assert(controller.title_or_fallback("bash", "Term 1") == "bash");
}

private void test_selected_text_or_null() {
    var controller = new TerminalController();
    assert(controller.selected_text_or_null(null) == null);
    assert(controller.selected_text_or_null("") == null);
    assert(controller.selected_text_or_null("  ") == null);
    assert(controller.selected_text_or_null("echo hi") == "echo hi");
}

// Verbatim decision from terminal_tool_view.vala close_terminal_page(); -1 stands for "add a new tab".
private int original_page_after_close(int page_index, int count) {
    if (count == 0) {
        return -1;
    }
    var next = page_index;
    if (next >= count) {
        next = count - 1;
    }
    return next;
}

private void test_page_to_select_after_close_matches_the_original_rule() {
    var controller = new TerminalController();
    for (int closed = 0; closed < 6; closed++) {
        for (int remaining = 0; remaining < 6; remaining++) {
            assert(controller.page_to_select_after_close(closed, remaining)
                   == original_page_after_close(closed, remaining));
        }
    }
    assert(controller.page_to_select_after_close(0, 0) == -1);
    assert(controller.page_to_select_after_close(2, 2) == 1);
    assert(controller.page_to_select_after_close(1, 3) == 1);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/terminal/resolve_shell", test_resolve_shell);
    Test.add_func("/holder/terminal/fallback_title", test_fallback_title_for_index);
    Test.add_func("/holder/terminal/title_or_fallback", test_title_or_fallback);
    Test.add_func("/holder/terminal/selected_text_or_null", test_selected_text_or_null);
    Test.add_func("/holder/terminal/page_to_select_after_close", test_page_to_select_after_close_matches_the_original_rule);
    return Test.run();
}

}
