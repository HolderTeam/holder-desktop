namespace HolderLinux {

public class ConnectionsBoardNode : Object {
    public string card_id { get; construct; }
    public string title { get; construct; }
    public int64 updated_at { get; construct; }
    public int child_count { get; construct; }
    public int x { get; set; }
    public int y { get; set; }

    public ConnectionsBoardNode(string card_id,
                                string title,
                                int64 updated_at = 0,
                                int child_count = 0,
                                int x = 0,
                                int y = 0) {
        Object(
            card_id: card_id,
            title: title,
            updated_at: updated_at,
            child_count: child_count,
            x: x,
            y: y
        );
    }
}

public class ConnectionsBoardEdge : Object {
    public string from_card_id { get; construct; }
    public string to_card_id { get; construct; }
    public string kind { get; construct; }
    public bool dashed { get; construct; }

    public ConnectionsBoardEdge(string from_card_id, string to_card_id, string kind, bool dashed = false) {
        Object(from_card_id: from_card_id, to_card_id: to_card_id, kind: kind, dashed: dashed);
    }
}

public class GraphLinkTargetOption : Object {
    public string card_id { get; construct; }
    public string display_text { get; construct; }

    public GraphLinkTargetOption(string card_id, string display_text) {
        Object(card_id: card_id, display_text: display_text);
    }
}

public class ConnectionsLinkAction : Object {
    public bool handled { get; construct; }
    public bool select_card { get; construct; }
    public bool select_project { get; construct; }
    public string target_id { get; construct; }

    public ConnectionsLinkAction(bool handled,
                                 bool select_card = false,
                                 bool select_project = false,
                                 string target_id = "") {
        Object(
            handled: handled,
            select_card: select_card,
            select_project: select_project,
            target_id: target_id
        );
    }
}

public class ConnectionsLinkKindGroup : Object {
    public string kind { get; construct; }
    public Gee.ArrayList<CardLink> links { get; construct; }

    public ConnectionsLinkKindGroup(string kind, Gee.ArrayList<CardLink> links) {
        Object(kind: kind, links: links);
    }
}

public class ConnectionsGraphLoadResult : Object {
    public bool success { get; construct; }
    public Gee.ArrayList<CardLink>? outgoing { get; construct; }
    public Gee.ArrayList<CardLink>? backlinks { get; construct; }
    public string outgoing_empty_text { get; construct; }
    public string backlinks_empty_text { get; construct; }
    public string debug_message { get; construct; }

    public ConnectionsGraphLoadResult(bool success,
                                      Gee.ArrayList<CardLink>? outgoing = null,
                                      Gee.ArrayList<CardLink>? backlinks = null,
                                      string outgoing_empty_text = "",
                                      string backlinks_empty_text = "",
                                      string debug_message = "") {
        Object(
            success: success,
            outgoing: outgoing,
            backlinks: backlinks,
            outgoing_empty_text: outgoing_empty_text,
            backlinks_empty_text: backlinks_empty_text,
            debug_message: debug_message
        );
    }
}

public class ConnectionsMutationResult : Object {
    public bool success { get; construct; }
    public bool ignored { get; construct; }
    public string toast_message { get; construct; }
    public string error_title { get; construct; }
    public string error_details { get; construct; }
    public bool should_refresh { get; construct; }

    public ConnectionsMutationResult(bool success,
                                     bool ignored = false,
                                     string toast_message = "",
                                     string error_title = "",
                                     string error_details = "",
                                     bool should_refresh = false) {
        Object(
            success: success,
            ignored: ignored,
            toast_message: toast_message,
            error_title: error_title,
            error_details: error_details,
            should_refresh: should_refresh
        );
    }
}

public class ConnectionsGraphRefreshTarget : Object {
    public string mode { get; construct; }
    public string project_id { get; construct; }
    public string card_id { get; construct; }
    public uint content_generation { get; construct; }

    public ConnectionsGraphRefreshTarget(string mode,
                                         string project_id = "",
                                         string card_id = "",
                                         uint content_generation = 0) {
        Object(
            mode: mode,
            project_id: project_id,
            card_id: card_id,
            content_generation: content_generation
        );
    }

    public string to_key() {
        return "%s|%s|%s|%u".printf(mode, project_id, card_id, content_generation);
    }
}

public class ConnectionsController : Object {
    internal static int ellipsize_cutoff_override_for_tests = int.MIN;

    private string? normalize_parent(string? parent_card_id) {
        if (parent_card_id == null) {
            return null;
        }
        var trimmed = parent_card_id.strip();
        return trimmed.length == 0 ? null : trimmed;
    }

    private int compare_sibling_order(CardSummary a, CardSummary b) {
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

    public string ellipsize_title(string? title) {
        if (title == null) {
            return "";
        }
        if (title.char_count() < 47) {
            return title;
        }
        int cutoff = ellipsize_cutoff_override_for_tests;
        if (cutoff == int.MIN) {
            cutoff = title.index_of_nth_char(44);
        }
        if (cutoff < 0) {
            return title;
        }
        return title.substring(0, cutoff) + "...";
    }

    public Gee.ArrayList<string> list_available_link_kinds(Settings? settings) {
        var values = new Gee.ArrayList<string>();
        values.add("ref");
        values.add("depends_on");
        values.add("example_of");
        values.add("blocks");
        values.add("related_to");

        if (settings == null) {
            return values;
        }

        foreach (var kind in settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS)) {
            var cleaned = kind.strip();
            if (cleaned.length == 0 || cleaned == "custom" || values.contains(cleaned)) {
                continue;
            }
            values.add(cleaned);
        }
        return values;
    }

    public void remember_custom_link_kind(Settings? settings, string kind) {
        if (settings == null) {
            return;
        }
        var cleaned = kind.strip();
        if (cleaned.length == 0 || cleaned == "custom") {
            return;
        }

        var defaults = new Gee.HashSet<string>();
        defaults.add("ref");
        defaults.add("depends_on");
        defaults.add("example_of");
        defaults.add("blocks");
        defaults.add("related_to");
        if (defaults.contains(cleaned)) {
            return;
        }

        var custom = new Gee.ArrayList<string>();
        foreach (var existing in settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS)) {
            var item = existing.strip();
            if (item.length == 0 || item == "custom" || defaults.contains(item) || custom.contains(item)) {
                continue;
            }
            custom.add(item);
        }
        if (custom.contains(cleaned)) {
            return;
        }

        custom.add(cleaned);
        while (custom.size > 20) {
            custom.remove_at(0);
        }

        string[] stored = new string[custom.size];
        for (int i = 0; i < custom.size; i++) {
            stored[i] = custom[i];
        }
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, stored);
    }

    public async ConnectionsGraphLoadResult load_graph_links(IHolderApi? api, CardSummary? selected_card) {
        if (api == null) {
            return new ConnectionsGraphLoadResult(
                false,
                null,
                null,
                "API unavailable.",
                "API unavailable."
            );
        }
        if (selected_card == null) {
            return new ConnectionsGraphLoadResult(
                false,
                null,
                null,
                "Select a card to view graph links.",
                "Select a card to view graph links."
            );
        }
        try {
            var outgoing = yield api.list_card_links(selected_card.card_id);
            var backlinks = yield api.list_card_backlinks(selected_card.card_id);
            return new ConnectionsGraphLoadResult(true, outgoing, backlinks);
        } catch (Error e) {
            return new ConnectionsGraphLoadResult(
                false,
                null,
                null,
                "Failed to load outgoing links.",
                "Failed to load backlinks.",
                "Graph links refresh failed: %s".printf(e.message)
            );
        }
    }

    public bool internal_links_equal(Gee.ArrayList<string> current_links,
                                     Gee.ArrayList<string>? candidate_links) {
        int candidate_size = candidate_links != null ? candidate_links.size : 0;
        if (current_links.size != candidate_size) {
            return false;
        }
        if (candidate_links == null) {
            return true;
        }
        for (int i = 0; i < candidate_links.size; i++) {
            if (current_links[i] != candidate_links[i]) {
                return false;
            }
        }
        return true;
    }

    public ConnectionsGraphRefreshTarget build_graph_refresh_target(bool show_projects_root,
                                                                    Project? selected_project,
                                                                    CardSummary? selected_card,
                                                                    uint content_generation) {
        if (selected_card != null
            && selected_project != null
            && selected_card.project_id != selected_project.project_id) {
            selected_card = null;
        }
        string mode = "project_root";
        string project_id = selected_project != null ? selected_project.project_id : "";
        string card_id = "";
        if (show_projects_root) {
            mode = "projects_root";
            project_id = "";
        } else if (selected_card != null) {
            mode = "card_focus";
            card_id = selected_card.card_id;
        }
        return new ConnectionsGraphRefreshTarget(
            mode,
            project_id,
            card_id,
            content_generation
        );
    }

    public string normalized_link_kind(string? kind) {
        if (kind == null) {
            return "ref";
        }
        var cleaned = kind.strip();
        return cleaned.length > 0 ? cleaned : "ref";
    }

    public int child_count_for(string card_id, Gee.ArrayList<CardSummary> cards) {
        int count = 0;
        foreach (var card in cards) {
            if (normalize_parent(card.parent_card_id) == card_id) {
                count++;
            }
        }
        return count;
    }

    public CardSummary? find_card_by_id(string card_id, Gee.ArrayList<CardSummary> cards) {
        foreach (var card in cards) {
            if (card.card_id == card_id) {
                return card;
            }
        }
        return null;
    }

    public void ensure_board_node(Gee.HashMap<string, ConnectionsBoardNode> nodes_by_id,
                                  string card_id,
                                  Gee.ArrayList<CardSummary> cards) {
        if (nodes_by_id.has_key(card_id)) {
            return;
        }
        var title = ellipsize_title(title_for_card_id(card_id, cards));
        int64 updated_at = 0;
        var card = find_card_by_id(card_id, cards);
        if (card != null) {
            updated_at = card.updated_at;
        }
        nodes_by_id.set(card_id, new ConnectionsBoardNode(
            card_id,
            title,
            updated_at,
            child_count_for(card_id, cards)
        ));
    }

    public bool add_edge_to_list(Gee.HashSet<string> edge_keys,
                                 Gee.ArrayList<ConnectionsBoardEdge> edges,
                                 string from_card_id,
                                 string to_card_id,
                                 string kind,
                                 bool dashed) {
        if (from_card_id == to_card_id) {
            return false;
        }
        var key = "%s|%s|%s".printf(from_card_id, to_card_id, kind);
        if (edge_keys.contains(key)) {
            return false;
        }
        edge_keys.add(key);
        edges.add(new ConnectionsBoardEdge(from_card_id, to_card_id, kind, dashed));
        return true;
    }

    public void add_board_edge(Gee.HashMap<string, ConnectionsBoardNode> nodes_by_id,
                               Gee.HashSet<string> edge_keys,
                               Gee.ArrayList<ConnectionsBoardEdge> edges,
                               string from_card_id,
                               string to_card_id,
                               string kind,
                               bool dashed,
                               Gee.ArrayList<CardSummary> cards) {
        if (!add_edge_to_list(edge_keys, edges, from_card_id, to_card_id, kind, dashed)) {
            return;
        }
        ensure_board_node(nodes_by_id, from_card_id, cards);
        ensure_board_node(nodes_by_id, to_card_id, cards);
    }

    public Gee.ArrayList<ConnectionsBoardEdge> build_structural_edges_for_selected(CardSummary selected_card,
                                                                                   Gee.ArrayList<CardSummary> project_cards) {
        var out = new Gee.ArrayList<ConnectionsBoardEdge>();
        var siblings = sibling_cards(selected_card, project_cards);
        int selected_index = -1;
        for (int i = 0; i < siblings.size; i++) {
            if (siblings[i].card_id == selected_card.card_id) {
                selected_index = i;
                break;
            }
        }
        if (selected_index > 0) {
            out.add(new ConnectionsBoardEdge(siblings[selected_index - 1].card_id, selected_card.card_id, "next", true));
        }
        if (selected_index >= 0 && selected_index < siblings.size - 1) {
            out.add(new ConnectionsBoardEdge(selected_card.card_id, siblings[selected_index + 1].card_id, "next", true));
        }
        var parent_id = normalize_parent(selected_card.parent_card_id);
        if (parent_id != null) {
            out.add(new ConnectionsBoardEdge(parent_id, selected_card.card_id, "child", true));
        }
        foreach (var card in project_cards) {
            if (normalize_parent(card.parent_card_id) == selected_card.card_id) {
                out.add(new ConnectionsBoardEdge(selected_card.card_id, card.card_id, "child", true));
            }
        }
        return out;
    }

    public Gee.ArrayList<ConnectionsBoardEdge> build_structural_edges_for_project(Gee.ArrayList<CardSummary> project_cards) {
        var out = new Gee.ArrayList<ConnectionsBoardEdge>();
        var parent_groups = new Gee.HashMap<string, Gee.ArrayList<CardSummary>>();
        foreach (var card in project_cards) {
            var parent_key = normalize_parent(card.parent_card_id) ?? "";
            var group = parent_groups.get(parent_key);
            if (group == null) {
                group = new Gee.ArrayList<CardSummary>();
                parent_groups.set(parent_key, group);
            }
            group.add(card);
            if (parent_key.length > 0) {
                out.add(new ConnectionsBoardEdge(parent_key, card.card_id, "child", true));
            }
        }
        foreach (var group in parent_groups.values) {
            group.sort((a, b) => compare_sibling_order(a, b));
            for (int i = 0; i < group.size - 1; i++) {
                out.add(new ConnectionsBoardEdge(group[i].card_id, group[i + 1].card_id, "next", true));
            }
        }
        return out;
    }

    public void layout_card_mode_nodes(string center_card_id,
                                       Gee.ArrayList<ConnectionsBoardNode> nodes,
                                       int board_min_width,
                                       int board_node_width,
                                       int board_node_height,
                                       int board_padding,
                                       int canvas_height) {
        int cx = board_min_width / 2 - board_node_width / 2;
        int cy = int.max(12, (canvas_height / 2 - board_node_height / 2) - 70);
        var ring = new Gee.ArrayList<ConnectionsBoardNode>();
        foreach (var node in nodes) {
            if (node.card_id == center_card_id) {
                node.x = cx;
                node.y = cy;
            } else {
                ring.add(node);
            }
        }
        if (ring.size == 0) {
            return;
        }
        int step_x = board_node_width + 56;
        int step_y = board_node_height + 34;
        int placed = 0;
        for (int radius = 1; placed < ring.size; radius++) {
            for (int grid_y = -radius; grid_y <= radius && placed < ring.size; grid_y++) {
                for (int grid_x = -radius; grid_x <= radius && placed < ring.size; grid_x++) {
                    if (imax(iabs(grid_x), iabs(grid_y)) != radius) {
                        continue;
                    }
                    ring[placed].x = int.max(board_padding / 2, cx + grid_x * step_x);
                    ring[placed].y = int.max(board_padding / 2, cy + grid_y * step_y);
                    placed++;
                }
            }
        }
    }

    public void layout_project_mode_nodes(Gee.ArrayList<ConnectionsBoardNode> nodes,
                                          int board_padding,
                                          int board_node_width,
                                          int board_node_height) {
        if (nodes.size == 0) {
            return;
        }
        int cols = 1;
        while ((cols * cols) < nodes.size) {
            cols++;
        }
        int gap_x = 36;
        int gap_y = 36;
        int start_x = board_padding;
        int start_y = 20;
        for (int i = 0; i < nodes.size; i++) {
            int col = i % cols;
            int row = i / cols;
            nodes[i].x = start_x + col * (board_node_width + gap_x);
            nodes[i].y = start_y + row * (board_node_height + gap_y);
        }
    }

    public void spread_nodes_to_avoid_overlap(Gee.ArrayList<ConnectionsBoardNode> nodes,
                                              int board_node_width,
                                              int board_node_height) {
        int gap = 14;
        if (nodes.size < 2) {
            return;
        }
        var placed = new Gee.ArrayList<ConnectionsBoardNode>();
        for (int i = 0; i < nodes.size; i++) {
            var node = nodes[i];
            int original_x = node.x;
            int original_y = node.y;
            int guard = 0;
            while (overlaps_any(node, placed, gap, board_node_width, board_node_height) && guard < 80) {
                node.y += board_node_height + gap;
                if (node.y > 780) {
                    node.y = original_y + ((guard % 3) * 10);
                    node.x += (board_node_width / 2) + gap;
                }
                guard++;
            }
            if (guard >= 80) {
                node.x = original_x + (i * 22);
                node.y = original_y + (i * 18);
            }
            placed.add(node);
        }
    }

    public int target_board_height_for_count(int node_count) {
        if (node_count <= 1) {
            return 220;
        }
        if (node_count <= 4) {
            return 320;
        }
        if (node_count <= 8) {
            return 430;
        }
        if (node_count <= 14) {
            return 560;
        }
        return 680;
    }

    public string format_counts_summary(Gee.HashMap<string, int> counts) {
        if (counts.size == 0) {
            return "No graph relationships yet.";
        }
        var keys = new Gee.ArrayList<string>();
        foreach (var key in counts.keys) {
            keys.add(key);
        }
        keys.sort((a, b) => {
            var ca = counts.get(a);
            var cb = counts.get(b);
            if (ca != cb) {
                return cb - ca;
            }
            return strcmp(a, b);
        });
        var parts = new Gee.ArrayList<string>();
        foreach (var key in keys) {
            parts.add("• %s: %d".printf(key, counts.get(key)));
        }
        return string.joinv("\n", parts.to_array());
    }

    public void increment_count(Gee.HashMap<string, int> counts, string kind) {
        if (counts.has_key(kind)) {
            counts.set(kind, counts.get(kind) + 1);
            return;
        }
        counts.set(kind, 1);
    }

    private Gee.ArrayList<CardSummary> sibling_cards(CardSummary selected_card, Gee.ArrayList<CardSummary> project_cards) {
        var siblings = new Gee.ArrayList<CardSummary>();
        var target_parent = normalize_parent(selected_card.parent_card_id);
        foreach (var card in project_cards) {
            if (normalize_parent(card.parent_card_id) == target_parent) {
                siblings.add(card);
            }
        }
        siblings.sort((a, b) => compare_sibling_order(a, b));
        return siblings;
    }

    private bool overlaps_any(ConnectionsBoardNode node,
                              Gee.ArrayList<ConnectionsBoardNode> placed,
                              int gap,
                              int board_node_width,
                              int board_node_height) {
        foreach (var other in placed) {
            if (nodes_overlap(node, other, gap, board_node_width, board_node_height)) {
                return true;
            }
        }
        return false;
    }

    private bool nodes_overlap(ConnectionsBoardNode a,
                               ConnectionsBoardNode b,
                               int gap,
                               int board_node_width,
                               int board_node_height) {
        int ax0 = a.x;
        int ay0 = a.y;
        int ax1 = a.x + board_node_width + gap;
        int ay1 = a.y + board_node_height + gap;
        int bx0 = b.x;
        int by0 = b.y;
        int bx1 = b.x + board_node_width + gap;
        int by1 = b.y + board_node_height + gap;
        bool x_overlap = ax0 < bx1 && bx0 < ax1;
        bool y_overlap = ay0 < by1 && by0 < ay1;
        return x_overlap && y_overlap;
    }

    private int iabs(int value) {
        return value < 0 ? -value : value;
    }

    private int imax(int a, int b) {
        return a >= b ? a : b;
    }

    public async ConnectionsMutationResult update_graph_link_flow(IHolderApi? api,
                                                                  CardLink old_link,
                                                                  string new_kind,
                                                                  string? new_label,
                                                                  bool remember_kind,
                                                                  Settings? settings) {
        if (api == null) {
            return new ConnectionsMutationResult(false, true);
        }
        try {
            var kind_changed = old_link.kind != new_kind;
            if (kind_changed) {
                yield api.create_card_link(old_link.from_card_id, old_link.to_card_id, new_kind, new_label, old_link.to_type);
                yield api.delete_card_link(old_link.from_card_id, old_link.to_card_id, old_link.kind, old_link.to_type);
            } else {
                yield api.create_card_link(old_link.from_card_id, old_link.to_card_id, new_kind, new_label, old_link.to_type);
            }
            if (remember_kind) {
                remember_custom_link_kind(settings, new_kind);
            }
            return new ConnectionsMutationResult(true, false, "Graph link updated.", "", "", true);
        } catch (Error e) {
            return new ConnectionsMutationResult(
                false,
                false,
                "",
                "Failed to edit graph link",
                e.message
            );
        }
    }

    public async ConnectionsMutationResult delete_graph_link_flow(IHolderApi? api, CardLink link) {
        if (api == null) {
            return new ConnectionsMutationResult(false, true);
        }
        try {
            yield api.delete_card_link(link.from_card_id, link.to_card_id, link.kind, link.to_type);
            return new ConnectionsMutationResult(true, false, "Graph link deleted.", "", "", true);
        } catch (Error e) {
            return new ConnectionsMutationResult(
                false,
                false,
                "",
                "Failed to delete graph link",
                e.message
            );
        }
    }

    public bool has_graph_link_targets(CardSummary? selected_card,
                                       Gee.List<CardSummary> cards) {
        if (selected_card == null) {
            return false;
        }
        foreach (var card in cards) {
            if (card.project_id != selected_card.project_id) {
                continue;
            }
            if (card.card_id != selected_card.card_id) {
                return true;
            }
        }
        return false;
    }

    public Gee.ArrayList<GraphLinkTargetOption> build_graph_link_target_options(CardSummary? selected_card,
                                                                                 Gee.List<CardSummary> cards) {
        var options = new Gee.ArrayList<GraphLinkTargetOption>();
        if (selected_card == null) {
            return options;
        }
        foreach (var card in cards) {
            if (card.project_id != selected_card.project_id || card.card_id == selected_card.card_id) {
                continue;
            }
            options.add(new GraphLinkTargetOption(
                card.card_id,
                "%s (%s)".printf(card.title, card.card_id)
            ));
        }
        return options;
    }

    public string title_for_card_id(string card_id, Gee.List<CardSummary> cards) {
        foreach (var card in cards) {
            if (card.card_id == card_id) {
                return card.title;
            }
        }
        return card_id;
    }

    public ConnectionsLinkAction resolve_link_action(string uri,
                                                     string? selected_project_id,
                                                     Gee.List<CardSummary> cards) {
        if (uri == null || uri.length == 0) {
            return new ConnectionsLinkAction(false);
        }

        if (uri.has_prefix("card:")) {
            var encoded = uri.substring("card:".length);
            var card_id = Uri.unescape_string(encoded, null);
            if (card_id != null) {
                return new ConnectionsLinkAction(true, true, false, card_id);
            }
            return new ConnectionsLinkAction(false);
        }

        if (uri.has_prefix("project:")) {
            var encoded = uri.substring("project:".length);
            var project_id = Uri.unescape_string(encoded, null);
            if (project_id != null) {
                return new ConnectionsLinkAction(true, false, true, project_id);
            }
            return new ConnectionsLinkAction(false);
        }

        if (uri.has_prefix("ilink:")) {
            var encoded = uri.substring("ilink:".length);
            var target = Uri.unescape_string(encoded, null);
            if (target != null) {
                var card_id = resolve_internal_link_target_card_id(target, selected_project_id, cards);
                if (card_id != null) {
                    return new ConnectionsLinkAction(true, true, false, card_id);
                }
                return new ConnectionsLinkAction(true);
            }
            return new ConnectionsLinkAction(false);
        }

        return new ConnectionsLinkAction(false);
    }

    public Gee.ArrayList<ConnectionsLinkKindGroup> group_links_by_kind(Gee.ArrayList<CardLink> links) {
        var grouped = new Gee.HashMap<string, Gee.ArrayList<CardLink>>();
        var kind_order = new Gee.ArrayList<string>();
        foreach (var link in links) {
            var kind = (link.kind != null && link.kind.strip().length > 0) ? link.kind.strip() : "ref";
            var bucket = grouped.get(kind);
            if (bucket == null) {
                bucket = new Gee.ArrayList<CardLink>();
                grouped.set(kind, bucket);
                kind_order.add(kind);
            }
            bucket.add(link);
        }

        var out_groups = new Gee.ArrayList<ConnectionsLinkKindGroup>();
        foreach (var kind in kind_order) {
            var bucket = grouped.get(kind);
            if (bucket != null) {
                out_groups.add(new ConnectionsLinkKindGroup(kind, bucket));
            }
        }
        return out_groups;
    }

    public string compact_structure_markup(Project? project,
                                           CardSummary? selected_card,
                                           Gee.List<CardSummary> cards) {
        var lines = new Gee.ArrayList<string>();
        if (project != null) {
            lines.add("Project: %s".printf(link_markup("project", project.project_id, project.name)));
        } else {
            lines.add("Project: None");
        }

        if (selected_card != null) {
            var parent_id = normalize_parent(selected_card.parent_card_id);
            if (parent_id != null) {
                foreach (var maybe_parent in cards) {
                    if (maybe_parent.card_id == parent_id) {
                        lines.add(
                            "Parent: %s".printf(
                                link_markup("card", maybe_parent.card_id, maybe_parent.title)
                            )
                        );
                        break;
                    }
                }
            }
        }

        if (selected_card != null) {
            var siblings = new Gee.ArrayList<CardSummary>();
            var parent_id = normalize_parent(selected_card.parent_card_id);
            foreach (var card in cards) {
                if (card.project_id != selected_card.project_id) {
                    continue;
                }
                if (normalize_parent(card.parent_card_id) == parent_id) {
                    siblings.add(card);
                }
            }
            siblings.sort((a, b) => compare_sibling_order(a, b));

            int selected_index = -1;
            for (int i = 0; i < siblings.size; i++) {
                if (siblings[i].card_id == selected_card.card_id) {
                    selected_index = i;
                    break;
                }
            }

            var sibling_parts = new Gee.ArrayList<string>();
            if (selected_index > 0) {
                sibling_parts.add("Previous: %s".printf(
                    link_markup("card", siblings[selected_index - 1].card_id, siblings[selected_index - 1].title)
                ));
            }
            if (selected_index >= 0 && selected_index < siblings.size - 1) {
                sibling_parts.add("Next: %s".printf(
                    link_markup("card", siblings[selected_index + 1].card_id, siblings[selected_index + 1].title)
                ));
            }
            if (sibling_parts.size > 0) {
                lines.add(string.joinv("   ", sibling_parts.to_array()));
            }

            var children = new Gee.ArrayList<CardSummary>();
            foreach (var card in cards) {
                if (card.project_id != selected_card.project_id) {
                    continue;
                }
                if (normalize_parent(card.parent_card_id) == selected_card.card_id) {
                    children.add(card);
                }
            }
            if (children.size > 0) {
                children.sort((a, b) => compare_sibling_order(a, b));
                var child_links = new StringBuilder();
                for (int i = 0; i < children.size; i++) {
                    if (i > 0) {
                        child_links.append(" ");
                    }
                    child_links.append(link_markup("card", children[i].card_id, children[i].title));
                }
                lines.add("Children: %s".printf(child_links.str));
            }
        }

        return string.joinv("\n", lines.to_array());
    }

    public string? resolve_internal_link_target_card_id(string target,
                                                        string? project_id,
                                                        Gee.List<CardSummary> cards) {
        if (target.length == 0 || project_id == null) {
            return null;
        }

        foreach (var card in cards) {
            if (card.project_id != project_id) {
                continue;
            }
            if (card.card_id == target) {
                return card.card_id;
            }
        }

        foreach (var card in cards) {
            if (card.project_id != project_id) {
                continue;
            }
            if (card.title == target) {
                return card.card_id;
            }
        }

        var lowered_target = target.down();
        foreach (var card in cards) {
            if (card.project_id != project_id) {
                continue;
            }
            if (card.title.down() == lowered_target) {
                return card.card_id;
            }
        }

        return null;
    }

    private string link_markup(string kind, string id, string title) {
        var href = "%s:%s".printf(kind, Uri.escape_string(id, null, false));
        return "<a href=\"%s\">%s</a>".printf(
            Markup.escape_text(href),
            Markup.escape_text(ellipsize_title(title))
        );
    }
}

}
