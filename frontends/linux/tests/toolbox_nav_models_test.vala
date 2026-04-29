using GLib;

namespace HolderLinux.Tests {

private void test_tool_scope_snapshot_preserves_explicit_values() {
    var snapshot = new HolderLinux.ToolScopeSnapshot(
        "connections",
        "Connections",
        "proj-1",
        "Project One",
        "card-1",
        "Card One",
        HolderLinux.ToolScopeMode.PROJECT_ROOT,
        true
    );

    assert(snapshot.tool_id == "connections");
    assert(snapshot.tool_label == "Connections");
    assert(snapshot.project_id == "proj-1");
    assert(snapshot.project_label == "Project One");
    assert(snapshot.card_id == "card-1");
    assert(snapshot.card_label == "Card One");
    assert(snapshot.scope_mode == HolderLinux.ToolScopeMode.PROJECT_ROOT);
    assert(snapshot.is_loading);
}

private void test_tool_scope_snapshot_uses_constructor_defaults() {
    var snapshot = new HolderLinux.ToolScopeSnapshot(
        "flowboard",
        "Flowboard",
        null,
        "",
        null,
        ""
    );

    assert(snapshot.tool_id == "flowboard");
    assert(snapshot.tool_label == "Flowboard");
    assert(snapshot.project_id == null);
    assert(snapshot.project_label == "");
    assert(snapshot.card_id == null);
    assert(snapshot.card_label == "");
    assert(snapshot.scope_mode == HolderLinux.ToolScopeMode.CARD_FOCUS);
    assert(!snapshot.is_loading);
}

private void test_navigation_breadcrumb_segment_preserves_constructor_values() {
    var segment = new HolderLinux.NavigationBreadcrumbSegment(
        "Project One",
        true,
        false,
        2
    );

    assert(segment.label == "Project One");
    assert(segment.emphasized);
    assert(!segment.clickable);
    assert(segment.index == 2);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/toolbox-nav-models/tool-scope-snapshot-preserves-explicit-values", test_tool_scope_snapshot_preserves_explicit_values);
    Test.add_func("/holder/toolbox-nav-models/tool-scope-snapshot-uses-constructor-defaults", test_tool_scope_snapshot_uses_constructor_defaults);
    Test.add_func("/holder/toolbox-nav-models/navigation-breadcrumb-segment-preserves-constructor-values", test_navigation_breadcrumb_segment_preserves_constructor_values);
    return Test.run();
}

}
