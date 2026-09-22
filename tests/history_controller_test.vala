using GLib;

namespace HolderLinuxTests {

public delegate void HistoryApiHook();

private class FakeHistoryApi : Object, HolderLinux.IHistoryApi, HolderLinux.IProjectHistoryApi {
    public int calls { get; set; default = 0; }
    public HolderLinux.CardHistoryPage? card_page = null;
    public HolderLinux.ProjectHistoryPage? project_page = null;
    public HolderLinux.CardHistoryComparison? comparison = null;
    public Error? card_error = null;
    public Error? project_error = null;
    public Error? compare_error = null;
    public Error? restore_error = null;
    public HistoryApiHook? hook = null;

    public string? last_project_id = null;
    public string? last_card_id = null;
    public int last_limit = 0;
    public string? last_cursor = null;
    public string? last_kind = null;
    public string? last_from = null;
    public string? last_to = null;
    public string? last_mode = null;
    public string? last_restored_oid = null;

    private void run_hook() {
        if (hook != null) ((!) hook)();
    }

    public async HolderLinux.CardHistoryPage list_card_history(string project_id,
                                                               string card_id,
                                                               int limit = 50,
                                                               string? cursor = null) throws Error {
        calls++;
        last_project_id = project_id;
        last_card_id = card_id;
        last_limit = limit;
        last_cursor = cursor;
        run_hook();
        if (card_error != null) throw card_error;
        return (!) card_page;
    }

    public async HolderLinux.CardHistoryComparison compare_card_history(string project_id,
                                                                        string card_id,
                                                                        string? from_oid,
                                                                        string to_oid,
                                                                        string mode = "since") throws Error {
        calls++;
        last_project_id = project_id;
        last_card_id = card_id;
        last_from = from_oid;
        last_to = to_oid;
        last_mode = mode;
        run_hook();
        if (compare_error != null) throw compare_error;
        return (!) comparison;
    }

    public async bool restore_card_history(string project_id, string card_id, string oid) throws Error {
        calls++;
        last_project_id = project_id;
        last_card_id = card_id;
        last_restored_oid = oid;
        run_hook();
        if (restore_error != null) throw restore_error;
        return true;
    }

    public async HolderLinux.ProjectHistoryPage list_project_history(string project_id,
                                                                     int limit = 50,
                                                                     string? cursor = null,
                                                                     string? kind = null) throws Error {
        calls++;
        last_project_id = project_id;
        last_limit = limit;
        last_cursor = cursor;
        last_kind = kind;
        run_hook();
        if (project_error != null) throw project_error;
        return (!) project_page;
    }
}

private class FakeScope : Object, HolderLinux.IHistoryScope {
    public HolderLinux.Project? project { get; set; }
    public HolderLinux.CardSummary? card { get; set; }

    public FakeScope() {
        project = make_project("p1");
        card = make_card("p1", "c1");
    }

    public HolderLinux.Project? current_project() {
        return project;
    }

    public HolderLinux.CardSummary? current_card() {
        return card;
    }
}

private HolderLinux.Project make_project(string id) {
    return new HolderLinux.Project(id, "Project " + id, "encrypted_git", "/tmp/" + id, 1, 1);
}

private HolderLinux.CardSummary make_card(string project_id, string card_id) {
    return new HolderLinux.CardSummary(card_id, project_id, "Card " + card_id, card_id + ".md", 1.0, null, 1, 1);
}

private HolderLinux.CardHistoryEntry entry_named(string oid, string[] parents = {}) {
    return new HolderLinux.CardHistoryEntry(
        oid, oid, parents, "Ada", "ada@example.test", 1000, 2000, "updated", "Edited", 1, false
    );
}

private HolderLinux.CardHistoryPage page_with(string? head,
                                              string? cursor = null,
                                              bool scan_limited = false) {
    return new HolderLinux.CardHistoryPage(head, { entry_named("head"), entry_named("older") }, cursor, scan_limited);
}

private HolderLinux.CardHistoryComparison make_comparison() {
    return new HolderLinux.CardHistoryComparison(
        new HolderLinux.CardHistoryVersion(true, "from", "Old", "old"),
        new HolderLinux.CardHistoryVersion(true, "to", "New", "new"),
        "summary",
        { new HolderLinux.CardHistoryDiffLine("+", "x", null, 1) },
        false
    );
}

// ---- async helpers ----

private HolderLinux.CardHistoryLoad run_load_card(HolderLinux.HistoryController controller,
                                                  FakeHistoryApi api,
                                                  uint serial) {
    HolderLinux.CardHistoryLoad? result = null;
    controller.load_card_page.begin(api, "p1", "c1", serial, (obj, res) => {
        result = controller.load_card_page.end(res);
    });
    assert(wait_for_condition(() => result != null));
    return (!) result;
}

private HolderLinux.ProjectHistoryLoad run_load_project(HolderLinux.HistoryController controller,
                                                        FakeHistoryApi api,
                                                        uint serial) {
    HolderLinux.ProjectHistoryLoad? result = null;
    controller.load_project_page.begin(api, "p1", "card", serial, (obj, res) => {
        result = controller.load_project_page.end(res);
    });
    assert(wait_for_condition(() => result != null));
    return (!) result;
}

private HolderLinux.HistoryComparisonLoad run_comparison(HolderLinux.HistoryController controller,
                                                         FakeHistoryApi api,
                                                         FakeScope scope,
                                                         HolderLinux.CardHistoryEntry entry,
                                                         HolderLinux.HistoryComparisonPlan plan,
                                                         uint serial) {
    HolderLinux.HistoryComparisonLoad? result = null;
    controller.load_comparison.begin(api, scope, entry, plan, serial, (obj, res) => {
        result = controller.load_comparison.end(res);
    });
    assert(wait_for_condition(() => result != null));
    return (!) result;
}

private HolderLinux.HistoryRestoreResult run_restore(HolderLinux.HistoryController controller,
                                                     FakeHistoryApi api,
                                                     FakeScope scope,
                                                     HolderLinux.HistoryRestorePlan plan) {
    HolderLinux.HistoryRestoreResult? result = null;
    controller.restore_version.begin(api, scope, plan, (obj, res) => {
        result = controller.restore_version.end(res);
    });
    assert(wait_for_condition(() => result != null));
    return (!) result;
}

private HolderLinux.HistoryOlderResult run_older(HolderLinux.HistoryController controller,
                                                 FakeHistoryApi api,
                                                 FakeScope scope,
                                                 HolderLinux.HistoryOlderPlan plan) {
    HolderLinux.HistoryOlderResult? result = null;
    controller.load_older.begin(api, scope, plan, (obj, res) => {
        result = controller.load_older.end(res);
    });
    assert(wait_for_condition(() => result != null));
    return (!) result;
}

private HolderLinux.ProjectHistoryOlderResult run_older_project(HolderLinux.HistoryController controller,
                                                                FakeHistoryApi api,
                                                                string cursor) {
    HolderLinux.ProjectHistoryOlderResult? result = null;
    controller.load_older_project.begin(api, "p1", cursor, "resource", (obj, res) => {
        result = controller.load_older_project.end(res);
    });
    assert(wait_for_condition(() => result != null));
    return (!) result;
}

// Loads a card page so the controller has a head and cursor to work with.
private HolderLinux.HistoryController primed_controller(FakeHistoryApi api, string? cursor = "cursor-1") {
    var controller = new HolderLinux.HistoryController();
    api.card_page = page_with("head", cursor);
    var load = run_load_card(controller, api, controller.begin_refresh());
    assert(!load.stale && load.error_message == null);
    return controller;
}

// ---- refresh planning ----

private void test_plan_refresh_covers_every_selection_state() {
    var project = make_project("p1");
    var same_project_card = make_card("p1", "c1");
    var other_project_card = make_card("p2", "c2");

    assert(HolderLinux.HistoryController.plan_refresh(null, null, true, true)
           == HolderLinux.HistoryRefreshPlan.NO_PROJECT);
    assert(HolderLinux.HistoryController.plan_refresh(project, null, true, true)
           == HolderLinux.HistoryRefreshPlan.LOAD_PROJECT);
    assert(HolderLinux.HistoryController.plan_refresh(project, other_project_card, true, true)
           == HolderLinux.HistoryRefreshPlan.LOAD_PROJECT);
    assert(HolderLinux.HistoryController.plan_refresh(project, null, true, false)
           == HolderLinux.HistoryRefreshPlan.PROJECT_UNAVAILABLE);
    assert(HolderLinux.HistoryController.plan_refresh(project, same_project_card, true, false)
           == HolderLinux.HistoryRefreshPlan.LOAD_CARD);
    assert(HolderLinux.HistoryController.plan_refresh(project, same_project_card, false, true)
           == HolderLinux.HistoryRefreshPlan.CARD_UNAVAILABLE);
}

// ---- project page ----

private void test_project_page_load_stores_cursor_and_reports_it() {
    var api = new FakeHistoryApi();
    api.project_page = new HolderLinux.ProjectHistoryPage("headhead1234", {}, "next");
    var controller = new HolderLinux.HistoryController();
    var load = run_load_project(controller, api, controller.begin_refresh());
    assert(!load.stale && load.error_message == null && load.page != null);
    assert(controller.project_next_cursor == "next");
    assert(load.debug_line == "Project history loaded: 0 activities at headhead");
    assert(api.last_limit == 50 && api.last_cursor == null && api.last_kind == "card");

    controller.reset_project_timeline();
    assert(controller.project_next_cursor == null);
}

private void test_project_page_load_reports_errors() {
    var api = new FakeHistoryApi();
    api.project_error = new IOError.FAILED("project boom");
    var controller = new HolderLinux.HistoryController();
    var load = run_load_project(controller, api, controller.begin_refresh());
    assert(!load.stale && load.page == null && load.error_message == "project boom");
}

private void test_project_page_load_drops_stale_answers() {
    var api = new FakeHistoryApi();
    api.project_page = new HolderLinux.ProjectHistoryPage("h", {}, "next");
    var controller = new HolderLinux.HistoryController();
    api.hook = () => { controller.begin_refresh(); };
    var stale_success = run_load_project(controller, api, controller.begin_refresh());
    assert(stale_success.stale && stale_success.page == null);
    assert(controller.project_next_cursor == null);

    api.project_error = new IOError.FAILED("late failure");
    var stale_failure = run_load_project(controller, api, controller.begin_refresh());
    assert(stale_failure.stale && stale_failure.error_message == null);
}

// ---- card page ----

private void test_card_page_load_captures_head_and_paging_state() {
    var api = new FakeHistoryApi();
    api.card_page = page_with("head", "cursor-1", true);
    var controller = new HolderLinux.HistoryController();
    var load = run_load_card(controller, api, controller.begin_refresh());
    assert(!load.stale && load.error_message == null && load.page.entries.length == 2);
    assert(controller.captured_head_oid == "head");
    assert(controller.next_cursor == "cursor-1");
    assert(controller.scan_limited);
    assert(load.debug_line == "History loaded: 2 entries at head; continue scanning older history");
    assert(api.last_project_id == "p1" && api.last_card_id == "c1");

    controller.reset_card_timeline();
    assert(controller.captured_head_oid == null && controller.next_cursor == null && !controller.scan_limited);
}

private void test_card_page_load_error_resets_state() {
    var api = new FakeHistoryApi();
    var controller = primed_controller(api);
    api.card_error = new IOError.FAILED("card boom");
    var load = run_load_card(controller, api, controller.begin_refresh());
    assert(!load.stale && load.page == null && load.error_message == "card boom");
    assert(load.debug_line == "History load failed: card boom");
    assert(controller.captured_head_oid == null && controller.next_cursor == null);
}

private void test_card_page_load_drops_stale_answers() {
    var api = new FakeHistoryApi();
    api.card_page = page_with("head", "cursor-1");
    var controller = new HolderLinux.HistoryController();
    api.hook = () => { controller.begin_refresh(); };
    var stale_success = run_load_card(controller, api, controller.begin_refresh());
    assert(stale_success.stale);
    assert(controller.captured_head_oid == null);

    api.card_error = new IOError.FAILED("late failure");
    var stale_failure = run_load_card(controller, api, controller.begin_refresh());
    assert(stale_failure.stale && stale_failure.error_message == null);
}

// ---- comparison ----

private void test_begin_comparison_remembers_the_entry_and_advances_the_serial() {
    var controller = new HolderLinux.HistoryController();
    var first = entry_named("a");
    var second = entry_named("b");
    var first_serial = controller.begin_comparison(first);
    assert(controller.detail_entry == first);
    var second_serial = controller.begin_comparison(second);
    assert(controller.detail_entry == second && second_serial == first_serial + 1);
}

private void test_plan_comparison_skips_without_the_needed_context() {
    var api = new FakeHistoryApi();
    var controller = new HolderLinux.HistoryController();
    var scope = new FakeScope();
    var entry = entry_named("older");
    var mode = HolderLinux.HistoryComparisonMode.SINCE;

    // No captured head yet.
    assert(controller.plan_comparison(scope, true, entry, mode).kind == HolderLinux.HistoryComparisonKind.SKIP);

    controller = primed_controller(api);
    assert(controller.plan_comparison(scope, false, entry, mode).kind == HolderLinux.HistoryComparisonKind.SKIP);
    scope.card = null;
    assert(controller.plan_comparison(scope, true, entry, mode).kind == HolderLinux.HistoryComparisonKind.SKIP);
    scope.card = make_card("p1", "c1");
    scope.project = null;
    assert(controller.plan_comparison(scope, true, entry, mode).kind == HolderLinux.HistoryComparisonKind.SKIP);
}

private void test_plan_comparison_resolves_endpoints_and_current_version() {
    var api = new FakeHistoryApi();
    var controller = primed_controller(api);
    var scope = new FakeScope();
    var older = entry_named("older", { "parent" });

    var since = controller.plan_comparison(scope, true, older, HolderLinux.HistoryComparisonMode.SINCE);
    assert(since.kind == HolderLinux.HistoryComparisonKind.LOAD);
    assert(since.from_oid == "older" && since.to_oid == "head" && since.head_oid == "head");
    assert(since.project_id == "p1" && since.card_id == "c1");

    var change = controller.plan_comparison(scope, true, older, HolderLinux.HistoryComparisonMode.CHANGE);
    assert(change.from_oid == "parent" && change.to_oid == "older");

    var current = controller.plan_comparison(scope, true, entry_named("head"), HolderLinux.HistoryComparisonMode.SINCE);
    assert(current.kind == HolderLinux.HistoryComparisonKind.CURRENT_VERSION);
}

private void test_load_comparison_returns_detail_and_debug_line() {
    var api = new FakeHistoryApi();
    var controller = primed_controller(api);
    var scope = new FakeScope();
    var entry = entry_named("older");
    var plan = controller.plan_comparison(scope, true, entry, HolderLinux.HistoryComparisonMode.VERSION);
    api.comparison = make_comparison();
    var serial = controller.begin_comparison(entry);

    var load = run_comparison(controller, api, scope, entry, plan, serial);
    assert(!load.stale && !load.failed && load.comparison != null);
    assert(load.detail.title == "New");
    assert(load.debug_line == "History compared older to older (version; 1 lines)");
    assert(api.last_from == "older" && api.last_to == "older" && api.last_mode == "since");
}

private void test_load_comparison_drops_results_for_a_moved_selection() {
    var api = new FakeHistoryApi();
    var controller = primed_controller(api);
    var scope = new FakeScope();
    var entry = entry_named("older");
    var plan = controller.plan_comparison(scope, true, entry, HolderLinux.HistoryComparisonMode.SINCE);
    api.comparison = make_comparison();

    // A newer comparison request supersedes this one.
    api.hook = () => { controller.begin_comparison(entry); };
    assert(run_comparison(controller, api, scope, entry, plan, controller.begin_comparison(entry)).stale);

    // The card changed while the request was in flight.
    api.hook = () => { scope.card = make_card("p1", "other"); };
    assert(run_comparison(controller, api, scope, entry, plan, controller.begin_comparison(entry)).stale);
    scope.card = make_card("p1", "c1");

    // The project went away.
    api.hook = () => { scope.project = null; };
    assert(run_comparison(controller, api, scope, entry, plan, controller.begin_comparison(entry)).stale);
    scope.project = make_project("p1");

    // The card went away.
    api.hook = () => { scope.card = null; };
    assert(run_comparison(controller, api, scope, entry, plan, controller.begin_comparison(entry)).stale);
    scope.card = make_card("p1", "c1");

    // The project changed to another one.
    api.hook = () => { scope.project = make_project("p2"); };
    assert(run_comparison(controller, api, scope, entry, plan, controller.begin_comparison(entry)).stale);
    scope.project = make_project("p1");

    // The captured head changed (the card page was reloaded) without a newer comparison
    // request. Reloading with the current refresh serial leaves the comparison serial alone.
    var refresh_serial = controller.begin_refresh();
    var comparison_serial = controller.begin_comparison(entry);
    api.hook = () => {
        api.hook = null;
        api.card_page = page_with("new-head");
        run_load_card(controller, api, refresh_serial);
    };
    assert(run_comparison(controller, api, scope, entry, plan, comparison_serial).stale);
    assert(controller.captured_head_oid == "new-head");
}

private void test_load_comparison_failure_is_reported_unless_stale() {
    var api = new FakeHistoryApi();
    var controller = primed_controller(api);
    var scope = new FakeScope();
    var entry = entry_named("older");
    var plan = controller.plan_comparison(scope, true, entry, HolderLinux.HistoryComparisonMode.SINCE);
    api.compare_error = new IOError.FAILED("compare boom");

    var failed = run_comparison(controller, api, scope, entry, plan, controller.begin_comparison(entry));
    assert(!failed.stale && failed.failed && failed.comparison == null);
    assert(failed.detail.title == "Could not compare this version" && failed.detail.meta == "compare boom");
    assert(failed.debug_line == "History comparison failed: compare boom");

    api.hook = () => { controller.begin_comparison(entry); };
    assert(run_comparison(controller, api, scope, entry, plan, controller.begin_comparison(entry)).stale);
}

// ---- restore ----

private void test_plan_restore_needs_api_project_and_card() {
    var controller = new HolderLinux.HistoryController();
    var scope = new FakeScope();
    var plan = controller.plan_restore(scope, true, "oid");
    assert(plan != null && plan.project_id == "p1" && plan.card_id == "c1" && plan.oid == "oid");
    assert(controller.plan_restore(scope, false, "oid") == null);
    scope.card = null;
    assert(controller.plan_restore(scope, true, "oid") == null);
    scope.card = make_card("p1", "c1");
    scope.project = null;
    assert(controller.plan_restore(scope, true, "oid") == null);
}

private void test_restore_reports_success() {
    var api = new FakeHistoryApi();
    var controller = new HolderLinux.HistoryController();
    var scope = new FakeScope();
    var result = run_restore(controller, api, scope, (!) controller.plan_restore(scope, true, "0123456789"));
    assert(result.outcome == HolderLinux.HistoryRestoreOutcome.RESTORED);
    assert(result.project_id == "p1" && result.card_id == "c1");
    assert(result.debug_line == "History restored 01234567");
    assert(api.last_restored_oid == "0123456789");
}

private void test_restore_is_dropped_when_the_selection_moved() {
    var api = new FakeHistoryApi();
    var controller = new HolderLinux.HistoryController();
    var scope = new FakeScope();
    var plan = (!) controller.plan_restore(scope, true, "oid");

    api.hook = () => { scope.card = make_card("p1", "other"); };
    assert(run_restore(controller, api, scope, plan).outcome == HolderLinux.HistoryRestoreOutcome.SELECTION_CHANGED);
    scope.card = make_card("p1", "c1");

    api.hook = () => { scope.project = null; };
    assert(run_restore(controller, api, scope, plan).outcome == HolderLinux.HistoryRestoreOutcome.SELECTION_CHANGED);
    scope.project = make_project("p1");

    api.hook = () => { scope.card = null; };
    assert(run_restore(controller, api, scope, plan).outcome == HolderLinux.HistoryRestoreOutcome.SELECTION_CHANGED);
    scope.card = make_card("p1", "c1");

    api.hook = () => { scope.project = make_project("p2"); };
    assert(run_restore(controller, api, scope, plan).outcome == HolderLinux.HistoryRestoreOutcome.SELECTION_CHANGED);
}

private void test_restore_failure_re_enables_restore_only_for_an_older_version() {
    var api = new FakeHistoryApi();
    var controller = primed_controller(api);
    var scope = new FakeScope();
    var plan = (!) controller.plan_restore(scope, true, "older");
    api.restore_error = new IOError.FAILED("restore boom");

    var without_detail = run_restore(controller, api, scope, plan);
    assert(without_detail.outcome == HolderLinux.HistoryRestoreOutcome.FAILED);
    assert(without_detail.error_message == "restore boom");
    assert(without_detail.debug_line == "History restore failed: restore boom");
    assert(!without_detail.restore_enabled);

    controller.begin_comparison(entry_named("older"));
    assert(run_restore(controller, api, scope, plan).restore_enabled);

    controller.begin_comparison(entry_named("head"));
    assert(!run_restore(controller, api, scope, plan).restore_enabled);
}

// ---- older card pages ----

private void test_plan_load_older_needs_a_cursor_and_context() {
    var api = new FakeHistoryApi();
    var scope = new FakeScope();

    var no_cursor = primed_controller(api, null);
    assert(no_cursor.plan_load_older(scope, true) == null);

    var controller = primed_controller(api);
    var plan = controller.plan_load_older(scope, true);
    assert(plan != null && plan.project_id == "p1" && plan.card_id == "c1" && plan.cursor == "cursor-1");
    assert(controller.plan_load_older(scope, false) == null);
    scope.card = null;
    assert(controller.plan_load_older(scope, true) == null);
    scope.card = make_card("p1", "c1");
    scope.project = null;
    assert(controller.plan_load_older(scope, true) == null);
}

private void test_load_older_appends_and_advances_the_cursor() {
    var api = new FakeHistoryApi();
    var controller = primed_controller(api);
    var scope = new FakeScope();
    var plan = (!) controller.plan_load_older(scope, true);
    api.card_page = new HolderLinux.CardHistoryPage("head", { entry_named("oldest") }, "cursor-2", true);

    var result = run_older(controller, api, scope, plan);
    assert(result.outcome == HolderLinux.HistoryOlderOutcome.APPENDED && result.refresh_button);
    assert(result.page.entries.length == 1);
    assert(result.debug_line == "History loaded 1 older entries; continue scanning");
    assert(controller.next_cursor == "cursor-2" && controller.scan_limited);
    assert(api.last_cursor == "cursor-1" && api.last_limit == 50);
}

private void test_load_older_is_dropped_when_superseded() {
    var api = new FakeHistoryApi();
    var controller = primed_controller(api);
    var scope = new FakeScope();
    var plan = (!) controller.plan_load_older(scope, true);
    api.card_page = page_with("head", "cursor-2");

    // A refresh started meanwhile: drop it and leave the button to the refresh.
    api.hook = () => { controller.begin_refresh(); };
    var superseded = run_older(controller, api, scope, plan);
    assert(superseded.outcome == HolderLinux.HistoryOlderOutcome.DROPPED && !superseded.refresh_button);
    assert(controller.next_cursor == "cursor-1");

    // The selection moved but the timeline was not refreshed: drop it, but the button
    // still has to leave its "loading" state.
    var fresh_plan = (!) controller.plan_load_older(scope, true);
    api.hook = () => { scope.card = make_card("p1", "other"); };
    var moved_card = run_older(controller, api, scope, fresh_plan);
    assert(moved_card.outcome == HolderLinux.HistoryOlderOutcome.DROPPED && moved_card.refresh_button);
    scope.card = make_card("p1", "c1");

    api.hook = () => { scope.project = null; };
    assert(run_older(controller, api, scope, fresh_plan).outcome == HolderLinux.HistoryOlderOutcome.DROPPED);
    scope.project = make_project("p1");

    api.hook = () => { scope.card = null; };
    assert(run_older(controller, api, scope, fresh_plan).outcome == HolderLinux.HistoryOlderOutcome.DROPPED);
    scope.card = make_card("p1", "c1");

    api.hook = () => { scope.project = make_project("p2"); };
    assert(run_older(controller, api, scope, fresh_plan).outcome == HolderLinux.HistoryOlderOutcome.DROPPED);
}

private void test_load_older_failure_is_reported_unless_superseded() {
    var api = new FakeHistoryApi();
    var controller = primed_controller(api);
    var scope = new FakeScope();
    var plan = (!) controller.plan_load_older(scope, true);
    api.card_error = new IOError.FAILED("older boom");

    var failed = run_older(controller, api, scope, plan);
    assert(failed.outcome == HolderLinux.HistoryOlderOutcome.FAILED && failed.refresh_button);
    assert(failed.error_message == "older boom");
    assert(failed.debug_line == "History older-page load failed: older boom");

    api.hook = () => { controller.begin_refresh(); };
    var superseded = run_older(controller, api, scope, plan);
    assert(superseded.outcome == HolderLinux.HistoryOlderOutcome.DROPPED && !superseded.refresh_button);
}

// ---- older project pages ----

private void test_project_older_page_flow() {
    var api = new FakeHistoryApi();
    var controller = new HolderLinux.HistoryController();
    var project = make_project("p1");

    // No cursor loaded yet, no API, or no project: nothing to load.
    assert(controller.plan_load_older_project(true, project) == null);
    api.project_page = new HolderLinux.ProjectHistoryPage("h", {}, "cursor-a");
    run_load_project(controller, api, controller.begin_refresh());
    assert(controller.plan_load_older_project(false, project) == null);
    assert(controller.plan_load_older_project(true, null) == null);
    assert(controller.plan_load_older_project(true, project) == "cursor-a");

    api.project_page = new HolderLinux.ProjectHistoryPage("h", {}, "cursor-b");
    var ok = run_older_project(controller, api, "cursor-a");
    assert(ok.error_message == null && ok.page != null);
    assert(controller.project_next_cursor == "cursor-b");
    assert(api.last_cursor == "cursor-a" && api.last_kind == "resource" && api.last_limit == 50);

    api.project_error = new IOError.FAILED("older project boom");
    var failed = run_older_project(controller, api, "cursor-b");
    assert(failed.page == null && failed.error_message == "older project boom");
    assert(controller.project_next_cursor == "cursor-b");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/history-controller/plan-refresh", test_plan_refresh_covers_every_selection_state);
    Test.add_func("/holder/history-controller/project-load", test_project_page_load_stores_cursor_and_reports_it);
    Test.add_func("/holder/history-controller/project-load-error", test_project_page_load_reports_errors);
    Test.add_func("/holder/history-controller/project-load-stale", test_project_page_load_drops_stale_answers);
    Test.add_func("/holder/history-controller/card-load", test_card_page_load_captures_head_and_paging_state);
    Test.add_func("/holder/history-controller/card-load-error", test_card_page_load_error_resets_state);
    Test.add_func("/holder/history-controller/card-load-stale", test_card_page_load_drops_stale_answers);
    Test.add_func("/holder/history-controller/begin-comparison", test_begin_comparison_remembers_the_entry_and_advances_the_serial);
    Test.add_func("/holder/history-controller/plan-comparison-skips", test_plan_comparison_skips_without_the_needed_context);
    Test.add_func("/holder/history-controller/plan-comparison", test_plan_comparison_resolves_endpoints_and_current_version);
    Test.add_func("/holder/history-controller/comparison-loaded", test_load_comparison_returns_detail_and_debug_line);
    Test.add_func("/holder/history-controller/comparison-stale", test_load_comparison_drops_results_for_a_moved_selection);
    Test.add_func("/holder/history-controller/comparison-failed", test_load_comparison_failure_is_reported_unless_stale);
    Test.add_func("/holder/history-controller/plan-restore", test_plan_restore_needs_api_project_and_card);
    Test.add_func("/holder/history-controller/restore-success", test_restore_reports_success);
    Test.add_func("/holder/history-controller/restore-selection-moved", test_restore_is_dropped_when_the_selection_moved);
    Test.add_func("/holder/history-controller/restore-failure", test_restore_failure_re_enables_restore_only_for_an_older_version);
    Test.add_func("/holder/history-controller/plan-older", test_plan_load_older_needs_a_cursor_and_context);
    Test.add_func("/holder/history-controller/older-appended", test_load_older_appends_and_advances_the_cursor);
    Test.add_func("/holder/history-controller/older-dropped", test_load_older_is_dropped_when_superseded);
    Test.add_func("/holder/history-controller/older-failed", test_load_older_failure_is_reported_unless_superseded);
    Test.add_func("/holder/history-controller/project-older", test_project_older_page_flow);
    return Test.run();
}

}
