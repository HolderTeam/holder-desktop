namespace HolderLinux {

public enum HistoryComparisonMode {
    SINCE,
    CHANGE,
    VERSION
}

public enum HistoryDiffLineKind {
    ADDED,
    REMOVED,
    CONTEXT
}

public class HistoryComparisonEndpoints : Object {
    public string? from_oid { get; construct; }
    public string to_oid { get; construct; }

    public HistoryComparisonEndpoints(string? from_oid, string to_oid) {
        Object(from_oid: from_oid, to_oid: to_oid);
    }
}

public class HistoryDetailText : Object {
    public string title { get; construct; }
    public string meta { get; construct; }

    public HistoryDetailText(string title, string meta) {
        Object(title: title, meta: meta);
    }
}

public class HistoryGitDetails : Object {
    public bool has_save { get; construct; }
    public string oid_text { get; construct; }
    public string parents_text { get; construct; }
    public string author_text { get; construct; }
    public string authored_text { get; construct; }
    public string committed_text { get; construct; }
    public string message_text { get; construct; }

    public HistoryGitDetails(bool has_save,
                             string oid_text,
                             string parents_text,
                             string author_text,
                             string authored_text,
                             string committed_text,
                             string message_text) {
        Object(
            has_save: has_save,
            oid_text: oid_text,
            parents_text: parents_text,
            author_text: author_text,
            authored_text: authored_text,
            committed_text: committed_text,
            message_text: message_text
        );
    }
}

public class HistoryEntryMatch : Object {
    public int index { get; construct; }
    public CardHistoryEntry entry { get; construct; }

    public HistoryEntryMatch(int index, CardHistoryEntry entry) {
        Object(index: index, entry: entry);
    }
}

public class HistoryPresenter { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public const string TIMESTAMP_FORMAT = "%e %b %Y, %H:%M";
    public const string DIFF_EMPTY_TEXT = "No text changes were recorded between these saved versions.";
    public const string LOADING_OLDER_LABEL = "Loading older history…";

    public static string short_oid(string? oid) {
        if (oid == null || ((!) oid).length == 0) return "no parent";
        return ((!) oid).length > 8 ? ((!) oid).substring(0, 8) : (!) oid;
    }

    public static string format_when(int64 epoch) {
        return new DateTime.from_unix_local(epoch).format(TIMESTAMP_FORMAT);
    }

    public static string? project_kind_for_index(uint index) {
        switch (index) {
            case 1: return "card";
            case 2: return "resource";
            case 3: return "location";
            case 4: return "ai_data";
            case 5: return "project_settings";
            case 6: return "unknown";
            default: return null;
        }
    }

    // ---- timeline rows ----

    public static string entry_title(CardHistoryEntry entry) {
        return entry.is_merge ? "Merged: " + entry.summary : entry.summary;
    }

    public static string entry_meta(CardHistoryEntry entry) {
        var details = "%s · %s".printf(format_when(entry.ended_at), entry.author_name);
        if (entry.commit_count > 1) {
            details += " · %d saves".printf(entry.commit_count);
        }
        return details;
    }

    public static string saves_expander_label(int save_count) {
        return "Show %d exact saves".printf(save_count);
    }

    public static string save_button_label(CardHistorySave save) {
        return "Saved %s".printf(format_when(save.committed_at));
    }

    public static string load_older_label(bool scan_limited) {
        return scan_limited ? "Continue scanning older history" : "Load older history";
    }

    // ---- comparison decisions ----

    public static HistoryComparisonMode mode_for_toggles(bool version_active, bool change_active) {
        if (version_active) return HistoryComparisonMode.VERSION;
        return change_active ? HistoryComparisonMode.CHANGE : HistoryComparisonMode.SINCE;
    }

    public static string mode_name(HistoryComparisonMode mode) {
        switch (mode) {
            case HistoryComparisonMode.VERSION: return "version";
            case HistoryComparisonMode.CHANGE: return "change";
            default: return "since";
        }
    }

    // The version view asks the API for a "since" comparison of one OID against itself.
    public static string api_mode(HistoryComparisonMode mode) {
        return mode == HistoryComparisonMode.VERSION ? "since" : mode_name(mode);
    }

    public static HistoryComparisonMode default_mode(CardHistoryEntry entry, string? head_oid) {
        return entry.last_oid == head_oid ? HistoryComparisonMode.CHANGE : HistoryComparisonMode.SINCE;
    }

    public static bool can_restore(CardHistoryEntry? entry, string? head_oid) {
        return entry != null && head_oid != null && ((!) entry).last_oid != (!) head_oid;
    }

    public static HistoryComparisonEndpoints endpoints(HistoryComparisonMode mode,
                                                       CardHistoryEntry entry,
                                                       string head_oid) {
        switch (mode) {
            case HistoryComparisonMode.CHANGE:
                return new HistoryComparisonEndpoints(
                    entry.parent_oids.length > 0 ? entry.parent_oids[0] : null,
                    entry.last_oid
                );
            case HistoryComparisonMode.VERSION:
                return new HistoryComparisonEndpoints(entry.last_oid, entry.last_oid);
            default:
                return new HistoryComparisonEndpoints(entry.last_oid, head_oid);
        }
    }

    public static bool is_current_version(HistoryComparisonMode mode,
                                          CardHistoryEntry entry,
                                          string head_oid) {
        return mode == HistoryComparisonMode.SINCE && entry.last_oid == head_oid;
    }

    public static string? detail_oid(CardHistoryEntry? detail, CardHistoryEntry? selected_row_entry) {
        if (detail != null) return ((!) detail).last_oid;
        return selected_row_entry != null ? ((!) selected_row_entry).last_oid : null;
    }

    // ---- detail panel text ----

    public static HistoryDetailText no_history_detail() {
        return new HistoryDetailText(
            "No saved history yet",
            "The card has no matching commits in this project repository."
        );
    }

    public static HistoryDetailText current_version_detail() {
        return new HistoryDetailText(
            "Current saved version",
            "This is the current saved version. Choose This change to see how it was made."
        );
    }

    public static HistoryDetailText loading_detail(CardHistoryEntry entry) {
        return new HistoryDetailText("Loading saved version…", entry.summary);
    }

    public static HistoryDetailText restored_detail() {
        return new HistoryDetailText("Version restored", "Refreshing saved history and comparison…");
    }

    public static HistoryDetailText failed_detail(string message) {
        return new HistoryDetailText("Could not compare this version", message);
    }

    public static HistoryDetailText loaded_detail(HistoryComparisonMode mode,
                                                  CardHistoryEntry entry,
                                                  CardHistoryComparison comparison) {
        var when = format_when(entry.ended_at);
        string title;
        string meta;
        if (mode == HistoryComparisonMode.VERSION) {
            title = comparison.to_version.exists ? comparison.to_version.title : "No saved card";
            meta = "%s by %s · Saved version".printf(when, entry.author_name);
        } else {
            title = entry.summary;
            meta = mode == HistoryComparisonMode.CHANGE
                ? "%s by %s · This change".printf(when, entry.author_name)
                : "%s by %s  →  Current saved version".printf(when, entry.author_name);
            if (comparison.truncated) meta += " · Diff shortened";
        }
        return new HistoryDetailText(title, meta);
    }

    public static HistoryDiffLineKind diff_line_kind(CardHistoryDiffLine line) {
        if (line.origin == "+") return HistoryDiffLineKind.ADDED;
        if (line.origin == "-") return HistoryDiffLineKind.REMOVED;
        return HistoryDiffLineKind.CONTEXT;
    }

    public static string diff_line_text(CardHistoryDiffLine line) {
        return "%s %s\n".printf(line.origin, line.text);
    }

    public static string version_text(CardHistoryVersion version) {
        if (!version.exists) return "This event does not contain a saved card version to view.";
        if (version.body.length == 0) return "This saved version has no card text.";
        return version.body;
    }

    public static HistoryGitDetails git_details(CardHistoryEntry entry) {
        if (entry.saves.length == 0) {
            return new HistoryGitDetails(false, "", "", "", "", "", "");
        }
        var save = entry.saves[entry.saves.length - 1];
        var authored = new DateTime.from_unix_local(save.authored_at);
        var committed = new DateTime.from_unix_local(save.committed_at);
        return new HistoryGitDetails(
            true,
            "Commit: " + save.oid,
            "Parents: " + (save.parent_oids.length > 0
                ? string.joinv(", ", save.parent_oids)
                : "None (card created)"),
            "Author: %s <%s>".printf(entry.author_name, entry.author_email),
            "Authored: " + authored.format("%e %b %Y, %H:%M:%S %z"),
            "Committed: " + committed.format("%e %b %Y, %H:%M:%S %z"),
            "Message: " + (save.message.length > 0 ? save.message : "(none)")
        );
    }

    public static string? commit_id_to_copy(CardHistoryEntry? entry) {
        if (entry == null || ((!) entry).saves.length == 0) return null;
        var saves = ((!) entry).saves;
        return saves[saves.length - 1].oid;
    }

    public static string copied_card_title(Project project, CardSummary card, CardHistoryEntry entry) {
        var saved_at = entry.ended_at;
        var version = "unsaved";
        if (entry.saves.length > 0) {
            var save = entry.saves[entry.saves.length - 1];
            saved_at = save.committed_at;
            version = save.oid.length > 8 ? save.oid.substring(0, 8) : save.oid;
        }
        return "Copy of %s from %s · %s · %s".printf(
            card.title, project.name, version, format_when(saved_at)
        );
    }

    // ---- entries and saves ----

    public static CardHistoryEntry entry_for_save(CardHistoryEntry group, CardHistorySave save) {
        return new CardHistoryEntry(
            save.oid, save.oid, save.parent_oids,
            group.author_name, group.author_email,
            save.committed_at, save.committed_at,
            "updated", "Saved version", 1, false,
            { save }
        );
    }

    // Finds the timeline entry whose head, or one of whose exact saves, has this OID.
    // A save match yields a single-save entry, as if that save had been selected.
    public static HistoryEntryMatch? find_entry(CardHistoryEntry[] entries, string? oid) {
        if (oid == null) return null;
        for (int index = 0; index < entries.length; index++) {
            var entry = entries[index];
            if (entry.last_oid == oid) return new HistoryEntryMatch(index, entry);
            foreach (var save in entry.saves) {
                if (save.oid == oid) {
                    return new HistoryEntryMatch(index, entry_for_save(entry, save));
                }
            }
        }
        return null;
    }

    // ---- debug log lines ----

    public static string card_loaded_debug(CardHistoryPage page) {
        return "History loaded: %d entries at %s%s".printf(
            page.entries.length,
            short_oid(page.head_oid),
            page.next_cursor != null
                ? page.scan_limited ? "; continue scanning older history"
                                    : "; older history available"
                : ""
        );
    }

    public static string older_loaded_debug(CardHistoryPage page) {
        return "History loaded %d older entries%s".printf(
            page.entries.length,
            page.next_cursor != null
                ? page.scan_limited ? "; continue scanning" : "; more available"
                : ""
        );
    }

    public static string project_loaded_debug(ProjectHistoryPage page) {
        return "Project history loaded: %d activities at %s".printf(
            page.activities.length, short_oid(page.head_oid)
        );
    }

    public static string compared_debug(string? from_oid,
                                        string to_oid,
                                        HistoryComparisonMode mode,
                                        CardHistoryComparison comparison) {
        return "History compared %s to %s (%s; %d lines%s)".printf(
            short_oid(from_oid),
            short_oid(to_oid),
            mode_name(mode),
            comparison.lines.length,
            comparison.truncated ? "; shortened" : ""
        );
    }

    public static string copy_as_card_debug(string oid, int character_count) {
        return "History copy as card requested from %s (%d characters)".printf(
            short_oid(oid), character_count
        );
    }

    public static string copied_debug(int character_count) {
        return "History copied %d characters to clipboard".printf(character_count);
    }
}

}
