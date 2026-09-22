namespace HolderLinux {

public class ConnectionsBoardCanvasSize : Object {
    public int width { get; construct; }
    public int height { get; construct; }

    public ConnectionsBoardCanvasSize(int width, int height) {
        Object(width: width, height: height);
    }
}

public class ConnectionsBoardPresenter : Object {
    public const int NODE_WIDTH = 220;
    public const int NODE_HEIGHT = 76;
    public const int PADDING = 48;
    public const int MIN_WIDTH = 900;
    public const int MIN_HEIGHT = 240;
    public const int BOTTOM_PADDING = 16;

    private ConnectionsController controller;

    public ConnectionsBoardPresenter(ConnectionsController controller) {
        this.controller = controller;
    }

    public string relations_title(bool show_projects_root,
                                  Project? selected_project,
                                  CardSummary? selected_card) {
        if (show_projects_root) {
            return "Projects";
        }
        if (selected_card != null) {
            return controller.ellipsize_title(selected_card.title);
        }
        if (selected_project != null) {
            return controller.ellipsize_title(selected_project.name);
        }
        return "Relations";
    }

    // Where the graph/relations divider goes on first layout: the relations pane gets 320 px,
    // but never leaves the graph under 520 px or the relations pane under 260 px.
    public static int default_relations_split_position(int total_width) {
        int position = total_width - 320;
        if (position < 520) {
            position = 520;
        }
        if (position > total_width - 260) {
            position = total_width - 260;
        }
        return position;
    }

    public bool add_link_enabled(bool show_projects_root,
                                 bool api_available,
                                 CardSummary? selected_card,
                                 Gee.List<CardSummary> cards) {
        if (show_projects_root) {
            return false;
        }
        var has_target = controller.has_graph_link_targets(selected_card, cards);
        return api_available && selected_card != null && has_target;
    }

    public Gee.ArrayList<ConnectionsBoardNode> build_projects_root_nodes(Gee.List<Project> projects) {
        var nodes = new Gee.ArrayList<ConnectionsBoardNode>();
        foreach (var project in projects) {
            nodes.add(new ConnectionsBoardNode(
                "project:%s".printf(project.project_id),
                controller.ellipsize_title(project.name),
                project.updated_at,
                project.root_card_count
            ));
        }
        if (nodes.size == 0) {
            return nodes;
        }
        controller.layout_project_mode_nodes(nodes, PADDING, NODE_WIDTH, NODE_HEIGHT);
        controller.spread_nodes_to_avoid_overlap(nodes, NODE_WIDTH, NODE_HEIGHT);
        return nodes;
    }

    public ConnectionsBoardCanvasSize canvas_size(Gee.List<ConnectionsBoardNode> nodes) {
        int required_w = MIN_WIDTH;
        int required_h = controller.target_board_height_for_count(nodes.size);
        int content_bottom = 0;
        foreach (var node in nodes) {
            required_w = int.max(required_w, node.x + NODE_WIDTH + PADDING);
            content_bottom = int.max(content_bottom, node.y + NODE_HEIGHT);
        }
        if (nodes.size > 0) {
            // Trim only the trailing space under the last node; keep node spacing/layout untouched.
            required_h = int.max(MIN_HEIGHT, content_bottom + BOTTOM_PADDING);
        }
        return new ConnectionsBoardCanvasSize(required_w, required_h);
    }
}

}
