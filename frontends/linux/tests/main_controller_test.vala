using GLib;

namespace HolderLinuxTests {

private HolderLinux.MainController make_controller(MainControllerFakeApi api,
                                                   TestScheduler scheduler,
                                                   FakeClock clock,
                                                   MutableTextProvider search_text,
                                                   MutableTextProvider editor_text,
                                                   FakeServerDiscovery? discovery = null,
                                                   HolderLinux.IHolderApi? initial_api = null,
                                                   bool inject_initial_api = true) {
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
        new MainControllerFakeApiFactory(api, api),
        discovery ?? new FakeServerDiscovery(),
        clock,
        scheduler,
        inject_initial_api ? (initial_api ?? api) : null
    );
    return controller;
}

private MainControllerTestHarness make_harness(MainControllerFakeApi api,
                                 TestScheduler scheduler,
                                 FakeClock clock,
                                 FakeServerDiscovery? discovery = null,
                                 HolderLinux.IHolderApi? initial_api = null,
                                 bool inject_initial_api = true) {
    return new MainControllerTestHarness(api, scheduler, clock, discovery, initial_api, inject_initial_api);
}

private void test_reload_everything_loads_project_and_card() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();

    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    bool saw_overview = false;
    controller.editor_state_changed.connect((text, editable) => {
        if (text.contains("## Overview")) {
            saw_overview = true;
        }
    });

    controller.reload_everything.begin();

    assert(wait_for_condition(() => saw_overview));
    assert(controller.get_current_project() != null);
    assert(controller.get_current_project().project_id == "p1");
    assert(controller.get_current_card() == null);
    assert(controller.selected_card_id() == null);
    assert(api.list_projects_calls >= 1);
    assert(api.list_cards_calls >= 1);
    assert(api.get_card_calls == 0);
}

private void test_search_debounce_runs_once() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();

    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    search_text.value = "hello";
    controller.schedule_search();
    controller.schedule_search();
    scheduler.run_all_once();

    assert(wait_for_condition(() => api.search_calls == 1));
    assert(api.search_calls == 1);
}

private void test_autosave_debounce_runs_once() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    assert(controller.selected_card_id() == null);
    harness.card_selection.set_selected_index(0);
    controller.on_card_selected();
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Updated Title\n\nNew body";
    clock.now_value = 4242;

    controller.schedule_autosave();
    controller.schedule_autosave();
    scheduler.run_all_once();

    assert(wait_for_condition(() => api.update_card_calls == 1));
    assert(api.update_card_calls == 1);
    assert(api.last_updated_card_id == "c1");
    assert(api.last_updated_title == "Updated Title");
    assert(api.last_updated_content == "# Updated Title\n\nNew body");
    assert(api.last_updated_at == 4242);
}

private void test_bootstrap_discovery_failure_updates_editor_state() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
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
    assert(wait_for_condition(() => saw_status && saw_not_found));
}

private void test_bootstrap_health_failure_emits_error() {
    var api = new MainControllerFakeApi();
    api.fail_health = true;
    var scheduler = new TestScheduler();
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
    assert(wait_for_condition(() => got_error));
}

private void test_create_card_error_emits_error() {
    var api = new MainControllerFakeApi();
    api.fail_create_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to create card") {
            got_error = true;
        }
    });
    controller.create_card.begin();
    assert(wait_for_condition(() => got_error));
}

private void test_create_project_error_emits_error() {
    var api = new MainControllerFakeApi();
    api.fail_create_project = true;
    var scheduler = new TestScheduler();
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
    assert(wait_for_condition(() => got_error));
}

private void test_create_project_with_no_api_is_noop() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text, null, null, false);

    controller.create_project_named.begin("X");
    assert(wait_for_condition(() => true));
    assert(api.create_project_calls == 0);
}

private void test_create_card_success_selects_created_card() {
    var api = new MainControllerFakeApi();
    api.include_created_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool saw_toast = false;
    controller.toast_requested.connect((message) => {
        if (message == "New card created") {
            saw_toast = true;
        }
    });

    controller.create_card.begin();
    assert(wait_for_condition(() => saw_toast));
    assert(api.create_card_calls == 1);
    assert(controller.selected_card_id() == "c-created");
}

private void test_create_card_in_flight_guard() {
    var api = new MainControllerFakeApi();
    api.include_created_card = true;
    api.slow_create_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool saw_in_flight = false;
    controller.status_changed.connect((text) => {
        if (text == "Create card already in progress...") {
            saw_in_flight = true;
        }
    });

    controller.create_card.begin();
    controller.create_card.begin();
    assert(wait_for_condition(() => saw_in_flight));
}

private void test_create_card_without_project_emits_error() {
    var api = new MainControllerFakeApi();
    api.list_projects_empty = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "No project selected") {
            got_error = true;
        }
    });

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() == null));
    controller.create_card.begin();
    assert(wait_for_condition(() => got_error));
}

private void test_create_card_with_title_success_trims_and_sets_content() {
    var api = new MainControllerFakeApi();
    api.include_created_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool saw_toast = false;
    controller.toast_requested.connect((message) => {
        if (message == "Created card: My Title") {
            saw_toast = true;
        }
    });

    controller.create_card_with_title.begin("  My Title  ");
    assert(wait_for_condition(() => saw_toast));

    assert(api.create_card_calls == 1);
    assert(api.last_created_project_id == "p1");
    assert(api.last_created_title == "My Title");
    assert(api.last_created_content == "# My Title\n\n");
    assert(api.last_created_parent_card_id == null);
}

private void test_create_card_with_title_empty_emits_error_and_skips_create() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Card title required") {
            got_error = true;
        }
    });

    controller.create_card_with_title.begin("   ");
    assert(wait_for_condition(() => got_error));
    assert(api.create_card_calls == 0);
}

private void test_reload_ai_threads_error_emits_error() {
    var api = new MainControllerFakeApi();
    api.fail_list_threads = true;
    var scheduler = new TestScheduler();
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
    assert(wait_for_condition(() => got_error));
}

private void test_open_search_result_existing_card_skips_reload() {
    var api = new MainControllerFakeApi();
    api.include_card2 = true;
    api.search_returns_card2 = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    search_text.value = "card2";
    controller.run_search.begin();
    assert(wait_for_condition(() => api.search_calls == 1));
    var list_cards_before = api.list_cards_calls;
    controller.open_search_result_at.begin(0);
    assert(wait_for_condition(() => controller.get_current_card() != null &&
                          controller.get_current_card().card_id == "c2"));
    assert(api.get_card_calls >= 1);
    assert(api.list_cards_calls == list_cards_before);
}

private void test_open_search_result_missing_card_triggers_reload() {
    var api = new MainControllerFakeApi();
    api.include_card2 = false;
    api.search_returns_card2 = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    search_text.value = "card2";
    controller.run_search.begin();
    assert(wait_for_condition(() => api.search_calls == 1));

    var before_reload = api.list_cards_calls;
    api.include_card2 = true;
    controller.open_search_result_at.begin(0);
    assert(wait_for_condition(() => api.list_cards_calls > before_reload));
    assert(wait_for_condition(() => controller.get_current_card() != null &&
                          controller.get_current_card().card_id == "c2"));
}

private void test_run_search_without_project_emits_error() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Search unavailable") {
            got_error = true;
        }
    });

    search_text.value = "anything";
    controller.run_search.begin();
    assert(wait_for_condition(() => got_error));
}

private void test_run_search_empty_query_shows_editor() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool show_editor = false;
    controller.show_editor_requested.connect(() => {
        show_editor = true;
    });
    search_text.value = "   ";
    controller.run_search.begin();
    assert(wait_for_condition(() => show_editor));
}

private void test_run_search_success_emits_summary_and_show_search() {
    var api = new MainControllerFakeApi();
    api.search_returns_card2 = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool show_search = false;
    bool saw_summary = false;
    controller.show_search_requested.connect(() => {
        show_search = true;
    });
    controller.search_summary_changed.connect((text) => {
        if (text.contains("1 result(s)")) {
            saw_summary = true;
        }
    });

    search_text.value = "card2";
    controller.run_search.begin();
    assert(wait_for_condition(() => show_search && saw_summary));
    assert(api.search_calls == 1);
}

private void test_run_search_failure_emits_error() {
    var api = new MainControllerFakeApi();
    api.fail_search = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Search failed") {
            got_error = true;
        }
    });

    search_text.value = "boom";
    controller.run_search.begin();
    assert(wait_for_condition(() => got_error));
}

private void test_run_search_with_no_api_is_noop() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text, null, null, false);
    search_text.value = "hello";

    controller.run_search.begin();
    assert(wait_for_condition(() => true));
    assert(api.search_calls == 0);
}

private void test_selected_ids_and_api_getter() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    assert(controller.get_api_client() == api);
    assert(controller.selected_project_id() == null);
    assert(controller.selected_card_id() == null);

    harness.project_store.append(new HolderLinux.Project("p1", "P1", "encrypted_git", "/tmp", 1, 1));
    harness.card_store.append(new HolderLinux.CardSummary("c1", "p1", "C1", "c1.md", 1024.0, null, 1, 1));
    harness.project_selection.set_selected_index(0);
    harness.card_selection.set_selected_index(0);

    assert(controller.selected_project_id() == "p1");
    assert(controller.selected_card_id() == "c1");
}

private void test_reload_everything_with_no_api_is_noop() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock, null, null, false);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => true));
    assert(controller.get_current_project() == null);
    assert(api.list_projects_calls == 0);
}

private void test_reload_everything_with_no_projects_sets_empty_state() {
    var api = new MainControllerFakeApi();
    api.list_projects_empty = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);

    bool saw_no_projects = false;
    controller.editor_state_changed.connect((text, editable) => {
        if (text.contains("No Projects")) {
            saw_no_projects = true;
        }
    });
    controller.reload_everything.begin();
    assert(wait_for_condition(() => saw_no_projects));
    assert(controller.get_current_project() == null);
}

private void test_show_project_overview_without_selection_sets_no_project_state() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    bool saw_no_project = false;
    bool show_editor = false;
    controller.editor_state_changed.connect((text, editable) => {
        if (text.contains("No Project Selected")) {
            saw_no_project = true;
            assert(!editable);
        }
    });
    controller.show_editor_requested.connect(() => {
        show_editor = true;
    });

    harness.project_selection.set_selected_index(uint.MAX);
    controller.show_project_overview.begin();
    assert(wait_for_condition(() => saw_no_project));
    assert(!show_editor);
    assert(controller.get_current_project() == null);
    assert(controller.get_current_card() == null);
}

private void test_show_project_overview_resource_failure_sets_unknown() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool saw_unknown_resources = false;
    controller.editor_state_changed.connect((text, editable) => {
        if (text.contains("## Overview") && text.contains("- Resources: unknown")) {
            saw_unknown_resources = true;
        }
    });

    api.fail_list_resources = true;
    controller.show_project_overview.begin();
    assert(wait_for_condition(() => saw_unknown_resources));
}

private void test_reload_everything_with_no_cards_sets_empty_state() {
    var api = new MainControllerFakeApi();
    api.list_cards_empty = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);

    bool saw_overview = false;
    controller.editor_state_changed.connect((text, editable) => {
        if (text.contains("## Overview") && text.contains("- Cards: 0")) {
            saw_overview = true;
        }
    });
    controller.reload_everything.begin();
    assert(wait_for_condition(() => saw_overview));
    assert(controller.get_current_card() == null);
}

private void test_reload_everything_list_projects_failure_emits_error() {
    var api = new MainControllerFakeApi();
    api.fail_list_projects = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to refresh") {
            got_error = true;
        }
    });
    controller.reload_everything.begin();
    assert(wait_for_condition(() => got_error));
}

private void test_reload_everything_uses_preferred_project_selection() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    harness.project_store.append(new HolderLinux.Project("p1", "Old P1", "encrypted_git", "/tmp", 1, 1));
    harness.project_selection.set_selected_index(0);
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    assert(controller.selected_project_id() == "p1");
}

private void test_ignore_flags_public_accessors_default_false() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    assert(!controller.should_ignore_project_selection_events());
    assert(!controller.should_ignore_card_selection_events());
}

private void test_reload_cards_error_emits_error() {
    var api = new MainControllerFakeApi();
    api.fail_list_cards = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to load cards") {
            got_error = true;
        }
    });
    controller.reload_everything.begin();
    assert(wait_for_condition(() => got_error));
}

private void test_cancel_pending_search_prevents_scheduled_run() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    search_text.value = "x";
    controller.schedule_search();
    controller.cancel_pending_search();
    scheduler.run_all_once();
    assert(api.search_calls == 0);

    controller.cancel_pending_search();
    assert(api.search_calls == 0);
}

private void test_reload_ai_threads_empty_emits_null_title() {
    var api = new MainControllerFakeApi();
    api.list_threads_empty = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);

    bool saw_null_title = false;
    controller.ai_thread_title_changed.connect((title) => {
        if (title == null) {
            saw_null_title = true;
        }
    });

    controller.reload_ai_threads_for_project.begin("p1");
    assert(wait_for_condition(() => saw_null_title));
}

private void test_select_ai_thread_by_unknown_id_returns_false() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);

    controller.reload_ai_threads_for_project.begin("p1");
    assert(wait_for_condition(() => api.list_threads_calls > 0));
    assert(!controller.select_ai_thread_by_id("does-not-exist"));
}

private void test_on_ai_thread_selected_with_no_selection_emits_null_title() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);

    bool saw_null = false;
    controller.ai_thread_title_changed.connect((title) => {
        if (title == null) {
            saw_null = true;
        }
    });
    controller.on_ai_thread_selected();
    assert(wait_for_condition(() => saw_null));
    assert(controller.get_current_ai_thread() == null);
}

private void test_on_project_selected_without_selection_noop() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.on_project_selected();
    assert(wait_for_condition(() => true));
    assert(controller.get_current_project() == null);
}

private void test_on_card_selected_without_selection_sets_empty_state() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    bool saw_no_selection = false;
    controller.editor_state_changed.connect((text, editable) => {
        if (text.contains("No Card Selected")) {
            saw_no_selection = true;
        }
    });

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(uint.MAX);
    controller.on_card_selected();
    assert(wait_for_condition(() => saw_no_selection));
}

private void test_on_ai_thread_selected_emits_title_and_sets_current_thread() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);

    bool got_title = false;
    controller.ai_thread_title_changed.connect((title) => {
        if (title == "Thread 1") {
            got_title = true;
        }
    });

    controller.reload_ai_threads_for_project.begin("p1");
    assert(wait_for_condition(() => api.list_threads_calls > 0));
    controller.on_ai_thread_selected();
    assert(wait_for_condition(() => got_title));
    assert(controller.get_current_ai_thread() != null);
    assert(controller.get_current_ai_thread().thread_id == "t1");
}

private void test_select_ai_thread_by_id_true_path() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_ai_threads_for_project.begin("p1");
    assert(wait_for_condition(() => api.list_threads_calls > 0));
    assert(controller.select_ai_thread_by_id("t1"));
}

private void test_open_search_result_with_empty_store_is_noop() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    var card_calls_before = api.get_card_calls;

    controller.open_search_result_at.begin(0);
    assert(wait_for_condition(() => true));
    assert(api.get_card_calls == card_calls_before);
}

private void test_load_selected_card_failure_emits_error() {
    var api = new MainControllerFakeApi();
    api.fail_get_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to load card") {
            got_error = true;
        }
    });
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    controller.on_card_selected();
    assert(wait_for_condition(() => got_error));
}

private void test_autosave_failure_emits_error() {
    var api = new MainControllerFakeApi();
    api.fail_update_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    controller.on_card_selected();
    assert(wait_for_condition(() => controller.get_current_card() != null));

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Autosave failed") {
            got_error = true;
        }
    });
    harness.editor_text.value = "# New title";
    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => got_error));
}

private void test_autosave_without_card_is_noop() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);

    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => true));
    assert(api.update_card_calls == 0);
}

private void test_create_ai_thread_success() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool done = false;
    bool ok = false;
    controller.create_ai_thread.begin("Thread", (obj, res) => {
        try {
            var id = controller.create_ai_thread.end(res);
            ok = (id == "t-created");
        } catch (Error e) {
            ok = false;
        }
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(ok);
}

private void test_create_ai_thread_without_context_throws() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text, null, null, false);

    bool done = false;
    bool got_error = false;
    controller.create_ai_thread.begin("Thread", (obj, res) => {
        try {
            controller.create_ai_thread.end(res);
        } catch (Error e) {
            got_error = true;
        }
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(got_error);
}

private void test_create_project_success_reloads_and_toasts() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    bool saw_toast = false;
    bool saw_created = false;
    controller.toast_requested.connect((message) => {
        if (message == "Created project: New") {
            saw_toast = true;
        }
    });
    controller.status_changed.connect((text) => {
        if (text == "Project created") {
            saw_created = true;
        }
    });

    controller.create_project_named.begin("New");
    assert(wait_for_condition(() => saw_toast && saw_created));
    assert(api.create_project_calls == 1);
}

private void test_on_project_selected_triggers_reload() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    var before = api.list_cards_calls;
    controller.on_project_selected();
    assert(wait_for_condition(() => api.list_cards_calls > before));
}

private void test_on_card_selected_triggers_load() {
    var api = new MainControllerFakeApi();
    api.include_card2 = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(1);
    var before = api.get_card_calls;
    controller.on_card_selected();
    assert(wait_for_condition(() => api.get_card_calls > before));
}

private void test_reload_ai_threads_without_api_is_noop() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text, null, null, false);

    controller.reload_ai_threads_for_project.begin("p1");
    assert(wait_for_condition(() => true));
    assert(api.list_threads_calls == 0);
}

private void test_create_card_without_api_emits_unavailable() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text, null, null, false);

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Create card unavailable") {
            got_error = true;
        }
    });
    controller.create_card.begin();
    assert(wait_for_condition(() => got_error));
}

private void test_bootstrap_success_emits_ready_and_refresh() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var discovery = new FakeServerDiscovery();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text, discovery, null);

    bool got_ready = false;
    bool got_refresh = false;
    controller.api_client_ready.connect((client) => {
        got_ready = true;
    });
    controller.ai_status_refresh_requested.connect(() => {
        got_refresh = true;
    });

    controller.bootstrap.begin();
    assert(wait_for_condition(() => got_ready && got_refresh));
    assert(api.factory_create_calls == 1);
}

private void test_bootstrap_creates_first_project_when_empty_first() {
    var api = new MainControllerFakeApi();
    api.list_projects_empty_first = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var discovery = new FakeServerDiscovery();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text, discovery, null);

    controller.bootstrap.begin();
    assert(wait_for_condition(() => api.create_project_calls > 0));
    assert(api.create_project_calls == 1);
}

private void test_bootstrap_list_projects_failure_emits_bootstrap_error() {
    var api = new MainControllerFakeApi();
    api.fail_list_projects = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var discovery = new FakeServerDiscovery();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text, discovery, null);

    bool saw_bootstrap_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Project bootstrap failed") {
            saw_bootstrap_error = true;
        }
    });

    controller.bootstrap.begin();
    assert(wait_for_condition(() => saw_bootstrap_error));
}

private HolderLinux.CardSummary? find_card_by_id(GLib.ListStore store, string card_id) {
    for (uint i = 0; i < store.get_n_items(); i++) {
        var card = store.get_item(i) as HolderLinux.CardSummary;
        if (card != null && card.card_id == card_id) {
            return card;
        }
    }
    return null;
}

private void test_move_card_success_updates_store_and_preserves_selection() {
    var api = new MainControllerFakeApi();
    api.include_card2 = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    harness.card_selection.set_selected_index(1);
    controller.on_card_selected();
    assert(wait_for_condition(() => controller.get_current_card() != null &&
                          controller.get_current_card().card_id == "c1"));

    clock.now_value = 500;
    bool saw_status = false;
    controller.status_changed.connect((text) => {
        if (text == "Moved card") {
            saw_status = true;
        }
    });

    controller.move_card.begin("c1", "c2", 1500.0);
    assert(wait_for_condition(() => saw_status));

    assert(api.update_card_position_calls == 1);
    assert(api.last_move_card_id == "c1");
    assert(api.last_move_parent_card_id == "c2");
    assert(api.last_move_sort_key == 1500.0);
    assert(api.last_move_updated_at == 500);

    var moved = find_card_by_id(harness.card_store, "c1");
    assert(moved != null);
    assert(moved.parent_card_id == "c2");
    assert(moved.sort_key == 1500.0);
    assert(moved.updated_at == 500);
    assert(controller.get_current_card().updated_at == 500);
    assert(controller.selected_card_id() == "c1");
}

private void test_move_card_failure_emits_error_and_reloads_cards() {
    var api = new MainControllerFakeApi();
    api.fail_update_card_position = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    var list_cards_before = api.list_cards_calls;
    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Move card failed" && details.contains("update position failed")) {
            got_error = true;
        }
    });

    controller.move_card.begin("c1", "c2", 1500.0);
    assert(wait_for_condition(() => got_error));
    assert(wait_for_condition(() => api.list_cards_calls > list_cards_before));
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
        "/main_controller/create_project_with_no_api_is_noop",
        test_create_project_with_no_api_is_noop
    );
    Test.add_func(
        "/main_controller/create_card_success_selects_created_card",
        test_create_card_success_selects_created_card
    );
    Test.add_func(
        "/main_controller/create_card_in_flight_guard",
        test_create_card_in_flight_guard
    );
    Test.add_func(
        "/main_controller/create_card_without_project_emits_error",
        test_create_card_without_project_emits_error
    );
    Test.add_func(
        "/main_controller/create_card_with_title_success_trims_and_sets_content",
        test_create_card_with_title_success_trims_and_sets_content
    );
    Test.add_func(
        "/main_controller/create_card_with_title_empty_emits_error_and_skips_create",
        test_create_card_with_title_empty_emits_error_and_skips_create
    );
    Test.add_func(
        "/main_controller/reload_ai_threads_error_emits_error",
        test_reload_ai_threads_error_emits_error
    );
    Test.add_func(
        "/main_controller/open_search_result_existing_card_skips_reload",
        test_open_search_result_existing_card_skips_reload
    );
    Test.add_func(
        "/main_controller/open_search_result_missing_card_triggers_reload",
        test_open_search_result_missing_card_triggers_reload
    );
    Test.add_func(
        "/main_controller/run_search_without_project_emits_error",
        test_run_search_without_project_emits_error
    );
    Test.add_func(
        "/main_controller/run_search_empty_query_shows_editor",
        test_run_search_empty_query_shows_editor
    );
    Test.add_func(
        "/main_controller/run_search_success_emits_summary_and_show_search",
        test_run_search_success_emits_summary_and_show_search
    );
    Test.add_func(
        "/main_controller/run_search_failure_emits_error",
        test_run_search_failure_emits_error
    );
    Test.add_func(
        "/main_controller/run_search_with_no_api_is_noop",
        test_run_search_with_no_api_is_noop
    );
    Test.add_func(
        "/main_controller/selected_ids_and_api_getter",
        test_selected_ids_and_api_getter
    );
    Test.add_func(
        "/main_controller/reload_everything_with_no_api_is_noop",
        test_reload_everything_with_no_api_is_noop
    );
    Test.add_func(
        "/main_controller/reload_everything_with_no_projects_sets_empty_state",
        test_reload_everything_with_no_projects_sets_empty_state
    );
    Test.add_func(
        "/main_controller/show_project_overview_without_selection_sets_no_project_state",
        test_show_project_overview_without_selection_sets_no_project_state
    );
    Test.add_func(
        "/main_controller/show_project_overview_resource_failure_sets_unknown",
        test_show_project_overview_resource_failure_sets_unknown
    );
    Test.add_func(
        "/main_controller/reload_everything_with_no_cards_sets_empty_state",
        test_reload_everything_with_no_cards_sets_empty_state
    );
    Test.add_func(
        "/main_controller/reload_everything_list_projects_failure_emits_error",
        test_reload_everything_list_projects_failure_emits_error
    );
    Test.add_func(
        "/main_controller/reload_everything_uses_preferred_project_selection",
        test_reload_everything_uses_preferred_project_selection
    );
    Test.add_func(
        "/main_controller/ignore_flags_public_accessors_default_false",
        test_ignore_flags_public_accessors_default_false
    );
    Test.add_func(
        "/main_controller/reload_cards_error_emits_error",
        test_reload_cards_error_emits_error
    );
    Test.add_func(
        "/main_controller/cancel_pending_search_prevents_scheduled_run",
        test_cancel_pending_search_prevents_scheduled_run
    );
    Test.add_func(
        "/main_controller/reload_ai_threads_empty_emits_null_title",
        test_reload_ai_threads_empty_emits_null_title
    );
    Test.add_func(
        "/main_controller/select_ai_thread_by_unknown_id_returns_false",
        test_select_ai_thread_by_unknown_id_returns_false
    );
    Test.add_func(
        "/main_controller/on_ai_thread_selected_with_no_selection_emits_null_title",
        test_on_ai_thread_selected_with_no_selection_emits_null_title
    );
    Test.add_func(
        "/main_controller/on_project_selected_without_selection_noop",
        test_on_project_selected_without_selection_noop
    );
    Test.add_func(
        "/main_controller/on_card_selected_without_selection_sets_empty_state",
        test_on_card_selected_without_selection_sets_empty_state
    );
    Test.add_func(
        "/main_controller/on_ai_thread_selected_emits_title_and_sets_current_thread",
        test_on_ai_thread_selected_emits_title_and_sets_current_thread
    );
    Test.add_func(
        "/main_controller/select_ai_thread_by_id_true_path",
        test_select_ai_thread_by_id_true_path
    );
    Test.add_func(
        "/main_controller/open_search_result_with_empty_store_is_noop",
        test_open_search_result_with_empty_store_is_noop
    );
    Test.add_func(
        "/main_controller/load_selected_card_failure_emits_error",
        test_load_selected_card_failure_emits_error
    );
    Test.add_func(
        "/main_controller/autosave_failure_emits_error",
        test_autosave_failure_emits_error
    );
    Test.add_func(
        "/main_controller/autosave_without_card_is_noop",
        test_autosave_without_card_is_noop
    );
    Test.add_func(
        "/main_controller/create_ai_thread_success",
        test_create_ai_thread_success
    );
    Test.add_func(
        "/main_controller/create_ai_thread_without_context_throws",
        test_create_ai_thread_without_context_throws
    );
    Test.add_func(
        "/main_controller/create_project_success_reloads_and_toasts",
        test_create_project_success_reloads_and_toasts
    );
    Test.add_func(
        "/main_controller/on_project_selected_triggers_reload",
        test_on_project_selected_triggers_reload
    );
    Test.add_func(
        "/main_controller/on_card_selected_triggers_load",
        test_on_card_selected_triggers_load
    );
    Test.add_func(
        "/main_controller/reload_ai_threads_without_api_is_noop",
        test_reload_ai_threads_without_api_is_noop
    );
    Test.add_func(
        "/main_controller/create_card_without_api_emits_unavailable",
        test_create_card_without_api_emits_unavailable
    );
    Test.add_func(
        "/main_controller/bootstrap_success_emits_ready_and_refresh",
        test_bootstrap_success_emits_ready_and_refresh
    );
    Test.add_func(
        "/main_controller/bootstrap_creates_first_project_when_empty_first",
        test_bootstrap_creates_first_project_when_empty_first
    );
    Test.add_func(
        "/main_controller/bootstrap_list_projects_failure_emits_bootstrap_error",
        test_bootstrap_list_projects_failure_emits_bootstrap_error
    );
    Test.add_func(
        "/main_controller/move_card_success_updates_store_and_preserves_selection",
        test_move_card_success_updates_store_and_preserves_selection
    );
    Test.add_func(
        "/main_controller/move_card_failure_emits_error_and_reloads_cards",
        test_move_card_failure_emits_error_and_reloads_cards
    );

    return Test.run();
}

}
