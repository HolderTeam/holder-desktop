namespace HolderLinux {

internal class SelectionIntentController : Object {
    public async void on_project_selection(string? project_id,
                                           SelectionTransitionController selection_transition_controller,
                                           SelectionController selection_controller,
                                           FlowboardController flowboard_controller) {
        yield selection_transition_controller.run_project_selection(
            project_id,
            selection_controller,
            flowboard_controller
        );
    }

    public async void on_card_selection(string? project_id,
                                        string? card_id,
                                        SelectionTransitionController selection_transition_controller,
                                        SelectionController selection_controller) {
        if (project_id == null || project_id.strip().length == 0 ||
            card_id == null || card_id.strip().length == 0) {
            return;
        }
        yield selection_transition_controller.run_card_selection(
            project_id,
            card_id,
            selection_controller
        );
    }

    public void on_ai_thread_selection(string? thread_id,
                                       string? project_id,
                                       string? card_id,
                                       SelectionTransitionController selection_transition_controller,
                                       MainController controller) {
        selection_transition_controller.run_ai_thread_selection(
            project_id,
            card_id,
            thread_id,
            controller
        );
    }

    public async void on_search_result_activation(uint position,
                                                  MainController controller,
                                                  SelectionTransitionController selection_transition_controller,
                                                  SelectionController selection_controller) {
        var target_card_id = yield controller.prepare_search_result_card_at(position);
        if (target_card_id == null || target_card_id.strip().length == 0) {
            return;
        }
        var selected_card = controller.card_summary_by_id(target_card_id);
        if (selected_card == null) {
            return;
        }
        controller.card_selection_requested(target_card_id);
        yield selection_transition_controller.run_card_open_transition(
            "search-result-activation",
            controller.selected_project_id(),
            target_card_id,
            selected_card.project_id,
            selected_card.card_id,
            selection_controller
        );
    }

    public async void open_card_with_transition(string card_id,
                                                string reason,
                                                MainController controller,
                                                SelectionTransitionController selection_transition_controller,
                                                SelectionController selection_controller) {
        var selected_card = controller.card_summary_by_id(card_id);
        if (selected_card == null) {
            return;
        }
        controller.card_selection_requested(card_id);
        yield selection_transition_controller.run_card_open_transition(
            reason,
            selected_card.project_id,
            selected_card.card_id,
            selected_card.project_id,
            selected_card.card_id,
            selection_controller
        );
    }
}

}
