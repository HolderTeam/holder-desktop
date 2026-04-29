using GLib;

namespace HolderLinuxTests {

private Gtk.SingleSelection project_selection_with_one() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    store.append(new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 10, 10));
    var selection = new Gtk.SingleSelection(store);
    selection.set_selected(0);
    return selection;
}

private Gtk.ColumnView? find_column_view(Gtk.Widget root) {
    if (root is Gtk.ColumnView) {
        return (Gtk.ColumnView) root;
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_column_view(child);
        if (match != null) {
            return match;
        }
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.DropDown? find_dropdown(Gtk.Widget root) {
    if (root is Gtk.DropDown) {
        return (Gtk.DropDown) root;
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_dropdown(child);
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

private Gtk.Label trash_empty_label(HolderLinux.TrashToolView view) {
    var label = view.widget.get_last_child() as Gtk.Label;
    assert(label != null);
    return (!) label;
}

private Gtk.Button empty_trash_button(HolderLinux.TrashToolView view) {
    var actions = view.get_actions_widget();
    assert(actions != null);
    var button = find_button_with_label((!) actions, "Empty Trash");
    assert(button != null);
    return (!) button;
}

private void set_trash_filter_index(HolderLinux.TrashToolView view, uint index) {
    var actions = view.get_actions_widget();
    assert(actions != null);
    var dropdown = find_dropdown((!) actions);
    assert(dropdown != null);
    ((!) dropdown).set_selected(index);
}

private uint trash_item_count(HolderLinux.TrashToolView view) {
    var column_view = find_column_view(view.widget);
    assert(column_view != null);
    var model = ((!) column_view).get_model();
    assert(model != null);
    return ((!) model).get_n_items();
}

private void test_refresh_without_project_shows_select_message() {
    var api = new MainControllerFakeApi();
    var view = new HolderLinux.TrashToolView();
    view.set_api_client(api);

    assert(wait_for_condition(() => trash_empty_label(view).get_visible()));
    var scope = view.get_scope_snapshot(null, null);
    assert(scope.project_label == "Projects");
    assert(scope.card_label == "Overview");
    assert(scope.scope_mode == HolderLinux.ToolScopeMode.PROJECTS_ROOT);
    assert(trash_empty_label(view).get_text() == "Select a project to view trash.");
    assert(!empty_trash_button(view).get_sensitive());
    assert(api.list_trash_calls == 0);
}

private void test_refresh_with_items_updates_scope_and_state() {
    var api = new MainControllerFakeApi();
    api.trash_items.add(new HolderLinux.TrashItem("card", "c1", "Card 1", 1700000000));
    api.trash_items.add(new HolderLinux.TrashItem("ai_message", "m1", "assistant: m1", 1700000001));

    var view = new HolderLinux.TrashToolView();
    view.set_api_client(api);
    view.set_project_selection(project_selection_with_one());

    assert(wait_for_condition(() => api.list_trash_calls > 0));
    assert(wait_for_condition(() => trash_item_count(view) == 2));
    var scope = view.get_scope_snapshot(new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 10, 10), null);
    assert(scope.project_label == "Project 1");
    assert(scope.card_label == "Overview");
    assert(scope.scope_mode == HolderLinux.ToolScopeMode.PROJECT_ROOT);
    assert(!trash_empty_label(view).get_visible());
    assert(empty_trash_button(view).get_sensitive());
    assert(api.last_trash_project_id == "p1");
    assert(api.last_trash_type == "all");
}

private void test_filter_selection_updates_type_param() {
    var api = new MainControllerFakeApi();
    var view = new HolderLinux.TrashToolView();
    view.set_api_client(api);
    view.set_project_selection(project_selection_with_one());

    assert(wait_for_condition(() => api.list_trash_calls > 0));

    set_trash_filter_index(view, 1);
    assert(wait_for_condition(() => api.last_trash_type == "card"));

    set_trash_filter_index(view, 2);
    assert(wait_for_condition(() => api.last_trash_type == "ai_message"));
}

private void test_refresh_failure_emits_error_and_empty_state() {
    var api = new MainControllerFakeApi();
    api.fail_list_trash = true;

    var view = new HolderLinux.TrashToolView();
    bool got_error = false;
    view.error_reported.connect((title, details) => {
        if (title == "Trash refresh failed") {
            got_error = true;
        }
    });

    view.set_api_client(api);
    view.set_project_selection(project_selection_with_one());

    assert(wait_for_condition(() => got_error));
    assert(trash_empty_label(view).get_visible());
    assert(trash_empty_label(view).get_text() == "Failed to load trash.");
    assert(!empty_trash_button(view).get_sensitive());
}

private void test_restore_hard_delete_and_empty_actions() {
    var api = new MainControllerFakeApi();
    var view = new HolderLinux.TrashToolView();

    string last_toast = "";
    view.toast_requested.connect((message) => {
        last_toast = message;
    });

    view.set_api_client(api);
    view.set_project_selection(project_selection_with_one());

    var item = new HolderLinux.TrashItem("card", "c1", "Card 1", 1700000000);

    bool restore_done = false;
    view.restore_item.begin(item, (obj, res) => {
        view.restore_item.end(res);
        restore_done = true;
    });
    assert(wait_for_condition(() => restore_done));
    assert(api.restore_trash_calls == 1);
    assert(api.last_restore_item_type == "card");
    assert(api.last_restore_item_id == "c1");
    assert(last_toast == "Item restored.");

    bool hard_delete_done = false;
    view.hard_delete_item.begin(item, (obj, res) => {
        view.hard_delete_item.end(res);
        hard_delete_done = true;
    });
    assert(wait_for_condition(() => hard_delete_done));
    assert(api.hard_delete_trash_calls == 1);
    assert(api.last_hard_delete_item_type == "card");
    assert(api.last_hard_delete_item_id == "c1");
    assert(last_toast == "Item permanently deleted.");

    bool empty_done = false;
    view.empty_trash.begin("p1", (obj, res) => {
        view.empty_trash.end(res);
        empty_done = true;
    });
    assert(wait_for_condition(() => empty_done));
    assert(api.empty_trash_calls == 1);
    assert(api.last_trash_project_id == "p1");
    assert(api.last_trash_type == "all");
    assert(last_toast == "Trash emptied.");
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping trash tool view tests: GTK display is unavailable.\\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/holder/trash-view/no-project", test_refresh_without_project_shows_select_message);
    Test.add_func("/holder/trash-view/refresh-with-items", test_refresh_with_items_updates_scope_and_state);
    Test.add_func("/holder/trash-view/filter-type-param", test_filter_selection_updates_type_param);
    Test.add_func("/holder/trash-view/refresh-failure", test_refresh_failure_emits_error_and_empty_state);
    Test.add_func("/holder/trash-view/actions", test_restore_hard_delete_and_empty_actions);
    return Test.run();
}

}
