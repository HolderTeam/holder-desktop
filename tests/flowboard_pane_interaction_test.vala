using GLib;

namespace HolderLinuxTests {

// ---- rendering ---------------------------------------------------------------------------------

private void fpi_test_leaf_and_container_tiles_render_from_the_presenter() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1", "Leaf Card"));
    h.add(fv_tile("c2", "Folder Card", true, null, 2, 1));

    var leaf = h.row("c1");
    assert(fv_title_label(leaf).get_text() == "Leaf Card");
    assert(fv_meta_label(leaf).get_text().length > 0);
    assert(!fv_meta_label(leaf).get_text().contains("item"));
    assert(!leaf.get_data<Gtk.Widget>("flowboard-folder-tab").get_visible());
    assert(leaf.get_data<Gtk.Widget>("flowboard-header-box").get_margin_top() == 15);
    assert(!leaf.has_css_class("flowboard-branch"));

    var folder = h.row("c2");
    assert(fv_title_label(folder).get_text() == "Folder Card");
    assert(fv_meta_label(folder).get_text().has_prefix("2 items | "));
    assert(folder.get_data<Gtk.Widget>("flowboard-folder-tab").get_visible());
    assert(folder.get_data<Gtk.Widget>("flowboard-header-box").get_margin_top() == 0);
    assert(folder.has_css_class("flowboard-branch"));
}

private void fpi_test_a_folder_with_one_item_uses_the_singular() {
    var h = new FlowboardPaneHarness();
    h.add(new HolderLinux.FlowboardTile("card:c1", "One", 100, true, "c1", null, null, 1, 0, 1));

    assert(fv_meta_label(h.row("c1")).get_text().has_prefix("1 item | "));
}

private void fpi_test_bound_tiles_carry_the_ids_and_sibling_data_the_menus_read() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1", "One", false, "parent-x", 3, 2));

    var row = h.row("c1");
    assert(row.get_data<string>("flowboard-card-id") == "c1");
    assert(row.get_data<string>("flowboard-parent-card-id") == "parent-x");
    assert(row.get_data<int>("flowboard-sibling-count") == 3);
    assert(row.get_data<int>("flowboard-sibling-index") == 2);
}

private void fpi_test_removing_a_tile_keeps_the_others_bound() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1", "One"));
    h.add(fv_tile("c2", "Two"));
    assert(h.stack().get_visible_child_name() == "grid");

    h.store.remove(0);
    fv_settle();

    assert(fv_title_label(h.row("c2")).get_text() == "Two");
    assert(h.stack().get_visible_child_name() == "grid");
}

private void fpi_test_empty_message_starts_generic_and_can_be_replaced() {
    var h = new FlowboardPaneHarness();
    var page = h.stack().get_child_by_name("empty");
    assert(page != null);
    var label = fv_find_type((!) page, typeof(Gtk.Label)) as Gtk.Label;
    assert(label != null);
    assert(((!) label).get_text() == "No cards yet.");
    assert(h.stack().get_visible_child_name() == "empty");

    h.pane.set_empty_message("Loading cards...");

    assert(((!) label).get_text() == "Loading cards...");
}

private void fpi_test_replacing_the_model_switches_what_the_pane_shows() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1", "One"));
    assert(h.stack().get_visible_child_name() == "grid");

    var replacement = new GLib.ListStore(typeof(HolderLinux.FlowboardTile));
    h.pane.set_model(replacement);
    assert(h.stack().get_visible_child_name() == "empty");

    // Changes to the model that was replaced no longer decide what the pane shows.
    h.store.append(fv_tile("c2", "Two"));
    fv_settle();
    assert(h.stack().get_visible_child_name() == "empty");

    replacement.append(fv_tile("c3", "Three"));
    fv_settle();
    assert(h.stack().get_visible_child_name() == "grid");
}

// ---- keyboard ----------------------------------------------------------------------------------

private void fpi_test_return_activates_the_first_selected_tile() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    h.add(fv_tile("c2"));
    h.add(fv_tile("c3"));
    var keys = fv_key_controller(h.grid());

    // Nothing is selected yet, so Return is left for someone else.
    assert(!h.selection().is_selected(0) && !h.selection().is_selected(1) && !h.selection().is_selected(2));
    assert(!keys.key_pressed(Gdk.Key.Return, 0, 0));
    assert(h.events.size == 0);

    h.selection().select_item(2, true);
    h.selection().select_item(1, false);
    assert(keys.key_pressed(Gdk.Key.Return, 0, 0));
    assert(keys.key_pressed(Gdk.Key.KP_Enter, 0, 0));
    assert(h.log() == "activated:1|activated:1");
}

private void fpi_test_delete_asks_to_trash_the_selected_card() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    h.add(fv_tile("c2"));
    var keys = fv_key_controller(h.grid());

    assert(!keys.key_pressed(Gdk.Key.Delete, 0, 0));
    assert(h.events.size == 0);

    h.selection().select_item(1, true);
    assert(keys.key_pressed(Gdk.Key.Delete, 0, 0));
    assert(keys.key_pressed(Gdk.Key.KP_Delete, 0, 0));
    assert(h.log() == "trash:c2|trash:c2");
}

private void fpi_test_delete_ignores_a_project_tile() {
    var h = new FlowboardPaneHarness();
    h.add(fv_project_tile("p1", "Project One"));
    var keys = fv_key_controller(h.grid());

    h.selection().select_item(0, true);
    assert(h.selection().is_selected(0));

    assert(!keys.key_pressed(Gdk.Key.Delete, 0, 0));
    assert(h.events.size == 0);
}

private void fpi_test_backspace_navigates_up_and_other_keys_are_left_alone() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    var keys = fv_key_controller(h.grid());

    assert(keys.key_pressed(Gdk.Key.BackSpace, 0, 0));
    assert(h.log() == "up");

    assert(!keys.key_pressed(Gdk.Key.Escape, 0, 0));
    assert(h.log() == "up");
}

// ---- pointer -----------------------------------------------------------------------------------

private void fpi_test_a_background_click_clears_the_selection_but_a_double_click_does_not() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    h.add(fv_tile("c2"));
    var primary = fv_click(h.grid(), Gdk.BUTTON_PRIMARY);
    h.selection().select_item(0, true);
    assert(h.selection().is_selected(0));

    primary.pressed(2, 5.0, 5.0);
    assert(h.selection().is_selected(0));

    primary.pressed(1, 5.0, 5.0);
    assert(!h.selection().is_selected(0));
    assert(h.grid().get_enable_rubberband());
}

private void fpi_test_clicking_a_tile_keeps_the_selection_and_pauses_rubberband_selection() {
    if (fv_skip_unless_linux()) {
        return;
    }
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    h.add(fv_tile("c2"));
    var centre = h.present_and_centre_of("c1");
    var primary = fv_click(h.grid(), Gdk.BUTTON_PRIMARY);
    h.selection().select_item(1, true);
    assert(h.selection().is_selected(1));
    // Precondition: the point really lands on the tile, not on the grid background.
    var picked = h.grid().pick(centre.x, centre.y, Gtk.PickFlags.DEFAULT);
    assert(picked != null && picked != h.grid());

    primary.pressed(1, centre.x, centre.y);

    assert(h.selection().is_selected(1));
    assert(!h.grid().get_enable_rubberband());
    primary.released(1, centre.x, centre.y);
    assert(h.grid().get_enable_rubberband());
    h.destroy_window();
}

private void fpi_test_releasing_the_pointer_restores_rubberband_selection() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    var primary = fv_click(h.grid(), Gdk.BUTTON_PRIMARY);
    h.grid().set_enable_rubberband(false);
    assert(!h.grid().get_enable_rubberband());

    primary.released(1, 5.0, 5.0);

    assert(h.grid().get_enable_rubberband());
}

// ---- dragging out of a tile --------------------------------------------------------------------

private void fpi_test_dragging_a_card_offers_its_id() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));

    var provider = fv_drag_source(h.row("c1")).prepare(1.0, 1.0);

    assert(provider != null);
    Value payload = Value(typeof(string));
    try {
        ((!) provider).get_value(ref payload);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(payload.get_string() == "c1");
}

private void fpi_test_dragging_a_project_tile_offers_nothing() {
    var h = new FlowboardPaneHarness();
    h.add(fv_project_tile("p1", "Project One"));

    assert(fv_drag_source(h.row_without_card()).prepare(1.0, 1.0) == null);
}

// ---- dropping onto a tile ----------------------------------------------------------------------

private void fpi_test_the_drop_hint_follows_the_pointer_across_a_tile() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    var row = h.sized_row("c1");
    var target = fv_drop_target(row);
    var width = (double) row.get_width();

    assert(!h.grid().has_css_class("flowboard-drag-active"));
    assert(target.enter(width * 0.1, 5.0) == Gdk.DragAction.MOVE);
    assert(h.grid().has_css_class("flowboard-drag-active"));
    assert(h.has_drop_hint(row, "before") && !h.has_drop_hint(row, "into") && !h.has_drop_hint(row, "after"));

    assert(target.motion(width * 0.5, 5.0) == Gdk.DragAction.MOVE);
    assert(h.has_drop_hint(row, "into") && !h.has_drop_hint(row, "before") && !h.has_drop_hint(row, "after"));

    assert(target.motion(width * 0.9, 5.0) == Gdk.DragAction.MOVE);
    assert(h.has_drop_hint(row, "after") && !h.has_drop_hint(row, "into") && !h.has_drop_hint(row, "before"));

    target.leave();
    assert(!h.has_drop_hint(row, "before") && !h.has_drop_hint(row, "into") && !h.has_drop_hint(row, "after"));
    assert(!h.grid().has_css_class("flowboard-drag-active"));
}

private void fpi_test_dropping_a_card_on_a_tile_reports_where_it_landed() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    h.add(fv_tile("c2"));
    var row = h.sized_row("c1");
    var target = fv_drop_target(row);
    var width = (double) row.get_width();

    target.enter(width * 0.5, 5.0);
    assert(target.drop(fv_string_value("c2"), width * 0.5, 5.0));
    assert(target.drop(fv_string_value("c2"), width * 0.1, 5.0));
    assert(target.drop(fv_string_value("c2"), width * 0.9, 5.0));

    assert(h.log() == "drop:c2>c1@0.50|drop:c2>c1@0.10|drop:c2>c1@0.90");
    assert(!h.has_drop_hint(row, "into") && !h.has_drop_hint(row, "before") && !h.has_drop_hint(row, "after"));
    assert(!h.grid().has_css_class("flowboard-drag-active"));
}

private void fpi_test_a_drop_that_cannot_move_anything_is_refused() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    var row = h.sized_row("c1");
    var target = fv_drop_target(row);

    target.enter(50.0, 5.0);
    assert(h.has_drop_hint(row, "into"));

    // A card dropped on itself, and a payload with no card id.
    assert(!target.drop(fv_string_value("c1"), 50.0, 5.0));
    assert(!h.has_drop_hint(row, "into"));
    assert(!h.grid().has_css_class("flowboard-drag-active"));
    target.enter(50.0, 5.0);
    assert(!target.drop(fv_string_value("   "), 50.0, 5.0));
    assert(!h.has_drop_hint(row, "into"));
    assert(h.events.size == 0);
}

private void fpi_test_dropping_onto_a_project_tile_is_refused() {
    var h = new FlowboardPaneHarness();
    h.add(fv_project_tile("p1", "Project One"));
    var row = h.row_without_card();
    row.allocate(200, 80, -1, null);
    var target = fv_drop_target(row);

    target.enter(50.0, 5.0);
    assert(!target.drop(fv_string_value("c9"), 50.0, 5.0));
    assert(!h.has_drop_hint(row, "into"));
    assert(!h.grid().has_css_class("flowboard-drag-active"));
    assert(h.events.size == 0);
}

// ---- dropping onto the background --------------------------------------------------------------

private void fpi_test_dropping_a_card_on_the_background_moves_it_to_the_end() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    var target = fv_drop_target(h.grid());

    assert(target.enter(5.0, 5.0) == Gdk.DragAction.MOVE);
    assert(h.grid().has_css_class("flowboard-drag-active"));
    assert(target.drop(fv_string_value("c1"), 5.0, 5.0));
    assert(!h.grid().has_css_class("flowboard-drag-active"));
    assert(h.log() == "background-drop:c1");
}

private void fpi_test_a_blank_drop_on_the_background_is_refused() {
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    var target = fv_drop_target(h.grid());

    target.enter(5.0, 5.0);
    assert(h.grid().has_css_class("flowboard-drag-active"));
    assert(!target.drop(fv_string_value("  "), 5.0, 5.0));
    assert(!h.grid().has_css_class("flowboard-drag-active"));

    target.enter(5.0, 5.0);
    target.leave();
    assert(!h.grid().has_css_class("flowboard-drag-active"));
    assert(h.events.size == 0);
}

// ---- context menus (they show a popover, which macOS cannot do in a test) -----------------------

private void fpi_test_right_clicking_a_card_opens_its_menu() {
    if (fv_skip_popover_tests()) {
        return;
    }
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c2", "Two", false, "parent-x", 3, 1));
    var row = h.row("c2");
    assert(fv_popover_count(row) == 0);

    fv_click(row, Gdk.BUTTON_SECONDARY).pressed(1, 4.0, 4.0);

    var popover = fv_popover(row);
    assert(popover != null);
    assert(fv_join(fv_button_labels((!) popover), ",") ==
           "Open,Create Child Card,Move Up a Level,Move to Trash,Move Left,Move Right,Move to Start,Move to End");

    foreach (var label in new string[] { "Open", "Create Child Card", "Move Up a Level", "Move to Trash",
                                         "Move Left", "Move Right", "Move to Start", "Move to End" }) {
        assert(fv_button_labeled((!) popover, label).get_sensitive());
        fv_button_labeled((!) popover, label).clicked();
    }
    assert(h.log() == "open:c2|child:c2|up-level:c2|trash:c2|left:c2|right:c2|start:c2|end:c2");
}

private void fpi_test_the_card_menu_disables_moves_that_are_not_possible() {
    if (fv_skip_popover_tests()) {
        return;
    }
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("first", "First", false, null, 3, 0));
    h.add(fv_tile("last", "Last", false, "parent-x", 3, 2));
    h.add(fv_tile("only", "Only", false, null, 1, 0));

    var first = h.row("first");
    fv_click(first, Gdk.BUTTON_SECONDARY).pressed(1, 4.0, 4.0);
    var menu = (!) fv_popover(first);
    assert(!fv_button_labeled(menu, "Move Up a Level").get_sensitive());
    assert(!fv_button_labeled(menu, "Move Left").get_sensitive());
    assert(fv_button_labeled(menu, "Move Right").get_sensitive());
    assert(fv_button_labeled(menu, "Move to Start").get_sensitive());
    assert(fv_button_labeled(menu, "Move to End").get_sensitive());

    var last = h.row("last");
    fv_click(last, Gdk.BUTTON_SECONDARY).pressed(1, 4.0, 4.0);
    menu = (!) fv_popover(last);
    assert(fv_button_labeled(menu, "Move Up a Level").get_sensitive());
    assert(fv_button_labeled(menu, "Move Left").get_sensitive());
    assert(!fv_button_labeled(menu, "Move Right").get_sensitive());

    var only = h.row("only");
    fv_click(only, Gdk.BUTTON_SECONDARY).pressed(1, 4.0, 4.0);
    menu = (!) fv_popover(only);
    assert(!fv_button_labeled(menu, "Move Left").get_sensitive());
    assert(!fv_button_labeled(menu, "Move Right").get_sensitive());
    assert(!fv_button_labeled(menu, "Move to Start").get_sensitive());
    assert(!fv_button_labeled(menu, "Move to End").get_sensitive());
    // Opening, creating a child and trashing never depend on the siblings.
    assert(fv_button_labeled(menu, "Open").get_sensitive());
    assert(fv_button_labeled(menu, "Create Child Card").get_sensitive());
    assert(fv_button_labeled(menu, "Move to Trash").get_sensitive());
}

private void fpi_test_right_clicking_a_card_again_does_not_stack_menus() {
    if (fv_skip_popover_tests()) {
        return;
    }
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1", "One", false, null, 2, 0));
    var row = h.row("c1");
    var context = fv_click(row, Gdk.BUTTON_SECONDARY);

    context.pressed(1, 4.0, 4.0);
    assert(fv_popover_count(row) == 1);
    context.pressed(1, 6.0, 6.0);
    context.pressed(1, 8.0, 8.0);

    // Each right-click used to leave another popover parented to the tile.
    assert(fv_popover_count(row) == 1);
}

private void fpi_test_only_a_single_right_click_on_a_card_opens_a_menu() {
    if (fv_skip_popover_tests()) {
        return;
    }
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    var row = h.row("c1");

    fv_click(row, Gdk.BUTTON_SECONDARY).pressed(2, 4.0, 4.0);

    assert(fv_popover_count(row) == 0);
}

private void fpi_test_a_project_tile_has_no_card_menu() {
    if (fv_skip_popover_tests()) {
        return;
    }
    var h = new FlowboardPaneHarness();
    h.add(fv_project_tile("p1", "Project One"));
    var row = h.row_without_card();

    fv_click(row, Gdk.BUTTON_SECONDARY).pressed(1, 4.0, 4.0);

    assert(fv_popover_count(row) == 0);
}

private void fpi_test_right_clicking_a_tile_does_not_open_the_background_menu() {
    if (fv_skip_popover_tests() || fv_skip_unless_linux()) {
        return;
    }
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    var centre = h.present_and_centre_of("c1");
    var grid = h.grid();
    var picked = grid.pick(centre.x, centre.y, Gtk.PickFlags.DEFAULT);
    assert(picked != null && picked != grid);

    // The tile's own gesture handles this press; the grid's background menu must stay closed.
    fv_click(grid, Gdk.BUTTON_SECONDARY).pressed(1, centre.x, centre.y);

    assert(fv_popover_count(grid) == 0);
    h.destroy_window();
}

private void fpi_test_right_clicking_the_background_offers_a_new_card() {
    if (fv_skip_popover_tests()) {
        return;
    }
    var h = new FlowboardPaneHarness();
    h.add(fv_tile("c1"));
    var grid = h.grid();
    var context = fv_click(grid, Gdk.BUTTON_SECONDARY);
    assert(fv_popover_count(grid) == 0);

    context.pressed(2, 10.0, 10.0);
    assert(fv_popover_count(grid) == 0);

    context.pressed(1, 10.0, 10.0);
    var popover = fv_popover(grid);
    assert(popover != null);
    assert(fv_join(fv_button_labels((!) popover), ",") == "New Card");

    // The menu is built once and reused.
    context.pressed(1, 30.0, 30.0);
    assert(fv_popover_count(grid) == 1);

    fv_button_labeled((!) popover, "New Card").clicked();
    assert(h.log() == "background-new");
}

public void register_flowboard_pane_interaction_tests() {
    var prefix = "/holder/flowboard-pane/";
    Test.add_func(prefix + "render/leaf-and-container", fpi_test_leaf_and_container_tiles_render_from_the_presenter);
    Test.add_func(prefix + "render/singular-item", fpi_test_a_folder_with_one_item_uses_the_singular);
    Test.add_func(prefix + "render/bound-data", fpi_test_bound_tiles_carry_the_ids_and_sibling_data_the_menus_read);
    Test.add_func(prefix + "render/remove-tile", fpi_test_removing_a_tile_keeps_the_others_bound);
    Test.add_func(prefix + "render/empty-message", fpi_test_empty_message_starts_generic_and_can_be_replaced);
    Test.add_func(prefix + "render/replace-model", fpi_test_replacing_the_model_switches_what_the_pane_shows);
    Test.add_func(prefix + "keys/return", fpi_test_return_activates_the_first_selected_tile);
    Test.add_func(prefix + "keys/delete", fpi_test_delete_asks_to_trash_the_selected_card);
    Test.add_func(prefix + "keys/delete-project", fpi_test_delete_ignores_a_project_tile);
    Test.add_func(prefix + "keys/backspace", fpi_test_backspace_navigates_up_and_other_keys_are_left_alone);
    Test.add_func(prefix + "pointer/background-click", fpi_test_a_background_click_clears_the_selection_but_a_double_click_does_not);
    Test.add_func(prefix + "pointer/tile-click", fpi_test_clicking_a_tile_keeps_the_selection_and_pauses_rubberband_selection);
    Test.add_func(prefix + "pointer/release", fpi_test_releasing_the_pointer_restores_rubberband_selection);
    Test.add_func(prefix + "drag/card", fpi_test_dragging_a_card_offers_its_id);
    Test.add_func(prefix + "drag/project", fpi_test_dragging_a_project_tile_offers_nothing);
    Test.add_func(prefix + "drop/hint", fpi_test_the_drop_hint_follows_the_pointer_across_a_tile);
    Test.add_func(prefix + "drop/lands", fpi_test_dropping_a_card_on_a_tile_reports_where_it_landed);
    Test.add_func(prefix + "drop/refused", fpi_test_a_drop_that_cannot_move_anything_is_refused);
    Test.add_func(prefix + "drop/project-tile", fpi_test_dropping_onto_a_project_tile_is_refused);
    Test.add_func(prefix + "drop/background", fpi_test_dropping_a_card_on_the_background_moves_it_to_the_end);
    Test.add_func(prefix + "drop/background-blank", fpi_test_a_blank_drop_on_the_background_is_refused);
    Test.add_func(prefix + "menu/card", fpi_test_right_clicking_a_card_opens_its_menu);
    Test.add_func(prefix + "menu/sensitivity", fpi_test_the_card_menu_disables_moves_that_are_not_possible);
    Test.add_func(prefix + "menu/no-stacking", fpi_test_right_clicking_a_card_again_does_not_stack_menus);
    Test.add_func(prefix + "menu/single-press", fpi_test_only_a_single_right_click_on_a_card_opens_a_menu);
    Test.add_func(prefix + "menu/project-tile", fpi_test_a_project_tile_has_no_card_menu);
    Test.add_func(prefix + "menu/background-not-on-tile", fpi_test_right_clicking_a_tile_does_not_open_the_background_menu);
    Test.add_func(prefix + "menu/background", fpi_test_right_clicking_the_background_offers_a_new_card);
}

}
