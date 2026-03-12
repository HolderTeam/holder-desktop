using GLib;

namespace HolderLinuxTests {

private Gtk.SingleSelection project_selection_with_one() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    store.append(new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 10, 10));
    var selection = new Gtk.SingleSelection(store);
    selection.set_selected(0);
    return selection;
}

private Gtk.SingleSelection project_selection_with_two() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    store.append(new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 10, 10));
    store.append(new HolderLinux.Project("p2", "Project 2", "encrypted_git", "/tmp/p2", 20, 20));
    var selection = new Gtk.SingleSelection(store);
    selection.set_selected(0);
    return selection;
}

private void test_refresh_without_project_shows_select_message() {
    var api = new MainControllerFakeApi();
    var controller = new HolderLinux.TrashController();
    controller.set_api_client(api);

    assert(wait_for_condition(() => controller.empty_visible));
    assert(controller.scope_text == "Projects / (none) / Trash");
    assert(controller.empty_text == "Select a project to view trash.");
    assert(!controller.empty_trash_sensitive);
    assert(api.list_trash_calls == 0);
}

private void test_refresh_with_items_updates_scope_and_state() {
    var api = new MainControllerFakeApi();
    api.trash_items.add(new HolderLinux.TrashItem("card", "c1", "Card 1", 1700000000));
    api.trash_items.add(new HolderLinux.TrashItem("ai_message", "m1", "assistant: m1", 1700000001));

    var controller = new HolderLinux.TrashController();
    controller.set_api_client(api);
    controller.set_project_selection(project_selection_with_one());

    assert(wait_for_condition(() => api.list_trash_calls > 0));
    assert(wait_for_condition(() => controller.items_store.get_n_items() == 2));
    assert(controller.scope_text == "Projects / Project 1 / Trash");
    assert(!controller.empty_visible);
    assert(controller.empty_trash_sensitive);
    assert(api.last_trash_project_id == "p1");
    assert(api.last_trash_type == "all");
}

private void test_filter_selection_updates_type_param() {
    var api = new MainControllerFakeApi();
    var controller = new HolderLinux.TrashController();
    controller.set_api_client(api);
    controller.set_project_selection(project_selection_with_one());

    assert(wait_for_condition(() => api.list_trash_calls > 0));

    controller.set_filter_index(1);
    assert(wait_for_condition(() => api.last_trash_type == "card"));

    controller.set_filter_index(2);
    assert(wait_for_condition(() => api.last_trash_type == "ai_message"));
}

private void test_refresh_failure_emits_error_and_empty_state() {
    var api = new MainControllerFakeApi();
    api.fail_list_trash = true;

    var controller = new HolderLinux.TrashController();
    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Trash refresh failed") {
            got_error = true;
        }
    });

    controller.set_api_client(api);
    controller.set_project_selection(project_selection_with_one());

    assert(wait_for_condition(() => got_error));
    assert(controller.empty_visible);
    assert(controller.empty_text == "Failed to load trash.");
    assert(!controller.empty_trash_sensitive);
}

private void test_refresh_with_project_and_no_api_shows_api_unavailable() {
    var controller = new HolderLinux.TrashController();
    controller.set_project_selection(project_selection_with_one());

    assert(wait_for_condition(() => controller.empty_visible));
    assert(controller.scope_text == "Projects / Project 1 / Trash");
    assert(controller.empty_text == "API unavailable.");
    assert(!controller.empty_trash_sensitive);
}

private void test_project_selection_notify_selected_triggers_refresh() {
    var api = new MainControllerFakeApi();
    var controller = new HolderLinux.TrashController();
    var selection = project_selection_with_two();
    controller.set_api_client(api);
    controller.set_project_selection(selection);

    assert(wait_for_condition(() => api.list_trash_calls > 0));
    var before = api.list_trash_calls;
    selection.set_selected(1);
    assert(wait_for_condition(() => api.list_trash_calls > before));
    assert(controller.scope_text == "Projects / Project 2 / Trash");
}

private void test_refresh_stale_serial_success_and_error_paths_no_state_update() {
    var api = new MainControllerFakeApi();
    var controller = new HolderLinux.TrashController();
    controller.set_api_client(api);
    controller.set_project_selection(project_selection_with_one());
    assert(wait_for_condition(() => api.list_trash_calls > 0));

    bool stale_done = false;
    controller.refresh.begin(999, (obj, res) => {
        controller.refresh.end(res);
        stale_done = true;
    });
    assert(wait_for_condition(() => stale_done));

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        got_error = true;
    });
    api.fail_list_trash = true;
    bool stale_error_done = false;
    controller.refresh.begin(999, (obj, res) => {
        controller.refresh.end(res);
        stale_error_done = true;
    });
    assert(wait_for_condition(() => stale_error_done));
    assert(!got_error);
}

private void test_restore_hard_delete_and_empty_actions() {
    var api = new MainControllerFakeApi();
    var controller = new HolderLinux.TrashController();
    controller.set_api_client(api);

    string last_toast = "";
    controller.toast_requested.connect((message) => {
        last_toast = message;
    });

    var item = new HolderLinux.TrashItem("card", "c1", "Card 1", 1700000000);

    bool restore_done = false;
    controller.restore_item.begin(item, (obj, res) => {
        controller.restore_item.end(res);
        restore_done = true;
    });
    assert(wait_for_condition(() => restore_done));
    assert(api.restore_trash_calls == 1);
    assert(api.last_restore_item_type == "card");
    assert(api.last_restore_item_id == "c1");
    assert(last_toast == "Item restored.");

    bool hard_delete_done = false;
    controller.hard_delete_item.begin(item, (obj, res) => {
        controller.hard_delete_item.end(res);
        hard_delete_done = true;
    });
    assert(wait_for_condition(() => hard_delete_done));
    assert(api.hard_delete_trash_calls == 1);
    assert(api.last_hard_delete_item_type == "card");
    assert(api.last_hard_delete_item_id == "c1");
    assert(last_toast == "Item permanently deleted.");

    bool empty_done = false;
    controller.empty_trash.begin("p1", (obj, res) => {
        controller.empty_trash.end(res);
        empty_done = true;
    });
    assert(wait_for_condition(() => empty_done));
    assert(api.empty_trash_calls == 1);
    assert(api.last_trash_project_id == "p1");
    assert(api.last_trash_type == "all");
    assert(last_toast == "Trash emptied.");
}

private void test_actions_with_no_api_are_noops() {
    var api = new MainControllerFakeApi();
    var controller = new HolderLinux.TrashController();
    var item = new HolderLinux.TrashItem("card", "c1", "Card 1", 1700000000);

    bool restore_done = false;
    controller.restore_item.begin(item, (obj, res) => {
        controller.restore_item.end(res);
        restore_done = true;
    });
    assert(wait_for_condition(() => restore_done));
    assert(api.restore_trash_calls == 0);

    bool hard_delete_done = false;
    controller.hard_delete_item.begin(item, (obj, res) => {
        controller.hard_delete_item.end(res);
        hard_delete_done = true;
    });
    assert(wait_for_condition(() => hard_delete_done));
    assert(api.hard_delete_trash_calls == 0);

    bool empty_done = false;
    controller.empty_trash.begin("p1", (obj, res) => {
        controller.empty_trash.end(res);
        empty_done = true;
    });
    assert(wait_for_condition(() => empty_done));
    assert(api.empty_trash_calls == 0);
}

private void test_action_failures_emit_errors() {
    var api = new MainControllerFakeApi();
    api.fail_restore_trash = true;
    api.fail_hard_delete_trash = true;
    api.fail_empty_trash = true;
    var controller = new HolderLinux.TrashController();
    controller.set_api_client(api);
    var item = new HolderLinux.TrashItem("card", "c1", "Card 1", 1700000000);

    bool got_restore_error = false;
    bool got_hard_delete_error = false;
    bool got_empty_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to restore item") {
            got_restore_error = true;
        }
        if (title == "Failed to permanently delete item") {
            got_hard_delete_error = true;
        }
        if (title == "Failed to empty trash") {
            got_empty_error = true;
        }
    });

    bool restore_done = false;
    controller.restore_item.begin(item, (obj, res) => {
        controller.restore_item.end(res);
        restore_done = true;
    });
    assert(wait_for_condition(() => restore_done && got_restore_error));

    bool hard_delete_done = false;
    controller.hard_delete_item.begin(item, (obj, res) => {
        controller.hard_delete_item.end(res);
        hard_delete_done = true;
    });
    assert(wait_for_condition(() => hard_delete_done && got_hard_delete_error));

    bool empty_done = false;
    controller.empty_trash.begin("p1", (obj, res) => {
        controller.empty_trash.end(res);
        empty_done = true;
    });
    assert(wait_for_condition(() => empty_done && got_empty_error));
}

private void test_helpers_pretty_type_and_format_epoch() {
    var controller = new HolderLinux.TrashController();
    assert(controller.pretty_type("card") == "Card");
    assert(controller.pretty_type("ai_message") == "AI message");
    assert(controller.pretty_type("other") == "other");

    assert(controller.format_epoch(0) == "");
    assert(controller.format_epoch(1700000000).length > 0);
}

private void test_confirmation_dialog_copy_helpers() {
    var controller = new HolderLinux.TrashController();
    var item = new HolderLinux.TrashItem("card", "c1", "Card 1", 1700000000);
    var project = new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 10, 10);

    assert(controller.hard_delete_dialog_title() == "Delete Permanently");
    assert(controller.hard_delete_dialog_body(item) == "Permanently delete \"Card 1\"?");
    assert(controller.empty_trash_dialog_title() == "Empty Trash");
    assert(controller.empty_trash_dialog_body(project) ==
           "Permanently delete all trash items in Project 1?");
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/holder/trash-controller/no-project", test_refresh_without_project_shows_select_message);
    Test.add_func("/holder/trash-controller/refresh-with-items", test_refresh_with_items_updates_scope_and_state);
    Test.add_func("/holder/trash-controller/filter-type-param", test_filter_selection_updates_type_param);
    Test.add_func("/holder/trash-controller/refresh-failure", test_refresh_failure_emits_error_and_empty_state);
    Test.add_func("/holder/trash-controller/refresh-no-api", test_refresh_with_project_and_no_api_shows_api_unavailable);
    Test.add_func("/holder/trash-controller/selection-notify-refresh", test_project_selection_notify_selected_triggers_refresh);
    Test.add_func("/holder/trash-controller/stale-serial-success-and-error", test_refresh_stale_serial_success_and_error_paths_no_state_update);
    Test.add_func("/holder/trash-controller/actions", test_restore_hard_delete_and_empty_actions);
    Test.add_func("/holder/trash-controller/actions-no-api", test_actions_with_no_api_are_noops);
    Test.add_func("/holder/trash-controller/action-failures-emit-errors", test_action_failures_emit_errors);
    Test.add_func("/holder/trash-controller/helpers", test_helpers_pretty_type_and_format_epoch);
    Test.add_func("/holder/trash-controller/confirmation-copy-helpers",
                  test_confirmation_dialog_copy_helpers);
    return Test.run();
}

}
