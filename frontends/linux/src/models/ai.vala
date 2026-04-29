namespace HolderLinux {

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

public class AiRunnerPullInfo : Object {
    public string job_id { get; construct; }
    public string runner_id { get; construct; }
    public string model { get; construct; }
    public string status { get; construct; }
    public double percent { get; construct; }
    public string stage { get; construct; }

    public AiRunnerPullInfo(string job_id,
                            string runner_id,
                            string model,
                            string status,
                            double percent,
                            string stage) {
        Object(
            job_id: job_id,
            runner_id: runner_id,
            model: model,
            status: status,
            percent: percent,
            stage: stage
        );
    }
}

public class AiRunnerRuntimeInfo : Object {
    public bool configured { get; construct; }
    public bool available { get; construct; }
    public bool spawn_attempted { get; construct; }
    public int64 last_checked { get; construct; }
    public string version { get; construct; }
    public string error { get; construct; }
    public Gee.ArrayList<string> models { get; construct; }
    public Gee.ArrayList<AiRunnerPullInfo> pulls { get; construct; }

    public AiRunnerRuntimeInfo(bool configured,
                               bool available,
                               bool spawn_attempted,
                               int64 last_checked,
                               string version,
                               string error,
                               Gee.ArrayList<string> models,
                               Gee.ArrayList<AiRunnerPullInfo> pulls) {
        Object(
            configured: configured,
            available: available,
            spawn_attempted: spawn_attempted,
            last_checked: last_checked,
            version: version,
            error: error,
            models: models,
            pulls: pulls
        );
    }
}

public class AiRunnerInfo : Object {
    public string runner_id { get; construct; }
    public string name { get; construct; }
    public string kind { get; construct; }
    public string? base_url { get; construct; }
    public string source { get; construct; }
    public bool enabled { get; construct; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; construct; }
    public AiRunnerRuntimeInfo runtime { get; construct; }

    public AiRunnerInfo(string runner_id,
                        string name,
                        string kind,
                        string? base_url,
                        string source,
                        bool enabled,
                        int64 created_at,
                        int64 updated_at,
                        AiRunnerRuntimeInfo runtime) {
        Object(
            runner_id: runner_id,
            name: name,
            kind: kind,
            base_url: base_url,
            source: source,
            enabled: enabled,
            created_at: created_at,
            updated_at: updated_at,
            runtime: runtime
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
    public Gee.ArrayList<AiRunnerPullInfo> pulls { get; construct; }

    public AiStatusInfo(int64 checked_at,
                        bool runner_available,
                        string runner_error,
                        int64 active_runs,
                        int64 active_pull_jobs,
                        int64 cloud_configured_providers,
                        Gee.ArrayList<AiRunnerPullInfo> pulls) {
        Object(
            checked_at: checked_at,
            runner_available: runner_available,
            runner_error: runner_error,
            active_runs: active_runs,
            active_pull_jobs: active_pull_jobs,
            cloud_configured_providers: cloud_configured_providers,
            pulls: pulls
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

}
