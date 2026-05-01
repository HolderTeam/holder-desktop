namespace HolderLinux {

internal class WindowStartupGeometry : Object {
    public int width { get; construct; }
    public int height { get; construct; }
    public bool start_maximized { get; construct; }

    public WindowStartupGeometry(int width, int height, bool start_maximized) {
        Object(
            width: width,
            height: height,
            start_maximized: start_maximized
        );
    }
}

internal class WindowGeometry : Object {
    public const int DEFAULT_WINDOW_WIDTH = 1200;
    public const int DEFAULT_WINDOW_HEIGHT = 800;
    public const int DEFAULT_SIDEBAR_WIDTH = 280;
    public const int MIN_SIDEBAR_WIDTH = 180;
    public const int MAX_SIDEBAR_WIDTH = 700;
    public const int MIN_RESTORE_WIDTH = 690;
    public const int MIN_RESTORE_HEIGHT = 590;
    public const int TINY_CLOSE_STRIKE_LIMIT = 3;

    public static WindowStartupGeometry resolve_startup_geometry(
        int startup_width,
        int startup_height,
        bool has_saved_geometry,
        int saved_width = DEFAULT_WINDOW_WIDTH,
        int saved_height = DEFAULT_WINDOW_HEIGHT,
        bool saved_maximized = false,
        int tiny_close_streak = 0
    ) {
        if (startup_width > 0 || startup_height > 0) {
            return new WindowStartupGeometry(
                startup_width > 0 ? startup_width : DEFAULT_WINDOW_WIDTH,
                startup_height > 0 ? startup_height : DEFAULT_WINDOW_HEIGHT,
                false
            );
        }

        if (!has_saved_geometry) {
            return new WindowStartupGeometry(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT, false);
        }

        var width = DEFAULT_WINDOW_WIDTH;
        var height = DEFAULT_WINDOW_HEIGHT;
        if (!is_tiny_size(saved_width, saved_height) ||
            tiny_close_streak >= TINY_CLOSE_STRIKE_LIMIT) {
            width = saved_width;
            height = saved_height;
        }

        return new WindowStartupGeometry(width, height, saved_maximized);
    }

    public static bool is_tiny_size(int width, int height) {
        return width < MIN_RESTORE_WIDTH || height < MIN_RESTORE_HEIGHT;
    }

    public static int clamp_sidebar_width(int width) {
        if (width < MIN_SIDEBAR_WIDTH) {
            return MIN_SIDEBAR_WIDTH;
        }
        if (width > MAX_SIDEBAR_WIDTH) {
            return MAX_SIDEBAR_WIDTH;
        }
        return width;
    }

    public static int next_tiny_close_streak(bool maximized,
                                             int width,
                                             int height,
                                             int current_streak) {
        if (maximized || !is_tiny_size(width, height)) {
            return 0;
        }
        return current_streak + 1;
    }
}

}
