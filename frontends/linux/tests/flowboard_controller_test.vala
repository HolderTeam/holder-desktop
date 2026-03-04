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

    return Test.run();
}

}
