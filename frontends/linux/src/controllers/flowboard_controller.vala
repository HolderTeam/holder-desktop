namespace HolderLinux {

public class FlowboardController : Object {
    private GLib.ListStore project_store;
    private Gtk.SingleSelection project_selection;
    private GLib.ListStore card_store;
    private GLib.ListStore visible_tiles;

    public signal void breadcrumb_changed(string text);
    public signal void empty_message_changed(string text);
    public signal void card_open_requested(string card_id);

    public FlowboardController(GLib.ListStore project_store,
                               Gtk.SingleSelection project_selection,
                               GLib.ListStore card_store) {
        this.project_store = project_store;
        this.project_selection = project_selection;
        this.card_store = card_store;
        this.visible_tiles = new GLib.ListStore(typeof(FlowboardTile));
    }

    public GLib.ListModel get_visible_model() {
        return visible_tiles;
    }

    public void refresh() {
        var selected_project = project_selection.get_selected_item() as Project;
        if (selected_project == null) {
            visible_tiles.remove_all();
            breadcrumb_changed("Projects");
            empty_message_changed("Select a project to browse cards.");
            return;
        }

        breadcrumb_changed("Projects / %s".printf(selected_project.name));
        visible_tiles.remove_all();
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null) {
                continue;
            }
            visible_tiles.append(new FlowboardTile(card.card_id, card.title, card.updated_at));
        }

        if (visible_tiles.get_n_items() == 0) {
            empty_message_changed("No cards yet. Create one to get started.");
        } else {
            empty_message_changed("Use arrow keys to navigate. Press Enter to open.");
        }
    }

    public void activate_position(uint position) {
        var tile = visible_tiles.get_item(position) as FlowboardTile;
        if (tile == null) {
            return;
        }
        card_open_requested(tile.card_id);
    }

    public void navigate_up() {
        // Root-only for now; hierarchy support will be added with parent/child card metadata.
    }
}

}
