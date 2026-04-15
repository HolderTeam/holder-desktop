using GLib;

namespace HolderLinuxTests {

private class RecordingExplorerStateSink : Object, HolderLinux.IExplorerStateSink {
    public int replace_projects_calls = 0;
    public int replace_cards_calls = 0;
    public int replace_ai_threads_calls = 0;
    public Gee.ArrayList<HolderLinux.Project> last_projects = new Gee.ArrayList<HolderLinux.Project>();
    public Gee.ArrayList<HolderLinux.CardSummary> last_cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    public Gee.ArrayList<HolderLinux.AiThreadSummary> last_ai_threads = new Gee.ArrayList<HolderLinux.AiThreadSummary>();

    public void replace_projects_snapshot(Gee.ArrayList<HolderLinux.Project> projects) {
        replace_projects_calls++;
        last_projects = projects;
    }

    public void replace_cards_snapshot(Gee.ArrayList<HolderLinux.CardSummary> cards) {
        replace_cards_calls++;
        last_cards = cards;
    }

    public void replace_ai_threads_snapshot(Gee.ArrayList<HolderLinux.AiThreadSummary> ai_threads) {
        replace_ai_threads_calls++;
        last_ai_threads = ai_threads;
    }
}

private MainControllerTestHarness make_harness(MainControllerFakeApi api,
                                               TestScheduler scheduler,
                                               FakeClock clock,
                                               FakeServerDiscovery? discovery = null,
                                               HolderLinux.IHolderApi? initial_api = null,
                                               bool inject_initial_api = true,
                                               HolderLinux.IExplorerStateSink? explorer_state_sink = null) {
    return new MainControllerTestHarness(
        api,
        scheduler,
        clock,
        discovery,
        initial_api,
        inject_initial_api,
        null,
        explorer_state_sink
    );
}

private void load_selected_card_from_store(HolderLinux.MainController controller,
                                           StoreSelectionState selection,
                                           GLib.ListStore card_store) {
    var index = selection.get_selected_index();
    if (index == uint.MAX || index >= card_store.get_n_items()) {
        return;
    }
    var selected = card_store.get_item(index) as HolderLinux.CardSummary;
    if (selected == null) {
        return;
    }
    controller.load_card_by_id.begin(selected.card_id);
}

private void test_store_sync_updates_snapshots_and_false_lookups() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var sink = new RecordingExplorerStateSink();
    var harness = make_harness(api, scheduler, clock, null, null, true, sink);
    var sync = new HolderLinux.StoreSyncController(harness.controller);

    var projects = new Gee.ArrayList<HolderLinux.Project>();
    projects.add(new HolderLinux.Project("p2", "Project 2", "plain", "/tmp/p2", 2, 3));
    projects.add(new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 1, 2));
    sync.replace_projects(projects);
    assert(harness.project_store.get_n_items() == 2);
    assert(sink.replace_projects_calls == 1);
    assert(!sync.has_project_summary("missing"));

    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    cards.add(new HolderLinux.CardSummary("c2", "p1", "Zulu", "c2.md", 2.0, null, 1, 10));
    cards.add(new HolderLinux.CardSummary("c1", "p1", "Alpha", "c1.md", 1.0, null, 1, 20));
    sync.replace_cards(cards);
    assert(harness.card_store.get_n_items() == 2);
    assert(sink.replace_cards_calls == 1);
    assert(!sync.has_card_summary("missing"));

    var threads = new Gee.ArrayList<HolderLinux.AiThreadSummary>();
    threads.add(new HolderLinux.AiThreadSummary("t1", "p1", "Thread 1", 1, 2));
    sync.replace_ai_threads(threads);
    assert(harness.thread_store.get_n_items() == 1);
    assert(sink.replace_ai_threads_calls == 1);

    harness.controller.current_card = new HolderLinux.CardDetail("c1", "p1", "Card 1", "# Card 1", 20);
    sync.update_selected_card_summary("Renamed", 42);
    var updated = harness.card_store.get_item(0) as HolderLinux.CardSummary;
    assert(updated != null && updated.title == "Renamed");
    assert(sink.replace_cards_calls == 2);

    harness.controller.current_ai_thread = new HolderLinux.AiThreadSummary("t1", "p1", "Thread 1", 1, 2);
    bool saw_null_thread_title = false;
    harness.controller.ai_thread_title_changed.connect((title) => {
        if (title == null) {
            saw_null_thread_title = true;
        }
    });
    sync.clear_cards();
    assert(harness.card_store.get_n_items() == 0);
    assert(harness.thread_store.get_n_items() == 0);
    assert(saw_null_thread_title);
    assert(sink.replace_cards_calls == 3);
    assert(sink.replace_ai_threads_calls == 2);
}

private void test_backend_session_connect_from_discovery_emits_ready() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var discovery = new FakeServerDiscovery();
    var harness = make_harness(api, scheduler, clock, discovery, null, false);
    var session = new HolderLinux.BackendSessionController(harness.controller);

    bool ready = false;
    HolderLinux.IHolderApi? ready_api = null;
    harness.controller.api_client_ready.connect((connected_api) => {
        ready = true;
        ready_api = connected_api;
    });

    session.connect_from_discovery.begin();
    assert(wait_for_condition(() => ready));
    assert(api.factory_create_calls == 1);
    assert(ready_api == api);
    assert(session.get_active_server_info() != null);
}

private void test_backend_session_reconnect_paths() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock, null, null, false);
    var session = new HolderLinux.BackendSessionController(harness.controller);

    bool non_transport_done = false;
    bool non_transport_result = true;
    session.try_reconnect_after_transport_error.begin(new IOError.FAILED("bad parse"), (obj, res) => {
        non_transport_result = session.try_reconnect_after_transport_error.end(res);
        non_transport_done = true;
    });
    assert(wait_for_condition(() => non_transport_done));
    assert(!non_transport_result);

    bool first_done = false;
    bool second_done = false;
    bool first_result = false;
    bool second_result = true;
    int refresh_calls = 0;
    string last_status = "";
    harness.controller.ai_status_refresh_requested.connect(() => {
        refresh_calls++;
    });
    harness.controller.status_changed.connect((text) => {
        last_status = text;
    });
    api.health_before_complete_hook = () => {
        api.health_before_complete_hook = null;
        session.try_reconnect_after_transport_error.begin(new IOError.FAILED("connection reset"), (obj, res) => {
            second_result = session.try_reconnect_after_transport_error.end(res);
            second_done = true;
        });
    };
    session.try_reconnect_after_transport_error.begin(new IOError.FAILED("connection reset"), (obj, res) => {
        first_result = session.try_reconnect_after_transport_error.end(res);
        first_done = true;
    });
    assert(wait_for_condition(() => first_done && second_done));
    assert(first_result);
    assert(!second_result);
    assert(refresh_calls == 1);
    assert(last_status.contains("Reconnected to"));

    api.health_check_sequence.add("health still bad");
    bool health_failure_done = false;
    bool health_failure_result = true;
    Test.expect_message(null, LogLevelFlags.LEVEL_WARNING, "*Reconnect health-check failed*");
    session.try_reconnect_after_transport_error.begin(new IOError.FAILED("connection dropped"), (obj, res) => {
        health_failure_result = session.try_reconnect_after_transport_error.end(res);
        health_failure_done = true;
    });
    assert(wait_for_condition(() => health_failure_done));
    Test.assert_expected_messages();
    assert(!health_failure_result);

    var failing_discovery = new FakeServerDiscovery();
    failing_discovery.should_fail = true;
    failing_discovery.fail_message = "discovery broke";
    var harness2 = make_harness(api, scheduler, clock, failing_discovery, null, false);
    var session2 = new HolderLinux.BackendSessionController(harness2.controller);
    bool discovery_failure_done = false;
    bool discovery_failure_result = true;
    Test.expect_message(null, LogLevelFlags.LEVEL_WARNING, "*Reconnect failed*");
    session2.try_reconnect_after_transport_error.begin(new IOError.FAILED("connection lost"), (obj, res) => {
        discovery_failure_result = session2.try_reconnect_after_transport_error.end(res);
        discovery_failure_done = true;
    });
    assert(wait_for_condition(() => discovery_failure_done));
    Test.assert_expected_messages();
    assert(!discovery_failure_result);
}

private void test_main_bootstrap_retry_second_health_failure_reports_retry_error() {
    var api = new MainControllerFakeApi();
    api.health_check_sequence.add("connection refused");
    api.health_check_sequence.add(null);
    api.health_check_sequence.add("retry still failed");
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock, null, null, false);
    var bootstrap = new HolderLinux.MainBootstrapController(harness.controller);

    string error_title = "";
    string error_details = "";
    string last_status = "";
    string last_editor = "";
    harness.controller.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });
    harness.controller.status_changed.connect((text) => {
        last_status = text;
    });
    harness.controller.editor_state_changed.connect((text, editable) => {
        last_editor = text;
    });

    bootstrap.bootstrap.begin();
    assert(wait_for_condition(() => error_details == "retry still failed"));
    assert(error_title == "Health check failed");
    assert(last_status == "Health check failed");
    assert(last_editor.contains("retry still failed"));

}

private void test_main_project_flow_retry_fallback_and_loading_status() {
    var api = new MainControllerFakeApi();
    api.include_card2 = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var flow = new HolderLinux.MainProjectFlowController(harness.controller);

    string? selected_card_id = null;
    string last_status = "";
    harness.controller.card_selection_requested.connect((card_id) => {
        selected_card_id = card_id;
    });
    harness.controller.status_changed.connect((text) => {
        last_status = text;
    });

    bool fallback_done = false;
    flow.reload_everything_with_selection.begin("p1", "missing", true, (obj, res) => {
        flow.reload_everything_with_selection.end(res);
        fallback_done = true;
    });
    assert(wait_for_condition(() => fallback_done));
    var selected_card = harness.card_selection.get_selected_item() as HolderLinux.CardSummary;
    assert(selected_card != null && selected_card.card_id == "c2");

    api.fail_list_projects_once = true;
    api.list_projects_failure_message = "connection reset";
    selected_card_id = null;
    int list_projects_before_retry = api.list_projects_calls;
    bool project_retry_done = false;
    flow.reload_everything_with_selection.begin("p1", "missing", true, (obj, res) => {
        flow.reload_everything_with_selection.end(res);
        project_retry_done = true;
    });
    assert(wait_for_condition(() => project_retry_done));
    assert(api.list_projects_calls > list_projects_before_retry);
    assert(api.factory_create_calls >= 1);

    harness.project_selection.set_selected_index(0);
    api.list_cards_before_complete_hook = (project_id) => {
        api.list_cards_before_complete_hook = null;
        scheduler.run_all_once();
    };
    bool loading_done = false;
    flow.reload_selected_project_cards_data.begin(true, (obj, res) => {
        flow.reload_selected_project_cards_data.end(res);
        loading_done = true;
    });
    assert(wait_for_condition(() => loading_done));
    assert(last_status == "Loading cards for Project 1...");

    api.fail_list_cards_once = true;
    api.list_cards_failure_message = "connection dropped";
    bool retry_done = false;
    bool retry_result = false;
    flow.reload_selected_project_cards_data.begin(true, (obj, res) => {
        retry_result = flow.reload_selected_project_cards_data.end(res);
        retry_done = true;
    });
    assert(wait_for_condition(() => retry_done));
    assert(retry_result);
}

private void test_main_card_load_status_cancel_and_retry() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var card_load = new HolderLinux.MainCardLoadController(harness.controller);

    harness.controller.reload_everything.begin();
    assert(wait_for_condition(() => harness.card_store.get_n_items() > 0));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(harness.controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => harness.controller.get_current_card() != null));
    harness.controller.current_card = null;

    string last_status = "";
    harness.controller.status_changed.connect((text) => {
        last_status = text;
    });

    api.slow_get_card = true;
    card_load.load_card_by_id.begin("c1");
    card_load.load_card_by_id.begin("c1");
    scheduler.run_all_once();
    assert(wait_for_condition(() => api.get_card_calls >= 2));
    assert(scheduler.cancel_calls > 0);
    assert(last_status == "Loading card..." || last_status.contains("Loaded "));

    api.slow_get_card = false;
    api.fail_get_card_once = true;
    api.get_card_failure_message = "connection refused";
    bool retry_done = false;
    card_load.load_card_by_id.begin("c1", true, (obj, res) => {
        card_load.load_card_by_id.end(res);
        retry_done = true;
    });
    assert(wait_for_condition(() => retry_done));
    assert(harness.controller.get_current_card() != null);
    assert(api.get_card_calls >= 4);
}

private void test_main_overview_stale_and_selection_change_paths() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var overview = new HolderLinux.MainOverviewController(harness.controller);

    harness.controller.reload_everything.begin();
    assert(wait_for_condition(() => harness.project_store.get_n_items() > 0));
    harness.project_selection.set_selected_index(0);

    int loaded_count = 0;
    harness.controller.status_changed.connect((text) => {
        if (text == "Loaded project overview") {
            loaded_count++;
        }
    });

    api.list_resources_before_complete_hook = (project_id) => {
        api.list_resources_before_complete_hook = null;
        overview.show_project_overview.begin();
    };
    overview.show_project_overview.begin();
    assert(wait_for_condition(() => loaded_count >= 1));

    api.fail_list_resources = true;
    api.list_resources_failure_message = "resources failed";
    api.list_resources_before_complete_hook = (project_id) => {
        api.list_resources_before_complete_hook = null;
        api.fail_list_resources = false;
        overview.show_project_overview.begin();
    };
    overview.show_project_overview.begin();
    assert(wait_for_condition(() => loaded_count >= 2));

    string prior_editor = harness.editor_text.value;
    api.list_resources_before_complete_hook = (project_id) => {
        api.list_resources_before_complete_hook = null;
        harness.project_selection.set_selected_index(uint.MAX);
    };
    bool selection_change_done = false;
    overview.show_project_overview.begin((obj, res) => {
        overview.show_project_overview.end(res);
        selection_change_done = true;
    });
    assert(wait_for_condition(() => selection_change_done));
    assert(harness.editor_text.value == prior_editor);
}

public static int main(string[] args) {
    Test.init(ref args);
    Log.set_always_fatal(LogLevelFlags.LEVEL_ERROR);

    Test.add_func(
        "/main_extracted_controllers/store_sync_updates_snapshots_and_false_lookups",
        test_store_sync_updates_snapshots_and_false_lookups
    );
    Test.add_func(
        "/main_extracted_controllers/backend_session_connect_from_discovery_emits_ready",
        test_backend_session_connect_from_discovery_emits_ready
    );
    Test.add_func(
        "/main_extracted_controllers/backend_session_reconnect_paths",
        test_backend_session_reconnect_paths
    );
    Test.add_func(
        "/main_extracted_controllers/main_bootstrap_retry_second_health_failure_reports_retry_error",
        test_main_bootstrap_retry_second_health_failure_reports_retry_error
    );
    Test.add_func(
        "/main_extracted_controllers/main_project_flow_retry_fallback_and_loading_status",
        test_main_project_flow_retry_fallback_and_loading_status
    );
    Test.add_func(
        "/main_extracted_controllers/main_card_load_status_cancel_and_retry",
        test_main_card_load_status_cancel_and_retry
    );
    Test.add_func(
        "/main_extracted_controllers/main_overview_stale_and_selection_change_paths",
        test_main_overview_stale_and_selection_change_paths
    );

    return Test.run();
}

}
