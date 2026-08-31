namespace HolderLinux {

internal class WorkspaceLayout : Object {
    private const double DEFAULT_TOOLBOX_FRACTION = 0.5;
    private const int MIN_AI_PANEL_WIDTH = 360;
    private const int MAX_AI_PANEL_WIDTH = 720;
    private const double DEFAULT_AI_PANEL_FRACTION = 0.38;
    private const int MIN_ASSET_PREVIEW_WIDTH = 300;
    private const int MAX_ASSET_PREVIEW_WIDTH = 900;
    private const double DEFAULT_ASSET_PREVIEW_FRACTION = 0.34;

    public static int clamp_ai_panel_width(int width) {
        if (width < MIN_AI_PANEL_WIDTH) {
            return MIN_AI_PANEL_WIDTH;
        }
        if (width > MAX_AI_PANEL_WIDTH) {
            return MAX_AI_PANEL_WIDTH;
        }
        return width;
    }

    public static int default_ai_panel_width(int split_width) {
        var width = (int) ((double) split_width * DEFAULT_AI_PANEL_FRACTION);
        return clamp_ai_panel_width(width);
    }

    public static int initial_ai_panel_position(int split_width,
                                                int last_ai_panel_width,
                                                bool ai_panel_width_user_set,
                                                int min_start,
                                                int max_start) {
        var desired_width = ai_panel_width_user_set && last_ai_panel_width > 0
            ? clamp_ai_panel_width(last_ai_panel_width)
            : default_ai_panel_width(split_width);
        return clamp_position(split_width - desired_width, min_start, max_start);
    }

    public static int clamp_asset_preview_width(int width) {
        if (width < MIN_ASSET_PREVIEW_WIDTH) return MIN_ASSET_PREVIEW_WIDTH;
        if (width > MAX_ASSET_PREVIEW_WIDTH) return MAX_ASSET_PREVIEW_WIDTH;
        return width;
    }

    public static int default_asset_preview_width(int split_width) {
        return clamp_asset_preview_width((int) ((double) split_width * DEFAULT_ASSET_PREVIEW_FRACTION));
    }

    public static int initial_asset_preview_position(int split_width,
                                                     int last_preview_width,
                                                     bool preview_width_user_set,
                                                     int min_start,
                                                     int max_start) {
        var desired_width = preview_width_user_set && last_preview_width > 0
            ? clamp_asset_preview_width(last_preview_width)
            : default_asset_preview_width(split_width);
        return clamp_position(split_width - desired_width, min_start, max_start);
    }

    public static int initial_toolbox_position(int paned_height, int min_top, int max_top) {
        var target_top = (int) ((double) paned_height * (1.0 - DEFAULT_TOOLBOX_FRACTION));
        return clamp_position(target_top, min_top, max_top);
    }

    private static int clamp_position(int position, int minimum, int maximum) {
        var max_position = maximum;
        if (max_position < minimum) {
            max_position = minimum;
        }
        if (position < minimum) {
            return minimum;
        }
        if (position > max_position) {
            return max_position;
        }
        return position;
    }
}

}
