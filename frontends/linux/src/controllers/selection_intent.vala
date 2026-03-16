namespace HolderLinux {

public delegate CardSummary? CardSummaryResolver(string card_id);

internal class SelectionIntentController : Object {
    private const string SIDEBAR_CARD_SELECTION_REASON = "sidebar-card-selection";
    private const string SEARCH_RESULT_ACTIVATION_REASON = "search-result-activation";
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
                                        SelectionController selection_controller,
                                        MainController main_controller,
                                        CardSummaryResolver resolve_card_summary,
                                        FlowboardController flowboard_controller) {
        if (project_id == null || project_id.strip().length == 0) {
            return;
        }
        if (card_id == null || card_id.strip().length == 0) {
            yield selection_transition_controller.run_project_overview_selection(
                project_id,
                main_controller,
                flowboard_controller
            );
            return;
        }
        yield open_card_with_transition(
            card_id,
            SIDEBAR_CARD_SELECTION_REASON,
            main_controller,
            resolve_card_summary,
            selection_transition_controller,
            selection_controller,
            flowboard_controller
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
                                                  CardSummaryResolver resolve_card_summary,
                                                  SelectionTransitionController selection_transition_controller,
                                                  SelectionController selection_controller,
                                                  FlowboardController flowboard_controller) {
        var target_card_id = yield controller.prepare_search_result_card_at(position);
        if (target_card_id == null || target_card_id.strip().length == 0) {
            return;
        }
        yield open_card_with_transition(
            target_card_id,
            SEARCH_RESULT_ACTIVATION_REASON,
            controller,
            resolve_card_summary,
            selection_transition_controller,
            selection_controller,
            flowboard_controller
        );
    }

    public async void open_card_with_transition(string card_id,
                                                string reason,
                                                MainController controller,
                                                CardSummaryResolver resolve_card_summary,
                                                SelectionTransitionController selection_transition_controller,
                                                SelectionController selection_controller,
                                                FlowboardController flowboard_controller) {
        var selected_card = resolve_card_summary(card_id);
        if (selected_card == null) {
            return;
        }
        yield selection_transition_controller.run_card_open_transition(
            reason,
            selected_card.project_id,
            selected_card.card_id,
            selected_card.project_id,
            selected_card.card_id,
            selection_controller,
            flowboard_controller
        );
    }
}

}
