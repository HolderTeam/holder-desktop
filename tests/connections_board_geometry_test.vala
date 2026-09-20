using GLib;

namespace HolderLinuxTests {

private const int W = 220;
private const int H = 76;

private void test_edge_point_faces_target_horizontally() {
    double x;
    double y;
    HolderLinux.ConnectionsBoardGeometry.point_on_node_edge(0, 0, 400, 0, W, H, out x, out y);
    assert(x == W);
    assert(y == H / 2.0);

    HolderLinux.ConnectionsBoardGeometry.point_on_node_edge(400, 0, 0, 0, W, H, out x, out y);
    assert(x == 400);
    assert(y == H / 2.0);
}

private void test_edge_point_faces_target_vertically() {
    double x;
    double y;
    HolderLinux.ConnectionsBoardGeometry.point_on_node_edge(0, 0, 0, 300, W, H, out x, out y);
    assert(x == W / 2.0);
    assert(y == H);

    HolderLinux.ConnectionsBoardGeometry.point_on_node_edge(0, 300, 0, 0, W, H, out x, out y);
    assert(x == W / 2.0);
    assert(y == 300);
}

private void test_edge_point_prefers_horizontal_when_offsets_tie_and_centres_when_identical() {
    double x;
    double y;
    HolderLinux.ConnectionsBoardGeometry.point_on_node_edge(0, 0, 100, 100, W, H, out x, out y);
    assert(x == W);
    assert(y == H / 2.0);

    HolderLinux.ConnectionsBoardGeometry.point_on_node_edge(50, 60, 50, 60, W, H, out x, out y);
    assert(x == 50 + W / 2.0);
    assert(y == 60 + H / 2.0);
}

private void test_arrow_head_is_null_for_zero_length() {
    assert(HolderLinux.ConnectionsBoardGeometry.arrow_head(5, 5, 5, 5) == null);
    assert(HolderLinux.ConnectionsBoardGeometry.arrow_head(5, 5, 5.0005, 5.0005) == null);
}

private void test_arrow_head_horizontal() {
    var right = HolderLinux.ConnectionsBoardGeometry.arrow_head(0, 0, 100, 10);
    assert(right != null);
    assert(right.tip_x == 100 && right.tip_y == 10);
    assert(right.first_x == 92 && right.first_y == 6.5);
    assert(right.second_x == 92 && right.second_y == 13.5);

    var left = HolderLinux.ConnectionsBoardGeometry.arrow_head(100, 0, 0, 10);
    assert(left.first_x == 8 && left.second_x == 8);
}

private void test_arrow_head_vertical() {
    var down = HolderLinux.ConnectionsBoardGeometry.arrow_head(0, 0, 10, 100);
    assert(down.tip_x == 10 && down.tip_y == 100);
    assert(down.first_x == 6.5 && down.first_y == 92);
    assert(down.second_x == 13.5 && down.second_y == 92);

    var up = HolderLinux.ConnectionsBoardGeometry.arrow_head(0, 100, 10, 0);
    assert(up.first_y == 8 && up.second_y == 8);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/connections-board-geometry/edge-horizontal", test_edge_point_faces_target_horizontally);
    Test.add_func("/connections-board-geometry/edge-vertical", test_edge_point_faces_target_vertically);
    Test.add_func("/connections-board-geometry/edge-tie-and-identical", test_edge_point_prefers_horizontal_when_offsets_tie_and_centres_when_identical);
    Test.add_func("/connections-board-geometry/arrow-null", test_arrow_head_is_null_for_zero_length);
    Test.add_func("/connections-board-geometry/arrow-horizontal", test_arrow_head_horizontal);
    Test.add_func("/connections-board-geometry/arrow-vertical", test_arrow_head_vertical);
    return Test.run();
}

}
