namespace HolderLinux {

public class ConnectionsArrowHead : Object {
    public double tip_x { get; construct; }
    public double tip_y { get; construct; }
    public double first_x { get; construct; }
    public double first_y { get; construct; }
    public double second_x { get; construct; }
    public double second_y { get; construct; }

    public ConnectionsArrowHead(double tip_x, double tip_y,
                                double first_x, double first_y,
                                double second_x, double second_y) {
        Object(tip_x: tip_x, tip_y: tip_y, first_x: first_x, first_y: first_y,
               second_x: second_x, second_y: second_y);
    }
}

public class ConnectionsBoardGeometry { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public const double ARROW_LENGTH = 8.0;
    public const double ARROW_HALF_WIDTH = 3.5;
    private const double EPSILON = 0.001;

    // Point on the border of `source` (midpoint of the side facing `target`).
    public static void point_on_node_edge(int source_x, int source_y,
                                          int target_x, int target_y,
                                          int node_width, int node_height,
                                          out double out_x, out double out_y) {
        double cx = source_x + node_width / 2.0;
        double cy = source_y + node_height / 2.0;
        double dx = (target_x + node_width / 2.0) - cx;
        double dy = (target_y + node_height / 2.0) - cy;
        if (Math.fabs(dx) < EPSILON && Math.fabs(dy) < EPSILON) {
            out_x = cx;
            out_y = cy;
            return;
        }
        if (Math.fabs(dx) >= Math.fabs(dy)) {
            out_x = dx >= 0 ? (source_x + node_width) : source_x;
            out_y = cy;
            return;
        }
        out_x = cx;
        out_y = dy >= 0 ? (source_y + node_height) : source_y;
    }

    // Null when the line has no length.
    public static ConnectionsArrowHead? arrow_head(double x0, double y0, double x1, double y1) {
        double dx = x1 - x0;
        double dy = y1 - y0;
        if (Math.fabs(dx) < EPSILON && Math.fabs(dy) < EPSILON) {
            return null;
        }
        if (Math.fabs(dx) >= Math.fabs(dy)) {
            double dir = dx >= 0 ? 1.0 : -1.0;
            return new ConnectionsArrowHead(
                x1, y1,
                x1 - (ARROW_LENGTH * dir), y1 - ARROW_HALF_WIDTH,
                x1 - (ARROW_LENGTH * dir), y1 + ARROW_HALF_WIDTH
            );
        }
        double dir = dy >= 0 ? 1.0 : -1.0;
        return new ConnectionsArrowHead(
            x1, y1,
            x1 - ARROW_HALF_WIDTH, y1 - (ARROW_LENGTH * dir),
            x1 + ARROW_HALF_WIDTH, y1 - (ARROW_LENGTH * dir)
        );
    }
}

}
