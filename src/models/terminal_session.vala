namespace HolderLinux {

public enum TerminalSessionState {
    ACTIVE,
    COMPLETED,
    INTERRUPTED;

    public string to_storage_value() {
        switch (this) {
        case ACTIVE:
            return "active";
        case COMPLETED:
            return "completed";
        case INTERRUPTED:
            return "interrupted";
        default:
            return "interrupted";
        }
    }

    public static TerminalSessionState from_storage_value(string? value) {
        switch (value ?? "") {
        case "active":
            return ACTIVE;
        case "completed":
            return COMPLETED;
        default:
            return INTERRUPTED;
        }
    }
}

public class TerminalSession : Object {
    public string session_id { get; construct; }
    public string project_id { get; construct; }
    public string project_label { get; construct; }
    public string? card_id { get; construct; }
    public string? card_label { get; construct; }
    public string working_directory { get; construct; }
    public string transcript_path { get; construct; }
    public string bootstrap_path { get; construct; }
    public int64 created_at { get; construct; }
    public int64 last_modified_at { get; set; }
    public TerminalSessionState state { get; set; }

    public TerminalSession(string session_id,
                           string project_id,
                           string project_label,
                           string? card_id,
                           string? card_label,
                           string working_directory,
                           string transcript_path,
                           string bootstrap_path,
                           int64 created_at,
                           int64 last_modified_at = 0,
                           TerminalSessionState state = TerminalSessionState.ACTIVE) {
        Object(
            session_id: session_id,
            project_id: project_id,
            project_label: project_label,
            card_id: card_id,
            card_label: card_label,
            working_directory: working_directory,
            transcript_path: transcript_path,
            bootstrap_path: bootstrap_path,
            created_at: created_at,
            last_modified_at: last_modified_at,
            state: state
        );
    }
}

}
