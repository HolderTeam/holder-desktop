using GLib;

namespace HolderLinuxTests {

private void test_send_with_existing_thread_streams_and_completes() {
    var api = new AiRunFakeApi();
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
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
    var api = new AiRunFakeApi();
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
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
    assert(ctx.reload_threads_calls == 2);
    assert(ctx.selected_thread_id == "t-created");
    assert(api.run_calls == 1);
    assert(api.last_thread_id == "t-created");
}

private void test_send_requires_project() {
    var api = new AiRunFakeApi();
    var ctx = new AiRunFakeContext();
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
    var api = new AiRunFakeApi();
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
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
    var api = new AiRunFakeApi();
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
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
    var api = new AiRunFakeApi();
    api.pull_returns_empty_job_id = true;
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
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
    var api = new AiRunFakeApi();
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool rendered = false;
    controller.render_status_requested.connect((capabilities, status) => {
        rendered = true;
    });

    controller.refresh_status.begin();
    assert(wait_for_condition(() => rendered));
}

private void test_refresh_status_error_preserves_rendered_state_and_emits_status_error() {
    var api = new AiRunFakeApi();
    api.fail_capabilities = true;
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool got_status = false;
    bool got_error = false;
    bool got_render_reset = false;
    controller.status_changed.connect((text) => {
        if (text == "AI status refresh failed") {
            got_status = true;
        }
    });
    controller.error_reported.connect((title, details) => {
        if (title == "AI status refresh failed" && details.contains("capabilities failed")) {
            got_error = true;
        }
    });
    controller.render_status_error_requested.connect((message) => {
        got_render_reset = true;
    });

    controller.refresh_status.begin();
    assert(wait_for_condition(() => got_status && got_error));
    assert(!got_render_reset);
}

private void test_start_model_pull_error_emits_error() {
    var api = new AiRunFakeApi();
    api.fail_pull = true;
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
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
    var api = new AiRunFakeApi();
    api.emit_progress = true;
    api.emit_fallback = true;
    api.emit_failed = true;
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
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
    var api = new AiRunFakeApi();
    api.emit_failed_empty = true;
    api.done_without_model = true;
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
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
    var api = new AiRunFakeApi();
    var ctx = new AiRunFakeContext();
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
    var api = new AiRunFakeApi();
    api.status_active_pull_jobs = 1;
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
    var scheduler = new TestScheduler();
    var controller = new HolderLinux.AiRunController(ctx, scheduler);

    controller.set_panel_visible(true);
    assert(wait_for_condition(() => scheduler.repeating_scheduled > 0));
    controller.set_panel_visible(false);
    assert(scheduler.cancel_calls > 0);
}

private void test_refresh_status_with_no_api_is_noop() {
    var ctx = new AiRunFakeContext();
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
    var ctx = new AiRunFakeContext();
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
    var api = new AiRunFakeApi();
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
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
    var api = new AiRunFakeApi();
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
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
    var api = new AiRunFakeApi();
    api.fail_stream = true;
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
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
    var api = new AiRunFakeApi();
    api.slow_stream = true;
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
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
    var api = new AiRunFakeApi();
    api.emit_chunk_missing_delta = true;
    api.emit_progress_empty = true;
    api.emit_fallback_empty = true;
    api.done_without_model = true;
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
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
    var api = new AiRunFakeApi();
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
    var scheduler = new TestScheduler();
    var controller = new HolderLinux.AiRunController(ctx, scheduler);

    controller.stop();
    assert(scheduler.cancel_calls == 0);
}

private void test_refresh_status_stops_polling_when_no_active_pull_jobs() {
    var api = new AiRunFakeApi();
    api.status_active_pull_jobs = 1;
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
    var scheduler = new TestScheduler();
    var controller = new HolderLinux.AiRunController(ctx, scheduler);

    controller.set_panel_visible(true);
    assert(wait_for_condition(() => scheduler.repeating_scheduled > 0));
    assert(scheduler.cancel_calls == 0);

    api.status_active_pull_jobs = 0;
    controller.refresh_status.begin();
    assert(wait_for_condition(() => scheduler.cancel_calls > 0));
}

private void test_refresh_status_with_active_jobs_does_not_schedule_polling_twice() {
    var api = new AiRunFakeApi();
    api.status_active_pull_jobs = 1;
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
    var scheduler = new TestScheduler();
    var controller = new HolderLinux.AiRunController(ctx, scheduler);

    int renders = 0;
    controller.render_status_requested.connect((capabilities, status) => {
        renders++;
    });

    controller.set_panel_visible(true);
    assert(wait_for_condition(() => scheduler.repeating_scheduled == 1 && renders >= 1));

    controller.refresh_status.begin();
    assert(wait_for_condition(() => renders >= 2));
    assert(scheduler.repeating_scheduled == 1);
}

private void test_ai_poll_tick_visible_continues_and_triggers_refresh() {
    var api = new AiRunFakeApi();
    api.status_active_pull_jobs = 1;
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
    var scheduler = new TestScheduler();
    var controller = new HolderLinux.AiRunController(ctx, scheduler);

    int renders = 0;
    controller.render_status_requested.connect((capabilities, status) => {
        renders++;
    });

    controller.set_panel_visible(true);
    assert(wait_for_condition(() => renders >= 1));
    var before = renders;
    assert(controller.poll_tick() == Source.CONTINUE);
    assert(wait_for_condition(() => renders > before));
}

private void test_ai_poll_tick_hidden_removes() {
    var api = new AiRunFakeApi();
    api.status_active_pull_jobs = 1;
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "encrypted_git", "/tmp", 1, 1);
    var scheduler = new TestScheduler();
    var controller = new HolderLinux.AiRunController(ctx, scheduler);

    controller.set_panel_visible(true);
    assert(wait_for_condition(() => scheduler.repeating_scheduled > 0));
    controller.set_panel_visible(false);

    assert(controller.poll_tick() == Source.REMOVE);
}

private void test_handle_ai_run_event_unknown_event_is_ignored() {
    var api = new AiRunFakeApi();
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool saw_output = false;
    bool saw_chunk = false;
    bool saw_status = false;
    controller.append_output_requested.connect((role, text) => {
        saw_output = true;
    });
    controller.append_output_chunk_requested.connect((text) => {
        saw_chunk = true;
    });
    controller.status_changed.connect((text) => {
        saw_status = true;
    });

    controller.handle_ai_run_event("mystery_event", new Json.Object());

    assert(!saw_output);
    assert(!saw_chunk);
    assert(!saw_status);
}

private void test_handle_ai_run_event_with_null_member_is_ignored() {
    var api = new AiRunFakeApi();
    var ctx = new AiRunFakeContext();
    ctx.api = api;
    var controller = new HolderLinux.AiRunController(ctx, new TestScheduler());

    bool saw_chunk = false;
    controller.append_output_chunk_requested.connect((text) => {
        if (text.length > 0) {
            saw_chunk = true;
        }
    });

    var data = new Json.Object();
    data.set_null_member("delta");
    controller.handle_ai_run_event("chunk", data);

    assert(!saw_chunk);
}

private void test_constructor_uses_default_scheduler_when_null() {
    var ctx = new AiRunFakeContext();
    ctx.api = null;
    var controller = new HolderLinux.AiRunController(ctx, null);

    bool rendered = false;
    bool errored = false;
    controller.render_status_requested.connect((capabilities, status) => {
        rendered = true;
    });
    controller.render_status_error_requested.connect((message) => {
        errored = true;
    });

    controller.refresh_status.begin();
    assert(wait_for_condition(() => true));
    assert(!rendered);
    assert(!errored);
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
        "/ai_run/refresh_status_error_preserves_rendered_state_and_emits_status_error",
        test_refresh_status_error_preserves_rendered_state_and_emits_status_error
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
    Test.add_func(
        "/ai_run/refresh_status_stops_polling_when_no_active_pull_jobs",
        test_refresh_status_stops_polling_when_no_active_pull_jobs
    );
    Test.add_func(
        "/ai_run/refresh_status_with_active_jobs_does_not_schedule_polling_twice",
        test_refresh_status_with_active_jobs_does_not_schedule_polling_twice
    );
    Test.add_func(
        "/ai_run/ai_poll_tick_visible_continues_and_triggers_refresh",
        test_ai_poll_tick_visible_continues_and_triggers_refresh
    );
    Test.add_func(
        "/ai_run/ai_poll_tick_hidden_removes",
        test_ai_poll_tick_hidden_removes
    );
    Test.add_func(
        "/ai_run/handle_ai_run_event_unknown_event_is_ignored",
        test_handle_ai_run_event_unknown_event_is_ignored
    );
    Test.add_func(
        "/ai_run/handle_ai_run_event_with_null_member_is_ignored",
        test_handle_ai_run_event_with_null_member_is_ignored
    );
    Test.add_func(
        "/ai_run/constructor_uses_default_scheduler_when_null",
        test_constructor_uses_default_scheduler_when_null
    );

    return Test.run();
}

}
