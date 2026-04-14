using GLib;

namespace HolderLinux.Tests {

private void test_load_uses_known_titles_and_fallback_missing_resource_markdown() {
    var controller = new HolderLinux.ToolHelpController();

    var result = controller.load("flowboard");

    assert(result.title == "Flowboard");
    assert(result.status_text == "Loaded Flowboard help.");
    assert(result.markdown.has_prefix("# Flowboard\n\nHelp page resource missing:"));
}

private void test_load_formats_unknown_tool_ids_readably() {
    var controller = new HolderLinux.ToolHelpController();

    var result = controller.load("my_custom-tool");

    assert(result.title == "My custom tool");
    assert(result.status_text == "Loaded My custom tool help.");
    assert(result.markdown.has_prefix("# My custom tool\n\nHelp page resource missing:"));
}

private void test_load_uses_generic_title_for_blank_tool_id() {
    var controller = new HolderLinux.ToolHelpController();

    var result = controller.load("   ");

    assert(result.title == "Tool Help");
    assert(result.status_text == "Loaded Tool Help help.");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/tool-help/load-known-title-and-fallback-markdown", test_load_uses_known_titles_and_fallback_missing_resource_markdown);
    Test.add_func("/holder/tool-help/load-formats-unknown-tool-ids-readably", test_load_formats_unknown_tool_ids_readably);
    Test.add_func("/holder/tool-help/load-uses-generic-title-for-blank-tool-id", test_load_uses_generic_title_for_blank_tool_id);
    return Test.run();
}

}
