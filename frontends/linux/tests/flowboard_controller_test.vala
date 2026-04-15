using GLib;

namespace HolderLinuxTests {

private HolderLinux.Project make_project(string id,
                                         string name,
                                         int64 updated_at = 0,
                                         int root_card_count = 0,
                                         int card_count = 0) {
    return new HolderLinux.Project(
        id,
        name,
        "encrypted_git",
        "/tmp/%s".printf(id),
        0,
        updated_at,
        null,
        null,
        card_count,
        root_card_count
    );
}

private HolderLinux.CardSummary make_card(string id,
                                          string project_id,
                                          string title,
                                          double sort_key,
                                          string? parent_id = null,
                                          int64 updated_at = 0) {
    return new HolderLinux.CardSummary(id, project_id, title, "%s.md".printf(id), sort_key, parent_id, 0, updated_at);
}

private string? normalize_parent(string? parent_id) {
    if (parent_id == null) {
        return null;
    }
    var trimmed = parent_id.strip();
    return trimmed.length == 0 ? null : trimmed;
}

private HolderLinux.CardSummary? find_card_in_store(GLib.ListStore card_store, string card_id) {
    for (uint i = 0; i < card_store.get_n_items(); i++) {
        var card = card_store.get_item(i) as HolderLinux.CardSummary;
        if (card != null && card.card_id == card_id) {
            return card;
        }
    }
    return null;
}

private int child_count_for_card(GLib.ListStore card_store, string card_id) {
    int count = 0;
    for (uint i = 0; i < card_store.get_n_items(); i++) {
        var card = card_store.get_item(i) as HolderLinux.CardSummary;
        if (card == null) {
            continue;
        }
        if (normalize_parent(card.parent_card_id) == card_id) {
            count++;
        }
    }
    return count;
}

private HolderLinux.CardContextData build_context_for_request(GLib.ListStore project_store,
                                                              GLib.ListStore card_store,
                                                              string project_id,
                                                              string? parent_card_id) {
    string project_name = project_id;
    for (uint i = 0; i < project_store.get_n_items(); i++) {
        var project = project_store.get_item(i) as HolderLinux.Project;
        if (project != null && project.project_id == project_id) {
            project_name = project.name;
            break;
        }
    }

    var breadcrumbs = new Gee.ArrayList<HolderLinux.CardContextBreadcrumb>();
    breadcrumbs.add(new HolderLinux.CardContextBreadcrumb("project", project_name, project_id, null));

    var parent_chain = new Gee.ArrayList<HolderLinux.CardSummary>();
    var cursor = normalize_parent(parent_card_id);
    int guard = 0;
    while (cursor != null && guard < 256) {
        var card = find_card_in_store(card_store, cursor);
        if (card == null) {
            break;
        }
        parent_chain.add(card);
        cursor = normalize_parent(card.parent_card_id);
        guard++;
    }
    for (int i = parent_chain.size - 1; i >= 0; i--) {
        var card = parent_chain[i];
        breadcrumbs.add(new HolderLinux.CardContextBreadcrumb("card", card.title, null, card.card_id));
    }

    var cards = new Gee.ArrayList<HolderLinux.CardContextCard>();
    for (uint i = 0; i < card_store.get_n_items(); i++) {
        var card = card_store.get_item(i) as HolderLinux.CardSummary;
        if (card == null || card.project_id != project_id) {
            continue;
        }
        if (normalize_parent(card.parent_card_id) != normalize_parent(parent_card_id)) {
            continue;
        }
        cards.add(new HolderLinux.CardContextCard(
            card.card_id,
            card.project_id,
            card.title,
            card.rel_path,
            card.sort_key,
            card.parent_card_id,
            card.created_at,
            card.updated_at,
            child_count_for_card(card_store, card.card_id)
        ));
    }

    return new HolderLinux.CardContextData(
        new HolderLinux.CardContextProject(project_id, project_name),
        normalize_parent(parent_card_id),
        breadcrumbs,
        cards
    );
}

private HolderLinux.FlowboardController make_controller(out GLib.ListStore project_store,
                                                        out Gtk.SingleSelection project_selection,
                                                        out GLib.ListStore card_store) {
    project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    project_selection = new Gtk.SingleSelection(project_store);
    card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var controller = new HolderLinux.FlowboardController(project_store, project_selection, card_store);
    var projects = project_store;
    var cards = card_store;
    controller.context_load_requested.connect((project_id, parent_card_id) => {
        var context = build_context_for_request(projects, cards, project_id, parent_card_id);
        controller.apply_card_context(project_id, parent_card_id, context);
    });
    return controller;
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

private void test_refresh_selected_project_uses_backend_context_order() {
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
    assert(first.card_id == "c2");
    assert(!first.is_container);
    assert(second.card_id == "c1");
    assert(second.is_container);
    assert(second.child_count == 1);
}

private void test_refresh_selected_project_without_context_shows_loading_state() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var project_selection = new Gtk.SingleSelection(project_store);
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var controller = new HolderLinux.FlowboardController(project_store, project_selection, card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);

    int load_requests = 0;
    string load_project_id = "";
    string? load_parent_id = "__unset__";
    controller.context_load_requested.connect((project_id, parent_card_id) => {
        load_requests++;
        load_project_id = project_id;
        load_parent_id = parent_card_id;
    });

    string last_empty = "";
    controller.empty_message_changed.connect((text) => {
        last_empty = text;
    });
    Gee.ArrayList<HolderLinux.FlowboardBreadcrumbSegment>? crumbs = null;
    controller.breadcrumb_segments_changed.connect((segments) => {
        crumbs = segments;
    });

    controller.refresh();

    assert(load_requests == 1);
    assert(load_project_id == "p1");
    assert(load_parent_id == null);
    assert(last_empty == "Loading cards...");
    assert(controller.get_visible_model().get_n_items() == 0);
    assert(crumbs != null);
    assert(crumbs.size == 2);
    assert(crumbs[0].label == "Projects");
    assert(crumbs[1].label == "Project One");
}

private void test_refresh_pending_context_keeps_committed_tiles_visible() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var project_selection = new Gtk.SingleSelection(project_store);
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var controller = new HolderLinux.FlowboardController(project_store, project_selection, card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_store.append(make_project("p2", "Project Two", 20));
    project_selection.set_selected(0);
    card_store.append(make_card("p1a", "p1", "P1 A", 1024.0));
    card_store.append(make_card("p2a", "p2", "P2 A", 1024.0));

    int p2_load_requests = 0;
    controller.context_load_requested.connect((project_id, parent_card_id) => {
        if (project_id == "p1") {
            var context = build_context_for_request(project_store, card_store, project_id, parent_card_id);
            controller.apply_card_context(project_id, parent_card_id, context);
            return;
        }
        if (project_id == "p2") {
            p2_load_requests++;
        }
    });

    controller.refresh();
    var model = controller.get_visible_model();
    assert(model.get_n_items() == 1);
    var committed = tile_at(model, 0);
    assert(committed != null);
    assert(committed.card_id == "p1a");

    int empty_signals = 0;
    string last_empty = "";
    controller.empty_message_changed.connect((text) => {
        empty_signals++;
        last_empty = text;
    });

    project_selection.set_selected(1);
    controller.refresh();

    assert(p2_load_requests == 1);
    assert(model.get_n_items() == 1);
    var still_visible = tile_at(model, 0);
    assert(still_visible != null);
    assert(still_visible.card_id == "p1a");
    assert(empty_signals == 0);
    assert(last_empty != "Loading cards...");
}

private void test_transient_null_project_selection_keeps_committed_board() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var project_selection = new Gtk.SingleSelection(project_store);
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var controller = new HolderLinux.FlowboardController(project_store, project_selection, card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("p1a", "p1", "P1 A", 1024.0));

    controller.context_load_requested.connect((project_id, parent_card_id) => {
        var context = build_context_for_request(project_store, card_store, project_id, parent_card_id);
        controller.apply_card_context(project_id, parent_card_id, context);
    });

    string last_empty = "";
    controller.empty_message_changed.connect((text) => {
        last_empty = text;
    });

    controller.refresh();
    var model = controller.get_visible_model();
    assert(model.get_n_items() == 1);
    var committed = tile_at(model, 0);
    assert(committed != null);
    assert(committed.card_id == "p1a");

    project_selection.set_selected(Gtk.INVALID_LIST_POSITION);
    controller.refresh();

    model = controller.get_visible_model();
    assert(model.get_n_items() == 1);
    committed = tile_at(model, 0);
    assert(committed != null);
    assert(committed.card_id == "p1a");
    assert(last_empty != "Select a project to browse cards.");
}

private void test_apply_card_context_guard_when_showing_projects() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_store.append(make_project("p2", "Project Two", 20));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "A", 1024.0));

    controller.refresh();
    controller.navigate_to_breadcrumb_index(0); // showing_projects = true

    var context = build_context_for_request(project_store, card_store, "p1", null);
    controller.apply_card_context("p1", null, context);

    var model = controller.get_visible_model();
    assert(model.get_n_items() == 2);
    var first = tile_at(model, 0);
    assert(first != null);
    assert(first.project_id == "p1");
}

private void test_apply_card_context_guard_when_current_project_not_initialized() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var project_selection = new Gtk.SingleSelection(project_store);
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var controller = new HolderLinux.FlowboardController(project_store, project_selection, card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "A", 1024.0));

    var context = build_context_for_request(project_store, card_store, "p1", null);
    controller.apply_card_context("p1", null, context);

    assert(controller.get_visible_model().get_n_items() == 0);
}

private void test_apply_card_context_guard_when_project_mismatch() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_store.append(make_project("p2", "Project Two", 20));
    project_selection.set_selected(0);
    card_store.append(make_card("p1a", "p1", "P1 A", 1024.0));
    card_store.append(make_card("p2a", "p2", "P2 A", 1024.0));

    controller.refresh();
    var before_model = controller.get_visible_model();
    assert(before_model.get_n_items() == 1);
    var before = tile_at(before_model, 0);
    assert(before != null);
    assert(before.card_id == "p1a");

    var mismatched_context = build_context_for_request(project_store, card_store, "p2", null);
    controller.apply_card_context("p2", null, mismatched_context);

    var after_model = controller.get_visible_model();
    assert(after_model.get_n_items() == 1);
    var after = tile_at(after_model, 0);
    assert(after != null);
    assert(after.card_id == "p1a");
}

private void test_apply_card_context_guard_when_parent_mismatch() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("parent", "p1", "Parent", 1024.0));
    card_store.append(make_card("child", "p1", "Child", 1024.0, "parent"));

    controller.refresh();
    controller.activate_position(0); // enter parent
    var inside_model = controller.get_visible_model();
    assert(inside_model.get_n_items() == 1);
    var inside = tile_at(inside_model, 0);
    assert(inside != null);
    assert(inside.card_id == "child");

    var root_context = build_context_for_request(project_store, card_store, "p1", null);
    controller.apply_card_context("p1", null, root_context); // mismatched requested_parent_card_id

    var after_model = controller.get_visible_model();
    assert(after_model.get_n_items() == 1);
    var after = tile_at(after_model, 0);
    assert(after != null);
    assert(after.card_id == "child");
}

private void test_replace_visible_with_projects_skips_non_project_items() {
    var project_store = new GLib.ListStore(typeof(GLib.Object));
    var project_selection = new Gtk.SingleSelection(project_store);
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var controller = new HolderLinux.FlowboardController(project_store, project_selection, card_store);

    project_store.append(new GLib.Object()); // not a HolderLinux.Project
    project_store.append(make_project("p1", "Project One", 10, 2, 3));

    controller.navigate_to_breadcrumb_index(0); // projects mode

    var model = controller.get_visible_model();
    assert(model.get_n_items() == 1);
    var only = tile_at(model, 0);
    assert(only != null);
    assert(only.project_id == "p1");
    assert(only.child_count == 2);
}

private void test_breadcrumbs_in_projects_mode_are_just_projects() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);

    Gee.ArrayList<HolderLinux.FlowboardBreadcrumbSegment>? crumbs = null;
    controller.breadcrumb_segments_changed.connect((segments) => {
        crumbs = segments;
    });

    controller.refresh();
    controller.navigate_to_breadcrumb_index(0);

    assert(crumbs != null);
    assert(crumbs.size == 1);
    assert(crumbs[0].label == "Projects");
}

private void test_breadcrumbs_from_context_skip_empty_titles() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var project_selection = new Gtk.SingleSelection(project_store);
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var controller = new HolderLinux.FlowboardController(project_store, project_selection, card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("parent", "p1", "Parent", 1024.0));

    // Prime current_project_id without auto context application.
    controller.refresh();

    var crumbs = new Gee.ArrayList<HolderLinux.CardContextBreadcrumb>();
    crumbs.add(new HolderLinux.CardContextBreadcrumb("project", "Project One", "p1", null));
    crumbs.add(new HolderLinux.CardContextBreadcrumb("card", "", null, "blank"));
    crumbs.add(new HolderLinux.CardContextBreadcrumb("card", "Parent", null, "parent"));
    var cards = new Gee.ArrayList<HolderLinux.CardContextCard>();
    cards.add(new HolderLinux.CardContextCard("parent", "p1", "Parent", "parent.md", 1024.0, null, 0, 0, 0));
    var context = new HolderLinux.CardContextData(
        new HolderLinux.CardContextProject("p1", "Project One"),
        null,
        crumbs,
        cards
    );

    Gee.ArrayList<HolderLinux.FlowboardBreadcrumbSegment>? emitted = null;
    controller.breadcrumb_segments_changed.connect((segments) => {
        emitted = segments;
    });
    controller.apply_card_context("p1", null, context);

    assert(emitted != null);
    assert(emitted.size == 3);
    assert(emitted[0].label == "Projects");
    assert(emitted[1].label == "Project One");
    assert(emitted[2].label == "Parent");
}

private void test_transient_null_selection_preserves_committed_breadcrumbs() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var project_selection = new Gtk.SingleSelection(project_store);
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var controller = new HolderLinux.FlowboardController(project_store, project_selection, card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("root", "p1", "Root", 1024.0));

    Gee.ArrayList<HolderLinux.FlowboardBreadcrumbSegment>? crumbs = null;
    controller.breadcrumb_segments_changed.connect((segments) => {
        crumbs = segments;
    });

    // Prime current_project_id.
    controller.refresh();

    // Seed visible root tile without auto context loading.
    var context_cards = new Gee.ArrayList<HolderLinux.CardContextCard>();
    context_cards.add(new HolderLinux.CardContextCard("root", "p1", "Root", "root.md", 1024.0, null, 0, 0, 1));
    var context_crumbs = new Gee.ArrayList<HolderLinux.CardContextBreadcrumb>();
    context_crumbs.add(new HolderLinux.CardContextBreadcrumb("project", "Project One", "p1", null));
    var root_context = new HolderLinux.CardContextData(
        new HolderLinux.CardContextProject("p1", "Project One"),
        null,
        context_crumbs,
        context_cards
    );
    controller.apply_card_context("p1", null, root_context);
    controller.activate_position(0); // enter root => parent_stack contains root

    // Selected project removed => transient null selection keeps committed breadcrumb state.
    project_selection.set_selected(Gtk.INVALID_LIST_POSITION);
    controller.refresh();
    assert(crumbs != null);
    assert(crumbs.size >= 1);
    assert(crumbs[0].label == "Projects");
    assert(crumbs[crumbs.size - 1].label != "");
}

private void test_transient_null_selection_preserves_committed_breadcrumbs_when_store_changes() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var project_selection = new Gtk.SingleSelection(project_store);
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var controller = new HolderLinux.FlowboardController(project_store, project_selection, card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("root", "p1", "Root", 1024.0));

    Gee.ArrayList<HolderLinux.FlowboardBreadcrumbSegment>? crumbs = null;
    controller.breadcrumb_segments_changed.connect((segments) => {
        crumbs = segments;
    });

    // Prime current_project_id.
    controller.refresh();

    // Seed visible root tile without auto context loading.
    var context_cards = new Gee.ArrayList<HolderLinux.CardContextCard>();
    context_cards.add(new HolderLinux.CardContextCard("root", "p1", "Root", "root.md", 1024.0, null, 0, 0, 1));
    var context_crumbs = new Gee.ArrayList<HolderLinux.CardContextBreadcrumb>();
    context_crumbs.add(new HolderLinux.CardContextBreadcrumb("project", "Project One", "p1", null));
    var root_context = new HolderLinux.CardContextData(
        new HolderLinux.CardContextProject("p1", "Project One"),
        null,
        context_crumbs,
        context_cards
    );
    controller.apply_card_context("p1", null, root_context);
    controller.activate_position(0); // enter root => parent_stack contains root

    // Remove root before deselect. Breadcrumbs stay on last committed state.
    card_store.remove(0);
    project_selection.set_selected(Gtk.INVALID_LIST_POSITION);
    controller.refresh();

    assert(crumbs != null);
    assert(crumbs.size >= 1);
    assert(crumbs[0].label == "Projects");
    assert(crumbs[crumbs.size - 1].label != "");
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
    string moved_intent = "";
    string? moved_target = "__unset__";
    string toast = "";
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
        moved_card = card_id;
        moved_intent = intent;
        moved_target = target_card_id;
    });
    controller.toast_requested.connect((text) => {
        toast = text;
    });

    controller.refresh();
    controller.on_card_drop("a", "b", 0.5);

    assert(moved_card == "a");
    assert(moved_intent == "into");
    assert(moved_target == "b");
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

    string moved_intent = "";
    string? moved_target = null;
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
        if (card_id == "a") {
            moved_intent = intent;
            moved_target = target_card_id;
        }
    });

    controller.refresh();
    controller.on_card_drop("a", "b", 0.9);

    assert(moved_intent == "after");
    assert(moved_target == "b");
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

    string moved_intent = "";
    string? moved_parent = "__unset__";
    string toast = "";
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
        if (card_id == "child") {
            moved_intent = intent;
            moved_parent = parent_card_id;
        }
    });
    controller.toast_requested.connect((text) => {
        toast = text;
    });

    controller.refresh();
    controller.move_card_up_level_from_context_menu("child");

    assert(moved_intent == "up_level");
    assert(moved_parent == "root");
    assert(toast == "Moved Child into Root");
}

private void test_navigate_to_projects_mode_shows_project_tiles_in_store_order() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Alpha", 10, 1, 1));
    project_store.append(make_project("p2", "Beta", 20, 1, 2));
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
    assert(first.project_id == "p1");
    assert(first.child_count == 1);
    assert(second.project_id == "p2");
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

    assert(requested_project_id == "p1");
    var selected = project_selection.get_selected_item() as HolderLinux.Project;
    assert(selected != null);
    assert(selected.project_id == "p1");
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
    string moved_intent = "";
    string? moved_parent = "__unset__";
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
        moved_card = card_id;
        moved_intent = intent;
        moved_parent = parent_card_id;
    });

    controller.refresh();
    controller.on_background_drop("c");

    assert(moved_card == "c");
    assert(moved_intent == "to_end");
    assert(moved_parent == null);
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
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
        move_emits++;
    });

    controller.refresh();
    controller.on_card_drop("p", "c", 0.5);
    assert(move_emits == 0);
}

private void test_move_card_to_start_and_end_emit_expected_intents() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "Alpha", 1024.0));
    card_store.append(make_card("b", "p1", "Beta", 2048.0));
    card_store.append(make_card("c", "p1", "Gamma", 3072.0));

    bool saw_start = false;
    bool saw_end = false;
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
        if (card_id == "c" && intent == "to_start") saw_start = true;
        if (card_id == "a" && intent == "to_end") saw_end = true;
    });

    controller.refresh();
    controller.move_card_to_start_from_context_menu("c");
    controller.move_card_to_end_from_context_menu("a");

    assert(saw_start);
    assert(saw_end);
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

private void test_activate_tile_with_null_card_id_is_noop() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);

    int opened = 0;
    int overviews = 0;
    controller.card_open_requested.connect((card_id) => {
        opened++;
    });
    controller.project_overview_requested.connect((project_id) => {
        overviews++;
    });

    var invalid_tile = new HolderLinux.FlowboardTile(
        "invalid",
        "Invalid",
        0,
        false,
        null,
        null,
        null
    );
    controller.activate_tile(invalid_tile);

    assert(opened == 0);
    assert(overviews == 0);
    var selected = project_selection.get_selected_item() as HolderLinux.Project;
    assert(selected != null);
    assert(selected.project_id == "p1");
}

private void test_is_descendant_in_cards_null_candidate_is_false() {
    var source_cards = new Gee.ArrayList<HolderLinux.CardSummary?>();
    source_cards.add(make_card("a", "p1", "A", 1024.0));
    source_cards.add(make_card("b", "p1", "B", 2048.0, "a"));

    assert(!HolderLinux.FlowboardController.is_descendant_in_cards(source_cards, null, "a"));
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

private void test_open_card_from_context_menu_without_context_defaults_to_leaf() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var project_selection = new Gtk.SingleSelection(project_store);
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var controller = new HolderLinux.FlowboardController(project_store, project_selection, card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("orphan", "p1", "Orphan", 1024.0));

    string opened = "";
    int load_requests = 0;
    controller.card_open_requested.connect((card_id) => {
        opened = card_id;
    });
    controller.context_load_requested.connect((_project_id, _parent_id) => {
        load_requests++;
    });

    // No refresh/apply context here: fallback path should treat card as leaf.
    controller.open_card_from_context_menu("orphan");

    assert(opened == "orphan");
    assert(load_requests == 0);
}

private void test_open_card_from_context_menu_uses_context_child_count_for_hidden_container() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("root", "p1", "Root", 1024.0));
    card_store.append(make_card("child", "p1", "Child", 2048.0, "root"));

    string opened = "";
    string? last_parent_requested = "__unset__";
    controller.card_open_requested.connect((card_id) => {
        opened = card_id;
    });
    controller.context_load_requested.connect((_project_id, parent_id) => {
        last_parent_requested = parent_id;
    });

    controller.refresh();

    // Force fallback path (tile lookup miss) while keeping current_context populated.
    var model_store = controller.get_visible_model() as GLib.ListStore;
    assert(model_store != null);
    model_store.remove_all();

    controller.open_card_from_context_menu("root");

    assert(opened == "root");
    // "root" exists in context with child_count > 0, so fallback should treat it as container and navigate into it.
    assert(last_parent_requested == "root");
}

private void test_move_left_right_edge_cards_emit_relative_intents() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "Alpha", 1024.0));
    card_store.append(make_card("b", "p1", "Beta", 2048.0));
    card_store.append(make_card("c", "p1", "Gamma", 3072.0));

    int edge_moves = 0;
    string? left_intent = null;
    string? right_intent = null;
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
        if (card_id == "a") {
            edge_moves++;
            left_intent = intent;
        }
        if (card_id == "c") {
            edge_moves++;
            right_intent = intent;
        }
    });

    controller.refresh();
    controller.move_card_left_from_context_menu("a");
    controller.move_card_right_from_context_menu("c");
    assert(edge_moves == 2);
    assert(left_intent == "left");
    assert(right_intent == "right");
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

    string moved_intent = "";
    string? moved_target = null;
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
        if (card_id == "a") {
            moved_intent = intent;
            moved_target = target_card_id;
        }
    });

    controller.refresh();
    controller.on_card_drop("a", "b", 0.9);
    assert(moved_intent == "after");
    assert(moved_target == "b");
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
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => { move_emits++; });
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
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => { move_emits++; });

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

    string moved_intent = "";
    string? moved_target = null;
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
        if (card_id == "c") {
            moved_intent = intent;
            moved_target = target_card_id;
        }
    });

    controller.refresh();
    controller.on_card_drop("c", "b", 0.1);
    assert(moved_intent == "before");
    assert(moved_target == "b");
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
    string? first_intent = null;
    string? second_intent = null;
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
        if (card_id == "b") {
            b_moves++;
            if (b_moves == 1) {
                first_intent = intent;
            } else if (b_moves == 2) {
                second_intent = intent;
            }
        }
    });

    controller.refresh();
    controller.move_card_left_from_context_menu("b");
    controller.move_card_right_from_context_menu("b");
    assert(b_moves == 2);
    assert(first_intent == "left");
    assert(second_intent == "right");
}

private void test_move_card_to_start_single_sibling_emits_intent() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("only", "p1", "Only", 1024.0));

    int move_emits = 0;
    string? emitted_intent = null;
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
        move_emits++;
        emitted_intent = intent;
    });

    controller.refresh();
    controller.move_card_to_start_from_context_menu("only");
    assert(move_emits == 1);
    assert(emitted_intent == "to_start");
}

private void test_navigate_up_from_depth_two_keeps_parent_context() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "A", 1024.0));
    card_store.append(make_card("b", "p1", "B", 1024.0, "a"));
    card_store.append(make_card("c", "p1", "C", 1024.0, "b"));

    controller.refresh();
    controller.activate_position(0); // enter A -> shows B
    controller.activate_position(0); // enter B -> shows C
    controller.navigate_up();        // back to A context -> should show B

    var model = controller.get_visible_model();
    assert(model.get_n_items() == 1);
    var only = tile_at(model, 0);
    assert(only != null);
    assert(only.card_id == "b");
}

private void test_navigate_to_parent_breadcrumb_trims_stack() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "A", 1024.0));
    card_store.append(make_card("b", "p1", "B", 1024.0, "a"));
    card_store.append(make_card("c", "p1", "C", 1024.0, "b"));

    controller.refresh();
    controller.activate_position(0); // enter A
    controller.activate_position(0); // enter B
    controller.navigate_to_breadcrumb_index(2); // Projects / Project / A

    var model = controller.get_visible_model();
    assert(model.get_n_items() == 1);
    var only = tile_at(model, 0);
    assert(only != null);
    assert(only.card_id == "b");
}

private void test_projects_mode_preserves_store_order_when_timestamps_tie() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p2", "zeta", 10));
    project_store.append(make_project("p1", "Alpha", 10));
    project_store.append(make_project("p3", "alpha", 10));
    project_selection.set_selected(0);

    controller.refresh();
    controller.navigate_to_breadcrumb_index(0);

    var model = controller.get_visible_model();
    assert(model.get_n_items() == 3);
    var first = tile_at(model, 0);
    var second = tile_at(model, 1);
    var third = tile_at(model, 2);
    assert(first != null && second != null && third != null);
    assert(first.project_id == "p2");
    assert(second.project_id == "p1");
    assert(third.project_id == "p3");
}

private void test_equal_sort_key_preserves_backend_context_order() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("old", "p1", "Old", 1024.0, null, 1));
    card_store.append(make_card("new", "p1", "New", 1024.0, null, 2));

    controller.refresh();
    var model = controller.get_visible_model();
    assert(model.get_n_items() == 2);
    var first = tile_at(model, 0);
    var second = tile_at(model, 1);
    assert(first != null && second != null);
    assert(first.card_id == "old");
    assert(second.card_id == "new");
}

private void test_drop_right_edge_on_last_card_uses_tail_padding() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("a", "p1", "Alpha", 1024.0));
    card_store.append(make_card("b", "p1", "Beta", 2048.0));
    card_store.append(make_card("c", "p1", "Gamma", 3072.0));

    string moved_intent = "";
    string? moved_target = null;
    controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
        if (card_id == "a") {
            moved_intent = intent;
            moved_target = target_card_id;
        }
    });

    controller.refresh();
    controller.on_card_drop("a", "c", 0.95);
    assert(moved_intent == "after");
    assert(moved_target == "c");
}

private void test_equal_sort_key_inverse_insertion_still_prefers_newer_card() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("new", "p1", "New", 1024.0, null, 2));
    card_store.append(make_card("old", "p1", "Old", 1024.0, null, 1));

    controller.refresh();
    var model = controller.get_visible_model();
    assert(model.get_n_items() == 2);
    var first = tile_at(model, 0);
    var second = tile_at(model, 1);
    assert(first != null && second != null);
    assert(first.card_id == "new");
    assert(second.card_id == "old");
}

private void test_projects_mode_preserves_store_order_for_mixed_timestamps() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "One", 30));
    project_store.append(make_project("p2", "Two", 10));
    project_store.append(make_project("p3", "Three", 50));
    project_store.append(make_project("p4", "Four", 20));
    project_store.append(make_project("p5", "Five", 40));
    project_selection.set_selected(0);

    controller.refresh();
    controller.navigate_to_breadcrumb_index(0);

    var model = controller.get_visible_model();
    assert(model.get_n_items() == 5);
    var first = tile_at(model, 0);
    var second = tile_at(model, 1);
    var third = tile_at(model, 2);
    var fourth = tile_at(model, 3);
    var fifth = tile_at(model, 4);
    assert(first != null && second != null && third != null && fourth != null && fifth != null);
    assert(first.project_id == "p1");
    assert(second.project_id == "p2");
    assert(third.project_id == "p3");
    assert(fourth.project_id == "p4");
    assert(fifth.project_id == "p5");
}

private void test_focus_card_container_enters_selected_card_level() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);

    card_store.append(make_card("root", "p1", "Root", 1024.0));
    card_store.append(make_card("child-a", "p1", "Child A", 2048.0, "root"));
    card_store.append(make_card("child-b", "p1", "Child B", 3072.0, "root"));

    controller.refresh();
    controller.focus_card("root");

    var model = controller.get_visible_model();
    assert(model.get_n_items() == 2);
    var first = tile_at(model, 0);
    var second = tile_at(model, 1);
    assert(first != null && second != null);
    assert(first.card_id == "child-a");
    assert(second.card_id == "child-b");
}

private void test_focus_card_leaf_shows_parent_level() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);

    card_store.append(make_card("root", "p1", "Root", 1024.0));
    card_store.append(make_card("leaf-a", "p1", "Leaf A", 2048.0, "root"));
    card_store.append(make_card("leaf-b", "p1", "Leaf B", 3072.0, "root"));

    controller.refresh();
    controller.focus_card("leaf-b");

    var model = controller.get_visible_model();
    assert(model.get_n_items() == 2);
    var first = tile_at(model, 0);
    var second = tile_at(model, 1);
    assert(first != null && second != null);
    assert(first.card_id == "leaf-a");
    assert(second.card_id == "leaf-b");
}

private void test_focus_missing_card_is_noop() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("root", "p1", "Root", 1024.0));

    controller.refresh();
    controller.focus_card("missing");

    assert(controller.is_showing_project_root_level());
    assert(!controller.is_showing_projects_root());
    var model = controller.get_visible_model();
    assert(model.get_n_items() == 1);
    var only = tile_at(model, 0);
    assert(only != null);
    assert(only.card_id == "root");
}

private void test_root_mode_getters_reflect_projects_and_nested_states() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("parent", "p1", "Parent", 1024.0));
    card_store.append(make_card("child", "p1", "Child", 2048.0, "parent"));

    controller.refresh();
    assert(controller.is_showing_project_root_level());
    assert(!controller.is_showing_projects_root());

    controller.navigate_to_breadcrumb_index(0);
    assert(controller.is_showing_projects_root());
    assert(!controller.is_showing_project_root_level());

    controller.focus_card("parent");
    assert(!controller.is_showing_projects_root());
    assert(!controller.is_showing_project_root_level());
}

private void test_focus_card_handles_non_card_entries_when_detecting_children() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var project_selection = new Gtk.SingleSelection(project_store);
    var card_store = new GLib.ListStore(typeof(GLib.Object));
    var controller = new HolderLinux.FlowboardController(project_store, project_selection, card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(new GLib.Object());
    card_store.append(make_card("parent", "p1", "Parent", 1024.0));
    card_store.append(make_card("child", "p1", "Child", 2048.0, "parent"));

    controller.context_load_requested.connect((project_id, parent_card_id) => {
        var context = build_context_for_request(project_store, card_store, project_id, parent_card_id);
        controller.apply_card_context(project_id, parent_card_id, context);
    });

    controller.focus_card("parent");

    var model = controller.get_visible_model();
    assert(model.get_n_items() == 1);
    var only = tile_at(model, 0);
    assert(only != null);
    assert(only.card_id == "child");
}

private void test_focus_orphan_leaf_rebuilds_parent_stack_until_missing_parent() {
    GLib.ListStore project_store;
    Gtk.SingleSelection project_selection;
    GLib.ListStore card_store;
    var controller = make_controller(out project_store, out project_selection, out card_store);

    project_store.append(make_project("p1", "Project One", 10));
    project_selection.set_selected(0);
    card_store.append(make_card("sibling", "p1", "Sibling", 1024.0));
    card_store.append(make_card("orphan", "p1", "Orphan", 2048.0, "missing-parent"));

    controller.focus_card("orphan");
    assert(controller.is_showing_project_root_level());

    var root_model = controller.get_visible_model();
    assert(root_model.get_n_items() == 1);
    var only = tile_at(root_model, 0);
    assert(only != null);
    assert(only.card_id == "sibling");
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/flowboard/refresh_without_selected_project_shows_empty_state",
                  test_refresh_without_selected_project_shows_empty_state);
    Test.add_func("/flowboard/refresh_selected_project_uses_backend_context_order",
                  test_refresh_selected_project_uses_backend_context_order);
    Test.add_func("/flowboard/refresh_selected_project_without_context_shows_loading_state",
                  test_refresh_selected_project_without_context_shows_loading_state);
    Test.add_func("/flowboard/refresh_pending_context_keeps_committed_tiles_visible",
                  test_refresh_pending_context_keeps_committed_tiles_visible);
    Test.add_func("/flowboard/transient_null_selection_keeps_committed_board",
                  test_transient_null_project_selection_keeps_committed_board);
    Test.add_func("/flowboard/apply_card_context_guard_when_showing_projects",
                  test_apply_card_context_guard_when_showing_projects);
    Test.add_func("/flowboard/apply_card_context_guard_when_current_project_not_initialized",
                  test_apply_card_context_guard_when_current_project_not_initialized);
    Test.add_func("/flowboard/apply_card_context_guard_when_project_mismatch",
                  test_apply_card_context_guard_when_project_mismatch);
    Test.add_func("/flowboard/apply_card_context_guard_when_parent_mismatch",
                  test_apply_card_context_guard_when_parent_mismatch);
    Test.add_func("/flowboard/replace_visible_with_projects_skips_non_project_items",
                  test_replace_visible_with_projects_skips_non_project_items);
    Test.add_func("/flowboard/breadcrumbs_in_projects_mode_are_just_projects",
                  test_breadcrumbs_in_projects_mode_are_just_projects);
    Test.add_func("/flowboard/breadcrumbs_from_context_skip_empty_titles",
                  test_breadcrumbs_from_context_skip_empty_titles);
    Test.add_func("/flowboard/transient_null_selection_preserves_committed_breadcrumbs",
                  test_transient_null_selection_preserves_committed_breadcrumbs);
    Test.add_func("/flowboard/transient_null_selection_preserves_committed_breadcrumbs_when_store_changes",
                  test_transient_null_selection_preserves_committed_breadcrumbs_when_store_changes);
    Test.add_func("/flowboard/activate_container_enters_it_and_backspace_returns",
                  test_activate_container_enters_it_and_backspace_returns);
    Test.add_func("/flowboard/drop_center_nests_and_emits_move_and_toast",
                  test_drop_center_nests_and_emits_move_and_toast);
    Test.add_func("/flowboard/drop_right_edge_reorders_next_to_target",
                  test_drop_right_edge_reorders_next_to_target);
    Test.add_func("/flowboard/move_card_up_level_uses_grandparent_and_toast",
                  test_move_card_up_level_uses_grandparent_and_toast);
    Test.add_func("/flowboard/navigate_to_projects_mode_shows_project_tiles_in_store_order",
                  test_navigate_to_projects_mode_shows_project_tiles_in_store_order);
    Test.add_func("/flowboard/activate_project_tile_selects_and_requests_overview",
                  test_activate_project_tile_selects_and_requests_overview);
    Test.add_func("/flowboard/request_create_card_here_emits_and_honors_guards",
                  test_request_create_card_here_emits_and_honors_guards);
    Test.add_func("/flowboard/on_background_drop_moves_card_to_project_root",
                  test_on_background_drop_moves_card_to_project_root);
    Test.add_func("/flowboard/on_card_drop_prevents_descendant_cycle",
                  test_on_card_drop_prevents_descendant_cycle);
    Test.add_func("/flowboard/move_card_to_start_and_end_emit_expected_intents",
                  test_move_card_to_start_and_end_emit_expected_intents);
    Test.add_func("/flowboard/projects_mode_with_no_projects_shows_empty_projects_message",
                  test_projects_mode_with_no_projects_shows_empty_projects_message);
    Test.add_func("/flowboard/breadcrumb_index_one_requests_project_overview",
                  test_breadcrumb_index_one_requests_project_overview);
    Test.add_func("/flowboard/refresh_clears_missing_current_parent",
                  test_refresh_clears_missing_current_parent);
    Test.add_func("/flowboard/activate_position_out_of_range_is_noop",
                  test_activate_position_out_of_range_is_noop);
    Test.add_func("/flowboard/activate_tile_with_null_card_id_is_noop",
                  test_activate_tile_with_null_card_id_is_noop);
    Test.add_func("/flowboard/is_descendant_in_cards_null_candidate_is_false",
                  test_is_descendant_in_cards_null_candidate_is_false);
    Test.add_func("/flowboard/open_card_from_context_menu_leaf_opens_without_navigation",
                  test_open_card_from_context_menu_leaf_opens_without_navigation);
    Test.add_func("/flowboard/open_card_from_context_menu_without_context_defaults_to_leaf",
                  test_open_card_from_context_menu_without_context_defaults_to_leaf);
    Test.add_func("/flowboard/open_card_from_context_menu_uses_context_child_count_for_hidden_container",
                  test_open_card_from_context_menu_uses_context_child_count_for_hidden_container);
    Test.add_func("/flowboard/move_left_right_edge_cards_emit_relative_intents",
                  test_move_left_right_edge_cards_emit_relative_intents);
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
    Test.add_func("/flowboard/move_card_to_start_single_sibling_emits_intent",
                  test_move_card_to_start_single_sibling_emits_intent);
    Test.add_func("/flowboard/navigate_up_from_depth_two_keeps_parent_context",
                  test_navigate_up_from_depth_two_keeps_parent_context);
    Test.add_func("/flowboard/navigate_to_parent_breadcrumb_trims_stack",
                  test_navigate_to_parent_breadcrumb_trims_stack);
    Test.add_func("/flowboard/projects_mode_preserves_store_order_when_timestamps_tie",
                  test_projects_mode_preserves_store_order_when_timestamps_tie);
    Test.add_func("/flowboard/equal_sort_key_preserves_backend_context_order",
                  test_equal_sort_key_preserves_backend_context_order);
    Test.add_func("/flowboard/drop_right_edge_on_last_card_uses_tail_padding",
                  test_drop_right_edge_on_last_card_uses_tail_padding);
    Test.add_func("/flowboard/equal_sort_key_inverse_insertion_still_prefers_newer_card",
                  test_equal_sort_key_inverse_insertion_still_prefers_newer_card);
    Test.add_func("/flowboard/projects_mode_preserves_store_order_for_mixed_timestamps",
                  test_projects_mode_preserves_store_order_for_mixed_timestamps);
    Test.add_func("/flowboard/focus_card_container_enters_selected_card_level",
                  test_focus_card_container_enters_selected_card_level);
    Test.add_func("/flowboard/focus_card_leaf_shows_parent_level",
                  test_focus_card_leaf_shows_parent_level);
    Test.add_func("/flowboard/focus_missing_card_is_noop",
                  test_focus_missing_card_is_noop);
    Test.add_func("/flowboard/root_mode_getters_reflect_projects_and_nested_states",
                  test_root_mode_getters_reflect_projects_and_nested_states);
    Test.add_func("/flowboard/focus_card_handles_non_card_entries_when_detecting_children",
                  test_focus_card_handles_non_card_entries_when_detecting_children);
    Test.add_func("/flowboard/focus_orphan_leaf_rebuilds_parent_stack_until_missing_parent",
                  test_focus_orphan_leaf_rebuilds_parent_stack_until_missing_parent);

    return Test.run();
}

}
