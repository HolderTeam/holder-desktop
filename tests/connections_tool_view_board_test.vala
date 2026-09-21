using GLib;

namespace HolderLinuxTests {

private const string CVB_NO_CARDS = "No cards in this project yet.";

private void cvb_settle(uint duration_ms = 400) {
    var loop = new MainLoop();
    Timeout.add(duration_ms, () => {
        loop.quit();
        return Source.REMOVE;
    });
    loop.run();
}

// Polls the structure label while a test runs, remembering whether it ever showed a given text.
private class CvbTextWatcher : Object {
    public bool seen { get; set; default = false; }
    private uint source_id = 0;

    public CvbTextWatcher(ConnectionsViewHarness harness, string text) {
        source_id = Timeout.add(5, () => {
            if (cv_structure_label(harness.content()).get_text() == text) {
                seen = true;
            }
            return Source.CONTINUE;
        });
    }

    public void stop() {
        if (source_id != 0) {
            Source.remove(source_id);
            source_id = 0;
        }
    }
}

private ConnectionsViewHarness cvb_project_harness(int root_card_count = 3, bool start = true) {
    var h = new ConnectionsViewHarness();
    h.project_store.append(cv_project("p1", "Project One", root_card_count));
    h.project_store.append(cv_project("p2", "Project Two", 1));
    h.projects.set_selected(0);
    h.card_store.append(cv_card("c1", "p1", "Card One", 10));
    h.card_store.append(cv_card("c2", "p1", "Card Two", 20));
    h.card_store.append(cv_card("c3", "p1", "Card Three", 30));
    h.card_store.append(cv_card("x1", "p2", "Other Card", 10));
    if (start) {
        h.start();
    }
    return h;
}

private void test_no_projects_means_a_hint_to_select_one() {
    var h = new ConnectionsViewHarness();
    h.start();

    assert(h.wait_for_empty_text("Select a project to view connections."));
    assert(cv_node_buttons(h.content()).size == 0);
    assert(!h.add_button().get_sensitive());
}

private void test_losing_the_project_keeps_the_board_that_is_already_drawn() {
    var h = cvb_project_harness();
    assert(h.wait_for_nodes(3));

    // Selection passes through "nothing selected" while projects reload; keep what is drawn.
    h.project_store.remove_all();
    assert(h.projects.get_selected_item() == null);
    cvb_settle();

    assert(cv_node_buttons(h.content()).size == 3);
    assert(!cv_empty_label(h.content()).get_visible());
}

private void test_a_card_from_another_project_is_treated_as_no_card() {
    var h = cvb_project_harness(3, false);
    h.cards.set_selected(0);
    h.projects.set_selected(1);
    h.start();

    // Card One belongs to project one, so the board shows project two's cards instead.
    assert(h.wait_for_nodes(1));
    assert(cv_node_titles(h.content()).contains("Other Card"));
    assert(wait_for_condition(() => h.api.list_card_links_calls == 1));
    assert(h.api.list_card_backlinks_calls == 0);
}

private void test_a_project_board_without_an_api_says_so() {
    var h = cvb_project_harness(3, false);
    h.start(false);

    assert(h.wait_for_empty_text("API unavailable."));
    assert(cv_node_buttons(h.content()).size == 0);
    assert(cv_eq(cv_structure_label(h.content()).get_text(), "API unavailable."));
}

private void test_a_failed_card_load_reports_it_when_nothing_is_drawn() {
    var h = cvb_project_harness(3, false);
    h.api.fail_list_card_links = true;
    h.cards.set_selected(0);
    h.start();

    assert(h.wait_for_empty_text("Failed to load outgoing links."));
    assert(h.wait_for_log("Graph links refresh failed: list card links failed"));
    assert(cv_node_buttons(h.content()).size == 0);
}

private void test_a_failed_card_load_keeps_an_existing_board() {
    var h = cvb_project_harness(3, false);
    h.cards.set_selected(0);
    h.api.card_links.add(cv_link("c1", "c2", "ref"));
    h.start();
    assert(h.wait_for_nodes(2));

    h.api.fail_list_card_links = true;
    var links = new Gee.ArrayList<string>();
    links.add("Card Three");
    h.view.set_internal_links(links);

    assert(h.wait_for_log("Graph links refresh failed: list card links failed"));
    assert(cv_node_buttons(h.content()).size == 2);
    assert(!cv_empty_label(h.content()).get_visible());
}

private void test_a_failed_project_load_reports_it_when_nothing_is_drawn() {
    var h = cvb_project_harness(3, false);
    h.api.fail_list_card_links = true;
    h.start();

    assert(h.wait_for_empty_text("Failed to load project graph links."));
    assert(h.wait_for_log("Project graph links refresh failed: list card links failed"));
    assert(cv_node_buttons(h.content()).size == 0);
}

private void test_a_failed_project_load_keeps_an_existing_board() {
    var h = cvb_project_harness();
    assert(h.wait_for_nodes(3));

    h.api.fail_list_card_links = true;
    h.card_store.append(cv_card("c4", "p1", "Card Four", 40));

    assert(h.wait_for_log("Project graph links refresh failed: list card links failed"));
    assert(cv_node_buttons(h.content()).size == 3);
    assert(!cv_empty_label(h.content()).get_visible());
}

private void test_project_links_only_count_cards_of_the_same_project() {
    var h = cvb_project_harness(3, false);
    var from_c1 = new Gee.ArrayList<HolderLinux.CardLink>();
    from_c1.add(cv_link("c1", "x1", "ref"));
    from_c1.add(cv_link("c1", "r1", "ref", "resource"));
    from_c1.add(cv_link("c1", "c2", "depends_on"));
    h.api.card_links_by_source = new Gee.HashMap<string, Gee.ArrayList<HolderLinux.CardLink>>();
    ((!) h.api.card_links_by_source).set("c1", from_c1);
    h.start();

    assert(h.wait_for_nodes(3));
    // Only the c1 -> c2 link stays inside the project (plus the two sibling "next" edges); the link
    // to another project's card and the link to a resource are dropped.
    assert(cv_eq(cv_structure_label(h.content()).get_text(), "• next: 2\n• depends_on: 1"));
    assert(h.api.list_card_links_calls == 3);
}

private void test_an_empty_project_says_so_straight_away() {
    var h = new ConnectionsViewHarness();
    h.project_store.append(cv_project("p1", "Empty Project", 0));
    h.projects.set_selected(0);
    h.start();

    assert(h.wait_for_empty_text(CVB_NO_CARDS));
    assert(cv_eq(cv_structure_label(h.content()).get_text(), CVB_NO_CARDS));
    assert(cv_node_buttons(h.content()).size == 0);
    assert(!h.add_button().get_sensitive());
}

private void test_a_project_that_should_have_cards_waits_before_declaring_itself_empty() {
    // The project claims cards, but the local snapshot has none yet (still loading).
    var h = new ConnectionsViewHarness();
    h.project_store.append(cv_project("p1", "Loading Project", 4));
    h.projects.set_selected(0);
    var watcher = new CvbTextWatcher(h, CVB_NO_CARDS);
    h.start();

    // Give the delayed empty check plenty of time to fire.
    cvb_settle(700);
    watcher.stop();

    assert(!watcher.seen);
    assert(cv_eq(cv_empty_label(h.content()).get_text(), "Select a card to view graph links."));
}

private void test_a_drawn_board_turns_into_the_empty_message_after_the_delay() {
    var h = cvb_project_harness(0);
    assert(h.wait_for_nodes(3));

    h.card_store.remove_all();

    // The board is not blanked at once (the empty snapshot may be transitional)...
    assert(wait_for_condition(() => cv_empty_label(h.content()).get_visible()));
    // ...but once the delayed check confirms the project really is empty it says so.
    assert(h.wait_for_empty_text(CVB_NO_CARDS));
    assert(cv_node_buttons(h.content()).size == 0);
    assert(cv_eq(cv_structure_label(h.content()).get_text(), CVB_NO_CARDS));
}

private void test_cards_arriving_before_the_delay_cancel_the_empty_message() {
    var h = cvb_project_harness(0);
    assert(h.wait_for_nodes(3));
    var watcher = new CvbTextWatcher(h, CVB_NO_CARDS);

    h.card_store.remove_all();
    // Long enough for the emptied board to be processed and the delayed check scheduled, but well
    // inside the check's delay.
    cvb_settle(150);
    h.card_store.append(cv_card("c9", "p1", "Card Nine", 10));

    assert(h.wait_for_nodes(1));
    cvb_settle(500);
    watcher.stop();

    assert(!watcher.seen);
    assert(cv_node_titles(h.content()).contains("Card Nine"));
    assert(!cv_empty_label(h.content()).get_visible());
}

private void test_an_empty_check_is_ignored_once_the_project_changed() {
    var h = cvb_project_harness(0);
    assert(h.wait_for_nodes(3));
    var watcher = new CvbTextWatcher(h, CVB_NO_CARDS);

    h.card_store.remove_all();
    cvb_settle(150);
    // Switching project before the delayed check fires makes that check stale.
    h.projects.set_selected(1);

    assert(wait_for_condition(() => cv_relations_title(h.content()).get_text() == "Project Two"));
    cvb_settle(500);
    watcher.stop();

    assert(!watcher.seen);
}

private void test_the_projects_root_without_a_selection_model_has_nothing_to_show() {
    var h = new ConnectionsViewHarness();
    h.view.set_api_client(h.api);
    h.view.set_tool_visible(true);

    bool done = false;
    h.view.navigate_to_projects_root.begin(null, (obj, res) => {
        h.view.navigate_to_projects_root.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));

    // Not bound to any selection yet.
    assert(h.wait_for_empty_text("No projects available."));
    assert(cv_eq(cv_structure_label(h.content()).get_text(), "No projects available."));
}

private void test_the_projects_root_with_no_projects_has_nothing_to_show() {
    var h = new ConnectionsViewHarness();
    h.start();
    bool done = false;
    h.view.navigate_to_projects_root.begin(null, (obj, res) => {
        h.view.navigate_to_projects_root.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));

    assert(h.wait_for_empty_text("No projects available."));
    assert(cv_eq(cv_relations_title(h.content()).get_text(), "Projects"));
}

private void test_the_projects_root_needs_no_api() {
    var h = new ConnectionsViewHarness();
    h.project_store.append(cv_project("p1", "Project One", 3));
    h.projects.set_selected(0);
    h.start(false);
    bool done = false;
    h.view.navigate_to_projects_root.begin(null, (obj, res) => {
        h.view.navigate_to_projects_root.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));

    assert(h.wait_for_nodes(1));
    assert(cv_node_titles(h.content()).contains("Project One"));
}

private void test_a_selection_model_without_items_shows_no_projects() {
    var h = new ConnectionsViewHarness();
    var no_model = new Gtk.SingleSelection(null);
    h.view.set_api_client(h.api);
    h.view.bind_context(no_model, h.card_store, h.cards);
    h.view.set_tool_visible(true);
    bool done = false;
    h.view.navigate_to_projects_root.begin(null, (obj, res) => {
        h.view.navigate_to_projects_root.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));

    assert(h.wait_for_empty_text("No projects available."));
}

// Presses the secondary button on a node the way a right click does.
private void cvb_secondary_press(Gtk.Button node, int n_press = 1) {
    var controllers = node.observe_controllers();
    for (uint i = 0; i < controllers.get_n_items(); i++) {
        var click = controllers.get_item(i) as Gtk.GestureClick;
        if (click != null && ((!) click).get_button() == Gdk.BUTTON_SECONDARY) {
            ((!) click).pressed(n_press, 4.0, 4.0);
            return;
        }
    }
    assert_not_reached();
}

private Gtk.Popover? cvb_popover(Gtk.Button node) {
    for (var child = node.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        if (child is Gtk.Popover) {
            return (Gtk.Popover) child;
        }
    }
    return null;
}

private void test_right_clicking_a_card_offers_open_and_create_child() {
    var h = cvb_project_harness();
    assert(h.wait_for_nodes(3));
    var node = cv_node(h.content(), "Card Two");
    assert(cvb_popover(node) == null);

    cvb_secondary_press(node);

    var popover = cvb_popover(node);
    assert(popover != null);
    var open = cv_button_labeled((!) popover, "Open");
    var create = cv_button_labeled((!) popover, "Create Child Card");
    open.clicked();
    create.clicked();
    assert(h.card_opens.size == 1 && h.card_opens[0] == "c2");
    assert(h.child_requests.size == 1 && h.child_requests[0] == "c2");
}

private void test_only_a_single_right_click_on_a_card_opens_the_menu() {
    var h = cvb_project_harness();
    assert(h.wait_for_nodes(3));
    var node = cv_node(h.content(), "Card One");

    cvb_secondary_press(node, 2);

    assert(cvb_popover(node) == null);
}

private void test_project_nodes_have_no_context_menu() {
    var h = cvb_project_harness();
    bool done = false;
    h.view.navigate_to_projects_root.begin(null, (obj, res) => {
        h.view.navigate_to_projects_root.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(h.wait_for_nodes(2));
    var node = cv_node(h.content(), "Project One");

    cvb_secondary_press(node);

    assert(cvb_popover(node) == null);
}

private void test_a_view_that_was_never_bound_shows_the_select_a_project_hint() {
    var h = new ConnectionsViewHarness();
    h.view.set_api_client(h.api);
    h.view.set_tool_visible(true);

    assert(h.wait_for_empty_text("Select a project to view connections."));
    assert(cv_eq(cv_relations_title(h.content()).get_text(), "Relations"));
    // No selection models, so nothing can be added and links are not resolved against a project.
    h.add_button().clicked();
    assert(h.dialog() == null);
    assert(h.toasts.size == 0);
    var probe = new CvLinkProbe();
    assert(cv_activate_link(cv_structure_label(h.content()), "card:c1", probe));
    assert(wait_for_condition(() => h.card_opens.size == 1));
    assert(h.card_opens[0] == "c1");
}

private class CvbOnce : Object {
    public bool fired { get; set; default = false; }
}

// Changes the content generation from inside the first list_card_links call, i.e. while the
// project refresh is part-way through loading. (Not cleared from inside the hook itself: that would
// free the closure that is still running.)
private CvbOnce cvb_bump_generation_during_the_first_load(ConnectionsViewHarness h) {
    var once = new CvbOnce();
    h.api.list_card_links_hook = (card_id) => {
        if (once.fired) {
            return;
        }
        once.fired = true;
        var links = new Gee.ArrayList<string>();
        links.add("Card Two");
        h.view.set_internal_links(links);
    };
    return once;
}

private void test_a_project_refresh_that_goes_stale_between_cards_stops_early() {
    var h = cvb_project_harness(3, false);
    var once = cvb_bump_generation_during_the_first_load(h);
    h.start();

    assert(h.wait_for_log("dropped stale project result"));
    assert(once.fired);
    // The queued follow-up refresh still draws the whole board.
    assert(h.wait_for_nodes(3));
    assert(h.api.max_list_card_links_in_flight == 1);
}

private void test_a_project_refresh_that_goes_stale_at_the_end_is_not_committed() {
    var h = new ConnectionsViewHarness();
    h.project_store.append(cv_project("p1", "Project One", 1));
    h.projects.set_selected(0);
    h.card_store.append(cv_card("c1", "p1", "Only Card", 10));
    var once = cvb_bump_generation_during_the_first_load(h);
    h.start();

    assert(h.wait_for_log("dropped stale project completion"));
    assert(once.fired);
    assert(h.wait_for_nodes(1));
}

public void register_connections_view_board_tests() {
    var prefix = "/holder/connections-tool-view/board/";
    Test.add_func(prefix + "no-projects", test_no_projects_means_a_hint_to_select_one);
    Test.add_func(prefix + "project-lost-keeps-board", test_losing_the_project_keeps_the_board_that_is_already_drawn);
    Test.add_func(prefix + "card-of-other-project", test_a_card_from_another_project_is_treated_as_no_card);
    Test.add_func(prefix + "project-no-api", test_a_project_board_without_an_api_says_so);
    Test.add_func(prefix + "card-load-failure", test_a_failed_card_load_reports_it_when_nothing_is_drawn);
    Test.add_func(prefix + "card-load-failure-keeps-board", test_a_failed_card_load_keeps_an_existing_board);
    Test.add_func(prefix + "project-load-failure", test_a_failed_project_load_reports_it_when_nothing_is_drawn);
    Test.add_func(prefix + "project-load-failure-keeps-board", test_a_failed_project_load_keeps_an_existing_board);
    Test.add_func(prefix + "project-links-filtered", test_project_links_only_count_cards_of_the_same_project);
    Test.add_func(prefix + "empty-project-now", test_an_empty_project_says_so_straight_away);
    Test.add_func(prefix + "empty-check-waits", test_a_project_that_should_have_cards_waits_before_declaring_itself_empty);
    Test.add_func(prefix + "empty-check-confirms", test_a_drawn_board_turns_into_the_empty_message_after_the_delay);
    Test.add_func(prefix + "empty-check-cancelled", test_cards_arriving_before_the_delay_cancel_the_empty_message);
    Test.add_func(prefix + "empty-check-stale", test_an_empty_check_is_ignored_once_the_project_changed);
    Test.add_func(prefix + "root-unbound", test_the_projects_root_without_a_selection_model_has_nothing_to_show);
    Test.add_func(prefix + "root-no-projects", test_the_projects_root_with_no_projects_has_nothing_to_show);
    Test.add_func(prefix + "root-no-api", test_the_projects_root_needs_no_api);
    Test.add_func(prefix + "root-no-model", test_a_selection_model_without_items_shows_no_projects);
    Test.add_func(prefix + "context-menu", test_right_clicking_a_card_offers_open_and_create_child);
    Test.add_func(prefix + "context-menu-single-press", test_only_a_single_right_click_on_a_card_opens_the_menu);
    Test.add_func(prefix + "context-menu-projects", test_project_nodes_have_no_context_menu);
    Test.add_func(prefix + "unbound-view", test_a_view_that_was_never_bound_shows_the_select_a_project_hint);
    Test.add_func(prefix + "stale-between-cards", test_a_project_refresh_that_goes_stale_between_cards_stops_early);
    Test.add_func(prefix + "stale-at-completion", test_a_project_refresh_that_goes_stale_at_the_end_is_not_committed);
}

}
