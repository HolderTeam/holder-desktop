namespace HolderLinux {

public class ActivityLogEntry : Object {
    public int64 timestamp { get; construct; }
    public string kind { get; construct; }
    public string message { get; construct; }
    public string? project_id { get; construct; }
    public string? card_id { get; construct; }
    public ActivityDetails? details { get; construct; }

    public ActivityLogEntry(int64 timestamp,
                            string kind,
                            string message,
                            string? project_id = null,
                            string? card_id = null,
                            ActivityDetails? details = null) {
        Object(
            timestamp: timestamp,
            kind: kind,
            message: message,
            project_id: project_id,
            card_id: card_id,
            details: details
        );
    }
}

public class ActivityLogStore : Object {
    private const int MAX_ENTRIES = 500;
    private Gee.ArrayList<ActivityLogEntry> entries = new Gee.ArrayList<ActivityLogEntry>();

    public signal void entry_added(ActivityLogEntry entry);
    public signal void cleared();

    public Gee.List<ActivityLogEntry> snapshot() {
        return entries.read_only_view;
    }

    public void append(string kind,
                       string message,
                       string? project_id = null,
                       string? card_id = null,
                       ActivityDetails? details = null) {
        var entry = new ActivityLogEntry(
            new DateTime.now_utc().to_unix(),
            kind,
            message,
            project_id,
            card_id,
            details
        );
        entries.add(entry);
        while (entries.size > MAX_ENTRIES) {
            entries.remove_at(0);
        }
        entry_added(entry);
    }

    public void clear() {
        entries.clear();
        cleared();
    }
}

}
