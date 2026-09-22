using GLib;

namespace HolderLinuxTests {

private const string STAMP_FORMAT = "%e %b %Y, %H:%M";

private string stamp(int64 epoch) {
    return new DateTime.from_unix_local(epoch).format(STAMP_FORMAT);
}

private HolderLinux.CardHistoryEntry make_entry(string oid,
                                                string[] parents = {},
                                                bool is_merge = false,
                                                int commit_count = 1,
                                                HolderLinux.CardHistorySave[] saves = {}) {
    return new HolderLinux.CardHistoryEntry(
        oid, oid, parents, "Ada", "ada@example.test", 1000, 2000, "updated",
        "Edited intro", commit_count, is_merge, saves
    );
}

private HolderLinux.CardHistoryComparison make_comparison(bool exists,
                                                          string title,
                                                          bool truncated,
                                                          HolderLinux.CardHistoryDiffLine[] lines = {}) {
    var version = new HolderLinux.CardHistoryVersion(exists, "to", title, "body");
    return new HolderLinux.CardHistoryComparison(
        new HolderLinux.CardHistoryVersion(true, "from", "Old", "old body"),
        version, "summary", lines, truncated
    );
}

// ---- small formatters ----

private void test_short_oid_handles_missing_short_and_long_oids() {
    assert(HolderLinux.HistoryPresenter.short_oid(null) == "no parent");
    assert(HolderLinux.HistoryPresenter.short_oid("") == "no parent");
    assert(HolderLinux.HistoryPresenter.short_oid("abc") == "abc");
    assert(HolderLinux.HistoryPresenter.short_oid("0123456789") == "01234567");
}

private void test_format_when_uses_the_local_timestamp_format() {
    assert(HolderLinux.HistoryPresenter.format_when(1700000000) == stamp(1700000000));
}

private void test_project_kind_filter_indexes() {
    assert(HolderLinux.HistoryPresenter.project_kind_for_index(0) == null);
    assert(HolderLinux.HistoryPresenter.project_kind_for_index(1) == "card");
    assert(HolderLinux.HistoryPresenter.project_kind_for_index(2) == "resource");
    assert(HolderLinux.HistoryPresenter.project_kind_for_index(3) == "location");
    assert(HolderLinux.HistoryPresenter.project_kind_for_index(4) == "ai_data");
    assert(HolderLinux.HistoryPresenter.project_kind_for_index(5) == "project_settings");
    assert(HolderLinux.HistoryPresenter.project_kind_for_index(6) == "unknown");
    assert(HolderLinux.HistoryPresenter.project_kind_for_index(7) == null);
}

private void test_row_text() {
    var plain = make_entry("a");
    var merged = make_entry("b", {}, true, 3);
    assert(HolderLinux.HistoryPresenter.entry_title(plain) == "Edited intro");
    assert(HolderLinux.HistoryPresenter.entry_title(merged) == "Merged: Edited intro");
    assert(HolderLinux.HistoryPresenter.entry_meta(plain) == "%s · Ada".printf(stamp(2000)));
    assert(HolderLinux.HistoryPresenter.entry_meta(merged) == "%s · Ada · 3 saves".printf(stamp(2000)));
    assert(HolderLinux.HistoryPresenter.saves_expander_label(4) == "Show 4 exact saves");
    assert(HolderLinux.HistoryPresenter.save_button_label(new HolderLinux.CardHistorySave("s", {}, 3000))
           == "Saved %s".printf(stamp(3000)));
    assert(HolderLinux.HistoryPresenter.load_older_label(false) == "Load older history");
    assert(HolderLinux.HistoryPresenter.load_older_label(true) == "Continue scanning older history");
}

// ---- comparison decisions ----

private void test_comparison_mode_mapping() {
    assert(HolderLinux.HistoryPresenter.mode_for_toggles(true, false) == HolderLinux.HistoryComparisonMode.VERSION);
    assert(HolderLinux.HistoryPresenter.mode_for_toggles(true, true) == HolderLinux.HistoryComparisonMode.VERSION);
    assert(HolderLinux.HistoryPresenter.mode_for_toggles(false, true) == HolderLinux.HistoryComparisonMode.CHANGE);
    assert(HolderLinux.HistoryPresenter.mode_for_toggles(false, false) == HolderLinux.HistoryComparisonMode.SINCE);

    assert(HolderLinux.HistoryPresenter.mode_name(HolderLinux.HistoryComparisonMode.SINCE) == "since");
    assert(HolderLinux.HistoryPresenter.mode_name(HolderLinux.HistoryComparisonMode.CHANGE) == "change");
    assert(HolderLinux.HistoryPresenter.mode_name(HolderLinux.HistoryComparisonMode.VERSION) == "version");
    // The version view is fetched as a "since" comparison of one OID against itself.
    assert(HolderLinux.HistoryPresenter.api_mode(HolderLinux.HistoryComparisonMode.VERSION) == "since");
    assert(HolderLinux.HistoryPresenter.api_mode(HolderLinux.HistoryComparisonMode.CHANGE) == "change");
    assert(HolderLinux.HistoryPresenter.api_mode(HolderLinux.HistoryComparisonMode.SINCE) == "since");
}

private void test_default_mode_and_restore_rules() {
    var entry = make_entry("saved");
    assert(HolderLinux.HistoryPresenter.default_mode(entry, "saved") == HolderLinux.HistoryComparisonMode.CHANGE);
    assert(HolderLinux.HistoryPresenter.default_mode(entry, "head") == HolderLinux.HistoryComparisonMode.SINCE);
    assert(HolderLinux.HistoryPresenter.default_mode(entry, null) == HolderLinux.HistoryComparisonMode.SINCE);

    assert(HolderLinux.HistoryPresenter.can_restore(entry, "head"));
    assert(!HolderLinux.HistoryPresenter.can_restore(entry, "saved"));
    assert(!HolderLinux.HistoryPresenter.can_restore(entry, null));
    assert(!HolderLinux.HistoryPresenter.can_restore(null, "head"));
}

private void test_comparison_endpoints_per_mode() {
    var with_parent = make_entry("saved", { "parent-1", "parent-2" });
    var root = make_entry("root");

    var change = HolderLinux.HistoryPresenter.endpoints(HolderLinux.HistoryComparisonMode.CHANGE, with_parent, "head");
    assert(change.from_oid == "parent-1" && change.to_oid == "saved");
    var root_change = HolderLinux.HistoryPresenter.endpoints(HolderLinux.HistoryComparisonMode.CHANGE, root, "head");
    assert(root_change.from_oid == null && root_change.to_oid == "root");

    var version = HolderLinux.HistoryPresenter.endpoints(HolderLinux.HistoryComparisonMode.VERSION, with_parent, "head");
    assert(version.from_oid == "saved" && version.to_oid == "saved");

    var since = HolderLinux.HistoryPresenter.endpoints(HolderLinux.HistoryComparisonMode.SINCE, with_parent, "head");
    assert(since.from_oid == "saved" && since.to_oid == "head");

    assert(HolderLinux.HistoryPresenter.is_current_version(HolderLinux.HistoryComparisonMode.SINCE, with_parent, "saved"));
    assert(!HolderLinux.HistoryPresenter.is_current_version(HolderLinux.HistoryComparisonMode.SINCE, with_parent, "head"));
    assert(!HolderLinux.HistoryPresenter.is_current_version(HolderLinux.HistoryComparisonMode.CHANGE, with_parent, "saved"));
}

private void test_detail_oid_prefers_the_shown_entry() {
    var shown = make_entry("shown");
    var selected = make_entry("selected");
    assert(HolderLinux.HistoryPresenter.detail_oid(shown, selected) == "shown");
    assert(HolderLinux.HistoryPresenter.detail_oid(null, selected) == "selected");
    assert(HolderLinux.HistoryPresenter.detail_oid(null, null) == null);
}

// ---- detail panel text ----

private void test_fixed_detail_texts() {
    var none = HolderLinux.HistoryPresenter.no_history_detail();
    assert(none.title == "No saved history yet");
    assert(none.meta == "The card has no matching commits in this project repository.");
    var current = HolderLinux.HistoryPresenter.current_version_detail();
    assert(current.title == "Current saved version");
    assert(current.meta == "This is the current saved version. Choose This change to see how it was made.");
    var loading = HolderLinux.HistoryPresenter.loading_detail(make_entry("a"));
    assert(loading.title == "Loading saved version…" && loading.meta == "Edited intro");
    var restored = HolderLinux.HistoryPresenter.restored_detail();
    assert(restored.title == "Version restored");
    assert(restored.meta == "Refreshing saved history and comparison…");
    var failed = HolderLinux.HistoryPresenter.failed_detail("boom");
    assert(failed.title == "Could not compare this version" && failed.meta == "boom");
}

private void test_loaded_detail_per_mode() {
    var entry = make_entry("a");

    var version = HolderLinux.HistoryPresenter.loaded_detail(
        HolderLinux.HistoryComparisonMode.VERSION, entry, make_comparison(true, "Old title", true)
    );
    assert(version.title == "Old title");
    // The version view never gets the "Diff shortened" suffix.
    assert(version.meta == "%s by Ada · Saved version".printf(stamp(2000)));

    var missing = HolderLinux.HistoryPresenter.loaded_detail(
        HolderLinux.HistoryComparisonMode.VERSION, entry, make_comparison(false, "", false)
    );
    assert(missing.title == "No saved card");

    var change = HolderLinux.HistoryPresenter.loaded_detail(
        HolderLinux.HistoryComparisonMode.CHANGE, entry, make_comparison(true, "t", false)
    );
    assert(change.title == "Edited intro");
    assert(change.meta == "%s by Ada · This change".printf(stamp(2000)));

    var since = HolderLinux.HistoryPresenter.loaded_detail(
        HolderLinux.HistoryComparisonMode.SINCE, entry, make_comparison(true, "t", true)
    );
    assert(since.meta == "%s by Ada  →  Current saved version · Diff shortened".printf(stamp(2000)));
}

private void test_diff_and_version_text() {
    var added = new HolderLinux.CardHistoryDiffLine("+", "new", null, 1);
    var removed = new HolderLinux.CardHistoryDiffLine("-", "old", 1, null);
    var context = new HolderLinux.CardHistoryDiffLine(" ", "same", 1, 1);
    assert(HolderLinux.HistoryPresenter.diff_line_kind(added) == HolderLinux.HistoryDiffLineKind.ADDED);
    assert(HolderLinux.HistoryPresenter.diff_line_kind(removed) == HolderLinux.HistoryDiffLineKind.REMOVED);
    assert(HolderLinux.HistoryPresenter.diff_line_kind(context) == HolderLinux.HistoryDiffLineKind.CONTEXT);
    assert(HolderLinux.HistoryPresenter.diff_line_text(added) == "+ new\n");
    assert(HolderLinux.HistoryPresenter.DIFF_EMPTY_TEXT
           == "No text changes were recorded between these saved versions.");

    assert(HolderLinux.HistoryPresenter.version_text(new HolderLinux.CardHistoryVersion(false, "o", "", ""))
           == "This event does not contain a saved card version to view.");
    assert(HolderLinux.HistoryPresenter.version_text(new HolderLinux.CardHistoryVersion(true, "o", "T", ""))
           == "This saved version has no card text.");
    assert(HolderLinux.HistoryPresenter.version_text(new HolderLinux.CardHistoryVersion(true, "o", "T", "Body"))
           == "Body");
}

private void test_git_details_without_saves_are_blank() {
    var details = HolderLinux.HistoryPresenter.git_details(make_entry("a"));
    assert(!details.has_save);
    assert(details.oid_text == "" && details.parents_text == "" && details.author_text == "");
    assert(details.authored_text == "" && details.committed_text == "" && details.message_text == "");
}

private void test_git_details_describe_the_latest_save() {
    string[] parents = { "p1", "p2" };
    var first = new HolderLinux.CardHistorySave("first", {}, 1000);
    var latest = new HolderLinux.CardHistorySave("latest", parents, 3000, 2500, "Fix typo");
    var details = HolderLinux.HistoryPresenter.git_details(make_entry("latest", {}, false, 2, { first, latest }));
    assert(details.has_save);
    assert(details.oid_text == "Commit: latest");
    assert(details.parents_text == "Parents: p1, p2");
    assert(details.author_text == "Author: Ada <ada@example.test>");
    assert(details.authored_text == "Authored: " + new DateTime.from_unix_local(2500).format("%e %b %Y, %H:%M:%S %z"));
    assert(details.committed_text == "Committed: " + new DateTime.from_unix_local(3000).format("%e %b %Y, %H:%M:%S %z"));
    assert(details.message_text == "Message: Fix typo");

    var created = HolderLinux.HistoryPresenter.git_details(
        make_entry("root", {}, false, 1, { new HolderLinux.CardHistorySave("root", {}, 1000) })
    );
    assert(created.parents_text == "Parents: None (card created)");
    assert(created.message_text == "Message: (none)");
}

private void test_commit_id_and_copied_card_title() {
    var project = new HolderLinux.Project("p1", "Notebook", "encrypted_git", "/tmp/p1", 1, 1);
    var card = new HolderLinux.CardSummary("c1", "p1", "Idea", "c1.md", 1.0, null, 1, 1);

    assert(HolderLinux.HistoryPresenter.commit_id_to_copy(null) == null);
    assert(HolderLinux.HistoryPresenter.commit_id_to_copy(make_entry("a")) == null);
    var saves = new HolderLinux.CardHistorySave[] {
        new HolderLinux.CardHistorySave("older", {}, 10),
        new HolderLinux.CardHistorySave("0123456789abcdef", {}, 3000)
    };
    var with_saves = make_entry("0123456789abcdef", {}, false, 2, saves);
    assert(HolderLinux.HistoryPresenter.commit_id_to_copy(with_saves) == "0123456789abcdef");

    assert(HolderLinux.HistoryPresenter.copied_card_title(project, card, with_saves)
           == "Copy of Idea from Notebook · 01234567 · %s".printf(stamp(3000)));
    var short_save = make_entry("abc", {}, false, 1, { new HolderLinux.CardHistorySave("abc", {}, 4000) });
    assert(HolderLinux.HistoryPresenter.copied_card_title(project, card, short_save)
           == "Copy of Idea from Notebook · abc · %s".printf(stamp(4000)));
    assert(HolderLinux.HistoryPresenter.copied_card_title(project, card, make_entry("x"))
           == "Copy of Idea from Notebook · unsaved · %s".printf(stamp(2000)));
}

// ---- entries and saves ----

private void test_entry_for_save_builds_a_single_save_entry() {
    var save = new HolderLinux.CardHistorySave("save-oid", { "prev" }, 5000);
    var group = make_entry("group", {}, true, 2, { save });
    var entry = HolderLinux.HistoryPresenter.entry_for_save(group, save);
    assert(entry.first_oid == "save-oid" && entry.last_oid == "save-oid");
    assert(entry.parent_oids.length == 1 && entry.parent_oids[0] == "prev");
    assert(entry.author_name == "Ada" && entry.author_email == "ada@example.test");
    assert(entry.started_at == 5000 && entry.ended_at == 5000);
    assert(entry.summary == "Saved version" && entry.commit_count == 1 && !entry.is_merge);
    assert(entry.saves.length == 1);
}

private void test_find_entry_matches_heads_then_saves() {
    var inner = new HolderLinux.CardHistorySave("inner-save", {}, 10);
    HolderLinux.CardHistoryEntry[] entries = {
        make_entry("first-head"),
        make_entry("second-head", {}, false, 2, { inner })
    };
    assert(HolderLinux.HistoryPresenter.find_entry(entries, null) == null);
    assert(HolderLinux.HistoryPresenter.find_entry(entries, "unknown") == null);

    var head_match = HolderLinux.HistoryPresenter.find_entry(entries, "second-head");
    assert(head_match != null && head_match.index == 1 && head_match.entry == entries[1]);

    var save_match = HolderLinux.HistoryPresenter.find_entry(entries, "inner-save");
    assert(save_match != null && save_match.index == 1);
    assert(save_match.entry.last_oid == "inner-save" && save_match.entry.summary == "Saved version");
}

// ---- debug lines ----

private void test_debug_lines() {
    var entry = make_entry("a");
    var no_more = new HolderLinux.CardHistoryPage("headhead1234", { entry }, null);
    var more = new HolderLinux.CardHistoryPage("headhead1234", { entry, entry }, "cursor");
    var scanning = new HolderLinux.CardHistoryPage("headhead1234", {}, "cursor", true);
    assert(HolderLinux.HistoryPresenter.card_loaded_debug(no_more) == "History loaded: 1 entries at headhead");
    assert(HolderLinux.HistoryPresenter.card_loaded_debug(more)
           == "History loaded: 2 entries at headhead; older history available");
    assert(HolderLinux.HistoryPresenter.card_loaded_debug(scanning)
           == "History loaded: 0 entries at headhead; continue scanning older history");

    assert(HolderLinux.HistoryPresenter.older_loaded_debug(no_more) == "History loaded 1 older entries");
    assert(HolderLinux.HistoryPresenter.older_loaded_debug(more) == "History loaded 2 older entries; more available");
    assert(HolderLinux.HistoryPresenter.older_loaded_debug(scanning)
           == "History loaded 0 older entries; continue scanning");

    var project_page = new HolderLinux.ProjectHistoryPage("abcdefghij", {}, null);
    assert(HolderLinux.HistoryPresenter.project_loaded_debug(project_page)
           == "Project history loaded: 0 activities at abcdefgh");

    var lines = new HolderLinux.CardHistoryDiffLine[] {
        new HolderLinux.CardHistoryDiffLine("+", "x", null, 1)
    };
    assert(HolderLinux.HistoryPresenter.compared_debug(
        "fromfromfrom", "to", HolderLinux.HistoryComparisonMode.SINCE, make_comparison(true, "t", false, lines)
    ) == "History compared fromfrom to to (since; 1 lines)");
    assert(HolderLinux.HistoryPresenter.compared_debug(
        null, "to", HolderLinux.HistoryComparisonMode.CHANGE, make_comparison(true, "t", true)
    ) == "History compared no parent to to (change; 0 lines; shortened)");

    assert(HolderLinux.HistoryPresenter.copy_as_card_debug("0123456789", 12)
           == "History copy as card requested from 01234567 (12 characters)");
    assert(HolderLinux.HistoryPresenter.copied_debug(7) == "History copied 7 characters to clipboard");
}

// ---- project activity ----

private HolderLinux.ProjectHistoryActivity make_activity(bool is_merge,
                                                         string[] parents,
                                                         HolderLinux.ProjectHistoryAffectedObject[] objects) {
    return new HolderLinux.ProjectHistoryActivity(
        "oid", parents, "Grace", "grace@example.test", 6000, "Reorganised", objects, is_merge
    );
}

private void test_project_activity_without_affected_paths() {
    var presentation = HolderLinux.ProjectHistoryPresenter.present(make_activity(false, {}, {}));
    assert(presentation.title == "Reorganised");
    assert(presentation.meta == "%s · Grace".printf(stamp(6000)));
    assert(presentation.unknown_text == null);
    assert(presentation.affected_label == null);
    assert(presentation.items.length == 0);
    assert(HolderLinux.ProjectHistoryPresenter.EMPTY_TEXT == "No project activity yet");
}

private void test_project_merge_activity_text() {
    var one_parent = HolderLinux.ProjectHistoryPresenter.present(make_activity(true, { "p" }, {}));
    assert(one_parent.title == "Merged: Reorganised");
    assert(one_parent.meta == "%s · Grace · Merged from 1 parent".printf(stamp(6000)));
    var two_parents = HolderLinux.ProjectHistoryPresenter.present(make_activity(true, { "p", "q" }, {}));
    assert(two_parents.meta == "%s · Grace · Merged from 2 parents".printf(stamp(6000)));
}

private void test_project_activity_summarises_kinds_and_unknown_paths() {
    var objects = new HolderLinux.ProjectHistoryAffectedObject[] {
        new HolderLinux.ProjectHistoryAffectedObject("card", {
            new HolderLinux.ProjectHistoryAffectedPath("cards/c1.md", "Intro", "renamed"),
            new HolderLinux.ProjectHistoryAffectedPath("cards/c2.md")
        }),
        new HolderLinux.ProjectHistoryAffectedObject("ai_data", {
            new HolderLinux.ProjectHistoryAffectedPath("ai_threads/t1.json")
        }),
        new HolderLinux.ProjectHistoryAffectedObject("unknown", {
            new HolderLinux.ProjectHistoryAffectedPath("README"),
            new HolderLinux.ProjectHistoryAffectedPath("notes.txt")
        })
    };
    var presentation = HolderLinux.ProjectHistoryPresenter.present(make_activity(false, {}, objects));
    assert(presentation.meta == "%s · Grace · card (2) · ai data (1)".printf(stamp(6000)));
    assert(presentation.unknown_text == "Other Git changes (2)");
    assert(presentation.affected_label == "Show 5 affected items");
    assert(presentation.items.length == 5);

    var single = HolderLinux.ProjectHistoryPresenter.present(make_activity(false, {}, {
        new HolderLinux.ProjectHistoryAffectedObject("location", {
            new HolderLinux.ProjectHistoryAffectedPath("locations/l1.json")
        })
    }));
    assert(single.affected_label == "Show 1 affected item");
}

private void test_project_path_items_link_to_their_objects() {
    var card = HolderLinux.ProjectHistoryPresenter.present_path(
        "card", new HolderLinux.ProjectHistoryAffectedPath("cards/c1.md", "Intro", "renamed")
    );
    assert(card.item_kind == HolderLinux.ProjectHistoryItemKind.CARD && card.target_id == "c1");
    assert(card.text == "card: Intro — cards/c1.md · renamed");
    assert(!card.dimmed);

    var untitled = HolderLinux.ProjectHistoryPresenter.present_path(
        "card", new HolderLinux.ProjectHistoryAffectedPath("cards/c2.md", "", "")
    );
    assert(untitled.text == "card: cards/c2.md");

    var resource = HolderLinux.ProjectHistoryPresenter.present_path(
        "resource", new HolderLinux.ProjectHistoryAffectedPath("resources/r1.json", "Spec")
    );
    assert(resource.item_kind == HolderLinux.ProjectHistoryItemKind.RESOURCE && resource.target_id == "r1");
    assert(resource.text == "resource: Spec — resources/r1.json");

    var thread = HolderLinux.ProjectHistoryPresenter.present_path(
        "ai_data", new HolderLinux.ProjectHistoryAffectedPath("ai_threads/t1.json")
    );
    assert(thread.item_kind == HolderLinux.ProjectHistoryItemKind.AI_THREAD && thread.target_id == "t1");
    assert(thread.text == "ai data: ai_threads/t1.json");
}

private void test_project_path_items_without_a_target_are_plain_text() {
    var settings = HolderLinux.ProjectHistoryPresenter.present_path(
        "project_settings", new HolderLinux.ProjectHistoryAffectedPath("project.json", "Settings", "theme")
    );
    assert(settings.item_kind == HolderLinux.ProjectHistoryItemKind.TEXT && settings.target_id == null);
    assert(settings.text == "project settings: Settings — project.json · theme");
    assert(!settings.dimmed);

    // Title and detail are only shown for object kinds that describe an object.
    var location = HolderLinux.ProjectHistoryPresenter.present_path(
        "location", new HolderLinux.ProjectHistoryAffectedPath("locations/l1.json", "Drive", "bound")
    );
    assert(location.text == "location: locations/l1.json");

    var unknown = HolderLinux.ProjectHistoryPresenter.present_path(
        "unknown", new HolderLinux.ProjectHistoryAffectedPath("README")
    );
    assert(unknown.item_kind == HolderLinux.ProjectHistoryItemKind.TEXT);
    assert(unknown.text == "Other Git change: README");
    assert(unknown.dimmed);
}

private void test_path_id_requires_the_owning_kind_folder_and_suffix() {
    assert(HolderLinux.ProjectHistoryPresenter.path_id("card", "cards/c1.md", "cards/", ".md") == "c1");
    assert(HolderLinux.ProjectHistoryPresenter.path_id("resource", "resources/r1.json", "resources/", ".json") == "r1");
    assert(HolderLinux.ProjectHistoryPresenter.path_id("ai_data", "ai_threads/t1.json", "ai_threads/", ".json") == "t1");
    // The kind must own the folder.
    assert(HolderLinux.ProjectHistoryPresenter.path_id("resource", "cards/c1.md", "cards/", ".md") == null);
    assert(HolderLinux.ProjectHistoryPresenter.path_id("card", "resources/r1.json", "resources/", ".json") == null);
    assert(HolderLinux.ProjectHistoryPresenter.path_id("card", "ai_threads/t1.json", "ai_threads/", ".json") == null);
    // Prefix and suffix must both match.
    assert(HolderLinux.ProjectHistoryPresenter.path_id("card", "notes/c1.md", "cards/", ".md") == null);
    assert(HolderLinux.ProjectHistoryPresenter.path_id("card", "cards/c1.txt", "cards/", ".md") == null);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/history-presenter/short-oid", test_short_oid_handles_missing_short_and_long_oids);
    Test.add_func("/holder/history-presenter/format-when", test_format_when_uses_the_local_timestamp_format);
    Test.add_func("/holder/history-presenter/project-kind-index", test_project_kind_filter_indexes);
    Test.add_func("/holder/history-presenter/row-text", test_row_text);
    Test.add_func("/holder/history-presenter/mode-mapping", test_comparison_mode_mapping);
    Test.add_func("/holder/history-presenter/default-mode-and-restore", test_default_mode_and_restore_rules);
    Test.add_func("/holder/history-presenter/endpoints", test_comparison_endpoints_per_mode);
    Test.add_func("/holder/history-presenter/detail-oid", test_detail_oid_prefers_the_shown_entry);
    Test.add_func("/holder/history-presenter/fixed-detail-texts", test_fixed_detail_texts);
    Test.add_func("/holder/history-presenter/loaded-detail", test_loaded_detail_per_mode);
    Test.add_func("/holder/history-presenter/diff-and-version-text", test_diff_and_version_text);
    Test.add_func("/holder/history-presenter/git-details-blank", test_git_details_without_saves_are_blank);
    Test.add_func("/holder/history-presenter/git-details-latest-save", test_git_details_describe_the_latest_save);
    Test.add_func("/holder/history-presenter/commit-id-and-title", test_commit_id_and_copied_card_title);
    Test.add_func("/holder/history-presenter/entry-for-save", test_entry_for_save_builds_a_single_save_entry);
    Test.add_func("/holder/history-presenter/find-entry", test_find_entry_matches_heads_then_saves);
    Test.add_func("/holder/history-presenter/debug-lines", test_debug_lines);
    Test.add_func("/holder/project-history/plain-activity", test_project_activity_without_affected_paths);
    Test.add_func("/holder/project-history/merge-activity", test_project_merge_activity_text);
    Test.add_func("/holder/project-history/kinds-and-unknown", test_project_activity_summarises_kinds_and_unknown_paths);
    Test.add_func("/holder/project-history/linked-items", test_project_path_items_link_to_their_objects);
    Test.add_func("/holder/project-history/plain-text-items", test_project_path_items_without_a_target_are_plain_text);
    Test.add_func("/holder/project-history/path-id", test_path_id_requires_the_owning_kind_folder_and_suffix);
    return Test.run();
}

}
