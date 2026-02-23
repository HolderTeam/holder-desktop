namespace HolderLinux {

public class FlowboardController : Object {
    private GLib.ListStore project_store;
    private Gtk.SingleSelection project_selection;
    private GLib.ListStore card_store;
    private GLib.ListStore visible_tiles;

    public signal void breadcrumb_changed(string text);
    public signal void empty_message_changed(string text);
    public signal void card_open_requested(string card_id);
    public signal void move_requested(string card_id, string? parent_card_id, double sort_key);

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

        replace_visible_flat_cards();
        breadcrumb_changed("Projects / %s".printf(selected_project.name));
        if (visible_tiles.get_n_items() == 0) {
            empty_message_changed("No cards yet. Create one to get started.");
        } else {
            empty_message_changed("Drag card center onto another card to nest. Drag top/bottom edges to reorder.");
        }
    }

    public void activate_position(uint position) {
        var tile = visible_tiles.get_item(position) as FlowboardTile;
        if (tile == null || tile.card_id == null) {
            return;
        }
        card_open_requested(tile.card_id);
    }

    public void navigate_up() {
    }

    public void on_card_drop(string source_card_id, string target_card_id, double target_y_fraction) {
        if (source_card_id == target_card_id) {
            return;
        }

        var source = find_card(source_card_id);
        var target = find_card(target_card_id);
        if (source == null || target == null) {
            return;
        }

        string? new_parent;
        double new_sort;
        if (target_y_fraction >= 0.30 && target_y_fraction <= 0.70) {
            new_parent = target.card_id;
            new_sort = next_sort_key_for_parent(new_parent, source.card_id);
        } else {
            new_parent = normalize_parent(target.parent_card_id);
            var after = target_y_fraction > 0.70;
            new_sort = sort_key_around_target(source.card_id, target.card_id, new_parent, after);
        }

        apply_local_move(source.card_id, new_parent, new_sort);
        move_requested(source.card_id, new_parent, new_sort);
    }

    public void on_background_drop(string source_card_id) {
        var source = find_card(source_card_id);
        if (source == null) {
            return;
        }
        string? new_parent = null;
        double new_sort = next_sort_key_for_parent(new_parent, source.card_id);
        apply_local_move(source.card_id, new_parent, new_sort);
        move_requested(source.card_id, new_parent, new_sort);
    }

    private void replace_visible_flat_cards() {
        visible_tiles.remove_all();
        var sorted = all_cards();
        sorted.sort((a, b) => compare_cards(a, b));
        foreach (var card in sorted) {
            visible_tiles.append(new FlowboardTile(
                "card:%s".printf(card.card_id),
                card.title,
                card.updated_at,
                false,
                card.card_id
            ));
        }
    }

    private Gee.ArrayList<CardSummary> all_cards() {
        var out_cards = new Gee.ArrayList<CardSummary>();
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null) {
                out_cards.add(card);
            }
        }
        return out_cards;
    }

    private CardSummary? find_card(string card_id) {
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null && card.card_id == card_id) {
                return card;
            }
        }
        return null;
    }

    private int compare_cards(CardSummary a, CardSummary b) {
        var parent_cmp = strcmp((normalize_parent(a.parent_card_id) ?? "").down(), (normalize_parent(b.parent_card_id) ?? "").down());
        if (parent_cmp != 0) {
            return parent_cmp;
        }
        if (a.sort_key < b.sort_key) {
            return -1;
        }
        if (a.sort_key > b.sort_key) {
            return 1;
        }
        return strcmp(a.title.down(), b.title.down());
    }

    private string? normalize_parent(string? parent_card_id) {
        if (parent_card_id == null) {
            return null;
        }
        var trimmed = parent_card_id.strip();
        return trimmed.length == 0 ? null : trimmed;
    }

    private Gee.ArrayList<CardSummary> siblings_for_parent(string? parent_card_id, string? exclude_card_id = null) {
        var siblings = new Gee.ArrayList<CardSummary>();
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null) {
                continue;
            }
            if (exclude_card_id != null && card.card_id == exclude_card_id) {
                continue;
            }
            if (normalize_parent(card.parent_card_id) == normalize_parent(parent_card_id)) {
                siblings.add(card);
            }
        }
        siblings.sort((a, b) => {
            if (a.sort_key < b.sort_key) {
                return -1;
            }
            if (a.sort_key > b.sort_key) {
                return 1;
            }
            return strcmp(a.title.down(), b.title.down());
        });
        return siblings;
    }

    private double next_sort_key_for_parent(string? parent_card_id, string? exclude_card_id = null) {
        var siblings = siblings_for_parent(parent_card_id, exclude_card_id);
        if (siblings.size == 0) {
            return 1024.0;
        }
        return siblings[siblings.size - 1].sort_key + 1024.0;
    }

    private double sort_key_around_target(string source_card_id,
                                          string target_card_id,
                                          string? parent_card_id,
                                          bool after) {
        var siblings = siblings_for_parent(parent_card_id, source_card_id);
        int target_index = -1;
        for (int i = 0; i < siblings.size; i++) {
            if (siblings[i].card_id == target_card_id) {
                target_index = i;
                break;
            }
        }
        if (target_index < 0) {
            return next_sort_key_for_parent(parent_card_id, source_card_id);
        }

        double left;
        double right;
        if (after) {
            left = siblings[target_index].sort_key;
            right = target_index + 1 < siblings.size
                ? siblings[target_index + 1].sort_key
                : left + 1024.0;
        } else {
            right = siblings[target_index].sort_key;
            left = target_index > 0
                ? siblings[target_index - 1].sort_key
                : right - 1024.0;
        }
        if (right - left < 0.0001) {
            return after ? right + 1.0 : left - 1.0;
        }
        return (left + right) / 2.0;
    }

    private void apply_local_move(string card_id, string? parent_card_id, double sort_key) {
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null || card.card_id != card_id) {
                continue;
            }
            var updated_at = new DateTime.now_utc().to_unix();
            var replacement = new CardSummary(
                card.card_id,
                card.project_id,
                card.title,
                card.rel_path,
                sort_key,
                parent_card_id,
                card.created_at,
                updated_at
            );
            card_store.remove(i);
            card_store.insert(i, replacement);
            break;
        }
    }
}

}
