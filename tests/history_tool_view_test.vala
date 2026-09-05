using GLib;

namespace HolderLinuxTests {

private class FakeHistoryApi : MainControllerFakeApi, HolderLinux.IHistoryApi {
    public int list_history_calls = 0;
    public int compare_history_calls = 0;
    public string? last_project_id;
    public string? last_card_id;
    public string? last_cursor;
    public bool paginate = false;
    public bool newest_is_head = false;
    public string expected_from_oid = "saved-oid";

    public async HolderLinux.CardHistoryPage list_card_history(string project_id,
                                                               string card_id,
                                                               int limit = 50,
                                                               string? cursor = null) throws Error {
        list_history_calls++;
        last_project_id = project_id;
        last_card_id = card_id;
        last_cursor = cursor;
        if (cursor != null) {
            string[] older_parents = { "older-parent" };
            HolderLinux.CardHistoryEntry[] older_entries = {
                new HolderLinux.CardHistoryEntry(
                    "older-oid", "older-oid", older_parents, "Ezra", "ezra@example.test",
                    5, 5, "created", "Card created", 1, false
                )
            };
            return new HolderLinux.CardHistoryPage("head-oid", older_entries, null);
        }
        string[] parents = { newest_is_head ? "previous-oid" : "parent-oid" };
        var oid = newest_is_head ? "head-oid" : "saved-oid";
        HolderLinux.CardHistoryEntry[] entries = {
            new HolderLinux.CardHistoryEntry(
                oid, oid, parents, "Ezra", "ezra@example.test",
                10, 10, "updated", "Changed one line", 1, false
            )
        };
        return new HolderLinux.CardHistoryPage(
            "head-oid", entries, paginate ? "page-cursor" : null
        );
    }

    public async HolderLinux.CardHistoryComparison compare_card_history(string project_id,
                                                                         string card_id,
                                                                         string from_oid,
                                                                         string to_oid) throws Error {
        compare_history_calls++;
        assert(from_oid == expected_from_oid);
        assert(to_oid == "head-oid");
        HolderLinux.CardHistoryDiffLine[] lines = {
            new HolderLinux.CardHistoryDiffLine("-", "Old wording", 1, null),
            new HolderLinux.CardHistoryDiffLine("+", "New wording", null, 1)
        };
        return new HolderLinux.CardHistoryComparison(
            new HolderLinux.CardHistoryVersion(true, from_oid, "Card", "Old wording"),
            new HolderLinux.CardHistoryVersion(true, to_oid, "Card", "New wording"),
            "Changed one line",
            lines,
            false
        );
    }
}

private Gtk.Label? history_find_label(Gtk.Widget root, string text) {
    if (root is Gtk.Label && ((Gtk.Label) root).get_text() == text) return (Gtk.Label) root;
    var child = root.get_first_child();
    while (child != null) {
        var found = history_find_label(child, text);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.TextView? history_find_text_view(Gtk.Widget root) {
    if (root is Gtk.TextView) return (Gtk.TextView) root;
    var child = root.get_first_child();
    while (child != null) {
        var found = history_find_text_view(child);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.Button? history_find_button(Gtk.Widget root, string label) {
    if (root is Gtk.Button && ((Gtk.Button) root).get_label() == label) {
        return (Gtk.Button) root;
    }
    var child = root.get_first_child();
    while (child != null) {
        var found = history_find_button(child, label);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private string text_view_contents(Gtk.TextView view) {
    var buffer = view.get_buffer();
    Gtk.TextIter start;
    Gtk.TextIter end;
    buffer.get_bounds(out start, out end);
    return buffer.get_text(start, end, false);
}

private void test_history_loads_timeline_and_selected_comparison() {
    var api = new FakeHistoryApi();
    var projects = new GLib.ListStore(typeof(HolderLinux.Project));
    projects.append(new HolderLinux.Project("p1", "Home", "plain_git", "/tmp/p1", 1, 1));
    var project_selection = new Gtk.SingleSelection(projects);
    project_selection.set_selected(0);
    var cards = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    cards.append(new HolderLinux.CardSummary("c1", "p1", "Card", "", 0, null, 1, 1));
    var card_selection = new Gtk.SingleSelection(cards);
    card_selection.set_selected(0);

    var view = new HolderLinux.HistoryToolView();
    view.set_api_client(api);
    view.bind_context(project_selection, card_selection);
    view.set_tool_visible(true);

    assert(wait_for_condition(() => api.list_history_calls == 1));
    assert(wait_for_condition(() => api.compare_history_calls == 1));
    assert(api.last_project_id == "p1");
    assert(api.last_card_id == "c1");
    assert(history_find_label(view.widget, "●  Changed one line") != null);
    assert(history_find_label(view.widget, "Changed one line") != null);
    var text_view = history_find_text_view(view.widget);
    assert(text_view != null);
    var contents = text_view_contents((!) text_view);
    assert(contents.contains("- Old wording"));
    assert(contents.contains("+ New wording"));

    // Refreshing and rendering another comparison must reuse the existing text tags.
    view.refresh();
    assert(wait_for_condition(() => api.list_history_calls == 2));
    assert(wait_for_condition(() => api.compare_history_calls == 2));
    contents = text_view_contents((!) text_view);
    assert(contents.contains("+ New wording"));
}

private void test_history_without_card_does_not_call_api() {
    var api = new FakeHistoryApi();
    var view = new HolderLinux.HistoryToolView();
    view.set_api_client(api);
    view.set_tool_visible(true);
    while (MainContext.default().iteration(false)) {}
    assert(api.list_history_calls == 0);
    assert(history_find_label(
        view.widget, "History shows how the selected card reached its current saved version."
    ) != null);
}

private void test_history_loads_older_page() {
    var api = new FakeHistoryApi() { paginate = true };
    var projects = new GLib.ListStore(typeof(HolderLinux.Project));
    projects.append(new HolderLinux.Project("p1", "Home", "plain_git", "/tmp/p1", 1, 1));
    var project_selection = new Gtk.SingleSelection(projects);
    project_selection.set_selected(0);
    var cards = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    cards.append(new HolderLinux.CardSummary("c1", "p1", "Card", "", 0, null, 1, 1));
    var card_selection = new Gtk.SingleSelection(cards);
    card_selection.set_selected(0);

    var view = new HolderLinux.HistoryToolView();
    view.set_api_client(api);
    view.bind_context(project_selection, card_selection);
    view.set_tool_visible(true);
    assert(wait_for_condition(() => api.list_history_calls == 1));
    var button = history_find_button(view.widget, "Load older history");
    assert(button != null);
    ((!) button).clicked();
    assert(wait_for_condition(() => api.list_history_calls == 2));
    assert(api.last_cursor == "page-cursor");
    assert(history_find_label(view.widget, "●  Card created") != null);
    button = history_find_button(view.widget, "Load older history");
    assert(button != null && !((!) button).get_visible());
}

private void test_current_head_compares_its_change() {
    var api = new FakeHistoryApi() {
        newest_is_head = true,
        expected_from_oid = "previous-oid"
    };
    var projects = new GLib.ListStore(typeof(HolderLinux.Project));
    projects.append(new HolderLinux.Project("p1", "Home", "plain_git", "/tmp/p1", 1, 1));
    var project_selection = new Gtk.SingleSelection(projects);
    project_selection.set_selected(0);
    var cards = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    cards.append(new HolderLinux.CardSummary("c1", "p1", "Card", "", 0, null, 1, 1));
    var card_selection = new Gtk.SingleSelection(cards);
    card_selection.set_selected(0);

    var view = new HolderLinux.HistoryToolView();
    view.set_api_client(api);
    view.bind_context(project_selection, card_selection);
    view.set_tool_visible(true);
    assert(wait_for_condition(() => api.compare_history_calls == 1));
}

public static int main(string[] args) {
    Test.init(ref args);
    Gtk.init();
    Test.add_func(
        "/holder/history-tool/timeline-and-comparison",
        test_history_loads_timeline_and_selected_comparison
    );
    Test.add_func("/holder/history-tool/no-card", test_history_without_card_does_not_call_api);
    Test.add_func("/holder/history-tool/load-older-page", test_history_loads_older_page);
    Test.add_func("/holder/history-tool/current-head-change", test_current_head_compares_its_change);
    return Test.run();
}

}
