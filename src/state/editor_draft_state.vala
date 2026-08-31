namespace HolderLinux {

public class EditorDraftState : Object {
    public string? card_id { get; private set; default = null; }
    public string committed_text { get; private set; default = ""; }
    public bool editable { get; private set; default = false; }

    public void reset_to_view_state(string text, bool editable) {
        card_id = null;
        committed_text = text;
        this.editable = editable;
    }

    public void load_card_state(string card_id, string content) {
        this.card_id = card_id;
        committed_text = content;
        editable = true;
    }

    public void mark_save_succeeded(string card_id, string content) {
        if (this.card_id != card_id) {
            return;
        }
        committed_text = content;
    }

    // Takes the current text as a plain string, already trimmed the same way it will be before
    // saving (see TextUtils.trim_trailing_whitespace_for_save and
    // EditorSaveController.trim_for_save) -- not an ITextProvider read directly here, so this
    // comparison is never accidentally made against the untrimmed live buffer while
    // committed_text holds the trimmed text a save actually persisted, which would otherwise
    // make this permanently report unsaved changes that don't exist.
    public bool has_unsaved_changes(CardDetail? current_card, string current_text) {
        if (current_card == null || card_id == null || current_card.card_id != card_id) {
            return false;
        }
        return current_text != committed_text;
    }
}

}
