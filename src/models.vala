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
    public int64 created_at { get; construct; }
    public int64 updated_at { get; set; }

    public CardSummary(string card_id,
                       string project_id,
                       string title,
                       string rel_path,
                       int64 created_at,
                       int64 updated_at) {
        Object(
            card_id: card_id,
            project_id: project_id,
            title: title,
            rel_path: rel_path,
            created_at: created_at,
            updated_at: updated_at
        );
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

}
