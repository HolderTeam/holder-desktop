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

    public async void run_project_selection(string? project_id,
                                            SelectionController selection_controller,
                                            FlowboardController flowboard_controller) {
        var seq = begin_navigation("project-selection", project_id, null, null);
        try {
            commit_selection(seq, project_id, null, null);
            yield selection_controller.on_project_selected();
            if (!is_current(seq)) {
                return;
            }
            flowboard_controller.refresh();
        } finally {
            finish_navigation_if_current(seq);
        }
    }

    public async void run_card_selection(string project_id,
                                         string card_id,
                                         SelectionController selection_controller) {
        var seq = begin_navigation("card-selection", project_id, card_id, null);
        try {
            commit_selection(seq, project_id, card_id, null);
            yield selection_controller.on_card_selected();
            if (!is_current(seq)) {
                return;
            }
        } finally {
            finish_navigation_if_current(seq);
        }
    }

    public async void run_card_open_transition(string reason,
                                               string? pending_project_id,
                                               string pending_card_id,
                                               string selected_project_id,
                                               string selected_card_id,
                                               SelectionController selection_controller) {
        var seq = begin_navigation(
            reason,
            pending_project_id,
            pending_card_id,
            null
        );
        try {
            commit_selection(
                seq,
                selected_project_id,
                selected_card_id,
                null
            );
            yield selection_controller.on_card_selected();
            if (!is_current(seq)) {
                return;
            }
        } finally {
            finish_navigation_if_current(seq);
        }
    }

    public void run_ai_thread_selection(string? project_id,
                                        string? card_id,
                                        string? ai_thread_id,
                                        MainController main_controller) {
        var seq = transitions.begin(
            "ai-thread-selection",
            project_id,
            card_id,
            ai_thread_id
        );
        try {
            main_controller.on_ai_thread_selected();
            if (!is_current(seq)) {
                return;
            }
            commit_selection(seq, project_id, card_id, ai_thread_id);
        } finally {
            if (is_current(seq)) {
                transitions.finish(seq);
            }
        }
    }
}

}
