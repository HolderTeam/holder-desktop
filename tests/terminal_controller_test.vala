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

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/terminal/resolve_shell", test_resolve_shell);
    Test.add_func("/holder/terminal/fallback_title", test_fallback_title_for_index);
    Test.add_func("/holder/terminal/title_or_fallback", test_title_or_fallback);
    Test.add_func("/holder/terminal/selected_text_or_null", test_selected_text_or_null);
    return Test.run();
}

}
