namespace HolderLinux {

public class AssetZoomPresentation : Object {
    public double zoom { get; construct; }
    public int width { get; construct; }
    public int height { get; construct; }
    public string label { get; construct; }

    public AssetZoomPresentation(double zoom, int width, int height, string label) {
        Object(zoom: zoom, width: width, height: height, label: label);
    }
}

public class AssetNavigationState : Object {
    public bool previous_enabled { get; construct; }
    public bool next_enabled { get; construct; }

    public AssetNavigationState(bool previous_enabled, bool next_enabled) {
        Object(previous_enabled: previous_enabled, next_enabled: next_enabled);
    }
}

public class AssetPreviewPresenter {
    public const double MIN_ZOOM = 0.2;
    public const double MAX_ZOOM = 4.0;
    public const double ZOOM_STEP = 0.2;
    public const int MAX_PIXELS = 16384;
    public const string FIT_LABEL = "Fit";

    // Zoom of 0.0 means "fit to preview"; the first step from fit lands on 80% / 120%.
    public static double zoom_out_target(double current_zoom) {
        return current_zoom == 0.0 ? 0.8 : current_zoom - ZOOM_STEP;
    }

    public static double zoom_in_target(double current_zoom) {
        return current_zoom == 0.0 ? 1.2 : current_zoom + ZOOM_STEP;
    }

    public static AssetZoomPresentation zoom(double requested_zoom, int texture_width, int texture_height) {
        var applied = requested_zoom.clamp(MIN_ZOOM, MAX_ZOOM);
        return new AssetZoomPresentation(
            applied,
            ((int) (((double) texture_width) * applied)).clamp(1, MAX_PIXELS),
            ((int) (((double) texture_height) * applied)).clamp(1, MAX_PIXELS),
            "%d%%".printf((int) (applied * 100.0 + 0.5))
        );
    }

    public static AssetNavigationState navigation(int selected_index, int attachment_count) {
        return new AssetNavigationState(
            selected_index > 0,
            selected_index >= 0 && selected_index + 1 < attachment_count
        );
    }
}

}
