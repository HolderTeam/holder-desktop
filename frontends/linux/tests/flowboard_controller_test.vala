using GLib;

namespace HolderLinuxTests {

private HolderLinux.Project make_project(string id, string name, int64 updated_at = 0) {
    return new HolderLinux.Project(id, name, "encrypted_git", "/tmp/%s".printf(id), 0, updated_at);
}

private HolderLinux.CardSummary make_card(string id,
                                          string project_id,
                                          string title,
                                          double sort_key,
                                          string? parent_id = null,
                                          int64 updated_at = 0) {
    return new HolderLinux.CardSummary(id, project_id, title, "%s.md".printf(id), sort_key, parent_id, 0, updated_at);
}

private HolderLinux.FlowboardController make_controller(out GLib.ListStore project_store,
                                                        out Gtk.SingleSelection project_selection,
                                                        out GLib.ListStore card_store) {
    project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    project_selection = new Gtk.SingleSelection(project_store);
    card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    return new HolderLinux.FlowboardController(project_store, project_selection, card_store);
}

private HolderLinux.FlowboardTile? tile_at(GLib.ListModel model, uint index) {
    return model.get_item(index) as HolderLinux.FlowboardTile;
}

private void test_refresh_without_selected_project_shows_empty_state() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    string last_empty = "";
    controller.empty_message_changed.connect((text) => {
        last_empty = text;
    });

    controller.refresh();

    assert(last_empty == "Select a project to browse cards.");
    assert(controller.get_visible_model().get_n_items() == 0);
}

private void test_refresh_selected_project_sorts_root_cards_by_sort_key() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("c2", "p1", "Second", 2048.0, null, 2));
    card_store.append(make_card("c1", "p1", "First", 1024.0, null, 1));
    card_store.append(make_card("c1a", "p1", "Child", 1024.0, "c1", 3));

    controller.refresh();

    var model = controller.get_visible_model();
    assert(model.get_n_items() == 2);
    var first = tile_at(model, 0);
    var second = tile_at(model, 1);
    assert(first != null && second != null);
    assert(first.card_id == "c1");
    assert(first.is_container);
    assert(first.child_count == 1);
    assert(second.card_id == "c2");
    assert(!second.is_container);
}

private void test_activate_container_enters_it_and_backspace_returns() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("parent", "p1", "Parent", 1024.0));
    card_store.append(make_card("child", "p1", "Child", 1024.0, "parent"));

    string opened = "";
    controller.card_open_requested.connect((card_id) => {
        opened = card_id;
    });

    controller.refresh();
    controller.activate_position(0);

    assert(opened == "parent");
    assert(controller.get_visible_model().get_n_items() == 1);
    var child_tile = tile_at(controller.get_visible_model(), 0);
    assert(child_tile != null);
    assert(child_tile.card_id == "child");

    controller.navigate_up();
    assert(controller.get_visible_model().get_n_items() == 1);
    var root_tile = tile_at(controller.get_visible_model(), 0);
    assert(root_tile != null);
    assert(root_tile.card_id == "parent");
}

private void test_drop_center_nests_and_emits_move_and_toast() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "Alpha", 1024.0));
    card_store.append(make_card("b", "p1", "Beta", 2048.0));

    string moved_card = "";
    string? moved_parent = "__unset__";
    double moved_sort = 0.0;
    string toast = "";
    controller.move_requested.connect((card_id, parent_id, sort_key) => {
        moved_card = card_id;
        moved_parent = parent_id;
        moved_sort = sort_key;
    });
    controller.toast_requested.connect((text) => {
        toast = text;
    });

    controller.refresh();
    controller.on_card_drop("a", "b", 0.5);

    assert(moved_card == "a");
    assert(moved_parent == "b");
    assert(moved_sort >= 1024.0);
    assert(toast.contains("Moved \"Alpha\" into \"Beta\""));
}

private void test_drop_right_edge_reorders_next_to_target() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "Alpha", 1024.0));
    card_store.append(make_card("b", "p1", "Beta", 2048.0));
    card_store.append(make_card("c", "p1", "Gamma", 3072.0));

    double moved_sort = 0.0;
    controller.move_requested.connect((card_id, parent_id, sort_key) => {
        if (card_id == "a") {
            moved_sort = sort_key;
        }
    });

    controller.refresh();
    controller.on_card_drop("a", "b", 0.9);

    assert(moved_sort > 2048.0);
    assert(moved_sort < 3072.0);
}

private void test_move_card_up_level_uses_grandparent_and_toast() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("root", "p1", "Root", 1024.0));
    card_store.append(make_card("parent", "p1", "Parent", 1024.0, "root"));
    card_store.append(make_card("child", "p1", "Child", 1024.0, "parent"));

    string? moved_parent = "__unset__";
    string toast = "";
    controller.move_requested.connect((card_id, parent_id, sort_key) => {
        if (card_id == "child") {
            moved_parent = parent_id;
        }
    });
    controller.toast_requested.connect((text) => {
        toast = text;
    });

    controller.refresh();
    controller.move_card_up_level_from_context_menu("child");

    assert(moved_parent == "root");
    assert(toast == "Moved Child into Root");
}

private void test_navigate_to_projects_mode_shows_project_tiles_sorted() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Alpha", 10));
    project_store.append(make_project("p2", "Beta", 20));
    project_selection.set_selected(0);
    card_store.append(make_card("c1", "p1", "A Root", 1024.0));
    card_store.append(make_card("c2", "p2", "B Root", 1024.0));
    card_store.append(make_card("c3", "p2", "B Child", 1024.0, "c2"));

    controller.refresh();
    controller.navigate_to_breadcrumb_index(0);

    var model = controller.get_visible_model();
    assert(model.get_n_items() == 2);
    var first = tile_at(model, 0);
    var second = tile_at(model, 1);
    assert(first != null && second != null);
    assert(first.project_id == "p2");
    assert(first.child_count == 1);
    assert(second.project_id == "p1");
    assert(second.child_count == 1);
}

private void test_activate_project_tile_selects_and_requests_overview() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Alpha", 10));
    project_store.append(make_project("p2", "Beta", 20));
    project_selection.set_selected(0);
    card_store.append(make_card("c1", "p1", "A Root", 1024.0));
    card_store.append(make_card("c2", "p2", "B Root", 1024.0));

    string requested_project_id = "";
    controller.project_overview_requested.connect((project_id) => {
        requested_project_id = project_id;
    });

    controller.refresh();
    controller.navigate_to_breadcrumb_index(0);
    controller.activate_position(0);

    assert(requested_project_id == "p2");
    var selected = project_selection.get_selected_item() as HolderLinux.Project;
    assert(selected != null);
    assert(selected.project_id == "p2");
}

private void test_request_create_card_here_emits_and_honors_guards() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("parent", "p1", "Parent", 1024.0));
    card_store.append(make_card("child", "p1", "Child", 1024.0, "parent"));

    int creates = 0;
    string? last_parent = "__unset__";
    controller.create_card_requested.connect((parent_id) => {
        creates++;
        last_parent = parent_id;
    });

    controller.refresh();
    controller.request_create_card_here();
    assert(creates == 1);
    assert(last_parent == null);

    controller.activate_position(0);
    controller.request_create_card_here();
    assert(creates == 2);
    assert(last_parent == "parent");

    controller.navigate_to_breadcrumb_index(0);
    controller.request_create_card_here();
    assert(creates == 2);
}

private void test_on_background_drop_moves_card_to_project_root() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "Alpha", 1024.0));
    card_store.append(make_card("p", "p1", "Parent", 2048.0));
    card_store.append(make_card("c", "p1", "Child", 1024.0, "p"));

    string moved_card = "";
    string? moved_parent = "__unset__";
    double moved_sort = 0;
    controller.move_requested.connect((card_id, parent_id, sort_key) => {
        moved_card = card_id;
        moved_parent = parent_id;
        moved_sort = sort_key;
    });

    controller.refresh();
    controller.on_background_drop("c");

    assert(moved_card == "c");
    assert(moved_parent == null);
    assert(moved_sort > 2048.0);
}

private void test_on_card_drop_prevents_descendant_cycle() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("p", "p1", "Parent", 1024.0));
    card_store.append(make_card("c", "p1", "Child", 1024.0, "p"));

    int move_emits = 0;
    controller.move_requested.connect((card_id, parent_id, sort_key) => {
        move_emits++;
    });

    controller.refresh();
    controller.on_card_drop("p", "c", 0.5);
    assert(move_emits == 0);
}

private void test_move_card_to_start_and_end_emit_expected_sort() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "Alpha", 1024.0));
    card_store.append(make_card("b", "p1", "Beta", 2048.0));
    card_store.append(make_card("c", "p1", "Gamma", 3072.0));

    double start_sort = 0;
    double end_sort = 0;
    controller.move_requested.connect((card_id, parent_id, sort_key) => {
        if (card_id == "c") {
            start_sort = sort_key;
        }
        if (card_id == "a") {
            end_sort = sort_key;
        }
    });

    controller.refresh();
    controller.move_card_to_start_from_context_menu("c");
    controller.move_card_to_end_from_context_menu("a");

    assert(start_sort < 1024.0);
    assert(end_sort >= 3072.0);
}

private void test_projects_mode_with_no_projects_shows_empty_projects_message() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    string last_empty = "";
    controller.empty_message_changed.connect((text) => {
        last_empty = text;
    });

    controller.navigate_to_breadcrumb_index(0);
    assert(last_empty == "No projects yet. Create one to get started.");
    assert(controller.get_visible_model().get_n_items() == 0);
}

private void test_breadcrumb_index_one_requests_project_overview() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);

    string requested_project_id = "";
    controller.project_overview_requested.connect((project_id) => {
        requested_project_id = project_id;
    });

    controller.navigate_to_breadcrumb_index(1);
    assert(requested_project_id == "p1");
}

private void test_refresh_clears_missing_current_parent() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("parent", "p1", "Parent", 1024.0));
    card_store.append(make_card("child", "p1", "Child", 1024.0, "parent"));
    card_store.append(make_card("other", "p1", "Other", 2048.0));

    string last_empty = "";
    controller.empty_message_changed.connect((text) => {
        last_empty = text;
    });

    controller.refresh();
    controller.activate_position(0);
    card_store.remove(0);
    controller.refresh();

    var model = controller.get_visible_model();
    assert(model.get_n_items() == 1);
    var first = tile_at(model, 0);
    assert(first != null);
    assert(first.card_id == "other");
    assert(last_empty == "Drag card center onto another card to nest. Drag left/right edges to reorder.");
}

private void test_activate_position_out_of_range_is_noop() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("leaf", "p1", "Leaf", 1024.0));

    int opened = 0;
    controller.card_open_requested.connect((card_id) => {
        opened++;
    });

    controller.refresh();
    controller.activate_position(99);
    assert(opened == 0);
}

private void test_open_card_from_context_menu_leaf_opens_without_navigation() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("leaf", "p1", "Leaf", 1024.0));

    string opened = "";
    controller.card_open_requested.connect((card_id) => {
        opened = card_id;
    });

    controller.refresh();
    controller.open_card_from_context_menu("leaf");
    assert(opened == "leaf");
    assert(controller.get_visible_model().get_n_items() == 1);
    var only = tile_at(controller.get_visible_model(), 0);
    assert(only != null && only.card_id == "leaf");
}

private void test_move_left_right_edge_cards_are_noop() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "Alpha", 1024.0));
    card_store.append(make_card("b", "p1", "Beta", 2048.0));
    card_store.append(make_card("c", "p1", "Gamma", 3072.0));

    int move_emits = 0;
    controller.move_requested.connect((card_id, parent_id, sort_key) => {
        move_emits++;
    });

    controller.refresh();
    controller.move_card_left_from_context_menu("a");
    controller.move_card_right_from_context_menu("c");
    assert(move_emits == 0);
}

private void test_on_card_drop_tiny_gap_uses_fallback_increment() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "Alpha", 500.0));
    card_store.append(make_card("b", "p1", "Beta", 1000.0));
    card_store.append(make_card("c", "p1", "Gamma", 1000.00001));

    double moved_sort = 0.0;
    controller.move_requested.connect((card_id, parent_id, sort_key) => {
        if (card_id == "a") {
            moved_sort = sort_key;
        }
    });

    controller.refresh();
    controller.on_card_drop("a", "b", 0.9);
    assert(moved_sort > 1000.00001);
}

private void test_move_up_with_missing_parent_uses_project_destination() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("child", "p1", "Child", 1024.0, "missing-parent"));

    string toast = "";
    controller.toast_requested.connect((text) => {
        toast = text;
    });

    controller.refresh();
    controller.move_card_up_level_from_context_menu("child");
    assert(toast == "Moved Child into Project One");
}

private void test_noop_guards_for_missing_ids_and_self_drop() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "Alpha", 1024.0));

    int move_emits = 0;
    int open_emits = 0;
    controller.move_requested.connect((card_id, parent_id, sort_key) => { move_emits++; });
    controller.card_open_requested.connect((card_id) => { open_emits++; });

    controller.refresh();
    controller.on_card_drop("a", "a", 0.5);
    controller.on_card_drop("missing", "a", 0.5);
    controller.on_card_drop("a", "missing", 0.5);
    controller.on_background_drop("missing");
    controller.open_card_from_context_menu("missing");
    controller.move_card_to_end_from_context_menu("missing");
    controller.move_card_to_start_from_context_menu("missing");
    controller.move_card_left_from_context_menu("missing");
    controller.move_card_right_from_context_menu("missing");
    controller.move_card_up_level_from_context_menu("missing");

    assert(move_emits == 0);
    assert(open_emits == 0);
}

private void test_root_move_up_and_empty_stack_navigation_are_noop() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("root", "p1", "Root", 1024.0));

    int move_emits = 0;
    controller.move_requested.connect((card_id, parent_id, sort_key) => { move_emits++; });

    controller.refresh();
    controller.navigate_up();
    controller.move_card_up_level_from_context_menu("root");
    assert(move_emits == 0);
    assert(controller.get_visible_model().get_n_items() == 1);
}

private void test_move_up_without_selected_project_uses_literal_project_label() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    card_store.append(make_card("child", "p1", "Child", 1024.0, "missing-parent"));

    string toast = "";
    controller.toast_requested.connect((text) => {
        toast = text;
    });

    controller.move_card_up_level_from_context_menu("child");
    assert(toast == "Moved Child into project");
}

private void test_refresh_while_showing_projects_switches_to_new_selected_project() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "One", 10));
    project_store.append(make_project("p2", "Two", 20));
    project_selection.set_selected(0);
    card_store.append(make_card("b1", "p2", "B1", 1024.0));
    string last_empty = "";
    controller.empty_message_changed.connect((text) => {
        last_empty = text;
    });

    controller.refresh();
    controller.navigate_to_breadcrumb_index(0);
    project_selection.set_selected(1);
    controller.refresh();

    var model = controller.get_visible_model();
    assert(model.get_n_items() == 1);
    var only = tile_at(model, 0);
    assert(only != null);
    assert(only.card_id == "b1");
    assert(last_empty == "Drag card center onto another card to nest. Drag left/right edges to reorder.");
}

private void test_breadcrumb_out_of_range_is_noop() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("parent", "p1", "Parent", 1024.0));
    card_store.append(make_card("child", "p1", "Child", 1024.0, "parent"));

    controller.refresh();
    controller.activate_position(0);
    assert(controller.get_visible_model().get_n_items() == 1);

    controller.navigate_to_breadcrumb_index(99);
    assert(controller.get_visible_model().get_n_items() == 1);
    var only = tile_at(controller.get_visible_model(), 0);
    assert(only != null);
    assert(only.card_id == "child");
}

private void test_drop_left_edge_places_before_target() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "Alpha", 1024.0));
    card_store.append(make_card("b", "p1", "Beta", 2048.0));
    card_store.append(make_card("c", "p1", "Gamma", 3072.0));

    double moved_sort = 0.0;
    controller.move_requested.connect((card_id, parent_id, sort_key) => {
        if (card_id == "c") {
            moved_sort = sort_key;
        }
    });

    controller.refresh();
    controller.on_card_drop("c", "b", 0.1);
    assert(moved_sort > 1024.0);
    assert(moved_sort < 2048.0);
}

private void test_move_left_and_right_middle_card_emit_reorder() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "Alpha", 1024.0));
    card_store.append(make_card("b", "p1", "Beta", 2048.0));
    card_store.append(make_card("c", "p1", "Gamma", 3072.0));

    int b_moves = 0;
    controller.move_requested.connect((card_id, parent_id, sort_key) => {
        if (card_id == "b") {
            b_moves++;
        }
    });

    controller.refresh();
    controller.move_card_left_from_context_menu("b");
    controller.move_card_right_from_context_menu("b");
    assert(b_moves == 2);
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/flowboard/refresh_without_selected_project_shows_empty_state",
                  test_refresh_without_selected_project_shows_empty_state);
    Test.add_func("/flowboard/refresh_selected_project_sorts_root_cards_by_sort_key",
                  test_refresh_selected_project_sorts_root_cards_by_sort_key);
    Test.add_func("/flowboard/activate_container_enters_it_and_backspace_returns",
                  test_activate_container_enters_it_and_backspace_returns);
    Test.add_func("/flowboard/drop_center_nests_and_emits_move_and_toast",
                  test_drop_center_nests_and_emits_move_and_toast);
    Test.add_func("/flowboard/drop_right_edge_reorders_next_to_target",
                  test_drop_right_edge_reorders_next_to_target);
    Test.add_func("/flowboard/move_card_up_level_uses_grandparent_and_toast",
                  test_move_card_up_level_uses_grandparent_and_toast);
    Test.add_func("/flowboard/navigate_to_projects_mode_shows_project_tiles_sorted",
                  test_navigate_to_projects_mode_shows_project_tiles_sorted);
    Test.add_func("/flowboard/activate_project_tile_selects_and_requests_overview",
                  test_activate_project_tile_selects_and_requests_overview);
    Test.add_func("/flowboard/request_create_card_here_emits_and_honors_guards",
                  test_request_create_card_here_emits_and_honors_guards);
    Test.add_func("/flowboard/on_background_drop_moves_card_to_project_root",
                  test_on_background_drop_moves_card_to_project_root);
    Test.add_func("/flowboard/on_card_drop_prevents_descendant_cycle",
                  test_on_card_drop_prevents_descendant_cycle);
    Test.add_func("/flowboard/move_card_to_start_and_end_emit_expected_sort",
                  test_move_card_to_start_and_end_emit_expected_sort);
    Test.add_func("/flowboard/projects_mode_with_no_projects_shows_empty_projects_message",
                  test_projects_mode_with_no_projects_shows_empty_projects_message);
    Test.add_func("/flowboard/breadcrumb_index_one_requests_project_overview",
                  test_breadcrumb_index_one_requests_project_overview);
    Test.add_func("/flowboard/refresh_clears_missing_current_parent",
                  test_refresh_clears_missing_current_parent);
    Test.add_func("/flowboard/activate_position_out_of_range_is_noop",
                  test_activate_position_out_of_range_is_noop);
    Test.add_func("/flowboard/open_card_from_context_menu_leaf_opens_without_navigation",
                  test_open_card_from_context_menu_leaf_opens_without_navigation);
    Test.add_func("/flowboard/move_left_right_edge_cards_are_noop",
                  test_move_left_right_edge_cards_are_noop);
    Test.add_func("/flowboard/on_card_drop_tiny_gap_uses_fallback_increment",
                  test_on_card_drop_tiny_gap_uses_fallback_increment);
    Test.add_func("/flowboard/move_up_with_missing_parent_uses_project_destination",
                  test_move_up_with_missing_parent_uses_project_destination);
    Test.add_func("/flowboard/noop_guards_for_missing_ids_and_self_drop",
                  test_noop_guards_for_missing_ids_and_self_drop);
    Test.add_func("/flowboard/root_move_up_and_empty_stack_navigation_are_noop",
                  test_root_move_up_and_empty_stack_navigation_are_noop);
    Test.add_func("/flowboard/move_up_without_selected_project_uses_literal_project_label",
                  test_move_up_without_selected_project_uses_literal_project_label);
    Test.add_func("/flowboard/refresh_while_showing_projects_switches_to_new_selected_project",
                  test_refresh_while_showing_projects_switches_to_new_selected_project);
    Test.add_func("/flowboard/breadcrumb_out_of_range_is_noop",
                  test_breadcrumb_out_of_range_is_noop);
    Test.add_func("/flowboard/drop_left_edge_places_before_target",
                  test_drop_left_edge_places_before_target);
    Test.add_func("/flowboard/move_left_and_right_middle_card_emit_reorder",
                  test_move_left_and_right_middle_card_emit_reorder);

    return Test.run();
}

}
