using GLib;

namespace HolderLinuxTests {

private MainControllerTestHarness make_harness(MainControllerFakeApi api,
                                               bool inject_initial_api = true) {
    var scheduler = new TestScheduler();
    var clock = new FakeClock();
    clock.now_value = 4242;
    return new MainControllerTestHarness(
        api,
        scheduler,
        clock,
        null,
        null,
        inject_initial_api
    );
}

private void select_project(MainControllerTestHarness harness,
                            string project_id = "p1",
                            string name = "Project") {
    harness.project_store.append(new HolderLinux.Project(project_id, name, "encrypted_git", "/tmp", 1, 1));
    harness.project_selection.set_selected_index(0);
}

private void select_card(MainControllerTestHarness harness,
                         string card_id = "c1",
                         string project_id = "p1",
                         string title = "Card 1") {
    harness.card_store.append(
        new HolderLinux.CardSummary(card_id, project_id, title, "cards/%s.md".printf(card_id), 1024.0, null, 1, 1)
    );
    harness.card_selection.set_selected_index(0);
}

private void run_project_selected(HolderLinux.SelectionController controller) {
    bool done = false;
    controller.on_project_selected.begin((obj, res) => {
        controller.on_project_selected.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));
}

private void run_card_selected(HolderLinux.SelectionController controller, string card_id) {
    bool done = false;
    controller.on_card_selected.begin(card_id, (obj, res) => {
        controller.on_card_selected.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));
}

private void test_project_selected_with_no_api_is_noop() {
    var api = new MainControllerFakeApi();
    var harness = make_harness(api, false);
    select_project(harness);
    var controller = new HolderLinux.SelectionController(harness.controller);

    run_project_selected(controller);

    assert(api.list_cards_calls == 0);
    assert(harness.controller.get_current_project() == null);
}

private void test_project_selected_with_no_project_is_noop() {
    var api = new MainControllerFakeApi();
    var harness = make_harness(api);
    var controller = new HolderLinux.SelectionController(harness.controller);

    run_project_selected(controller);

    assert(api.list_cards_calls == 0);
    assert(harness.card_store.get_n_items() == 0);
}

private void test_project_selected_reloads_cards_and_clears_card_selection() {
    var api = new MainControllerFakeApi();
    api.include_card2 = true;
    var harness = make_harness(api);
    select_project(harness, "p1", "Home");
    select_card(harness, "old-card", "p1", "Old Card");
    string? window_title = null;
    string? requested_card_id = "unchanged";
    harness.controller.window_title_changed.connect((title) => {
        window_title = title;
    });
    harness.controller.card_selection_requested.connect((card_id) => {
        requested_card_id = card_id;
    });
    var controller = new HolderLinux.SelectionController(harness.controller);

    run_project_selected(controller);

    assert(api.list_cards_calls == 1);
    assert(api.list_threads_calls == 1);
    assert(harness.controller.get_current_project() != null);
    assert(harness.controller.get_current_project().project_id == "p1");
    assert(window_title == "Home");
    assert(harness.card_store.get_n_items() == 2);
    assert(((HolderLinux.CardSummary) harness.card_store.get_item(0)).card_id == "c2");
    assert(((HolderLinux.CardSummary) harness.card_store.get_item(1)).card_id == "c1");
    assert(requested_card_id == null);
    assert(harness.controller.selected_card_id() == null);
}

private void test_project_selected_reports_reload_error() {
    var api = new MainControllerFakeApi();
    api.fail_list_cards = true;
    api.list_cards_failure_message = "cards unavailable";
    var harness = make_harness(api);
    select_project(harness, "p1", "Home");
    string? error_title = null;
    string? error_details = null;
    harness.controller.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });
    var controller = new HolderLinux.SelectionController(harness.controller);

    run_project_selected(controller);

    assert(api.list_cards_calls == 1);
    assert(error_title == "Failed to load cards");
    assert(error_details == "cards unavailable");
}

private void test_card_selected_with_no_api_is_noop() {
    var api = new MainControllerFakeApi();
    var harness = make_harness(api, false);
    select_project(harness);
    select_card(harness, "c1");
    var controller = new HolderLinux.SelectionController(harness.controller);

    run_card_selected(controller, "c1");

    assert(api.get_card_calls == 0);
    assert(harness.controller.get_current_card() == null);
}

private void test_card_selected_loads_current_selected_card() {
    var api = new MainControllerFakeApi();
    var harness = make_harness(api);
    select_project(harness);
    select_card(harness, "c1");
    string? window_title = null;
    string? editor_text = null;
    bool show_editor = false;
    string? status = null;
    harness.controller.window_title_changed.connect((title) => {
        window_title = title;
    });
    harness.controller.editor_state_changed.connect((text, editable) => {
        editor_text = text;
    });
    harness.controller.show_editor_requested.connect(() => {
        show_editor = true;
    });
    harness.controller.status_changed.connect((text) => {
        status = text;
    });
    var controller = new HolderLinux.SelectionController(harness.controller);

    run_card_selected(controller, "c1");

    assert(api.get_card_calls == 1);
    assert(harness.controller.get_current_card() != null);
    assert(harness.controller.get_current_card().card_id == "c1");
    assert(harness.controller.get_current_card().title == "Card 1");
    assert(editor_text == "# Card 1\n\nBody");
    assert(show_editor);
    assert(window_title == "Card 1");
    assert(status == "Loaded Card 1");
}

private void test_card_selected_discards_result_when_selection_changes() {
    var api = new MainControllerFakeApi();
    var harness = make_harness(api);
    select_project(harness);
    select_card(harness, "c1");
    api.get_card_before_complete_hook = (card_id) => {
        harness.card_selection.set_selected_index(uint.MAX);
    };
    var controller = new HolderLinux.SelectionController(harness.controller);

    run_card_selected(controller, "c1");

    assert(api.get_card_calls == 1);
    assert(harness.controller.get_current_card() == null);
    assert(harness.controller.selected_card_id() == null);
}

private void test_card_selected_reports_load_error_for_still_selected_card() {
    var api = new MainControllerFakeApi();
    api.fail_get_card = true;
    api.get_card_failure_message = "card unavailable";
    var harness = make_harness(api);
    select_project(harness);
    select_card(harness, "c1");
    string? error_title = null;
    string? error_details = null;
    string? status = null;
    harness.controller.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });
    harness.controller.status_changed.connect((text) => {
        status = text;
    });
    var controller = new HolderLinux.SelectionController(harness.controller);

    run_card_selected(controller, "c1");

    assert(api.get_card_calls == 1);
    assert(status == "Failed to load card.");
    assert(error_title == "Failed to load card");
    assert(error_details == "card unavailable");
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/selection/project_selected_with_no_api_is_noop", test_project_selected_with_no_api_is_noop);
    Test.add_func("/selection/project_selected_with_no_project_is_noop", test_project_selected_with_no_project_is_noop);
    Test.add_func(
        "/selection/project_selected_reloads_cards_and_clears_card_selection",
        test_project_selected_reloads_cards_and_clears_card_selection
    );
    Test.add_func("/selection/project_selected_reports_reload_error", test_project_selected_reports_reload_error);
    Test.add_func("/selection/card_selected_with_no_api_is_noop", test_card_selected_with_no_api_is_noop);
    Test.add_func("/selection/card_selected_loads_current_selected_card", test_card_selected_loads_current_selected_card);
    Test.add_func(
        "/selection/card_selected_discards_result_when_selection_changes",
        test_card_selected_discards_result_when_selection_changes
    );
    Test.add_func(
        "/selection/card_selected_reports_load_error_for_still_selected_card",
        test_card_selected_reports_load_error_for_still_selected_card
    );

    return Test.run();
}

}
