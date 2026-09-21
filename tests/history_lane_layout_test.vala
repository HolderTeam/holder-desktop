using GLib;

namespace HolderLinuxTests {

// ---- Reference implementations ----
// Verbatim copies (adapted only to take HistoryLaneNode[]) of the two lane-assignment
// algorithms that used to live, duplicated, in history_tool_view.vala. They pin down the
// behaviour the single HistoryLaneAssigner must preserve.

private int ref_find_lane(string?[] lanes, string oid) {
    for (int lane = 0; lane < lanes.length; lane++) {
        if (lanes[lane] == oid) return lane;
    }
    return -1;
}

private int ref_first_free_lane(string?[] lanes) {
    for (int lane = 0; lane < lanes.length; lane++) {
        if (lanes[lane] == null) return lane;
    }
    return -1;
}

private bool ref_contains_oid(string[] oids, string candidate) {
    foreach (var oid in oids) {
        if (oid == candidate) return true;
    }
    return false;
}

private HolderLinux.HistoryLaneGraph reference_card_lanes(HolderLinux.HistoryLaneNode[] nodes) {
    HolderLinux.HistoryLaneLayout[] layouts = {};
    string?[] active_lanes = {};
    int lane_count = 1;
    foreach (var row in nodes) {
        int[] incoming_lanes = {};
        for (int lane = 0; lane < active_lanes.length; lane++) {
            if (active_lanes[lane] != null) incoming_lanes += lane;
        }

        int node_lane = ref_find_lane(active_lanes, row.oid);
        if (node_lane < 0) {
            node_lane = ref_first_free_lane(active_lanes);
            if (node_lane < 0) {
                node_lane = active_lanes.length;
                active_lanes += null;
            }
        }
        active_lanes[node_lane] = null;

        int[] parent_lanes = {};
        foreach (var parent_oid in row.parent_oids) {
            int parent_lane = ref_find_lane(active_lanes, parent_oid);
            if (parent_lane < 0) {
                parent_lane = parent_lanes.length == 0
                    ? node_lane
                    : ref_first_free_lane(active_lanes);
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
        layouts += new HolderLinux.HistoryLaneLayout(
            node_lane, incoming_lanes, outgoing_lanes, parent_lanes
        );
    }
    return new HolderLinux.HistoryLaneGraph(lane_count, layouts);
}

private HolderLinux.HistoryLaneGraph reference_project_lanes(HolderLinux.HistoryLaneNode[] nodes) {
    string[] visible_oids = {};
    foreach (var row in nodes) {
        visible_oids += row.oid;
    }

    HolderLinux.HistoryLaneLayout[] layouts = {};
    string?[] active_lanes = {};
    int lane_count = 1;
    foreach (var row in nodes) {
        int[] incoming_lanes = {};
        for (int lane = 0; lane < active_lanes.length; lane++) {
            if (active_lanes[lane] != null) incoming_lanes += lane;
        }

        int node_lane = ref_find_lane(active_lanes, row.oid);
        if (node_lane < 0) {
            node_lane = ref_first_free_lane(active_lanes);
            if (node_lane < 0) {
                node_lane = active_lanes.length;
                active_lanes += null;
            }
        }
        active_lanes[node_lane] = null;

        int[] parent_lanes = {};
        foreach (var parent_oid in row.parent_oids) {
            if (!ref_contains_oid(visible_oids, parent_oid)) continue;
            int parent_lane = ref_find_lane(active_lanes, parent_oid);
            if (parent_lane < 0) {
                parent_lane = parent_lanes.length == 0
                    ? node_lane
                    : ref_first_free_lane(active_lanes);
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
        layouts += new HolderLinux.HistoryLaneLayout(
            node_lane, incoming_lanes, outgoing_lanes, parent_lanes
        );
    }
    return new HolderLinux.HistoryLaneGraph(lane_count, layouts);
}

// ---- Helpers ----

private HolderLinux.HistoryLaneNode node(string oid, string[] parents) {
    return new HolderLinux.HistoryLaneNode(oid, parents);
}

private bool lanes_equal(int[] a, int[] b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
    }
    return true;
}

private void assert_graphs_equal(HolderLinux.HistoryLaneGraph expected,
                                 HolderLinux.HistoryLaneGraph actual) {
    assert(expected.lane_count == actual.lane_count);
    assert(expected.layouts.length == actual.layouts.length);
    for (int i = 0; i < expected.layouts.length; i++) {
        assert(expected.layouts[i].node_lane == actual.layouts[i].node_lane);
        assert(lanes_equal(expected.layouts[i].incoming_lanes, actual.layouts[i].incoming_lanes));
        assert(lanes_equal(expected.layouts[i].outgoing_lanes, actual.layouts[i].outgoing_lanes));
        assert(lanes_equal(expected.layouts[i].parent_lanes, actual.layouts[i].parent_lanes));
    }
}

private void assert_matches_reference(HolderLinux.HistoryLaneNode[] nodes) {
    assert_graphs_equal(
        reference_card_lanes(nodes),
        HolderLinux.HistoryLaneAssigner.compute(nodes, HolderLinux.HistoryLaneParentRule.AS_GIVEN)
    );
    assert_graphs_equal(
        reference_project_lanes(nodes),
        HolderLinux.HistoryLaneAssigner.compute(nodes, HolderLinux.HistoryLaneParentRule.LISTED_ONLY)
    );
}

// ---- Assigner ----

private void test_empty_history_has_one_lane_and_no_layouts() {
    HolderLinux.HistoryLaneNode[] nodes = {};
    var graph = HolderLinux.HistoryLaneAssigner.compute(nodes, HolderLinux.HistoryLaneParentRule.AS_GIVEN);
    assert(graph.lane_count == 1);
    assert(graph.layouts.length == 0);
    assert_matches_reference(nodes);
}

private void test_linear_history_stays_in_lane_zero() {
    HolderLinux.HistoryLaneNode[] nodes = {
        node("c", { "b" }), node("b", { "a" }), node("a", {})
    };
    var graph = HolderLinux.HistoryLaneAssigner.compute(nodes, HolderLinux.HistoryLaneParentRule.AS_GIVEN);
    assert(graph.lane_count == 1);
    assert(graph.layouts.length == 3);
    foreach (var layout in graph.layouts) assert(layout.node_lane == 0);
    assert(graph.layouts[0].incoming_lanes.length == 0);
    assert(lanes_equal(graph.layouts[0].parent_lanes, { 0 }));
    assert(lanes_equal(graph.layouts[0].outgoing_lanes, { 0 }));
    assert(lanes_equal(graph.layouts[1].incoming_lanes, { 0 }));
    assert(graph.layouts[2].parent_lanes.length == 0);
    assert(graph.layouts[2].outgoing_lanes.length == 0);
    assert_matches_reference(nodes);
}

private void test_branch_and_merge_opens_a_second_lane() {
    HolderLinux.HistoryLaneNode[] nodes = {
        node("merge", { "main", "side" }),
        node("main", { "base" }),
        node("side", { "base" }),
        node("base", {})
    };
    var graph = HolderLinux.HistoryLaneAssigner.compute(nodes, HolderLinux.HistoryLaneParentRule.AS_GIVEN);
    assert(graph.lane_count == 2);
    assert(lanes_equal(graph.layouts[0].parent_lanes, { 0, 1 }));
    assert(graph.layouts[1].node_lane == 0);
    assert(graph.layouts[2].node_lane == 1);
    assert(graph.layouts[3].node_lane == 0);
    assert_matches_reference(nodes);
}

private void test_octopus_merge_uses_one_lane_per_parent() {
    HolderLinux.HistoryLaneNode[] nodes = {
        node("octopus", { "p1", "p2", "p3" }),
        node("p1", {}),
        node("p2", {}),
        node("p3", {})
    };
    var graph = HolderLinux.HistoryLaneAssigner.compute(nodes, HolderLinux.HistoryLaneParentRule.AS_GIVEN);
    assert(graph.lane_count == 3);
    assert(lanes_equal(graph.layouts[0].parent_lanes, { 0, 1, 2 }));
    assert(lanes_equal(graph.layouts[0].outgoing_lanes, { 0, 1, 2 }));
    assert(graph.layouts[1].node_lane == 0);
    assert(graph.layouts[2].node_lane == 1);
    assert(graph.layouts[3].node_lane == 2);
    assert_matches_reference(nodes);
}

private void test_parent_rules_differ_only_for_unlisted_parents() {
    HolderLinux.HistoryLaneNode[] nodes = {
        node("newest", { "older", "not-on-this-page" }),
        node("older", {})
    };
    var as_given = HolderLinux.HistoryLaneAssigner.compute(
        nodes, HolderLinux.HistoryLaneParentRule.AS_GIVEN
    );
    var listed_only = HolderLinux.HistoryLaneAssigner.compute(
        nodes, HolderLinux.HistoryLaneParentRule.LISTED_ONLY
    );
    // AS_GIVEN keeps the parent that is not on the page and leaves its lane running down.
    assert(lanes_equal(as_given.layouts[0].parent_lanes, { 0, 1 }));
    assert(as_given.lane_count == 2);
    // LISTED_ONLY ignores it.
    assert(lanes_equal(listed_only.layouts[0].parent_lanes, { 0 }));
    assert(listed_only.lane_count == 1);
    assert_matches_reference(nodes);
}

private void test_lane_is_reused_once_freed() {
    HolderLinux.HistoryLaneNode[] nodes = {
        node("m", { "a", "b" }),
        node("a", {}),
        node("b", {}),
        node("solo", {})
    };
    var graph = HolderLinux.HistoryLaneAssigner.compute(nodes, HolderLinux.HistoryLaneParentRule.AS_GIVEN);
    assert(graph.layouts[3].node_lane == 0);
    assert(graph.lane_count == 2);
    assert_matches_reference(nodes);
}

private void test_random_graphs_match_the_original_algorithms() {
    var rand = new Rand.with_seed(20260920);
    for (int round = 0; round < 300; round++) {
        int count = rand.int_range(1, 40);
        HolderLinux.HistoryLaneNode[] nodes = {};
        for (int i = 0; i < count; i++) {
            string[] parents = {};
            int wanted = rand.int_range(0, 4);
            for (int k = 0; k < wanted; k++) {
                string candidate;
                if (rand.int_range(0, 6) == 0) {
                    candidate = "external-%d".printf(rand.int_range(0, 5));
                } else if (i + 1 < count) {
                    candidate = "n%d".printf(rand.int_range(i + 1, count));
                } else {
                    continue;
                }
                bool seen = false;
                foreach (var existing in parents) {
                    if (existing == candidate) seen = true;
                }
                if (!seen) parents += candidate;
            }
            nodes += node("n%d".printf(i), parents);
        }
        assert_matches_reference(nodes);
    }
}

// ---- Geometry ----

private void test_gutter_width_grows_with_lanes() {
    assert(HolderLinux.HistoryLaneGeometry.gutter_width(1) == 36);
    assert(HolderLinux.HistoryLaneGeometry.gutter_width(3) == 76);
}

private void test_lane_x_centres_the_lanes_in_the_gutter() {
    assert(HolderLinux.HistoryLaneGeometry.lane_x(0, 36, 1) == 18.0);
    assert(HolderLinux.HistoryLaneGeometry.lane_x(0, 76, 3) == 18.0);
    assert(HolderLinux.HistoryLaneGeometry.lane_x(2, 76, 3) == 58.0);
}

private void test_node_and_bend_heights_are_clamped() {
    assert(HolderLinux.HistoryLaneGeometry.node_y(100) == 18.0);
    assert(HolderLinux.HistoryLaneGeometry.node_y(20) == 10.0);
    assert(HolderLinux.HistoryLaneGeometry.bend_y(18.0, 100) == 27.0);
    assert(HolderLinux.HistoryLaneGeometry.bend_y(18.0, 30) == 26.0);
}

private void test_contains_lane_and_merge_marker() {
    assert(HolderLinux.HistoryLaneGeometry.contains_lane({ 0, 2 }, 2));
    assert(!HolderLinux.HistoryLaneGeometry.contains_lane({ 0, 2 }, 1));
    assert(!HolderLinux.HistoryLaneGeometry.contains_lane({}, 0));

    var single = new HolderLinux.HistoryLaneLayout(0, {}, { 0 }, { 0 });
    var multiple = new HolderLinux.HistoryLaneLayout(0, {}, { 0, 1 }, { 0, 1 });
    assert(!HolderLinux.HistoryLaneGeometry.draws_merge_marker(false, single));
    assert(HolderLinux.HistoryLaneGeometry.draws_merge_marker(true, single));
    assert(HolderLinux.HistoryLaneGeometry.draws_merge_marker(false, multiple));
}

private void test_tooltip_describes_lane_and_visible_parents() {
    var none = new HolderLinux.HistoryLaneLayout(0, {}, {}, {});
    var one = new HolderLinux.HistoryLaneLayout(1, {}, { 1 }, { 1 });
    var two = new HolderLinux.HistoryLaneLayout(0, {}, { 0, 1 }, { 0, 1 });
    assert(HolderLinux.HistoryLaneGeometry.tooltip(none, 1)
           == "History graph: lane 1 of 1; no direct visible parents");
    assert(HolderLinux.HistoryLaneGeometry.tooltip(one, 2)
           == "History graph: lane 2 of 2; 1 direct visible parent");
    assert(HolderLinux.HistoryLaneGeometry.tooltip(two, 2)
           == "History graph: lane 1 of 2; 2 direct visible parents");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/history-lanes/empty", test_empty_history_has_one_lane_and_no_layouts);
    Test.add_func("/holder/history-lanes/linear", test_linear_history_stays_in_lane_zero);
    Test.add_func("/holder/history-lanes/branch-merge", test_branch_and_merge_opens_a_second_lane);
    Test.add_func("/holder/history-lanes/octopus", test_octopus_merge_uses_one_lane_per_parent);
    Test.add_func("/holder/history-lanes/parent-rules", test_parent_rules_differ_only_for_unlisted_parents);
    Test.add_func("/holder/history-lanes/lane-reuse", test_lane_is_reused_once_freed);
    Test.add_func("/holder/history-lanes/random-matches-original", test_random_graphs_match_the_original_algorithms);
    Test.add_func("/holder/history-lanes/gutter-width", test_gutter_width_grows_with_lanes);
    Test.add_func("/holder/history-lanes/lane-x", test_lane_x_centres_the_lanes_in_the_gutter);
    Test.add_func("/holder/history-lanes/heights", test_node_and_bend_heights_are_clamped);
    Test.add_func("/holder/history-lanes/contains-and-marker", test_contains_lane_and_merge_marker);
    Test.add_func("/holder/history-lanes/tooltip", test_tooltip_describes_lane_and_visible_parents);
    return Test.run();
}

}
