using GLib;

namespace HolderLinuxTests {

// Project one with cards c1..c3 (c1 selected) plus a card of another project.
private ConnectionsViewHarness cvd_harness() {
    var h = new ConnectionsViewHarness();
    h.project_store.append(cv_project("p1", "Project One", 3));
    h.project_store.append(cv_project("p2", "Project Two", 1));
    h.projects.set_selected(0);
    h.card_store.append(cv_card("c1", "p1", "Card One", 10));
    h.card_store.append(cv_card("c2", "p1", "Card Two", 20));
    h.card_store.append(cv_card("c3", "p1", "Card Three", 30));
    h.card_store.append(cv_card("x1", "p2", "Other Card", 10));
    h.cards.set_selected(0);
    h.start();
    // The structure panel only fills in once the card-focus board has been rendered.
    assert(h.wait_for_structure("Project: "));
    return h;
}

private Adw.AlertDialog cvd_open_dialog(ConnectionsViewHarness h) {
    assert(h.dialog() == null);
    assert(h.add_button().get_sensitive());
    h.add_button().clicked();
    assert(h.wait_for_dialog());
    return (!) h.dialog();
}

private Gtk.Widget cvd_content(Adw.AlertDialog dialog) {
    var content = dialog.get_extra_child();
    assert(content != null);
    return (!) content;
}

private Settings? cvd_settings() {
    var source = SettingsSchemaSource.get_default();
    if (source == null || ((!) source).lookup(HolderLinux.AppSettings.SCHEMA_ID, true) == null) {
        Test.skip("settings schema is not available");
        return null;
    }
    var settings = new Settings(HolderLinux.AppSettings.SCHEMA_ID);
    settings.reset(HolderLinux.AppSettings.KEY_CUSTOM_CARD_LINK_KINDS);
    return settings;
}

private void test_the_add_button_needs_a_selected_card_with_other_cards_to_link() {
    var h = new ConnectionsViewHarness();
    h.project_store.append(cv_project("p1", "Project One", 1));
    h.projects.set_selected(0);
    h.card_store.append(cv_card("c1", "p1", "Only Card", 10));
    h.cards.set_selected(0);
    h.start();
    assert(h.wait_for_nodes(1));

    // The only card in its project has nothing to be connected to.
    assert(!h.add_button().get_sensitive());

    h.card_store.append(cv_card("c2", "p1", "Second Card", 20));
    assert(h.wait(() => h.add_button().get_sensitive()));

    // Another project's card is not a link target.
    h.card_store.remove(1);
    h.card_store.append(cv_card("x1", "p2", "Other Card", 10));
    assert(h.wait(() => !h.add_button().get_sensitive()));
}

private void test_the_add_button_needs_an_api_connection() {
    var h = new ConnectionsViewHarness();
    h.project_store.append(cv_project("p1", "Project One", 2));
    h.projects.set_selected(0);
    h.card_store.append(cv_card("c1", "p1", "Card One", 10));
    h.card_store.append(cv_card("c2", "p1", "Card Two", 20));
    h.cards.set_selected(0);
    h.start(false);

    assert(h.wait_for_empty_text("API unavailable."));
    assert(!h.add_button().get_sensitive());

    h.view.set_api_client(h.api);
    assert(h.wait(() => h.add_button().get_sensitive()));
    assert(h.wait_for_nodes(2));
}

private void test_the_dialog_offers_the_other_cards_and_the_default_kinds() {
    var h = cvd_harness();

    var dialog = cvd_open_dialog(h);

    assert(cv_eq(dialog.get_heading(), "Add Graph Connection"));
    assert(cv_eq(dialog.get_body(), "Create an explicit card-to-card connection."));
    assert(dialog.has_response("cancel") && dialog.has_response("add"));
    assert(cv_eq(dialog.get_default_response(), "add"));
    assert(cv_eq(dialog.get_close_response(), "cancel"));

    var targets = cv_dropdown(cvd_content(dialog), "Target card");
    var target_items = cv_dropdown_items(targets);
    assert(target_items.size == 2);
    assert(cv_eq(target_items[0], "Card Two (c2)"));
    assert(cv_eq(target_items[1], "Card Three (c3)"));
    assert(targets.get_selected() == 0);

    var kinds = cv_dropdown(cvd_content(dialog), "Kind");
    var kind_items = cv_dropdown_items(kinds);
    assert(kind_items.size == 6);
    assert(cv_eq(kind_items[0], "ref"));
    assert(cv_eq(kind_items[3], "blocks"));
    assert(cv_eq(kind_items[5], "custom"));
    assert(kinds.get_selected() == 0);
    assert(!cv_entry(cvd_content(dialog), "custom kind").get_visible());
    assert(cv_eq(cv_entry(cvd_content(dialog), "optional note").get_text(), ""));
}

private void test_choosing_custom_reveals_the_kind_entry_and_leaving_it_clears_the_text() {
    var h = cvd_harness();
    var dialog = cvd_open_dialog(h);
    var kinds = cv_dropdown(cvd_content(dialog), "Kind");
    var custom_entry = cv_entry(cvd_content(dialog), "custom kind");
    assert(!custom_entry.get_visible());

    kinds.set_selected(5);
    assert(custom_entry.get_visible());

    custom_entry.set_text("my_kind");
    kinds.set_selected(1);
    assert(!custom_entry.get_visible());
    assert(cv_eq(custom_entry.get_text(), ""));
}

private void test_adding_creates_the_link_from_the_selected_card() {
    var h = cvd_harness();
    var dialog = cvd_open_dialog(h);
    var content = cvd_content(dialog);
    cv_dropdown(content, "Target card").set_selected(1);
    cv_dropdown(content, "Kind").set_selected(3);
    cv_entry(content, "optional note").set_text("  because it gates the release  ");
    var links_before = h.api.list_card_links_calls;
    assert(h.api.create_card_link_calls == 0);

    dialog.response("add");

    assert(h.wait(() => h.api.create_card_link_calls == 1));
    assert(cv_eq(h.api.last_link_from_card_id, "c1"));
    assert(cv_eq(h.api.last_link_to_card_id, "c3"));
    assert(cv_eq(h.api.last_link_kind, "blocks"));
    assert(cv_eq(h.api.last_link_label, "because it gates the release"));
    assert(cv_eq(h.api.last_link_to_type, "card"));
    assert(h.wait(() => h.toasts.contains("Graph link added.")));
    assert(h.errors.size == 0);
    // The board reloads so the new connection shows up.
    assert(h.wait(() => h.api.list_card_links_calls == links_before + 1));
}

private void test_adding_with_untouched_defaults_links_the_first_card_as_a_ref_without_a_label() {
    var h = cvd_harness();
    var dialog = cvd_open_dialog(h);

    dialog.response("add");

    assert(h.wait(() => h.api.create_card_link_calls == 1));
    assert(cv_eq(h.api.last_link_to_card_id, "c2"));
    assert(cv_eq(h.api.last_link_kind, "ref"));
    assert(h.api.last_link_label == null);
}

private void test_a_blank_custom_kind_falls_back_to_a_ref() {
    var h = cvd_harness();
    var dialog = cvd_open_dialog(h);
    cv_dropdown(cvd_content(dialog), "Kind").set_selected(5);
    cv_entry(cvd_content(dialog), "custom kind").set_text("   ");

    dialog.response("add");

    assert(h.wait(() => h.api.create_card_link_calls == 1));
    assert(cv_eq(h.api.last_link_kind, "ref"));
}

private void test_a_custom_kind_is_used_remembered_and_offered_next_time() {
    var settings = cvd_settings();
    if (settings == null) {
        return;
    }
    var h = cvd_harness();
    h.view.set_settings(settings);
    var dialog = cvd_open_dialog(h);
    cv_dropdown(cvd_content(dialog), "Kind").set_selected(5);
    cv_entry(cvd_content(dialog), "custom kind").set_text("  inspired_by ");

    dialog.response("add");

    assert(h.wait(() => h.api.create_card_link_calls == 1));
    assert(cv_eq(h.api.last_link_kind, "inspired_by"));
    var remembered = ((!) settings).get_strv(HolderLinux.AppSettings.KEY_CUSTOM_CARD_LINK_KINDS);
    assert(remembered.length == 1);
    assert(remembered[0] == "inspired_by");

    // The dialog now lists the remembered kind before "custom".
    dialog.force_close();
    h.settle();
    // Removing the closed dialog from the window is libadwaita's own bookkeeping (with libadwaita 1.5
    // it never completes for a window that is not shown), so wait for a different dialog instead.
    assert(h.add_button().get_sensitive());
    h.add_button().clicked();
    assert(h.wait(() => h.dialog() != null && h.dialog() != dialog));
    var reopened = (!) h.dialog();
    var kind_items = cv_dropdown_items(cv_dropdown(cvd_content(reopened), "Kind"));
    assert(kind_items.size == 7);
    assert(cv_eq(kind_items[5], "inspired_by"));
    assert(cv_eq(kind_items[6], "custom"));
}

private void test_a_listed_kind_is_not_remembered_as_custom() {
    var settings = cvd_settings();
    if (settings == null) {
        return;
    }
    var h = cvd_harness();
    h.view.set_settings(settings);
    var dialog = cvd_open_dialog(h);
    cv_dropdown(cvd_content(dialog), "Kind").set_selected(2);

    dialog.response("add");

    assert(h.wait(() => h.api.create_card_link_calls == 1));
    assert(cv_eq(h.api.last_link_kind, "example_of"));
    assert(((!) settings).get_strv(HolderLinux.AppSettings.KEY_CUSTOM_CARD_LINK_KINDS).length == 0);
}

private void test_cancelling_creates_nothing() {
    var h = cvd_harness();
    var dialog = cvd_open_dialog(h);
    var links_before = h.api.list_card_links_calls;

    dialog.response("cancel");
    h.drain();

    assert(h.api.create_card_link_calls == 0);
    assert(h.toasts.size == 0);
    assert(h.errors.size == 0);
    assert(h.api.list_card_links_calls == links_before);
}

private void test_a_failed_create_reports_an_error_and_does_not_reload() {
    var h = cvd_harness();
    h.api.fail_create_card_link = true;
    var dialog = cvd_open_dialog(h);
    var links_before = h.api.list_card_links_calls;

    dialog.response("add");

    assert(h.wait(() => h.errors.size == 1));
    assert(cv_eq(h.errors[0], "Failed to add graph link|create card link failed"));
    assert(!h.toasts.contains("Graph link added."));
    // A reload would have been queued within the debounce window if the create had succeeded.
    h.drain();
    assert(h.api.list_card_links_calls == links_before);
}

private void test_the_add_action_does_nothing_without_a_selected_card() {
    var h = cvd_harness();
    h.cards.set_selected(Gtk.INVALID_LIST_POSITION);
    assert(h.wait(() => !h.add_button().get_sensitive()));

    // The button is disabled, but the click handler must also guard against being invoked.
    h.add_button().clicked();
    h.drain();

    assert(h.dialog() == null);
    assert(h.toasts.size == 0);
}

private void test_a_project_without_other_cards_explains_why_no_dialog_opens() {
    var h = new ConnectionsViewHarness();
    h.project_store.append(cv_project("p1", "Project One", 1));
    h.projects.set_selected(0);
    h.card_store.append(cv_card("c1", "p1", "Only Card", 10));
    h.cards.set_selected(0);
    h.start();
    assert(h.wait_for_nodes(1));
    assert(!h.add_button().get_sensitive());

    h.add_button().clicked();

    assert(h.wait(() => h.toasts.contains("No other cards in this project to link.")));
    assert(h.dialog() == null);
}

private void test_the_dialog_needs_a_window_to_attach_to() {
    var h = cvd_harness();
    h.window.set_content(null);
    assert(h.view.widget.get_root() == null);
    // Presented without a parent window a dialog would become a toplevel of its own, which the
    // harness window would not report, so count toplevels instead.
    var toplevels_before = Gtk.Window.get_toplevels().get_n_items();

    h.add_button().clicked();
    h.drain();

    assert(Gtk.Window.get_toplevels().get_n_items() == toplevels_before);
    assert(h.dialog() == null);
    assert(h.toasts.size == 0);
    assert(h.errors.size == 0);
}

private void test_losing_the_api_while_the_dialog_is_open_creates_nothing() {
    var h = cvd_harness();
    var dialog = cvd_open_dialog(h);
    h.view.set_api_client(null);

    dialog.response("add");
    h.drain();

    assert(h.api.create_card_link_calls == 0);
    assert(h.toasts.size == 0);
    assert(h.errors.size == 0);
}

private void test_losing_the_api_after_the_board_is_drawn_disables_the_add_button() {
    var h = cvd_harness();
    // Preconditions: the board is drawn and the button was usable, so losing the API is the only
    // thing that can turn it off.
    assert(h.wait(() => cv_node_buttons(h.content()).size > 0));
    assert(h.add_button().get_sensitive());

    h.view.set_api_client(null);

    assert(!h.add_button().get_sensitive());
    // Clicking it must not open a dialog either.
    h.add_button().clicked();
    h.drain();
    assert(h.dialog() == null);

    h.view.set_api_client(h.api);
    assert(h.add_button().get_sensitive());
}

private void test_clearing_the_selected_card_disables_the_add_button() {
    var h = cvd_harness();
    assert(h.add_button().get_sensitive());

    h.cards.set_selected(Gtk.INVALID_LIST_POSITION);
    assert(h.cards.get_selected() == Gtk.INVALID_LIST_POSITION);

    assert(!h.add_button().get_sensitive());

    h.cards.set_selected(1);
    assert(h.add_button().get_sensitive());
}

private void test_the_projects_overview_has_no_add_button_and_leaving_it_restores_it() {
    var h = cvd_harness();
    assert(h.add_button().get_sensitive());

    bool done = false;
    h.view.navigate_to_projects_root.begin(null, (obj, res) => {
        h.view.navigate_to_projects_root.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(!h.add_button().get_sensitive());

    h.cards.set_selected(1);
    assert(h.add_button().get_sensitive());
}

private void test_the_add_button_follows_the_card_store_under_the_selection() {
    var h = cvd_harness();
    assert(h.add_button().get_sensitive());

    // The selected card disappears: nothing is selected any more.
    h.card_store.remove(0);
    assert(h.cards.get_selected() == Gtk.INVALID_LIST_POSITION);
    assert(!h.add_button().get_sensitive());

    // Selecting Card Two, which still has Card Three to link to, brings it back.
    h.cards.set_selected(0);
    assert(cv_eq(((HolderLinux.CardSummary) h.cards.get_selected_item()).card_id, "c2"));
    assert(h.add_button().get_sensitive());

    h.card_store.remove_all();
    assert(!h.add_button().get_sensitive());
}

public void register_connections_view_addlink_tests() {
    var prefix = "/holder/connections-tool-view/add-link/";
    Test.add_func(prefix + "button-needs-targets", test_the_add_button_needs_a_selected_card_with_other_cards_to_link);
    Test.add_func(prefix + "button-needs-api", test_the_add_button_needs_an_api_connection);
    Test.add_func(prefix + "dialog-content", test_the_dialog_offers_the_other_cards_and_the_default_kinds);
    Test.add_func(prefix + "custom-entry-toggle", test_choosing_custom_reveals_the_kind_entry_and_leaving_it_clears_the_text);
    Test.add_func(prefix + "create-link", test_adding_creates_the_link_from_the_selected_card);
    Test.add_func(prefix + "defaults", test_adding_with_untouched_defaults_links_the_first_card_as_a_ref_without_a_label);
    Test.add_func(prefix + "blank-custom-kind", test_a_blank_custom_kind_falls_back_to_a_ref);
    Test.add_func(prefix + "custom-kind-remembered", test_a_custom_kind_is_used_remembered_and_offered_next_time);
    Test.add_func(prefix + "listed-kind-not-remembered", test_a_listed_kind_is_not_remembered_as_custom);
    Test.add_func(prefix + "cancel", test_cancelling_creates_nothing);
    Test.add_func(prefix + "create-failure", test_a_failed_create_reports_an_error_and_does_not_reload);
    Test.add_func(prefix + "no-selected-card", test_the_add_action_does_nothing_without_a_selected_card);
    Test.add_func(prefix + "no-other-cards", test_a_project_without_other_cards_explains_why_no_dialog_opens);
    Test.add_func(prefix + "no-window", test_the_dialog_needs_a_window_to_attach_to);
    Test.add_func(prefix + "api-lost", test_losing_the_api_while_the_dialog_is_open_creates_nothing);
    Test.add_func(prefix + "button-follows-api-loss", test_losing_the_api_after_the_board_is_drawn_disables_the_add_button);
    Test.add_func(prefix + "button-follows-selection-clear", test_clearing_the_selected_card_disables_the_add_button);
    Test.add_func(prefix + "button-follows-projects-overview", test_the_projects_overview_has_no_add_button_and_leaving_it_restores_it);
    Test.add_func(prefix + "button-follows-card-store", test_the_add_button_follows_the_card_store_under_the_selection);
}

}
