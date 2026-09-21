using GLib;

namespace HolderLinuxTests {

// Two projects; project one has three cards linked c1 -> c2 (ref) and c3 -> c1 (blocks).
private ConnectionsViewHarness cvr_harness(bool select_card = false, bool start = true) {
    var h = new ConnectionsViewHarness();
    h.project_store.append(cv_project("p1", "Project One", 3));
    h.project_store.append(cv_project("p2", "Project Two", 1));
    h.projects.set_selected(0);
    h.card_store.append(cv_card("c1", "p1", "Card One", 10));
    h.card_store.append(cv_card("c2", "p1", "Card Two", 20));
    h.card_store.append(cv_card("c3", "p1", "Card Three", 30));
    h.card_store.append(cv_card("x1", "p2", "Other Card", 10));
    h.api.card_links.add(cv_link("c1", "c2", "ref"));
    h.api.card_backlinks.add(cv_link("c3", "c1", "blocks"));
    if (select_card) {
        h.cards.set_selected(0);
    }
    if (start) {
        h.start();
    }
    return h;
}

private void cvr_wait_for_card_focus(ConnectionsViewHarness h) {
    assert(h.wait_for_nodes(3));
    assert(h.wait_for_structure("Project: "));
}

private bool cvr_navigate_to_projects_root(ConnectionsViewHarness h) {
    bool done = false;
    bool result = false;
    h.view.navigate_to_projects_root.begin(null, (obj, res) => {
        result = h.view.navigate_to_projects_root.end(res);
        done = true;
    });
    assert(h.wait(() => done));
    return result;
}

private void test_the_tool_identifies_itself_and_starts_with_a_hint() {
    var h = cvr_harness(false, false);

    assert(h.view.tool_id == "connections");
    assert(h.view.tool_label == "Connections");
    assert(h.view.get_actions_widget() != null);
    assert(h.view.get_content_widget() == h.view.widget);

    assert(cv_eq(cv_relations_title(h.content()).get_text(), "Relations"));
    var hint = cv_empty_label(h.content());
    assert(hint.get_visible());
    assert(hint.get_text() == "Select a card to view graph links.");
    assert(cv_eq(cv_structure_label(h.content()).get_text(), "Select a card to view graph links."));
    assert(cv_eq(cv_outgoing_label(h.content()).get_text(), "None"));
    assert(!h.add_button().get_sensitive());
    // The overview text has no sections to show, so the three link sections are hidden.
    assert(!cv_outgoing_label(h.content()).get_parent().get_visible());
    assert(!cv_backlinks_label(h.content()).get_parent().get_visible());
    assert(!cv_internal_label(h.content()).get_parent().get_visible());
    assert(cv_node_buttons(h.content()).size == 0);
}

private void test_a_project_without_a_selected_card_shows_all_its_cards() {
    var h = cvr_harness();

    assert(h.wait_for_nodes(3));
    // One links call per card of the selected project (the other project's card is skipped).
    assert(h.wait(() => h.api.list_card_links_calls == 3));

    var titles = cv_node_titles(h.content());
    assert(titles.contains("Card One") && titles.contains("Card Two") && titles.contains("Card Three"));
    assert(!titles.contains("Other Card"));
    assert(!cv_empty_label(h.content()).get_visible());
    assert(cv_eq(cv_relations_title(h.content()).get_text(), "Project One"));
    assert(cv_eq(cv_structure_label(h.content()).get_text(), "• next: 2\n• ref: 1"));
    assert(!cv_outgoing_label(h.content()).get_parent().get_visible());
    // No card is selected, so there is nothing to attach a new link to.
    assert(!h.add_button().get_sensitive());
}

private void test_the_board_canvas_and_node_layer_are_sized_from_the_nodes() {
    var h = cvr_harness();
    assert(h.wait_for_nodes(3));

    var canvas = cv_canvas(h.content());
    var layer = cv_nodes_layer(h.content());
    int width;
    int height;
    layer.get_size_request(out width, out height);
    assert(canvas.get_content_width() == width);
    assert(canvas.get_content_height() == height);
    assert(canvas.get_content_width() >= HolderLinux.ConnectionsBoardPresenter.MIN_WIDTH);
    assert(canvas.get_content_height() >= HolderLinux.ConnectionsBoardPresenter.MIN_HEIGHT);

    // Every node button is placed on the layer at its model coordinates.
    foreach (var node in cv_node_buttons(h.content())) {
        assert(node.get_parent() == layer);
    }
}

private void test_card_focus_fills_the_relations_panel() {
    var h = cvr_harness(true);
    cvr_wait_for_card_focus(h);

    var titles = cv_node_titles(h.content());
    assert(titles.size == 3);
    assert(titles.contains("Card One") && titles.contains("Card Two") && titles.contains("Card Three"));
    assert(cv_eq(cv_relations_title(h.content()).get_text(), "Card One"));
    assert(cv_structure_label(h.content()).get_text().contains("Project: Project One"));
    assert(cv_eq(cv_outgoing_label(h.content()).get_text(), "ref: Card Two"));
    assert(cv_eq(cv_backlinks_label(h.content()).get_text(), "blocks: Card Three"));
    assert(cv_eq(cv_internal_label(h.content()).get_text(), "None"));
    assert(cv_outgoing_label(h.content()).get_parent().get_visible());
    assert(cv_backlinks_label(h.content()).get_parent().get_visible());
    assert(cv_internal_label(h.content()).get_parent().get_visible());
    // Links are clickable markup, and the accessible label carries the plain text.
    assert(cv_outgoing_label(h.content()).get_label().contains("<a href=\"card:c2\">Card Two</a>"));
    assert(!cv_empty_label(h.content()).get_visible());
    // One card selected, with other cards in its project to connect to.
    assert(h.add_button().get_sensitive());
    assert(h.api.list_card_links_calls == 1);
    assert(h.api.list_card_backlinks_calls == 1);
}

private void test_node_meta_line_shows_child_counts_and_age() {
    var h = new ConnectionsViewHarness();
    h.project_store.append(cv_project("p1", "Project One", 2));
    h.projects.set_selected(0);
    h.card_store.append(cv_card("parent", "p1", "Parent Card", 10));
    h.card_store.append(cv_card("child", "p1", "Child Card", 10, "parent"));
    h.card_store.append(cv_card("child2", "p1", "Second Child", 20, "parent"));
    h.start();
    assert(h.wait_for_nodes(3));

    var parent = cv_node(h.content(), "Parent Card");
    assert(parent.has_css_class("flowboard-branch"));
    assert(cv_node_texts(parent)[1].has_prefix("2 items | "));

    var child = cv_node(h.content(), "Child Card");
    assert(!child.has_css_class("flowboard-branch"));
    assert(!cv_node_texts(child)[1].contains(" | "));
}

private void test_internal_links_add_to_the_panel_and_refresh_the_board() {
    var h = cvr_harness(true);
    cvr_wait_for_card_focus(h);
    var calls = h.api.list_card_links_calls;

    var links = new Gee.ArrayList<string>();
    links.add("Card Two");
    links.add("No Such Card");
    h.view.set_internal_links(links);

    assert(h.wait(() => h.api.list_card_links_calls == calls + 1));
    assert(h.wait(() => cv_internal_label(h.content()).get_text() == "Card Two\nNo Such Card"));
    // The resolvable target is a link, the unknown one is plain text.
    var markup = cv_internal_label(h.content()).get_label();
    assert(markup.contains("<a href=\"card:c2\">Card Two</a>"));
    assert(!markup.contains("No Such Card</a>"));

    // Clearing them again is a content change too, and goes back to the empty text.
    h.view.set_internal_links(new Gee.ArrayList<string>());
    assert(h.wait(() => h.api.list_card_links_calls == calls + 2));
    assert(h.wait(() => cv_internal_label(h.content()).get_text() == "None"));
}

private void test_selection_changes_retitle_the_panel_and_reload() {
    var h = cvr_harness();
    assert(h.wait_for_nodes(3));
    assert(cv_eq(cv_relations_title(h.content()).get_text(), "Project One"));

    h.cards.set_selected(1);
    assert(h.wait(() => cv_relations_title(h.content()).get_text() == "Card Two"));
    assert(h.wait(() => cv_outgoing_label(h.content()).get_parent().get_visible()));

    // Switching project clears the card selection in the app, so do the same here.
    h.cards.set_selected(Gtk.INVALID_LIST_POSITION);
    assert(h.wait(() => cv_relations_title(h.content()).get_text() == "Project One"));
    h.projects.set_selected(1);
    assert(h.wait(() => cv_relations_title(h.content()).get_text() == "Project Two"));
}

private void test_adding_a_card_redraws_the_project_board() {
    var h = cvr_harness();
    assert(h.wait_for_nodes(3));

    h.card_store.append(cv_card("c4", "p1", "Card Four", 40));

    assert(h.wait_for_nodes(4));
    assert(cv_node_titles(h.content()).contains("Card Four"));
}

private void test_links_in_every_relations_section_are_routed_by_the_view() {
    var h = cvr_harness(true);
    cvr_wait_for_card_focus(h);
    var probe = new CvLinkProbe();
    var labels = cv_markup_labels(h.content());

    // All four labels (structure, outgoing, incoming, internal) share the same handler.
    for (int i = 0; i < labels.size; i++) {
        assert(cv_activate_link(labels[i], "card:c%d".printf(i % 3 + 1), probe));
    }
    assert(h.wait(() => h.card_opens.size == 4));
    assert(h.card_opens[0] == "c1");
    assert(h.card_opens[1] == "c2");
    assert(h.card_opens[2] == "c3");
    assert(h.card_opens[3] == "c1");
    assert(probe.blocked == 0);
}

private void test_project_links_focus_the_project_overview() {
    var h = cvr_harness(true);
    cvr_wait_for_card_focus(h);
    var probe = new CvLinkProbe();

    assert(cv_activate_link(cv_structure_label(h.content()), "project:p1", probe));

    assert(h.wait(() => h.project_overviews.size == 1));
    assert(h.project_overviews[0] == "p1");
    assert(h.card_opens.size == 0);
}

private void test_internal_links_resolve_to_cards_and_unknown_ones_do_nothing() {
    var h = cvr_harness(true);
    cvr_wait_for_card_focus(h);
    var probe = new CvLinkProbe();
    var label = cv_internal_label(h.content());

    // Unknown targets are claimed (so GTK does not try to open them) but open nothing.
    assert(cv_activate_link(label, "ilink:No%20Such%20Card", probe));
    assert(cv_activate_link(label, "ilink:Card%20Two", probe));
    // A later known link proves the unknown one had already been processed and produced nothing.
    assert(cv_activate_link(label, "card:c3", probe));

    assert(h.wait(() => h.card_opens.size == 2));
    assert(h.card_opens[0] == "c2");
    assert(h.card_opens[1] == "c3");
    assert(probe.blocked == 0);
}

private void test_links_the_view_does_not_own_are_left_to_gtk() {
    var h = cvr_harness(true);
    cvr_wait_for_card_focus(h);
    var probe = new CvLinkProbe();
    var label = cv_structure_label(h.content());

    assert(!cv_activate_link(label, "https://example.com/page", probe));
    assert(!cv_activate_link(label, "", probe));
    assert(!cv_activate_link(label, "mailto:someone@example.com", probe));

    assert(probe.blocked == 3);
    // Nothing was requested for any of them.
    var settle = new MainLoop();
    Idle.add(() => { settle.quit(); return Source.REMOVE; });
    settle.run();
    assert(h.card_opens.size == 0);
    assert(h.project_overviews.size == 0);
}

private void test_the_relations_toggle_shows_and_hides_the_panel() {
    var h = cvr_harness();
    var scroller = cv_relations_scroller(h.content());
    var toggle = h.relations_toggle();

    assert(toggle.get_active());
    assert(scroller.get_visible());

    toggle.set_active(false);
    assert(!scroller.get_visible());

    toggle.set_active(true);
    assert(scroller.get_visible());
}

private void test_scope_snapshot_follows_the_selection() {
    var h = cvr_harness(true);
    cvr_wait_for_card_focus(h);
    var project = (HolderLinux.Project) h.projects.get_selected_item();
    var card = (HolderLinux.CardSummary) h.cards.get_selected_item();

    var focused = h.view.get_scope_snapshot(project, card);
    assert(focused.tool_id == "connections");
    assert(focused.tool_label == "Connections");
    assert(focused.project_id == "p1");
    assert(focused.card_id == "c1");
    assert(focused.scope_mode == HolderLinux.ToolScopeMode.CARD_FOCUS);

    var overview = h.view.get_scope_snapshot(project, null);
    assert(overview.card_id == null);
    assert(overview.card_label == "Overview");
    assert(overview.scope_mode == HolderLinux.ToolScopeMode.PROJECT_ROOT);
}

private void test_navigating_to_the_projects_root_shows_one_node_per_project() {
    var h = cvr_harness(true);
    cvr_wait_for_card_focus(h);
    assert(h.add_button().get_sensitive());

    assert(cvr_navigate_to_projects_root(h));

    assert(h.wait_for_nodes(2));
    var titles = cv_node_titles(h.content());
    assert(titles.contains("Project One") && titles.contains("Project Two"));
    assert(cv_eq(cv_relations_title(h.content()).get_text(), "Projects"));
    assert(cv_eq(cv_structure_label(h.content()).get_text(), "Select a project."));
    assert(cv_eq(cv_outgoing_label(h.content()).get_text(), "None"));
    assert(!cv_empty_label(h.content()).get_visible());
    // Links can only be added between cards, never on the projects overview.
    assert(!h.add_button().get_sensitive());
    // The projects show their root card counts, e.g. "3 items" for Project One.
    assert(cv_node_texts(cv_node(h.content(), "Project One"))[1].has_prefix("3 items | "));
    assert(cv_node_texts(cv_node(h.content(), "Project Two"))[1].has_prefix("1 item | "));

    var focused = h.view.get_scope_snapshot(
        (HolderLinux.Project) h.projects.get_selected_item(),
        (HolderLinux.CardSummary) h.cards.get_selected_item()
    );
    assert(focused.scope_mode == HolderLinux.ToolScopeMode.PROJECTS_ROOT);
    assert(focused.project_label == "Projects");
    assert(focused.project_id == null);
}

private void test_clicking_a_project_node_opens_that_project() {
    var h = cvr_harness();
    assert(cvr_navigate_to_projects_root(h));
    assert(h.wait_for_nodes(2));
    assert(cv_eq(cv_relations_title(h.content()).get_text(), "Projects"));

    cv_node(h.content(), "Project Two").clicked();

    assert(h.project_overviews.size == 1);
    assert(h.project_overviews[0] == "p2");
    assert(h.card_opens.size == 0);
    // Focusing a project leaves the overview and goes back to the selected project's board.
    assert(h.wait(() => cv_relations_title(h.content()).get_text() == "Project One"));
    assert(h.wait(() => cv_node_buttons(h.content()).size == 3));
}

private void test_clicking_a_card_node_opens_that_card() {
    var h = cvr_harness(true);
    cvr_wait_for_card_focus(h);

    cv_node(h.content(), "Card Two").clicked();

    assert(h.card_opens.size == 1);
    assert(h.card_opens[0] == "c2");
    assert(h.project_overviews.size == 0);
}

private void test_changing_the_selection_leaves_the_projects_root() {
    var h = cvr_harness();
    assert(cvr_navigate_to_projects_root(h));
    assert(cv_eq(cv_relations_title(h.content()).get_text(), "Projects"));

    h.projects.set_selected(1);

    assert(h.wait(() => cv_relations_title(h.content()).get_text() == "Project Two"));
    assert(h.wait(() => cv_node_titles(h.content()).contains("Other Card")));
}

private void test_navigation_requests_are_forwarded_to_the_shell() {
    var h = cvr_harness();
    bool project_done = false;
    bool project_result = false;
    bool card_done = false;
    bool card_result = false;

    h.view.navigate_to_project_root.begin("p2", (obj, res) => {
        project_result = h.view.navigate_to_project_root.end(res);
        project_done = true;
    });
    h.view.navigate_to_card.begin("c2", (obj, res) => {
        card_result = h.view.navigate_to_card.end(res);
        card_done = true;
    });

    assert(h.wait(() => project_done && card_done));
    assert(project_result && card_result);
    assert(h.project_overviews.size == 1 && h.project_overviews[0] == "p2");
    assert(h.card_opens.size == 1 && h.card_opens[0] == "c2");
}

public void register_connections_view_relations_tests() {
    var prefix = "/holder/connections-tool-view/relations/";
    Test.add_func(prefix + "identity-and-initial-hint", test_the_tool_identifies_itself_and_starts_with_a_hint);
    Test.add_func(prefix + "project-board", test_a_project_without_a_selected_card_shows_all_its_cards);
    Test.add_func(prefix + "canvas-sizing", test_the_board_canvas_and_node_layer_are_sized_from_the_nodes);
    Test.add_func(prefix + "card-focus", test_card_focus_fills_the_relations_panel);
    Test.add_func(prefix + "node-meta", test_node_meta_line_shows_child_counts_and_age);
    Test.add_func(prefix + "internal-links", test_internal_links_add_to_the_panel_and_refresh_the_board);
    Test.add_func(prefix + "selection-retitles", test_selection_changes_retitle_the_panel_and_reload);
    Test.add_func(prefix + "card-added-redraws", test_adding_a_card_redraws_the_project_board);
    Test.add_func(prefix + "links-all-sections", test_links_in_every_relations_section_are_routed_by_the_view);
    Test.add_func(prefix + "links-project", test_project_links_focus_the_project_overview);
    Test.add_func(prefix + "links-internal", test_internal_links_resolve_to_cards_and_unknown_ones_do_nothing);
    Test.add_func(prefix + "links-declined", test_links_the_view_does_not_own_are_left_to_gtk);
    Test.add_func(prefix + "toggle", test_the_relations_toggle_shows_and_hides_the_panel);
    Test.add_func(prefix + "scope-snapshot", test_scope_snapshot_follows_the_selection);
    Test.add_func(prefix + "projects-root", test_navigating_to_the_projects_root_shows_one_node_per_project);
    Test.add_func(prefix + "project-node-click", test_clicking_a_project_node_opens_that_project);
    Test.add_func(prefix + "card-node-click", test_clicking_a_card_node_opens_that_card);
    Test.add_func(prefix + "selection-leaves-root", test_changing_the_selection_leaves_the_projects_root);
    Test.add_func(prefix + "navigation-forwarded", test_navigation_requests_are_forwarded_to_the_shell);
}

}
