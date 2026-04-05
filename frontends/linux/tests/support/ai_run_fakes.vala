using GLib;

namespace HolderLinuxTests {

public class AiRunFakeApi : Object, HolderLinux.IHolderApi {
    public int run_calls = 0;
    public string? last_thread_id = null;
    public string? last_run_runner_id = null;
    public string? last_run_model = null;
    public int start_pull_calls = 0;
    public string last_pull_model = "";
    public bool fail_capabilities = false;
    public bool fail_status = false;
    public bool fail_pull = false;
    public bool fail_stream = false;
    public bool slow_stream = false;
    public bool emit_progress = false;
    public bool emit_progress_empty = false;
    public bool emit_fallback = false;
    public bool emit_fallback_empty = false;
    public bool emit_failed = false;
    public bool emit_failed_empty = false;
    public bool done_without_model = false;
    public bool emit_chunk_missing_delta = false;
    public bool emit_router_result = false;
    public string emitted_run_id = "run-1";
    public string emitted_provider = "";
    public string emitted_model = "phi4";
    public string emitted_router_model = "";
    public bool pull_returns_empty_job_id = false;
    public int64 status_active_pull_jobs = 0;
    public bool fail_export_recovery_token = false;
    public string export_recovery_token_payload = "{\"token\":\"fake\"}";
    public Gee.ArrayList<HolderLinux.AiRunnerInfo> runners = new Gee.ArrayList<HolderLinux.AiRunnerInfo>();

    public async void health_check() throws Error {}
    public async HolderLinux.HealthInfo get_health_info() throws Error {
        return new HolderLinux.HealthInfo(true, 1000, "0.1", "test", 1);
    }
    public async Gee.ArrayList<HolderLinux.Project> list_projects() throws Error {
        return new Gee.ArrayList<HolderLinux.Project>();
    }
    public async string create_project(string name, string privacy_mode = "encrypted_git") throws Error {
        return "p1";
    }
    public async HolderLinux.ProjectRecoveryTokenExport export_project_recovery_token(
        string project_id,
        string pin
    ) throws Error {
        if (fail_export_recovery_token) {
            throw new IOError.FAILED("export failed");
        }
        return new HolderLinux.ProjectRecoveryTokenExport(project_id, "key-1", export_recovery_token_payload);
    }
    public async void import_project_recovery_token(
        string project_id,
        string pin,
        string recovery_token
    ) throws Error {}
    public async HolderLinux.RecoveryTokenImportResult import_recovery_token(
        string pin,
        string recovery_token
    ) throws Error {
        return new HolderLinux.RecoveryTokenImportResult(
            "p1",
            false,
            false,
            false,
            "",
            "not_attempted",
            ""
        );
    }
    public async Gee.ArrayList<HolderLinux.CardSummary> list_cards(string project_id,
                                                                    string view = "tree",
                                                                    string? parent_card_id = null,
                                                                    int limit = 0) throws Error {
        return new Gee.ArrayList<HolderLinux.CardSummary>();
    }
    public async HolderLinux.CardContextData get_card_context(string project_id,
                                                              string? parent_card_id = null) throws Error {
        return new HolderLinux.CardContextData(
            new HolderLinux.CardContextProject(project_id, "Project"),
            parent_card_id,
            new Gee.ArrayList<HolderLinux.CardContextBreadcrumb>(),
            new Gee.ArrayList<HolderLinux.CardContextCard>()
        );
    }
    public async HolderLinux.CardDetail get_card(string card_id) throws Error {
        return new HolderLinux.CardDetail(card_id, "p1", "T", "C", 1);
    }
    public async Gee.ArrayList<HolderLinux.CardLink> list_card_links(string card_id) throws Error {
        return new Gee.ArrayList<HolderLinux.CardLink>();
    }
    public async Gee.ArrayList<HolderLinux.CardLink> list_card_backlinks(string card_id) throws Error {
        return new Gee.ArrayList<HolderLinux.CardLink>();
    }
    public async Gee.ArrayList<HolderLinux.ProjectResource> list_resources(string project_id) throws Error {
        return new Gee.ArrayList<HolderLinux.ProjectResource>();
    }
    public async Gee.ArrayList<HolderLinux.TrashItem> list_trash_items(string project_id,
                                                                        string type = "all") throws Error {
        return new Gee.ArrayList<HolderLinux.TrashItem>();
    }
    public async void empty_trash(string project_id, string type = "all") throws Error {}
    public async void restore_trash_item(string item_type, string item_id) throws Error {}
    public async void hard_delete_trash_item(string item_type, string item_id) throws Error {}
    public async string create_resource(string project_id,
                                        string kind,
                                        string uri,
                                        string label,
                                        string? desc = null) throws Error {
        return "r1";
    }
    public async void update_resource(string resource_id,
                                      string? kind,
                                      string? uri,
                                      string? label,
                                      string? desc,
                                      int64 updated_at) throws Error {}
    public async void delete_resource(string resource_id) throws Error {}
    public async HolderLinux.CardLink create_card_link(string from_card_id,
                                                       string to_card_id,
                                                       string kind = "ref",
                                                       string? label = null,
                                                       string to_type = "card") throws Error {
        return new HolderLinux.CardLink(from_card_id, to_card_id, to_type, kind, label, 0);
    }
    public async void delete_card_link(string from_card_id,
                                       string to_card_id,
                                       string kind,
                                       string to_type = "card") throws Error {}
    public async Gee.ArrayList<HolderLinux.SearchCardResult> search_cards(string project_id,
                                                                           string query_text,
                                                                           int limit = 30) throws Error {
        return new Gee.ArrayList<HolderLinux.SearchCardResult>();
    }
    public async HolderLinux.AiCapabilitiesInfo get_ai_capabilities(string? project_id = null) throws Error {
        if (fail_capabilities) {
            throw new IOError.FAILED("capabilities failed");
        }
        return new HolderLinux.AiCapabilitiesInfo(
            true, "", 1, "1.0", "user", new Gee.ArrayList<string>(), new Gee.ArrayList<string>()
        );
    }
    public async HolderLinux.AiStatusInfo get_ai_status() throws Error {
        if (fail_status) {
            throw new IOError.FAILED("status failed");
        }
        return new HolderLinux.AiStatusInfo(1, true, "", 0, status_active_pull_jobs, 0, new Gee.ArrayList<string>());
    }
    public async string start_ai_runner_pull(string model_tag, string? runner_id = null) throws Error {
        if (fail_pull) {
            throw new IOError.FAILED("pull failed");
        }
        start_pull_calls++;
        last_pull_model = model_tag;
        if (pull_returns_empty_job_id) {
            return "";
        }
        return "job-1";
    }
    public async Gee.ArrayList<HolderLinux.AiRunnerInfo> list_ai_runners() throws Error {
        return runners;
    }
    public async HolderLinux.AiRunnerInfo create_ai_runner(string name,
                                                           string base_url,
                                                           bool enabled = true) throws Error {
        return new HolderLinux.AiRunnerInfo(
            "manual-created",
            name,
            "ollama",
            base_url,
            "manual",
            enabled,
            0,
            0,
            new HolderLinux.AiRunnerRuntimeInfo(false, false, false, 0, "", "", new Gee.ArrayList<string>(), new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>())
        );
    }
    public async HolderLinux.AiRunnerInfo update_ai_runner(string runner_id,
                                                           string? name = null,
                                                           string? base_url = null,
                                                           bool? enabled = null) throws Error {
        return new HolderLinux.AiRunnerInfo(
            runner_id,
            name ?? "Runner",
            "ollama",
            base_url,
            "manual",
            enabled ?? true,
            0,
            0,
            new HolderLinux.AiRunnerRuntimeInfo(false, false, false, 0, "", "", new Gee.ArrayList<string>(), new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>())
        );
    }
    public async void delete_ai_runner(string runner_id) throws Error {}
    public async Gee.ArrayList<HolderLinux.AiThreadSummary> list_ai_threads(string project_id) throws Error {
        return new Gee.ArrayList<HolderLinux.AiThreadSummary>();
    }
    public async Gee.ArrayList<HolderLinux.AiMessage> list_ai_messages(string thread_id) throws Error {
        return new Gee.ArrayList<HolderLinux.AiMessage>();
    }
    public async string create_ai_thread(string project_id, string title) throws Error {
        return "t-created";
    }
    public async Gee.ArrayList<HolderLinux.AiCatalogProvider> list_ai_provider_catalog() throws Error {
        return new Gee.ArrayList<HolderLinux.AiCatalogProvider>();
    }
    public async Gee.ArrayList<HolderLinux.AiRuntimeProvider> list_ai_runtime_providers() throws Error {
        return new Gee.ArrayList<HolderLinux.AiRuntimeProvider>();
    }
    public async HolderLinux.AiLocalModelConfigInfo get_ai_local_model_config() throws Error {
        return new HolderLinux.AiLocalModelConfigInfo(null, null, null, 0);
    }

    public async HolderLinux.AiLocalModelConfigInfo set_ai_local_model_config(string? fast_model,
                                                                              string? strong_model,
                                                                              string? deep_model) throws Error {
        return new HolderLinux.AiLocalModelConfigInfo(fast_model, strong_model, deep_model, 0);
    }
    public async Gee.ArrayList<HolderLinux.AiProviderCredentialState> list_ai_provider_credentials() throws Error {
        return new Gee.ArrayList<HolderLinux.AiProviderCredentialState>();
    }
    public async Gee.ArrayList<HolderLinux.AiProviderSettingState> list_ai_provider_settings() throws Error {
        return new Gee.ArrayList<HolderLinux.AiProviderSettingState>();
    }
    public async void upsert_ai_provider_credential(string provider, string api_key) throws Error {}
    public async void delete_ai_provider_credential(string provider) throws Error {}
    public async void set_ai_provider_enabled(string provider, bool enabled) throws Error {}
    public async Gee.ArrayList<HolderLinux.AiNudge> list_ai_nudges(string project_id,
                                                                   string? card_id = null) throws Error {
        return new Gee.ArrayList<HolderLinux.AiNudge>();
    }
    public async void dismiss_ai_nudge(string nudge_id) throws Error {}
    public async HolderLinux.NudgeEvaluationResult evaluate_nudge_candidate(string kind,
                                                                            string project_id,
                                                                            string? card_id,
                                                                            int64 created_at,
                                                                            Json.Object facts,
                                                                            string? basis_fingerprint = null,
                                                                            string? basis_commit = null) throws Error {
        return new HolderLinux.NudgeEvaluationResult(kind, false, false, "fake_not_implemented");
    }
    public async Gee.ArrayList<HolderLinux.GitProviderCatalogEntry> list_git_provider_catalog() throws Error {
        return new Gee.ArrayList<HolderLinux.GitProviderCatalogEntry>();
    }
    public async void set_project_git_remote(string project_id,
                                             string? git_remote_url,
                                             int64 updated_at) throws Error {}
    public async HolderLinux.GitTestRemoteResult test_project_git_remote(string project_id,
                                                                         string? remote_url = null,
                                                                         string branch = "") throws Error {
        return new HolderLinux.GitTestRemoteResult(project_id,
                                                   remote_url ?? "",
                                                   branch,
                                                   "reachable",
                                                   true,
                                                   "",
                                                   "");
    }
    public async HolderLinux.GitPushResult push_project_git(string project_id,
                                                            string branch = "",
                                                            bool set_upstream = true) throws Error {
        return new HolderLinux.GitPushResult(project_id,
                                             "",
                                             branch,
                                             "pushed",
                                             0,
                                             0,
                                             "",
                                             "",
                                             "",
                                             "");
    }
    public async void run_ai_stream(string prompt,
                                    string? project_id,
                                    string? thread_id,
                                    string? context_card_id,
                                    string? context_card_title,
                                    string? context_card_body,
                                    HolderLinux.AiRunEventHandler on_event,
                                    string? runner_id = null,
                                    string? model = null) throws Error {
        if (fail_stream) {
            throw new IOError.FAILED("stream failed");
        }
        run_calls++;
        last_thread_id = thread_id;
        last_run_runner_id = runner_id;
        last_run_model = model;

        if (slow_stream) {
            var loop = new MainLoop();
            Timeout.add(80, () => {
                loop.quit();
                return Source.REMOVE;
            });
            loop.run();
        }

        var chunk_obj = new Json.Object();
        chunk_obj.set_string_member("run_id", emitted_run_id);
        if (emitted_provider.length > 0) {
            chunk_obj.set_string_member("provider", emitted_provider);
        }
        if (emitted_model.length > 0) {
            chunk_obj.set_string_member("model", emitted_model);
        }
        if (emitted_provider.length == 0 && runner_id != null && runner_id.length > 0) {
            chunk_obj.set_string_member("runner_id", runner_id);
        }
        if (!emit_chunk_missing_delta) {
            chunk_obj.set_string_member("delta", "hello");
        }
        on_event("chunk", chunk_obj);

        if (emit_progress) {
            var progress_obj = new Json.Object();
            progress_obj.set_string_member("run_id", emitted_run_id);
            progress_obj.set_string_member("message", "working");
            if (emitted_provider.length > 0) {
                progress_obj.set_string_member("provider", emitted_provider);
            }
            if (emitted_model.length > 0) {
                progress_obj.set_string_member("model", emitted_model);
            }
            on_event("progress", progress_obj);
        }
        if (emit_progress_empty) {
            on_event("progress", new Json.Object());
        }
        if (emit_router_result) {
            var router_obj = new Json.Object();
            router_obj.set_string_member("run_id", emitted_run_id);
            if (emitted_router_model.length > 0) {
                router_obj.set_string_member("router_model", emitted_router_model);
            }
            on_event("router_result", router_obj);
        }
        if (emit_fallback) {
            var fallback_obj = new Json.Object();
            fallback_obj.set_string_member("run_id", emitted_run_id);
            if (emitted_provider.length > 0) {
                fallback_obj.set_string_member("provider", emitted_provider);
            }
            if (emitted_model.length > 0) {
                fallback_obj.set_string_member("model", emitted_model);
            }
            fallback_obj.set_string_member("error", "rate limit");
            on_event("fallback", fallback_obj);
        }
        if (emit_fallback_empty) {
            on_event("fallback", new Json.Object());
        }
        if (emit_failed) {
            var failed_obj = new Json.Object();
            failed_obj.set_string_member("error", "bad prompt");
            on_event("failed", failed_obj);
        }
        if (emit_failed_empty) {
            on_event("failed", new Json.Object());
        }

        var done_obj = new Json.Object();
        done_obj.set_string_member("run_id", emitted_run_id);
        if (emitted_provider.length > 0) {
            done_obj.set_string_member("provider", emitted_provider);
        }
        if (!done_without_model && emitted_model.length > 0) {
            done_obj.set_string_member("model", emitted_model);
        }
        on_event("done", done_obj);
    }
    public async string create_card(string project_id,
                                    string title,
                                    string content,
                                    string? parent_card_id = null) throws Error {
        return "c1";
    }
    public async void update_card(string card_id,
                                  string title,
                                  string content,
                                  int64 updated_at) throws Error {}
    public async void update_card_position(string card_id,
                                           string? parent_card_id,
                                           double sort_key,
                                           int64 updated_at) throws Error {}
    public async void delete_card(string card_id) throws Error {}
    public async HolderLinux.CardMoveResult move_card(string card_id,
                                                       string project_id,
                                                       string intent,
                                                       string? target_card_id = null,
                                                       string? parent_card_id = null) throws Error {
        return new HolderLinux.CardMoveResult(card_id, parent_card_id, 0.0, 1, "");
    }
}

public class AiRunFakeContext : Object, HolderLinux.IAiRunContext {
    public HolderLinux.IHolderApi? api;
    public HolderLinux.Project? project;
    public HolderLinux.CardDetail? card;
    public HolderLinux.AiThreadSummary? thread;
    public int create_thread_calls = 0;
    public int reload_threads_calls = 0;
    public string? selected_thread_id = null;
    public bool fail_create_thread = false;
    public string create_thread_id = "t-created";
    public Gee.ArrayList<HolderLinux.AiMessage> transcript_messages = new Gee.ArrayList<HolderLinux.AiMessage>();

    public HolderLinux.IHolderApi? get_api_client() {
        return api;
    }

    public string? selected_project_id() {
        return project != null ? project.project_id : null;
    }

    public HolderLinux.Project? get_current_project() {
        return project;
    }

    public HolderLinux.CardDetail? get_current_card() {
        return card;
    }

    public HolderLinux.AiThreadSummary? get_current_ai_thread() {
        return thread;
    }

    public async Gee.ArrayList<HolderLinux.AiMessage> list_ai_messages(string thread_id) throws Error {
        return transcript_messages;
    }

    public int64 now_epoch_seconds() {
        return 1234;
    }

    public async string create_ai_thread(string title) throws Error {
        if (fail_create_thread) {
            throw new IOError.FAILED("create thread failed");
        }
        create_thread_calls++;
        return create_thread_id;
    }

    public async void reload_ai_threads_for_project(string project_id,
                                                    string? preferred_thread_id = null) {
        reload_threads_calls++;
        if (preferred_thread_id != null && preferred_thread_id.length > 0) {
            select_ai_thread_by_id(preferred_thread_id);
        }
    }

    public bool select_ai_thread_by_id(string thread_id) {
        selected_thread_id = thread_id;
        thread = new HolderLinux.AiThreadSummary(thread_id, "p1", "New thread", 1, 1);
        return true;
    }
}

}
