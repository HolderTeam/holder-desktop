using GLib;

private void test_begin_sets_in_flight_and_pending_selection() {
    var state = new HolderLinux.AppStateStore();
    var controller = new HolderLinux.AppTransitionController(state);

    uint started_seq = 0;
    string started_reason = "";
    controller.transition_started.connect((sequence, reason) => {
        started_seq = sequence;
        started_reason = reason;
    });

    var seq = controller.begin("card-selection", "p1", "c1", null);

    assert(seq == 1);
    assert(started_seq == seq);
    assert(started_reason == "card-selection");
    assert(state.transition.in_flight);
    assert(state.transition.reason == "card-selection");
    assert(state.transition.pending_selection.project_id == "p1");
    assert(state.transition.pending_selection.card_id == "c1");
    assert(state.transition.pending_selection.ai_thread_id == null);
}

private void test_commit_selection_applies_for_current_sequence_only() {
    var state = new HolderLinux.AppStateStore();
    var controller = new HolderLinux.AppTransitionController(state);

    var stale = controller.begin("stale", "p-stale", "c-stale", null);
    var current = controller.begin("current", "p2", "c2", null);

    controller.commit_selection(stale, "p-stale", "c-stale", "t-stale");
    assert(state.selection.project_id == null);
    assert(state.selection.card_id == null);
    assert(state.selection.ai_thread_id == null);

    controller.commit_selection(current, "p2", "c2", "t2");
    assert(state.selection.project_id == "p2");
    assert(state.selection.card_id == "c2");
    assert(state.selection.ai_thread_id == "t2");
}

private void test_finish_ignores_stale_sequence() {
    var state = new HolderLinux.AppStateStore();
    var controller = new HolderLinux.AppTransitionController(state);

    uint finished_count = 0;
    uint finished_seq = 0;
    controller.transition_finished.connect((sequence) => {
        finished_count++;
        finished_seq = sequence;
    });

    var stale = controller.begin("stale", "p1", null, null);
    var current = controller.begin("current", "p2", null, null);

    controller.finish(stale);
    assert(state.transition.in_flight);
    assert(state.transition.reason == "current");
    assert(finished_count == 0);

    controller.finish(current);
    assert(!state.transition.in_flight);
    assert(state.transition.reason == "");
    assert(state.transition.pending_selection.project_id == null);
    assert(finished_count == 1);
    assert(finished_seq == current);
}

public int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/app_transition/begin_sets_in_flight_and_pending_selection",
                  test_begin_sets_in_flight_and_pending_selection);
    Test.add_func("/app_transition/commit_selection_applies_for_current_sequence_only",
                  test_commit_selection_applies_for_current_sequence_only);
    Test.add_func("/app_transition/finish_ignores_stale_sequence",
                  test_finish_ignores_stale_sequence);

    return Test.run();
}
