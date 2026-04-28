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

private void select_project_and_card(MainControllerTestHarness harness,
                                     string project_id = "p1",
                                     string card_id = "c1",
                                     string summary_title = "Untitled") {
    harness.project_store.append(new HolderLinux.Project(project_id, "Project", "encrypted_git", "/tmp", 1, 1));
    harness.project_selection.set_selected_index(0);
    harness.card_store.append(
        new HolderLinux.CardSummary(card_id, project_id, summary_title, "cards/c1.md", 1024.0, null, 1, 1)
    );
    harness.card_selection.set_selected_index(0);
}

private HolderLinux.NudgeCandidate candidate_with_facts() {
    var facts = new Json.Object();
    facts.set_string_member("title", "Untitled");
    facts.set_boolean_member("body_empty", false);
    facts.set_int_member("body_chars", 120);
    return new HolderLinux.NudgeCandidate(
        "card.title_suggestion",
        "p1",
        "c1",
        111,
        facts,
        "fp-123",
        "commit-123"
    );
}

private HolderLinux.AiNudge nudge() {
    return new HolderLinux.AiNudge(
        "n1",
        "card.title_suggestion",
        "p1",
        "c1",
        "Suggest a title",
        "Pick a title",
        "fp-123",
        "",
        111
    );
}

private void run_evaluate_candidate(HolderLinux.AiNudgeController controller,
                                    HolderLinux.NudgeCandidate candidate) {
    bool done = false;
    controller.evaluate_candidate.begin(candidate, (obj, res) => {
        controller.evaluate_candidate.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));
}

private void run_evaluate_title(HolderLinux.AiNudgeController controller) {
    bool done = false;
    controller.evaluate_title_suggestion_for_current_card.begin((obj, res) => {
        controller.evaluate_title_suggestion_for_current_card.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));
}

private void run_apply_title(HolderLinux.AiNudgeController controller,
                             string nudge_id,
                             string card_id,
                             string title) {
    bool done = false;
    controller.apply_title_suggestion.begin(nudge_id, card_id, title, (obj, res) => {
        controller.apply_title_suggestion.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));
}

private void test_evaluate_candidate_no_api_is_noop() {
    var api = new MainControllerFakeApi();
    var harness = make_harness(api, false);
    var controller = new HolderLinux.AiNudgeController(harness.controller);
    bool logged = false;
    controller.debug_log_requested.connect((message) => {
        logged = true;
    });

    run_evaluate_candidate(controller, candidate_with_facts());

    assert(api.evaluate_nudge_candidate_calls == 0);
    assert(!logged);
}

private void test_evaluate_candidate_logs_and_refreshes_when_nudge_created() {
    var api = new MainControllerFakeApi();
    api.next_nudge_result = new HolderLinux.NudgeEvaluationResult(
        "card.title_suggestion",
        true,
        true,
        "title_suggestion_candidate_ready",
        nudge()
    );
    var harness = make_harness(api);
    var controller = new HolderLinux.AiNudgeController(harness.controller);
    var logs = new Gee.ArrayList<string>();
    string? refresh_project_id = null;
    string? refresh_card_id = null;
    controller.debug_log_requested.connect((message) => {
        logs.add(message);
    });
    controller.nudges_refresh_requested.connect((project_id, card_id) => {
        refresh_project_id = project_id;
        refresh_card_id = card_id;
    });

    run_evaluate_candidate(controller, candidate_with_facts());

    assert(api.evaluate_nudge_candidate_calls == 1);
    assert(api.last_nudge_kind == "card.title_suggestion");
    assert(api.last_nudge_project_id == "p1");
    assert(api.last_nudge_card_id == "c1");
    assert(api.last_nudge_created_at == 111);
    assert(api.last_nudge_basis_fingerprint == "fp-123");
    assert(api.last_nudge_basis_commit == "commit-123");
    assert(api.last_nudge_facts != null);
    assert(((Json.Object) api.last_nudge_facts).get_string_member("title") == "Untitled");
    assert(logs.size == 2);
    assert(logs[0].contains("CANDIDATE card.title_suggestion"));
    assert(logs[0].contains("project=p1"));
    assert(logs[0].contains("card=c1"));
    assert(logs[0].contains("fingerprint=fp-123"));
    assert(logs[0].contains("commit=commit-123"));
    assert(logs[0].contains("\"body_chars\":120"));
    assert(logs[1] == "NUDGE_EVAL card.title_suggestion accepted=true should_nudge=true reason=title_suggestion_candidate_ready");
    assert(refresh_project_id == "p1");
    assert(refresh_card_id == "c1");
}

private void test_evaluate_candidate_without_nudge_does_not_refresh() {
    var api = new MainControllerFakeApi();
    api.next_nudge_result = new HolderLinux.NudgeEvaluationResult(
        "card.title_suggestion",
        true,
        false,
        "title_suggestion_not_actionable"
    );
    var harness = make_harness(api);
    var controller = new HolderLinux.AiNudgeController(harness.controller);
    bool refreshed = false;
    controller.nudges_refresh_requested.connect((project_id, card_id) => {
        refreshed = true;
    });

    run_evaluate_candidate(controller, candidate_with_facts());

    assert(api.evaluate_nudge_candidate_calls == 1);
    assert(!refreshed);
}

private void test_evaluate_candidate_error_logs_error() {
    var api = new MainControllerFakeApi();
    api.fail_evaluate_nudge_candidate = true;
    var harness = make_harness(api);
    var controller = new HolderLinux.AiNudgeController(harness.controller);
    string last_log = "";
    controller.debug_log_requested.connect((message) => {
        last_log = message;
    });

    run_evaluate_candidate(controller, candidate_with_facts());

    assert(api.evaluate_nudge_candidate_calls == 0);
    assert(last_log == "NUDGE_EVAL_ERROR card.title_suggestion evaluate nudge failed");
}

private void test_title_suggestion_candidate_noops_for_missing_context() {
    var api = new MainControllerFakeApi();
    var harness = make_harness(api);
    var controller = new HolderLinux.AiNudgeController(harness.controller);

    run_evaluate_title(controller);
    assert(api.evaluate_nudge_candidate_calls == 0);

    harness.controller.current_card = new HolderLinux.CardDetail(
        "c1",
        "p1",
        "Untitled",
        "# Untitled\n\nThis body is long enough to be a candidate for title suggestion.",
        1
    );
    run_evaluate_title(controller);
    assert(api.evaluate_nudge_candidate_calls == 0);
}

private void test_title_suggestion_candidate_rejects_non_actionable_cards() {
    var api = new MainControllerFakeApi();
    var harness = make_harness(api);
    select_project_and_card(harness);
    var controller = new HolderLinux.AiNudgeController(harness.controller);

    harness.controller.current_card = new HolderLinux.CardDetail(
        "other",
        "p1",
        "Untitled",
        "# Untitled\n\nThis body is long enough to be a candidate for title suggestion.",
        1
    );
    run_evaluate_title(controller);
    assert(api.evaluate_nudge_candidate_calls == 0);

    harness.controller.current_card = new HolderLinux.CardDetail(
        "c1",
        "p1",
        "Real title",
        "# Real title\n\nThis body is long enough to be a candidate for title suggestion.",
        1
    );
    run_evaluate_title(controller);
    assert(api.evaluate_nudge_candidate_calls == 0);

    harness.controller.current_card = new HolderLinux.CardDetail("c1", "p1", "Untitled", "# Untitled", 1);
    run_evaluate_title(controller);
    assert(api.evaluate_nudge_candidate_calls == 0);

    harness.controller.current_card = new HolderLinux.CardDetail("c1", "p1", "Untitled", "# Untitled\n", 1);
    run_evaluate_title(controller);
    assert(api.evaluate_nudge_candidate_calls == 0);

    harness.controller.current_card = new HolderLinux.CardDetail("c1", "p1", "Untitled", "# Untitled\n   \n", 1);
    run_evaluate_title(controller);
    assert(api.evaluate_nudge_candidate_calls == 0);

    harness.controller.current_card = new HolderLinux.CardDetail("c1", "p1", "Untitled", "# Untitled\nshort", 1);
    run_evaluate_title(controller);
    assert(api.evaluate_nudge_candidate_calls == 0);
}

private void test_title_suggestion_candidate_evaluates_current_placeholder_card() {
    var api = new MainControllerFakeApi();
    api.next_nudge_result = new HolderLinux.NudgeEvaluationResult(
        "card.title_suggestion",
        true,
        true,
        "title_suggestion_candidate_ready",
        nudge()
    );
    var harness = make_harness(api);
    select_project_and_card(harness, "p1", "c1", "Untitled draft");
    var content = "# Untitled draft\n\nThis body has enough detail to produce a useful title suggestion candidate.";
    harness.controller.current_card = new HolderLinux.CardDetail("c1", "p1", "  Untitled draft  ", content, 1);
    var controller = new HolderLinux.AiNudgeController(harness.controller);

    run_evaluate_title(controller);

    assert(api.evaluate_nudge_candidate_calls == 1);
    assert(api.last_nudge_kind == "card.title_suggestion");
    assert(api.last_nudge_project_id == "p1");
    assert(api.last_nudge_card_id == "c1");
    assert(api.last_nudge_created_at == 4242);
    assert(api.last_nudge_basis_fingerprint == Checksum.compute_for_string(ChecksumType.SHA256, content).substring(0, 12));
    assert(api.last_nudge_basis_commit == null);
    assert(api.last_nudge_facts != null);
    var facts = (Json.Object) api.last_nudge_facts;
    assert(facts.get_string_member("title") == "  Untitled draft  ");
    assert(!facts.get_boolean_member("body_empty"));
    assert(facts.get_int_member("doc_chars") == content.char_count());
    assert(facts.get_int_member("body_chars") == content.substring(content.index_of_char('\n') + 1).char_count());
}

private void test_apply_title_suggestion_skips_stale_or_empty_context() {
    var api = new MainControllerFakeApi();
    var harness = make_harness(api);
    select_project_and_card(harness);
    harness.controller.current_card = new HolderLinux.CardDetail("c1", "p1", "Untitled", "# Untitled\n\nBody", 1);
    var controller = new HolderLinux.AiNudgeController(harness.controller);
    var logs = new Gee.ArrayList<string>();
    controller.debug_log_requested.connect((message) => {
        logs.add(message);
    });

    run_apply_title(controller, "n1", "other", "New title");
    run_apply_title(controller, "n1", "c1", "   ");

    assert(api.update_card_calls == 0);
    assert(api.dismiss_ai_nudge_calls == 0);
    assert(logs.size == 2);
    assert(logs[0] == "TITLE_SUGGESTION_APPLY_SKIPPED stale_or_missing_context");
    assert(logs[1] == "TITLE_SUGGESTION_APPLY_SKIPPED stale_or_missing_context");
}

private void test_apply_title_suggestion_replaces_existing_heading_and_updates_state() {
    var api = new MainControllerFakeApi();
    var harness = make_harness(api);
    select_project_and_card(harness);
    harness.controller.current_card = new HolderLinux.CardDetail(
        "c1",
        "p1",
        "Untitled",
        "\n\n# Untitled\n\nOriginal body",
        1
    );
    var controller = new HolderLinux.AiNudgeController(harness.controller);
    string? refresh_project_id = null;
    string? refresh_card_id = null;
    string? window_title = null;
    string? save_state = null;
    string? editor_text = null;
    string? activity_kind = null;
    string? activity_message = null;
    string? activity_project_id = null;
    string? activity_card_id = null;
    controller.nudges_refresh_requested.connect((project_id, card_id) => {
        refresh_project_id = project_id;
        refresh_card_id = card_id;
    });
    harness.controller.window_title_changed.connect((title) => {
        window_title = title;
    });
    harness.controller.editor_save_state_changed.connect((text) => {
        save_state = text;
    });
    harness.controller.editor_state_changed.connect((text, editable) => {
        editor_text = text;
    });
    harness.controller.activity_requested.connect((kind, message, project_id, card_id, details) => {
        activity_kind = kind;
        activity_message = message;
        activity_project_id = project_id;
        activity_card_id = card_id;
    });

    run_apply_title(controller, "n1", "c1", "  Thread Roles in Holder  ");

    assert(api.update_card_calls == 1);
    assert(api.last_updated_card_id == "c1");
    assert(api.last_updated_title == "Thread Roles in Holder");
    assert(api.last_updated_content == "\n\n# Thread Roles in Holder\n\nOriginal body");
    assert(api.last_updated_at == 4242);
    assert(api.dismiss_ai_nudge_calls == 1);
    assert(api.last_dismissed_nudge_id == "n1");
    assert(harness.controller.get_current_card().title == "Thread Roles in Holder");
    assert(harness.controller.get_current_card().content == "\n\n# Thread Roles in Holder\n\nOriginal body");
    assert(harness.controller.get_current_card().updated_at == 4242);
    assert(((HolderLinux.CardSummary) harness.card_store.get_item(0)).title == "Thread Roles in Holder");
    assert(((HolderLinux.CardSummary) harness.card_store.get_item(0)).updated_at == 4242);
    assert(window_title == "Thread Roles in Holder");
    assert(save_state == "Saved");
    assert(editor_text == "\n\n# Thread Roles in Holder\n\nOriginal body");
    assert(refresh_project_id == "p1");
    assert(refresh_card_id == "c1");
    assert(activity_kind == "result.card.title_suggestion_apply");
    assert(activity_message == "Applied title suggestion: Thread Roles in Holder");
    assert(activity_project_id == "p1");
    assert(activity_card_id == "c1");
}

private void test_apply_title_suggestion_prepends_heading_when_missing() {
    var api = new MainControllerFakeApi();
    var harness = make_harness(api);
    select_project_and_card(harness);
    harness.controller.current_card = new HolderLinux.CardDetail("c1", "p1", "Untitled", "Original body", 1);
    var controller = new HolderLinux.AiNudgeController(harness.controller);

    run_apply_title(controller, "n1", "c1", "New Card Title");

    assert(api.update_card_calls == 1);
    assert(api.last_updated_content == "# New Card Title\n\nOriginal body");
}

private void test_apply_title_suggestion_reports_update_error() {
    var api = new MainControllerFakeApi();
    api.fail_update_card = true;
    var harness = make_harness(api);
    select_project_and_card(harness);
    harness.controller.current_card = new HolderLinux.CardDetail("c1", "p1", "Untitled", "# Untitled\n\nBody", 1);
    var controller = new HolderLinux.AiNudgeController(harness.controller);
    string? error_title = null;
    string? error_details = null;
    string last_log = "";
    harness.controller.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });
    controller.debug_log_requested.connect((message) => {
        last_log = message;
    });

    run_apply_title(controller, "n1", "c1", "New Card Title");

    assert(api.update_card_calls == 0);
    assert(api.dismiss_ai_nudge_calls == 0);
    assert(error_title == "Title suggestion failed");
    assert(error_details == "update failed");
    assert(last_log == "TITLE_SUGGESTION_APPLY_ERROR update failed");
}

private void test_apply_title_suggestion_reports_dismiss_error_after_update() {
    var api = new MainControllerFakeApi();
    api.fail_dismiss_ai_nudge = true;
    var harness = make_harness(api);
    select_project_and_card(harness);
    harness.controller.current_card = new HolderLinux.CardDetail("c1", "p1", "Untitled", "# Untitled\n\nBody", 1);
    var controller = new HolderLinux.AiNudgeController(harness.controller);
    string? error_title = null;
    string last_log = "";
    harness.controller.error_reported.connect((title, details) => {
        error_title = title;
    });
    controller.debug_log_requested.connect((message) => {
        last_log = message;
    });

    run_apply_title(controller, "n1", "c1", "New Card Title");

    assert(api.update_card_calls == 1);
    assert(api.dismiss_ai_nudge_calls == 0);
    assert(error_title == "Title suggestion failed");
    assert(last_log == "TITLE_SUGGESTION_APPLY_ERROR dismiss nudge failed");
}

private void test_main_controller_load_card_by_id_path_is_used_by_target() {
    var api = new MainControllerFakeApi();
    var harness = make_harness(api);
    select_project_and_card(harness);
    bool done = false;

    harness.controller.load_card_by_id.begin("c1", true, (obj, res) => {
        harness.controller.load_card_by_id.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(api.get_card_calls == 1);
    assert(harness.controller.get_current_card() != null);
    assert(harness.controller.get_current_card().card_id == "c1");
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/ai_nudge/evaluate_candidate_no_api_is_noop", test_evaluate_candidate_no_api_is_noop);
    Test.add_func(
        "/ai_nudge/evaluate_candidate_logs_and_refreshes_when_nudge_created",
        test_evaluate_candidate_logs_and_refreshes_when_nudge_created
    );
    Test.add_func(
        "/ai_nudge/evaluate_candidate_without_nudge_does_not_refresh",
        test_evaluate_candidate_without_nudge_does_not_refresh
    );
    Test.add_func("/ai_nudge/evaluate_candidate_error_logs_error", test_evaluate_candidate_error_logs_error);
    Test.add_func(
        "/ai_nudge/title_suggestion_candidate_noops_for_missing_context",
        test_title_suggestion_candidate_noops_for_missing_context
    );
    Test.add_func(
        "/ai_nudge/title_suggestion_candidate_rejects_non_actionable_cards",
        test_title_suggestion_candidate_rejects_non_actionable_cards
    );
    Test.add_func(
        "/ai_nudge/title_suggestion_candidate_evaluates_current_placeholder_card",
        test_title_suggestion_candidate_evaluates_current_placeholder_card
    );
    Test.add_func(
        "/ai_nudge/apply_title_suggestion_skips_stale_or_empty_context",
        test_apply_title_suggestion_skips_stale_or_empty_context
    );
    Test.add_func(
        "/ai_nudge/apply_title_suggestion_replaces_existing_heading_and_updates_state",
        test_apply_title_suggestion_replaces_existing_heading_and_updates_state
    );
    Test.add_func(
        "/ai_nudge/apply_title_suggestion_prepends_heading_when_missing",
        test_apply_title_suggestion_prepends_heading_when_missing
    );
    Test.add_func(
        "/ai_nudge/apply_title_suggestion_reports_update_error",
        test_apply_title_suggestion_reports_update_error
    );
    Test.add_func(
        "/ai_nudge/apply_title_suggestion_reports_dismiss_error_after_update",
        test_apply_title_suggestion_reports_dismiss_error_after_update
    );
    Test.add_func(
        "/ai_nudge/main_controller_load_card_by_id_path_is_used_by_target",
        test_main_controller_load_card_by_id_path_is_used_by_target
    );

    return Test.run();
}

}
