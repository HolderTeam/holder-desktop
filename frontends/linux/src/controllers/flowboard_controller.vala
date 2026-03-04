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
    public signal void move_intent_requested(string card_id,
                                             string project_id,
                                             string intent,
                                             string? target_card_id,
                                             string? parent_card_id);
    public signal void create_card_requested(string? parent_card_id);
    public signal void toast_requested(string message);
    public signal void project_overview_requested(string project_id);

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

        if (current_parent_card_id != null
            && card_store.get_n_items() > 0
            && find_card(current_parent_card_id) == null) {
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
        activate_tile(tile);
    }

    internal void activate_tile(FlowboardTile tile) {
        if (tile.project_id != null) {
            select_project(tile.project_id);
            project_overview_requested(tile.project_id);
            return;
        }
        if (tile.card_id == null) {
            return;
        }
        activate_card(tile.card_id);
    }

    public void open_card_from_context_menu(string card_id) {
        activate_card(card_id);
    }

    public void move_card_up_level_from_context_menu(string card_id) {
        var card = find_card(card_id);
        if (card == null) {
            return;
        }
        var parent_id = normalize_parent(card.parent_card_id);
        if (parent_id == null) {
            return;
        }
        var parent = find_card(parent_id);
        string? new_parent = null;
        if (parent != null) {
            new_parent = normalize_parent(parent.parent_card_id);
        }
        emit_move_intent(card_id, "up_level", null, new_parent);
        var destination = destination_label_for_parent(new_parent);
        toast_requested("Moved %s into %s".printf(card.title, destination));
    }

    public void move_card_to_start_from_context_menu(string card_id) {
        var card = find_card(card_id);
        if (card == null) {
            return;
        }
        var parent_id = normalize_parent(card.parent_card_id);
        var siblings = siblings_for_parent(parent_id, card_id);
        if (siblings.size == 0) {
            return;
        }
        emit_move_intent(card_id, "to_start", null, parent_id);
    }

    public void move_card_left_from_context_menu(string card_id) {
        var card = find_card(card_id);
        if (card == null) {
            return;
        }
        var parent_id = normalize_parent(card.parent_card_id);
        var siblings = siblings_for_parent(parent_id, null);
        int index = -1;
        for (int i = 0; i < siblings.size; i++) {
            if (siblings[i].card_id == card_id) {
                index = i;
                break;
            }
        }
        if (index <= 0) {
            return;
        }
        var target_id = siblings[index - 1].card_id;
        emit_move_intent(card_id, "before", target_id, parent_id);
    }

    public void move_card_right_from_context_menu(string card_id) {
        var card = find_card(card_id);
        if (card == null) {
            return;
        }
        var parent_id = normalize_parent(card.parent_card_id);
        var siblings = siblings_for_parent(parent_id, null);
        int index = -1;
        for (int i = 0; i < siblings.size; i++) {
            if (siblings[i].card_id == card_id) {
                index = i;
                break;
            }
        }
        if (index < 0 || index >= siblings.size - 1) {
            return;
        }
        var target_id = siblings[index + 1].card_id;
        emit_move_intent(card_id, "after", target_id, parent_id);
    }

    public void move_card_to_end_from_context_menu(string card_id) {
        var card = find_card(card_id);
        if (card == null) {
            return;
        }
        var parent_id = normalize_parent(card.parent_card_id);
        emit_move_intent(card_id, "to_end", null, parent_id);
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
            var selected_project = project_selection.get_selected_item() as Project;
            if (selected_project != null) {
                project_overview_requested(selected_project.project_id);
            }
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

        if (target_x_fraction >= 0.25 && target_x_fraction <= 0.75) {
            var new_parent = target.card_id;
            if (is_descendant(new_parent, source.card_id)) {
                return;
            }
            toast_requested("Moved \"%s\" into \"%s\"".printf(source.title, target.title));
            emit_move_intent(source.card_id, "into", target.card_id, new_parent);
        } else {
            var new_parent = normalize_parent(target.parent_card_id);
            var intent = target_x_fraction > 0.75 ? "after" : "before";
            emit_move_intent(source.card_id, intent, target.card_id, new_parent);
        }
    }

    public void on_background_drop(string source_card_id) {
        var source = find_card(source_card_id);
        if (source == null) {
            return;
        }
        emit_move_intent(source.card_id, "to_end", null, null);
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
        for (int i = 0; i < sorted.size; i++) {
            var card = sorted[i];
            var child_count = child_count_for_parent(card.card_id);
            var is_container = child_count > 0;
            visible_tiles.append(new FlowboardTile(
                "card:%s".printf(card.card_id),
                card.title,
                card.updated_at,
                is_container,
                card.card_id,
                null,
                parent_card_id,
                sorted.size,
                i,
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
            var root_count = root_card_count_for_project(project.project_id);
            visible_tiles.append(new FlowboardTile(
                "project:%s".printf(project.project_id),
                project.name,
                project.updated_at,
                true,
                null,
                project.project_id,
                null,
                0,
                0,
                root_count
            ));
        }
    }

    private int root_card_count_for_project(string project_id) {
        var source_cards = new Gee.ArrayList<CardSummary?>();
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            source_cards.add(card_store.get_item(i) as CardSummary);
        }
        return count_root_cards_for_project(source_cards, project_id);
    }

    internal static int count_root_cards_for_project(Gee.ArrayList<CardSummary?> source_cards,
                                                     string project_id) {
        int count = 0;
        foreach (var card in source_cards) {
            if (card == null) {
                continue;
            }
            if (card.project_id == project_id && normalize_parent(card.parent_card_id) == null) {
                count++;
            }
        }
        return count;
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
        var source_cards = new Gee.ArrayList<CardSummary?>();
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            source_cards.add(card_store.get_item(i) as CardSummary);
        }
        return count_children_for_parent(source_cards, card_id);
    }

    private bool is_descendant(string? candidate_parent_card_id, string card_id) {
        var source_cards = new Gee.ArrayList<CardSummary?>();
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            source_cards.add(card_store.get_item(i) as CardSummary);
        }
        return is_descendant_in_cards(source_cards, candidate_parent_card_id, card_id);
    }

    internal static bool is_descendant_in_cards(Gee.ArrayList<CardSummary?> source_cards,
                                                string? candidate_parent_card_id,
                                                string card_id) {
        if (candidate_parent_card_id == null) {
            return false;
        }
        string? cursor = candidate_parent_card_id;
        int guard = 0;
        while (cursor != null && guard < 256) {
            if (cursor == card_id) {
                return true;
            }
            CardSummary? card = null;
            foreach (var candidate in source_cards) {
                if (candidate != null && candidate.card_id == cursor) {
                    card = candidate;
                    break;
                }
            }
            cursor = card == null ? null : normalize_parent(card.parent_card_id);
            guard++;
        }
        return false;
    }

    internal static int count_children_for_parent(Gee.ArrayList<CardSummary?> source_cards,
                                                  string card_id) {
        int count = 0;
        foreach (var card in source_cards) {
            if (card == null) {
                continue;
            }
            if (normalize_parent(card.parent_card_id) == card_id) {
                count++;
            }
        }
        return count;
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

    private static int compare_for_flowboard(CardSummary a, CardSummary b) {
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

    private static string? normalize_parent(string? parent_card_id) {
        if (parent_card_id == null) {
            return null;
        }
        var trimmed = parent_card_id.strip();
        return trimmed.length == 0 ? null : trimmed;
    }

    private Gee.ArrayList<CardSummary> siblings_for_parent(string? parent_card_id, string? exclude_card_id = null) {
        var source_cards = new Gee.ArrayList<CardSummary?>();
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            source_cards.add(card_store.get_item(i) as CardSummary);
        }
        return siblings_for_parent_in_cards(source_cards, parent_card_id, exclude_card_id);
    }

    internal static Gee.ArrayList<CardSummary> siblings_for_parent_in_cards(
        Gee.ArrayList<CardSummary?> source_cards,
        string? parent_card_id,
        string? exclude_card_id = null
    ) {
        var siblings = new Gee.ArrayList<CardSummary>();
        foreach (var card in source_cards) {
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

    private void emit_move_intent(string card_id,
                                  string intent,
                                  string? target_card_id,
                                  string? parent_card_id) {
        var selected_project = project_selection.get_selected_item() as Project;
        if (selected_project == null) {
            return;
        }
        move_intent_requested(
            card_id,
            selected_project.project_id,
            intent,
            target_card_id,
            parent_card_id
        );
    }

    private void activate_card(string card_id) {
        var card = find_card(card_id);
        if (card == null) {
            return;
        }
        var is_container = child_count_for_parent(card_id) > 0;
        if (is_container) {
            card_open_requested(card_id);
            current_parent_card_id = card_id;
            parent_stack_ids.add(card_id);
            refresh();
            return;
        }
        card_open_requested(card_id);
    }

    private string destination_label_for_parent(string? parent_card_id) {
        var normalized = normalize_parent(parent_card_id);
        if (normalized != null) {
            var parent_card = find_card(normalized);
            if (parent_card != null) {
                return parent_card.title;
            }
        }
        var selected_project = project_selection.get_selected_item() as Project;
        if (selected_project != null) {
            return selected_project.name;
        }
        return "project";
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
