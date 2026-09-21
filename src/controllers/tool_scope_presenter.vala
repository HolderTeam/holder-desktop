namespace HolderLinux {

public class ToolScopePresenter {
    public static ToolScopeSnapshot snapshot(string tool_id,
                                             string tool_label,
                                             Project? selected_project,
                                             CardSummary? selected_card,
                                             bool is_loading = false) {
        var project_id = selected_project != null ? selected_project.project_id : null;
        var project_label = selected_project != null ? selected_project.name : "(none)";
        var card_id = selected_card != null ? selected_card.card_id : null;
        var card_label = selected_card != null ? selected_card.title : "Overview";

        ToolScopeMode scope_mode = selected_card != null
            ? ToolScopeMode.CARD_FOCUS
            : ToolScopeMode.PROJECT_ROOT;
        if (project_id == null) {
            scope_mode = ToolScopeMode.PROJECTS_ROOT;
            project_label = "Projects";
            card_id = null;
            card_label = "Overview";
        }

        return new ToolScopeSnapshot(
            tool_id,
            tool_label,
            project_id,
            project_label,
            card_id,
            card_label,
            scope_mode,
            is_loading
        );
    }

    // For tools that can also show the all-projects overview, independent of the selection.
    public static ToolScopeSnapshot snapshot_with_projects_root(string tool_id,
                                                                string tool_label,
                                                                bool show_projects_root,
                                                                Project? selected_project,
                                                                CardSummary? selected_card) {
        var project_id = selected_project != null ? selected_project.project_id : null;
        var project_label = selected_project != null ? selected_project.name : "(none)";
        var card_id = selected_card != null ? selected_card.card_id : null;
        var card_label = selected_card != null ? selected_card.title : "Overview";

        ToolScopeMode scope_mode = ToolScopeMode.CARD_FOCUS;
        if (show_projects_root) {
            scope_mode = ToolScopeMode.PROJECTS_ROOT;
            project_id = null;
            project_label = "Projects";
            card_id = null;
            card_label = "Overview";
        } else if (selected_card == null) {
            scope_mode = ToolScopeMode.PROJECT_ROOT;
            card_id = null;
            card_label = "Overview";
        }

        return new ToolScopeSnapshot(
            tool_id,
            tool_label,
            project_id,
            project_label,
            card_id,
            card_label,
            scope_mode,
            false
        );
    }
}

}
