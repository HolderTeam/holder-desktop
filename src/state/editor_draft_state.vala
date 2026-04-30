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

    public bool has_unsaved_changes(CardDetail? current_card, ITextProvider editor_text) {
        if (current_card == null || card_id == null || current_card.card_id != card_id) {
            return false;
        }
        return editor_text.get_text() != committed_text;
    }
}

}
