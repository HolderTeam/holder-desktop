namespace HolderLinux {

internal enum WorkspacePanel {
    AI_PANEL,
    ASSET_PREVIEW
}

// Remembers how wide a side panel was last dragged and turns it back into a paned position.
// The view owns the Gtk.Paned and the Idle-based suppress reset; this owns the decisions.
internal class PanelWidthTracker : Object {
    private WorkspacePanel panel;

    public int last_width { get; private set; default = -1; }
    public bool user_set { get; private set; default = false; }
    public bool suppress_persist { get; set; default = false; }

    public PanelWidthTracker(WorkspacePanel panel) {
        this.panel = panel;
    }

    public void set_width(int width) {
        if (width > 0) {
            last_width = clamp(width);
            user_set = true;
        } else {
            last_width = -1;
            user_set = false;
        }
    }

    public int width_for_persist() {
        if (!user_set || last_width <= 0) {
            return 0;
        }
        return clamp(last_width);
    }

    public void on_position_changed(bool panel_visible, int split_width, int position) {
        if (suppress_persist || !panel_visible) {
            return;
        }
        if (split_width <= 0) {
            return;
        }
        var panel_width = split_width - position;
        if (panel_width <= 0) {
            return;
        }
        last_width = clamp(panel_width);
        user_set = true;
    }

    public int initial_position(int split_width, int min_start, int max_start) {
        if (panel == WorkspacePanel.AI_PANEL) {
            return WorkspaceLayout.initial_ai_panel_position(
                split_width, last_width, user_set, min_start, max_start
            );
        }
        return WorkspaceLayout.initial_asset_preview_position(
            split_width, last_width, user_set, min_start, max_start
        );
    }

    private int clamp(int width) {
        return panel == WorkspacePanel.AI_PANEL
            ? WorkspaceLayout.clamp_ai_panel_width(width)
            : WorkspaceLayout.clamp_asset_preview_width(width);
    }
}

}
