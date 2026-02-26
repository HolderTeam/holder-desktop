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
    public string root_path { get; construct; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; set; }

    public Project(string project_id,
                   string name,
                   string root_path,
                   int64 created_at,
                   int64 updated_at) {
        Object(
            project_id: project_id,
            name: name,
            root_path: root_path,
            created_at: created_at,
            updated_at: updated_at
        );
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

public class GitProviderCatalogEntry : Object {
    public string id { get; construct; }
    public string name { get; construct; }
    public string kind { get; construct; }
    public string preferred_transport { get; construct; }
    public string transports_summary { get; construct; }

    public GitProviderCatalogEntry(string id,
                                   string name,
                                   string kind,
                                   string preferred_transport,
                                   string transports_summary) {
        Object(
            id: id,
            name: name,
            kind: kind,
            preferred_transport: preferred_transport,
            transports_summary: transports_summary
        );
    }
}

}
