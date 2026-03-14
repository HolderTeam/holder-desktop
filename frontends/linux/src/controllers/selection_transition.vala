namespace HolderLinux {

internal class SelectionTransitionController : Object {
    private AppTransitionController transitions;

    public signal void navigation_loading_changed(bool loading);

    public SelectionTransitionController(AppTransitionController transitions) {
        this.transitions = transitions;
    }

    public uint begin_navigation(string reason,
                                 string? pending_project_id = null,
                                 string? pending_card_id = null,
                                 string? pending_ai_thread_id = null) {
        navigation_loading_changed(true);
        return transitions.begin(
            reason,
            pending_project_id,
            pending_card_id,
            pending_ai_thread_id
        );
    }

    public bool is_current(uint sequence) {
        return transitions.is_current(sequence);
    }

    public void commit_selection(uint sequence,
                                 string? project_id = null,
                                 string? card_id = null,
                                 string? ai_thread_id = null) {
        transitions.commit_selection(sequence, project_id, card_id, ai_thread_id);
    }

    public void finish_navigation_if_current(uint sequence) {
        if (!is_current(sequence)) {
            return;
        }
        navigation_loading_changed(false);
        transitions.finish(sequence);
    }
}

}
