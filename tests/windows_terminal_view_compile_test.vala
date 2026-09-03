using GLib;

namespace HolderLinuxTests {

private void test_windows_terminal_view_sources_link() {
    var controller = new HolderLinux.TerminalController();
    assert(controller.selected_text_or_null("terminal output") == "terminal output");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func(
        "/windows_terminal_view/sources_link",
        test_windows_terminal_view_sources_link
    );
    return Test.run();
}

}
