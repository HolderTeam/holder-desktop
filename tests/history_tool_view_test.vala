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
    assert(history_find_label(
        view.widget,
        "card: Project card — cards/ab/cd/card.md · Milestone: Review — Project review"
    ) != null);
    assert(history_find_label(
        view.widget,
        "resource: Project notes — resources/ab/cd/resource.json · Attachment: project-notes.pdf"
    ) != null);
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

public static int main(string[] args) {
    Test.init(ref args);
    Gtk.init();
    Test.add_func(
        "/holder/history-tool/timeline-and-comparison",
        test_history_loads_timeline_and_selected_comparison
    );
    Test.add_func("/holder/history-tool/no-card", test_history_without_card_does_not_call_api);
    Test.add_func("/holder/history-tool/project-history", test_project_history_renders_without_a_card);
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
    return Test.run();
}

}
