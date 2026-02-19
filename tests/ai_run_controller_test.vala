using GLib;

namespace HolderLinuxTests {

private class FakeScheduler : Object, HolderLinux.IScheduler {
    private uint next_id = 1;

    public uint schedule_once(uint delay_ms, owned SourceFunc callback) {
        var id = next_id++;
        Idle.add(() => {
            callback();
            return Source.REMOVE;
        });
        return id;
    }

    public uint schedule_repeating(uint interval_ms, owned SourceFunc callback) {
        return next_id++;
    }

    public bool cancel(uint source_id) {
        return true;
    }
}

private class FakeApi : Object, HolderLinux.IHolderApi {
    public int run_calls = 0;
    public string? last_thread_id = null;
    public int start_pull_calls = 0;
    public string last_pull_model = "";

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
        return new HolderLinux.AiCapabilitiesInfo(
            true, "", 1, "1.0", "user", new Gee.ArrayList<string>(), new Gee.ArrayList<string>()
        );
    }
    public async HolderLinux.AiStatusInfo get_ai_status() throws Error {
        return new HolderLinux.AiStatusInfo(1, true, "", 0, 0, 0, new Gee.ArrayList<string>());
    }
    public async string start_ai_runner_pull(string model_tag) throws Error {
        start_pull_calls++;
        last_pull_model = model_tag;
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
        run_calls++;
        last_thread_id = thread_id;

        var chunk_obj = new Json.Object();
        chunk_obj.set_string_member("delta", "hello");
        on_event("chunk", chunk_obj);

        var done_obj = new Json.Object();
        done_obj.set_string_member("model", "phi4");
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
        create_thread_calls++;
        return "t-created";
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

private delegate bool ConditionFunc();

private bool wait_for(ConditionFunc condition) {
    var loop = new MainLoop();
    uint timeout_id = 0;
    uint poll_id = 0;
    bool ok = false;

    poll_id = Timeout.add(10, () => {
        if (condition()) {
            ok = true;
            poll_id = 0;
            loop.quit();
            return Source.REMOVE;
        }
        return Source.CONTINUE;
    });
    timeout_id = Timeout.add(1000, () => {
        timeout_id = 0;
        loop.quit();
        return Source.REMOVE;
    });

    loop.run();
    if (timeout_id != 0) {
        Source.remove(timeout_id);
    }
    if (poll_id != 0) {
        Source.remove(poll_id);
    }
    return ok;
}

private void test_send_with_existing_thread_streams_and_completes() {
    var api = new FakeApi();
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    ctx.thread = new HolderLinux.AiThreadSummary("t1", "p1", "T", 1, 1);
    ctx.card = new HolderLinux.CardDetail("c1", "p1", "Card", "Body", 1);
    var controller = new HolderLinux.AiRunController(ctx, new FakeScheduler());

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
    assert(wait_for(() => done));
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
    var controller = new HolderLinux.AiRunController(ctx, new FakeScheduler());

    bool done = false;
    controller.status_changed.connect((text) => {
        if (text == "AI run complete") {
            done = true;
        }
    });

    controller.on_send_clicked("prompt");
    assert(wait_for(() => done));
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
    var controller = new HolderLinux.AiRunController(ctx, new FakeScheduler());

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "No project selected") {
            got_error = true;
        }
    });
    controller.on_send_clicked("prompt");
    assert(wait_for(() => got_error));
    assert(api.run_calls == 0);
}

private void test_start_model_pull_emits_status_and_toast() {
    var api = new FakeApi();
    var ctx = new FakeContext();
    ctx.api = api;
    ctx.project = new HolderLinux.Project("p1", "P", "/tmp", 1, 1);
    var controller = new HolderLinux.AiRunController(ctx, new FakeScheduler());

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
    assert(wait_for(() => saw_toast && saw_started));
    assert(api.start_pull_calls == 1);
    assert(api.last_pull_model == "phi4");
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
        "/ai_run/start_model_pull_emits_status_and_toast",
        test_start_model_pull_emits_status_and_toast
    );

    return Test.run();
}

}
