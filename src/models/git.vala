namespace HolderLinux {

public class GitProviderCatalogEntry : Object {
    public string id { get; construct; }
    public string name { get; construct; }
    public string kind { get; construct; }
    public string preferred_transport { get; construct; }
    public string transports_summary { get; construct; }
    public string ssh_example { get; construct; }
    public string https_example { get; construct; }

    public GitProviderCatalogEntry(string id,
                                   string name,
                                   string kind,
                                   string preferred_transport,
                                   string transports_summary,
                                   string ssh_example,
                                   string https_example) {
        Object(
            id: id,
            name: name,
            kind: kind,
            preferred_transport: preferred_transport,
            transports_summary: transports_summary,
            ssh_example: ssh_example,
            https_example: https_example
        );
    }
}

public class GitTestRemoteResult : Object {
    public string project_id { get; construct; }
    public string remote_url { get; construct; }
    public string branch { get; construct; }
    public string status { get; construct; }
    public bool remote_has_head { get; construct; }
    public string error_code { get; construct; }
    public string error_message { get; construct; }

    public GitTestRemoteResult(string project_id,
                               string remote_url,
                               string branch,
                               string status,
                               bool remote_has_head,
                               string error_code,
                               string error_message) {
        Object(
            project_id: project_id,
            remote_url: remote_url,
            branch: branch,
            status: status,
            remote_has_head: remote_has_head,
            error_code: error_code,
            error_message: error_message
        );
    }
}

public class GitPushResult : Object {
    public string project_id { get; construct; }
    public string remote_url { get; construct; }
    public string branch { get; construct; }
    public string status { get; construct; }
    public int ahead_count { get; construct; }
    public int behind_count { get; construct; }
    public string local_head_commit { get; construct; }
    public string error_code { get; construct; }
    public string error_message { get; construct; }
    public string next_action { get; construct; }

    public GitPushResult(string project_id,
                         string remote_url,
                         string branch,
                         string status,
                         int ahead_count,
                         int behind_count,
                         string local_head_commit,
                         string error_code,
                         string error_message,
                         string next_action) {
        Object(
            project_id: project_id,
            remote_url: remote_url,
            branch: branch,
            status: status,
            ahead_count: ahead_count,
            behind_count: behind_count,
            local_head_commit: local_head_commit,
            error_code: error_code,
            error_message: error_message,
            next_action: next_action
        );
    }
}

public class GitPushDetails : ActivityDetails {
    public string status { get; construct; }
    public string local_head_commit { get; construct; }
    public string branch { get; construct; }

    public GitPushDetails(string status, string local_head_commit, string branch) {
        Object(status: status, local_head_commit: local_head_commit, branch: branch);
    }
}

}
