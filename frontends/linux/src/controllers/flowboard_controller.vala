namespace HolderLinux {

public class FlowboardController : Object {
    private const string ROOT_CONTAINER = "";

    private GLib.ListStore project_store;
    private Gtk.SingleSelection project_selection;
    private GLib.ListStore card_store;
    private GLib.ListStore visible_tiles;
    private Gee.HashMap<string, Gee.ArrayList<FlowboardTile>> children_by_container;
    private Gee.HashMap<string, bool> seen_node_keys;
    private Gee.ArrayList<string> container_stack;
    private string current_container = ROOT_CONTAINER;
    private string? current_project_id = null;

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
        this.children_by_container = new Gee.HashMap<string, Gee.ArrayList<FlowboardTile>>();
        this.seen_node_keys = new Gee.HashMap<string, bool>();
        this.container_stack = new Gee.ArrayList<string>();
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
            current_project_id = null;
            current_container = ROOT_CONTAINER;
            container_stack.clear();
            return;
        }

        if (current_project_id != selected_project.project_id) {
            current_project_id = selected_project.project_id;
            current_container = ROOT_CONTAINER;
            container_stack.clear();
        }
        if (current_container == ROOT_CONTAINER) {
            replace_visible_flat_cards();
            breadcrumb_changed("Projects / %s".printf(selected_project.name));
            if (visible_tiles.get_n_items() == 0) {
                empty_message_changed("No cards yet. Create one to get started.");
            } else {
                empty_message_changed("Use arrow keys to navigate. Press Enter to open.");
            }
            return;
        }

        rebuild_index();
        if (!children_by_container.has_key(current_container)) {
            current_container = ROOT_CONTAINER;
            container_stack.clear();
            refresh();
            return;
        }
        replace_visible(children_by_container.get(current_container));
        breadcrumb_changed(build_breadcrumb(selected_project.name));
        if (visible_tiles.get_n_items() == 0) {
            empty_message_changed("No items in this section. Press Backspace to go up.");
        } else {
            empty_message_changed("Use arrow keys to navigate. Enter drills in or opens. Backspace goes up.");
        }
    }

    public void activate_position(uint position) {
        var tile = visible_tiles.get_item(position) as FlowboardTile;
        if (tile == null) {
            return;
        }
        if (current_container == ROOT_CONTAINER) {
            if (tile.card_id != null) {
                card_open_requested(tile.card_id);
            }
            return;
        }
        if (tile.is_container) {
            current_container = tile.node_key;
            container_stack.add(tile.title);
            refresh();
            return;
        }
        if (tile.card_id == null) {
            return;
        }
        card_open_requested(tile.card_id);
    }

    public void navigate_up() {
        if (current_container == ROOT_CONTAINER || container_stack.size == 0) {
            return;
        }
        container_stack.remove_at(container_stack.size - 1);
        current_container = container_stack_to_key();
        refresh();
    }

    private void rebuild_index() {
        children_by_container.clear();
        seen_node_keys.clear();
        ensure_bucket(ROOT_CONTAINER);

        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null) {
                continue;
            }

            var rel_path = normalize_rel_path(card.rel_path);
            var parent = ROOT_CONTAINER;
            var dirname = Path.get_dirname(rel_path);
            if (dirname != null && dirname != "." && dirname != "/") {
                var parts = dirname.split("/");
                var cumulative = "";
                foreach (var raw_part in parts) {
                    var part = raw_part.strip();
                    if (part.length == 0) {
                        continue;
                    }
                    cumulative = cumulative.length == 0 ? part : "%s/%s".printf(cumulative, part);
                    var dir_key = "dir:%s".printf(cumulative);
                    ensure_unique_child(
                        parent,
                        new FlowboardTile(dir_key, part, card.updated_at, true, null)
                    );
                    ensure_bucket(dir_key);
                    parent = dir_key;
                }
            }

            var node_key = "card:%s".printf(card.card_id);
            ensure_unique_child(
                parent,
                new FlowboardTile(node_key, card.title, card.updated_at, false, card.card_id)
            );
        }
    }

    private static string normalize_rel_path(string rel_path) {
        return rel_path.replace("\\", "/");
    }

    private string build_breadcrumb(string project_name) {
        var parts = new Gee.ArrayList<string>();
        parts.add("Projects");
        parts.add(project_name);
        foreach (var seg in container_stack) {
            parts.add(seg);
        }
        return string.joinv(" / ", parts.to_array());
    }

    private string container_stack_to_key() {
        if (container_stack.size == 0) {
            return ROOT_CONTAINER;
        }
        var joined = string.joinv("/", container_stack.to_array());
        return "dir:%s".printf(joined);
    }

    private void replace_visible(Gee.ArrayList<FlowboardTile>? items) {
        visible_tiles.remove_all();
        if (items == null) {
            return;
        }
        var sorted = new Gee.ArrayList<FlowboardTile>();
        foreach (var item in items) {
            sorted.add(item);
        }
        sorted.sort((a, b) => {
            if (a.is_container != b.is_container) {
                return a.is_container ? -1 : 1;
            }
            return strcmp(a.title.down(), b.title.down());
        });
        foreach (var item in sorted) {
            visible_tiles.append(item);
        }
    }

    private void replace_visible_flat_cards() {
        visible_tiles.remove_all();
        var sorted = new Gee.ArrayList<FlowboardTile>();
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null) {
                continue;
            }
            sorted.add(new FlowboardTile(
                "card:%s".printf(card.card_id),
                card.title,
                card.updated_at,
                false,
                card.card_id
            ));
        }
        sorted.sort((a, b) => strcmp(a.title.down(), b.title.down()));
        foreach (var item in sorted) {
            visible_tiles.append(item);
        }
    }

    private void ensure_bucket(string key) {
        if (!children_by_container.has_key(key)) {
            children_by_container.set(key, new Gee.ArrayList<FlowboardTile>());
        }
    }

    private void ensure_unique_child(string parent_key, FlowboardTile tile) {
        ensure_bucket(parent_key);
        if (seen_node_keys.has_key("%s|%s".printf(parent_key, tile.node_key))) {
            return;
        }
        seen_node_keys.set("%s|%s".printf(parent_key, tile.node_key), true);
        children_by_container.get(parent_key).add(tile);
    }
}

}
