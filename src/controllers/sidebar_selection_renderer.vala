namespace HolderLinux {

internal class SidebarSelectionRenderer : Object {
    private Gtk.SingleSelection project_selection;
    private Gtk.SingleSelection card_selection;
    private Gtk.SingleSelection ai_thread_selection;
    private ExplorerSelectionController explorer_selection;

    public SidebarSelectionRenderer(Gtk.SingleSelection project_selection,
                                    Gtk.SingleSelection card_selection,
                                    Gtk.SingleSelection ai_thread_selection,
                                    ExplorerSelectionController explorer_selection) {
        this.project_selection = project_selection;
        this.card_selection = card_selection;
        this.ai_thread_selection = ai_thread_selection;
        this.explorer_selection = explorer_selection;
    }

    public void apply_from_snapshot(string? project_id,
                                    string? card_id,
                                    string? ai_thread_id) {
        apply_selection(
            project_selection,
            explorer_selection.project_position_for_id(project_id)
        );
        apply_selection(
            card_selection,
            explorer_selection.card_position_for_id(card_id)
        );
        apply_selection(
            ai_thread_selection,
            explorer_selection.ai_thread_position_for_id(ai_thread_id)
        );
    }

    private static void apply_selection(Gtk.SingleSelection selection, uint target) {
        if (selection.get_selected() == target) {
            return;
        }
        if (target == Gtk.INVALID_LIST_POSITION) {
            selection.set_can_unselect(true);
        }
        selection.set_selected(target);
    }
}

}
