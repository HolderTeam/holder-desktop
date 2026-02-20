using GLib;

namespace HolderLinuxTests {

private class FakeApi : Object, HolderLinux.IHolderApi {
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
    public async Gee.ArrayList<HolderLinux.CardSummary> list_cards(string project_id) throws Error {
        return new Gee.ArrayList<HolderLinux.CardSummary>();
    }
    public async HolderLinux.CardDetail get_card(string card_id) throws Error {
        return new HolderLinux.CardDetail(card_id, "p1", "T", "C", 1);
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
                                    string content) throws Error {
        return "c1";
    }
    public async void update_card(string card_id,
                                  string title,
                                  string content,
                                  int64 updated_at) throws Error {}
}

private class FakeContext : Object, HolderLinux.IAiRunContext {
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

private void test_send_with_existing_thread_streams_and_completes() {
    var api = new FakeApi();
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    ctx.thread = new HolderLinux.AiThreadSummary("t1", "p1", "T", 1, 1);
    ctx.card = new HolderLinux.CardDetail("c1", "p1", "Card", "Body", 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool done = false;
    int send_enabled_events = 0;
    string output_chunks = "";
    controller.status_changed.connect((text) => {
        if (text == "AI run complete") {
            done = true;
        }
    });
    controller.set_send_enabled_requested.connect((enabled) => {
        send_enabled_events++;
    });
    controller.append_output_chunk_requested.connect((text) => {
        output_chunks += text;
    });

    controller.on_send_clicked("hello world");
    assert(wait_for_condition(() => done));
    assert(api.run_calls == 1);
    assert(api.last_thread_id == "t1");
    assert(send_enabled_events >= 2);
    assert(output_chunks.contains("hello"));
}

private void test_send_without_thread_creates_thread_then_runs() {
    var api = new FakeApi();
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    ctx.thread = null;
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool done = false;
    controller.status_changed.connect((text) => {
        if (text == "AI run complete") {
            done = true;
        }
    });

    controller.on_send_clicked("prompt");
    assert(wait_for_condition(() => done));
    assert(ctx.create_thread_calls == 1);
    assert(ctx.reload_threads_calls == 1);
    assert(ctx.selected_thread_id == "t-created");
    assert(api.run_calls == 1);
    assert(api.last_thread_id == "t-created");
}

private void test_send_requires_project() {
    var api = new FakeApi();
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = null;
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "No project selected") {
            got_error = true;
        }
    });
    controller.on_send_clicked("prompt");
    assert(wait_for_condition(() => got_error));
    assert(api.run_calls == 0);
}

private void test_send_requires_prompt() {
    var api = new FakeApi();
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    ctx.thread = new HolderLinux.AiThreadSummary("t1", "p1", "T", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Prompt required") {
            got_error = true;
        }
    });

    controller.on_send_clicked("   ");
    assert(wait_for_condition(() => got_error));
    assert(api.run_calls == 0);
}

private void test_start_model_pull_emits_status_and_toast() {
    var api = new FakeApi();
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool saw_toast = false;
    bool saw_started = false;
    controller.toast_requested.connect((message) => {
        if (message.contains("Started pull")) {
            saw_toast = true;
        }
    });
    controller.status_changed.connect((text) => {
        if (text.contains("Pull job started")) {
            saw_started = true;
        }
    });

    controller.start_model_pull.begin("phi4");
    assert(wait_for_condition(() => saw_toast && saw_started));
    assert(api.start_pull_calls == 1);
    assert(api.last_pull_model == "phi4");
}

private void test_start_model_pull_with_empty_job_id_reports_started() {
    var api = new FakeApi();
    api.pull_returns_empty_job_id = true;
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool saw_started = false;
    controller.status_changed.connect((text) => {
        if (text == "Pull started: phi4") {
            saw_started = true;
        }
    });

    controller.start_model_pull.begin("phi4");
    assert(wait_for_condition(() => saw_started));
    assert(api.start_pull_calls == 1);
}

private void test_refresh_status_emits_render_status() {
    var api = new FakeApi();
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool rendered = false;
    controller.render_status_requested.connect((capabilities, status) => {
        rendered = true;
    });

    controller.refresh_status.begin();
    assert(wait_for_condition(() => rendered));
}

private void test_refresh_status_error_emits_render_status_error() {
    var api = new FakeApi();
    api.fail_capabilities = true;
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool got_error = false;
    controller.render_status_error_requested.connect((message) => {
        if (message.contains("capabilities failed")) {
            got_error = true;
        }
    });

    controller.refresh_status.begin();
    assert(wait_for_condition(() => got_error));
}

private void test_start_model_pull_error_emits_error() {
    var api = new FakeApi();
    api.fail_pull = true;
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to start model pull") {
            got_error = true;
        }
    });

    controller.start_model_pull.begin("phi4");
    assert(wait_for_condition(() => got_error));
}

private void test_stream_progress_fallback_failed_events_are_rendered() {
    var api = new FakeApi();
    api.emit_progress = true;
    api.emit_fallback = true;
    api.emit_failed = true;
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    ctx.thread = new HolderLinux.AiThreadSummary("t1", "p1", "T", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool saw_progress = false;
    bool saw_fallback = false;
    bool saw_failed = false;
    controller.append_output_requested.connect((role, text) => {
        if (text.contains("working")) {
            saw_progress = true;
        }
        if (text.contains("Fallback from phi4")) {
            saw_fallback = true;
        }
        if (text.contains("bad prompt")) {
            saw_failed = true;
        }
    });

    controller.on_send_clicked("prompt");
    assert(wait_for_condition(() => saw_progress && saw_fallback && saw_failed));
}

private void test_stream_failed_without_error_uses_default_message() {
    var api = new FakeApi();
    api.emit_failed_empty = true;
    api.done_without_model = true;
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    ctx.thread = new HolderLinux.AiThreadSummary("t1", "p1", "T", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool saw_default_failed = false;
    bool saw_done_model_message = false;
    controller.append_output_requested.connect((role, text) => {
        if (text == "Run failed.") {
            saw_default_failed = true;
        }
        if (text.contains("Completed with")) {
            saw_done_model_message = true;
        }
    });

    controller.on_send_clicked("prompt");
    assert(wait_for_condition(() => saw_default_failed));
    assert(!saw_done_model_message);
}

private void test_create_thread_from_prompt_without_project_errors() {
    var api = new FakeApi();
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = null;
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Cannot create thread") {
            got_error = true;
        }
    });

    controller.create_thread_from_prompt.begin();
    assert(wait_for_condition(() => got_error));
}

private void test_set_panel_visible_starts_and_stops_polling() {
    var api = new FakeApi();
    api.status_active_pull_jobs = 1;
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    var scheduler = new TestScheduler();
    var controller = new HolderLinux.AiRunController(ctx, scheduler);

    controller.set_panel_visible(true);
    assert(wait_for_condition(() => scheduler.repeating_scheduled > 0));
    controller.set_panel_visible(false);
    assert(scheduler.cancel_calls > 0);
}

private void test_refresh_status_with_no_api_is_noop() {
    var ctx = new FakeContext();
    ctx.api = null;
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool rendered = false;
    bool got_error = false;
    controller.render_status_requested.connect((capabilities, status) => {
        rendered = true;
    });
    controller.render_status_error_requested.connect((message) => {
        got_error = true;
    });

    controller.refresh_status.begin();
    assert(wait_for_condition(() => true));
    assert(!rendered);
    assert(!got_error);
}

private void test_start_model_pull_with_no_api_is_noop() {
    var ctx = new FakeContext();
    ctx.api = null;
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool saw_status = false;
    controller.status_changed.connect((text) => {
        saw_status = true;
    });

    controller.start_model_pull.begin("phi4");
    assert(wait_for_condition(() => true));
    assert(!saw_status);
}

private void test_create_thread_failure_emits_error() {
    var api = new FakeApi();
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    ctx.fail_create_thread = true;
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to create AI thread") {
            got_error = true;
        }
    });

    controller.on_send_clicked("prompt");
    assert(wait_for_condition(() => got_error));
}

private void test_create_thread_empty_id_then_prompt_errors_missing_context() {
    var api = new FakeApi();
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    ctx.create_thread_id = "";
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool got_context_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Cannot run AI") {
            got_context_error = true;
        }
    });

    controller.on_send_clicked("prompt");
    assert(wait_for_condition(() => got_context_error));
    assert(api.run_calls == 0);
}

private void test_send_stream_failure_reports_error_and_recovers_send_enabled() {
    var api = new FakeApi();
    api.fail_stream = true;
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    ctx.thread = new HolderLinux.AiThreadSummary("t1", "p1", "T", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool got_error = false;
    bool send_reenabled = false;
    bool saw_system_failure = false;
    controller.error_reported.connect((title, details) => {
        if (title == "AI run failed") {
            got_error = true;
        }
    });
    controller.set_send_enabled_requested.connect((enabled) => {
        if (enabled) {
            send_reenabled = true;
        }
    });
    controller.append_output_requested.connect((role, text) => {
        if (text.contains("AI run failed: stream failed")) {
            saw_system_failure = true;
        }
    });

    controller.on_send_clicked("prompt");
    assert(wait_for_condition(() => got_error && send_reenabled && saw_system_failure));
}

private void test_send_while_in_flight_emits_busy_status() {
    var api = new FakeApi();
    api.slow_stream = true;
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    ctx.thread = new HolderLinux.AiThreadSummary("t1", "p1", "T", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool saw_busy = false;
    controller.status_changed.connect((text) => {
        if (text == "AI run already in progress...") {
            saw_busy = true;
        }
    });
    controller.set_send_enabled_requested.connect((enabled) => {
        if (!enabled) {
            controller.on_send_clicked("second");
        }
    });

    controller.on_send_clicked("first");
    assert(wait_for_condition(() => saw_busy));
}

private void test_stream_event_edge_defaults() {
    var api = new FakeApi();
    api.emit_chunk_missing_delta = true;
    api.emit_progress_empty = true;
    api.emit_fallback_empty = true;
    api.done_without_model = true;
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    ctx.thread = new HolderLinux.AiThreadSummary("t1", "p1", "T", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool saw_fallback_default = false;
    bool saw_working = false;
    bool saw_completed = false;
    string chunks = "";
    controller.append_output_requested.connect((role, text) => {
        if (text == "Fallback") {
            saw_fallback_default = true;
        }
        if (text.contains("working")) {
            saw_working = true;
        }
        if (text.contains("Completed with")) {
            saw_completed = true;
        }
    });
    controller.append_output_chunk_requested.connect((text) => {
        chunks += text;
    });

    controller.on_send_clicked("prompt");
    assert(wait_for_condition(() => saw_fallback_default));
    assert(!saw_working);
    assert(!saw_completed);
    assert(chunks.contains("\n"));
}

private void test_stop_without_polling_is_noop() {
    var api = new FakeApi();
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    var scheduler = new TestScheduler();
    var controller = new HolderLinux.AiRunController(ctx, scheduler);

    controller.stop();
    assert(scheduler.cancel_calls == 0);
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func(
        "/ai_run/send_with_existing_thread_streams_and_completes",
        test_send_with_existing_thread_streams_and_completes
    );
    Test.add_func(
        "/ai_run/send_without_thread_creates_thread_then_runs",
        test_send_without_thread_creates_thread_then_runs
    );
    Test.add_func(
        "/ai_run/send_requires_project",
        test_send_requires_project
    );
    Test.add_func(
        "/ai_run/send_requires_prompt",
        test_send_requires_prompt
    );
    Test.add_func(
        "/ai_run/start_model_pull_emits_status_and_toast",
        test_start_model_pull_emits_status_and_toast
    );
    Test.add_func(
        "/ai_run/start_model_pull_with_empty_job_id_reports_started",
        test_start_model_pull_with_empty_job_id_reports_started
    );
    Test.add_func(
        "/ai_run/refresh_status_emits_render_status",
        test_refresh_status_emits_render_status
    );
    Test.add_func(
        "/ai_run/refresh_status_error_emits_render_status_error",
        test_refresh_status_error_emits_render_status_error
    );
    Test.add_func(
        "/ai_run/start_model_pull_error_emits_error",
        test_start_model_pull_error_emits_error
    );
    Test.add_func(
        "/ai_run/stream_progress_fallback_failed_events_are_rendered",
        test_stream_progress_fallback_failed_events_are_rendered
    );
    Test.add_func(
        "/ai_run/stream_failed_without_error_uses_default_message",
        test_stream_failed_without_error_uses_default_message
    );
    Test.add_func(
        "/ai_run/create_thread_from_prompt_without_project_errors",
        test_create_thread_from_prompt_without_project_errors
    );
    Test.add_func(
        "/ai_run/set_panel_visible_starts_and_stops_polling",
        test_set_panel_visible_starts_and_stops_polling
    );
    Test.add_func(
        "/ai_run/refresh_status_with_no_api_is_noop",
        test_refresh_status_with_no_api_is_noop
    );
    Test.add_func(
        "/ai_run/start_model_pull_with_no_api_is_noop",
        test_start_model_pull_with_no_api_is_noop
    );
    Test.add_func(
        "/ai_run/create_thread_failure_emits_error",
        test_create_thread_failure_emits_error
    );
    Test.add_func(
        "/ai_run/create_thread_empty_id_then_prompt_errors_missing_context",
        test_create_thread_empty_id_then_prompt_errors_missing_context
    );
    Test.add_func(
        "/ai_run/send_stream_failure_reports_error_and_recovers_send_enabled",
        test_send_stream_failure_reports_error_and_recovers_send_enabled
    );
    Test.add_func(
        "/ai_run/send_while_in_flight_emits_busy_status",
        test_send_while_in_flight_emits_busy_status
    );
    Test.add_func(
        "/ai_run/stream_event_edge_defaults",
        test_stream_event_edge_defaults
    );
    Test.add_func(
        "/ai_run/stop_without_polling_is_noop",
        test_stop_without_polling_is_noop
    );

    return Test.run();
}

}
