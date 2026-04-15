using GLib;

namespace HolderLinux.Tests {

private void test_load_uses_known_titles_and_fallback_missing_resource_markdown() {
    var controller = new HolderLinux.ToolHelpController();

    var result = controller.load("flowboard");

    assert(result.title == "Flowboard");
    assert(result.status_text == "Loaded Flowboard help.");
    assert(result.markdown.length > 0);
}

private void test_load_uses_known_titles_for_all_explicit_tool_ids() {
    var controller = new HolderLinux.ToolHelpController();

    var connections = controller.load("connections");
    var resources = controller.load("resources");
    var sharing = controller.load("sharing");
    var terminals = controller.load("terminals");
    var git = controller.load("git");
    var recovery = controller.load("recovery");
    var trash = controller.load("trash");
    var debug = controller.load("debug");

    assert(connections.title == "Connections");
    assert(resources.title == "Resources");
    assert(sharing.title == "Sharing");
    assert(terminals.title == "Terminals");
    assert(git.title == "Git Sync");
    assert(recovery.title == "Recovery Key");
    assert(trash.title == "Trash");
    assert(debug.title == "Debug");
}

private void test_load_reads_real_help_resource_when_available() {
    var controller = new HolderLinux.ToolHelpController();

    var result = controller.load("connections");

    assert(result.title == "Connections");
    assert(result.status_text == "Loaded Connections help.");
    assert(!result.markdown.has_prefix("# Connections\n\nHelp page resource missing:"));
    assert(result.markdown.length > 0);
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
    Test.add_func("/holder/tool-help/load-known-titles-for-all-explicit-tool-ids", test_load_uses_known_titles_for_all_explicit_tool_ids);
    Test.add_func("/holder/tool-help/load-reads-real-help-resource-when-available", test_load_reads_real_help_resource_when_available);
    Test.add_func("/holder/tool-help/load-formats-unknown-tool-ids-readably", test_load_formats_unknown_tool_ids_readably);
    Test.add_func("/holder/tool-help/load-uses-generic-title-for-blank-tool-id", test_load_uses_generic_title_for_blank_tool_id);
    return Test.run();
}

}
