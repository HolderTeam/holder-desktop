namespace HolderLinux {

internal enum FlowboardDropHint {
    BEFORE,
    INTO,
    AFTER
}

internal class FlowboardTilePresentation : Object {
    public string title { get; construct; }
    public string meta_text { get; construct; }
    public bool folder_tab_visible { get; construct; }
    public int header_margin_top { get; construct; }
    public bool branch_css { get; construct; }
    public string card_id { get; construct; }
    public string parent_card_id { get; construct; }
    public int sibling_count { get; construct; }
    public int sibling_index { get; construct; }

    public FlowboardTilePresentation(string title,
                                     string meta_text,
                                     bool folder_tab_visible,
                                     int header_margin_top,
                                     bool branch_css,
                                     string card_id,
                                     string parent_card_id,
                                     int sibling_count,
                                     int sibling_index) {
        Object(
            title: title,
            meta_text: meta_text,
            folder_tab_visible: folder_tab_visible,
            header_margin_top: header_margin_top,
            branch_css: branch_css,
            card_id: card_id,
            parent_card_id: parent_card_id,
            sibling_count: sibling_count,
            sibling_index: sibling_index
        );
    }
}

internal class FlowboardPresenter : Object {
    public static FlowboardTilePresentation tile(FlowboardTile? tile, int64 now) {
        if (tile == null) {
            return new FlowboardTilePresentation("", "", false, 0, false, "", "", 0, 0);
        }

        if (tile.is_container) {
            return new FlowboardTilePresentation(
                tile.title,
                "%d %s | %s".printf(
                    tile.child_count,
                    tile.child_count == 1 ? "item" : "items",
                    TextUtils.format_relative_time(now, tile.updated_at)
                ),
                true,
                0,
                true,
                tile.card_id ?? "",
                tile.parent_card_id ?? "",
                tile.sibling_count,
                tile.sibling_index
            );
        }

        return new FlowboardTilePresentation(
            tile.title,
            TextUtils.format_relative_time(now, tile.updated_at),
            false,
            15,
            false,
            tile.card_id ?? "",
            tile.parent_card_id ?? "",
            tile.sibling_count,
            tile.sibling_index
        );
    }

    public static double drop_fraction(double x, int width) {
        double fraction = 0.5;
        if (width > 0) {
            fraction = x / (double) width;
        }
        if (fraction < 0.0) {
            return 0.0;
        }
        if (fraction > 1.0) {
            return 1.0;
        }
        return fraction;
    }

    public static FlowboardDropHint drop_hint(double x, int width) {
        var fraction = drop_fraction(x, width);
        if (fraction < 0.25) {
            return FlowboardDropHint.BEFORE;
        }
        if (fraction > 0.75) {
            return FlowboardDropHint.AFTER;
        }
        return FlowboardDropHint.INTO;
    }

    public static bool move_up_sensitive(string? parent_card_id) {
        return parent_card_id != null && parent_card_id.strip().length > 0;
    }

    public static bool move_left_sensitive(int sibling_count, int sibling_index) {
        return sibling_count > 1 && sibling_index > 0;
    }

    public static bool move_right_sensitive(int sibling_count, int sibling_index) {
        return sibling_count > 1 && sibling_index < sibling_count - 1;
    }

    public static bool move_to_boundary_sensitive(int sibling_count) {
        return sibling_count > 1;
    }
}

}
