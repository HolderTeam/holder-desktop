namespace HolderLinux {

public class FlowboardController : Object {
    private GLib.ListStore project_store;
    private Gtk.SingleSelection project_selection;
    private GLib.ListStore card_store;
    private GLib.ListStore visible_tiles;
    private string? current_project_id = null;
    private string? current_parent_card_id = null;
    private bool showing_projects = false;
    private Gee.ArrayList<string> parent_stack_ids;

    public signal void breadcrumb_segments_changed(Gee.ArrayList<FlowboardBreadcrumbSegment> segments);
    public signal void empty_message_changed(string text);
    public signal void card_open_requested(string card_id);
    public signal void move_requested(string card_id, string? parent_card_id, double sort_key);
    public signal void create_card_requested(string? parent_card_id);
    public signal void toast_requested(string message);

    public FlowboardController(GLib.ListStore project_store,
                               Gtk.SingleSelection project_selection,
                               GLib.ListStore card_store) {
        this.project_store = project_store;
        this.project_selection = project_selection;
        this.card_store = card_store;
        this.visible_tiles = new GLib.ListStore(typeof(FlowboardTile));
        this.parent_stack_ids = new Gee.ArrayList<string>();
    }

    public GLib.ListModel get_visible_model() {
        return visible_tiles;
    }

    public void refresh() {
        var selected_project = project_selection.get_selected_item() as Project;
        if (showing_projects && selected_project != null && selected_project.project_id != current_project_id) {
            showing_projects = false;
            current_project_id = selected_project.project_id;
            current_parent_card_id = null;
            parent_stack_ids.clear();
        }
        if (showing_projects) {
            replace_visible_with_projects();
            breadcrumb_segments_changed(build_breadcrumb_segments(""));
            if (visible_tiles.get_n_items() == 0) {
                empty_message_changed("No projects yet. Create one to get started.");
            } else {
                empty_message_changed("Select a project.");
            }
            return;
        }

        if (selected_project == null) {
            visible_tiles.remove_all();
            breadcrumb_segments_changed(build_breadcrumb_segments(""));
            empty_message_changed("Select a project to browse cards.");
            current_project_id = null;
            current_parent_card_id = null;
            parent_stack_ids.clear();
            return;
        }

        if (current_project_id != selected_project.project_id) {
            current_project_id = selected_project.project_id;
            current_parent_card_id = null;
            parent_stack_ids.clear();
            showing_projects = false;
        }

        if (current_parent_card_id != null && find_card(current_parent_card_id) == null) {
            current_parent_card_id = null;
            parent_stack_ids.clear();
        }

        replace_visible_for_parent(current_parent_card_id);
        breadcrumb_segments_changed(build_breadcrumb_segments(selected_project.name));
        if (visible_tiles.get_n_items() == 0) {
            empty_message_changed("No cards yet. Create one to get started.");
        } else {
            if (current_parent_card_id == null) {
                empty_message_changed("Drag card center onto another card to nest. Drag left/right edges to reorder.");
            } else {
                empty_message_changed("Inside nested cards. Enter opens item/folder. Backspace goes up.");
            }
        }
    }

    public void activate_position(uint position) {
        var tile = visible_tiles.get_item(position) as FlowboardTile;
        if (tile == null) {
            return;
        }
        if (tile.project_id != null) {
            select_project(tile.project_id);
            return;
        }
        if (tile.card_id == null) {
            return;
        }
        if (tile.is_container) {
            current_parent_card_id = tile.card_id;
            parent_stack_ids.add(tile.card_id);
            refresh();
            return;
        }
        card_open_requested(tile.card_id);
    }

    public void navigate_up() {
        if (parent_stack_ids.size == 0) {
            return;
        }
        parent_stack_ids.remove_at(parent_stack_ids.size - 1);
        if (parent_stack_ids.size == 0) {
            current_parent_card_id = null;
        } else {
            current_parent_card_id = parent_stack_ids[parent_stack_ids.size - 1];
        }
        refresh();
    }

    public void navigate_to_breadcrumb_index(int index) {
        if (index <= 0) {
            showing_projects = true;
            current_parent_card_id = null;
            parent_stack_ids.clear();
            refresh();
            return;
        }

        if (index == 1) {
            showing_projects = false;
            current_parent_card_id = null;
            parent_stack_ids.clear();
            refresh();
            return;
        }

        var stack_index = index - 2;
        if (stack_index < 0 || stack_index >= parent_stack_ids.size) {
            return;
        }
        current_parent_card_id = parent_stack_ids[stack_index];
        while (parent_stack_ids.size > stack_index + 1) {
            parent_stack_ids.remove_at(parent_stack_ids.size - 1);
        }
        showing_projects = false;
        refresh();
    }

    public void on_card_drop(string source_card_id, string target_card_id, double target_x_fraction) {
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
        if (target_x_fraction >= 0.25 && target_x_fraction <= 0.75) {
            new_parent = target.card_id;
            if (is_descendant(new_parent, source.card_id)) {
                return;
            }
            new_sort = next_sort_key_for_parent(new_parent, source.card_id);
            toast_requested("Moved \"%s\" into \"%s\"".printf(source.title, target.title));
        } else {
            new_parent = normalize_parent(target.parent_card_id);
            var after = target_x_fraction > 0.75;
            new_sort = sort_key_around_target(source.card_id, target.card_id, new_parent, after);
        }

        apply_local_move(source.card_id, new_parent, new_sort);
        refresh();
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
        refresh();
        move_requested(source.card_id, new_parent, new_sort);
    }

    public void request_create_card_here() {
        if (showing_projects || current_project_id == null) {
            return;
        }
        create_card_requested(current_parent_card_id);
    }

    private void replace_visible_for_parent(string? parent_card_id) {
        visible_tiles.remove_all();
        var sorted = siblings_for_parent(parent_card_id);
        foreach (var card in sorted) {
            var child_count = child_count_for_parent(card.card_id);
            var is_container = child_count > 0;
            visible_tiles.append(new FlowboardTile(
                "card:%s".printf(card.card_id),
                card.title,
                card.updated_at,
                is_container,
                card.card_id,
                null,
                child_count
            ));
        }
    }

    private void replace_visible_with_projects() {
        visible_tiles.remove_all();
        var projects = new Gee.ArrayList<Project>();
        for (uint i = 0; i < project_store.get_n_items(); i++) {
            var project = project_store.get_item(i) as Project;
            if (project != null) {
                projects.add(project);
            }
        }
        projects.sort((a, b) => {
            if (a.updated_at > b.updated_at) {
                return -1;
            }
            if (a.updated_at < b.updated_at) {
                return 1;
            }
            return strcmp(a.name.down(), b.name.down());
        });
        foreach (var project in projects) {
            visible_tiles.append(new FlowboardTile(
                "project:%s".printf(project.project_id),
                project.name,
                project.updated_at,
                true,
                null,
                project.project_id,
                0
            ));
        }
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

    private int child_count_for_parent(string card_id) {
        int count = 0;
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null) {
                continue;
            }
            if (normalize_parent(card.parent_card_id) == card_id) {
                count++;
            }
        }
        return count;
    }

    private bool is_descendant(string? candidate_parent_card_id, string card_id) {
        if (candidate_parent_card_id == null) {
            return false;
        }
        string? cursor = candidate_parent_card_id;
        int guard = 0;
        while (cursor != null && guard < 256) {
            if (cursor == card_id) {
                return true;
            }
            var card = find_card(cursor);
            cursor = card == null ? null : normalize_parent(card.parent_card_id);
            guard++;
        }
        return false;
    }

    private Gee.ArrayList<FlowboardBreadcrumbSegment> build_breadcrumb_segments(string project_name) {
        var segments = new Gee.ArrayList<FlowboardBreadcrumbSegment>();
        segments.add(new FlowboardBreadcrumbSegment("Projects"));
        if (showing_projects) {
            return segments;
        }
        if (project_name != null && project_name.length > 0) {
            segments.add(new FlowboardBreadcrumbSegment(project_name));
        }
        foreach (var parent_id in parent_stack_ids) {
            var card = find_card(parent_id);
            if (card != null) {
                segments.add(new FlowboardBreadcrumbSegment(card.title));
            }
        }
        return segments;
    }

    private int compare_for_flowboard(CardSummary a, CardSummary b) {
        if (a.sort_key < b.sort_key) {
            return -1;
        }
        if (a.sort_key > b.sort_key) {
            return 1;
        }
        if (a.updated_at > b.updated_at) {
            return -1;
        }
        if (a.updated_at < b.updated_at) {
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
        siblings.sort((a, b) => compare_for_flowboard(a, b));
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

    private void select_project(string project_id) {
        for (uint i = 0; i < project_store.get_n_items(); i++) {
            var project = project_store.get_item(i) as Project;
            if (project != null && project.project_id == project_id) {
                project_selection.set_selected(i);
                current_project_id = project_id;
                current_parent_card_id = null;
                parent_stack_ids.clear();
                showing_projects = false;
                refresh();
                return;
            }
        }
    }
}

}
