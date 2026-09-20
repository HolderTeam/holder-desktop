namespace HolderLinux {

public class GitSyncNowOutcome : Object {
    public string toast_message { get; construct; }
    public string error_title { get; construct; }
    public string error_details { get; construct; }
    public bool history_changed { get; construct; }

    public GitSyncNowOutcome(string toast_message,
                             string error_title = "",
                             string error_details = "",
                             bool history_changed = false) {
        Object(
            toast_message: toast_message,
            error_title: error_title,
            error_details: error_details,
            history_changed: history_changed
        );
    }
}

public class GitSyncOutcomes : Object {
    public static GitSyncNowOutcome for_push_result(GitPushResult result) {
        if (result.status == "pushed") {
            return new GitSyncNowOutcome("Project synced.", "", "", true);
        }
        if (result.status == "up_to_date") {
            return new GitSyncNowOutcome("Project is already up to date.", "", "", true);
        }
        var details = result.error_message.strip();
        if (details.length == 0) {
            details = "Git sync returned: %s".printf(result.status);
        }
        return new GitSyncNowOutcome("", "Git sync failed", details, false);
    }
}

}
