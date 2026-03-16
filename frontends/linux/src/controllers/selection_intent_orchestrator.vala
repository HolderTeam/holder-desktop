namespace HolderLinux {

internal class SelectionIntentOrchestrator : Object {
    private SelectionIntentController selection_intent_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private SelectionTransitionController selection_transition_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private SelectionController selection_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private MainController controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private FlowboardController flowboard_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private Gtk.SingleSelection project_selection; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private Gtk.SingleSelection card_selection; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private Gtk.SingleSelection ai_thread_selection; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private Gtk.SingleSelection search_selection; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private GLib.ListStore card_store; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private SearchSelectionController search_selection_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public SelectionIntentOrchestrator(SelectionIntentController selection_intent_controller,
                                       SelectionTransitionController selection_transition_controller,
                                       SelectionController selection_controller,
                                       MainController controller,
                                       FlowboardController flowboard_controller,
                                       Gtk.SingleSelection project_selection,
                                       Gtk.SingleSelection card_selection,
                                       Gtk.SingleSelection ai_thread_selection,
                                       Gtk.SingleSelection search_selection,
                                       GLib.ListStore card_store,
                                       SearchSelectionController search_selection_controller) {
        this.selection_intent_controller = selection_intent_controller;
        this.selection_transition_controller = selection_transition_controller;
        this.selection_controller = selection_controller;
        this.controller = controller;
        this.flowboard_controller = flowboard_controller;
        this.project_selection = project_selection;
        this.card_selection = card_selection;
        this.ai_thread_selection = ai_thread_selection;
        this.search_selection = search_selection;
        this.card_store = card_store;
        this.search_selection_controller = search_selection_controller;
    }

    public async void on_project_selection_changed() {
        var selected = project_selection.get_selected_item() as Project;
        if (selected == null) {
            return;
        }
        yield selection_intent_controller.on_project_selection(
            selected.project_id,
            selection_transition_controller,
            selection_controller,
            flowboard_controller
        );
    }

    public async void on_card_selection_changed() {
        var selected = card_selection.get_selected_item() as CardSummary;
        yield selection_intent_controller.on_card_selection(
            selected != null ? selected.project_id : controller.selected_project_id(),
            selected != null ? selected.card_id : null,
            selection_transition_controller,
            selection_controller,
            controller,
            flowboard_controller
        );
    }

    public void on_ai_thread_selection_changed() {
        var selected = ai_thread_selection.get_selected_item() as AiThreadSummary;
        selection_intent_controller.on_ai_thread_selection(
            selected != null ? selected.thread_id : null,
            controller.selected_project_id(),
            controller.selected_card_id(),
            selection_transition_controller,
            controller
        );
    }

    public async void on_search_result_activation(uint position) {
        yield selection_intent_controller.on_search_result_activation(
            position,
            controller,
            resolve_card_summary_by_id,
            selection_transition_controller,
            selection_controller,
            flowboard_controller
        );
    }

    public void on_search_selection_requested(int position) {
        var target = search_selection_controller.position_for_request(position);
        if (search_selection.get_selected() == target) {
            return;
        }
        search_selection.set_selected(target);
    }

    public async void on_project_selection_requested(string project_id) {
        yield selection_intent_controller.on_project_selection(
            project_id,
            selection_transition_controller,
            selection_controller,
            flowboard_controller
        );
    }

    public async void open_card_with_transition(string card_id, string reason) {
        yield selection_intent_controller.open_card_with_transition(
            card_id,
            reason,
            controller,
            resolve_card_summary_by_id,
            selection_transition_controller,
            selection_controller,
            flowboard_controller
        );
    }

    private CardSummary? resolve_card_summary_by_id(string card_id) {
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null && card.card_id == card_id) {
                return card;
            }
        }
        return null;
    }
}

}
