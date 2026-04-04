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

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping connections tool view tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/holder/connections-tool-view/hidden-refresh-suppressed-until-visible",
                  test_hidden_connections_tool_does_not_refresh_until_visible);

    return Test.run();
}

}
