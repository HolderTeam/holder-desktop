namespace HolderLinux {

internal class WindowMainControllerSignalSink : Object, IMainControllerSignalSink {
    private MainWindow owner;

    public WindowMainControllerSignalSink(MainWindow owner) {
        this.owner = owner;
    }

    public void on_status_changed(string text) {
        owner.set_status(text);
        owner.log_status_activity(text);
    }

    public void on_editor_state_changed(string text, bool editable) {
        owner.set_editor_state(text, editable);
    }

    public void on_validated_tag_occurrences_changed(CardTagOccurrence[] occurrences) {
        owner.set_validated_tag_occurrences(occurrences);
    }

    public void on_editor_save_state_changed(string text) {
        owner.set_editor_save_state_text(text);
    }

    public void on_card_durable_save_completed(string project_id,
                                               string card_id,
                                               int64 updated_at) {
        owner.refresh_milestones_after_card_save();
    }

    public void on_window_title_changed(string title_text) {
        owner.update_window_title(title_text);
    }

    public void on_toast_requested(string message) {
        owner.add_toast(message);
        owner.log_toast_activity(message);
    }

    public void on_error_reported(string title_text, string details) {
        owner.show_error(title_text, details);
        owner.log_error_activity(title_text, details);
    }

    public void on_show_editor_requested() {
        owner.show_editor_mode();
    }

    public void on_show_search_requested() {
        owner.show_search_mode();
    }

    public void on_search_summary_changed(string text) {
        owner.set_search_summary_text(text);
    }

    public void on_ai_status_refresh_requested() {
        owner.refresh_ai_status();
    }

    public void on_project_selection_requested(string? project_id) {
        owner.request_project_selection(project_id);
    }

    public void on_card_selection_requested(string? card_id) {
        owner.request_card_selection(card_id);
    }

    public void on_search_selection_requested(int position) {
        owner.request_search_selection(position);
    }

    public void on_ai_thread_title_changed(string? title_text) {
        owner.set_ai_thread_title(title_text);
    }

    public void on_ai_thread_selection_requested(string? thread_id) {
        owner.request_ai_thread_selection(thread_id);
    }

    public void on_api_client_ready(IHolderApi api_client) {
        owner.on_api_client_connected(api_client);
    }

    public void on_card_trashed(string card_id) {
        owner.refresh_trash_tool();
    }


    public void on_activity_requested(string kind,
                                      string message,
                                      string? project_id,
                                      string? card_id,
                                      ActivityDetails? details) {
        owner.log_activity(kind, message, project_id, card_id, details);
    }
}

internal class WindowMainControllerSignalSource : Object, IMainControllerSignalSource {
    public WindowMainControllerSignalSource(MainController controller) {
        controller.status_changed.connect((text) => {
            status_changed(text);
        });
        controller.editor_state_changed.connect((text, editable) => {
            editor_state_changed(text, editable);
        });
        controller.validated_tag_occurrences_changed.connect((occurrences) => {
            validated_tag_occurrences_changed(occurrences);
        });
        controller.editor_save_state_changed.connect((text) => {
            editor_save_state_changed(text);
        });
        controller.card_durable_save_completed.connect((project_id, card_id, updated_at) => {
            card_durable_save_completed(project_id, card_id, updated_at);
        });
        controller.window_title_changed.connect((title_text) => {
            window_title_changed(title_text);
        });
        controller.toast_requested.connect((message) => {
            toast_requested(message);
        });
        controller.error_reported.connect((title_text, details) => {
            error_reported(title_text, details);
        });
        controller.show_editor_requested.connect(() => {
            show_editor_requested();
        });
        controller.show_search_requested.connect(() => {
            show_search_requested();
        });
        controller.search_summary_changed.connect((text) => {
            search_summary_changed(text);
        });
        controller.ai_status_refresh_requested.connect(() => {
            ai_status_refresh_requested();
        });
        controller.project_selection_requested.connect((project_id) => {
            project_selection_requested(project_id);
        });
        controller.card_selection_requested.connect((card_id) => {
            card_selection_requested(card_id);
        });
        controller.search_selection_requested.connect((position) => {
            search_selection_requested(position);
        });
        controller.ai_thread_title_changed.connect((title_text) => {
            ai_thread_title_changed(title_text);
        });
        controller.ai_thread_selection_requested.connect((thread_id) => {
            ai_thread_selection_requested(thread_id);
        });
        controller.api_client_ready.connect((api_client) => {
            api_client_ready(api_client);
        });
        controller.card_trashed.connect((card_id) => {
            card_trashed(card_id);
        });
        controller.activity_requested.connect((kind, message, project_id, card_id, details) => {
            activity_requested(kind, message, project_id, card_id, details);
        });
    }
}

internal class WindowAiPanelEventSink : Object, IAiPanelEventSink {
    private MainWindow owner;

    public WindowAiPanelEventSink(MainWindow owner) {
        this.owner = owner;
    }

    public void set_status(string text) {
        owner.set_status(text);
    }

    public void show_error(string title_text, string details) {
        owner.show_error(title_text, details);
    }

    public void add_toast(string message) {
        owner.add_toast(message);
    }

    public void log_debug(string message) {
        owner.log_debug_line(message);
    }

    public void log_activity(string kind,
                             string message,
                             string? project_id,
                             string? card_id,
                             ActivityDetails? details) {
        owner.log_activity(kind, message, project_id, card_id, details);
        if (kind == "result.trash.restore") {
            owner.on_trash_item_restored.begin(card_id);
        }
    }
}

internal class WindowToolboxEventSink : Object, IToolboxEventSink {
    private MainWindow owner;

    public WindowToolboxEventSink(MainWindow owner) {
        this.owner = owner;
    }

    public void show_error(string title_text, string details) {
        owner.show_error(title_text, details);
    }

    public void add_toast(string message) {
        owner.add_toast(message);
    }

    public void show_tool_help_page(string tool_id) {
        owner.show_tool_help_page(tool_id);
    }

    public void confirm_move_card_to_trash(string card_id) {
        owner.confirm_move_card_to_trash(card_id);
    }

    public void send_current_card_as_email() {
        owner.send_current_card_as_email();
    }

    public void request_send_recovery_key_as_email() {
        owner.request_send_recovery_key_as_email();
    }

    public void request_save_recovery_key_to_usb() {
        owner.request_save_recovery_key_to_usb();
    }

    public void request_import_recovery_key() {
        owner.request_import_recovery_key();
    }

    public void append_text_to_current_card(string text) {
        owner.append_text_to_current_card(text);
    }

    public void log_activity(string kind,
                             string message,
                             string? project_id,
                             string? card_id,
                             ActivityDetails? details) {
        owner.log_activity(kind, message, project_id, card_id, details);
    }
}

internal class WindowToolboxEventSource : Object, IToolboxEventSource {
    public WindowToolboxEventSource(ToolboxPane toolbox) {
        toolbox.error_reported.connect((title_text, details) => {
            error_reported(title_text, details);
        });
        toolbox.toast_requested.connect((message) => {
            toast_requested(message);
        });
        toolbox.breadcrumb_navigation_requested.connect((tool_id, segment_index, project_id, card_id) => {
            breadcrumb_navigation_requested(tool_id, segment_index, project_id, card_id);
        });
        toolbox.flowboard_card_open_requested.connect((card_id) => {
            flowboard_card_open_requested(card_id);
        });
        toolbox.connections_card_open_requested.connect((card_id) => {
            connections_card_open_requested(card_id);
        });
        toolbox.tags_card_open_requested.connect((card_id) => {
            tags_card_open_requested(card_id);
        });
        toolbox.resources_card_open_requested.connect((card_id) => {
            resources_card_open_requested(card_id);
        });
        toolbox.milestones_card_open_requested.connect((card_id) => {
            milestones_card_open_requested(card_id);
        });
        toolbox.resource_references_requested.connect((resource) => {
            resource_references_requested(resource);
        });
        toolbox.connections_card_create_child_requested.connect((card_id) => {
            connections_card_create_child_requested(card_id);
        });
        toolbox.flowboard_card_move_to_trash_requested.connect((card_id) => {
            flowboard_card_move_to_trash_requested(card_id);
        });
        toolbox.flowboard_move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
            flowboard_move_intent_requested(card_id, project_id, intent, target_card_id, parent_card_id);
        });
        toolbox.flowboard_new_card_requested.connect((parent_card_id) => {
            flowboard_new_card_requested(parent_card_id);
        });
        toolbox.send_card_as_email_requested.connect(() => {
            send_card_as_email_requested();
        });
        toolbox.send_recovery_key_as_email_requested.connect(() => {
            send_recovery_key_as_email_requested();
        });
        toolbox.save_recovery_key_to_usb_requested.connect(() => {
            save_recovery_key_to_usb_requested();
        });
        toolbox.import_recovery_key_requested.connect(() => {
            import_recovery_key_requested();
        });
        toolbox.terminal_copy_to_card_requested.connect((text) => {
            terminal_copy_to_card_requested(text);
        });
        toolbox.activity_requested.connect((kind, message, project_id, card_id, details) => {
            activity_requested(kind, message, project_id, card_id, details);
        });
    }
}

internal class WindowFeedbackSink : Object, IWindowFeedbackSink {
    private MainWindow owner;

    public WindowFeedbackSink(MainWindow owner) {
        this.owner = owner;
    }

    public void add_toast(string message) {
        owner.add_toast(message);
    }

    public void show_error(string title_text, string details) {
        owner.show_error(title_text, details);
    }
}

internal class WindowActionSink : Object, IWindowActionSink {
    private MainWindow owner;

    public WindowActionSink(MainWindow owner) {
        this.owner = owner;
    }

    public void on_refresh_requested() {
        owner.handle_refresh_action();
    }

    public void on_save_requested() {
        owner.handle_save_action();
    }

    public void on_new_project_requested() {
        owner.handle_new_project_action();
    }

    public void on_new_card_requested() {
        owner.handle_new_card_action();
    }

    public void on_flowboard_new_child_card_requested() {
        owner.handle_flowboard_new_child_card_action();
    }

    public void on_move_selected_card_to_trash_requested() {
        owner.handle_move_selected_card_to_trash_action();
    }

    public void on_toggle_toolbox_requested() {
        owner.handle_toggle_toolbox_action();
    }

    public void on_find_replace_requested() {
        owner.handle_find_replace_action();
    }

    public void on_print_requested() {
        owner.handle_print_action();
    }

    public void on_show_local_info_requested() {
        owner.handle_show_local_info_action();
    }

    public void on_show_preferences_requested() {
        owner.handle_show_preferences_action();
    }

    public void on_show_about_requested() {
        owner.handle_show_about_action();
    }
}

internal class WindowSidebarEventSink : Object, ISidebarEventSink {
    private MainWindow owner;

    public WindowSidebarEventSink(MainWindow owner) {
        this.owner = owner;
    }

    public void on_sidebar_card_move_to_trash_requested(string card_id) {
        owner.on_sidebar_card_move_to_trash_requested(card_id);
    }

    public void on_sidebar_card_context_selection_requested(string card_id) {
        owner.on_sidebar_card_context_selection_requested(card_id);
    }

    public void on_sidebar_card_create_child_requested(string card_id) {
        owner.on_sidebar_card_create_child_requested(card_id);
    }
}

internal class WindowSidebarEventSource : Object, ISidebarEventSource {
    private SidebarPane sidebar;

    public WindowSidebarEventSource(SidebarPane sidebar) {
        this.sidebar = sidebar;
        sidebar.card_move_to_trash_requested.connect((card_id) => {
            card_move_to_trash_requested(card_id);
        });
        sidebar.card_context_selection_requested.connect((card_id) => {
            card_context_selection_requested(card_id);
        });
        sidebar.card_create_child_requested.connect((card_id) => {
            card_create_child_requested(card_id);
        });
    }
}

internal class WindowWorkspaceEventSink : Object, IWorkspaceEventSink {
    private MainWindow owner;

    public WindowWorkspaceEventSink(MainWindow owner) {
        this.owner = owner;
    }

    public void on_workspace_refresh_requested() {
        owner.on_workspace_refresh_requested();
    }

    public void on_workspace_new_project_requested() {
        owner.on_workspace_new_project_requested();
    }

    public void on_workspace_new_card_requested() {
        owner.on_workspace_new_card_requested();
    }

    public void on_workspace_explorer_panel_toggled(bool visible) {
        owner.on_workspace_explorer_panel_toggled(visible);
    }

    public void on_workspace_ai_panel_toggled(bool visible) {
        owner.on_workspace_ai_panel_toggled(visible);
    }

    public void on_workspace_toolbox_toggled(bool visible) {
        owner.on_workspace_toolbox_toggled(visible);
    }

    public void on_workspace_open_debug_panel_requested() {
        owner.on_workspace_open_debug_panel_requested();
    }

    public void on_workspace_search_activated() {
        owner.on_workspace_search_activated();
    }

    public void on_workspace_search_changed() {
        owner.on_workspace_search_changed();
    }

    public void on_workspace_search_cleared() {
        owner.on_workspace_search_cleared();
    }

    public void on_workspace_search_focus_results_requested() {
        owner.on_workspace_search_focus_results_requested();
    }

    public void on_workspace_search_result_activated(uint position) {
        owner.on_workspace_search_result_activated(position);
    }

    public void on_workspace_find_next_requested() {
        owner.on_workspace_find_next_requested();
    }

    public void on_workspace_replace_requested() {
        owner.on_workspace_replace_requested();
    }

    public void on_workspace_replace_all_requested() {
        owner.on_workspace_replace_all_requested();
    }
}

internal class WindowWorkspaceEventSource : Object, IWorkspaceEventSource {
    private WorkspacePane workspace;

    public WindowWorkspaceEventSource(WorkspacePane workspace) {
        this.workspace = workspace;
        workspace.refresh_requested.connect(() => {
            refresh_requested();
        });
        workspace.new_project_requested.connect(() => {
            new_project_requested();
        });
        workspace.new_card_requested.connect(() => {
            new_card_requested();
        });
        workspace.explorer_panel_toggled.connect((visible) => {
            explorer_panel_toggled(visible);
        });
        workspace.ai_panel_toggled.connect((visible) => {
            ai_panel_toggled(visible);
        });
        workspace.toolbox_toggled.connect((visible) => {
            toolbox_toggled(visible);
        });
        workspace.open_debug_panel_requested.connect(() => {
            open_debug_panel_requested();
        });
        workspace.search_activated.connect(() => {
            search_activated();
        });
        workspace.search_changed.connect(() => {
            search_changed();
        });
        workspace.search_cleared.connect(() => {
            search_cleared();
        });
        workspace.search_focus_results_requested.connect(() => {
            search_focus_results_requested();
        });
        workspace.search_result_activated.connect((position) => {
            search_result_activated(position);
        });
        workspace.find_next_requested.connect(() => {
            find_next_requested();
        });
        workspace.replace_requested.connect(() => {
            replace_requested();
        });
        workspace.replace_all_requested.connect(() => {
            replace_all_requested();
        });
    }
}

internal class WindowSelectionEditorEventSink : Object, IWindowSelectionEditorEventSink {
    private MainWindow owner;

    public WindowSelectionEditorEventSink(MainWindow owner) {
        this.owner = owner;
    }

    public void on_project_selection_changed() {
        owner.on_project_selection_changed();
    }

    public void on_card_selection_changed() {
        owner.on_card_selection_changed();
    }

    public void on_ai_thread_selection_changed() {
        owner.on_ai_thread_selection_changed();
    }

    public void on_editor_buffer_changed() {
        owner.on_editor_buffer_changed();
    }

    public void on_internal_link_click_pressed(Gtk.GestureClick gesture,
                                               int n_press,
                                               double x,
                                               double y) {
        owner.on_internal_link_click_pressed(gesture, n_press, x, y);
    }

    public bool on_internal_link_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state) {
        return owner.on_internal_link_key_pressed(keyval, keycode, state);
    }
}

internal class WindowFlowboardEventSink : Object, IWindowFlowboardEventSink {
    private MainWindow owner;

    public WindowFlowboardEventSink(MainWindow owner) {
        this.owner = owner;
    }

    public void on_card_store_items_changed(uint position, uint removed, uint added) {
        owner.on_card_store_items_changed(position, removed, added);
    }

    public void on_flowboard_project_overview_requested(string project_id) {
        owner.on_flowboard_project_overview_requested(project_id);
    }

    public void on_flowboard_context_load_requested(string project_id, string? parent_card_id) {
        owner.on_flowboard_context_load_requested(project_id, parent_card_id);
    }
}

internal class WindowLifecycleEventSink : Object, IWindowLifecycleEventSink {
    private MainWindow owner;

    public WindowLifecycleEventSink(MainWindow owner) {
        this.owner = owner;
    }

    public void on_project_create_error_reported(string title_text, string details) {
        owner.on_project_create_error_reported(title_text, details);
    }

    public bool on_window_close_requested() {
        return owner.on_window_close_requested();
    }
}

internal class WindowStateEventSink : Object, IWindowStateEventSink {
    private MainWindow owner;

    public WindowStateEventSink(MainWindow owner) {
        this.owner = owner;
    }

    public void on_root_paned_position_changed(int position) {
        owner.on_root_paned_position_changed(position);
    }

    public void on_app_state_changed() {
        owner.on_app_state_changed();
    }

    public void on_navigation_loading_changed(bool loading) {
        owner.on_navigation_loading_changed(loading);
    }
}

}
