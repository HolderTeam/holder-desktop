namespace HolderLinux {

// Builds the toolbox header breadcrumb trail and the small selection checks around it, so the
// toolbox view only reads GTK state and applies the result.
internal class ToolboxHeaderBreadcrumbs { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public const string DEFAULT_TOOL_ID = "tool";
    public const string DEFAULT_TOOL_LABEL = "Tool";

    public static string tool_id_for_page(string? page_name) {
        if (page_name == null || page_name.strip().length == 0) {
            return DEFAULT_TOOL_ID;
        }
        return (!) page_name;
    }

    public static Gee.ArrayList<NavigationBreadcrumbSegment> from_snapshot(ToolScopeSnapshot snapshot) {
        var segments = new Gee.ArrayList<NavigationBreadcrumbSegment>();
        segments.add(new NavigationBreadcrumbSegment(snapshot.tool_label, true, true, 0));
        segments.add(new NavigationBreadcrumbSegment(
            snapshot.project_label,
            false,
            snapshot.project_id != null,
            1
        ));
        segments.add(new NavigationBreadcrumbSegment(
            snapshot.card_label,
            false,
            snapshot.card_id != null,
            2
        ));
        return segments;
    }

    // Used when the visible tool has no scope adapter: derive the trail from the selection.
    public static Gee.ArrayList<NavigationBreadcrumbSegment> from_selection(
        string? page_title,
        Project? selected_project,
        CardSummary? selected_card
    ) {
        string tool_name = page_title != null && page_title.strip().length > 0
            ? (!) page_title
            : DEFAULT_TOOL_LABEL;
        string project_name = selected_project != null && selected_project.name.strip().length > 0
            ? selected_project.name
            : "(none)";
        string card_name = selected_card != null &&
            (selected_project == null || selected_card.project_id == selected_project.project_id) &&
            selected_card.title.strip().length > 0
            ? selected_card.title
            : "Overview";

        var segments = new Gee.ArrayList<NavigationBreadcrumbSegment>();
        segments.add(new NavigationBreadcrumbSegment(tool_name, true, true, 0));
        segments.add(new NavigationBreadcrumbSegment(project_name, false, selected_project != null, 1));
        segments.add(new NavigationBreadcrumbSegment(card_name, false, selected_card != null, 2));
        return segments;
    }

    public static bool selection_matches(Project? selected_project,
                                         CardSummary? selected_card,
                                         string project_id,
                                         string card_id) {
        return selected_project != null
            && selected_card != null
            && selected_project.project_id == project_id
            && selected_card.card_id == card_id;
    }
}

}
