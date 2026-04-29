namespace HolderLinux {

public class Project : Object {
    public string project_id { get; construct; }
    public string name { get; set; }
    public string privacy_mode { get; construct; }
    public string root_path { get; construct; }
    public string? git_remote_url { get; construct; }
    public ProjectSyncState sync { get; set; }
    public int card_count { get; set; }
    public int root_card_count { get; set; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; set; }

    public Project(string project_id,
                   string name,
                   string privacy_mode,
                   string root_path,
                   int64 created_at,
                   int64 updated_at,
                   string? git_remote_url = null,
                   ProjectSyncState? sync = null,
                   int card_count = 0,
                   int root_card_count = 0) {
        Object(
            project_id: project_id,
            name: name,
            privacy_mode: privacy_mode,
            root_path: root_path,
            git_remote_url: git_remote_url,
            sync: sync ?? new ProjectSyncState(),
            card_count: card_count,
            root_card_count: root_card_count,
            created_at: created_at,
            updated_at: updated_at
        );
    }
}

public class ProjectSyncState : Object {
    public bool has_last_commit_at { get; set; }
    public int64 last_commit_at { get; set; }
    public bool has_last_push_at { get; set; }
    public int64 last_push_at { get; set; }
    public bool has_last_pull_at { get; set; }
    public int64 last_pull_at { get; set; }
    public int uncommitted_changes_count { get; set; }
    public int unpushed_commits_count { get; set; }
    public string last_push_status { get; set; }
    public string last_pull_status { get; set; }
    public string last_sync_error { get; set; }
    public bool has_last_sync_error_at { get; set; }
    public int64 last_sync_error_at { get; set; }
    public int retry_count { get; set; }
    public bool has_next_retry_at { get; set; }
    public int64 next_retry_at { get; set; }
    public int pull_retry_count { get; set; }
    public bool has_next_pull_retry_at { get; set; }
    public int64 next_pull_retry_at { get; set; }
    public bool has_updated_at { get; set; }
    public int64 updated_at { get; set; }

    public ProjectSyncState(int64? last_commit_at = null,
                            int64? last_push_at = null,
                            int64? last_pull_at = null,
                            int uncommitted_changes_count = 0,
                            int unpushed_commits_count = 0,
                            string last_push_status = "",
                            string last_pull_status = "",
                            string last_sync_error = "",
                            int64? last_sync_error_at = null,
                            int retry_count = 0,
                            int64? next_retry_at = null,
                            int pull_retry_count = 0,
                            int64? next_pull_retry_at = null,
                            int64? updated_at = null) {
        this.has_last_commit_at = last_commit_at != null;
        this.last_commit_at = last_commit_at ?? 0;
        this.has_last_push_at = last_push_at != null;
        this.last_push_at = last_push_at ?? 0;
        this.has_last_pull_at = last_pull_at != null;
        this.last_pull_at = last_pull_at ?? 0;
        this.uncommitted_changes_count = uncommitted_changes_count;
        this.unpushed_commits_count = unpushed_commits_count;
        this.last_push_status = last_push_status;
        this.last_pull_status = last_pull_status;
        this.last_sync_error = last_sync_error;
        this.has_last_sync_error_at = last_sync_error_at != null;
        this.last_sync_error_at = last_sync_error_at ?? 0;
        this.retry_count = retry_count;
        this.has_next_retry_at = next_retry_at != null;
        this.next_retry_at = next_retry_at ?? 0;
        this.pull_retry_count = pull_retry_count;
        this.has_next_pull_retry_at = next_pull_retry_at != null;
        this.next_pull_retry_at = next_pull_retry_at ?? 0;
        this.has_updated_at = updated_at != null;
        this.updated_at = updated_at ?? 0;
    }
}

public class ProjectResource : Object {
    public string resource_id { get; construct; }
    public string project_id { get; construct; }
    public string kind { get; set; }
    public string uri { get; set; }
    public string label { get; set; }
    public string? desc { get; set; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; set; }

    public ProjectResource(string resource_id,
                           string project_id,
                           string kind,
                           string uri,
                           string label,
                           string? desc,
                           int64 created_at,
                           int64 updated_at) {
        Object(
            resource_id: resource_id,
            project_id: project_id,
            kind: kind,
            uri: uri,
            label: label,
            desc: desc,
            created_at: created_at,
            updated_at: updated_at
        );
    }
}

public class TrashItem : Object {
    public string item_type { get; construct; }
    public string item_id { get; construct; }
    public string title { get; construct; }
    public int64 deleted_at { get; construct; }

    public TrashItem(string item_type,
                     string item_id,
                     string title,
                     int64 deleted_at) {
        Object(
            item_type: item_type,
            item_id: item_id,
            title: title,
            deleted_at: deleted_at
        );
    }
}

}
