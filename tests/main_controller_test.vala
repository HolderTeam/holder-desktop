using GLib;

namespace HolderLinuxTests {

private class FakeClock : Object, HolderLinux.IClock {
    public int64 now_value = 1000;

    public int64 now_epoch_seconds() {
        return now_value;
    }
}

private class FakeScheduler : Object, HolderLinux.IScheduler {
    private class OneShotTask : Object {
        public uint id;
        public SourceFunc callback;

        public OneShotTask(uint id, owned SourceFunc callback) {
            this.id = id;
            this.callback = (owned) callback;
        }
    }

    private uint next_id = 1;
    private Gee.ArrayList<OneShotTask> one_shots = new Gee.ArrayList<OneShotTask>();

    public uint schedule_once(uint delay_ms, owned SourceFunc callback) {
        var id = next_id++;
        one_shots.add(new OneShotTask(id, (owned) callback));
        return id;
    }

    public uint schedule_repeating(uint interval_ms, owned SourceFunc callback) {
        return next_id++;
    }

    public bool cancel(uint source_id) {
        for (int i = 0; i < one_shots.size; i++) {
            if (one_shots[i].id == source_id) {
                one_shots.remove_at(i);
                return true;
            }
        }
        return false;
    }

    public void run_all_once() {
        var tasks = new Gee.ArrayList<OneShotTask>();
        foreach (var task in one_shots) {
            tasks.add(task);
        }
        one_shots.clear();
        foreach (var task in tasks) {
            task.callback();
        }
    }
}

private class StoreSelectionState : Object, HolderLinux.ISelectionState {
    private GLib.ListStore store;
    private uint selected = uint.MAX;

    public StoreSelectionState(GLib.ListStore store) {
        this.store = store;
    }

    public Object? get_selected_item() {
        if (selected == uint.MAX) {
            return null;
        }
        return store.get_item(selected);
    }

    public uint get_selected_index() {
        return selected;
    }

    public void set_selected_index(uint index) {
        selected = index;
    }
}

private class MutableTextProvider : Object, HolderLinux.ITextProvider {
    public string value = "";

    public string get_text() {
        return value;
    }
}

private class FakeApi : Object, HolderLinux.IHolderApi {
    public int list_projects_calls = 0;
    public int list_cards_calls = 0;
    public int get_card_calls = 0;
    public int search_calls = 0;
    public int update_card_calls = 0;
    public int create_card_calls = 0;
    public int create_project_calls = 0;
    public int list_threads_calls = 0;
    public string last_updated_card_id = "";
    public string last_updated_title = "";
    public string last_updated_content = "";
    public int64 last_updated_at = 0;
    public bool fail_health = false;
    public bool fail_create_card = false;
    public bool fail_create_project = false;
    public bool fail_list_threads = false;
    public bool include_card2 = false;
    public bool search_returns_card2 = false;

    public async void health_check() throws Error {
        if (fail_health) {
            throw new IOError.FAILED("health failed");
        }
    }

    public async Gee.ArrayList<HolderLinux.Project> list_projects() throws Error {
        list_projects_calls++;
        var projects = new Gee.ArrayList<HolderLinux.Project>();
        projects.add(new HolderLinux.Project("p1", "Project 1", "/tmp/p1", 10, 10));
        return projects;
    }

    public async string create_project(string name) throws Error {
        if (fail_create_project) {
            throw new IOError.FAILED("create project failed");
        }
        create_project_calls++;
        return "p-created";
    }

    public async Gee.ArrayList<HolderLinux.CardSummary> list_cards(string project_id) throws Error {
        list_cards_calls++;
        var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
        cards.add(new HolderLinux.CardSummary("c1", project_id, "Card 1", "c1.md", 20, 20));
        if (include_card2) {
            cards.add(new HolderLinux.CardSummary("c2", project_id, "Card 2", "c2.md", 21, 21));
        }
        return cards;
    }

    public async HolderLinux.CardDetail get_card(string card_id) throws Error {
        get_card_calls++;
        return new HolderLinux.CardDetail(card_id, "p1", "Card 1", "# Card 1\n\nBody", 20);
    }

    public async Gee.ArrayList<HolderLinux.SearchCardResult> search_cards(string project_id,
                                                                           string query_text,
                                                                           int limit = 30) throws Error {
        search_calls++;
        var results = new Gee.ArrayList<HolderLinux.SearchCardResult>();
        if (search_returns_card2) {
            results.add(new HolderLinux.SearchCardResult("c2", "Card 2", 21, 21, "snippet", 1.0));
        }
        return results;
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
        return "job-1";
    }

    public async Gee.ArrayList<HolderLinux.AiThreadSummary> list_ai_threads(string project_id) throws Error {
        if (fail_list_threads) {
            throw new IOError.FAILED("list threads failed");
        }
        list_threads_calls++;
        var threads = new Gee.ArrayList<HolderLinux.AiThreadSummary>();
        threads.add(new HolderLinux.AiThreadSummary("t1", project_id, "Thread 1", 30, 30));
        return threads;
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
                                    HolderLinux.AiRunEventHandler on_event) throws Error {}

    public async string create_card(string project_id,
                                    string title,
                                    string content) throws Error {
        if (fail_create_card) {
            throw new IOError.FAILED("create card failed");
        }
        create_card_calls++;
        return "c-created";
    }

    public async void update_card(string card_id,
                                  string title,
                                  string content,
                                  int64 updated_at) throws Error {
        update_card_calls++;
        last_updated_card_id = card_id;
        last_updated_title = title;
        last_updated_content = content;
        last_updated_at = updated_at;
    }
}

private class FakeApiFactory : Object, HolderLinux.IApiFactory {
    private HolderLinux.IHolderApi api;

    public FakeApiFactory(HolderLinux.IHolderApi api) {
        this.api = api;
    }

    public HolderLinux.IHolderApi create(string base_url, string auth_token) {
        return api;
    }
}

private class FakeServerDiscovery : Object, HolderLinux.IServerDiscovery {
    public HolderLinux.ServerInfo info;
    public bool should_fail = false;
    public string fail_message = "discovery failed";

    public FakeServerDiscovery() {
        info = new HolderLinux.ServerInfo(1, "127.0.0.1", 8080, 1, "0.1", "0.1", "token");
    }

    public HolderLinux.ServerInfo discover_server() throws Error {
        if (should_fail) {
            throw new IOError.FAILED(fail_message);
        }
        return info;
    }

    public string holder_info_path() {
        return "/tmp/holder.json";
    }
}

private HolderLinux.MainController make_controller(FakeApi api,
                                                   FakeScheduler scheduler,
                                                   FakeClock clock,
                                                   MutableTextProvider search_text,
                                                   MutableTextProvider editor_text,
                                                   FakeServerDiscovery? discovery = null,
                                                   HolderLinux.IHolderApi? initial_api = null) {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));
    var search_store = new GLib.ListStore(typeof(HolderLinux.SearchCardResult));

    var controller = new HolderLinux.MainController(
        project_store,
        new StoreSelectionState(project_store),
        card_store,
        new StoreSelectionState(card_store),
        thread_store,
        new StoreSelectionState(thread_store),
        search_store,
        new StoreSelectionState(search_store),
        search_text,
        editor_text,
        new FakeApiFactory(api),
        discovery ?? new FakeServerDiscovery(),
        clock,
        scheduler,
        initial_api ?? api
    );
    return controller;
}

private bool wait_for(owned SourceFunc condition) {
    var loop = new MainLoop();
    bool ok = false;
    uint poll_id = 0;
    uint timeout_id = 0;

    poll_id = Timeout.add(10, () => {
        if (condition()) {
            ok = true;
            poll_id = 0;
            loop.quit();
            return Source.REMOVE;
        }
        return Source.CONTINUE;
    });
    timeout_id = Timeout.add(1500, () => {
        timeout_id = 0;
        loop.quit();
        return Source.REMOVE;
    });

    loop.run();
    if (poll_id != 0) {
        Source.remove(poll_id);
    }
    if (timeout_id != 0) {
        Source.remove(timeout_id);
    }
    return ok;
}

private void test_reload_everything_loads_project_and_card() {
    var api = new FakeApi();
    var scheduler = new FakeScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();

    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();

    assert(wait_for(() => controller.get_current_card() != null));
    assert(controller.get_current_project() != null);
    assert(controller.get_current_project().project_id == "p1");
    assert(controller.get_current_card().card_id == "c1");
    assert(api.list_projects_calls >= 1);
    assert(api.list_cards_calls >= 1);
    assert(api.get_card_calls >= 1);
}

private void test_search_debounce_runs_once() {
    var api = new FakeApi();
    var scheduler = new FakeScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();

    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for(() => controller.get_current_project() != null));

    search_text.value = "hello";
    controller.schedule_search();
    controller.schedule_search();
    scheduler.run_all_once();

    assert(wait_for(() => api.search_calls == 1));
    assert(api.search_calls == 1);
}

private void test_autosave_debounce_runs_once() {
    var api = new FakeApi();
    var scheduler = new FakeScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();

    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for(() => controller.get_current_card() != null));

    editor_text.value = "# Updated Title\n\nNew body";
    clock.now_value = 4242;

    controller.schedule_autosave();
    controller.schedule_autosave();
    scheduler.run_all_once();

    assert(wait_for(() => api.update_card_calls == 1));
    assert(api.update_card_calls == 1);
    assert(api.last_updated_card_id == "c1");
    assert(api.last_updated_title == "Updated Title");
    assert(api.last_updated_content == "# Updated Title\n\nNew body");
    assert(api.last_updated_at == 4242);
}

private void test_bootstrap_discovery_failure_updates_editor_state() {
    var api = new FakeApi();
    var scheduler = new FakeScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var discovery = new FakeServerDiscovery();
    discovery.should_fail = true;
    discovery.fail_message = "no holder running";

    var controller = make_controller(api, scheduler, clock, search_text, editor_text, discovery, null);
    bool saw_status = false;
    bool saw_not_found = false;
    controller.status_changed.connect((text) => {
        if (text.contains("no holder running")) {
            saw_status = true;
        }
    });
    controller.editor_state_changed.connect((text, editable) => {
        if (text.contains("Holder Not Found")) {
            saw_not_found = true;
        }
    });

    controller.bootstrap.begin();
    assert(wait_for(() => saw_status && saw_not_found));
}

private void test_bootstrap_health_failure_emits_error() {
    var api = new FakeApi();
    api.fail_health = true;
    var scheduler = new FakeScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();

    var controller = make_controller(api, scheduler, clock, search_text, editor_text, null, null);
    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Health check failed") {
            got_error = true;
        }
    });

    controller.bootstrap.begin();
    assert(wait_for(() => got_error));
}

private void test_create_card_error_emits_error() {
    var api = new FakeApi();
    api.fail_create_card = true;
    var scheduler = new FakeScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for(() => controller.get_current_project() != null));

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to create card") {
            got_error = true;
        }
    });
    controller.create_card.begin();
    assert(wait_for(() => got_error));
}

private void test_create_project_error_emits_error() {
    var api = new FakeApi();
    api.fail_create_project = true;
    var scheduler = new FakeScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to create project") {
            got_error = true;
        }
    });
    controller.create_project_named.begin("X");
    assert(wait_for(() => got_error));
}

private void test_reload_ai_threads_error_emits_error() {
    var api = new FakeApi();
    api.fail_list_threads = true;
    var scheduler = new FakeScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to load AI threads") {
            got_error = true;
        }
    });
    controller.reload_ai_threads_for_project.begin("p1");
    assert(wait_for(() => got_error));
}

private void test_open_search_result_existing_card_skips_reload() {
    var api = new FakeApi();
    api.include_card2 = true;
    api.search_returns_card2 = true;
    var scheduler = new FakeScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for(() => controller.get_current_project() != null));

    search_text.value = "card2";
    controller.run_search.begin();
    assert(wait_for(() => api.search_calls == 1));
    var list_cards_before = api.list_cards_calls;
    controller.open_search_result_at.begin(0);
    assert(wait_for(() => api.get_card_calls >= 2));
    assert(api.list_cards_calls == list_cards_before);
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func(
        "/main_controller/reload_everything_loads_project_and_card",
        test_reload_everything_loads_project_and_card
    );
    Test.add_func(
        "/main_controller/search_debounce_runs_once",
        test_search_debounce_runs_once
    );
    Test.add_func(
        "/main_controller/autosave_debounce_runs_once",
        test_autosave_debounce_runs_once
    );
    Test.add_func(
        "/main_controller/bootstrap_discovery_failure_updates_editor_state",
        test_bootstrap_discovery_failure_updates_editor_state
    );
    Test.add_func(
        "/main_controller/bootstrap_health_failure_emits_error",
        test_bootstrap_health_failure_emits_error
    );
    Test.add_func(
        "/main_controller/create_card_error_emits_error",
        test_create_card_error_emits_error
    );
    Test.add_func(
        "/main_controller/create_project_error_emits_error",
        test_create_project_error_emits_error
    );
    Test.add_func(
        "/main_controller/reload_ai_threads_error_emits_error",
        test_reload_ai_threads_error_emits_error
    );
    Test.add_func(
        "/main_controller/open_search_result_existing_card_skips_reload",
        test_open_search_result_existing_card_skips_reload
    );

    return Test.run();
}

}
