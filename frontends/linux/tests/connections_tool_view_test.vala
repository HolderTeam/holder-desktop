using GLib;

namespace HolderLinuxTests {

private bool wait_until_true(owned SourceFunc predicate, int timeout_ms = 2000) {
    var loop = new MainLoop(null, false);
    var deadline = GLib.get_monotonic_time() + (int64) timeout_ms * 1000;
    Timeout.add(5, () => {
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

private void spin_main_loop_briefly(int duration_ms = 80) {
    var loop = new MainLoop(null, false);
    Timeout.add((uint) duration_ms, () => {
        loop.quit();
        return Source.REMOVE;
    });
    loop.run();
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
    var view = new HolderLinux.ConnectionsToolView();

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

    spin_main_loop_briefly();
    assert(api.list_card_links_calls == 0);
    assert(api.list_card_backlinks_calls == 0);

    view.set_tool_visible(true);
    assert(wait_until_true(() => {
        return api.list_card_links_calls == 1 && api.list_card_backlinks_calls == 1;
    }));

    view.set_tool_visible(false);
    card_selection.set_selected(1);

    spin_main_loop_briefly();
    assert(api.list_card_links_calls == 1);
    assert(api.list_card_backlinks_calls == 1);

    view.set_tool_visible(true);
    assert(wait_until_true(() => {
        return api.list_card_links_calls == 2 && api.list_card_backlinks_calls == 2;
    }));
}

private void test_visible_connections_refresh_is_debounced() {
    var api = new MainControllerFakeApi();
    var view = new HolderLinux.ConnectionsToolView();

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
    }));

    card_selection.set_selected(1);
    card_selection.set_selected(2);
    card_selection.set_selected(0);

    spin_main_loop_briefly(40);
    assert(api.list_card_links_calls == 1);
    assert(api.list_card_backlinks_calls == 1);

    assert(wait_until_true(() => {
        return api.list_card_links_calls == 2 && api.list_card_backlinks_calls == 2;
    }));
}

private void test_visible_connections_refresh_is_single_flight_for_latest_selection() {
    var api = new MainControllerFakeApi();
    api.list_card_links_delay_ms = 180;
    var view = new HolderLinux.ConnectionsToolView();

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
    }, 3000));

    card_selection.set_selected(1);
    spin_main_loop_briefly(130);
    card_selection.set_selected(2);
    card_selection.set_selected(0);

    assert(wait_until_true(() => {
        return api.list_card_links_calls == 2 && api.list_card_backlinks_calls == 2;
    }, 3000));

    assert(wait_until_true(() => {
        return api.list_card_links_calls == 3 && api.list_card_backlinks_calls == 3;
    }, 3000));

    assert(api.max_list_card_links_in_flight == 1);
}

private void test_stale_project_graph_refresh_result_is_dropped_when_generation_changes() {
    var api = new MainControllerFakeApi();
    api.list_card_links_delay_ms = 180;
    var view = new HolderLinux.ConnectionsToolView();

    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    project_store.append(project("p1", "Project One"));
    project_store.append(project("p2", "Project Two"));
    var project_selection = new Gtk.SingleSelection(project_store);
    project_selection.set_selected(1);

    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    card_store.append(card("p1-card", "p1", "P1 Unique Node", 10));
    card_store.append(card("p2-card", "p2", "P2 Unique Node", 10));
    var card_selection = new Gtk.SingleSelection(card_store);
    card_selection.set_selected(Gtk.INVALID_LIST_POSITION);

    view.set_api_client(api);
    view.bind_context(project_selection, card_store, card_selection);
    view.set_tool_visible(true);

    assert(wait_until_true(() => {
        return api.list_card_links_calls == 1
            && widget_tree_contains_label_text(view.get_content_widget(), "P2 Unique Node");
    }, 3000));

    project_selection.set_selected(0);
    spin_main_loop_briefly(130);
    project_selection.set_selected(1);

    spin_main_loop_briefly(120);
    assert(widget_tree_contains_label_text(view.get_content_widget(), "P2 Unique Node"));
    assert(!widget_tree_contains_label_text(view.get_content_widget(), "P1 Unique Node"));

    assert(wait_until_true(() => {
        return api.list_card_links_calls == 3
            && widget_tree_contains_label_text(view.get_content_widget(), "P2 Unique Node");
    }, 3000));
}

private void test_duplicate_refresh_triggers_for_same_effective_target_are_suppressed() {
    var api = new MainControllerFakeApi();
    var view = new HolderLinux.ConnectionsToolView();

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
    }, 3000));

    view.set_api_client(api);
    spin_main_loop_briefly(160);
    assert(api.list_card_links_calls == 1);
    assert(api.list_card_backlinks_calls == 1);

    var internal_links = new Gee.ArrayList<string>();
    internal_links.add("Card One");
    view.set_internal_links(internal_links);
    assert(wait_until_true(() => {
        return api.list_card_links_calls == 2 && api.list_card_backlinks_calls == 2;
    }, 3000));

    var same_internal_links = new Gee.ArrayList<string>();
    same_internal_links.add("Card One");
    view.set_internal_links(same_internal_links);
    spin_main_loop_briefly(160);
    assert(api.list_card_links_calls == 2);
    assert(api.list_card_backlinks_calls == 2);
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping connections tool view tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

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

    return Test.run();
}

}
