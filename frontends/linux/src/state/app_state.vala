namespace HolderLinux {

public class AppSelectionSnapshot : Object {
    public string? project_id { get; set; }
    public string? card_id { get; set; }
    public string? ai_thread_id { get; set; }

    public AppSelectionSnapshot(string? project_id = null,
                                string? card_id = null,
                                string? ai_thread_id = null) {
        this.project_id = project_id;
        this.card_id = card_id;
        this.ai_thread_id = ai_thread_id;
    }
}

public class AppTransitionSnapshot : Object {
    public uint sequence { get; set; }
    public bool in_flight { get; set; }
    public string reason { get; set; }
    public AppSelectionSnapshot pending_selection { get; set; }

    public AppTransitionSnapshot() {
        sequence = 0;
        in_flight = false;
        reason = "";
        pending_selection = new AppSelectionSnapshot();
    }
}

public class AppStateStore : Object {
    public AppSelectionSnapshot selection { get; private set; }
    public AppTransitionSnapshot transition { get; private set; }

    public signal void state_changed();

    public AppStateStore() {
        selection = new AppSelectionSnapshot();
        transition = new AppTransitionSnapshot();
    }

    public void set_selected_project(string? project_id) {
        selection.project_id = project_id;
        state_changed();
    }

    public void set_selected_card(string? card_id) {
        selection.card_id = card_id;
        state_changed();
    }

    public void set_selected_ai_thread(string? thread_id) {
        selection.ai_thread_id = thread_id;
        state_changed();
    }

    public uint begin_transition(string reason,
                                 string? pending_project_id = null,
                                 string? pending_card_id = null,
                                 string? pending_ai_thread_id = null) {
        transition.sequence++;
        transition.in_flight = true;
        transition.reason = reason;
        transition.pending_selection.project_id = pending_project_id;
        transition.pending_selection.card_id = pending_card_id;
        transition.pending_selection.ai_thread_id = pending_ai_thread_id;
        state_changed();
        return transition.sequence;
    }

    public bool is_current(uint sequence) {
        return transition.sequence == sequence;
    }

    public void finish_transition(uint sequence) {
        if (!is_current(sequence)) {
            return;
        }
        transition.in_flight = false;
        transition.reason = "";
        transition.pending_selection.project_id = null;
        transition.pending_selection.card_id = null;
        transition.pending_selection.ai_thread_id = null;
        state_changed();
    }
}

}
