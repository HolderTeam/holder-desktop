namespace HolderLinux {

internal class SelectionRequestController : Object {
    private ExplorerSelectionController explorer_selection;
    private SearchSelectionController search_selection;
    private GLib.ListStore card_store;

    public SelectionRequestController(ExplorerSelectionController explorer_selection,
                                      SearchSelectionController search_selection,
                                      GLib.ListStore card_store) {
        this.explorer_selection = explorer_selection;
        this.search_selection = search_selection;
        this.card_store = card_store;
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

    public void request_search(Gtk.SingleSelection search_selection, int position) {
        apply_selection(
            search_selection,
            this.search_selection.position_for_request(position)
        );
    }

    public CardSummary? select_card_by_id(Gtk.SingleSelection card_selection, string card_id) {
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null || card.card_id != card_id) {
                continue;
            }
            apply_selection(card_selection, i);
            return card;
        }
        return null;
    }

    private static void apply_selection(Gtk.SingleSelection selection, uint target) {
        if (selection.get_selected() == target) {
            return;
        }
        selection.set_selected(target);
    }
}

}
