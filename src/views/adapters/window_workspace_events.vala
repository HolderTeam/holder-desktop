namespace HolderLinux {

internal interface IWorkspaceEventSource : Object {
    public abstract signal void refresh_requested();
    public abstract signal void new_project_requested();
    public abstract signal void new_card_requested();
    public abstract signal void explorer_panel_toggled(bool visible);
    public abstract signal void ai_panel_toggled(bool visible);
    public abstract signal void toolbox_toggled(bool visible);
    public abstract signal void open_debug_panel_requested();
    public abstract signal void search_activated();
    public abstract signal void search_changed();
    public abstract signal void search_cleared();
    public abstract signal void search_focus_results_requested();
    public abstract signal void search_result_activated(uint position);
    public abstract signal void find_next_requested();
    public abstract signal void replace_requested();
    public abstract signal void replace_all_requested();
}

internal interface IWorkspaceEventSink : Object {
    public abstract void on_workspace_refresh_requested();
    public abstract void on_workspace_new_project_requested();
    public abstract void on_workspace_new_card_requested();
    public abstract void on_workspace_explorer_panel_toggled(bool visible);
    public abstract void on_workspace_ai_panel_toggled(bool visible);
    public abstract void on_workspace_toolbox_toggled(bool visible);
    public abstract void on_workspace_open_debug_panel_requested();
    public abstract void on_workspace_search_activated();
    public abstract void on_workspace_search_changed();
    public abstract void on_workspace_search_cleared();
    public abstract void on_workspace_search_focus_results_requested();
    public abstract void on_workspace_search_result_activated(uint position);
    public abstract void on_workspace_find_next_requested();
    public abstract void on_workspace_replace_requested();
    public abstract void on_workspace_replace_all_requested();
}

internal class WindowWorkspaceEventBinder : Object {
    private IWorkspaceEventSource workspace; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IWorkspaceEventSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public WindowWorkspaceEventBinder(IWorkspaceEventSource workspace, IWorkspaceEventSink sink) {
        this.workspace = workspace;
        this.sink = sink;
    }

    public void bind() {
        workspace.refresh_requested.connect(() => {
            sink.on_workspace_refresh_requested();
        });
        workspace.new_project_requested.connect(() => {
            sink.on_workspace_new_project_requested();
        });
        workspace.new_card_requested.connect(() => {
            sink.on_workspace_new_card_requested();
        });
        workspace.explorer_panel_toggled.connect((visible) => {
            sink.on_workspace_explorer_panel_toggled(visible);
        });
        workspace.ai_panel_toggled.connect((visible) => {
            sink.on_workspace_ai_panel_toggled(visible);
        });
        workspace.toolbox_toggled.connect((visible) => {
            sink.on_workspace_toolbox_toggled(visible);
        });
        workspace.open_debug_panel_requested.connect(() => {
            sink.on_workspace_open_debug_panel_requested();
        });
        workspace.search_activated.connect(() => {
            sink.on_workspace_search_activated();
        });
        workspace.search_changed.connect(() => {
            sink.on_workspace_search_changed();
        });
        workspace.search_cleared.connect(() => {
            sink.on_workspace_search_cleared();
        });
        workspace.search_focus_results_requested.connect(() => {
            sink.on_workspace_search_focus_results_requested();
        });
        workspace.search_result_activated.connect((position) => {
            sink.on_workspace_search_result_activated(position);
        });
        workspace.find_next_requested.connect(() => {
            sink.on_workspace_find_next_requested();
        });
        workspace.replace_requested.connect(() => {
            sink.on_workspace_replace_requested();
        });
        workspace.replace_all_requested.connect(() => {
            sink.on_workspace_replace_all_requested();
        });
    }
}

}
