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

// Verbatim copy of the hand-written get_scope_snapshot() that the toolbox views used to carry.
private HolderLinux.ToolScopeSnapshot original_view_snapshot(HolderLinux.Project? selected_project,
                                                             HolderLinux.CardSummary? selected_card,
                                                             bool is_loading) {
    var project_id = selected_project != null ? selected_project.project_id : null;
    var project_label = selected_project != null ? selected_project.name : "(none)";
    var card_id = selected_card != null ? selected_card.card_id : null;
    var card_label = selected_card != null ? selected_card.title : "Overview";

    HolderLinux.ToolScopeMode scope_mode = selected_card != null
        ? HolderLinux.ToolScopeMode.CARD_FOCUS
        : HolderLinux.ToolScopeMode.PROJECT_ROOT;
    if (project_id == null) {
        scope_mode = HolderLinux.ToolScopeMode.PROJECTS_ROOT;
        project_label = "Projects";
        card_id = null;
        card_label = "Overview";
    }

    return new HolderLinux.ToolScopeSnapshot(
        "tool", "Tool", project_id, project_label, card_id, card_label, scope_mode, is_loading
    );
}

// Verbatim copy of the variant tags_tool_view.vala used (different project label seed).
private HolderLinux.ToolScopeSnapshot original_tags_snapshot(HolderLinux.Project? selected_project,
                                                             HolderLinux.CardSummary? selected_card) {
    var project_id = selected_project != null ? selected_project.project_id : null;
    var project_label = selected_project != null ? selected_project.name : "Projects";
    var card_id = selected_card != null ? selected_card.card_id : null;
    var card_label = selected_card != null ? selected_card.title : "Overview";
    var scope = selected_card != null
        ? HolderLinux.ToolScopeMode.CARD_FOCUS
        : HolderLinux.ToolScopeMode.PROJECT_ROOT;
    if (project_id == null) {
        scope = HolderLinux.ToolScopeMode.PROJECTS_ROOT;
        card_id = null;
        card_label = "Overview";
    }
    return new HolderLinux.ToolScopeSnapshot(
        "tool", "Tool", project_id, project_label, card_id, card_label, scope, false
    );
}

// Verbatim copy of flowboard_tool_view.vala's rule, with its two state predicates as inputs.
private HolderLinux.ToolScopeSnapshot original_flowboard_snapshot(bool showing_projects_root,
                                                                  bool showing_project_root_level,
                                                                  HolderLinux.Project? selected_project,
                                                                  HolderLinux.CardSummary? selected_card) {
    var project_id = selected_project != null ? selected_project.project_id : null;
    var project_label = selected_project != null ? selected_project.name : "(none)";
    var card_id = selected_card != null ? selected_card.card_id : null;
    var card_label = selected_card != null ? selected_card.title : "Overview";

    HolderLinux.ToolScopeMode scope_mode = HolderLinux.ToolScopeMode.CARD_FOCUS;
    if (showing_projects_root) {
        scope_mode = HolderLinux.ToolScopeMode.PROJECTS_ROOT;
        project_label = "Projects";
        card_label = "Overview";
        project_id = null;
        card_id = null;
    } else if (showing_project_root_level || selected_card == null) {
        scope_mode = HolderLinux.ToolScopeMode.PROJECT_ROOT;
        card_label = "Overview";
        card_id = null;
    }
    return new HolderLinux.ToolScopeSnapshot(
        "tool", "Tool", project_id, project_label, card_id, card_label, scope_mode, false
    );
}

private void assert_same_snapshot(HolderLinux.ToolScopeSnapshot expected, HolderLinux.ToolScopeSnapshot actual) {
    assert(expected.tool_id == actual.tool_id);
    assert(expected.tool_label == actual.tool_label);
    assert(expected.project_id == actual.project_id);
    assert(expected.project_label == actual.project_label);
    assert(expected.card_id == actual.card_id);
    assert(expected.card_label == actual.card_label);
    assert(expected.scope_mode == actual.scope_mode);
    assert(expected.is_loading == actual.is_loading);
}

private void test_snapshot_matches_the_original_view_copies_for_every_selection() {
    for (int p = 0; p < 2; p++) {
        for (int c = 0; c < 2; c++) {
            HolderLinux.Project? project = p == 0 ? null : scope_project();
            HolderLinux.CardSummary? card = c == 0 ? null : scope_card();
            for (int l = 0; l < 2; l++) {
                bool loading = l == 1;
                assert_same_snapshot(
                    original_view_snapshot(project, card, loading),
                    HolderLinux.ToolScopePresenter.snapshot("tool", "Tool", project, card, loading)
                );
            }
            assert_same_snapshot(
                original_tags_snapshot(project, card),
                HolderLinux.ToolScopePresenter.snapshot("tool", "Tool", project, card)
            );
        }
    }
}

private void test_projects_root_variant_reproduces_the_flowboard_rule() {
    for (int p = 0; p < 2; p++) {
        for (int c = 0; c < 2; c++) {
            for (int r = 0; r < 2; r++) {
                for (int l = 0; l < 2; l++) {
                    HolderLinux.Project? project = p == 0 ? null : scope_project();
                    HolderLinux.CardSummary? card = c == 0 ? null : scope_card();
                    bool projects_root = r == 1;
                    bool root_level = l == 1;
                    assert_same_snapshot(
                        original_flowboard_snapshot(projects_root, root_level, project, card),
                        HolderLinux.ToolScopePresenter.snapshot_with_projects_root(
                            "tool", "Tool", projects_root, project, root_level ? null : card
                        )
                    );
                }
            }
        }
    }
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
    Test.add_func("/holder/tool-scope/matches-original-view-copies", test_snapshot_matches_the_original_view_copies_for_every_selection);
    Test.add_func("/holder/tool-scope/flowboard-rule-via-projects-root-variant", test_projects_root_variant_reproduces_the_flowboard_rule);
    return Test.run();
}

}
