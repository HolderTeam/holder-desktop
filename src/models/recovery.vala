namespace HolderLinux {

public class ProjectRecoveryTokenExport : Object {
    public string project_id { get; construct; }
    public string key_id { get; construct; }
    public string recovery_token { get; construct; }

    public ProjectRecoveryTokenExport(string project_id,
                                      string key_id,
                                      string recovery_token) {
        Object(
            project_id: project_id,
            key_id: key_id,
            recovery_token: recovery_token
        );
    }
}

public class RecoveryTokenImportResult : Object {
    public string project_id { get; construct; }
    public bool project_created { get; construct; }
    public bool remote_hint_present { get; construct; }
    public bool remote_configured { get; construct; }
    public string remote_error { get; construct; }
    public string pull_status { get; construct; }
    public string pull_error { get; construct; }

    public RecoveryTokenImportResult(string project_id,
                                     bool project_created,
                                     bool remote_hint_present,
                                     bool remote_configured,
                                     string remote_error,
                                     string pull_status,
                                     string pull_error) {
        Object(
            project_id: project_id,
            project_created: project_created,
            remote_hint_present: remote_hint_present,
            remote_configured: remote_configured,
            remote_error: remote_error,
            pull_status: pull_status,
            pull_error: pull_error
        );
    }
}

}
