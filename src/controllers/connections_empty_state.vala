namespace HolderLinux {

public enum ConnectionsProjectRenderPlan {
    RENDER_BOARD,
    SHOW_EMPTY_NOW,
    SCHEDULE_EMPTY_CHECK
}

public class ConnectionsEmptyStatePolicy { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public static bool project_has_known_cards(Project project) {
        return project.root_card_count > 0;
    }

    // An empty local card snapshot is only trusted immediately when the project also claims
    // to have no cards and nothing has been drawn yet; otherwise it is probably transitional.
    public static ConnectionsProjectRenderPlan plan_for_project_cards(Project project,
                                                                      int project_card_count,
                                                                      bool has_committed_board) {
        if (project_card_count > 0) {
            return ConnectionsProjectRenderPlan.RENDER_BOARD;
        }
        if (project_has_known_cards(project)) {
            return ConnectionsProjectRenderPlan.SCHEDULE_EMPTY_CHECK;
        }
        if (!has_committed_board) {
            return ConnectionsProjectRenderPlan.SHOW_EMPTY_NOW;
        }
        return ConnectionsProjectRenderPlan.SCHEDULE_EMPTY_CHECK;
    }

    public static bool should_show_no_cards(bool show_projects_root,
                                            Project? selected_project,
                                            string project_id,
                                            CardSummary? selected_card,
                                            Gee.List<CardSummary> cards) {
        if (show_projects_root) {
            return false;
        }
        if (selected_project == null || selected_project.project_id != project_id) {
            return false;
        }
        if (project_has_known_cards(selected_project)) {
            return false;
        }
        if (selected_card != null) {
            return false;
        }
        foreach (var card in cards) {
            if (card.project_id == project_id) {
                return false;
            }
        }
        return true;
    }
}

}
