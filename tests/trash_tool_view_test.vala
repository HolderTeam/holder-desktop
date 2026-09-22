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

// ---- harness for driving the view's widgets -----------------------------------------------------

private void tv_settle() {
    var context = MainContext.default();
    for (int i = 0; i < 20; i++) {
        while (context.iteration(false)) {}
    }
}

private void tv_collect(Gtk.Widget root, Gee.ArrayList<Gtk.Widget> out_widgets) {
    out_widgets.add(root);
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        tv_collect((!) child, out_widgets);
    }
}

private Gee.ArrayList<Gtk.Widget> tv_descendants(Gtk.Widget root) {
    var widgets = new Gee.ArrayList<Gtk.Widget>();
    tv_collect(root, widgets);
    return widgets;
}

private Gee.ArrayList<Gtk.Button> tv_buttons_labeled(Gtk.Widget root, string label) {
    var buttons = new Gee.ArrayList<Gtk.Button>();
    foreach (var widget in tv_descendants(root)) {
        var button = widget as Gtk.Button;
        if (button != null && ((!) button).get_label() == label) {
            buttons.add((!) button);
        }
    }
    return buttons;
}

private Gtk.Button tv_button(Gtk.Widget root, string label, int index = 0) {
    var buttons = tv_buttons_labeled(root, label);
    assert(index < buttons.size);
    return buttons[index];
}

private Gee.ArrayList<string> tv_label_texts(Gtk.Widget root) {
    var texts = new Gee.ArrayList<string>();
    foreach (var widget in tv_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label != null) {
            texts.add(((!) label).get_text());
        }
    }
    return texts;
}

// list_trash_items that can be held back so a test can act while a project's list is still loading.
private class TrashStallApi : MainControllerFakeApi {
    public string? stall_project = null;
    private SourceFunc? stalled = null;

    public override async Gee.ArrayList<HolderLinux.TrashItem> list_trash_items(string project_id,
                                                                                 string type = "all") throws Error {
        if (stall_project != null && stall_project == project_id) {
            stalled = list_trash_items.callback;
            yield;
        }
        return yield base.list_trash_items(project_id, type);
    }

    public bool has_stalled_list() {
        return stalled != null;
    }

    public void release_stalled_list() {
        stall_project = null;
        SourceFunc? callback = (owned) stalled;
        stalled = null;
        if (callback != null) {
            Idle.add((owned) callback);
        }
    }
}

private class TrashViewHarness : Object {
    public TrashStallApi api = new TrashStallApi();
    public HolderLinux.TrashToolView view = new HolderLinux.TrashToolView();
    public Adw.Window window = new Adw.Window();
    public GLib.ListStore projects = new GLib.ListStore(typeof(HolderLinux.Project));
    public Gtk.SingleSelection selection;
    public Gee.ArrayList<string> toasts = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> errors = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> activities = new Gee.ArrayList<string>();
    public int event_count { get; set; default = 0; }

    public TrashViewHarness(bool with_project = true, bool attach_window = true) {
        projects.append(new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 10, 10));
        projects.append(new HolderLinux.Project("p2", "Project 2", "encrypted_git", "/tmp/p2", 10, 10));
        selection = new Gtk.SingleSelection(projects);
        view.toast_requested.connect((message) => { toasts.add(message); event_count++; });
        view.error_reported.connect((title, details) => { errors.add("%s|%s".printf(title, details)); event_count++; });
        view.activity_requested.connect((kind, message, project_id, card_id, details) => {
            activities.add("%s|%s|%s|%s".printf(kind, message, project_id ?? "-", card_id ?? "-"));
            event_count++;
        });
        if (attach_window) {
            window.set_content(view.widget);
        }
        view.set_api_client(api);
        if (with_project) {
            selection.set_selected(0);
            view.set_project_selection(selection);
        }
    }

    public void add_item(string item_type, string item_id, string title, int64 deleted_at = 1700000000) {
        api.trash_items.add(new HolderLinux.TrashItem(item_type, item_id, title, deleted_at));
    }

    public bool wait_for_items(uint count) {
        return wait_for_condition(() => trash_item_count(view) == count);
    }

    public Adw.AlertDialog? dialog() {
        return window.get_visible_dialog() as Adw.AlertDialog;
    }

    public bool wait_for_dialog() {
        return wait_for_condition(() => dialog() != null);
    }

    public Gtk.Widget actions() {
        var actions = view.get_actions_widget();
        assert(actions != null);
        return (!) actions;
    }

    // The Restore/Delete/... button in the nth listed row.
    public Gtk.Button row_button(string label, int index = 0) {
        return tv_button(view.widget, label, index);
    }

    // Runs the main loop until idle, flushing anything a response queued.
    public void settle() {
        tv_settle();
    }
}

private Gtk.SingleSelection tv_unselected_projects() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    store.append(new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 10, 10));
    var selection = new Gtk.SingleSelection(store);
    selection.set_autoselect(false);
    selection.set_can_unselect(true);
    selection.unselect_item(selection.get_selected());
    assert(selection.get_selected() == Gtk.INVALID_LIST_POSITION);
    return selection;
}

// ---- rows ---------------------------------------------------------------------------------------

private void test_rows_show_the_type_title_and_deletion_time() {
    var h = new TrashViewHarness();
    h.add_item("card", "c1", "Card 1", 1700000000);
    h.add_item("ai_message", "m1", "assistant: hello", 1700000100);
    h.add_item("widget", "w1", "Odd one", 0);
    h.view.refresh();
    assert(h.wait_for_items(3));
    h.settle();

    var texts = tv_label_texts(h.view.widget);
    assert(texts.contains("Card"));
    assert(texts.contains("AI message"));
    // An unknown type is shown as it is.
    assert(texts.contains("widget"));
    assert(texts.contains("Card 1") && texts.contains("assistant: hello") && texts.contains("Odd one"));
    var expected = new DateTime.from_unix_local(1700000000).format("%Y-%m-%d %H:%M");
    assert(texts.contains(expected));
    // Precondition: three rows really rendered their action buttons.
    assert(tv_buttons_labeled(h.view.widget, "Restore").size == 3);
    assert(tv_buttons_labeled(h.view.widget, "Delete").size == 3);
}

private void test_row_tooltips_carry_the_full_title_and_the_raw_timestamp() {
    var h = new TrashViewHarness();
    h.add_item("card", "c1", "A rather long card title", 1700000000);
    h.view.refresh();
    assert(h.wait_for_items(1));
    h.settle();

    bool title_tip = false;
    bool time_tip = false;
    foreach (var widget in tv_descendants(h.view.widget)) {
        if (widget is Gtk.Label) {
            var tip = widget.get_tooltip_text();
            if (tip == "A rather long card title") {
                title_tip = true;
            }
            if (tip == "1700000000") {
                time_tip = true;
            }
        }
    }
    assert(title_tip && time_tip);
}

// ---- actions through the buttons -----------------------------------------------------------------

private void test_the_restore_button_restores_that_row_and_reports_it() {
    var h = new TrashViewHarness();
    h.add_item("card", "c1", "Card 1");
    h.add_item("ai_message", "m1", "assistant: hello");
    h.view.refresh();
    assert(h.wait_for_items(2));
    h.settle();

    h.row_button("Restore", 1).clicked();

    assert(wait_for_condition(() => h.api.restore_trash_calls == 1));
    assert(h.api.last_restore_item_type == "ai_message");
    assert(h.api.last_restore_item_id == "m1");
    assert(wait_for_condition(() => h.toasts.contains("Item restored.")));
    assert(h.activities.contains("result.trash.restore|Restored ai_message: assistant: hello|p1|m1"));
    // The list is reloaded afterwards.
    assert(wait_for_condition(() => h.api.list_trash_calls >= 3));
}

private void test_the_delete_button_asks_first_and_cancel_deletes_nothing() {
    var h = new TrashViewHarness();
    h.add_item("card", "c1", "Card 1");
    h.view.refresh();
    assert(h.wait_for_items(1));
    h.settle();

    h.row_button("Delete").clicked();

    assert(h.wait_for_dialog());
    var dialog = (!) h.dialog();
    assert(dialog.get_heading() == "Delete Permanently");
    assert(dialog.get_body() == "Permanently delete \"Card 1\"?");
    tv_button(dialog, "Cancel").clicked();
    h.settle();
    assert(h.api.hard_delete_trash_calls == 0);
    assert(h.toasts.size == 0);
}

private void test_confirming_the_delete_dialog_deletes_that_item_for_good() {
    var h = new TrashViewHarness();
    h.add_item("card", "c1", "Card 1");
    h.add_item("card", "c2", "Card 2");
    h.view.refresh();
    assert(h.wait_for_items(2));
    h.settle();

    h.row_button("Delete", 1).clicked();
    assert(h.wait_for_dialog());
    tv_button((!) h.dialog(), "Delete").clicked();

    assert(wait_for_condition(() => h.api.hard_delete_trash_calls == 1));
    assert(h.api.last_hard_delete_item_type == "card");
    assert(h.api.last_hard_delete_item_id == "c2");
    assert(wait_for_condition(() => h.toasts.contains("Item permanently deleted.")));
    assert(h.activities.contains("result.trash.delete|Permanently deleted card: Card 2|p1|c2"));
}

private void test_empty_trash_names_the_project_and_cancel_empties_nothing() {
    var h = new TrashViewHarness();
    h.add_item("card", "c1", "Card 1");
    h.view.refresh();
    assert(h.wait_for_items(1));
    var empty_button = tv_button(h.actions(), "Empty Trash");
    assert(empty_button.get_sensitive());

    empty_button.clicked();

    assert(h.wait_for_dialog());
    var dialog = (!) h.dialog();
    assert(dialog.get_heading() == "Empty Trash");
    assert(dialog.get_body() == "Permanently delete all trash items in Project 1?");
    tv_button(dialog, "Cancel").clicked();
    h.settle();
    assert(h.api.empty_trash_calls == 0);
    assert(h.toasts.size == 0);
}

private void test_confirming_empty_trash_empties_the_selected_project() {
    var h = new TrashViewHarness();
    h.add_item("card", "c1", "Card 1");
    h.view.refresh();
    assert(h.wait_for_items(1));

    tv_button(h.actions(), "Empty Trash").clicked();
    assert(h.wait_for_dialog());
    // The dialog's own button is the one that confirms (the toolbar button has the same label).
    tv_button((!) h.dialog(), "Empty Trash").clicked();

    assert(wait_for_condition(() => h.api.empty_trash_calls == 1));
    assert(h.api.last_trash_project_id == "p1");
    assert(h.api.last_trash_type == "all");
    assert(wait_for_condition(() => h.toasts.contains("Trash emptied.")));
    assert(h.activities.contains("result.trash.empty|Emptied trash|p1|-"));
}

private void test_the_refresh_button_and_navigation_reload_the_list() {
    var h = new TrashViewHarness();
    assert(wait_for_condition(() => h.api.list_trash_calls >= 1));
    var before = h.api.list_trash_calls;

    var refresh = h.actions();
    Gtk.Button? refresh_button = null;
    foreach (var widget in tv_descendants(refresh)) {
        if (widget is Gtk.Button && widget.get_tooltip_text() == "Refresh trash") {
            refresh_button = (Gtk.Button) widget;
        }
    }
    assert(refresh_button != null);
    ((!) refresh_button).clicked();
    assert(h.api.list_trash_calls == before + 1);

    bool done = false;
    h.view.navigate_to_projects_root.begin(null, (obj, res) => {
        assert(h.view.navigate_to_projects_root.end(res));
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(h.api.list_trash_calls == before + 2);

    done = false;
    h.view.navigate_to_project_root.begin("p1", (obj, res) => {
        assert(h.view.navigate_to_project_root.end(res));
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(h.api.list_trash_calls == before + 3);

    done = false;
    h.view.navigate_to_card.begin("c1", (obj, res) => {
        assert(h.view.navigate_to_card.end(res));
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(h.api.list_trash_calls == before + 4);
    assert(h.view.tool_id == "trash" && h.view.tool_label == "Trash");
    assert(h.view.get_content_widget() == h.view.widget);
}

// ---- guards ---------------------------------------------------------------------------------------

private void test_destructive_actions_do_nothing_when_the_view_has_no_window() {
    // Never attached to a window, so the view has no root to put a dialog on.
    var h = new TrashViewHarness(true, false);
    h.add_item("card", "c1", "Card 1");
    h.view.refresh();
    assert(wait_for_condition(() => trash_item_count(h.view) == 1));
    assert(h.view.widget.get_root() == null);
    // Precondition: Empty Trash is enabled, so the only thing stopping it is the missing window.
    assert(tv_button(h.actions(), "Empty Trash").get_sensitive());
    var item = new HolderLinux.TrashItem("card", "c1", "Card 1", 1700000000);

    h.view.confirm_hard_delete(item);
    h.view.confirm_empty_trash();
    h.settle();

    assert(h.dialog() == null);
    assert(h.api.hard_delete_trash_calls == 0 && h.api.empty_trash_calls == 0);
    assert(h.event_count == 0);
}

private void test_empty_trash_without_a_selected_project_opens_nothing() {
    var h = new TrashViewHarness(false);
    h.view.set_project_selection(tv_unselected_projects());
    h.settle();
    var empty_button = tv_button(h.actions(), "Empty Trash");
    assert(!empty_button.get_sensitive());

    // A disabled button cannot be pressed, but the signal still must not open a dialog.
    empty_button.clicked();
    h.settle();

    assert(h.dialog() == null);
    assert(h.api.empty_trash_calls == 0);
}

private void test_actions_without_an_api_do_nothing_and_say_nothing() {
    var h = new TrashViewHarness();
    h.view.set_api_client(null);
    h.settle();
    var item = new HolderLinux.TrashItem("card", "c1", "Card 1", 1700000000);
    int finished = 0;

    h.view.restore_item.begin(item, (obj, res) => { h.view.restore_item.end(res); finished++; });
    h.view.hard_delete_item.begin(item, (obj, res) => { h.view.hard_delete_item.end(res); finished++; });
    h.view.empty_trash.begin("p1", (obj, res) => { h.view.empty_trash.end(res); finished++; });

    assert(wait_for_condition(() => finished == 3));
    assert(h.api.restore_trash_calls == 0 && h.api.hard_delete_trash_calls == 0 && h.api.empty_trash_calls == 0);
    assert(h.event_count == 0);
}

private void test_failed_actions_are_reported_and_logged() {
    var h = new TrashViewHarness();
    h.view.set_project_selection(tv_unselected_projects());
    h.settle();
    h.api.fail_restore_trash = true;
    h.api.fail_hard_delete_trash = true;
    h.api.fail_empty_trash = true;
    var item = new HolderLinux.TrashItem("card", "c1", "Card 1", 1700000000);
    int finished = 0;

    h.view.restore_item.begin(item, (obj, res) => { h.view.restore_item.end(res); finished++; });
    h.view.hard_delete_item.begin(item, (obj, res) => { h.view.hard_delete_item.end(res); finished++; });
    h.view.empty_trash.begin("p1", (obj, res) => { h.view.empty_trash.end(res); finished++; });

    assert(wait_for_condition(() => finished == 3));
    assert(h.errors.contains("Failed to restore item|restore trash failed"));
    assert(h.errors.contains("Failed to permanently delete item|hard delete trash failed"));
    assert(h.errors.contains("Failed to empty trash|empty trash failed"));
    // With no project selected and no list loaded there is no project to log the item against.
    assert(h.activities.contains("result.trash.restore_failed|Failed to restore card: restore trash failed|-|c1"));
    assert(h.activities.contains("result.trash.delete_failed|Failed to permanently delete card: hard delete trash failed|-|c1"));
    assert(h.activities.contains("result.trash.empty_failed|Failed to empty trash: empty trash failed|p1|-"));
    assert(h.toasts.size == 0);
}

// ---- regressions ---------------------------------------------------------------------------------

private void test_replacing_the_project_selection_stops_listening_to_the_old_one() {
    var h = new TrashViewHarness();
    assert(wait_for_condition(() => h.api.list_trash_calls >= 1));
    var replacement = new Gtk.SingleSelection(h.projects);
    replacement.set_selected(0);
    h.view.set_project_selection(replacement);
    h.settle();
    var before = h.api.list_trash_calls;

    // The first selection is no longer the view's, so moving it must not reload anything.
    h.selection.set_selected(1);
    h.settle();
    assert(h.api.list_trash_calls == before);

    // The current one still does, exactly once per change.
    replacement.set_selected(1);
    assert(h.api.list_trash_calls == before + 1);
}

private void test_setting_the_same_selection_twice_does_not_double_the_reloads() {
    var h = new TrashViewHarness();
    h.view.set_project_selection(h.selection);
    h.view.set_project_selection(h.selection);
    h.settle();
    var before = h.api.list_trash_calls;

    h.selection.set_selected(1);

    // Each extra bind used to leave another handler behind, so one change reloaded several times.
    assert(h.api.list_trash_calls == before + 1);
}

private void test_the_list_is_cleared_when_the_project_is_deselected() {
    var h = new TrashViewHarness();
    h.add_item("card", "c1", "Card 1");
    h.view.refresh();
    assert(h.wait_for_items(1));

    h.view.set_project_selection(tv_unselected_projects());

    assert(wait_for_condition(() => h.wait_for_items(0)));
    assert(tv_label_texts(h.view.widget).contains("Select a project to view trash."));
    // The old project's rows must not stay behind with live Restore/Delete buttons.
    h.settle();
    assert(tv_buttons_labeled(h.view.widget, "Restore").size == 0);
    assert(!tv_button(h.actions(), "Empty Trash").get_sensitive());
}

private void test_the_list_is_cleared_when_the_api_goes_away() {
    var h = new TrashViewHarness();
    h.add_item("card", "c1", "Card 1");
    h.view.refresh();
    assert(h.wait_for_items(1));

    h.view.set_api_client(null);

    assert(wait_for_condition(() => h.wait_for_items(0)));
    assert(tv_label_texts(h.view.widget).contains("API unavailable."));
    assert(!tv_button(h.actions(), "Empty Trash").get_sensitive());
}

private void test_a_failed_list_for_another_project_does_not_keep_the_previous_projects_items() {
    var h = new TrashViewHarness();
    h.add_item("card", "c1", "Card 1");
    h.view.refresh();
    assert(h.wait_for_items(1));

    h.api.fail_list_trash = true;
    h.selection.set_selected(1);

    assert(wait_for_condition(() => h.errors.contains("Trash refresh failed|list trash failed")));
    // Project 1's items used to stay on screen with Project 2's name and Empty Trash still enabled.
    assert(h.wait_for_items(0));
    assert(tv_label_texts(h.view.widget).contains("Failed to load trash."));
    assert(!tv_button(h.actions(), "Empty Trash").get_sensitive());
}

private void test_a_failed_reload_of_the_same_project_keeps_what_is_already_shown() {
    var h = new TrashViewHarness();
    h.add_item("card", "c1", "Card 1");
    h.view.refresh();
    assert(h.wait_for_items(1));

    h.api.fail_list_trash = true;
    h.view.refresh();

    assert(wait_for_condition(() => h.errors.contains("Trash refresh failed|list trash failed")));
    h.settle();
    assert(trash_item_count(h.view) == 1);
    assert(tv_button(h.actions(), "Empty Trash").get_sensitive());
}

private void test_restoring_after_the_selection_moved_is_filed_under_the_projects_own_list() {
    var h = new TrashViewHarness();
    h.add_item("card", "c1", "Card 1");
    h.view.refresh();
    assert(h.wait_for_items(1));
    h.settle();

    // Project 2's list is still loading, so the rows on screen are Project 1's.
    h.api.stall_project = "p2";
    h.selection.set_selected(1);
    assert(wait_for_condition(() => h.api.has_stalled_list()));
    assert(trash_item_count(h.view) == 1);

    h.row_button("Restore").clicked();

    assert(wait_for_condition(() => h.api.restore_trash_calls == 1));
    assert(wait_for_condition(() => h.activities.size == 1));
    // It used to be logged against Project 2, which was merely selected by then.
    assert(h.activities[0] == "result.trash.restore|Restored card: Card 1|p1|c1");
    h.api.release_stalled_list();
    assert(wait_for_condition(() => !h.api.has_stalled_list()));
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
    Test.add_func("/holder/trash-view/rows", test_rows_show_the_type_title_and_deletion_time);
    Test.add_func("/holder/trash-view/row-tooltips", test_row_tooltips_carry_the_full_title_and_the_raw_timestamp);
    Test.add_func("/holder/trash-view/restore-button", test_the_restore_button_restores_that_row_and_reports_it);
    Test.add_func("/holder/trash-view/delete-cancel", test_the_delete_button_asks_first_and_cancel_deletes_nothing);
    Test.add_func("/holder/trash-view/delete-confirm", test_confirming_the_delete_dialog_deletes_that_item_for_good);
    Test.add_func("/holder/trash-view/empty-cancel", test_empty_trash_names_the_project_and_cancel_empties_nothing);
    Test.add_func("/holder/trash-view/empty-confirm", test_confirming_empty_trash_empties_the_selected_project);
    Test.add_func("/holder/trash-view/refresh-and-navigation", test_the_refresh_button_and_navigation_reload_the_list);
    Test.add_func("/holder/trash-view/no-window", test_destructive_actions_do_nothing_when_the_view_has_no_window);
    Test.add_func("/holder/trash-view/empty-no-project", test_empty_trash_without_a_selected_project_opens_nothing);
    Test.add_func("/holder/trash-view/no-api-actions", test_actions_without_an_api_do_nothing_and_say_nothing);
    Test.add_func("/holder/trash-view/failed-actions", test_failed_actions_are_reported_and_logged);
    Test.add_func("/holder/trash-view/selection-handler-replaced", test_replacing_the_project_selection_stops_listening_to_the_old_one);
    Test.add_func("/holder/trash-view/selection-set-twice", test_setting_the_same_selection_twice_does_not_double_the_reloads);
    Test.add_func("/holder/trash-view/cleared-on-deselect", test_the_list_is_cleared_when_the_project_is_deselected);
    Test.add_func("/holder/trash-view/cleared-without-api", test_the_list_is_cleared_when_the_api_goes_away);
    Test.add_func("/holder/trash-view/failed-list-other-project", test_a_failed_list_for_another_project_does_not_keep_the_previous_projects_items);
    Test.add_func("/holder/trash-view/failed-reload-same-project", test_a_failed_reload_of_the_same_project_keeps_what_is_already_shown);
    Test.add_func("/holder/trash-view/restore-after-selection-moved", test_restoring_after_the_selection_moved_is_filed_under_the_projects_own_list);
    return Test.run();
}

}
