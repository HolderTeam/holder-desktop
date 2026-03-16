namespace HolderLinux {

public class AppTransitionController : Object {
    private AppStateStore state_store;

    public signal void transition_started(uint sequence, string reason);
    public signal void transition_finished(uint sequence);

    public AppTransitionController(AppStateStore state_store) {
        this.state_store = state_store;
    }

    public uint begin(string reason,
                      string? pending_project_id = null,
                      string? pending_card_id = null,
                      string? pending_ai_thread_id = null) {
        var seq = state_store.begin_transition(
            reason,
            pending_project_id,
            pending_card_id,
            pending_ai_thread_id
        );
        transition_started(seq, reason);
        return seq;
    }

    public bool is_current(uint sequence) {
        return state_store.is_current(sequence);
    }

    public void commit_selection(uint sequence,
                                 string? project_id = null,
                                 string? card_id = null,
                                 string? ai_thread_id = null) {
        if (!is_current(sequence)) {
            return;
        }
        state_store.set_selection_snapshot(project_id, card_id, ai_thread_id);
    }

    public void finish(uint sequence) {
        if (!is_current(sequence)) {
            return;
        }
        state_store.finish_transition(sequence);
        transition_finished(sequence);
    }
}

}
