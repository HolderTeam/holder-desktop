using GLib;

namespace HolderLinuxTests {

private HolderLinux.AppTransitionSnapshot make_transition(bool in_flight,
                                                          string? project_id = null,
                                                          string? card_id = null,
                                                          string? ai_thread_id = null) {
    var transition = new HolderLinux.AppTransitionSnapshot();
    transition.in_flight = in_flight;
    transition.pending_selection = new HolderLinux.AppSelectionSnapshot(project_id, card_id, ai_thread_id);
    return transition;
}

private void test_selection_without_transition_is_the_committed_snapshot() {
    var snapshot = new HolderLinux.AppSelectionSnapshot("p1", "c1", "t1");
    var effective = HolderLinux.EffectiveSelection.resolve(snapshot, make_transition(false, "p2", "c2", "t2"), "live");
    assert(effective.project_id == "p1");
    assert(effective.card_id == "c1");
    assert(effective.ai_thread_id == "t1");
}

private void test_pending_project_replaces_project_card_and_thread() {
    var snapshot = new HolderLinux.AppSelectionSnapshot("p1", "c1", "t1");
    var effective = HolderLinux.EffectiveSelection.resolve(snapshot, make_transition(true, "p2"), "live");
    assert(effective.project_id == "p2");
    assert(effective.card_id == null);
    assert(effective.ai_thread_id == null);
}

private void test_pending_card_only_keeps_project_and_thread() {
    var snapshot = new HolderLinux.AppSelectionSnapshot("p1", "c1", "t1");
    var effective = HolderLinux.EffectiveSelection.resolve(snapshot, make_transition(true, null, "c2"), null);
    assert(effective.project_id == "p1");
    assert(effective.card_id == "c2");
    assert(effective.ai_thread_id == "t1");
}

private void test_pending_thread_only_replaces_the_thread() {
    var snapshot = new HolderLinux.AppSelectionSnapshot("p1", "c1", "t1");
    var effective = HolderLinux.EffectiveSelection.resolve(snapshot, make_transition(true, null, null, "t2"), null);
    assert(effective.project_id == "p1");
    assert(effective.card_id == "c1");
    assert(effective.ai_thread_id == "t2");
}

private void test_in_flight_without_pending_project_uses_the_live_project() {
    var snapshot = new HolderLinux.AppSelectionSnapshot("p1", "c1", "t1");
    var with_live = HolderLinux.EffectiveSelection.resolve(snapshot, make_transition(true), "live");
    assert(with_live.project_id == "live");
    assert(with_live.card_id == "c1");
    assert(with_live.ai_thread_id == "t1");

    var without_live = HolderLinux.EffectiveSelection.resolve(snapshot, make_transition(true), null);
    assert(without_live.project_id == "p1");
}

private void test_is_blank_treats_null_and_whitespace_as_blank() {
    assert(HolderLinux.WindowPresenter.is_blank(null));
    assert(HolderLinux.WindowPresenter.is_blank(""));
    assert(HolderLinux.WindowPresenter.is_blank("  \t\n"));
    assert(!HolderLinux.WindowPresenter.is_blank(" c1 "));
}

private void test_card_title_lookup_falls_back_when_the_card_is_unknown() {
    var store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    store.append(new HolderLinux.CardSummary("c1", "p1", "First", "c1.md", 1.0, null, 1, 1));
    store.append(new HolderLinux.CardSummary("c2", "p1", "Second", "c2.md", 2.0, null, 1, 1));
    assert(HolderLinux.WindowPresenter.card_title_for_id(store, "c2") == "Second");
    assert(HolderLinux.WindowPresenter.card_title_for_id(store, "missing") == "this card");
    assert(HolderLinux.WindowPresenter.card_title_for_id(new GLib.ListStore(typeof(Object)), "c1") == "this card");
}

private void test_recovery_draft_body_uses_the_given_time_zone() {
    var utc = new TimeZone.utc();
    var body = HolderLinux.WindowPresenter.recovery_draft_body("My card", 0, utc);
    var expected_time = new DateTime.from_unix_utc(0).to_timezone(utc).format("%c");
    assert(body == "Holder found a local recovery copy of “My card” from %s.".printf(expected_time));
    assert(HolderLinux.WindowPresenter.RECOVERY_DIALOG_TITLE == "Recover unsaved changes?");

    // Fixed offset: named zones need a tz database, which the Windows CI runner lacks.
    TimeZone tokyo;
    try {
        tokyo = new TimeZone.identifier("+09:00");
    } catch (Error e) {
        assert_not_reached();
    }
    assert(HolderLinux.WindowPresenter.recovery_draft_body("My card", 0, tokyo) != body);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/window-logic/effective-selection/no-transition", test_selection_without_transition_is_the_committed_snapshot);
    Test.add_func("/window-logic/effective-selection/pending-project", test_pending_project_replaces_project_card_and_thread);
    Test.add_func("/window-logic/effective-selection/pending-card", test_pending_card_only_keeps_project_and_thread);
    Test.add_func("/window-logic/effective-selection/pending-thread", test_pending_thread_only_replaces_the_thread);
    Test.add_func("/window-logic/effective-selection/live-project", test_in_flight_without_pending_project_uses_the_live_project);
    Test.add_func("/window-logic/presenter/is-blank", test_is_blank_treats_null_and_whitespace_as_blank);
    Test.add_func("/window-logic/presenter/card-title", test_card_title_lookup_falls_back_when_the_card_is_unknown);
    Test.add_func("/window-logic/presenter/recovery-body", test_recovery_draft_body_uses_the_given_time_zone);
    return Test.run();
}

}
