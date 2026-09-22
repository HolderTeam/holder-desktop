namespace HolderLinux {

public class InlineImageDecorationPlan { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public const int FALLBACK_WIDTH = 560;
    public const int MIN_VIEW_WIDTH = 160;
    public const int SIDE_MARGIN_TOTAL = 80;

    // True when an existing decoration can keep its widget for the new item.
    public static bool same_content(InlineResourceImageItem existing, InlineResourceImageItem incoming) {
        return existing.resource.resource_id == incoming.resource.resource_id
            && existing.resource.label == incoming.resource.label
            && existing.asset.asset_id == incoming.asset.asset_id
            && existing.reference.alt_text == incoming.reference.alt_text;
    }

    public static bool anchor_at_expected_offset(long chars_before_anchor, InlineResourceImageItem item) {
        return chars_before_anchor == item.reference.char_offset;
    }

    public static int decoration_width(int view_width) {
        return view_width > MIN_VIEW_WIDTH ? view_width - SIDE_MARGIN_TOTAL : FALLBACK_WIDTH;
    }
}

}
