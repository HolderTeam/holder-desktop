namespace HolderLinux {

public class ConnectionsBoardModel : Object {
    public Gee.ArrayList<ConnectionsBoardNode> nodes { get; construct; }
    public Gee.ArrayList<ConnectionsBoardEdge> edges { get; construct; }
    public string summary { get; construct; }

    public ConnectionsBoardModel(Gee.ArrayList<ConnectionsBoardNode> nodes,
                                 Gee.ArrayList<ConnectionsBoardEdge> edges,
                                 string summary) {
        Object(nodes: nodes, edges: edges, summary: summary);
    }
}

public class ConnectionsBoardBuilder : Object {
    public const int PROJECT_MODE_MAX_NODES = 12;
    public const string CARD_MODE_SUMMARY = "Card-focused graph.";

    private ConnectionsController controller;

    public ConnectionsBoardBuilder(ConnectionsController controller) {
        this.controller = controller;
    }

    public static Gee.ArrayList<CardSummary> cards_in_project(Project project,
                                                              Gee.ArrayList<CardSummary> cards) {
        var project_cards = new Gee.ArrayList<CardSummary>();
        foreach (var card in cards) {
            if (card.project_id == project.project_id) {
                project_cards.add(card);
            }
        }
        return project_cards;
    }

    public ConnectionsBoardModel build_card_mode(Project project,
                                                 CardSummary selected_card,
                                                 Gee.ArrayList<CardLink> outgoing,
                                                 Gee.ArrayList<CardLink> backlinks,
                                                 Gee.ArrayList<string> internal_links,
                                                 Gee.ArrayList<CardSummary> cards) {
        var project_cards = cards_in_project(project, cards);
        var nodes_by_id = new Gee.HashMap<string, ConnectionsBoardNode>();
        nodes_by_id.set(selected_card.card_id, new ConnectionsBoardNode(
            selected_card.card_id,
            controller.ellipsize_title(selected_card.title),
            selected_card.updated_at,
            controller.child_count_for(selected_card.card_id, cards)
        ));
        var edges = new Gee.ArrayList<ConnectionsBoardEdge>();
        var edge_keys = new Gee.HashSet<string>();

        foreach (var link in outgoing) {
            if (link.to_type != "card") {
                continue;
            }
            controller.add_board_edge(nodes_by_id, edge_keys, edges, link.from_card_id, link.to_card_id, controller.normalized_link_kind(link.kind), false, cards);
        }
        foreach (var link in backlinks) {
            if (link.to_type != "card") {
                continue;
            }
            controller.add_board_edge(nodes_by_id, edge_keys, edges, link.from_card_id, link.to_card_id, controller.normalized_link_kind(link.kind), false, cards);
        }

        foreach (var edge in controller.build_structural_edges_for_selected(selected_card, project_cards)) {
            controller.add_board_edge(nodes_by_id, edge_keys, edges, edge.from_card_id, edge.to_card_id, edge.kind, true, cards);
        }
        foreach (var target in internal_links) {
            var target_card_id = controller.resolve_internal_link_target_card_id(target, project.project_id, cards);
            if (target_card_id != null && target_card_id != selected_card.card_id) {
                controller.add_board_edge(nodes_by_id, edge_keys, edges, selected_card.card_id, target_card_id, "internal", true, cards);
            }
        }

        var node_list = new Gee.ArrayList<ConnectionsBoardNode>();
        foreach (var node in nodes_by_id.values) {
            node_list.add(node);
        }
        node_list.sort((a, b) => strcmp(a.title.down(), b.title.down()));
        controller.layout_card_mode_nodes(
            selected_card.card_id,
            node_list,
            ConnectionsBoardPresenter.MIN_WIDTH,
            ConnectionsBoardPresenter.NODE_WIDTH,
            ConnectionsBoardPresenter.NODE_HEIGHT,
            ConnectionsBoardPresenter.PADDING,
            controller.target_board_height_for_count(node_list.size)
        );
        controller.spread_nodes_to_avoid_overlap(
            node_list, ConnectionsBoardPresenter.NODE_WIDTH, ConnectionsBoardPresenter.NODE_HEIGHT
        );
        return new ConnectionsBoardModel(node_list, edges, CARD_MODE_SUMMARY);
    }

    // Reorders `project_cards` in place (most connected first).
    public ConnectionsBoardModel build_project_mode(Gee.ArrayList<CardSummary> project_cards,
                                                    Gee.ArrayList<CardLink> project_links) {
        var all_edges = new Gee.ArrayList<ConnectionsBoardEdge>();
        var edge_keys = new Gee.HashSet<string>();
        var counts = new Gee.HashMap<string, int>();
        foreach (var link in project_links) {
            var kind = controller.normalized_link_kind(link.kind);
            if (controller.add_edge_to_list(edge_keys, all_edges, link.from_card_id, link.to_card_id, kind, false)) {
                controller.increment_count(counts, kind);
            }
        }
        foreach (var edge in controller.build_structural_edges_for_project(project_cards)) {
            if (controller.add_edge_to_list(edge_keys, all_edges, edge.from_card_id, edge.to_card_id, edge.kind, true)) {
                controller.increment_count(counts, edge.kind);
            }
        }

        var degree = new Gee.HashMap<string, int>();
        foreach (var card in project_cards) {
            degree.set(card.card_id, 0);
        }
        foreach (var edge in all_edges) {
            degree.set(edge.from_card_id, degree.get(edge.from_card_id) + 1);
            degree.set(edge.to_card_id, degree.get(edge.to_card_id) + 1);
        }

        project_cards.sort((a, b) => {
            var da = degree.get(a.card_id);
            var db = degree.get(b.card_id);
            if (da != db) {
                return db - da;
            }
            return strcmp(a.title.down(), b.title.down());
        });
        var keep = new Gee.HashSet<string>();
        for (int i = 0; i < project_cards.size && i < PROJECT_MODE_MAX_NODES; i++) {
            keep.add(project_cards[i].card_id);
        }
        var nodes = new Gee.ArrayList<ConnectionsBoardNode>();
        foreach (var card in project_cards) {
            if (!keep.contains(card.card_id)) {
                continue;
            }
            nodes.add(new ConnectionsBoardNode(
                card.card_id,
                controller.ellipsize_title(card.title),
                card.updated_at,
                controller.child_count_for(card.card_id, project_cards)
            ));
        }
        var edges = new Gee.ArrayList<ConnectionsBoardEdge>();
        foreach (var edge in all_edges) {
            if (keep.contains(edge.from_card_id) && keep.contains(edge.to_card_id)) {
                edges.add(edge);
            }
        }
        controller.layout_project_mode_nodes(
            nodes, ConnectionsBoardPresenter.PADDING,
            ConnectionsBoardPresenter.NODE_WIDTH, ConnectionsBoardPresenter.NODE_HEIGHT
        );
        controller.spread_nodes_to_avoid_overlap(
            nodes, ConnectionsBoardPresenter.NODE_WIDTH, ConnectionsBoardPresenter.NODE_HEIGHT
        );
        return new ConnectionsBoardModel(nodes, edges, controller.format_counts_summary(counts));
    }
}

}
