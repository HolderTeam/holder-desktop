namespace HolderLinux {

internal class SelectionRequestController : Object {
    private ExplorerSelectionController explorer_selection;

    public SelectionRequestController(ExplorerSelectionController explorer_selection) {
        this.explorer_selection = explorer_selection;
    }

    public void request_project(Gtk.SingleSelection project_selection, string? project_id) {
        apply_selection(
            project_selection,
            explorer_selection.project_position_for_id(project_id)
        );
    }

    public void request_card(Gtk.SingleSelection card_selection, string? card_id) {
        apply_selection(
            card_selection,
            explorer_selection.card_position_for_id(card_id)
        );
    }

    public void request_ai_thread(Gtk.SingleSelection ai_thread_selection, string? thread_id) {
        apply_selection(
            ai_thread_selection,
            explorer_selection.ai_thread_position_for_id(thread_id)
        );
    }

    private static void apply_selection(Gtk.SingleSelection selection, uint target) {
        if (selection.get_selected() == target) {
            return;
        }
        selection.set_selected(target);
    }
}

}
