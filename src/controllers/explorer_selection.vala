namespace HolderLinux {

internal class ExplorerSelectionController : Object {
    private GLib.ListStore project_store;
    private GLib.ListStore card_store;
    private GLib.ListStore ai_thread_store;

    public ExplorerSelectionController(GLib.ListStore project_store,
                                       GLib.ListStore card_store,
                                       GLib.ListStore ai_thread_store) {
        this.project_store = project_store;
        this.card_store = card_store;
        this.ai_thread_store = ai_thread_store;
    }

    public uint project_position_for_id(string? project_id) {
        if (project_id == null || project_id.strip().length == 0) {
            return Gtk.INVALID_LIST_POSITION;
        }
        for (uint i = 0; i < project_store.get_n_items(); i++) {
            var project = project_store.get_item(i) as Project;
            if (project != null && project.project_id == project_id) {
                return i;
            }
        }
        return Gtk.INVALID_LIST_POSITION;
    }

    public uint card_position_for_id(string? card_id) {
        if (card_id == null || card_id.strip().length == 0) {
            return Gtk.INVALID_LIST_POSITION;
        }
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null && card.card_id == card_id) {
                return i;
            }
        }
        return Gtk.INVALID_LIST_POSITION;
    }

    public uint ai_thread_position_for_id(string? thread_id) {
        if (thread_id == null || thread_id.strip().length == 0) {
            return Gtk.INVALID_LIST_POSITION;
        }
        for (uint i = 0; i < ai_thread_store.get_n_items(); i++) {
            var thread = ai_thread_store.get_item(i) as AiThreadSummary;
            if (thread != null && thread.thread_id == thread_id) {
                return i;
            }
        }
        return Gtk.INVALID_LIST_POSITION;
    }
}

}
