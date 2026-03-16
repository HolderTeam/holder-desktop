namespace HolderLinux {

internal class ToolboxBreadcrumbController : Object {
    public delegate void OpenCardFunc(string card_id);
    public delegate void ShowToolHelpFunc(string tool_id);

    private SelectionIntentOrchestrator selection_intent_orchestrator;
    private ToolboxPane toolbox;

    public ToolboxBreadcrumbController(SelectionIntentOrchestrator selection_intent_orchestrator,
                                       ToolboxPane toolbox) {
        this.selection_intent_orchestrator = selection_intent_orchestrator;
        this.toolbox = toolbox;
    }

    public async void navigate(string tool_id,
                               int segment_index,
                               string? project_id,
                               string? card_id,
                               OpenCardFunc open_card,
                               ShowToolHelpFunc show_tool_help) {
        if (segment_index == 2) {
            if (card_id == null || card_id.strip().length == 0) {
                return;
            }
            if (tool_id == "flowboard" || tool_id == "connections") {
                open_card(card_id);
            }
            return;
        }

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
            yield selection_intent_orchestrator.on_project_selection_requested(project_id);
            if (tool_id == "flowboard") {
                toolbox.show_flowboard_project_root();
            }
        }
    }
}

}
