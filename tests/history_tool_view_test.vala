using GLib;

namespace HolderLinuxTests {

private class FakeHistoryApi : MainControllerFakeApi, HolderLinux.IHistoryApi {
    public int list_history_calls = 0;
    public int compare_history_calls = 0;
    public int restore_history_calls = 0;
    public string? last_project_id;
    public string? last_card_id;
    public string? last_cursor;
    public bool paginate = false;
    public bool newest_is_head = false;
    public bool newest_is_creation = false;
    public bool merge_graph = false;
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
        if (merge_graph) {
            string[] merge_parents = { "main-oid", "side-oid" };
            string[] main_parents = { "autosave-oid" };
            string[] side_parents = { "side-base-oid" };
            HolderLinux.CardHistoryEntry[] merge_entries = {
                new HolderLinux.CardHistoryEntry(
                    "merge-oid", "merge-oid", merge_parents, "Alice", "alice@example.test",
                    30, 30, "merged", "Combined changes", 1, true,
                    { new HolderLinux.CardHistorySave("merge-oid", merge_parents, 30) },
                    merge_parents
                ),
                new HolderLinux.CardHistoryEntry(
                    "main-oid", "main-oid", main_parents, "Alice", "alice@example.test",
                    20, 20, "updated", "Main branch", 1, false,
                    { new HolderLinux.CardHistorySave("main-oid", main_parents, 20) },
                    main_parents
                ),
                new HolderLinux.CardHistoryEntry(
                    "side-oid", "side-oid", side_parents, "Bob", "bob@example.test",
                    19, 19, "updated", "Side branch", 1, false,
                    { new HolderLinux.CardHistorySave("side-oid", side_parents, 19) }
                ),
                new HolderLinux.CardHistoryEntry(
                    "autosave-oid", "autosave-oid", {}, "Alice", "alice@example.test",
                    10, 10, "created", "Card created", 1, false,
                    { new HolderLinux.CardHistorySave("autosave-oid", {}, 10) }
                )
            };
            return new HolderLinux.CardHistoryPage("merge-oid", merge_entries, null);
        }
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
        string[] visible_parents = {};
        if (paginate && !newest_is_creation) visible_parents += "older-oid";
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
                saves,
                visible_parents
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

    public async bool restore_card_history(string project_id, string card_id, string oid) throws Error {
        restore_history_calls++;
        return true;
    }
}

private class DelayedHistoryApi : MainControllerFakeApi, HolderLinux.IHistoryApi {
    public int list_history_calls = 0;
    public int compare_history_calls = 0;
    public string? delayed_list_card_id;
    public string? delayed_compare_card_id;
    public uint delay_ms = 50;
    public bool delayed_list_completed = false;
    public bool delayed_compare_completed = false;

    public async HolderLinux.CardHistoryPage list_card_history(string project_id,
                                                               string card_id,
                                                               int limit = 50,
                                                               string? cursor = null) throws Error {
        list_history_calls++;
        if (card_id == delayed_list_card_id) {
            SourceFunc resume = list_card_history.callback;
            Timeout.add(delay_ms, () => {
                delayed_list_completed = true;
                resume();
                return Source.REMOVE;
            });
            yield;
        }
        var oid = "%s-oid".printf(card_id);
        string[] parents = { "%s-parent".printf(card_id) };
        HolderLinux.CardHistoryEntry[] entries = {
            new HolderLinux.CardHistoryEntry(
                oid, oid, parents, "Fixture", "fixture@example.test", 10, 10,
                "updated", "History for %s".printf(card_id), 1, false,
                { new HolderLinux.CardHistorySave(oid, parents, 10) }
            )
        };
        return new HolderLinux.CardHistoryPage(oid, entries, null);
    }

    public async HolderLinux.CardHistoryComparison compare_card_history(string project_id,
                                                                         string card_id,
                                                                         string? from_oid,
                                                                         string to_oid,
                                                                         string mode = "since") throws Error {
        compare_history_calls++;
        if (card_id == delayed_compare_card_id) {
            SourceFunc resume = compare_card_history.callback;
            Timeout.add(delay_ms, () => {
                delayed_compare_completed = true;
                resume();
                return Source.REMOVE;
            });
            yield;
        }
        HolderLinux.CardHistoryDiffLine[] lines = {
            new HolderLinux.CardHistoryDiffLine(
                "+", "New wording for %s".printf(card_id), null, 1
            )
        };
        return new HolderLinux.CardHistoryComparison(
            new HolderLinux.CardHistoryVersion(
                from_oid != null, from_oid ?? "", "Card %s".printf(card_id), "Old wording"
            ),
            new HolderLinux.CardHistoryVersion(true, to_oid, "Card %s".printf(card_id), lines[0].text),
            "History for %s".printf(card_id), lines, false
        );
    }

    public async bool restore_card_history(string project_id, string card_id, string oid) throws Error {
        return true;
    }
}

private class FakeProjectHistoryApi : MainControllerFakeApi, HolderLinux.IProjectHistoryApi {
    public int project_history_calls = 0;
    public string? last_kind;
    public async HolderLinux.ProjectHistoryPage list_project_history(string project_id,
                                                                      int limit = 50,
                                                                      string? cursor = null,
                                                                      string? kind = null) throws Error {
        project_history_calls++;
        last_kind = kind;
        if (cursor == "older-project") {
            HolderLinux.ProjectHistoryActivity[] older = {
                new HolderLinux.ProjectHistoryActivity(
                    "older-project", {}, "Ezra", "ezra@example.test", 9,
                    "Older project activity", {}, false
                )
            };
            return new HolderLinux.ProjectHistoryPage("project-head", older, null);
        }
        HolderLinux.ProjectHistoryAffectedObject[] affected = {
            new HolderLinux.ProjectHistoryAffectedObject("card", {
                new HolderLinux.ProjectHistoryAffectedPath(
                    "cards/ab/cd/card.md", "Project card", "Milestone: Review — Project review"
                )
            }),
            new HolderLinux.ProjectHistoryAffectedObject("resource", {
                new HolderLinux.ProjectHistoryAffectedPath(
                    "resources/ab/cd/resource.json", "Project notes", "Attachment: project-notes.pdf"
                )
            }),
            new HolderLinux.ProjectHistoryAffectedObject("ai_data", {
                new HolderLinux.ProjectHistoryAffectedPath(
                    "ai_messages/ab/cd/message.md", "Release review", "user: Can you review the release notes?"
                )
            }),
            new HolderLinux.ProjectHistoryAffectedObject("project_settings", {
                new HolderLinux.ProjectHistoryAffectedPath(
                    ".holder/privacy.json", "Privacy settings", "Mode: plain Git"
                )
            }),
            new HolderLinux.ProjectHistoryAffectedObject("unknown", {
                new HolderLinux.ProjectHistoryAffectedPath("notes/external.txt")
            })
        };
        HolderLinux.ProjectHistoryActivity[] activities = {
            new HolderLinux.ProjectHistoryActivity(
                "project-head", { "project-main", "project-side" }, "Ezra", "ezra@example.test", 10,
                "Attach project resource", affected, true
            ),
            new HolderLinux.ProjectHistoryActivity(
                "project-main", { "project-base" }, "Ezra", "ezra@example.test", 9,
                "Update main project work", {}, false
            ),
            new HolderLinux.ProjectHistoryActivity(
                "project-side", { "project-base" }, "Mina", "mina@example.test", 8,
                "Update side project work", {}, false
            ),
            new HolderLinux.ProjectHistoryActivity(
                "project-base", {}, "Ezra", "ezra@example.test", 7,
                "Project created", {}, false
            )
        };
        return new HolderLinux.ProjectHistoryPage("project-head", activities, "older-project");
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

private bool history_has_label_containing(Gtk.Widget root, string text) {
    if (root is Gtk.Label && ((Gtk.Label) root).get_text().contains(text)) return true;
    var child = root.get_first_child();
    while (child != null) {
        if (history_has_label_containing(child, text)) return true;
        child = child.get_next_sibling();
    }
    return false;
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

private Gtk.DropDown? history_find_dropdown(Gtk.Widget root) {
    if (root is Gtk.DropDown) return (Gtk.DropDown) root;
    var child = root.get_first_child();
    while (child != null) {
        var found = history_find_dropdown(child);
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

private Gtk.Widget? history_find_lane_gutter(Gtk.Widget root) {
    if (root.has_css_class("history-lane-gutter")) return root;
    var child = root.get_first_child();
    while (child != null) {
        var found = history_find_lane_gutter(child);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private void history_collect_lane_gutters(Gtk.Widget root, Gee.ArrayList<Gtk.Widget> gutters) {
    if (root.has_css_class("history-lane-gutter")) gutters.add(root);
    var child = root.get_first_child();
    while (child != null) {
        history_collect_lane_gutters(child, gutters);
        child = child.get_next_sibling();
    }
}

private string text_view_contents(Gtk.TextView view) {
    var buffer = view.get_buffer();
    Gtk.TextIter start;
    Gtk.TextIter end;
    buffer.get_bounds(out start, out end);
    return buffer.get_text(start, end, false);
}

private void setup_history_context(out Gtk.SingleSelection project_selection,
                                   out Gtk.SingleSelection card_selection) {
    var projects = new GLib.ListStore(typeof(HolderLinux.Project));
    projects.append(new HolderLinux.Project("p1", "Home", "plain_git", "/tmp/p1", 1, 1));
    project_selection = new Gtk.SingleSelection(projects);
    project_selection.set_selected(0);
    var cards = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    cards.append(new HolderLinux.CardSummary("c1", "p1", "Card A", "", 0, null, 1, 1));
    cards.append(new HolderLinux.CardSummary("c2", "p1", "Card B", "", 0, null, 1, 1));
    card_selection = new Gtk.SingleSelection(cards);
    card_selection.set_selected(0);
}

private void test_history_late_list_response_keeps_newer_card() {
    var api = new DelayedHistoryApi() { delayed_list_card_id = "c1" };
    Gtk.SingleSelection project_selection;
    Gtk.SingleSelection card_selection;
    setup_history_context(out project_selection, out card_selection);
    var view = new HolderLinux.HistoryToolView();
    view.set_api_client(api);
    view.bind_context(project_selection, card_selection);
    view.set_tool_visible(true);

    assert(wait_for_condition(() => api.list_history_calls == 1));
    card_selection.set_selected(1);
    assert(wait_for_condition(() => api.list_history_calls == 2));
    assert(wait_for_condition(() => api.compare_history_calls == 1));
    assert(wait_for_condition(() => api.delayed_list_completed));

    var text_view = history_find_text_view(view.widget);
    assert(text_view != null);
    assert(history_find_label(view.widget, "History for c2") != null);
    var contents = text_view_contents((!) text_view);
    assert(contents.contains("New wording for c2"));
    assert(!contents.contains("New wording for c1"));
}

private void test_history_late_comparison_response_keeps_newer_card() {
    var api = new DelayedHistoryApi() { delayed_compare_card_id = "c1" };
    Gtk.SingleSelection project_selection;
    Gtk.SingleSelection card_selection;
    setup_history_context(out project_selection, out card_selection);
    var view = new HolderLinux.HistoryToolView();
    view.set_api_client(api);
    view.bind_context(project_selection, card_selection);
    view.set_tool_visible(true);

    assert(wait_for_condition(() => api.list_history_calls == 1));
    assert(wait_for_condition(() => api.compare_history_calls == 1));
    card_selection.set_selected(1);
    assert(wait_for_condition(() => api.list_history_calls == 2));
    assert(wait_for_condition(() => api.compare_history_calls == 2));
    assert(wait_for_condition(() => api.delayed_compare_completed));

    var text_view = history_find_text_view(view.widget);
    assert(text_view != null);
    assert(history_find_label(view.widget, "History for c2") != null);
    var contents = text_view_contents((!) text_view);
    assert(contents.contains("New wording for c2"));
    assert(!contents.contains("New wording for c1"));
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
    var debug_lines = new Gee.ArrayList<string>();
    view.history_text_copied.connect((text) => { copied_text = text; });
    view.copy_as_card_requested.connect((title, content) => {
        copied_card_title = title;
        copied_card_content = content;
    });
    view.debug_log_requested.connect((line) => { debug_lines.add(line); });
    view.set_api_client(api);
    view.bind_context(project_selection, card_selection);
    view.set_tool_visible(true);

    assert(wait_for_condition(() => api.list_history_calls == 1));
    assert(wait_for_condition(() => api.compare_history_calls == 1));
    assert(api.last_project_id == "p1");
    assert(api.last_card_id == "c1");
    assert(debug_lines.any_match((line) => line.contains("History loaded: 1 entries at head-oid")));
    assert(debug_lines.any_match((line) => line.contains(
        "History compared saved-oi to head-oid (since; 2 lines)"
    )));
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
    assert(debug_lines.any_match((line) => line.contains(
        "History copy as card requested from saved-oi"
    )));
    assert(history_find_label(view.widget, "Changed one line") != null);
    var lane_gutter = history_find_lane_gutter(view.widget);
    assert(lane_gutter != null);
    assert(((!) lane_gutter).get_tooltip_text().contains("lane 1 of 1"));
    assert(((!) lane_gutter).get_tooltip_text().contains("no direct visible parents"));
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

private void test_project_history_renders_without_a_card() {
    var api = new FakeProjectHistoryApi();
    var projects = new GLib.ListStore(typeof(HolderLinux.Project));
    projects.append(new HolderLinux.Project("p1", "Home", "plain_git", "/tmp/p1", 1, 1));
    var project_selection = new Gtk.SingleSelection(projects);
    project_selection.set_selected(0);
    var cards = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var card_selection = new Gtk.SingleSelection(cards);
    var view = new HolderLinux.HistoryToolView();
    string? opened_card = null;
    string? opened_resource = null;
    view.project_history_card_open_requested.connect((card_id) => { opened_card = card_id; });
    view.project_history_resource_open_requested.connect((resource_id) => { opened_resource = resource_id; });
    view.set_api_client(api);
    view.bind_context(project_selection, card_selection);
    view.set_tool_visible(true);

    assert(wait_for_condition(() => api.project_history_calls == 1));
    assert(history_find_label(view.widget, "Merged: Attach project resource") != null);
    assert(history_has_label_containing(view.widget, "Merged from 2 parents"));
    var gutters = new Gee.ArrayList<Gtk.Widget>();
    history_collect_lane_gutters(view.widget, gutters);
    assert(gutters.size == 4);
    assert(gutters[0].get_tooltip_text().contains("lane 1 of 2"));
    assert(gutters[0].get_tooltip_text().contains("2 direct visible parents"));
    assert(gutters[1].get_tooltip_text().contains("lane 1 of 2"));
    assert(gutters[2].get_tooltip_text().contains("lane 2 of 2"));
    assert(history_find_label(view.widget, "Other Git changes (1)") != null);
    var affected = history_find_expander(view.widget, "Show 5 affected items");
    assert(affected != null);
    ((!) affected).set_expanded(true);
    var card_button = history_find_button(
        view.widget, "card: Project card — cards/ab/cd/card.md · Milestone: Review — Project review"
    );
    assert(card_button != null);
    ((!) card_button).clicked();
    assert(opened_card == "card");
    var resource_button = history_find_button(
        view.widget, "resource: Project notes — resources/ab/cd/resource.json · Attachment: project-notes.pdf"
    );
    assert(resource_button != null);
    ((!) resource_button).clicked();
    assert(opened_resource == "resource");
    assert(history_find_label(
        view.widget,
        "ai data: Release review — ai_messages/ab/cd/message.md · user: Can you review the release notes?"
    ) != null);
    assert(history_find_label(
        view.widget, "project settings: Privacy settings — .holder/privacy.json · Mode: plain Git"
    ) != null);
    assert(history_find_label(view.widget, "Other Git change: notes/external.txt") != null);
    var filter = history_find_dropdown(view.widget);
    assert(filter != null);
    ((!) filter).set_selected(2);
    assert(wait_for_condition(() => api.project_history_calls == 2));
    assert(api.last_kind == "resource");
    var older = history_find_button(view.widget, "Load older activity");
    assert(older != null);
    ((!) older).clicked();
    assert(wait_for_condition(() => api.project_history_calls == 3));
    assert(history_find_label(view.widget, "Older project activity") != null);
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
    assert(history_find_label(view.widget, "Card created") != null);
    var lane_gutter = history_find_lane_gutter(view.widget);
    assert(lane_gutter != null);
    assert(((!) lane_gutter).get_tooltip_text().contains("1 direct visible parent"));
    button = history_find_button(view.widget, "Load older history");
    assert(button != null && !((!) button).get_visible());
}

private void test_history_restores_selected_version_and_refreshes() {
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
    bool restore_notified = false;
    view.restore_succeeded.connect((project_id, card_id) => {
        restore_notified = project_id == "p1" && card_id == "c1";
    });
    view.set_api_client(api);
    view.bind_context(project_selection, card_selection);
    view.set_tool_visible(true);
    assert(wait_for_condition(() => api.list_history_calls == 1));
    view.restore_selected_version.begin("saved-oid");
    assert(wait_for_condition(() => api.restore_history_calls == 1));
    assert(wait_for_condition(() => restore_notified));
    assert(wait_for_condition(() => api.list_history_calls == 2));
}

private void test_history_merge_uses_aligned_page_lanes() {
    var api = new FakeHistoryApi() {
        merge_graph = true,
        expected_from_oid = "main-oid",
        expected_to_oid = "merge-oid",
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

    var gutters = new Gee.ArrayList<Gtk.Widget>();
    history_collect_lane_gutters(view.widget, gutters);
    assert(gutters.size == 4);
    var merge_gutter = gutters[0] as Gtk.DrawingArea;
    assert(merge_gutter != null && ((!) merge_gutter).get_content_width() == 56);
    assert(gutters[0].get_tooltip_text().contains("lane 1 of 2"));
    assert(gutters[0].get_tooltip_text().contains("2 direct visible parents"));
    assert(gutters[1].get_tooltip_text().contains("lane 1 of 2"));
    assert(gutters[2].get_tooltip_text().contains("lane 2 of 2"));
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

// ---- release-quality pass: shell surface, states, clipboard seam and bug regressions ----

private class HvsApi : MainControllerFakeApi, HolderLinux.IHistoryApi, HolderLinux.IProjectHistoryApi {
    public bool fail_card { get; set; default = false; }
    public bool fail_project { get; set; default = false; }
    public bool shared_oids { get; set; default = false; }
    public bool paginate { get; set; default = false; }
    public bool fail_older { get; set; default = false; }
    public bool fail_compare { get; set; default = false; }
    public bool fail_restore { get; set; default = false; }
    public bool stall_restore { get; set; default = false; }
    public bool project_empty { get; set; default = false; }
    public bool project_paginate { get; set; default = false; }
    public bool fail_project_older { get; set; default = false; }
    public Gee.HashSet<string> empty_cards = new Gee.HashSet<string>();
    public int card_calls = 0;
    public int project_calls = 0;
    public Gee.ArrayList<string> compares = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> restores = new Gee.ArrayList<string>();
    private SourceFunc? stalled_restore = null;

    public bool has_stalled_restore() {
        return stalled_restore != null;
    }

    public void release_stalled_restore() {
        if (stalled_restore != null) {
            var resume = (owned) stalled_restore;
            stalled_restore = null;
            resume();
        }
    }

    public async HolderLinux.CardHistoryPage list_card_history(string project_id,
                                                               string card_id,
                                                               int limit = 50,
                                                               string? cursor = null) throws Error {
        card_calls++;
        if (fail_card) throw new IOError.FAILED("card history down");
        if (cursor != null) {
            if (fail_older) throw new IOError.FAILED("older down");
            string[] older_parents = {};
            HolderLinux.CardHistoryEntry[] older = {
                new HolderLinux.CardHistoryEntry(
                    "%s-0".printf(card_id), "%s-0".printf(card_id), older_parents, "Ezra",
                    "ezra@example.test", 5, 5, "created", "Older change", 1, false,
                    { new HolderLinux.CardHistorySave("%s-0".printf(card_id), older_parents, 5) }
                )
            };
            return new HolderLinux.CardHistoryPage("%s-2".printf(card_id), older, null);
        }
        if (empty_cards.contains(card_id)) {
            HolderLinux.CardHistoryEntry[] none = {};
            return new HolderLinux.CardHistoryPage("head", none, null);
        }
        var prefix = shared_oids ? "shared" : card_id;
        var newest = "%s-2".printf(prefix);
        var oldest = "%s-1".printf(prefix);
        string[] newest_parents = { oldest };
        string[] no_parents = {};
        string[] visible = { oldest };
        HolderLinux.CardHistoryEntry[] entries = {
            new HolderLinux.CardHistoryEntry(
                newest, newest, newest_parents, "Ezra", "ezra@example.test", 20, 20,
                "updated", "Second change", 1, false,
                { new HolderLinux.CardHistorySave(newest, newest_parents, 20) }, visible
            ),
            new HolderLinux.CardHistoryEntry(
                oldest, oldest, no_parents, "Ezra", "ezra@example.test", 10, 10,
                "created", "Card created", 1, false,
                { new HolderLinux.CardHistorySave(oldest, no_parents, 10) }
            )
        };
        return new HolderLinux.CardHistoryPage(newest, entries, paginate ? "older-cursor" : null);
    }

    public async HolderLinux.CardHistoryComparison compare_card_history(string project_id,
                                                                         string card_id,
                                                                         string? from_oid,
                                                                         string to_oid,
                                                                         string mode = "since") throws Error {
        compares.add("%s:%s>%s:%s".printf(card_id, from_oid ?? "none", to_oid, mode));
        if (fail_compare) throw new IOError.FAILED("compare down");
        HolderLinux.CardHistoryDiffLine[] lines = {
            new HolderLinux.CardHistoryDiffLine(" ", "Unchanged line", 1, 1),
            new HolderLinux.CardHistoryDiffLine("+", "Wording %s".printf(to_oid), null, 2)
        };
        return new HolderLinux.CardHistoryComparison(
            new HolderLinux.CardHistoryVersion(from_oid != null, from_oid ?? "", "Card", "Old"),
            new HolderLinux.CardHistoryVersion(true, to_oid, "Card", "Wording %s".printf(to_oid)),
            "Change %s".printf(to_oid), lines, false
        );
    }

    public async bool restore_card_history(string project_id, string card_id, string oid) throws Error {
        restores.add("%s:%s".printf(card_id, oid));
        if (stall_restore) {
            stall_restore = false;
            stalled_restore = restore_card_history.callback;
            yield;
        }
        if (fail_restore) throw new IOError.FAILED("restore down");
        return true;
    }

    public async HolderLinux.ProjectHistoryPage list_project_history(string project_id,
                                                                      int limit = 50,
                                                                      string? cursor = null,
                                                                      string? kind = null) throws Error {
        project_calls++;
        if (fail_project) throw new IOError.FAILED("project history down");
        if (cursor != null) {
            if (fail_project_older) throw new IOError.FAILED("older project down");
            HolderLinux.ProjectHistoryAffectedObject[] no_items = {};
            HolderLinux.ProjectHistoryActivity[] older = {
                new HolderLinux.ProjectHistoryActivity(
                    "project-old", {}, "Ezra", "ezra@example.test", 5, "Older project change", no_items, false
                )
            };
            return new HolderLinux.ProjectHistoryPage("project-head", older, null);
        }
        if (project_empty) {
            HolderLinux.ProjectHistoryActivity[] none = {};
            return new HolderLinux.ProjectHistoryPage("project-head", none, null);
        }
        HolderLinux.ProjectHistoryAffectedObject[] affected = {
            new HolderLinux.ProjectHistoryAffectedObject("card", {
                new HolderLinux.ProjectHistoryAffectedPath("cards/c9.md")
            }),
            new HolderLinux.ProjectHistoryAffectedObject("resource", {
                new HolderLinux.ProjectHistoryAffectedPath("resources/r9.json")
            }),
            new HolderLinux.ProjectHistoryAffectedObject("ai_data", {
                new HolderLinux.ProjectHistoryAffectedPath("ai_threads/t9.json")
            })
        };
        HolderLinux.ProjectHistoryActivity[] activities = {
            new HolderLinux.ProjectHistoryActivity(
                "project-head", {}, "Ezra", "ezra@example.test", 10, "Project created", affected, false
            )
        };
        return new HolderLinux.ProjectHistoryPage(
            "project-head", activities, project_paginate ? "older-project" : null
        );
    }
}

private class HvsClipboard : Object, HolderLinux.ITextClipboard {
    public bool available { get; set; default = true; }
    public Gee.ArrayList<string> copied = new Gee.ArrayList<string>();

    public bool set_text(string text) {
        if (!available) return false;
        copied.add(text);
        return true;
    }
}

private class HvsHarness : Object {
    public HvsApi api = new HvsApi();
    public HvsClipboard clipboard = new HvsClipboard();
    public Adw.Window window = new Adw.Window();
    public HolderLinux.HistoryToolView view;
    public Gtk.SingleSelection project_selection;
    public Gtk.SingleSelection card_selection;
    public Gee.ArrayList<string> errors = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> debug = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> copied_signals = new Gee.ArrayList<string>();

    public HvsHarness(bool with_cards = true, bool bind = true, bool attach_window = false) {
        hvs_context(with_cards, out project_selection, out card_selection);
        view = new HolderLinux.HistoryToolView(clipboard);
        if (attach_window) window.set_content(view.widget);
        view.error_reported.connect((title, details) => { errors.add("%s|%s".printf(title, details)); });
        view.debug_log_requested.connect((line) => { debug.add(line); });
        view.history_text_copied.connect((text) => { copied_signals.add(text); });
        view.set_api_client(api);
        if (bind) view.bind_context(project_selection, card_selection);
        view.set_tool_visible(true);
    }

    public string page() {
        return ((Gtk.Stack) view.widget).get_visible_child_name();
    }

    public Adw.AlertDialog? dialog() {
        return window.get_visible_dialog() as Adw.AlertDialog;
    }

    public bool wait_for_page(string name) {
        return wait_for_condition(() => page() == name);
    }

    public Gtk.ListBox timeline() {
        var found = hvs_find_timeline(view.widget);
        assert(found != null);
        return (!) found;
    }

    public int selected_row_index() {
        var row = timeline().get_selected_row();
        assert(row != null);
        return ((!) row).get_index();
    }

    public Gtk.Button button(string label) {
        var found = history_find_button(view.widget, label);
        assert(found != null);
        return (!) found;
    }

    // The git detail labels are only reachable once their expander has been opened.
    public void open_git_details() {
        var expander = history_find_expander(view.widget, "Git details");
        assert(expander != null);
        ((!) expander).set_expanded(true);
    }
}

private void hvs_context(bool with_cards,
                         out Gtk.SingleSelection project_selection,
                         out Gtk.SingleSelection card_selection) {
    var projects = new GLib.ListStore(typeof(HolderLinux.Project));
    projects.append(new HolderLinux.Project("p1", "Home", "plain_git", "/tmp/p1", 1, 1));
    project_selection = new Gtk.SingleSelection(projects);
    project_selection.set_selected(0);
    var cards = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    if (with_cards) {
        cards.append(new HolderLinux.CardSummary("c1", "p1", "Card A", "", 0, null, 1, 1));
        cards.append(new HolderLinux.CardSummary("c2", "p1", "Card B", "", 0, null, 1, 1));
    }
    card_selection = new Gtk.SingleSelection(cards);
    if (with_cards) card_selection.set_selected(0);
}

private Gtk.ListBox? hvs_find_timeline(Gtk.Widget root) {
    // The card timeline is the single-selection list box; the project timeline selects nothing.
    if (root is Gtk.ListBox && ((Gtk.ListBox) root).get_selection_mode() == Gtk.SelectionMode.SINGLE) {
        return (Gtk.ListBox) root;
    }
    var child = root.get_first_child();
    while (child != null) {
        var found = hvs_find_timeline(child);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private void hvs_settle() {
    while (MainContext.default().iteration(false)) {}
}

private void test_hvs_shell_adapter_reports_identity_scope_and_navigation() {
    var view = new HolderLinux.HistoryToolView(new HvsClipboard());
    assert(view.tool_id == "history");
    assert(view.tool_label == "History");
    assert(view.get_content_widget() == view.widget);
    assert(view.get_actions_widget() != null);

    var project = new HolderLinux.Project("p1", "Home", "plain_git", "/tmp/p1", 1, 1);
    var card = new HolderLinux.CardSummary("c1", "p1", "Card A", "", 0, null, 1, 1);
    var nothing = view.get_scope_snapshot(null, null);
    assert(nothing.scope_mode == HolderLinux.ToolScopeMode.PROJECTS_ROOT);
    assert(nothing.project_id == null && nothing.project_label == "Projects");
    assert(nothing.card_id == null && nothing.card_label == "Select a card");
    var project_only = view.get_scope_snapshot(project, null);
    assert(project_only.scope_mode == HolderLinux.ToolScopeMode.PROJECT_ROOT);
    assert(project_only.project_id == "p1" && project_only.project_label == "Home");
    assert(project_only.card_id == null && project_only.card_label == "Select a card");
    var focused = view.get_scope_snapshot(project, card);
    assert(focused.scope_mode == HolderLinux.ToolScopeMode.CARD_FOCUS);
    assert(focused.card_id == "c1" && focused.card_label == "Card A");
    assert(focused.tool_id == "history" && focused.tool_label == "History" && !focused.is_loading);

    bool root_ok = false;
    bool project_ok = false;
    bool card_ok = false;
    view.navigate_to_projects_root.begin(null, (obj, res) => { root_ok = view.navigate_to_projects_root.end(res); });
    view.navigate_to_project_root.begin("p1", (obj, res) => { project_ok = view.navigate_to_project_root.end(res); });
    view.navigate_to_card.begin("c1", (obj, res) => { card_ok = view.navigate_to_card.end(res); });
    assert(wait_for_condition(() => root_ok && project_ok && card_ok));
}

private void test_hvs_rebinding_stops_listening_to_the_old_selections() {
    var h = new HvsHarness();
    assert(wait_for_condition(() => h.api.card_calls >= 1));
    assert(h.wait_for_page("history"));

    Gtk.SingleSelection second_projects;
    Gtk.SingleSelection second_cards;
    hvs_context(true, out second_projects, out second_cards);
    var before_rebind = h.api.card_calls;
    h.view.bind_context(second_projects, second_cards);
    assert(wait_for_condition(() => h.api.card_calls > before_rebind));
    hvs_settle();
    var settled = h.api.card_calls;

    // The first context is no longer bound, so moving its selection must not refresh anything.
    h.card_selection.set_selected(1);
    hvs_settle();
    assert(h.api.card_calls == settled);

    // Precondition for the assertion above: the newly bound context does refresh.
    second_cards.set_selected(1);
    assert(wait_for_condition(() => h.api.card_calls > settled));
}

private void test_hvs_choosing_another_row_compares_that_version() {
    var h = new HvsHarness();
    assert(h.wait_for_page("history"));
    assert(wait_for_condition(() => h.api.compares.size == 1));
    assert(h.selected_row_index() == 0);

    var older = h.timeline().get_row_at_index(1);
    assert(older != null);
    h.timeline().select_row(older);

    assert(wait_for_condition(() => h.api.compares.size == 2));
    assert(h.api.compares[1].contains("c1-1"));
    assert(h.selected_row_index() == 1);
}

private void test_hvs_the_change_toggle_compares_the_change() {
    var h = new HvsHarness();
    assert(h.wait_for_page("history"));
    assert(wait_for_condition(() => h.api.compares.size == 1));
    // Start from the older row, which defaults to "since this version", so the toggle really changes mode.
    h.timeline().select_row(h.timeline().get_row_at_index(1));
    assert(wait_for_condition(() => h.api.compares.size == 2));
    assert(h.api.compares[1].has_suffix(":since"));

    ((Gtk.ToggleButton) h.button("This change")).set_active(true);

    assert(wait_for_condition(() => h.api.compares.size == 3));
    assert(h.api.compares[2].has_suffix(":change"));
}

private void test_hvs_project_history_without_a_project_history_api_shows_the_empty_page() {
    var h = new HvsHarness(false);
    assert(h.wait_for_page("project"));
    assert(history_find_label(h.view.widget, "Project created") != null);

    // An API that only knows card history leaves nothing to show for the project overview.
    h.view.set_api_client(new FakeHistoryApi());

    assert(h.wait_for_page("empty"));
    assert(h.errors.size == 0);
}

private void test_hvs_a_failed_project_history_load_shows_the_error_page() {
    var h = new HvsHarness(false, false);
    h.api.fail_project = true;
    h.view.bind_context(h.project_selection, h.card_selection);

    assert(h.wait_for_page("error"));
    assert(h.errors.size == 1);
    assert(h.errors[0] == "Failed to load project history|project history down");
}

private void test_hvs_a_failed_card_history_load_shows_the_error_page_and_forgets_the_details() {
    var h = new HvsHarness();
    assert(h.wait_for_page("history"));
    assert(wait_for_condition(() => h.api.compares.size == 1));
    h.open_git_details();
    assert(history_find_label(h.view.widget, "Commit: c1-2") != null);
    assert(h.button("Copy commit ID").get_sensitive());

    h.api.fail_card = true;
    h.card_selection.set_selected(1);

    assert(h.wait_for_page("error"));
    assert(h.errors.size == 1);
    assert(h.errors[0] == "Failed to load card history|card history down");
    assert(h.debug.any_match((line) => line.contains("History load failed: card history down")));
    // Nothing of card A may stay behind for a later refresh or a stray click to act on.
    assert(history_find_label(h.view.widget, "Commit: c1-2") == null);
    assert(!h.button("Copy commit ID").get_sensitive());
    assert(!h.button("Restore this version").get_sensitive());
}

private void test_hvs_a_card_without_history_clears_the_previous_cards_details() {
    var h = new HvsHarness();
    h.api.empty_cards.add("c2");
    assert(h.wait_for_page("history"));
    assert(wait_for_condition(() => h.api.compares.size == 1));
    // Choose the older saved version, which can be restored.
    h.timeline().select_row(h.timeline().get_row_at_index(1));
    assert(wait_for_condition(() => h.api.compares.size == 2));
    assert(wait_for_condition(() => h.button("Restore this version").get_sensitive()));
    h.open_git_details();
    assert(history_find_label(h.view.widget, "Commit: c1-1") != null);
    assert(wait_for_condition(() => h.button("Copy text").get_sensitive()));

    h.card_selection.set_selected(1);

    assert(wait_for_condition(() => h.api.card_calls == 2));
    assert(wait_for_condition(() => history_find_label(h.view.widget, "No saved history yet") != null));
    assert(h.page() == "history");
    assert(history_find_label(h.view.widget, "Commit: c1-1") == null);
    assert(!h.button("Restore this version").get_sensitive());
    assert(!h.button("Copy commit ID").get_sensitive());
    assert(!h.button("Copy text").get_sensitive());
    assert(!h.button("Copy as card").get_sensitive());
    var text_view = history_find_text_view(h.view.widget);
    assert(text_view != null && text_view_contents((!) text_view) == "");
}

private void test_hvs_a_commit_shared_by_two_cards_does_not_carry_the_chosen_row_across() {
    var h = new HvsHarness();
    h.api.shared_oids = true;
    h.view.refresh();
    assert(wait_for_condition(() => h.api.card_calls == 2));
    assert(h.wait_for_page("history"));
    hvs_settle();
    h.timeline().select_row(h.timeline().get_row_at_index(1));
    assert(h.selected_row_index() == 1);

    // The same card refreshing in the background keeps the user's explicit choice ...
    h.view.refresh();
    assert(wait_for_condition(() => h.api.card_calls == 3));
    assert(wait_for_condition(() => h.selected_row_index() == 1));

    // ... but another card that merely contains the same commit starts from its own default row.
    h.card_selection.set_selected(1);
    assert(wait_for_condition(() => h.api.card_calls == 4));
    assert(wait_for_condition(() => h.api.compares.size >= 3 && h.api.compares[h.api.compares.size - 1].has_prefix("c2:")));
    assert(h.selected_row_index() == 0);
}

private void test_hvs_copy_actions_go_through_the_clipboard() {
    var h = new HvsHarness();
    assert(h.wait_for_page("history"));
    assert(wait_for_condition(() => h.api.compares.size == 1));
    assert(wait_for_condition(() => h.button("Copy text").get_sensitive()));

    h.button("Copy text").clicked();
    assert(h.clipboard.copied.size == 1);
    assert(h.clipboard.copied[0].contains("Wording c1-2"));
    assert(h.copied_signals.size == 1 && h.copied_signals[0] == h.clipboard.copied[0]);
    assert(h.debug.any_match((line) => line == HolderLinux.HistoryPresenter.copied_debug(h.clipboard.copied[0].length)));

    h.button("Copy commit ID").clicked();
    assert(h.clipboard.copied.size == 2 && h.clipboard.copied[1] == "c1-2");
    assert(h.errors.size == 0);
}

private void test_hvs_copying_without_a_clipboard_reports_the_error() {
    var h = new HvsHarness();
    assert(h.wait_for_page("history"));
    assert(wait_for_condition(() => h.api.compares.size == 1));
    assert(wait_for_condition(() => h.button("Copy commit ID").get_sensitive()));
    h.clipboard.available = false;

    h.button("Copy commit ID").clicked();

    assert(h.errors.size == 1 && h.errors[0] == "Clipboard unavailable|No display available.");
    assert(h.copied_signals.size == 0);
    assert(h.clipboard.copied.size == 0);
}

private int hvs_ink(Cairo.ImageSurface surface) {
    surface.flush();
    unowned uchar[] data = surface.get_data();
    var stride = surface.get_stride();
    int ink = 0;
    for (int y = 0; y < surface.get_height(); y++) {
        for (int x = 0; x < surface.get_width(); x++) {
            if (data[y * stride + x * 4 + 3] != 0) ink++;
        }
    }
    return ink;
}

// A position-weighted sum of the alpha channel: two shapes that cover the same area (a circle and a
// diamond of similar size) still give different values.
private int64 hvs_fingerprint(Cairo.ImageSurface surface) {
    surface.flush();
    unowned uchar[] data = surface.get_data();
    var stride = surface.get_stride();
    int64 sum = 0;
    for (int y = 0; y < surface.get_height(); y++) {
        for (int x = 0; x < surface.get_width(); x++) {
            sum += (int64) data[y * stride + x * 4 + 3] * (x * 31 + y * 17 + 1);
        }
    }
    return sum;
}

// Renders the gutter through its real draw function: a Gtk.DrawingArea draws from snapshot(), so the
// widget is allocated, snapshotted and the resulting render node is drawn into an image.
private Cairo.ImageSurface hvs_draw_surface(HolderLinux.HistoryLaneGutter gutter) {
    gutter.allocate(48, 48, -1, null);
    var snapshot = new Gtk.Snapshot();
    gutter.snapshot(snapshot);
    var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, 48, 48);
    var node = snapshot.to_node();
    if (node != null) {
        var cr = new Cairo.Context(surface);
        ((!) node).draw(cr);
    }
    return surface;
}

private int hvs_draw(HolderLinux.HistoryLaneGutter gutter) {
    return hvs_ink(hvs_draw_surface(gutter));
}

private void test_hvs_the_lane_gutter_draws_lines_bends_and_merge_markers() {
    var gutter = new HolderLinux.HistoryLaneGutter();
    assert(hvs_draw(gutter) == 0);

    // a merges b and c, which both continue to d: covers straight, bending and closing lanes.
    HolderLinux.HistoryLaneNode[] nodes = {
        new HolderLinux.HistoryLaneNode("a", { "b", "c" }),
        new HolderLinux.HistoryLaneNode("b", { "d" }),
        new HolderLinux.HistoryLaneNode("c", { "d" }),
        new HolderLinux.HistoryLaneNode("d", {})
    };
    var graph = HolderLinux.HistoryLaneAssigner.compute(nodes, HolderLinux.HistoryLaneParentRule.AS_GIVEN);
    assert(graph.layouts.length == 4);
    for (int i = 0; i < graph.layouts.length; i++) {
        gutter.set_layout(graph.layouts[i], graph.lane_count, false);
        assert(hvs_draw(gutter) > 0);
    }

    // A node with one parent is a dot unless the entry is a merge, which draws the diamond marker.
    gutter.set_layout(graph.layouts[1], graph.lane_count, false);
    var as_dot = hvs_fingerprint(hvs_draw_surface(gutter));
    gutter.set_layout(graph.layouts[1], graph.lane_count, true);
    var as_merge = hvs_fingerprint(hvs_draw_surface(gutter));
    assert(as_dot > 0 && as_merge > 0);
    assert(as_merge != as_dot);

    // A node with two parents always gets the diamond, whatever the entry says.
    gutter.set_layout(graph.layouts[0], graph.lane_count, false);
    var two_parents = hvs_fingerprint(hvs_draw_surface(gutter));
    gutter.set_layout(graph.layouts[0], graph.lane_count, true);
    assert(hvs_fingerprint(hvs_draw_surface(gutter)) == two_parents);
}

private void hvs_expand_all(Gtk.Widget root) {
    if (root is Gtk.Expander) ((Gtk.Expander) root).set_expanded(true);
    var child = root.get_first_child();
    while (child != null) {
        hvs_expand_all(child);
        child = child.get_next_sibling();
    }
}

private void hvs_select_older_row(HvsHarness h) {
    assert(h.wait_for_page("history"));
    assert(wait_for_condition(() => h.api.compares.size >= 1));
    var before = h.api.compares.size;
    h.timeline().select_row(h.timeline().get_row_at_index(1));
    assert(wait_for_condition(() => h.api.compares.size > before));
    assert(wait_for_condition(() => h.button("Restore this version").get_sensitive()));
}

private void test_hvs_view_version_compares_the_version_itself() {
    var h = new HvsHarness();
    hvs_select_older_row(h);
    var before = h.api.compares.size;

    ((Gtk.ToggleButton) h.button("View version")).set_active(true);

    assert(wait_for_condition(() => h.api.compares.size > before));
    // The version view shows that version's own text instead of a diff.
    var text_view = history_find_text_view(h.view.widget);
    assert(text_view != null);
    assert(wait_for_condition(() => text_view_contents((!) text_view) == "Wording c1-1"));
}

private void test_hvs_the_head_version_needs_no_comparison_against_itself() {
    var h = new HvsHarness();
    assert(h.wait_for_page("history"));
    assert(wait_for_condition(() => h.api.compares.size == 1));
    assert(h.selected_row_index() == 0);

    // "Since this version" on the current version has nothing to compare.
    ((Gtk.ToggleButton) h.button("Since this version")).set_active(true);

    var current = HolderLinux.HistoryPresenter.current_version_detail();
    assert(wait_for_condition(() => history_find_label(h.view.widget, current.title) != null));
    var text_view = history_find_text_view(h.view.widget);
    assert(text_view != null && text_view_contents((!) text_view) == "");
    assert(h.api.compares.size == 1);
}

private void test_hvs_a_failed_comparison_leaves_an_empty_diff() {
    var h = new HvsHarness();
    hvs_select_older_row(h);
    var text_view = history_find_text_view(h.view.widget);
    assert(text_view != null && text_view_contents((!) text_view).contains("Unchanged line"));
    h.api.fail_compare = true;
    var before = h.api.compares.size;

    ((Gtk.ToggleButton) h.button("View version")).set_active(true);

    assert(wait_for_condition(() => h.api.compares.size > before));
    assert(wait_for_condition(() => text_view_contents((!) text_view) == ""));
}

private void test_hvs_context_lines_are_shown_unmarked_in_the_diff() {
    var h = new HvsHarness();
    assert(h.wait_for_page("history"));
    assert(wait_for_condition(() => h.api.compares.size == 1));
    var text_view = history_find_text_view(h.view.widget);
    assert(text_view != null);
    assert(wait_for_condition(() => text_view_contents((!) text_view).contains("Unchanged line")));
    assert(text_view_contents((!) text_view).contains("+ Wording c1-2"));
}

private void test_hvs_older_card_history_appends_and_reports_a_failure() {
    var h = new HvsHarness();
    h.api.paginate = true;
    h.view.refresh();
    assert(wait_for_condition(() => h.api.card_calls == 2));
    assert(wait_for_condition(() => h.button("Load older history").get_visible()));
    assert(h.timeline().get_row_at_index(2) == null);

    h.button("Load older history").clicked();
    assert(wait_for_condition(() => h.timeline().get_row_at_index(2) != null));
    assert(h.errors.size == 0);
}

private void test_hvs_a_failed_older_page_is_reported() {
    var h = new HvsHarness();
    h.api.paginate = true;
    h.view.refresh();
    assert(wait_for_condition(() => h.api.card_calls == 2));
    assert(wait_for_condition(() => h.button("Load older history").get_visible()));
    h.api.fail_older = true;

    h.button("Load older history").clicked();

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Failed to load older card history|older down");
    assert(h.timeline().get_row_at_index(2) == null);
}

private Adw.AlertDialog hvs_open_restore_dialog(HvsHarness h) {
    hvs_select_older_row(h);
    h.button("Restore this version").clicked();
    assert(wait_for_condition(() => h.dialog() != null));
    var dialog = h.dialog();
    assert(dialog != null && ((!) dialog).get_heading() == "Restore this card version?");
    return (!) dialog;
}

private void test_hvs_cancelling_the_restore_dialog_restores_nothing() {
    var h = new HvsHarness(true, true, true);
    var dialog = hvs_open_restore_dialog(h);

    dialog.response("cancel");
    hvs_settle();

    assert(h.api.restores.size == 0);
}

private void test_hvs_confirming_the_restore_dialog_restores_and_refreshes() {
    var h = new HvsHarness(true, true, true);
    var dialog = hvs_open_restore_dialog(h);
    string? restored_project = null;
    string? restored_card = null;
    h.view.restore_succeeded.connect((project_id, card_id) => { restored_project = project_id; restored_card = card_id; });
    var calls = h.api.card_calls;

    dialog.response("restore");

    assert(wait_for_condition(() => h.api.restores.size == 1));
    assert(h.api.restores[0] == "c1:c1-1");
    assert(wait_for_condition(() => restored_card == "c1"));
    assert(restored_project == "p1");
    assert(wait_for_condition(() => h.api.card_calls > calls));
}

private void test_hvs_a_failed_restore_is_reported_and_can_be_retried() {
    var h = new HvsHarness(true, true, true);
    var dialog = hvs_open_restore_dialog(h);
    h.api.fail_restore = true;

    dialog.response("restore");

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Could not restore this version|restore down");
    assert(h.debug.any_match((line) => line.contains("History restore failed: restore down")));
    assert(wait_for_condition(() => h.button("Restore this version").get_sensitive()));
}

private void test_hvs_a_restore_finishing_after_the_selection_moved_is_not_announced() {
    var h = new HvsHarness(true, true, true);
    var dialog = hvs_open_restore_dialog(h);
    bool succeeded = false;
    h.view.restore_succeeded.connect((project_id, card_id) => { succeeded = true; });
    h.api.stall_restore = true;

    dialog.response("restore");
    assert(wait_for_condition(() => h.api.has_stalled_restore()));
    h.card_selection.set_selected(1);
    h.api.release_stalled_restore();
    hvs_settle();

    assert(wait_for_condition(() => h.api.card_calls >= 2));
    assert(!succeeded);
    assert(h.errors.size == 0);
}

private void test_hvs_confirming_after_the_card_changed_does_not_restore_into_the_new_card() {
    var h = new HvsHarness(true, true, true);
    var dialog = hvs_open_restore_dialog(h);
    var calls = h.api.card_calls;

    // The dialog was opened for card A's commit; the selection moves to card B before it is confirmed.
    h.card_selection.set_selected(1);
    assert(wait_for_condition(() => h.api.card_calls > calls));
    dialog.response("restore");
    hvs_settle();

    assert(h.api.restores.size == 0);
}

private void test_hvs_restore_asks_nothing_without_a_restorable_version_or_a_window() {
    // The head version cannot be restored, whatever calls the handler.
    var head = new HvsHarness(true, true, true);
    assert(head.wait_for_page("history"));
    assert(wait_for_condition(() => head.api.compares.size == 1));
    assert(!head.button("Restore this version").get_sensitive());
    head.button("Restore this version").clicked();
    hvs_settle();
    assert(head.dialog() == null);

    // A restorable version still needs a window to ask in.
    var windowless = new HvsHarness();
    hvs_select_older_row(windowless);
    windowless.button("Restore this version").clicked();
    hvs_settle();
    assert(windowless.dialog() == null);
    assert(windowless.api.restores.size == 0);
}

private void test_hvs_project_history_items_open_their_targets() {
    var h = new HvsHarness(false);
    assert(h.wait_for_page("project"));
    var cards = new Gee.ArrayList<string>();
    var resources = new Gee.ArrayList<string>();
    var threads = new Gee.ArrayList<string>();
    h.view.project_history_card_open_requested.connect((id) => { cards.add(id); });
    h.view.project_history_resource_open_requested.connect((id) => { resources.add(id); });
    h.view.project_history_ai_thread_open_requested.connect((id) => { threads.add(id); });
    hvs_expand_all(h.view.widget);

    h.button("card: cards/c9.md").clicked();
    h.button("resource: resources/r9.json").clicked();
    h.button("ai data: ai_threads/t9.json").clicked();

    assert(cards.size == 1 && cards[0] == "c9");
    assert(resources.size == 1 && resources[0] == "r9");
    assert(threads.size == 1 && threads[0] == "t9");
}

private void test_hvs_an_empty_project_history_says_so() {
    var h = new HvsHarness(false, false);
    h.api.project_empty = true;
    h.view.bind_context(h.project_selection, h.card_selection);

    assert(h.wait_for_page("project"));
    assert(history_find_label(h.view.widget, HolderLinux.ProjectHistoryPresenter.EMPTY_TEXT) != null);
}

private void test_hvs_older_project_activity_appends_and_reports_a_failure() {
    var h = new HvsHarness(false, false);
    h.api.project_paginate = true;
    h.view.bind_context(h.project_selection, h.card_selection);
    assert(h.wait_for_page("project"));
    assert(wait_for_condition(() => h.button("Load older activity").get_visible()));
    assert(history_find_label(h.view.widget, "Older project change") == null);

    h.button("Load older activity").clicked();
    assert(wait_for_condition(() => history_find_label(h.view.widget, "Older project change") != null));
    assert(h.errors.size == 0);
}

private void test_hvs_a_failed_older_project_page_is_reported() {
    var h = new HvsHarness(false, false);
    h.api.project_paginate = true;
    h.view.bind_context(h.project_selection, h.card_selection);
    assert(h.wait_for_page("project"));
    assert(wait_for_condition(() => h.button("Load older activity").get_visible()));
    h.api.fail_project_older = true;

    h.button("Load older activity").clicked();

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Failed to load older project activity|older project down");
}

public static int main(string[] args) {
    Test.init(ref args);
    Gtk.init();
    Test.add_func(
        "/holder/history-tool/timeline-and-comparison",
        test_history_loads_timeline_and_selected_comparison
    );
    Test.add_func("/holder/history-tool/no-card", test_history_without_card_does_not_call_api);
    Test.add_func("/holder/history-tool/project-history", test_project_history_renders_without_a_card);
    Test.add_func("/holder/history-tool/restore-refresh", test_history_restores_selected_version_and_refreshes);
    Test.add_func("/holder/history-tool/load-older-page", test_history_loads_older_page);
    Test.add_func(
        "/holder/history-tool/merge-aligned-page-lanes",
        test_history_merge_uses_aligned_page_lanes
    );
    Test.add_func("/holder/history-tool/current-head-change", test_current_head_compares_its_change);
    Test.add_func(
        "/holder/history-tool/creation-change", test_creation_change_compares_from_missing_card
    );
    Test.add_func(
        "/holder/history-tool/empty-comparison", test_empty_comparison_explains_unchanged_text
    );
    Test.add_func(
        "/holder/history-tool/late-list-response-keeps-newer-card",
        test_history_late_list_response_keeps_newer_card
    );
    Test.add_func(
        "/holder/history-tool/late-comparison-response-keeps-newer-card",
        test_history_late_comparison_response_keeps_newer_card
    );
    var prefix = "/holder/history-tool/";
    Test.add_func(prefix + "shell-adapter", test_hvs_shell_adapter_reports_identity_scope_and_navigation);
    Test.add_func(prefix + "rebinding", test_hvs_rebinding_stops_listening_to_the_old_selections);
    Test.add_func(prefix + "choose-row", test_hvs_choosing_another_row_compares_that_version);
    Test.add_func(prefix + "change-toggle", test_hvs_the_change_toggle_compares_the_change);
    Test.add_func(prefix + "project-api-missing", test_hvs_project_history_without_a_project_history_api_shows_the_empty_page);
    Test.add_func(prefix + "project-error", test_hvs_a_failed_project_history_load_shows_the_error_page);
    Test.add_func(prefix + "card-error", test_hvs_a_failed_card_history_load_shows_the_error_page_and_forgets_the_details);
    Test.add_func(prefix + "no-history-clears-details", test_hvs_a_card_without_history_clears_the_previous_cards_details);
    Test.add_func(prefix + "shared-commit-row", test_hvs_a_commit_shared_by_two_cards_does_not_carry_the_chosen_row_across);
    Test.add_func(prefix + "copy-clipboard", test_hvs_copy_actions_go_through_the_clipboard);
    Test.add_func(prefix + "copy-no-clipboard", test_hvs_copying_without_a_clipboard_reports_the_error);
    Test.add_func(prefix + "lane-gutter-draws", test_hvs_the_lane_gutter_draws_lines_bends_and_merge_markers);
    Test.add_func(prefix + "view-version", test_hvs_view_version_compares_the_version_itself);
    Test.add_func(prefix + "head-needs-no-comparison", test_hvs_the_head_version_needs_no_comparison_against_itself);
    Test.add_func(prefix + "comparison-failure", test_hvs_a_failed_comparison_leaves_an_empty_diff);
    Test.add_func(prefix + "context-lines", test_hvs_context_lines_are_shown_unmarked_in_the_diff);
    Test.add_func(prefix + "older-appends", test_hvs_older_card_history_appends_and_reports_a_failure);
    Test.add_func(prefix + "older-failure", test_hvs_a_failed_older_page_is_reported);
    Test.add_func(prefix + "restore-cancel", test_hvs_cancelling_the_restore_dialog_restores_nothing);
    Test.add_func(prefix + "restore-confirm", test_hvs_confirming_the_restore_dialog_restores_and_refreshes);
    Test.add_func(prefix + "restore-failure", test_hvs_a_failed_restore_is_reported_and_can_be_retried);
    Test.add_func(prefix + "restore-selection-moved", test_hvs_a_restore_finishing_after_the_selection_moved_is_not_announced);
    Test.add_func(prefix + "restore-other-card", test_hvs_confirming_after_the_card_changed_does_not_restore_into_the_new_card);
    Test.add_func(prefix + "restore-guards", test_hvs_restore_asks_nothing_without_a_restorable_version_or_a_window);
    Test.add_func(prefix + "project-items-open", test_hvs_project_history_items_open_their_targets);
    Test.add_func(prefix + "project-empty", test_hvs_an_empty_project_history_says_so);
    Test.add_func(prefix + "project-older", test_hvs_older_project_activity_appends_and_reports_a_failure);
    Test.add_func(prefix + "project-older-failure", test_hvs_a_failed_older_project_page_is_reported);
    return Test.run();
}

}
