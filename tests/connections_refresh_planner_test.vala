using GLib;

namespace HolderLinuxTests {

private class PlannerHarness : Object {
    public TestScheduler scheduler = new TestScheduler();
    public HolderLinux.ConnectionsRefreshPlanner planner;
    public string mode = "project_root";
    public string project_id = "p1";
    public string card_id = "";
    public Gee.ArrayList<string> debug = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> empty_checks = new Gee.ArrayList<string>();
    public int dispatches = 0;
    public uint last_serial = 0;
    public uint last_generation = 0;
    public HolderLinux.ConnectionsGraphRefreshTarget? last_target = null;

    public PlannerHarness(bool visible = true) {
        planner = new HolderLinux.ConnectionsRefreshPlanner(scheduler, (content_generation) => {
            return new HolderLinux.ConnectionsGraphRefreshTarget(mode, project_id, card_id, content_generation);
        });
        planner.debug_event.connect((name, target) => {
            debug.add(name);
        });
        planner.refresh_dispatched.connect((serial, generation, target) => {
            dispatches++;
            last_serial = serial;
            last_generation = generation;
            last_target = target;
        });
        planner.empty_state_check_due.connect((id) => {
            empty_checks.add(id);
        });
        if (visible) {
            planner.set_tool_visible(true);
        }
    }

    public string last_debug() {
        return debug.size > 0 ? debug[debug.size - 1] : "";
    }
}

private void test_hidden_tool_defers_refresh_until_visible() {
    var h = new PlannerHarness(false);
    assert(h.planner.queue_refresh() == HolderLinux.ConnectionsRefreshOutcome.SUPPRESSED_WHILE_HIDDEN);
    assert(h.last_debug() == "suppressed while hidden");
    assert(h.planner.queue_refresh() == HolderLinux.ConnectionsRefreshOutcome.SUPPRESSED_HIDDEN_DUPLICATE);
    assert(h.last_debug() == "suppressed hidden duplicate");

    h.card_id = "c1";
    h.mode = "card_focus";
    assert(h.planner.queue_refresh() == HolderLinux.ConnectionsRefreshOutcome.SUPPRESSED_WHILE_HIDDEN);
    h.scheduler.run_all_once();
    assert(h.dispatches == 0);

    h.planner.set_tool_visible(true);
    h.planner.set_tool_visible(true);
    h.scheduler.run_all_once();
    assert(h.dispatches == 1);
    assert(h.last_target.mode == "card_focus");
    assert(h.last_target.card_id == "c1");
    assert(h.last_serial == 1);

    h.planner.finish_flight();
    h.planner.set_tool_visible(false);
    h.planner.set_tool_visible(true);
    h.scheduler.run_all_once();
    assert(h.dispatches == 1);
}

private void test_visible_refresh_is_debounced_and_duplicates_coalesce() {
    var h = new PlannerHarness();
    assert(h.planner.queue_refresh() == HolderLinux.ConnectionsRefreshOutcome.SCHEDULED);
    assert(h.dispatches == 0);
    assert(h.planner.queue_refresh() == HolderLinux.ConnectionsRefreshOutcome.COALESCED_PENDING_DUPLICATE);
    assert(h.last_debug() == "coalesced pending duplicate");
    assert(h.scheduler.cancel_calls == 0);

    h.project_id = "p2";
    assert(h.planner.queue_refresh() == HolderLinux.ConnectionsRefreshOutcome.SCHEDULED);
    assert(h.scheduler.cancel_calls == 1);

    h.scheduler.run_all_once();
    assert(h.dispatches == 1);
    assert(h.last_target.project_id == "p2");
}

private void test_requests_during_flight_are_coalesced_and_replayed_after_finish() {
    var h = new PlannerHarness();
    h.planner.queue_refresh();
    h.scheduler.run_all_once();
    assert(h.dispatches == 1);

    assert(h.planner.queue_refresh() == HolderLinux.ConnectionsRefreshOutcome.SUPPRESSED_SAME_IN_FLIGHT);
    assert(h.last_debug() == "suppressed same target in flight");

    h.project_id = "p2";
    assert(h.planner.queue_refresh() == HolderLinux.ConnectionsRefreshOutcome.COALESCED_AFTER_IN_FLIGHT);
    assert(h.last_debug() == "coalesced after in-flight refresh");
    assert(h.planner.queue_refresh() == HolderLinux.ConnectionsRefreshOutcome.COALESCED_DUPLICATE_AFTER_FLIGHT);
    assert(h.last_debug() == "coalesced duplicate after flight");
    h.project_id = "p3";
    assert(h.planner.queue_refresh() == HolderLinux.ConnectionsRefreshOutcome.COALESCED_AFTER_IN_FLIGHT);
    h.scheduler.run_all_once();
    assert(h.dispatches == 1);

    h.planner.finish_flight();
    h.scheduler.run_all_once();
    assert(h.dispatches == 2);
    assert(h.last_serial == 2);
    assert(h.last_target.project_id == "p3");
}

private void test_finish_flight_without_pending_work_schedules_nothing() {
    var h = new PlannerHarness();
    h.planner.queue_refresh();
    h.scheduler.run_all_once();
    h.planner.finish_flight();
    h.scheduler.run_all_once();
    assert(h.dispatches == 1);
}

private void test_committed_target_skips_unchanged_refresh_until_content_changes() {
    var h = new PlannerHarness();
    h.planner.queue_refresh();
    h.scheduler.run_all_once();
    h.planner.record_committed(h.last_target, h.last_generation);
    h.planner.finish_flight();

    assert(h.planner.queue_refresh() == HolderLinux.ConnectionsRefreshOutcome.SKIPPED_UNCHANGED);
    assert(h.last_debug() == "skipped unchanged target");

    h.planner.note_content_changed();
    assert(h.planner.content_generation == 1);
    assert(h.planner.queue_refresh() == HolderLinux.ConnectionsRefreshOutcome.SCHEDULED);
    h.scheduler.run_all_once();
    assert(h.dispatches == 2);
    assert(h.last_target.content_generation == 1);
}

private void test_committed_generation_mismatch_does_not_skip() {
    var h = new PlannerHarness();
    h.planner.queue_refresh();
    h.scheduler.run_all_once();
    h.planner.record_committed(h.last_target, h.last_generation + 5);
    h.planner.finish_flight();
    assert(h.planner.queue_refresh() == HolderLinux.ConnectionsRefreshOutcome.SCHEDULED);
}

private void test_stale_results_are_dropped_with_debug_events() {
    var h = new PlannerHarness();
    h.planner.queue_refresh();
    h.scheduler.run_all_once();
    var target = h.last_target;
    assert(!h.planner.drop_if_stale(h.last_serial, h.last_generation, target, "dropped stale test"));

    h.project_id = "p2";
    h.planner.queue_refresh();
    assert(h.planner.drop_if_stale(h.last_serial, h.last_generation, target, "dropped stale generation"));
    assert(h.last_debug() == "dropped stale generation");

    assert(h.planner.drop_if_stale(h.last_serial + 1, h.last_generation + 1, target, "dropped stale serial"));
    assert(h.last_debug() == "dropped stale serial");

    h.planner.report_dropped(target, "dropped stale selection");
    assert(h.last_debug() == "dropped stale selection");
}

private void test_debounce_firing_during_a_flight_is_deferred() {
    var h = new PlannerHarness();
    h.planner.queue_refresh();
    h.planner.set_in_flight_for_tests(true);
    h.scheduler.run_all_once();
    assert(h.dispatches == 0);
    assert(h.last_debug() == "coalesced at debounce dispatch");

    h.planner.finish_flight();
    h.scheduler.run_all_once();
    assert(h.dispatches == 1);
}

private void test_empty_state_check_fires_only_for_the_current_generation() {
    var h = new PlannerHarness();
    h.planner.schedule_empty_state_check("p1");
    h.scheduler.run_all_once();
    assert(h.empty_checks.size == 1);
    assert(h.empty_checks[0] == "p1");

    h.planner.schedule_empty_state_check("p1");
    h.project_id = "p2";
    h.planner.queue_refresh();
    h.scheduler.run_all_once();
    // The debounce timer dispatched (clearing the pending check) and the generation moved on.
    assert(h.empty_checks.size == 1);
}

private void test_empty_state_check_generation_change_suppresses_stale_check() {
    var h = new PlannerHarness(false);
    h.planner.schedule_empty_state_check("p1");
    h.planner.queue_refresh();
    h.scheduler.run_all_once();
    assert(h.empty_checks.size == 0);
}

private void test_scheduling_replaces_and_clearing_cancels_pending_empty_check() {
    var h = new PlannerHarness();
    h.planner.schedule_empty_state_check("p1");
    h.planner.schedule_empty_state_check("p2");
    assert(h.scheduler.cancel_calls == 1);
    h.scheduler.run_all_once();
    assert(h.empty_checks.size == 1);
    assert(h.empty_checks[0] == "p2");

    h.planner.schedule_empty_state_check("p3");
    h.planner.clear_pending_empty_state();
    h.planner.clear_pending_empty_state();
    h.scheduler.run_all_once();
    assert(h.empty_checks.size == 1);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/connections-refresh-planner/hidden-defers-until-visible",
                  test_hidden_tool_defers_refresh_until_visible);
    Test.add_func("/holder/connections-refresh-planner/debounce-and-duplicates",
                  test_visible_refresh_is_debounced_and_duplicates_coalesce);
    Test.add_func("/holder/connections-refresh-planner/flight-coalescing-and-replay",
                  test_requests_during_flight_are_coalesced_and_replayed_after_finish);
    Test.add_func("/holder/connections-refresh-planner/finish-flight-idle",
                  test_finish_flight_without_pending_work_schedules_nothing);
    Test.add_func("/holder/connections-refresh-planner/committed-target-skips-unchanged",
                  test_committed_target_skips_unchanged_refresh_until_content_changes);
    Test.add_func("/holder/connections-refresh-planner/committed-generation-mismatch",
                  test_committed_generation_mismatch_does_not_skip);
    Test.add_func("/holder/connections-refresh-planner/stale-results-dropped",
                  test_stale_results_are_dropped_with_debug_events);
    Test.add_func("/holder/connections-refresh-planner/debounce-during-flight-deferred",
                  test_debounce_firing_during_a_flight_is_deferred);
    Test.add_func("/holder/connections-refresh-planner/empty-check-current-generation",
                  test_empty_state_check_fires_only_for_the_current_generation);
    Test.add_func("/holder/connections-refresh-planner/empty-check-stale-generation",
                  test_empty_state_check_generation_change_suppresses_stale_check);
    Test.add_func("/holder/connections-refresh-planner/empty-check-replace-and-clear",
                  test_scheduling_replaces_and_clearing_cancels_pending_empty_check);
    return Test.run();
}

}
