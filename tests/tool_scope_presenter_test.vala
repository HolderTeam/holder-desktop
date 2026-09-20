using GLib;

namespace HolderLinuxTests {

private HolderLinux.Project scope_project() {
    return new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 10, 10);
}

private HolderLinux.CardSummary scope_card() {
    return new HolderLinux.CardSummary("c1", "p1", "Card 1", "c1.md", 1024.0, null, 20, 20);
}

private void test_snapshot_without_project_is_projects_root_even_with_a_card() {
    var snapshot = HolderLinux.ToolScopePresenter.snapshot("resources", "Resources", null, scope_card());
    assert(snapshot.tool_id == "resources");
    assert(snapshot.tool_label == "Resources");
    assert(snapshot.project_id == null);
    assert(snapshot.project_label == "Projects");
    assert(snapshot.card_id == null);
    assert(snapshot.card_label == "Overview");
    assert(snapshot.scope_mode == HolderLinux.ToolScopeMode.PROJECTS_ROOT);
    assert(!snapshot.is_loading);
}

private void test_snapshot_with_project_only_is_project_root() {
    var snapshot = HolderLinux.ToolScopePresenter.snapshot("trash", "Trash", scope_project(), null);
    assert(snapshot.project_id == "p1");
    assert(snapshot.project_label == "Project 1");
    assert(snapshot.card_id == null);
    assert(snapshot.card_label == "Overview");
    assert(snapshot.scope_mode == HolderLinux.ToolScopeMode.PROJECT_ROOT);
}

private void test_snapshot_with_project_and_card_is_card_focus() {
    var snapshot = HolderLinux.ToolScopePresenter.snapshot("trash", "Trash", scope_project(), scope_card());
    assert(snapshot.card_id == "c1");
    assert(snapshot.card_label == "Card 1");
    assert(snapshot.scope_mode == HolderLinux.ToolScopeMode.CARD_FOCUS);
}

private void test_projects_root_flag_overrides_the_selection() {
    var snapshot = HolderLinux.ToolScopePresenter.snapshot_with_projects_root(
        "connections", "Connections", true, scope_project(), scope_card()
    );
    assert(snapshot.project_id == null);
    assert(snapshot.project_label == "Projects");
    assert(snapshot.card_id == null);
    assert(snapshot.card_label == "Overview");
    assert(snapshot.scope_mode == HolderLinux.ToolScopeMode.PROJECTS_ROOT);
}

private void test_projects_root_variant_without_card_is_project_root_even_without_project() {
    var snapshot = HolderLinux.ToolScopePresenter.snapshot_with_projects_root(
        "connections", "Connections", false, null, null
    );
    assert(snapshot.project_id == null);
    assert(snapshot.project_label == "(none)");
    assert(snapshot.scope_mode == HolderLinux.ToolScopeMode.PROJECT_ROOT);

    var with_project = HolderLinux.ToolScopePresenter.snapshot_with_projects_root(
        "connections", "Connections", false, scope_project(), null
    );
    assert(with_project.project_id == "p1");
    assert(with_project.card_label == "Overview");
    assert(with_project.scope_mode == HolderLinux.ToolScopeMode.PROJECT_ROOT);
}

private void test_projects_root_variant_with_card_is_card_focus() {
    var snapshot = HolderLinux.ToolScopePresenter.snapshot_with_projects_root(
        "connections", "Connections", false, scope_project(), scope_card()
    );
    assert(snapshot.card_id == "c1");
    assert(snapshot.card_label == "Card 1");
    assert(snapshot.scope_mode == HolderLinux.ToolScopeMode.CARD_FOCUS);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/tool-scope/no-project", test_snapshot_without_project_is_projects_root_even_with_a_card);
    Test.add_func("/holder/tool-scope/project-only", test_snapshot_with_project_only_is_project_root);
    Test.add_func("/holder/tool-scope/project-and-card", test_snapshot_with_project_and_card_is_card_focus);
    Test.add_func("/holder/tool-scope/projects-root-flag", test_projects_root_flag_overrides_the_selection);
    Test.add_func("/holder/tool-scope/projects-root-variant-project-root",
                  test_projects_root_variant_without_card_is_project_root_even_without_project);
    Test.add_func("/holder/tool-scope/projects-root-variant-card-focus", test_projects_root_variant_with_card_is_card_focus);
    return Test.run();
}

}
