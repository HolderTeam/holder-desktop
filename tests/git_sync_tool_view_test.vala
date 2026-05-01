using GLib;

namespace HolderLinuxTests {

private Gtk.Widget? find_widget_by_type(Gtk.Widget root, Type type) {
    if (root.get_type().is_a(type)) {
        return root;
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_widget_by_type(child, type);
        if (match != null) {
            return match;
        }
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.Button? find_button_with_label(Gtk.Widget root, string label) {
    if (root is Gtk.Button) {
        var button = (Gtk.Button) root;
        if (button.get_label() == label) {
            return button;
        }
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_button_with_label(child, label);
        if (match != null) {
            return match;
        }
        child = child.get_next_sibling();
    }
    return null;
}

private HolderLinux.Project project() {
    return new HolderLinux.Project("p1", "Runbook Project", "encrypted_git", "/tmp/p1", 10, 20);
}

private HolderLinux.CardSummary card() {
    return new HolderLinux.CardSummary("c1", "p1", "Runbook Card", "card.md", 1.0, null, 10, 20);
}

private void test_git_sync_tool_view_constructs_pages_and_navigation() {
    var view = new HolderLinux.GitSyncToolView(false);
    var stack = find_widget_by_type(view.widget, typeof(Gtk.Stack)) as Gtk.Stack;
    assert(stack != null);
    assert(((!) stack).get_visible_child_name() == "start");

    var guided = find_button_with_label(view.widget, "Guided (I'm new to this)");
    var provider = find_button_with_label(view.widget, "Provider setup (I know git)");
    assert(guided != null);
    assert(provider != null);

    ((!) guided).clicked();
    assert(((!) stack).get_visible_child_name() == "guided-part1");

    ((!) provider).clicked();
    assert(((!) stack).get_visible_child_name() == "provider");
}

private void test_git_sync_tool_view_scope_snapshots() {
    var view = new HolderLinux.GitSyncToolView(false);

    var root_scope = view.get_scope_snapshot(null, null);
    assert(root_scope.tool_id == "git");
    assert(root_scope.tool_label == "Git Sync");
    assert(root_scope.scope_mode == HolderLinux.ToolScopeMode.PROJECTS_ROOT);
    assert(root_scope.project_label == "Projects");
    assert(root_scope.card_label == "Overview");

    var project_scope = view.get_scope_snapshot(project(), null);
    assert(project_scope.scope_mode == HolderLinux.ToolScopeMode.PROJECT_ROOT);
    assert(project_scope.project_id == "p1");
    assert(project_scope.project_label == "Runbook Project");
    assert(project_scope.card_label == "Overview");

    var card_scope = view.get_scope_snapshot(project(), card());
    assert(card_scope.scope_mode == HolderLinux.ToolScopeMode.CARD_FOCUS);
    assert(card_scope.card_id == "c1");
    assert(card_scope.card_label == "Runbook Card");
}

private void test_git_sync_tool_view_project_selection_refreshes_defaults() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    store.append(project());
    var selection = new Gtk.SingleSelection(store);

    var view = new HolderLinux.GitSyncToolView(false);
    view.set_project_selection(selection);
    assert(view.get_content_widget() == view.widget);
    assert(view.get_actions_widget() == null);
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping git sync tool view tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/holder/git-sync-tool-view/constructs-pages-and-navigation",
                  test_git_sync_tool_view_constructs_pages_and_navigation);
    Test.add_func("/holder/git-sync-tool-view/scope-snapshots",
                  test_git_sync_tool_view_scope_snapshots);
    Test.add_func("/holder/git-sync-tool-view/project-selection-refreshes-defaults",
                  test_git_sync_tool_view_project_selection_refreshes_defaults);

    return Test.run();
}

}
