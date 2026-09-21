using GLib;

namespace HolderLinuxTests {

private HolderLinux.Project ftv_project_at(FlowboardToolViewHarness h, uint position) {
    var project = h.projects.get_item(position) as HolderLinux.Project;
    assert(project != null);
    return (!) project;
}

private HolderLinux.CardSummary ftv_card_at(FlowboardToolViewHarness h, uint position) {
    var card = h.cards.get_item(position) as HolderLinux.CardSummary;
    assert(card != null);
    return (!) card;
}

// Drops `source` onto the tile for `target_card`, `fraction` of the way across it.
private bool ftv_drop(FlowboardToolViewHarness h, string source, string target_card, double fraction) {
    var row = h.row(target_card);
    row.allocate(200, 80, -1, null);
    var width = (double) row.get_width();
    assert(width > 0.0);
    return fv_drop_target(row).drop(fv_string_value(source), width * fraction, 5.0);
}

private Gtk.SelectionModel ftv_selection(FlowboardToolViewHarness h) {
    var model = h.grid().get_model() as Gtk.SelectionModel;
    assert(model != null);
    return (!) model;
}

private uint ftv_visible_count(FlowboardToolViewHarness h) {
    return h.controller.get_visible_model().get_n_items();
}

private void ftv_navigate_to_projects_root(FlowboardToolViewHarness h) {
    bool done = false;
    h.view.navigate_to_projects_root.begin(null, (obj, res) => {
        assert(h.view.navigate_to_projects_root.end(res));
        done = true;
    });
    fv_settle();
    assert(done);
}

private void ftv_navigate_to_project_root(FlowboardToolViewHarness h, string project_id) {
    bool done = false;
    h.view.navigate_to_project_root.begin(project_id, (obj, res) => {
        assert(h.view.navigate_to_project_root.end(res));
        done = true;
    });
    fv_settle();
    assert(done);
}

// ---- identity and an unbound view --------------------------------------------------------------

private void ftv_test_the_tool_identifies_itself() {
    var h = new FlowboardToolViewHarness(false);

    assert(h.view.tool_id == "flowboard");
    assert(h.view.tool_label == "Flowboard");
    assert(h.view.get_content_widget() == h.view.widget);
    assert(h.view.get_actions_widget() == null);
}

private void ftv_test_an_unbound_view_ignores_navigation_and_keeps_the_selected_card() {
    var h = new FlowboardToolViewHarness(false);

    h.view.show_projects_root();
    h.view.show_project_root();
    h.view.request_create_card_here();

    assert(h.events.size == 0);
    assert(!h.view.is_showing_projects_root());
    assert(!h.view.is_showing_project_root_level());
    var snapshot = h.view.get_scope_snapshot(ftv_project_at(h, 0), ftv_card_at(h, 0));
    assert(snapshot.scope_mode == HolderLinux.ToolScopeMode.CARD_FOCUS);
    assert(snapshot.project_id == "p1");
    assert(snapshot.card_id == "a");
}

// ---- what the bound board shows ----------------------------------------------------------------

private void ftv_test_binding_shows_the_project_root_tiles() {
    var h = new FlowboardToolViewHarness();

    assert(h.context_requests >= 1);
    assert(ftv_visible_count(h) == 3);
    assert(h.stack().get_visible_child_name() == "grid");
    assert(fv_title_label(h.row("a")).get_text() == "Alpha");
    assert(fv_title_label(h.row("b")).get_text() == "Bravo");
    assert(fv_title_label(h.row("f")).get_text() == "Folder");
    assert(fv_meta_label(h.row("f")).get_text().has_prefix("1 item | "));
    assert(h.empty_label().get_text() ==
           "Drag card center onto another card to nest. Drag left/right edges to reorder.");
    assert(h.view.is_showing_project_root_level());
    assert(!h.view.is_showing_projects_root());
}

private void ftv_test_an_empty_project_shows_the_empty_message() {
    var h = new FlowboardToolViewHarness();
    h.projects.append(fv_project("p3", "Project Three"));

    h.select_project(2);

    assert(ftv_visible_count(h) == 0);
    assert(h.stack().get_visible_child_name() == "empty");
    assert(h.empty_label().get_text() == "No cards yet. Create one to get started.");
}

private void ftv_test_no_selected_project_asks_for_one() {
    var h = new FlowboardToolViewHarness(false);
    h.project_selection.set_autoselect(false);
    h.project_selection.set_can_unselect(true);
    h.project_selection.unselect_item(0);
    assert(h.project_selection.get_selected() == Gtk.INVALID_LIST_POSITION);

    h.view.bind_controller(h.controller);
    fv_settle();

    assert(h.stack().get_visible_child_name() == "empty");
    assert(h.empty_label().get_text() == "Select a project to browse cards.");
}

private void ftv_test_switching_project_shows_that_projects_cards() {
    var h = new FlowboardToolViewHarness();
    assert(ftv_visible_count(h) == 3);

    h.select_project(1);

    assert(ftv_visible_count(h) == 1);
    assert(fv_row_for_card(h.content(), "z") != null);
    assert(fv_title_label(h.row("z")).get_text() == "Zulu");
}

private void ftv_test_the_board_says_loading_until_the_first_context_arrives() {
    var h = new FlowboardToolViewHarness(false);
    h.hold_contexts = true;

    h.view.bind_controller(h.controller);
    fv_settle();

    assert(h.pending.size >= 1);
    assert(ftv_visible_count(h) == 0);
    assert(h.stack().get_visible_child_name() == "empty");
    assert(h.empty_label().get_text() == "Loading cards...");

    h.hold_contexts = false;
    h.release_contexts();

    assert(ftv_visible_count(h) == 3);
    assert(h.stack().get_visible_child_name() == "grid");
}

private void ftv_test_a_late_answer_for_the_previous_project_is_ignored() {
    var h = new FlowboardToolViewHarness();
    assert(ftv_visible_count(h) == 3);
    h.hold_contexts = true;

    h.select_project(1);
    // While the other project's cards are still loading, the committed board stays up.
    assert(h.pending.size >= 1);
    assert(ftv_visible_count(h) == 3);
    assert(h.stack().get_visible_child_name() == "grid");

    // The user goes back before the first answer arrives; both answers then come in.
    h.select_project(0);
    assert(h.pending.size >= 2);
    h.release_contexts();

    assert(ftv_visible_count(h) == 3);
    assert(fv_title_label(h.row("a")).get_text() == "Alpha");
    assert(h.pending.size == 0);
}

// ---- opening and entering ----------------------------------------------------------------------

private void ftv_test_activating_a_card_asks_to_open_it() {
    var h = new FlowboardToolViewHarness();

    h.grid().activate(0);

    assert(h.log() == "open:a");
    assert(ftv_visible_count(h) == 3);
}

private void ftv_test_activating_a_folder_opens_it_and_backspace_returns() {
    var h = new FlowboardToolViewHarness();
    var folder = ftv_card_at(h, 2);

    h.grid().activate(2);
    fv_settle();

    assert(h.log() == "open:f");
    assert(ftv_visible_count(h) == 1);
    assert(fv_title_label(h.row("i")).get_text() == "Inner");
    assert(!h.view.is_showing_project_root_level());
    var inside = h.view.get_scope_snapshot(ftv_project_at(h, 0), folder);
    assert(inside.scope_mode == HolderLinux.ToolScopeMode.CARD_FOCUS);
    assert(inside.card_id == "f");

    assert(fv_key_controller(h.grid()).key_pressed(Gdk.Key.BackSpace, 0, 0));
    fv_settle();

    assert(ftv_visible_count(h) == 3);
    assert(h.view.is_showing_project_root_level());
    // At the project root a selected card is not part of the scope.
    var back = h.view.get_scope_snapshot(ftv_project_at(h, 0), folder);
    assert(back.scope_mode == HolderLinux.ToolScopeMode.PROJECT_ROOT);
    assert(back.card_id == null);
}

private void ftv_test_the_project_overview_and_card_navigation_entry_points() {
    var h = new FlowboardToolViewHarness();

    ftv_navigate_to_projects_root(h);
    assert(h.view.is_showing_projects_root());
    assert(!h.view.is_showing_project_root_level());
    assert(ftv_visible_count(h) == 2);
    assert(fv_row_for_card(h.content(), "") != null);
    var overview = h.view.get_scope_snapshot(ftv_project_at(h, 0), ftv_card_at(h, 0));
    assert(overview.scope_mode == HolderLinux.ToolScopeMode.PROJECTS_ROOT);
    assert(overview.project_id == null);
    assert(overview.card_id == null);

    // New cards need a project, so the overview ignores the request.
    h.view.request_create_card_here();
    assert(h.events.size == 0);

    ftv_navigate_to_project_root(h, "p1");
    assert(!h.view.is_showing_projects_root());
    assert(h.view.is_showing_project_root_level());
    assert(ftv_visible_count(h) == 3);

    bool opened = false;
    h.view.navigate_to_card.begin("z", (obj, res) => {
        opened = h.view.navigate_to_card.end(res);
    });
    fv_settle();
    assert(opened);
    assert(h.log() == "open:z");
}

private void ftv_test_show_projects_root_and_show_project_root_switch_levels() {
    var h = new FlowboardToolViewHarness();

    h.view.show_projects_root();
    fv_settle();
    assert(h.view.is_showing_projects_root());
    assert(ftv_visible_count(h) == 2);

    h.view.show_project_root();
    fv_settle();
    assert(!h.view.is_showing_projects_root());
    assert(ftv_visible_count(h) == 3);
}

private void ftv_test_a_new_card_request_carries_the_current_folder() {
    var h = new FlowboardToolViewHarness();

    h.view.request_create_card_here();
    h.grid().activate(2);
    fv_settle();
    h.view.request_create_card_here();

    assert(h.log() == "new:-|open:f|new:f");
}

// ---- moving cards ------------------------------------------------------------------------------

private void ftv_test_dropping_a_card_asks_for_the_move() {
    var h = new FlowboardToolViewHarness();

    assert(ftv_drop(h, "a", "b", 0.5));
    assert(ftv_drop(h, "a", "b", 0.1));
    assert(ftv_drop(h, "a", "b", 0.9));

    assert(h.log() == "toast:Moved \"Alpha\" into \"Bravo\"|move:a:p1:into:b:-|" +
                      "move:a:p1:before:b:-|move:a:p1:after:b:-");
}

private void ftv_test_dropping_on_the_background_moves_the_card_to_the_end() {
    var h = new FlowboardToolViewHarness();

    assert(fv_drop_target(h.grid()).drop(fv_string_value("a"), 5.0, 5.0));

    assert(h.log() == "move:a:p1:to_end:-:-");
}

private void ftv_test_a_drop_that_cannot_move_anything_asks_for_nothing() {
    var h = new FlowboardToolViewHarness();

    // Onto itself, and a card the board does not know.
    assert(!ftv_drop(h, "a", "a", 0.5));
    assert(ftv_drop(h, "ghost", "b", 0.5));
    assert(fv_drop_target(h.grid()).drop(fv_string_value("ghost"), 5.0, 5.0));

    assert(h.events.size == 0);
}

private void ftv_test_delete_asks_to_trash_the_selected_card() {
    var h = new FlowboardToolViewHarness();
    ftv_selection(h).select_item(1, true);

    assert(fv_key_controller(h.grid()).key_pressed(Gdk.Key.Delete, 0, 0));

    assert(h.log() == "trash:b");
}

// ---- context menus (they show a popover, which macOS cannot do in a test) -----------------------

private void ftv_test_the_card_menu_forwards_every_action() {
    if (fv_skip_popover_tests()) {
        return;
    }
    var h = new FlowboardToolViewHarness();
    fv_click(h.row("b"), Gdk.BUTTON_SECONDARY).pressed(1, 4.0, 4.0);
    var menu = fv_popover(h.row("b"));
    assert(menu != null);

    foreach (var label in new string[] { "Open", "Create Child Card", "Move to Trash", "Move Left",
                                         "Move Right", "Move to Start", "Move to End" }) {
        assert(fv_button_labeled((!) menu, label).get_sensitive());
        fv_button_labeled((!) menu, label).clicked();
    }

    assert(h.log() == "open:b|new:b|trash:b|move:b:p1:left:-:-|move:b:p1:right:-:-|" +
                      "move:b:p1:to_start:-:-|move:b:p1:to_end:-:-");
}

private void ftv_test_moving_a_card_up_a_level_names_where_it_went() {
    if (fv_skip_popover_tests()) {
        return;
    }
    var h = new FlowboardToolViewHarness();
    h.grid().activate(2);
    fv_settle();
    assert(fv_row_for_card(h.content(), "i") != null);
    h.events.clear();

    var inner = h.row("i");
    fv_click(inner, Gdk.BUTTON_SECONDARY).pressed(1, 4.0, 4.0);
    var menu = fv_popover(inner);
    assert(menu != null);
    assert(fv_button_labeled((!) menu, "Move Up a Level").get_sensitive());
    fv_button_labeled((!) menu, "Move Up a Level").clicked();

    assert(h.log() == "move:i:p1:up_level:-:-|toast:Moved Inner into Project One");
}

private void ftv_test_opening_a_folder_from_its_menu_enters_it() {
    if (fv_skip_popover_tests()) {
        return;
    }
    var h = new FlowboardToolViewHarness();
    var folder = h.row("f");
    fv_click(folder, Gdk.BUTTON_SECONDARY).pressed(1, 4.0, 4.0);

    fv_button_labeled((!) fv_popover(folder), "Open").clicked();
    fv_settle();

    assert(h.log() == "open:f");
    assert(ftv_visible_count(h) == 1);
    assert(!h.view.is_showing_project_root_level());
}

private void ftv_test_the_background_menu_asks_for_a_card_in_the_current_level() {
    if (fv_skip_popover_tests()) {
        return;
    }
    var h = new FlowboardToolViewHarness();
    var grid = h.grid();

    fv_click(grid, Gdk.BUTTON_SECONDARY).pressed(1, 10.0, 10.0);
    fv_button_labeled((!) fv_popover(grid), "New Card").clicked();
    assert(h.log() == "new:-");

    h.grid().activate(2);
    fv_settle();
    fv_click(grid, Gdk.BUTTON_SECONDARY).pressed(1, 10.0, 10.0);
    fv_button_labeled((!) fv_popover(grid), "New Card").clicked();
    assert(h.log() == "new:-|open:f|new:f");
}

// ---- binding a second controller ---------------------------------------------------------------

private void ftv_test_binding_a_new_controller_replaces_the_old_one() {
    var h = new FlowboardToolViewHarness();
    var replacement = h.make_controller();
    h.view.bind_controller(replacement);
    fv_settle();
    assert(ftv_visible_count(h) == 3);

    // Every event has to reach the outside world once, not once per controller ever bound.
    assert(ftv_drop(h, "a", "b", 0.5));
    assert(h.log() == "toast:Moved \"Alpha\" into \"Bravo\"|move:a:p1:into:b:-");
    h.events.clear();

    h.grid().activate(0);
    assert(h.log() == "open:a");
    h.events.clear();

    // The controller that was replaced no longer speaks for the view; the new one does.
    h.controller.request_create_card_here();
    assert(h.events.size == 0);
    replacement.request_create_card_here();
    assert(h.log() == "new:-");
}

public void register_flowboard_tool_view_tests() {
    var prefix = "/holder/flowboard-tool-view/";
    Test.add_func(prefix + "identity", ftv_test_the_tool_identifies_itself);
    Test.add_func(prefix + "unbound", ftv_test_an_unbound_view_ignores_navigation_and_keeps_the_selected_card);
    Test.add_func(prefix + "board/project-root", ftv_test_binding_shows_the_project_root_tiles);
    Test.add_func(prefix + "board/empty-project", ftv_test_an_empty_project_shows_the_empty_message);
    Test.add_func(prefix + "board/no-project", ftv_test_no_selected_project_asks_for_one);
    Test.add_func(prefix + "board/switch-project", ftv_test_switching_project_shows_that_projects_cards);
    Test.add_func(prefix + "board/loading", ftv_test_the_board_says_loading_until_the_first_context_arrives);
    Test.add_func(prefix + "board/late-answer", ftv_test_a_late_answer_for_the_previous_project_is_ignored);
    Test.add_func(prefix + "open/card", ftv_test_activating_a_card_asks_to_open_it);
    Test.add_func(prefix + "open/folder", ftv_test_activating_a_folder_opens_it_and_backspace_returns);
    Test.add_func(prefix + "navigate/entry-points", ftv_test_the_project_overview_and_card_navigation_entry_points);
    Test.add_func(prefix + "navigate/levels", ftv_test_show_projects_root_and_show_project_root_switch_levels);
    Test.add_func(prefix + "navigate/new-card", ftv_test_a_new_card_request_carries_the_current_folder);
    Test.add_func(prefix + "move/drop", ftv_test_dropping_a_card_asks_for_the_move);
    Test.add_func(prefix + "move/background", ftv_test_dropping_on_the_background_moves_the_card_to_the_end);
    Test.add_func(prefix + "move/refused", ftv_test_a_drop_that_cannot_move_anything_asks_for_nothing);
    Test.add_func(prefix + "move/delete-key", ftv_test_delete_asks_to_trash_the_selected_card);
    Test.add_func(prefix + "menu/card", ftv_test_the_card_menu_forwards_every_action);
    Test.add_func(prefix + "menu/up-level", ftv_test_moving_a_card_up_a_level_names_where_it_went);
    Test.add_func(prefix + "menu/open-folder", ftv_test_opening_a_folder_from_its_menu_enters_it);
    Test.add_func(prefix + "menu/background", ftv_test_the_background_menu_asks_for_a_card_in_the_current_level);
    Test.add_func(prefix + "rebind", ftv_test_binding_a_new_controller_replaces_the_old_one);
}

}
