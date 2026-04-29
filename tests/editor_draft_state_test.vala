using GLib;

namespace HolderLinux {

public interface ITextProvider : Object {
    public abstract string get_text();
}

}

namespace HolderLinuxTests {

private class FixedTextProvider : Object, HolderLinux.ITextProvider {
    private string text;

    public FixedTextProvider(string text) {
        this.text = text;
    }

    public string get_text() {
        return text;
    }
}

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

    var changed = state.has_unsaved_changes(other_card, new FixedTextProvider("different"));

    assert(!changed);
}

public int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/editor_draft_state/mark_save_succeeded_ignores_stale_card_id",
                  test_mark_save_succeeded_ignores_stale_card_id);
    Test.add_func("/editor_draft_state/has_unsaved_changes_returns_false_for_mismatched_card",
                  test_has_unsaved_changes_returns_false_for_mismatched_card);

    return Test.run();
}

}
