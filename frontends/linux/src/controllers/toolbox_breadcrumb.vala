namespace HolderLinux {

internal class ToolboxBreadcrumbController : Object {
    public delegate void OpenCardFunc(string card_id);
    public delegate void ShowToolHelpFunc(string tool_id);

    private SelectionTransitionController selection_transitions;
    private SelectionController selection_controller;
    private ToolboxPane toolbox;

    public ToolboxBreadcrumbController(SelectionTransitionController selection_transitions,
                                       SelectionController selection_controller,
                                       ToolboxPane toolbox) {
        this.selection_transitions = selection_transitions;
        this.selection_controller = selection_controller;
        this.toolbox = toolbox;
    }

    public async void navigate(string tool_id,
                               int segment_index,
                               string? project_id,
                               string? card_id,
                               OpenCardFunc open_card,
                               ShowToolHelpFunc show_tool_help) {
        var seq = selection_transitions.begin_navigation(
            "toolbox-breadcrumb",
            project_id,
            card_id
        );
        try {
            if (segment_index == 0) {
                if (tool_id == "flowboard") {
                    toolbox.show_flowboard_projects_root();
                } else {
                    show_tool_help(tool_id);
                }
                return;
            }

            if (segment_index == 1) {
                if (project_id == null || project_id.strip().length == 0) {
                    return;
                }
                if (tool_id == "flowboard") {
                    yield selection_transitions.run_project_selection_without_flowboard(
                        project_id,
                        selection_controller
                    );
                    toolbox.show_flowboard_project_root();
                    return;
                }
                yield selection_transitions.run_project_selection_without_flowboard(
                    project_id,
                    selection_controller
                );
                return;
            }

            if (segment_index == 2) {
                if (card_id == null || card_id.strip().length == 0) {
                    return;
                }
                if (tool_id == "flowboard" || tool_id == "connections") {
                    open_card(card_id);
                }
                return;
            }
        } finally {
            selection_transitions.finish_navigation_if_current(seq);
        }
    }
}

}
