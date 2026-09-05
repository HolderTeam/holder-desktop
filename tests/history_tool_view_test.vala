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
    public bool newest_is_creation = false;
    public string? expected_from_oid = "saved-oid";
    public string expected_to_oid = "head-oid";
    public string expected_mode = "since";
    public bool return_empty_comparison = false;

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
            HolderLinux.CardHistorySave[] older_saves = {
                new HolderLinux.CardHistorySave("older-oid", older_parents, 5)
            };
            HolderLinux.CardHistoryEntry[] older_entries = {
                new HolderLinux.CardHistoryEntry(
                    "older-oid", "older-oid", older_parents, "Ezra", "ezra@example.test",
                    5, 5, "created", "Card created", 1, false, older_saves
                )
            };
            return new HolderLinux.CardHistoryPage("head-oid", older_entries, null);
        }
        string[] parents = {};
        if (!newest_is_creation) {
            parents += newest_is_head ? "previous-oid" : "parent-oid";
        }
        var oid = newest_is_head || newest_is_creation ? "head-oid" : "saved-oid";
        var first_oid = newest_is_creation ? oid : "first-session-oid";
        HolderLinux.CardHistorySave[] saves = {};
        if (newest_is_creation) {
            saves += new HolderLinux.CardHistorySave(oid, parents, 10, 9, "Add card Card");
        } else {
            string[] first_parents = { "parent-oid" };
            saves += new HolderLinux.CardHistorySave(
                first_oid, first_parents, 9, 8, "Update card Card"
            );
            string[] last_parents = { first_oid };
            saves += new HolderLinux.CardHistorySave(oid, last_parents, 10, 9, "Update card Card");
        }
        HolderLinux.CardHistoryEntry[] entries = {
            new HolderLinux.CardHistoryEntry(
                first_oid, oid, parents, "Ezra", "ezra@example.test",
                10, 10,
                newest_is_creation ? "created" : "updated",
                newest_is_creation ? "Card created" : "Changed one line",
                newest_is_creation ? 1 : 2,
                false,
                saves
            )
        };
        return new HolderLinux.CardHistoryPage(
            "head-oid", entries, paginate ? "page-cursor" : null
        );
    }

    public async HolderLinux.CardHistoryComparison compare_card_history(string project_id,
                                                                         string card_id,
                                                                         string? from_oid,
                                                                         string to_oid,
                                                                         string mode = "since") throws Error {
        compare_history_calls++;
        assert(from_oid == expected_from_oid);
        assert(to_oid == expected_to_oid);
        assert(mode == expected_mode);
        HolderLinux.CardHistoryDiffLine[] lines = {};
        if (!return_empty_comparison) {
            lines += new HolderLinux.CardHistoryDiffLine("-", "Old wording", 1, null);
            lines += new HolderLinux.CardHistoryDiffLine("+", "New wording", null, 1);
        }
        return new HolderLinux.CardHistoryComparison(
            new HolderLinux.CardHistoryVersion(
                from_oid != null, from_oid ?? "", "Card", "Old wording"
            ),
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

private Gtk.Expander? history_find_expander(Gtk.Widget root, string label) {
    if (root is Gtk.Expander && ((Gtk.Expander) root).get_label() == label) {
        return (Gtk.Expander) root;
    }
    var child = root.get_first_child();
    while (child != null) {
        var found = history_find_expander(child, label);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.ScrolledWindow? history_find_timeline_scroll(Gtk.Widget root) {
    if (root is Gtk.ScrolledWindow && ((Gtk.ScrolledWindow) root).get_min_content_width() == 280) {
        return (Gtk.ScrolledWindow) root;
    }
    var child = root.get_first_child();
    while (child != null) {
        var found = history_find_timeline_scroll(child);
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
    string? copied_text = null;
    string? copied_card_title = null;
    string? copied_card_content = null;
    view.history_text_copied.connect((text) => { copied_text = text; });
    view.copy_as_card_requested.connect((title, content) => {
        copied_card_title = title;
        copied_card_content = content;
    });
    view.set_api_client(api);
    view.bind_context(project_selection, card_selection);
    view.set_tool_visible(true);

    assert(wait_for_condition(() => api.list_history_calls == 1));
    assert(wait_for_condition(() => api.compare_history_calls == 1));
    assert(api.last_project_id == "p1");
    assert(api.last_card_id == "c1");
    var timeline_scroll = history_find_timeline_scroll(view.widget);
    assert(timeline_scroll != null && ((!) timeline_scroll).get_vexpand());
    var git_details = history_find_expander(view.widget, "Git details");
    assert(git_details != null);
    ((!) git_details).set_expanded(true);
    assert(history_find_label(view.widget, "Commit: saved-oid") != null);
    assert(history_find_label(view.widget, "Parents: first-session-oid") != null);
    assert(history_find_label(view.widget, "Author: Ezra <ezra@example.test>") != null);
    assert(history_find_label(view.widget, "Message: Update card Card") != null);
    var text_view = history_find_text_view(view.widget);
    assert(text_view != null);
    var copy_text_button = history_find_button(view.widget, "Copy text");
    var copy_commit_button = history_find_button(view.widget, "Copy commit ID");
    var copy_as_card_button = history_find_button(view.widget, "Copy as card");
    assert(copy_as_card_button != null && ((!) copy_as_card_button).get_sensitive());
    assert(copy_text_button != null && ((!) copy_text_button).get_sensitive());
    assert(copy_commit_button != null && ((!) copy_commit_button).get_sensitive());
    ((!) copy_text_button).clicked();
    assert(copied_text != null && ((!) copied_text).contains("- Old wording"));
    ((!) copy_commit_button).clicked();
    assert(copied_text == "saved-oid");
    ((!) copy_as_card_button).clicked();
    assert(copied_card_title != null && ((!) copied_card_title).contains("Copy of Card from Home"));
    assert(copied_card_title != null && ((!) copied_card_title).contains("saved-oi"));
    assert(copied_card_content == text_view_contents((!) text_view));
    assert(history_find_label(view.widget, "●  Changed one line") != null);
    assert(history_find_label(view.widget, "Changed one line") != null);
    var contents = text_view_contents((!) text_view);
    assert(contents.contains("- Old wording"));
    assert(contents.contains("+ New wording"));

    var expander = history_find_expander(view.widget, "Show 2 exact saves");
    assert(expander != null);
    ((!) expander).set_expanded(true);
    var save_time = new DateTime.from_unix_local(9);
    var first_save_button = history_find_button(
        view.widget, "Saved %s".printf(save_time.format("%e %b %Y, %H:%M"))
    );
    assert(first_save_button != null);
    api.expected_from_oid = "first-session-oid";
    api.expected_to_oid = "head-oid";
    api.expected_mode = "since";
    ((!) first_save_button).clicked();
    assert(wait_for_condition(() => api.compare_history_calls == 2));

    api.expected_to_oid = "first-session-oid";
    var version_button = history_find_button(view.widget, "View version");
    assert(version_button != null);
    ((!) version_button).clicked();
    assert(wait_for_condition(() => api.compare_history_calls == 3));
    assert(history_find_label(view.widget, "Card") != null);
    contents = text_view_contents((!) text_view);
    assert(contents == "New wording");

    // A restored selection keeps an explicit View version choice.
    view.refresh();
    assert(wait_for_condition(() => api.list_history_calls == 2));
    assert(wait_for_condition(() => api.compare_history_calls == 4));
    contents = text_view_contents((!) text_view);
    assert(contents == "New wording");

    api.expected_from_oid = "parent-oid";
    api.expected_to_oid = "first-session-oid";
    api.expected_mode = "change";
    var change_button = history_find_button(view.widget, "This change");
    assert(change_button != null);
    ((!) change_button).clicked();
    assert(wait_for_condition(() => api.compare_history_calls == 5));

    // Refreshing and rendering another comparison must reuse the existing text tags.
    view.refresh();
    assert(wait_for_condition(() => api.list_history_calls == 3));
    assert(wait_for_condition(() => api.compare_history_calls == 6));
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
        expected_from_oid = "previous-oid",
        expected_mode = "change"
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
    assert(wait_for_condition(() => api.list_history_calls == 1));
    assert(wait_for_condition(() => api.compare_history_calls == 1));
}

private void test_empty_comparison_explains_unchanged_text() {
    var api = new FakeHistoryApi() { return_empty_comparison = true };
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
    var text_view = history_find_text_view(view.widget);
    assert(text_view != null);
    assert(text_view_contents((!) text_view).contains(
        "No text changes were recorded between these saved versions."
    ));
}

private void test_creation_change_compares_from_missing_card() {
    var api = new FakeHistoryApi() {
        newest_is_creation = true,
        expected_from_oid = null,
        expected_mode = "change"
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
    assert(wait_for_condition(() => api.list_history_calls == 1));
    var change_button = history_find_button(view.widget, "This change");
    assert(change_button != null);
    ((!) change_button).clicked();
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
    Test.add_func(
        "/holder/history-tool/creation-change", test_creation_change_compares_from_missing_card
    );
    Test.add_func(
        "/holder/history-tool/empty-comparison", test_empty_comparison_explains_unchanged_text
    );
    return Test.run();
}

}
