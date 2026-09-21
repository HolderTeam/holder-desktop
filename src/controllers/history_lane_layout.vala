namespace HolderLinux {

public class HistoryLaneLayout : Object {
    public int node_lane { get; construct; }
    public int[] incoming_lanes;
    public int[] outgoing_lanes;
    public int[] parent_lanes;

    public HistoryLaneLayout(int node_lane,
                             int[] incoming_lanes,
                             int[] outgoing_lanes,
                             int[] parent_lanes) {
        Object(node_lane: node_lane);
        this.incoming_lanes = incoming_lanes;
        this.outgoing_lanes = outgoing_lanes;
        this.parent_lanes = parent_lanes;
    }
}

public class HistoryLaneNode : Object {
    public string oid { get; construct; }
    public string[] parent_oids;

    public HistoryLaneNode(string oid, string[] parent_oids) {
        Object(oid: oid);
        this.parent_oids = parent_oids;
    }
}

// Which parents of a node take part in the graph.
public enum HistoryLaneParentRule {
    // Every parent given on the node counts (the card timeline pre-filters them to the
    // parents that are on the page).
    AS_GIVEN,
    // Only parents that are themselves listed as nodes count (the project timeline).
    LISTED_ONLY
}

public class HistoryLaneGraph : Object {
    public int lane_count { get; construct; }
    public HistoryLaneLayout[] layouts;

    public HistoryLaneGraph(int lane_count, HistoryLaneLayout[] layouts) {
        Object(lane_count: lane_count);
        this.layouts = layouts;
    }
}

public class HistoryLaneAssigner { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public static HistoryLaneGraph compute(HistoryLaneNode[] nodes, HistoryLaneParentRule rule) {
        string[] listed_oids = {};
        foreach (var node in nodes) {
            listed_oids += node.oid;
        }

        HistoryLaneLayout[] layouts = {};
        string?[] active_lanes = {};
        int lane_count = 1;
        foreach (var node in nodes) {
            int[] incoming_lanes = {};
            for (int lane = 0; lane < active_lanes.length; lane++) {
                if (active_lanes[lane] != null) incoming_lanes += lane;
            }

            int node_lane = find_lane(active_lanes, node.oid);
            if (node_lane < 0) {
                node_lane = first_free_lane(active_lanes);
                if (node_lane < 0) {
                    node_lane = active_lanes.length;
                    active_lanes += null;
                }
            }
            active_lanes[node_lane] = null;

            int[] parent_lanes = {};
            foreach (var parent_oid in node.parent_oids) {
                if (rule == HistoryLaneParentRule.LISTED_ONLY && !contains_oid(listed_oids, parent_oid)) {
                    continue;
                }
                int parent_lane = find_lane(active_lanes, parent_oid);
                if (parent_lane < 0) {
                    parent_lane = parent_lanes.length == 0
                        ? node_lane
                        : first_free_lane(active_lanes);
                    if (parent_lane < 0) {
                        parent_lane = active_lanes.length;
                        active_lanes += null;
                    }
                    active_lanes[parent_lane] = parent_oid;
                }
                parent_lanes += parent_lane;
            }

            int[] outgoing_lanes = {};
            for (int lane = 0; lane < active_lanes.length; lane++) {
                if (active_lanes[lane] != null) outgoing_lanes += lane;
            }
            if (active_lanes.length > lane_count) lane_count = active_lanes.length;
            layouts += new HistoryLaneLayout(
                node_lane, incoming_lanes, outgoing_lanes, parent_lanes
            );
        }
        return new HistoryLaneGraph(lane_count, layouts);
    }

    private static int find_lane(string?[] lanes, string oid) {
        for (int lane = 0; lane < lanes.length; lane++) {
            if (lanes[lane] == oid) return lane;
        }
        return -1;
    }

    private static int first_free_lane(string?[] lanes) {
        for (int lane = 0; lane < lanes.length; lane++) {
            if (lanes[lane] == null) return lane;
        }
        return -1;
    }

    private static bool contains_oid(string[] oids, string candidate) {
        foreach (var oid in oids) {
            if (oid == candidate) return true;
        }
        return false;
    }
}

// Pixel maths and text for one lane gutter cell; the view only issues the Cairo calls.
public class HistoryLaneGeometry { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public const int LANE_SPACING = 20;

    public static int gutter_width(int lane_count) {
        return 16 + (lane_count * LANE_SPACING);
    }

    public static double lane_x(int lane, int width, int lane_count) {
        return ((width - ((lane_count - 1) * LANE_SPACING)) / 2.0) + (lane * 20.0);
    }

    public static double node_y(int height) {
        return double.min(18.0, height / 2.0);
    }

    public static double bend_y(double node_y, int height) {
        return double.min(node_y + 9.0, height - 4.0);
    }

    public static bool contains_lane(int[] lanes, int candidate) {
        foreach (var lane in lanes) {
            if (lane == candidate) return true;
        }
        return false;
    }

    public static bool draws_merge_marker(bool is_merge, HistoryLaneLayout layout) {
        return is_merge || layout.parent_lanes.length > 1;
    }

    public static string tooltip(HistoryLaneLayout layout, int lane_count) {
        var parent_description = layout.parent_lanes.length == 0
            ? "no direct visible parents"
            : "%d direct visible parent%s".printf(
                layout.parent_lanes.length, layout.parent_lanes.length == 1 ? "" : "s"
            );
        return "History graph: lane %d of %d; %s".printf(
            layout.node_lane + 1, lane_count, parent_description
        );
    }
}

}
