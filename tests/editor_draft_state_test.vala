using GLib;

namespace HolderLinuxTests {

private void test_mark_save_succeeded_ignores_stale_card_id() {
    var state = new HolderLinux.EditorDraftState();
    state.load_card_state("card-1", "original");

    state.mark_save_succeeded("card-2", "new text");

    assert(state.card_id == "card-1");
    assert(state.committed_text == "original");
    assert(state.editable);
}

private void test_has_unsaved_changes_returns_false_for_mismatched_card() {
    var state = new HolderLinux.EditorDraftState();
    state.load_card_state("card-1", "original");
    var other_card = new HolderLinux.CardDetail("card-2", "proj-1", "Other", "changed", 123);

    var changed = state.has_unsaved_changes(other_card, "different");

    assert(!changed);
}

private void test_has_unsaved_changes_detects_a_real_difference() {
    var state = new HolderLinux.EditorDraftState();
    state.load_card_state("card-1", "original");
    var card = new HolderLinux.CardDetail("card-1", "proj-1", "Title", "original", 123);

    assert(state.has_unsaved_changes(card, "changed"));
    assert(!state.has_unsaved_changes(card, "original"));
}

private void test_has_unsaved_changes_after_save_compares_against_the_new_committed_text() {
    var state = new HolderLinux.EditorDraftState();
    state.load_card_state("card-1", "original with trailing space \n");
    var card = new HolderLinux.CardDetail("card-1", "proj-1", "Title", "original with trailing space \n", 123);

    // Simulates a save that trimmed trailing whitespace before persisting: the caller passes
    // the already-trimmed text in, not the raw live buffer, so this never gets permanently
    // stuck reporting unsaved changes just because trimming changed something. See
    // EditorSaveController.trim_for_save / TextUtils.trim_trailing_whitespace_for_save.
    state.mark_save_succeeded("card-1", "original with trailing space\n");

    assert(!state.has_unsaved_changes(card, "original with trailing space\n"));
}

public int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/editor_draft_state/mark_save_succeeded_ignores_stale_card_id",
                  test_mark_save_succeeded_ignores_stale_card_id);
    Test.add_func("/editor_draft_state/has_unsaved_changes_returns_false_for_mismatched_card",
                  test_has_unsaved_changes_returns_false_for_mismatched_card);
    Test.add_func("/editor_draft_state/has_unsaved_changes_detects_a_real_difference",
                  test_has_unsaved_changes_detects_a_real_difference);
    Test.add_func(
        "/editor_draft_state/has_unsaved_changes_after_save_compares_against_the_new_committed_text",
        test_has_unsaved_changes_after_save_compares_against_the_new_committed_text
    );

    return Test.run();
}

}
