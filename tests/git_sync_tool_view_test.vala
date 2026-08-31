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

private Gtk.Widget? find_widget_with_name(Gtk.Widget root, string name) {
    if (root.get_name() == name) {
        return root;
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_widget_with_name(child, name);
        if (match != null) {
            return match;
        }
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.Entry? find_entry_with_placeholder(Gtk.Widget root, string placeholder) {
    if (root is Gtk.Entry) {
        var entry = (Gtk.Entry) root;
        if (entry.get_placeholder_text() == placeholder) {
            return entry;
        }
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_entry_with_placeholder(child, placeholder);
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

private HolderLinux.Project configured_project() {
    return new HolderLinux.Project(
        "p1",
        "Runbook Project",
        "encrypted_git",
        "/tmp/p1",
        10,
        20,
        "git@github.com:HolderTeam/runbook.git",
        new HolderLinux.ProjectSyncState(null, 100, 110, 0, 0, "pushed", "pulled")
    );
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

private void test_git_sync_tool_view_shows_durable_configured_state() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    store.append(configured_project());
    var selection = new Gtk.SingleSelection(store);
    var view = new HolderLinux.GitSyncToolView(false);

    view.set_project_selection(selection);

    var state_stack = find_widget_with_name(view.widget, "git-start-state-stack") as Gtk.Stack;
    assert(state_stack != null);
    assert(((!) state_stack).get_visible_child_name() == "configured");
    var repository = find_widget_with_name(view.widget, "git-configured-repository") as Gtk.Label;
    var remote = find_widget_with_name(view.widget, "git-configured-remote") as Gtk.Label;
    assert(repository != null);
    assert(remote != null);
    assert(((!) repository).get_text() == "github.com/HolderTeam/runbook");
    assert(((!) remote).get_text() == "git@github.com:HolderTeam/runbook.git");

    var change = find_button_with_label(view.widget, "Change remote");
    assert(change != null);
    ((!) change).clicked();
    assert(((!) state_stack).get_visible_child_name() == "setup");
    var cancel = find_button_with_label(view.widget, "Cancel changes");
    assert(cancel != null);
    assert(((!) cancel).get_visible());
    ((!) cancel).clicked();
    assert(((!) state_stack).get_visible_child_name() == "configured");
}

private void test_git_sync_tool_view_refreshes_remote_from_backend() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    store.append(project());
    var selection = new Gtk.SingleSelection(store);
    var api = new MainControllerFakeApi();
    var view = new HolderLinux.GitSyncToolView(false);

    view.set_api_client(api);
    view.set_project_selection(selection);

    var state_stack = find_widget_with_name(view.widget, "git-start-state-stack") as Gtk.Stack;
    assert(state_stack != null);
    assert(wait_for_condition(() => ((!) state_stack).get_visible_child_name() == "configured"));
    var remote = find_widget_with_name(view.widget, "git-configured-remote") as Gtk.Label;
    assert(remote != null);
    assert(((!) remote).get_text() == "https://example.com/p1.git");
    assert(api.list_projects_calls > 0);
}

private void test_git_sync_tool_view_sync_now_uses_configured_project() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    store.append(configured_project());
    var selection = new Gtk.SingleSelection(store);
    var api = new MainControllerFakeApi();
    var view = new HolderLinux.GitSyncToolView(false);
    view.set_api_client(api);
    view.set_project_selection(selection);

    var sync = find_button_with_label(view.widget, "Sync now");
    assert(sync != null);
    ((!) sync).clicked();

    assert(wait_for_condition(() => api.push_project_git_calls == 1));
    assert(api.last_git_project_id == "p1");
}

private void test_git_sync_tool_view_setup_success_becomes_persistent_state() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    store.append(project());
    var selection = new Gtk.SingleSelection(store);
    var api = new MainControllerFakeApi();
    api.project_git_remote_url = null;
    var view = new HolderLinux.GitSyncToolView(false);
    view.set_api_client(api);
    view.set_project_selection(selection);

    var state_stack = find_widget_with_name(view.widget, "git-start-state-stack") as Gtk.Stack;
    assert(state_stack != null);
    var remote_entry = find_entry_with_placeholder(view.widget, "https://example.com/repo.git");
    var save = find_button_with_label(view.widget, "Save");
    assert(remote_entry != null);
    assert(save != null);
    ((!) remote_entry).set_text("https://github.com/HolderTeam/runbook.git");
    ((!) save).clicked();

    assert(wait_for_condition(() => ((!) state_stack).get_visible_child_name() == "configured"));
    var remote = find_widget_with_name(view.widget, "git-configured-remote") as Gtk.Label;
    assert(remote != null);
    assert(((!) remote).get_text() == "https://github.com/HolderTeam/runbook.git");
    assert(api.set_project_git_remote_calls == 1);
    assert(api.push_project_git_calls == 1);
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
    Test.add_func("/holder/git-sync-tool-view/configured-state",
                  test_git_sync_tool_view_shows_durable_configured_state);
    Test.add_func("/holder/git-sync-tool-view/backend-refresh",
                  test_git_sync_tool_view_refreshes_remote_from_backend);
    Test.add_func("/holder/git-sync-tool-view/sync-now",
                  test_git_sync_tool_view_sync_now_uses_configured_project);
    Test.add_func("/holder/git-sync-tool-view/setup-success-is-persistent",
                  test_git_sync_tool_view_setup_success_becomes_persistent_state);

    return Test.run();
}

}
