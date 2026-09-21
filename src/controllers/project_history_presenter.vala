namespace HolderLinux {

public enum ProjectHistoryItemKind {
    CARD,
    RESOURCE,
    AI_THREAD,
    TEXT
}

// One affected path. Card, resource and AI-thread paths carry the id to open.
public class ProjectHistoryItem : Object {
    public string text { get; construct; }
    public ProjectHistoryItemKind item_kind { get; construct; }
    public string? target_id { get; construct; }
    public bool dimmed { get; construct; }

    public ProjectHistoryItem(string text,
                              ProjectHistoryItemKind item_kind,
                              string? target_id,
                              bool dimmed) {
        Object(text: text, item_kind: item_kind, target_id: target_id, dimmed: dimmed);
    }
}

public class ProjectHistoryPresentation : Object {
    public string title { get; construct; }
    public string meta { get; construct; }
    // "Other Git changes (N)" line, or null when nothing unrecognised changed.
    public string? unknown_text { get; construct; }
    // Expander label, or null when the activity lists no affected paths.
    public string? affected_label { get; construct; }
    public ProjectHistoryItem[] items;

    public ProjectHistoryPresentation(string title,
                                      string meta,
                                      string? unknown_text,
                                      string? affected_label,
                                      ProjectHistoryItem[] items) {
        Object(title: title, meta: meta, unknown_text: unknown_text, affected_label: affected_label);
        this.items = items;
    }
}

public class ProjectHistoryPresenter {
    public const string EMPTY_TEXT = "No project activity yet";

    public static ProjectHistoryPresentation present(ProjectHistoryActivity activity) {
        var kinds = "";
        int unknown_paths = 0;
        foreach (var object in activity.affected_objects) {
            if (object.kind == "unknown") {
                unknown_paths += object.items.length;
                continue;
            }
            var label = object.kind.replace("_", " ");
            if (kinds.length > 0) kinds += " · ";
            kinds += "%s (%d)".printf(label, object.items.length);
        }
        var merge_context = activity.is_merge
            ? "Merged from %d parent%s".printf(
                activity.parent_oids.length, activity.parent_oids.length == 1 ? "" : "s"
            )
            : "";
        var meta = "%s · %s".printf(
            HistoryPresenter.format_when(activity.committed_at), activity.author_name
        );
        if (merge_context != "") meta += " · " + merge_context;
        if (kinds != "") meta += " · " + kinds;

        int affected_count = 0;
        foreach (var object in activity.affected_objects) affected_count += object.items.length;

        ProjectHistoryItem[] items = {};
        foreach (var object in activity.affected_objects) {
            foreach (var path in object.items) {
                items += present_path(object.kind, path);
            }
        }

        return new ProjectHistoryPresentation(
            activity.is_merge ? "Merged: " + activity.message : activity.message,
            meta,
            unknown_paths > 0 ? "Other Git changes (%d)".printf(unknown_paths) : null,
            affected_count > 0
                ? "Show %d affected item%s".printf(affected_count, affected_count == 1 ? "" : "s")
                : null,
            items
        );
    }

    public static ProjectHistoryItem present_path(string object_kind, ProjectHistoryAffectedPath path) {
        var kind = object_kind == "unknown" ? "Other Git change" : object_kind.replace("_", " ");
        var describes_object = object_kind == "card" || object_kind == "resource"
            || object_kind == "ai_data" || object_kind == "project_settings";
        var text = "%s: %s".printf(kind, path.path);
        if (describes_object && path.title != null && path.title != "") {
            text = "%s: %s — %s".printf(kind, path.title, path.path);
        }
        if (describes_object && path.detail != null && path.detail != "") {
            text += " · " + path.detail;
        }
        var card_id = path_id(object_kind, path.path, "cards/", ".md");
        if (card_id != null) {
            return new ProjectHistoryItem(text, ProjectHistoryItemKind.CARD, card_id, false);
        }
        var resource_id = path_id(object_kind, path.path, "resources/", ".json");
        if (resource_id != null) {
            return new ProjectHistoryItem(text, ProjectHistoryItemKind.RESOURCE, resource_id, false);
        }
        var thread_id = path_id(object_kind, path.path, "ai_threads/", ".json");
        if (thread_id != null) {
            return new ProjectHistoryItem(text, ProjectHistoryItemKind.AI_THREAD, thread_id, false);
        }
        return new ProjectHistoryItem(text, ProjectHistoryItemKind.TEXT, null, object_kind == "unknown");
    }

    // The object id embedded in a repository path, only for the object kind that owns the
    // folder ("cards/<id>.md" for cards, and so on).
    public static string? path_id(string kind, string path, string prefix, string suffix) {
        if ((kind != "card" && prefix == "cards/") ||
            (kind != "resource" && prefix == "resources/") ||
            (kind != "ai_data" && prefix == "ai_threads/")) return null;
        if (!path.has_prefix(prefix) || !path.has_suffix(suffix)) return null;
        var filename = Path.get_basename(path);
        return filename.substring(0, filename.length - suffix.length);
    }
}

}
