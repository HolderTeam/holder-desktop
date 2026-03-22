namespace HolderLinux {

public class ServerInfo : Object {
    public int pid { get; construct; }
    public string bind { get; construct; }
    public int port { get; construct; }
    public int64 started_at { get; construct; }
    public string api_version { get; construct; }
    public string server_version { get; construct; }
    public string auth_token { get; construct; }

    public ServerInfo(int pid,
                      string bind,
                      int port,
                      int64 started_at,
                      string api_version,
                      string server_version,
                      string auth_token) {
        Object(
            pid: pid,
            bind: bind,
            port: port,
            started_at: started_at,
            api_version: api_version,
            server_version: server_version,
            auth_token: auth_token
        );
    }

    public string base_url() {
        return "http://%s:%d".printf(bind, port);
    }
}

public class HealthInfo : Object {
    public bool db_ok { get; construct; }
    public int64 uptime_ms { get; construct; }
    public string api_version { get; construct; }
    public string server_version { get; construct; }
    public int pid { get; construct; }

    public HealthInfo(bool db_ok,
                      int64 uptime_ms,
                      string api_version,
                      string server_version,
                      int pid) {
        Object(
            db_ok: db_ok,
            uptime_ms: uptime_ms,
            api_version: api_version,
            server_version: server_version,
            pid: pid
        );
    }
}

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

public class CardSummary : Object {
    public string card_id { get; construct; }
    public string project_id { get; construct; }
    public string title { get; set; }
    public string rel_path { get; construct; }
    public double sort_key { get; set; }
    public string? parent_card_id { get; set; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; set; }

    public CardSummary(string card_id,
                       string project_id,
                       string title,
                       string rel_path,
                       double sort_key,
                       string? parent_card_id,
                       int64 created_at,
                       int64 updated_at) {
        Object(
            card_id: card_id,
            project_id: project_id,
            title: title,
            rel_path: rel_path,
            sort_key: sort_key,
            parent_card_id: parent_card_id,
            created_at: created_at,
            updated_at: updated_at
        );
    }
}

public class CardLink : Object {
    public string from_card_id { get; construct; }
    public string to_card_id { get; construct; }
    public string to_type { get; construct; }
    public string kind { get; construct; }
    public string? label { get; construct; }
    public int64 created_at { get; construct; }

    public CardLink(string from_card_id,
                    string to_card_id,
                    string to_type,
                    string kind,
                    string? label,
                    int64 created_at) {
        Object(
            from_card_id: from_card_id,
            to_card_id: to_card_id,
            to_type: to_type,
            kind: kind,
            label: label,
            created_at: created_at
        );
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

public class FlowboardTile : Object {
    public string node_key { get; construct; }
    public string title { get; construct; }
    public int64 updated_at { get; construct; }
    public bool is_container { get; construct; }
    public string? card_id { get; construct; }
    public string? project_id { get; construct; }
    public string? parent_card_id { get; construct; }
    public int sibling_count { get; construct; }
    public int sibling_index { get; construct; }
    public int child_count { get; construct; }

    public FlowboardTile(string node_key,
                         string title,
                         int64 updated_at,
                         bool is_container,
                         string? card_id = null,
                         string? project_id = null,
                         string? parent_card_id = null,
                         int sibling_count = 0,
                         int sibling_index = 0,
                         int child_count = 0) {
        Object(
            node_key: node_key,
            title: title,
            updated_at: updated_at,
            is_container: is_container,
            card_id: card_id,
            project_id: project_id,
            parent_card_id: parent_card_id,
            sibling_count: sibling_count,
            sibling_index: sibling_index,
            child_count: child_count
        );
    }
}

public class FlowboardBreadcrumbSegment : Object {
    public string label { get; construct; }

    public FlowboardBreadcrumbSegment(string label) {
        Object(label: label);
    }
}

public class CardDetail : Object {
    public string card_id { get; construct; }
    public string project_id { get; construct; }
    public string title { get; set; }
    public string content { get; set; }
    public int64 updated_at { get; set; }

    public CardDetail(string card_id,
                      string project_id,
                      string title,
                      string content,
                      int64 updated_at) {
        Object(
            card_id: card_id,
            project_id: project_id,
            title: title,
            content: content,
            updated_at: updated_at
        );
    }
}

public class SearchCardResult : Object {
    public string card_id { get; construct; }
    public string title { get; construct; }
    public int64 updated_at { get; construct; }
    public int64 created_at { get; construct; }
    public string snippet { get; construct; }
    public double rank { get; construct; }

    public SearchCardResult(string card_id,
                            string title,
                            int64 updated_at,
                            int64 created_at,
                            string snippet,
                            double rank) {
        Object(
            card_id: card_id,
            title: title,
            updated_at: updated_at,
            created_at: created_at,
            snippet: snippet,
            rank: rank
        );
    }
}

public class AiCapabilitiesInfo : Object {
    public bool runner_available { get; construct; }
    public string runner_error { get; construct; }
    public int64 last_checked { get; construct; }
    public string runner_version { get; construct; }
    public string caste_name { get; construct; }
    public Gee.ArrayList<string> models { get; construct; }
    public Gee.ArrayList<string> recommended_install { get; construct; }

    public AiCapabilitiesInfo(bool runner_available,
                              string runner_error,
                              int64 last_checked,
                              string runner_version,
                              string caste_name,
                              Gee.ArrayList<string> models,
                              Gee.ArrayList<string> recommended_install) {
        Object(
            runner_available: runner_available,
            runner_error: runner_error,
            last_checked: last_checked,
            runner_version: runner_version,
            caste_name: caste_name,
            models: models,
            recommended_install: recommended_install
        );
    }
}

public class AiStatusInfo : Object {
    public int64 checked_at { get; construct; }
    public bool runner_available { get; construct; }
    public string runner_error { get; construct; }
    public int64 active_runs { get; construct; }
    public int64 active_pull_jobs { get; construct; }
    public int64 cloud_configured_providers { get; construct; }
    public Gee.ArrayList<string> pull_jobs { get; construct; }

    public AiStatusInfo(int64 checked_at,
                        bool runner_available,
                        string runner_error,
                        int64 active_runs,
                        int64 active_pull_jobs,
                        int64 cloud_configured_providers,
                        Gee.ArrayList<string> pull_jobs) {
        Object(
            checked_at: checked_at,
            runner_available: runner_available,
            runner_error: runner_error,
            active_runs: active_runs,
            active_pull_jobs: active_pull_jobs,
            cloud_configured_providers: cloud_configured_providers,
            pull_jobs: pull_jobs
        );
    }
}

public class AiThreadSummary : Object {
    public string thread_id { get; construct; }
    public string project_id { get; construct; }
    public string title { get; set; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; set; }

    public AiThreadSummary(string thread_id,
                           string project_id,
                           string title,
                           int64 created_at,
                           int64 updated_at) {
        Object(
            thread_id: thread_id,
            project_id: project_id,
            title: title,
            created_at: created_at,
            updated_at: updated_at
        );
    }
}

public class AiMessage : Object {
    public string message_id { get; construct; }
    public string thread_id { get; construct; }
    public string role { get; construct; }
    public string source { get; construct; }
    public string? provider { get; construct; }
    public string? model { get; construct; }
    public string content { get; construct; }
    public int64 created_at { get; construct; }

    public AiMessage(string message_id,
                     string thread_id,
                     string role,
                     string source,
                     string? provider,
                     string? model,
                     string content,
                     int64 created_at) {
        Object(
            message_id: message_id,
            thread_id: thread_id,
            role: role,
            source: source,
            provider: provider,
            model: model,
            content: content,
            created_at: created_at
        );
    }
}

public class AiCatalogProvider : Object {
    public string id { get; construct; }
    public string display_name { get; construct; }
    public bool enabled { get; construct; }
    public bool configured { get; construct; }
    public string setup_url { get; construct; }
    public string docs_url { get; construct; }

    public AiCatalogProvider(string id,
                             string display_name,
                             bool enabled,
                             bool configured,
                             string setup_url,
                             string docs_url) {
        Object(
            id: id,
            display_name: display_name,
            enabled: enabled,
            configured: configured,
            setup_url: setup_url,
            docs_url: docs_url
        );
    }
}

public class AiRuntimeProvider : Object {
    public string id { get; construct; }
    public string display_name { get; construct; }
    public bool enabled { get; construct; }
    public bool configured { get; construct; }
    public string setup_url { get; construct; }
    public string docs_url { get; construct; }

    public AiRuntimeProvider(string id,
                             string display_name,
                             bool enabled,
                             bool configured,
                             string setup_url,
                             string docs_url) {
        Object(
            id: id,
            display_name: display_name,
            enabled: enabled,
            configured: configured,
            setup_url: setup_url,
            docs_url: docs_url
        );
    }
}

public class AiProviderCredentialState : Object {
    public string provider { get; construct; }
    public bool configured { get; construct; }
    public string api_key_preview { get; construct; }
    public int64 updated_at { get; construct; }

    public AiProviderCredentialState(string provider,
                                     bool configured,
                                     string api_key_preview,
                                     int64 updated_at) {
        Object(
            provider: provider,
            configured: configured,
            api_key_preview: api_key_preview,
            updated_at: updated_at
        );
    }
}

public class AiProviderSettingState : Object {
    public string provider { get; construct; }
    public bool enabled { get; construct; }
    public int64 updated_at { get; construct; }

    public AiProviderSettingState(string provider,
                                  bool enabled,
                                  int64 updated_at) {
        Object(
            provider: provider,
            enabled: enabled,
            updated_at: updated_at
        );
    }
}

public class AiLocalModelConfigInfo : Object {
    public string? fast_model { get; construct; }
    public string? strong_model { get; construct; }
    public string? deep_model { get; construct; }
    public int64 updated_at { get; construct; }

    public AiLocalModelConfigInfo(string? fast_model,
                                  string? strong_model,
                                  string? deep_model,
                                  int64 updated_at) {
        Object(
            fast_model: fast_model,
            strong_model: strong_model,
            deep_model: deep_model,
            updated_at: updated_at
        );
    }
}

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

public class CardMoveResult : Object {
    public string card_id { get; construct; }
    public string? parent_card_id { get; construct; }
    public double sort_key { get; construct; }
    public int64 revision { get; construct; }
    public string moved_into_title { get; construct; }

    public CardMoveResult(string card_id,
                          string? parent_card_id,
                          double sort_key,
                          int64 revision,
                          string moved_into_title) {
        Object(
            card_id: card_id,
            parent_card_id: parent_card_id,
            sort_key: sort_key,
            revision: revision,
            moved_into_title: moved_into_title
        );
    }
}

public class CardContextProject : Object {
    public string project_id { get; construct; }
    public string name { get; construct; }

    public CardContextProject(string project_id, string name) {
        Object(
            project_id: project_id,
            name: name
        );
    }
}

public class CardContextBreadcrumb : Object {
    public string crumb_type { get; construct; }
    public string title { get; construct; }
    public string? project_id { get; construct; }
    public string? card_id { get; construct; }

    public CardContextBreadcrumb(string crumb_type,
                                 string title,
                                 string? project_id = null,
                                 string? card_id = null) {
        Object(
            crumb_type: crumb_type,
            title: title,
            project_id: project_id,
            card_id: card_id
        );
    }
}

public class CardContextCard : Object {
    public string card_id { get; construct; }
    public string project_id { get; construct; }
    public string title { get; construct; }
    public string rel_path { get; construct; }
    public double sort_key { get; construct; }
    public string? parent_card_id { get; construct; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; construct; }
    public int child_count { get; construct; }

    public CardContextCard(string card_id,
                           string project_id,
                           string title,
                           string rel_path,
                           double sort_key,
                           string? parent_card_id,
                           int64 created_at,
                           int64 updated_at,
                           int child_count) {
        Object(
            card_id: card_id,
            project_id: project_id,
            title: title,
            rel_path: rel_path,
            sort_key: sort_key,
            parent_card_id: parent_card_id,
            created_at: created_at,
            updated_at: updated_at,
            child_count: child_count
        );
    }
}

public class CardContextData : Object {
    public CardContextProject project { get; construct; }
    public string? current_parent_card_id { get; construct; }
    public Gee.ArrayList<CardContextBreadcrumb> breadcrumbs { get; construct; }
    public Gee.ArrayList<CardContextCard> cards { get; construct; }

    public CardContextData(CardContextProject project,
                           string? current_parent_card_id,
                           Gee.ArrayList<CardContextBreadcrumb> breadcrumbs,
                           Gee.ArrayList<CardContextCard> cards) {
        Object(
            project: project,
            current_parent_card_id: current_parent_card_id,
            breadcrumbs: breadcrumbs,
            cards: cards
        );
    }
}

public abstract class ActivityDetails : Object {
}

public class CardRenamedDetails : ActivityDetails {
    public string old_title { get; construct; }
    public string new_title { get; construct; }
    public bool body_empty { get; construct; }

    public CardRenamedDetails(string old_title, string new_title, bool body_empty) {
        Object(old_title: old_title, new_title: new_title, body_empty: body_empty);
    }
}

public class CardAutosavedDetails : ActivityDetails {
    public string title { get; construct; }
    public int doc_chars { get; construct; }
    public int body_chars { get; construct; }
    public int delta_chars { get; construct; }
    public bool body_empty { get; construct; }
    public string fingerprint { get; construct; }

    public CardAutosavedDetails(string title,
                                int doc_chars,
                                int body_chars,
                                int delta_chars,
                                bool body_empty,
                                string fingerprint) {
        Object(
            title: title,
            doc_chars: doc_chars,
            body_chars: body_chars,
            delta_chars: delta_chars,
            body_empty: body_empty,
            fingerprint: fingerprint
        );
    }
}

public class CardCreatedDetails : ActivityDetails {
    public string title { get; construct; }
    public string? parent_card_id { get; construct; }

    public CardCreatedDetails(string title, string? parent_card_id = null) {
        Object(title: title, parent_card_id: parent_card_id);
    }
}

public class CardTrashedDetails : ActivityDetails {
    public string title { get; construct; }

    public CardTrashedDetails(string title) {
        Object(title: title);
    }
}

public class TrashActionDetails : ActivityDetails {
    public string item_type { get; construct; }
    public string title { get; construct; }

    public TrashActionDetails(string item_type, string title) {
        Object(item_type: item_type, title: title);
    }
}

public class ResourceChangedDetails : ActivityDetails {
    public string operation { get; construct; }
    public string name { get; construct; }

    public ResourceChangedDetails(string operation, string name) {
        Object(operation: operation, name: name);
    }
}

public class AiRunDetails : ActivityDetails {
    public string provider { get; construct; }
    public string model { get; construct; }
    public bool success { get; construct; }

    public AiRunDetails(string provider, string model, bool success) {
        Object(provider: provider, model: model, success: success);
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

public class AiNudge : Object {
    public string nudge_id { get; construct; }
    public string kind { get; construct; }
    public string project_id { get; construct; }
    public string card_id { get; construct; }
    public string title { get; construct; }
    public string body { get; construct; }
    public string basis_fingerprint { get; construct; }
    public string basis_commit { get; construct; }
    public int64 created_at { get; construct; }

    public AiNudge(string nudge_id,
                   string kind,
                   string project_id,
                   string card_id,
                   string title,
                   string body,
                   string basis_fingerprint,
                   string basis_commit,
                   int64 created_at) {
        Object(
            nudge_id: nudge_id,
            kind: kind,
            project_id: project_id,
            card_id: card_id,
            title: title,
            body: body,
            basis_fingerprint: basis_fingerprint,
            basis_commit: basis_commit,
            created_at: created_at
        );
    }
}

public class NudgeEvaluationResult : Object {
    public string kind { get; construct; }
    public bool accepted { get; construct; }
    public bool should_nudge { get; construct; }
    public string reason { get; construct; }
    public AiNudge? nudge { get; construct; }

    public NudgeEvaluationResult(string kind,
                                 bool accepted,
                                 bool should_nudge,
                                 string reason,
                                 AiNudge? nudge = null) {
        Object(
            kind: kind,
            accepted: accepted,
            should_nudge: should_nudge,
            reason: reason,
            nudge: nudge
        );
    }
}

}
