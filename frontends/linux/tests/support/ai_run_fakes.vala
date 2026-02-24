using GLib;

namespace HolderLinuxTests {

public class AiRunFakeApi : Object, HolderLinux.IHolderApi {
    public int run_calls = 0;
    public string? last_thread_id = null;
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
    public bool pull_returns_empty_job_id = false;
    public int64 status_active_pull_jobs = 0;

    public async void health_check() throws Error {}
    public async Gee.ArrayList<HolderLinux.Project> list_projects() throws Error {
        return new Gee.ArrayList<HolderLinux.Project>();
    }
    public async string create_project(string name) throws Error {
        return "p1";
    }
    public async Gee.ArrayList<HolderLinux.CardSummary> list_cards(string project_id,
                                                                    string scope = "root",
                                                                    string? parent_card_id = null) throws Error {
        return new Gee.ArrayList<HolderLinux.CardSummary>();
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
    public async HolderLinux.CardLink create_card_link(string from_card_id,
                                                       string to_card_id,
                                                       string kind = "ref",
                                                       string? label = null,
                                                       string to_type = "card") throws Error {
        return new HolderLinux.CardLink(from_card_id, to_card_id, to_type, kind, label, 0);
    }
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
    public async string start_ai_runner_pull(string model_tag) throws Error {
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
    public async Gee.ArrayList<HolderLinux.AiThreadSummary> list_ai_threads(string project_id) throws Error {
        return new Gee.ArrayList<HolderLinux.AiThreadSummary>();
    }
    public async string create_ai_thread(string project_id, string title) throws Error {
        return "t-created";
    }
    public async Gee.ArrayList<HolderLinux.AiCatalogProvider> list_ai_provider_catalog() throws Error {
        return new Gee.ArrayList<HolderLinux.AiCatalogProvider>();
    }
    public async void run_ai_stream(string prompt,
                                    string? project_id,
                                    string? thread_id,
                                    string? context_card_id,
                                    string? context_card_title,
                                    string? context_card_body,
                                    HolderLinux.AiRunEventHandler on_event) throws Error {
        if (fail_stream) {
            throw new IOError.FAILED("stream failed");
        }
        run_calls++;
        last_thread_id = thread_id;

        if (slow_stream) {
            var loop = new MainLoop();
            Timeout.add(80, () => {
                loop.quit();
                return Source.REMOVE;
            });
            loop.run();
        }

        var chunk_obj = new Json.Object();
        if (!emit_chunk_missing_delta) {
            chunk_obj.set_string_member("delta", "hello");
        }
        on_event("chunk", chunk_obj);

        if (emit_progress) {
            var progress_obj = new Json.Object();
            progress_obj.set_string_member("message", "working");
            on_event("progress", progress_obj);
        }
        if (emit_progress_empty) {
            on_event("progress", new Json.Object());
        }
        if (emit_fallback) {
            var fallback_obj = new Json.Object();
            fallback_obj.set_string_member("model", "phi4");
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
        if (!done_without_model) {
            done_obj.set_string_member("model", "phi4");
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

    public async void reload_ai_threads_for_project(string project_id) {
        reload_threads_calls++;
    }

    public bool select_ai_thread_by_id(string thread_id) {
        selected_thread_id = thread_id;
        thread = new HolderLinux.AiThreadSummary(thread_id, "p1", "New thread", 1, 1);
        return true;
    }
}

}
