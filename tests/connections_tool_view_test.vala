using GLib;

namespace HolderLinuxTests {

private const uint DEBOUNCE_MS = HolderLinux.ConnectionsRefreshPlanner.GRAPH_REFRESH_DEBOUNCE_MS;

// Polls until the predicate holds, firing the view's pending refresh debounce on every poll.
private bool wait_until_true(owned SourceFunc predicate, TestScheduler scheduler, int timeout_ms = 2000) {
    var loop = new MainLoop(null, false);
    var deadline = GLib.get_monotonic_time() + (int64) timeout_ms * 1000;
    Timeout.add(5, () => {
        scheduler.run_due(DEBOUNCE_MS);
        if (predicate()) {
            loop.quit();
            return Source.REMOVE;
        }
        if (GLib.get_monotonic_time() >= deadline) {
            loop.quit();
            return Source.REMOVE;
        }
        return Source.CONTINUE;
    });
    loop.run();
    return predicate();
}

// Runs the main loop until idle without advancing time, so anything the view queued behind its
// debounce stays queued.
private void settle_main_loop() {
    while (MainContext.default().iteration(false)) {}
}

// Fires the refresh debounce and lets the refresh finish, until nothing is left.
private void drain_view(TestScheduler scheduler) {
    for (int i = 0; i < 50; i++) {
        var fired = scheduler.run_due(DEBOUNCE_MS);
        settle_main_loop();
        if (fired == 0 && scheduler.pending_with_delay(DEBOUNCE_MS) == 0) {
            return;
        }
    }
    assert_not_reached();
}

private bool widget_tree_contains_label_text(Gtk.Widget? widget, string needle) {
    if (widget == null) {
        return false;
    }
    if (widget is Gtk.Label) {
        var label = widget as Gtk.Label;
        if (label != null && label.get_text().contains(needle)) {
            return true;
        }
    }
    for (var child = widget.get_first_child(); child != null; child = child.get_next_sibling()) {
        if (widget_tree_contains_label_text(child, needle)) {
            return true;
        }
    }
    return false;
}

private bool logs_contain(Gee.ArrayList<string> logs, string needle) {
    foreach (var line in logs) {
        if (line.contains(needle)) {
            return true;
        }
    }
    return false;
}

private HolderLinux.Project project(string id, string name) {
    return new HolderLinux.Project(id, name, "plain", "/tmp/%s".printf(id), 1, 1);
}

private HolderLinux.CardSummary card(string id,
                                     string project_id,
                                     string title,
                                     double sort_key,
                                     string? parent_card_id = null,
                                     int64 updated_at = 100) {
    return new HolderLinux.CardSummary(
        id,
        project_id,
        title,
        "cards/%s.md".printf(id),
        sort_key,
        parent_card_id,
        1,
        updated_at
    );
}

private void test_hidden_connections_tool_does_not_refresh_until_visible() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var view = new HolderLinux.ConnectionsToolView(scheduler);

    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    project_store.append(project("p1", "Project"));
    var project_selection = new Gtk.SingleSelection(project_store);
    project_selection.set_selected(0);

    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    card_store.append(card("c1", "p1", "Card One", 10));
    card_store.append(card("c2", "p1", "Card Two", 20));
    var card_selection = new Gtk.SingleSelection(card_store);
    card_selection.set_selected(0);

    view.set_api_client(api);
    view.bind_context(project_selection, card_store, card_selection);

    // Hidden: the refresh is held back, not merely delayed.
    assert(scheduler.pending_one_shots() == 0);
    drain_view(scheduler);
    assert(api.list_card_links_calls == 0);
    assert(api.list_card_backlinks_calls == 0);

    view.set_tool_visible(true);
    assert(scheduler.pending_with_delay(DEBOUNCE_MS) == 1);
    assert(wait_until_true(() => {
        return api.list_card_links_calls == 1 && api.list_card_backlinks_calls == 1;
    }, scheduler));

    view.set_tool_visible(false);
    card_selection.set_selected(1);

    assert(scheduler.pending_one_shots() == 0);
    drain_view(scheduler);
    assert(api.list_card_links_calls == 1);
    assert(api.list_card_backlinks_calls == 1);

    view.set_tool_visible(true);
    assert(wait_until_true(() => {
        return api.list_card_links_calls == 2 && api.list_card_backlinks_calls == 2;
    }, scheduler));
}

private void test_visible_connections_refresh_is_debounced() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var view = new HolderLinux.ConnectionsToolView(scheduler);

    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    project_store.append(project("p1", "Project"));
    var project_selection = new Gtk.SingleSelection(project_store);
    project_selection.set_selected(0);

    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    card_store.append(card("c1", "p1", "Card One", 10));
    card_store.append(card("c2", "p1", "Card Two", 20));
    card_store.append(card("c3", "p1", "Card Three", 30));
    var card_selection = new Gtk.SingleSelection(card_store);
    card_selection.set_selected(0);

    view.set_api_client(api);
    view.bind_context(project_selection, card_store, card_selection);
    view.set_tool_visible(true);

    assert(wait_until_true(() => {
        return api.list_card_links_calls == 1 && api.list_card_backlinks_calls == 1;
    }, scheduler));

    card_selection.set_selected(1);
    card_selection.set_selected(2);
    card_selection.set_selected(0);

    // Three selection changes, one pending debounce, nothing loaded yet.
    settle_main_loop();
    assert(scheduler.pending_with_delay(DEBOUNCE_MS) == 1);
    assert(api.list_card_links_calls == 1);
    assert(api.list_card_backlinks_calls == 1);

    assert(wait_until_true(() => {
        return api.list_card_links_calls == 2 && api.list_card_backlinks_calls == 2;
    }, scheduler));
    drain_view(scheduler);
    assert(api.list_card_links_calls == 2);
}

private void test_visible_connections_refresh_is_single_flight_for_latest_selection() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var view = new HolderLinux.ConnectionsToolView(scheduler);

    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    project_store.append(project("p1", "Project"));
    var project_selection = new Gtk.SingleSelection(project_store);
    project_selection.set_selected(0);

    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    card_store.append(card("c1", "p1", "Card One", 10));
    card_store.append(card("c2", "p1", "Card Two", 20));
    card_store.append(card("c3", "p1", "Card Three", 30));
    var card_selection = new Gtk.SingleSelection(card_store);
    card_selection.set_selected(0);

    view.set_api_client(api);
    view.bind_context(project_selection, card_store, card_selection);
    view.set_tool_visible(true);

    assert(wait_until_true(() => {
        return api.list_card_links_calls == 1 && api.list_card_backlinks_calls == 1;
    }, scheduler));

    // The selection changes while the second load is in flight.
    var interrupted = false;
    var loaded = new Gee.ArrayList<string>();
    api.list_card_links_hook = (card_id) => {
        loaded.add(card_id);
        if (!interrupted) {
            interrupted = true;
            card_selection.set_selected(2);
            card_selection.set_selected(0);
        }
    };
    card_selection.set_selected(1);

    // One debounce is pending and nothing has been loaded for the new selection yet.
    assert(scheduler.pending_with_delay(DEBOUNCE_MS) == 1);
    assert(loaded.size == 0);

    // Fire only that debounce: the load of Card Two starts, and the hook changes the selection
    // twice while it is in flight.
    assert(scheduler.run_due(DEBOUNCE_MS) == 1);
    assert(wait_for_condition(() => {
        return api.list_card_links_calls == 2 && api.list_card_backlinks_calls == 2;
    }));
    assert(interrupted);
    assert(api.max_list_card_links_in_flight == 1);
    // The two changes made during the flight coalesced into a single refresh queued behind it.
    assert(scheduler.pending_with_delay(DEBOUNCE_MS) == 1);
    assert(api.list_card_links_calls == 2);

    assert(scheduler.run_due(DEBOUNCE_MS) == 1);
    assert(wait_for_condition(() => {
        return api.list_card_links_calls == 3 && api.list_card_backlinks_calls == 3;
    }));
    drain_view(scheduler);

    // Card Two was loaded first (interrupted), then the latest selection, Card One; the
    // intermediate Card Three was never loaded, and only one load was ever in flight.
    assert(loaded.size == 2);
    assert(loaded[0] == "c2");
    assert(loaded[1] == "c1");
    assert(api.list_card_links_calls == 3);
    assert(api.max_list_card_links_in_flight == 1);
}

private void test_stale_project_graph_refresh_result_is_dropped_when_generation_changes() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var view = new HolderLinux.ConnectionsToolView(scheduler);

    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    project_store.append(project("p1", "Project One"));
    project_store.append(project("p2", "Project Two"));
    var project_selection = new Gtk.SingleSelection(project_store);
    project_selection.set_selected(1);

    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    card_store.append(card("p1-card", "p1", "P1 Unique Node", 10));
    card_store.append(card("p2-card", "p2", "P2 Unique Node", 10));
    var card_selection = new Gtk.SingleSelection(card_store);
    card_selection.set_autoselect(false);
    card_selection.set_can_unselect(true);
    card_selection.set_selected(Gtk.INVALID_LIST_POSITION);

    view.set_api_client(api);
    view.bind_context(project_selection, card_store, card_selection);
    view.set_tool_visible(true);

    assert(wait_until_true(() => {
        return api.list_card_links_calls == 1
            && widget_tree_contains_label_text(view.get_content_widget(), "P2 Unique Node");
    }, scheduler));

    // Project One starts loading, and the selection returns to Project Two while it is in flight.
    var interrupted = false;
    api.list_card_links_hook = (card_id) => {
        if (!interrupted && card_id == "p1-card") {
            interrupted = true;
            project_selection.set_selected(1);
        }
    };
    project_selection.set_selected(0);

    assert(wait_until_true(() => {
        return api.list_card_links_calls == 3
            && widget_tree_contains_label_text(view.get_content_widget(), "P2 Unique Node")
            && !widget_tree_contains_label_text(view.get_content_widget(), "P1 Unique Node");
    }, scheduler));
    assert(interrupted);
}

private void test_duplicate_refresh_triggers_for_same_effective_target_are_suppressed() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var view = new HolderLinux.ConnectionsToolView(scheduler);

    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    project_store.append(project("p1", "Project"));
    var project_selection = new Gtk.SingleSelection(project_store);
    project_selection.set_selected(0);

    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    card_store.append(card("c1", "p1", "Card One", 10));
    var card_selection = new Gtk.SingleSelection(card_store);
    card_selection.set_selected(0);

    view.set_api_client(api);
    view.bind_context(project_selection, card_store, card_selection);
    view.set_tool_visible(true);

    assert(wait_until_true(() => {
        return api.list_card_links_calls == 1 && api.list_card_backlinks_calls == 1;
    }, scheduler));

    view.set_api_client(api);
    assert(scheduler.pending_one_shots() == 0);
    drain_view(scheduler);
    assert(api.list_card_links_calls == 1);
    assert(api.list_card_backlinks_calls == 1);

    var internal_links = new Gee.ArrayList<string>();
    internal_links.add("Card One");
    view.set_internal_links(internal_links);
    assert(wait_until_true(() => {
        return api.list_card_links_calls == 2 && api.list_card_backlinks_calls == 2;
    }, scheduler));

    var same_internal_links = new Gee.ArrayList<string>();
    same_internal_links.add("Card One");
    view.set_internal_links(same_internal_links);
    assert(scheduler.pending_one_shots() == 0);
    drain_view(scheduler);
    assert(api.list_card_links_calls == 2);
    assert(api.list_card_backlinks_calls == 2);
}

private void test_debug_logs_cover_skipped_suppressed_stale_and_coalesced_refreshes() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var view = new HolderLinux.ConnectionsToolView(scheduler);
    var logs = new Gee.ArrayList<string>();
    view.debug_log_requested.connect((line) => {
        logs.add(line);
    });

    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    project_store.append(project("p1", "Project"));
    var project_selection = new Gtk.SingleSelection(project_store);
    project_selection.set_selected(0);

    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    card_store.append(card("c1", "p1", "Card One", 10));
    card_store.append(card("c2", "p1", "Card Two", 20));
    card_store.append(card("c3", "p1", "Card Three", 30));
    var card_selection = new Gtk.SingleSelection(card_store);
    card_selection.set_selected(0);

    view.set_api_client(api);
    view.bind_context(project_selection, card_store, card_selection);

    card_selection.set_selected(1);
    assert(wait_until_true(() => {
        return logs_contain(logs, "suppressed while hidden");
    }, scheduler));

    view.set_tool_visible(true);
    assert(wait_until_true(() => {
        return api.list_card_links_calls == 1 && api.list_card_backlinks_calls == 1;
    }, scheduler));

    view.set_api_client(api);
    assert(wait_until_true(() => {
        return logs_contain(logs, "skipped unchanged target");
    }, scheduler));

    // The selection changes back while the load for the third card is in flight.
    var interrupted = false;
    api.list_card_links_hook = (card_id) => {
        if (!interrupted) {
            interrupted = true;
            card_selection.set_selected(0);
        }
    };
    card_selection.set_selected(2);
    assert(wait_until_true(() => {
        return logs_contain(logs, "coalesced after in-flight refresh")
            && logs_contain(logs, "dropped stale card result");
    }, scheduler));
    assert(interrupted);
}

private void test_the_default_relations_split_waits_for_a_width_and_is_applied_once() {
    var h = new ConnectionsViewHarness();
    var pane = cv_find_paned(h.content());
    assert(pane != null);
    var paned = (!) pane;
    // Building the view queued exactly one repeating layout check.
    assert(h.scheduler.pending_repeating() == 1);
    var initial = paned.get_position();

    // No width yet (the harness window is never shown): the check stays queued and changes nothing.
    assert(paned.get_width() == 0);
    assert(h.scheduler.tick_repeating() == 1);
    assert(h.scheduler.pending_repeating() == 1);
    assert(paned.get_position() == initial);

    // Give the pane a width the way a layout pass would.
    paned.allocate(1200, 600, -1, null);
    assert(paned.get_width() == 1200);

    assert(h.scheduler.tick_repeating() == 1);
    assert(paned.get_position() == HolderLinux.ConnectionsBoardPresenter.default_relations_split_position(1200));
    assert(h.scheduler.pending_repeating() == 0);

    // Applied once: nothing is left queued, so a later divider position is never overwritten.
    paned.set_position(100);
    assert(h.scheduler.tick_repeating() == 0);
    assert(paned.get_position() == 100);
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping connections tool view tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    register_connections_view_relations_tests();
    register_connections_view_addlink_tests();
    register_connections_view_board_tests();

    Test.add_func("/holder/connections-tool-view/hidden-refresh-suppressed-until-visible",
                  test_hidden_connections_tool_does_not_refresh_until_visible);
    Test.add_func("/holder/connections-tool-view/visible-refresh-debounced",
                  test_visible_connections_refresh_is_debounced);
    Test.add_func("/holder/connections-tool-view/visible-refresh-single-flight-latest-selection",
                  test_visible_connections_refresh_is_single_flight_for_latest_selection);
    Test.add_func("/holder/connections-tool-view/stale-project-refresh-dropped-on-generation-change",
                  test_stale_project_graph_refresh_result_is_dropped_when_generation_changes);
    Test.add_func("/holder/connections-tool-view/duplicate-effective-target-refresh-suppressed",
                  test_duplicate_refresh_triggers_for_same_effective_target_are_suppressed);
    Test.add_func("/holder/connections-tool-view/default-split-waits-for-width",
                  test_the_default_relations_split_waits_for_a_width_and_is_applied_once);
    Test.add_func("/holder/connections-tool-view/debug-logs-cover-refresh-scheduler-decisions",
                  test_debug_logs_cover_skipped_suppressed_stale_and_coalesced_refreshes);

    return Test.run();
}

}
