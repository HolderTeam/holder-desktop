using GLib;

namespace HolderLinuxTests {

private HolderLinux.MainController make_controller(MainControllerFakeApi api,
                                                   TestScheduler scheduler,
                                                   FakeClock clock,
                                                   MutableTextProvider search_text,
                                                   MutableTextProvider editor_text,
                                                   FakeServerDiscovery? discovery = null,
                                                   HolderLinux.IHolderApi? initial_api = null,
                                                   bool inject_initial_api = true,
                                                   HolderLinux.IEditorRecoveryDraftService? recovery_draft_service = null) {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));
    var search_store = new GLib.ListStore(typeof(HolderLinux.SearchCardResult));
    var project_selection = new StoreSelectionState(project_store);
    var card_selection = new StoreSelectionState(card_store);
    var thread_selection = new StoreSelectionState(thread_store);

    var controller = new HolderLinux.MainController(
        project_store,
        project_selection,
        card_store,
        card_selection,
        thread_store,
        thread_selection,
        search_store,
        search_text,
        editor_text,
        new MainControllerFakeApiFactory(api, api),
        discovery ?? new FakeServerDiscovery(),
        clock,
        scheduler,
        inject_initial_api ? (initial_api ?? api) : null,
        null,
        recovery_draft_service
    );
    controller.project_selection_requested.connect((project_id) => {
        if (project_id == null || project_id.strip().length == 0) {
            project_selection.set_selected_index(uint.MAX);
            return;
        }
        for (uint i = 0; i < project_store.get_n_items(); i++) {
            var project = project_store.get_item(i) as HolderLinux.Project;
            if (project != null && project.project_id == project_id) {
                project_selection.set_selected_index(i);
                return;
            }
        }
        project_selection.set_selected_index(uint.MAX);
    });
    controller.card_selection_requested.connect((card_id) => {
        if (card_id == null || card_id.strip().length == 0) {
            card_selection.set_selected_index(uint.MAX);
            controller.show_project_overview.begin();
            return;
        }
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as HolderLinux.CardSummary;
            if (card != null && card.card_id == card_id) {
                card_selection.set_selected_index(i);
                return;
            }
        }
        card_selection.set_selected_index(uint.MAX);
    });
    controller.ai_thread_selection_requested.connect((thread_id) => {
        if (thread_id == null || thread_id.strip().length == 0) {
            thread_selection.set_selected_index(uint.MAX);
            controller.on_ai_thread_selected();
            return;
        }
        for (uint i = 0; i < thread_store.get_n_items(); i++) {
            var thread = thread_store.get_item(i) as HolderLinux.AiThreadSummary;
            if (thread != null && thread.thread_id == thread_id) {
                thread_selection.set_selected_index(i);
                controller.on_ai_thread_selected();
                return;
            }
        }
        thread_selection.set_selected_index(uint.MAX);
        controller.on_ai_thread_selected();
    });
    return controller;
}

private MainControllerTestHarness make_harness(MainControllerFakeApi api,
                                 TestScheduler scheduler,
                                 FakeClock clock,
                                 FakeServerDiscovery? discovery = null,
                                 HolderLinux.IHolderApi? initial_api = null,
                                 bool inject_initial_api = true,
                                 HolderLinux.IEditorRecoveryDraftService? recovery_draft_service = null,
                                 Settings? settings = null) {
    return new MainControllerTestHarness(
        api,
        scheduler,
        clock,
        discovery,
        initial_api,
        inject_initial_api,
        recovery_draft_service,
        null,
        settings
    );
}

private string? prepare_search_result_card(HolderLinux.MainController controller, uint position) {
    string? prepared = null;
    bool completed = false;
    controller.prepare_search_result_card_at.begin(position, (obj, res) => {
        prepared = controller.prepare_search_result_card_at.end(res);
        completed = true;
    });
    assert(wait_for_condition(() => completed));
    return prepared;
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
    assert(wait_for_condition(() => harness.card_store.get_n_items() > 0));
    assert(controller.selected_card_id() == null);
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
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

private void test_create_card_uses_selected_project_when_current_project_null() {
    var api = new MainControllerFakeApi();
    api.include_created_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    harness.project_store.append(
        new HolderLinux.Project("p-selected", "Selected", "encrypted_git", "/tmp/selected", 1, 1)
    );
    harness.project_selection.set_selected_index(0);
    assert(controller.get_current_project() == null);

    bool saw_toast = false;
    controller.toast_requested.connect((message) => {
        if (message == "New card created") {
            saw_toast = true;
        }
    });

    controller.create_card.begin();
    assert(wait_for_condition(() => saw_toast));
    assert(api.create_card_calls == 1);
    assert(api.last_created_project_id == "p-selected");
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

private void test_create_card_with_parent_uses_parent_based_default_title() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    harness.card_store.append(
        new HolderLinux.CardSummary("child-1", "p1", "Untitled child of Card 1", "child-1.md", 2000.0, "c1", 30, 30)
    );
    harness.card_store.append(
        new HolderLinux.CardSummary("child-2", "p1", "Untitled child of Card 1 4", "child-2.md", 3000.0, "c1", 31, 31)
    );

    bool saw_toast = false;
    controller.toast_requested.connect((message) => {
        if (message == "New card created") {
            saw_toast = true;
        }
    });

    controller.create_card.begin("c1");
    assert(wait_for_condition(() => saw_toast));

    assert(api.create_card_calls == 1);
    assert(api.last_created_parent_card_id == "c1");
    assert(api.last_created_title == "Untitled child of Card 1 5");
    assert(api.last_created_content == "# Untitled child of Card 1 5\n\n");
}

private void test_create_card_with_parent_uses_untitled_when_parent_missing() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool saw_toast = false;
    controller.toast_requested.connect((message) => {
        if (message == "New card created") {
            saw_toast = true;
        }
    });

    controller.create_card.begin("missing-parent");
    assert(wait_for_condition(() => saw_toast));

    assert(api.create_card_calls == 1);
    assert(api.last_created_parent_card_id == "missing-parent");
    assert(api.last_created_title == "Untitled");
    assert(api.last_created_content == "# Untitled\n\n");
}

private void test_create_card_with_parent_returns_base_title_when_children_are_unrelated() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    harness.card_store.append(
        new HolderLinux.CardSummary("child-x", "p1", "Something else entirely", "child-x.md", 2000.0, "c1", 30, 30)
    );

    bool saw_toast = false;
    controller.toast_requested.connect((message) => {
        if (message == "New card created") {
            saw_toast = true;
        }
    });

    controller.create_card.begin("c1");
    assert(wait_for_condition(() => saw_toast));

    assert(api.create_card_calls == 1);
    assert(api.last_created_parent_card_id == "c1");
    assert(api.last_created_title == "Untitled child of Card 1");
    assert(api.last_created_content == "# Untitled child of Card 1\n\n");
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
    var prepared = prepare_search_result_card(controller, 0);
    assert(prepared == "c2");
    controller.card_selection_requested("c2");
    controller.load_card_by_id.begin("c2");
    assert(wait_for_condition(() => controller.selected_card_id() == "c2"));
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
    var prepared = prepare_search_result_card(controller, 0);
    assert(wait_for_condition(() => api.list_cards_calls > before_reload));
    assert(prepared == "c2");
    controller.card_selection_requested("c2");
    controller.load_card_by_id.begin("c2");
    assert(wait_for_condition(() => controller.selected_card_id() == "c2"));
    assert(wait_for_condition(() => controller.get_current_card() != null &&
                          controller.get_current_card().card_id == "c2"));
}

private void test_open_search_result_missing_card_falls_back_to_first_card() {
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

    var list_cards_before = api.list_cards_calls;
    var prepared = prepare_search_result_card(controller, 0);
    assert(wait_for_condition(() => api.list_cards_calls > list_cards_before));
    assert(prepared == null);
    assert(controller.selected_card_id() == null);
    assert(controller.get_current_card() == null);
}

private void test_open_search_result_reload_failure_returns_null() {
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

    var list_cards_before = api.list_cards_calls;
    api.fail_list_cards_once = true;
    var prepared = prepare_search_result_card(controller, 0);
    assert(wait_for_condition(() => api.list_cards_calls > list_cards_before));
    assert(prepared == null);
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

private void test_clear_search_results_clears_store_and_resets_summary() {
    var api = new MainControllerFakeApi();
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
    assert(wait_for_condition(() => controller.search_store.get_n_items() > 0));

    string last_summary = "";
    controller.search_summary_changed.connect((text) => {
        last_summary = text;
    });

    controller.clear_search_results();
    assert(controller.search_store.get_n_items() == 0);
    assert(last_summary == "Search results will appear here.");
}

private void test_show_resource_references_populates_central_card_results() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;
    var resource = new HolderLinux.ProjectResource(
        "resource-1",
        "project-1",
        "image",
        "",
        "Boiler photograph",
        null,
        1,
        2
    );
    var first_kinds = new Gee.ArrayList<string>();
    first_kinds.add("attachment");
    resource.referenced_by_cards.add(new HolderLinux.ResourceCardReference(
        "card-1",
        "Boiler service",
        100,
        first_kinds
    ));
    var second_kinds = new Gee.ArrayList<string>();
    second_kinds.add("reference");
    second_kinds.add("related_item");
    resource.referenced_by_cards.add(new HolderLinux.ResourceCardReference(
        "card-2",
        "House records",
        200,
        second_kinds
    ));

    string summary = "";
    bool show_search = false;
    controller.search_summary_changed.connect((text) => { summary = text; });
    controller.show_search_requested.connect(() => { show_search = true; });

    controller.show_resource_references(resource);

    assert(show_search);
    assert(summary == "2 card(s) using “Boiler photograph”");
    assert(harness.search_store.get_n_items() == 2);
    var first = harness.search_store.get_item(0) as HolderLinux.SearchCardResult;
    var second = harness.search_store.get_item(1) as HolderLinux.SearchCardResult;
    assert(first != null && first.card_id == "card-1");
    assert(first.snippet == "Attachment");
    assert(second != null && second.card_id == "card-2");
    assert(second.snippet == "Reference · Related item");
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

private void test_list_ai_messages_without_api_throws_no_api_context() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock, null, null, false);
    var controller = harness.controller;

    bool done = false;
    bool got_error = false;
    controller.list_ai_messages.begin("t1", (obj, res) => {
        try {
            controller.list_ai_messages.end(res);
        } catch (Error e) {
            got_error = e.message.contains("No API context.");
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_error);
    assert(api.list_ai_messages_calls == 0);
}

private void test_list_ai_messages_with_api_passthrough() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    bool done = false;
    Gee.ArrayList<HolderLinux.AiMessage>? messages = null;
    controller.list_ai_messages.begin("t1", (obj, res) => {
        try {
            messages = controller.list_ai_messages.end(res);
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(messages != null);
    assert(messages.size == 0);
    assert(api.list_ai_messages_calls == 1);
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

private void test_show_project_overview_zero_timestamps_show_unknown() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock, null, null, false);
    var controller = harness.controller;

    harness.project_store.append(
        new HolderLinux.Project("p1", "Zero Times", "encrypted_git", "/tmp/zero", 0, 0)
    );
    harness.project_selection.set_selected_index(0);

    bool saw_unknown_timestamps = false;
    controller.editor_state_changed.connect((text, editable) => {
        if (text.contains("## Metadata") &&
            text.contains("- Created: unknown") &&
            text.contains("- Updated: unknown")) {
            saw_unknown_timestamps = true;
            assert(!editable);
        }
    });

    controller.show_project_overview.begin();
    assert(wait_for_condition(() => saw_unknown_timestamps));
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

private void test_reload_everything_preserves_backend_home_first_order() {
    var api = new MainControllerFakeApi();
    api.include_home_project = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => harness.project_store.get_n_items() == 2));

    var first = harness.project_store.get_item(0) as HolderLinux.Project;
    var second = harness.project_store.get_item(1) as HolderLinux.Project;
    assert(first != null && first.name == "Home");
    assert(second != null && second.name == "Project 1");
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

    controller.reload_cards_for_selected_project.begin();
    assert(wait_for_condition(() => true));
    assert(controller.get_current_project() == null);
}

private void test_on_project_selected_without_api_is_noop() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock, null, null, false);
    var controller = harness.controller;

    harness.project_store.append(new HolderLinux.Project("p1", "P1", "encrypted_git", "/tmp", 1, 1));
    harness.project_selection.set_selected_index(0);

    controller.reload_cards_for_selected_project.begin();
    assert(wait_for_condition(() => true));
    assert(api.list_cards_calls == 0);
}

private void test_reload_cards_without_selection_keeps_committed_sidebar_state() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    assert(harness.card_store.get_n_items() > 0);
    var card_count_before = harness.card_store.get_n_items();

    harness.project_selection.set_selected_index(uint.MAX);
    controller.reload_cards_for_selected_project.begin();
    assert(wait_for_condition(() => true));

    assert(harness.card_store.get_n_items() == card_count_before);
}

private void test_on_card_selected_without_selection_does_not_emit_empty_state() {
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
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => true));
    assert(!saw_no_selection);
}

private void test_on_card_selected_without_selection_keeps_committed_content() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    string last_editor_text = "";
    bool saw_no_selection = false;
    controller.editor_state_changed.connect((text, editable) => {
        last_editor_text = text;
        if (text.contains("No Card Selected")) {
            saw_no_selection = true;
        }
    });

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));
    var committed = last_editor_text;
    assert(committed.contains("# Card 1"));

    harness.card_selection.set_selected_index(uint.MAX);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => true));

    assert(last_editor_text == committed);
    assert(!saw_no_selection);
}

private void test_on_card_selected_without_api_is_noop() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock, null, null, false);
    var controller = harness.controller;

    harness.card_store.append(
        new HolderLinux.CardSummary("c1", "p1", "C1", "c1.md", 1024.0, null, 1, 1)
    );
    harness.card_selection.set_selected_index(0);

    bool got_editor_state = false;
    controller.editor_state_changed.connect((text, editable) => {
        got_editor_state = true;
    });

    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => true));
    assert(api.get_card_calls == 0);
    assert(!got_editor_state);
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

    controller.prepare_search_result_card_at.begin(0);
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
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => got_error));
}

private void test_load_selected_card_stale_success_is_ignored() {
    var api = new MainControllerFakeApi();
    api.include_card2 = true;
    api.slow_get_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    harness.card_selection.set_selected_index(0);
    Timeout.add(5, () => {
        harness.card_selection.set_selected_index(1);
        return Source.REMOVE;
    });

    bool loaded_card1_status = false;
    controller.status_changed.connect((text) => {
        if (text == "Loaded Card 1") {
            loaded_card1_status = true;
        }
    });

    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => harness.card_selection.get_selected_index() == 1));
    assert(wait_for_condition(() => api.get_card_calls == 1));
    assert(!loaded_card1_status);
    assert(controller.get_current_card() == null);
}

private void test_load_selected_card_stale_failure_is_ignored() {
    var api = new MainControllerFakeApi();
    api.include_card2 = true;
    api.slow_get_card = true;
    api.fail_get_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    harness.card_selection.set_selected_index(0);
    Timeout.add(5, () => {
        harness.card_selection.set_selected_index(1);
        return Source.REMOVE;
    });

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        got_error = true;
    });

    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => harness.card_selection.get_selected_index() == 1));
    assert(wait_for_condition(() => api.get_card_calls == 1));
    assert(!got_error);
}

private void test_load_selected_card_failure_keeps_previous_editor_content() {
    var api = new MainControllerFakeApi();
    api.include_card2 = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    string last_editor_text = "";
    controller.editor_state_changed.connect((text, editable) => {
        last_editor_text = text;
    });

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));
    var committed_text = last_editor_text;
    assert(committed_text == "# Card 1\n\nBody");

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to load card") {
            got_error = true;
        }
    });

    api.fail_get_card = true;
    harness.card_selection.set_selected_index(1);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => got_error));
    assert(last_editor_text == committed_text);
}

private void test_reload_cards_failure_keeps_previous_committed_state() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    string last_editor_text = "";
    controller.editor_state_changed.connect((text, editable) => {
        last_editor_text = text;
    });

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    assert(harness.card_store.get_n_items() > 0);

    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));
    var committed_text = last_editor_text;
    var card_count_before = harness.card_store.get_n_items();
    var first_before = harness.card_store.get_item(0) as HolderLinux.CardSummary;
    assert(first_before != null);
    var first_before_id = first_before.card_id;

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to load cards") {
            got_error = true;
        }
    });

    api.fail_list_cards = true;
    controller.reload_cards_for_selected_project.begin();
    assert(wait_for_condition(() => got_error));
    assert(harness.card_store.get_n_items() == card_count_before);
    var first_after = harness.card_store.get_item(0) as HolderLinux.CardSummary;
    assert(first_after != null);
    assert(first_after.card_id == first_before_id);
    assert(last_editor_text == committed_text);
}

private void test_reload_cards_stale_success_is_ignored() {
    var api = new MainControllerFakeApi();
    api.include_home_project = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;
    bool triggered = false;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    assert(controller.get_current_project().project_id == "p-home");
    api.list_cards_before_complete_hook = (project_id) => {
        if (triggered || project_id != "p-home") {
            return;
        }
        triggered = true;
        harness.project_selection.set_selected_index(1);
        controller.reload_cards_for_selected_project.begin();
    };

    harness.project_selection.set_selected_index(0);
    controller.reload_cards_for_selected_project.begin();

    assert(wait_for_condition(() => api.list_cards_calls >= 2));
    assert(wait_for_condition(() => triggered));

    assert(controller.get_current_project() != null);
    assert(controller.get_current_project().project_id == "p1");
    assert(harness.card_store.get_n_items() > 0);
    var first = harness.card_store.get_item(0) as HolderLinux.CardSummary;
    assert(first != null);
    assert(first.project_id == "p1");
}

private void test_reload_cards_stale_failure_is_ignored() {
    var api = new MainControllerFakeApi();
    api.include_home_project = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;
    bool triggered = false;

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to load cards") {
            got_error = true;
        }
    });

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    assert(controller.get_current_project().project_id == "p-home");
    api.fail_list_cards_for_project_id = "p-home";
    api.list_cards_before_complete_hook = (project_id) => {
        if (triggered || project_id != "p-home") {
            return;
        }
        triggered = true;
        harness.project_selection.set_selected_index(1);
        controller.reload_cards_for_selected_project.begin();
    };

    harness.project_selection.set_selected_index(0);
    controller.reload_cards_for_selected_project.begin();

    assert(wait_for_condition(() => api.list_cards_calls >= 2));
    assert(wait_for_condition(() => triggered));

    assert(controller.get_current_project() != null);
    assert(controller.get_current_project().project_id == "p1");
    assert(harness.card_store.get_n_items() > 0);
    var first = harness.card_store.get_item(0) as HolderLinux.CardSummary;
    assert(first != null);
    assert(first.project_id == "p1");
    assert(!got_error);
}

private void test_valid_card_to_card_transition_does_not_emit_no_card_selected() {
    var api = new MainControllerFakeApi();
    api.include_card2 = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    assert(harness.card_store.get_n_items() >= 2);

    var first = harness.card_store.get_item(0) as HolderLinux.CardSummary;
    var second = harness.card_store.get_item(1) as HolderLinux.CardSummary;
    assert(first != null);
    assert(second != null);

    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null
                                    && controller.get_current_card().card_id == first.card_id));

    bool saw_no_card_selected = false;
    controller.editor_state_changed.connect((text, editable) => {
        if (text.contains("No Card Selected")) {
            saw_no_card_selected = true;
        }
    });

    harness.card_selection.set_selected_index(1);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null
                                    && controller.get_current_card().card_id == second.card_id));
    assert(!saw_no_card_selected);
}

private void test_valid_project_to_project_transition_does_not_emit_empty_placeholders() {
    var api = new MainControllerFakeApi();
    api.include_home_project = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool saw_no_project_selected = false;
    bool saw_no_card_selected = false;
    controller.editor_state_changed.connect((text, editable) => {
        if (text.contains("No Project Selected")) {
            saw_no_project_selected = true;
        }
        if (text.contains("No Card Selected")) {
            saw_no_card_selected = true;
        }
    });

    var list_cards_before = api.list_cards_calls;
    harness.project_selection.set_selected_index(1);
    controller.reload_cards_for_selected_project.begin();

    assert(wait_for_condition(() => controller.get_current_project() != null
                                    && controller.get_current_project().project_id == "p1"));
    assert(wait_for_condition(() => api.list_cards_calls > list_cards_before));
    assert(!saw_no_project_selected);
    assert(!saw_no_card_selected);
}

private void test_autosave_failure_emits_error() {
    var api = new MainControllerFakeApi();
    api.fail_update_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var draft_service = new FakeEditorRecoveryDraftService();
    var harness = make_harness(api, scheduler, clock, null, null, true, draft_service);
    var controller = harness.controller;
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Autosave failed") {
            got_error = true;
        }
    });
    harness.editor_text.value = "# New title";
    controller.on_editor_content_changed();
    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => got_error));
    assert(controller.has_unsaved_editor_changes());
    assert(draft_service.save_calls == 1);
    assert(draft_service.last_saved_draft != null);
    assert(draft_service.last_saved_draft.card_id == "c1");
    assert(draft_service.last_saved_draft.content == "# New title");
}

private void test_editor_change_emits_unsaved_until_save_confirmation() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    string last_save_state = "";
    string saved_project_id = "";
    string saved_card_id = "";
    controller.editor_save_state_changed.connect((text) => {
        last_save_state = text;
    });
    controller.card_durable_save_completed.connect((project_id, card_id, updated_at) => {
        saved_project_id = project_id;
        saved_card_id = card_id;
    });

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));
    assert(last_save_state == "");

    harness.editor_text.value = "# Updated Title\n\nDraft body";
    controller.on_editor_content_changed();
    assert(last_save_state == "Unsaved");
    assert(controller.has_unsaved_editor_changes());

    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => last_save_state == "Autosaved"));
    assert(!controller.has_unsaved_editor_changes());
    assert(saved_project_id == "p1");
    assert(saved_card_id == "c1");
}

private void test_autosave_trims_trailing_whitespace_when_settings_enable_it() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    // Schema id duplicated as a literal rather than referencing HolderLinux.AppSettings
    // .SCHEMA_ID -- AppSettings also carries Adw.ColorScheme-returning helpers, and this test
    // target deliberately doesn't link libadwaita. See editor_save.vala's own KEY_* constants
    // for the same reasoning; keep this schema id and the three key names in sync with
    // team.holder.Holder.gschema.xml if either ever changes.
    var settings = new Settings("team.holder.Holder");
    settings.reset("preserve-trailing-whitespace");
    settings.set_boolean("trim-two-space-hard-breaks", true);
    settings.reset("trim-whitespace-in-code-blocks");
    var harness = make_harness(api, scheduler, clock, null, null, true, null, settings);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    // Ordinary trailing whitespace is always removed; the genuine two-space hard-break run on
    // the second line is stripped too here specifically because trim-two-space-hard-breaks is
    // on above -- proving the setting, not just the always-on ordinary-whitespace cleanup, is
    // actually reaching the save.
    harness.editor_text.value = "# Title \n\nHard break line  \nplain line";
    controller.on_editor_content_changed();
    assert(controller.has_unsaved_editor_changes());

    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => api.update_card_calls > 0));
    assert(api.last_updated_content == "# Title\n\nHard break line\nplain line");

    // Saving canonicalizes the durable copy without rewriting the active editor. Replacing the
    // live Gtk.TextBuffer here would remove an ordinary space while the user pauses between
    // words and would disturb its cursor, viewport, and inline child anchors.
    assert(harness.editor_text.value == "# Title \n\nHard break line  \nplain line");
    assert(!controller.has_unsaved_editor_changes());

    settings.reset("preserve-trailing-whitespace");
    settings.reset("trim-two-space-hard-breaks");
    settings.reset("trim-whitespace-in-code-blocks");
}

private void test_successful_autosave_refreshes_validated_tag_occurrences() {
    var api = new MainControllerFakeApi();
    api.reflect_update_in_get_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    controller.get_current_card().tag_occurrences = {
        new HolderLinux.CardTagOccurrence("old", 0, 4)
    };
    var edited = "# New title\n\n#todo";
    harness.editor_text.value = edited;
    api.current_tag_occurrences = {
        new HolderLinux.CardTagOccurrence("todo", 13, 18)
    };

    controller.on_editor_content_changed();
    assert(controller.get_current_card().tag_occurrences.length == 1);
    assert(controller.get_current_card().tag_occurrences[0].tag == "old");

    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => controller.get_current_card().tag_occurrences.length == 1));
    assert(controller.get_current_card().tag_occurrences[0].tag == "todo");
    assert(controller.get_current_card().tag_occurrences[0].byte_start == 13);
    assert(api.get_card_calls >= 2);
}

private void test_autosave_failure_keeps_unsaved_save_state() {
    var api = new MainControllerFakeApi();
    api.fail_update_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    string last_save_state = "";
    controller.editor_save_state_changed.connect((text) => {
        last_save_state = text;
    });

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Updated Title\n\nDraft body";
    controller.on_editor_content_changed();
    assert(last_save_state == "Unsaved");

    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => last_save_state == "Unsaved"));
    assert(controller.has_unsaved_editor_changes());
}

private void test_autosave_without_api_writes_local_recovery_draft() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var draft_service = new FakeEditorRecoveryDraftService();
    var harness = make_harness(api, scheduler, clock, null, null, true, draft_service);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Offline Title\n\nOffline body";
    controller.on_editor_content_changed();
    controller.api = null;

    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => draft_service.save_calls == 1));
    assert(draft_service.last_saved_draft != null);
    assert(draft_service.last_saved_draft.card_id == "c1");
    assert(draft_service.last_saved_draft.title == "Offline Title");
    assert(draft_service.last_saved_draft.content == "# Offline Title\n\nOffline body");
    assert(controller.has_unsaved_editor_changes());
}

private void test_autosave_failure_keeps_existing_recovery_draft() {
    var api = new MainControllerFakeApi();
    api.fail_update_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var draft_service = new FakeEditorRecoveryDraftService();
    var harness = make_harness(api, scheduler, clock, null, null, true, draft_service);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    try {
        draft_service.save_draft(new HolderLinux.EditorRecoveryDraft(
            "c1",
            "p1",
            "Old Draft",
            "# Old Draft",
            999
        ));
    } catch (Error e) {
        assert_not_reached();
    }
    draft_service.save_calls = 0;
    draft_service.remove_calls = 0;

    harness.editor_text.value = "# Failed Save Title\n\nDraft body";
    controller.on_editor_content_changed();
    controller.autosave_current_card.begin();

    assert(wait_for_condition(() => draft_service.save_calls == 1));
    assert(draft_service.remove_calls == 0);
    assert(draft_service.drafts.has_key("c1"));
    assert(draft_service.drafts["c1"].content == "# Failed Save Title\n\nDraft body");
}

private void test_confirmed_save_removes_recovery_draft() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var draft_service = new FakeEditorRecoveryDraftService();
    var harness = make_harness(api, scheduler, clock, null, null, true, draft_service);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    try {
        draft_service.save_draft(new HolderLinux.EditorRecoveryDraft(
            "c1",
            "p1",
            "Offline Title",
            "# Offline Title\n\nOffline body",
            1001
        ));
    } catch (Error e) {
        assert_not_reached();
    }
    draft_service.save_calls = 0;
    draft_service.remove_calls = 0;

    harness.editor_text.value = "# Saved Title\n\nDurable body";
    controller.on_editor_content_changed();
    controller.autosave_current_card.begin();

    assert(wait_for_condition(() => draft_service.remove_calls == 1));
    assert(!draft_service.drafts.has_key("c1"));
    assert(!controller.has_unsaved_editor_changes());
}

private void test_autosave_failure_schedules_retry_and_retry_success_clears_dirty_state() {
    var api = new MainControllerFakeApi();
    api.fail_update_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    string last_error_details = "";
    controller.error_reported.connect((title, details) => {
        if (title == "Autosave failed") {
            last_error_details = details;
        }
    });

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Updated Title\n\nDraft body";
    controller.on_editor_content_changed();
    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => controller.has_pending_autosave_retry()));
    assert(last_error_details.contains("Retrying in 1 s."));
    assert(controller.has_unsaved_editor_changes());

    api.fail_update_card = false;
    scheduler.run_all_once();
    assert(wait_for_condition(() => api.update_card_calls == 1));
    assert(wait_for_condition(() => !controller.has_unsaved_editor_changes()));
    assert(!controller.has_pending_autosave_retry());
    assert(controller.get_autosave_retry_attempts() == 0);
}

private void test_new_edit_cancels_pending_autosave_retry() {
    var api = new MainControllerFakeApi();
    api.fail_update_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Updated Title\n\nDraft body";
    controller.on_editor_content_changed();
    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => controller.has_pending_autosave_retry()));

    controller.schedule_autosave();
    assert(!controller.has_pending_autosave_retry());
    assert(controller.get_autosave_retry_attempts() == 0);
}

private void test_navigation_change_cancels_stale_autosave_retry() {
    var api = new MainControllerFakeApi();
    api.include_card2 = true;
    api.fail_update_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Updated Title\n\nDraft body";
    controller.on_editor_content_changed();
    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => controller.has_pending_autosave_retry()));

    api.fail_update_card = false;
    controller.show_project_overview.begin();
    assert(wait_for_condition(() => controller.get_current_card() == null));
    assert(!controller.has_pending_autosave_retry());
    scheduler.run_all_once();
    assert(api.update_card_calls == 0);
}

private void test_background_reload_success_keeps_dirty_editor_state() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));
    assert(!controller.has_unsaved_editor_changes());

    harness.editor_text.value = "# Card 1\n\nDraft changes";
    assert(controller.has_unsaved_editor_changes());

    controller.reload_cards_for_selected_project.begin();
    assert(wait_for_condition(() => api.list_cards_calls >= 2));
    assert(controller.has_unsaved_editor_changes());
}

private void test_background_reload_failure_keeps_dirty_editor_state() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Card 1\n\nDraft changes";
    assert(controller.has_unsaved_editor_changes());

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to load cards") {
            got_error = true;
        }
    });

    api.fail_list_cards = true;
    controller.reload_cards_for_selected_project.begin();
    assert(wait_for_condition(() => got_error));
    assert(controller.has_unsaved_editor_changes());
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

private void test_autosave_without_unsaved_changes_is_noop() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    string last_save_state = "unchanged";
    controller.editor_save_state_changed.connect((text) => {
        last_save_state = text;
    });

    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => true));
    assert(api.update_card_calls == 0);
    assert(last_save_state == "unchanged");
}

private void test_editor_content_changed_without_current_card_clears_save_state() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var search_text = new MutableTextProvider();
    var editor_text = new MutableTextProvider();
    var controller = make_controller(api, scheduler, clock, search_text, editor_text);

    string last_save_state = "seed";
    controller.editor_save_state_changed.connect((text) => {
        last_save_state = text;
    });

    controller.on_editor_content_changed();
    assert(last_save_state == "");
}

private void test_repeated_autosave_failures_use_backoff_status_and_tiers() {
    var api = new MainControllerFakeApi();
    api.fail_update_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    string last_status = "";
    controller.status_changed.connect((text) => {
        last_status = text;
    });

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Updated Title\n\nDraft body";
    controller.on_editor_content_changed();

    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => controller.has_pending_autosave_retry()));
    assert(controller.get_autosave_retry_attempts() == 1);

    scheduler.run_all_once();
    assert(wait_for_condition(() => controller.has_pending_autosave_retry()));
    assert(controller.get_autosave_retry_attempts() == 2);
    assert(last_status == "Autosave failed, retrying in 2 s");

    scheduler.run_all_once();
    assert(wait_for_condition(() => controller.has_pending_autosave_retry()));
    assert(controller.get_autosave_retry_attempts() == 3);
    assert(last_status == "Autosave failed, retrying in 5 s");

    scheduler.run_all_once();
    assert(wait_for_condition(() => controller.has_pending_autosave_retry()));
    assert(controller.get_autosave_retry_attempts() == 4);
    assert(last_status == "Autosave failed, retrying in 10 s");
}

private void test_repeated_manual_autosave_failure_replaces_existing_retry_timer() {
    var api = new MainControllerFakeApi();
    api.fail_update_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Updated Title\n\nDraft body";
    controller.on_editor_content_changed();

    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => controller.has_pending_autosave_retry()));
    assert(controller.get_autosave_retry_attempts() == 1);
    uint cancel_calls_after_first_failure = scheduler.cancel_calls;

    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => controller.has_pending_autosave_retry()));
    assert(controller.get_autosave_retry_attempts() == 2);
    assert(scheduler.cancel_calls > cancel_calls_after_first_failure);
}

private void test_clean_editor_state_cancels_pending_retry_when_view_changes() {
    var api = new MainControllerFakeApi();
    api.fail_update_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Updated Title\n\nDraft body";
    controller.on_editor_content_changed();
    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => controller.has_pending_autosave_retry()));

    controller.show_project_overview.begin();
    assert(wait_for_condition(() => !controller.has_pending_autosave_retry()));
    assert(controller.get_autosave_retry_attempts() == 0);
}

private void test_retry_callback_resets_attempts_when_editor_is_clean() {
    var api = new MainControllerFakeApi();
    api.fail_update_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Updated Title\n\nDraft body";
    controller.on_editor_content_changed();
    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => controller.has_pending_autosave_retry()));

    harness.editor_text.value = controller.get_current_card().content;
    controller.on_editor_content_changed();
    scheduler.run_all_once();
    assert(!controller.has_pending_autosave_retry());
    assert(controller.get_autosave_retry_attempts() == 0);
}

private void test_update_selected_card_summary_without_current_card_is_noop() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    harness.card_store.append(
        new HolderLinux.CardSummary("c1", "p1", "Card 1", "c1.md", 1000.0, null, 1, 20)
    );
    harness.card_selection.set_selected_index(0);
    assert(controller.get_current_card() == null);

    controller.update_selected_card_summary("Renamed", 999);

    assert(harness.card_store.get_n_items() == 1);
    var card = harness.card_store.get_item(0) as HolderLinux.CardSummary;
    assert(card != null);
    assert(card.title == "Card 1");
    assert(card.updated_at == 20);
}

private void test_rebuild_card_summaries_handles_null_and_non_target_cards() {
    var source = new Gee.ArrayList<HolderLinux.CardSummary?>();
    source.add(null);
    source.add(new HolderLinux.CardSummary("c1", "p1", "Card 1", "c1.md", 1000.0, null, 1, 20));
    source.add(new HolderLinux.CardSummary("c2", "p1", "Card 2", "c2.md", 2000.0, null, 2, 30));

    var rebuilt = HolderLinux.MainController.rebuild_card_summaries(
        source,
        "c2",
        "Renamed C2",
        999
    );

    assert(rebuilt.size == 2);
    assert(rebuilt[0].card_id == "c1");
    assert(rebuilt[0].title == "Card 1");
    assert(rebuilt[1].card_id == "c2");
    assert(rebuilt[1].title == "Renamed C2");
    assert(rebuilt[1].updated_at == 999);
}

private void test_compare_cards_for_sidebar_orders_older_last_and_tiebreaks_by_title() {
    var newer = new HolderLinux.CardSummary("new", "p1", "Zulu", "new.md", 1.0, null, 1, 20);
    var older = new HolderLinux.CardSummary("old", "p1", "Alpha", "old.md", 2.0, null, 2, 10);
    assert(HolderLinux.StoreSyncController.compare_cards_for_sidebar(older, newer) == 1);

    var tie_a = new HolderLinux.CardSummary("a", "p1", "Beta", "a.md", 1.0, null, 1, 50);
    var tie_b = new HolderLinux.CardSummary("b", "p1", "alpha", "b.md", 2.0, null, 2, 50);
    assert(HolderLinux.StoreSyncController.compare_cards_for_sidebar(tie_a, tie_b) > 0);
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
    bool saw_ready = false;
    controller.toast_requested.connect((message) => {
        if (message == "Created project: New") {
            saw_toast = true;
        }
    });
    controller.status_changed.connect((text) => {
        if (text == "Project ready") {
            saw_ready = true;
        }
    });

    controller.create_project_named.begin("New");
    assert(wait_for_condition(() => saw_toast && saw_ready));
    assert(api.create_project_calls == 1);
    assert(api.create_card_calls == 1);
    assert(api.last_created_project_id == "p-created");
    assert(api.last_created_title == "Untitled in New");
    assert(api.last_created_content == "# Untitled in New\n\n");
    assert(controller.selected_project_id() == "p-created");
    assert(controller.selected_card_id() == "c-created");
}

private void test_create_project_starter_card_failure_still_selects_project() {
    var api = new MainControllerFakeApi();
    api.fail_create_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    bool got_starter_card_error = false;
    bool saw_project_created = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Failed to create starter card") {
            got_starter_card_error = true;
        }
    });
    controller.status_changed.connect((text) => {
        if (text == "Project created") {
            saw_project_created = true;
        }
    });

    controller.create_project_named.begin("New");
    assert(wait_for_condition(() => got_starter_card_error && saw_project_created));
    assert(api.create_project_calls == 1);
    assert(api.create_card_calls == 0);
    assert(controller.selected_project_id() == "p-created");
    assert(controller.selected_card_id() == null);
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
    controller.reload_cards_for_selected_project.begin();
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
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
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

private void test_move_card_by_intent_success_reloads_and_preserves_selection() {
    var api = new MainControllerFakeApi();
    api.include_card2 = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    harness.card_selection.set_selected_index(1);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null &&
                          controller.get_current_card().card_id == "c1"));

    bool saw_status = false;
    controller.status_changed.connect((text) => {
        if (text == "Moved card") {
            saw_status = true;
        }
    });
    var list_cards_before = api.list_cards_calls;

    controller.move_card_by_intent.begin("c1", "before", "c2", null);
    assert(wait_for_condition(() => saw_status && api.list_cards_calls > list_cards_before));

    assert(api.update_card_position_calls == 1);
    assert(api.last_move_project_id == "p1");
    assert(api.last_move_intent == "before");
    assert(api.last_move_card_id == "c1");
    assert(api.last_move_target_card_id == "c2");
    assert(controller.selected_card_id() == "c1");
}

private void test_move_card_by_intent_failure_emits_error_and_reloads_cards() {
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
        if (title == "Move card failed" && details.contains("move by intent failed")) {
            got_error = true;
        }
    });

    controller.move_card_by_intent.begin("c1", "after", "c2", null);
    assert(wait_for_condition(() => got_error));
    assert(wait_for_condition(() => api.list_cards_calls > list_cards_before));
}

private void test_move_card_by_intent_without_api_is_noop() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock, null, null, false);
    var controller = harness.controller;

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        got_error = true;
    });

    controller.move_card_by_intent.begin("c1", "to_end", null, null);
    assert(wait_for_condition(() => true));
    assert(api.update_card_position_calls == 0);
    assert(api.list_cards_calls == 0);
    assert(!got_error);
}

private void test_move_card_by_intent_without_selected_project_emits_error() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Move card failed" && details == "Select a project first.") {
            got_error = true;
        }
    });

    // Do not load projects/selection first.
    controller.move_card_by_intent.begin("c1", "before", "c2", null);

    assert(wait_for_condition(() => got_error));
    assert(api.update_card_position_calls == 0);
}

private void test_move_card_by_intent_into_emits_toast() {
    var api = new MainControllerFakeApi();
    api.next_move_into_title = "Folder A";
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool saw_toast = false;
    controller.toast_requested.connect((text) => {
        if (text == "Moved card into Folder A") {
            saw_toast = true;
        }
    });

    controller.move_card_by_intent.begin("c1", "into", "c2", null);
    assert(wait_for_condition(() => saw_toast));
}

private void test_move_card_by_intent_stale_reload_returns_without_reselecting_card() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    int card_selection_requests = 0;
    controller.card_selection_requested.connect((card_id) => {
        card_selection_requests++;
    });

    bool triggered = false;
    var list_cards_before = api.list_cards_calls;
    api.list_cards_before_complete_hook = (project_id) => {
        if (triggered || project_id != "p1") {
            return;
        }
        triggered = true;
        harness.project_selection.set_selected_index(uint.MAX);
    };

    controller.move_card_by_intent.begin("c1", "before", "c2", null);
    assert(wait_for_condition(() => api.list_cards_calls > list_cards_before));
    assert(wait_for_condition(() => triggered));

    assert(api.update_card_position_calls == 1);
    assert(card_selection_requests == 0);
}

private void test_move_card_to_trash_success_emits_toast_and_signal() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool saw_status = false;
    bool saw_toast = false;
    bool saw_trashed = false;
    controller.status_changed.connect((text) => {
        if (text == "Moved card to trash") {
            saw_status = true;
        }
    });
    controller.toast_requested.connect((text) => {
        if (text == "Moved \"Card 1\" to Trash") {
            saw_toast = true;
        }
    });
    controller.card_trashed.connect((card_id) => {
        if (card_id == "c1") {
            saw_trashed = true;
        }
    });
    var list_cards_before = api.list_cards_calls;

    controller.move_card_to_trash.begin("c1");
    assert(wait_for_condition(() => saw_status && saw_toast && saw_trashed));

    assert(api.delete_card_calls == 1);
    assert(api.last_updated_card_id == "c1");
    assert(api.list_cards_calls > list_cards_before);
}

private void test_move_card_to_trash_failure_emits_error() {
    var api = new MainControllerFakeApi();
    api.fail_delete_card = true;
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Move to trash failed" && details.contains("delete card failed")) {
            got_error = true;
        }
    });

    controller.move_card_to_trash.begin("c1");
    assert(wait_for_condition(() => got_error));
    assert(api.delete_card_calls == 0);
}

private void test_move_card_to_trash_without_api_emits_unavailable() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock, null, null, false);
    var controller = harness.controller;

    bool got_error = false;
    controller.error_reported.connect((title, details) => {
        if (title == "Move to trash unavailable"
            && details == "API client is not connected.") {
            got_error = true;
        }
    });

    controller.move_card_to_trash.begin("c1");
    assert(wait_for_condition(() => got_error));
    assert(api.delete_card_calls == 0);
}

private void test_ensure_first_project_without_api_is_noop() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    var harness = make_harness(api, scheduler, clock, null, null, false);
    var controller = harness.controller;

    bool done = false;
    controller.ensure_first_project.begin((obj, res) => {
        controller.ensure_first_project.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(api.list_projects_calls == 0);
    assert(api.create_project_calls == 0);
}

private void test_editor_change_writes_debounced_recovery_snapshot() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var draft_service = new FakeEditorRecoveryDraftService();
    var harness = make_harness(api, scheduler, new FakeClock(), null, null, true, draft_service);
    var controller = harness.controller;
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Recovery Title\n\nExact unsaved text  ";
    controller.on_editor_content_changed();
    scheduler.run_all_once();

    assert(draft_service.save_calls == 1);
    assert(draft_service.last_saved_draft.content == "# Recovery Title\n\nExact unsaved text  ");
    assert(api.update_card_calls == 0);
}

private void test_plaintext_recovery_opt_out_prevents_snapshot() {
    var settings = new Settings("team.holder.Holder");
    settings.set_boolean("no-plaintext-recovery-files", true);
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var draft_service = new FakeEditorRecoveryDraftService();
    var harness = make_harness(api, scheduler, new FakeClock(), null, null, true, draft_service, settings);
    var controller = harness.controller;
    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Private draft";
    controller.on_editor_content_changed();
    scheduler.run_all_once();

    assert(draft_service.save_calls == 0);
    try {
        assert(!controller.save_emergency_recovery_draft());
    } catch (Error e) {
        assert_not_reached();
    }
    controller.autosave_current_card.begin();
    assert(wait_for_condition(() => api.update_card_calls == 1));
    assert(draft_service.save_calls == 0);
    settings.reset("no-plaintext-recovery-files");
}

private void test_loading_card_offers_and_restores_divergent_recovery_draft() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var draft_service = new FakeEditorRecoveryDraftService();
    try {
        draft_service.save_draft(new HolderLinux.EditorRecoveryDraft(
            "c1", "p1", "Recovered", "# Recovered\n\nUnsaved", 999
        ));
    } catch (Error e) {
        assert_not_reached();
    }
    draft_service.save_calls = 0;
    var harness = make_harness(api, scheduler, new FakeClock(), null, null, true, draft_service);
    var controller = harness.controller;
    HolderLinux.EditorRecoveryDraft? offered = null;
    controller.recovery_draft_available.connect((draft) => { offered = draft; });

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => offered != null));
    controller.restore_recovery_draft((!) offered);

    assert(harness.editor_text.value == "# Recovered\n\nUnsaved");
    assert(controller.has_unsaved_editor_changes());
}

private void test_explicit_save_bypasses_debounce_and_reassures_user() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var draft_service = new FakeEditorRecoveryDraftService();
    var harness = make_harness(api, scheduler, new FakeClock(), null, null, true, draft_service);
    var controller = harness.controller;
    string toast = "";
    controller.toast_requested.connect((message) => { toast = message; });

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    harness.editor_text.value = "# Explicit save\n\nLatest text";
    controller.on_editor_content_changed();
    bool completed = false;
    controller.save_now.begin((obj, result) => {
        assert(controller.save_now.end(result));
        completed = true;
    });

    assert(wait_for_condition(() => completed));
    assert(api.update_card_calls == 1);
    assert(api.last_updated_content == "# Explicit save\n\nLatest text");
    assert(draft_service.save_calls >= 1);
    assert(toast == "Card saved");
}

private void test_edit_during_in_flight_save_is_queued_and_newer_draft_survives() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var draft_service = new FakeEditorRecoveryDraftService();
    var harness = make_harness(api, scheduler, new FakeClock(), null, null, true, draft_service);
    var controller = harness.controller;

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    api.update_card_before_complete_hook = (card_id) => {
        if (api.update_card_calls == 1) {
            harness.editor_text.value = "# Second revision\n\nTyped during save";
            controller.on_editor_content_changed();
            controller.autosave_current_card.begin();
        }
    };

    harness.editor_text.value = "# First revision\n\nSaving now";
    controller.on_editor_content_changed();
    controller.autosave_current_card.begin();

    assert(wait_for_condition(() => api.update_card_calls == 2 && !controller.is_editor_save_in_flight()));
    assert(api.last_updated_content == "# Second revision\n\nTyped during save");
    assert(!controller.has_unsaved_editor_changes());
    assert(draft_service.remove_calls == 1);
    assert(!draft_service.drafts.has_key("c1"));
}

private void test_identical_recovery_draft_is_removed_without_prompt() {
    var api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var draft_service = new FakeEditorRecoveryDraftService();
    try {
        draft_service.save_draft(new HolderLinux.EditorRecoveryDraft(
            "c1", "p1", "Card 1", "# Card 1\n\nBody", 999
        ));
    } catch (Error e) {
        assert_not_reached();
    }
    draft_service.save_calls = 0;
    draft_service.remove_calls = 0;
    var harness = make_harness(api, scheduler, new FakeClock(), null, null, true, draft_service);
    var controller = harness.controller;
    bool offered = false;
    controller.recovery_draft_available.connect((draft) => { offered = true; });

    controller.reload_everything.begin();
    assert(wait_for_condition(() => controller.get_current_project() != null));
    harness.card_selection.set_selected_index(0);
    load_selected_card_from_store(controller, harness.card_selection, harness.card_store);
    assert(wait_for_condition(() => controller.get_current_card() != null));

    assert(!offered);
    assert(draft_service.remove_calls == 1);
    assert(!draft_service.drafts.has_key("c1"));
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
        "/main_controller/create_card_uses_selected_project_when_current_project_null",
        test_create_card_uses_selected_project_when_current_project_null
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
        "/main_controller/create_card_with_parent_uses_parent_based_default_title",
        test_create_card_with_parent_uses_parent_based_default_title
    );
    Test.add_func(
        "/main_controller/create_card_with_parent_uses_untitled_when_parent_missing",
        test_create_card_with_parent_uses_untitled_when_parent_missing
    );
    Test.add_func(
        "/main_controller/create_card_with_parent_returns_base_title_when_children_are_unrelated",
        test_create_card_with_parent_returns_base_title_when_children_are_unrelated
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
        "/main_controller/open_search_result_missing_card_falls_back_to_first_card",
        test_open_search_result_missing_card_falls_back_to_first_card
    );
    Test.add_func(
        "/main_controller/open_search_result_reload_failure_returns_null",
        test_open_search_result_reload_failure_returns_null
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
        "/main_controller/clear_search_results_clears_store_and_resets_summary",
        test_clear_search_results_clears_store_and_resets_summary
    );
    Test.add_func(
        "/main_controller/show_resource_references_populates_central_card_results",
        test_show_resource_references_populates_central_card_results
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
        "/main_controller/show_project_overview_zero_timestamps_show_unknown",
        test_show_project_overview_zero_timestamps_show_unknown
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
        "/main_controller/reload_everything_preserves_backend_home_first_order",
        test_reload_everything_preserves_backend_home_first_order
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
        "/main_controller/on_project_selected_without_api_is_noop",
        test_on_project_selected_without_api_is_noop
    );
    Test.add_func(
        "/main_controller/reload_cards_without_selection_keeps_committed_sidebar_state",
        test_reload_cards_without_selection_keeps_committed_sidebar_state
    );
    Test.add_func(
        "/main_controller/on_card_selected_without_selection_does_not_emit_empty_state",
        test_on_card_selected_without_selection_does_not_emit_empty_state
    );
    Test.add_func(
        "/main_controller/on_card_selected_without_selection_keeps_committed_content",
        test_on_card_selected_without_selection_keeps_committed_content
    );
    Test.add_func(
        "/main_controller/on_card_selected_without_api_is_noop",
        test_on_card_selected_without_api_is_noop
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
        "/main_controller/load_selected_card_stale_success_is_ignored",
        test_load_selected_card_stale_success_is_ignored
    );
    Test.add_func(
        "/main_controller/load_selected_card_stale_failure_is_ignored",
        test_load_selected_card_stale_failure_is_ignored
    );
    Test.add_func(
        "/main_controller/load_selected_card_failure_keeps_previous_editor_content",
        test_load_selected_card_failure_keeps_previous_editor_content
    );
    Test.add_func(
        "/main_controller/reload_cards_failure_keeps_previous_committed_state",
        test_reload_cards_failure_keeps_previous_committed_state
    );
    Test.add_func(
        "/main_controller/reload_cards_stale_success_is_ignored",
        test_reload_cards_stale_success_is_ignored
    );
    Test.add_func(
        "/main_controller/reload_cards_stale_failure_is_ignored",
        test_reload_cards_stale_failure_is_ignored
    );
    Test.add_func(
        "/main_controller/valid_card_to_card_transition_does_not_emit_no_card_selected",
        test_valid_card_to_card_transition_does_not_emit_no_card_selected
    );
    Test.add_func(
        "/main_controller/valid_project_to_project_transition_does_not_emit_empty_placeholders",
        test_valid_project_to_project_transition_does_not_emit_empty_placeholders
    );
    Test.add_func(
        "/main_controller/autosave_failure_emits_error",
        test_autosave_failure_emits_error
    );
    Test.add_func(
        "/main_controller/editor_change_emits_unsaved_until_save_confirmation",
        test_editor_change_emits_unsaved_until_save_confirmation
    );
    Test.add_func(
        "/main_controller/autosave_trims_trailing_whitespace_when_settings_enable_it",
        test_autosave_trims_trailing_whitespace_when_settings_enable_it
    );
    Test.add_func(
        "/main_controller/successful_autosave_refreshes_validated_tag_occurrences",
        test_successful_autosave_refreshes_validated_tag_occurrences
    );
    Test.add_func(
        "/main_controller/autosave_failure_keeps_unsaved_save_state",
        test_autosave_failure_keeps_unsaved_save_state
    );
    Test.add_func(
        "/main_controller/autosave_without_api_writes_local_recovery_draft",
        test_autosave_without_api_writes_local_recovery_draft
    );
    Test.add_func(
        "/main_controller/editor_change_writes_debounced_recovery_snapshot",
        test_editor_change_writes_debounced_recovery_snapshot
    );
    Test.add_func(
        "/main_controller/plaintext_recovery_opt_out_prevents_snapshot",
        test_plaintext_recovery_opt_out_prevents_snapshot
    );
    Test.add_func(
        "/main_controller/loading_card_offers_and_restores_divergent_recovery_draft",
        test_loading_card_offers_and_restores_divergent_recovery_draft
    );
    Test.add_func(
        "/main_controller/explicit_save_bypasses_debounce_and_reassures_user",
        test_explicit_save_bypasses_debounce_and_reassures_user
    );
    Test.add_func(
        "/main_controller/edit_during_in_flight_save_is_queued_and_newer_draft_survives",
        test_edit_during_in_flight_save_is_queued_and_newer_draft_survives
    );
    Test.add_func(
        "/main_controller/identical_recovery_draft_is_removed_without_prompt",
        test_identical_recovery_draft_is_removed_without_prompt
    );
    Test.add_func(
        "/main_controller/autosave_failure_keeps_existing_recovery_draft",
        test_autosave_failure_keeps_existing_recovery_draft
    );
    Test.add_func(
        "/main_controller/confirmed_save_removes_recovery_draft",
        test_confirmed_save_removes_recovery_draft
    );
    Test.add_func(
        "/main_controller/autosave_failure_schedules_retry_and_retry_success_clears_dirty_state",
        test_autosave_failure_schedules_retry_and_retry_success_clears_dirty_state
    );
    Test.add_func(
        "/main_controller/new_edit_cancels_pending_autosave_retry",
        test_new_edit_cancels_pending_autosave_retry
    );
    Test.add_func(
        "/main_controller/navigation_change_cancels_stale_autosave_retry",
        test_navigation_change_cancels_stale_autosave_retry
    );
    Test.add_func(
        "/main_controller/background_reload_success_keeps_dirty_editor_state",
        test_background_reload_success_keeps_dirty_editor_state
    );
    Test.add_func(
        "/main_controller/background_reload_failure_keeps_dirty_editor_state",
        test_background_reload_failure_keeps_dirty_editor_state
    );
    Test.add_func(
        "/main_controller/autosave_without_card_is_noop",
        test_autosave_without_card_is_noop
    );
    Test.add_func(
        "/main_controller/autosave_without_unsaved_changes_is_noop",
        test_autosave_without_unsaved_changes_is_noop
    );
    Test.add_func(
        "/main_controller/editor_content_changed_without_current_card_clears_save_state",
        test_editor_content_changed_without_current_card_clears_save_state
    );
    Test.add_func(
        "/main_controller/repeated_autosave_failures_use_backoff_status_and_tiers",
        test_repeated_autosave_failures_use_backoff_status_and_tiers
    );
    Test.add_func(
        "/main_controller/repeated_manual_autosave_failure_replaces_existing_retry_timer",
        test_repeated_manual_autosave_failure_replaces_existing_retry_timer
    );
    Test.add_func(
        "/main_controller/clean_editor_state_cancels_pending_retry_when_view_changes",
        test_clean_editor_state_cancels_pending_retry_when_view_changes
    );
    Test.add_func(
        "/main_controller/retry_callback_resets_attempts_when_editor_is_clean",
        test_retry_callback_resets_attempts_when_editor_is_clean
    );
    Test.add_func(
        "/main_controller/update_selected_card_summary_without_current_card_is_noop",
        test_update_selected_card_summary_without_current_card_is_noop
    );
    Test.add_func(
        "/main_controller/rebuild_card_summaries_handles_null_and_non_target_cards",
        test_rebuild_card_summaries_handles_null_and_non_target_cards
    );
    Test.add_func(
        "/main_controller/compare_cards_for_sidebar_orders_older_last_and_tiebreaks_by_title",
        test_compare_cards_for_sidebar_orders_older_last_and_tiebreaks_by_title
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
        "/main_controller/create_project_starter_card_failure_still_selects_project",
        test_create_project_starter_card_failure_still_selects_project
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
        "/main_controller/list_ai_messages_without_api_throws_no_api_context",
        test_list_ai_messages_without_api_throws_no_api_context
    );
    Test.add_func(
        "/main_controller/list_ai_messages_with_api_passthrough",
        test_list_ai_messages_with_api_passthrough
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
        "/main_controller/move_card_by_intent_success_reloads_and_preserves_selection",
        test_move_card_by_intent_success_reloads_and_preserves_selection
    );
    Test.add_func(
        "/main_controller/move_card_by_intent_failure_emits_error_and_reloads_cards",
        test_move_card_by_intent_failure_emits_error_and_reloads_cards
    );
    Test.add_func(
        "/main_controller/move_card_by_intent_without_api_is_noop",
        test_move_card_by_intent_without_api_is_noop
    );
    Test.add_func(
        "/main_controller/move_card_by_intent_without_selected_project_emits_error",
        test_move_card_by_intent_without_selected_project_emits_error
    );
    Test.add_func(
        "/main_controller/move_card_by_intent_into_emits_toast",
        test_move_card_by_intent_into_emits_toast
    );
    Test.add_func(
        "/main_controller/move_card_by_intent_stale_reload_returns_without_reselecting_card",
        test_move_card_by_intent_stale_reload_returns_without_reselecting_card
    );
    Test.add_func(
        "/main_controller/move_card_to_trash_success_emits_toast_and_signal",
        test_move_card_to_trash_success_emits_toast_and_signal
    );
    Test.add_func(
        "/main_controller/move_card_to_trash_failure_emits_error",
        test_move_card_to_trash_failure_emits_error
    );
    Test.add_func(
        "/main_controller/move_card_to_trash_without_api_emits_unavailable",
        test_move_card_to_trash_without_api_emits_unavailable
    );
    Test.add_func(
        "/main_controller/ensure_first_project_without_api_is_noop",
        test_ensure_first_project_without_api_is_noop
    );

    return Test.run();
}

}
