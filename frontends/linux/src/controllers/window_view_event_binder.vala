namespace HolderLinux {

internal interface ISidebarEventSink : Object {
    public abstract void on_sidebar_card_move_to_trash_requested(string card_id);
    public abstract void on_sidebar_card_context_selection_requested(string card_id);
    public abstract void on_sidebar_card_create_child_requested(string card_id);
}

internal class WindowSidebarEventBinder : Object {
    private SidebarPane sidebar; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private ISidebarEventSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public WindowSidebarEventBinder(SidebarPane sidebar, ISidebarEventSink sink) {
        this.sidebar = sidebar;
        this.sink = sink;
    }

    public void bind() {
        sidebar.card_move_to_trash_requested.connect((card_id) => {
            sink.on_sidebar_card_move_to_trash_requested(card_id);
        });
        sidebar.card_context_selection_requested.connect((card_id) => {
            sink.on_sidebar_card_context_selection_requested(card_id);
        });
        sidebar.card_create_child_requested.connect((card_id) => {
            sink.on_sidebar_card_create_child_requested(card_id);
        });
    }
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
    private WorkspacePane workspace; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IWorkspaceEventSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public WindowWorkspaceEventBinder(WorkspacePane workspace, IWorkspaceEventSink sink) {
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
