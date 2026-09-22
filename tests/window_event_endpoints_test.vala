using GLib;

namespace HolderLinux {

// ---- Interfaces copied verbatim from the real files that declare them, so this target links only
// window_event_endpoints.vala plus the standard model files and does not need to link window.vala,
// toolbox.vala, workspace_pane.vala, sidebar.vala or the controller files that hold the rest of each
// interface's own binder/orchestrator logic (which are tested separately: e.g.
// tests/main_signal_binder_test.vala, tests/window_event_binders_test.vala).

// from src/controllers/main_signal_binder.vala
internal interface IMainControllerSignalSink : Object {
    public abstract void on_status_changed(string text);
    public abstract void on_editor_state_changed(string text, bool editable);
    public abstract void on_validated_tag_occurrences_changed(CardTagOccurrence[] occurrences);
    public abstract void on_editor_save_state_changed(string text);
    public abstract void on_card_durable_save_completed(string project_id,
                                                        string card_id,
                                                        int64 updated_at);
    public abstract void on_window_title_changed(string title_text);
    public abstract void on_toast_requested(string message);
    public abstract void on_error_reported(string title_text, string details);
    public abstract void on_show_editor_requested();
    public abstract void on_show_search_requested();
    public abstract void on_search_summary_changed(string text);
    public abstract void on_ai_status_refresh_requested();
    public abstract void on_project_selection_requested(string? project_id);
    public abstract void on_card_selection_requested(string? card_id);
    public abstract void on_search_selection_requested(int position);
    public abstract void on_ai_thread_title_changed(string? title_text);
    public abstract void on_ai_thread_selection_requested(string? thread_id);
    public abstract void on_api_client_ready(IHolderApi api_client);
    public abstract void on_card_trashed(string card_id);
    public abstract void on_activity_requested(string kind,
                                              string message,
                                              string? project_id,
                                              string? card_id,
                                              ActivityDetails? details);
}

internal interface IMainControllerSignalSource : Object {
    public abstract signal void status_changed(string text);
    public abstract signal void editor_state_changed(string text, bool editable);
    public abstract signal void validated_tag_occurrences_changed(CardTagOccurrence[] occurrences);
    public abstract signal void editor_save_state_changed(string text);
    public abstract signal void card_durable_save_completed(string project_id,
                                                            string card_id,
                                                            int64 updated_at);
    public abstract signal void window_title_changed(string title_text);
    public abstract signal void toast_requested(string message);
    public abstract signal void error_reported(string title_text, string details);
    public abstract signal void show_editor_requested();
    public abstract signal void show_search_requested();
    public abstract signal void search_summary_changed(string text);
    public abstract signal void ai_status_refresh_requested();
    public abstract signal void project_selection_requested(string? project_id);
    public abstract signal void card_selection_requested(string? card_id);
    public abstract signal void search_selection_requested(int position);
    public abstract signal void ai_thread_title_changed(string? title_text);
    public abstract signal void ai_thread_selection_requested(string? thread_id);
    public abstract signal void api_client_ready(IHolderApi api_client);
    public abstract signal void card_trashed(string card_id);
    public abstract signal void activity_requested(string kind,
                                                  string message,
                                                  string? project_id,
                                                  string? card_id,
                                                  ActivityDetails? details);
}

// from src/controllers/ai_panel_event_orchestrator.vala
internal interface IAiPanelEventSink : Object {
    public abstract void set_status(string text);
    public abstract void show_error(string title_text, string details);
    public abstract void add_toast(string message);
    public abstract void log_debug(string message);
    public abstract void log_activity(string kind,
                                      string message,
                                      string? project_id,
                                      string? card_id,
                                      ActivityDetails? details);
}

// from src/controllers/toolbox_event_orchestrator.vala
internal interface IToolboxEventSink : Object {
    public abstract void show_error(string title_text, string details);
    public abstract void add_toast(string message);
    public abstract void show_tool_help_page(string tool_id);
    public abstract void confirm_move_card_to_trash(string card_id);
    public abstract void reload_card_after_history_restore(string card_id);
    public abstract void select_ai_thread_from_history(string thread_id);
    public abstract void send_current_card_as_email();
    public abstract void request_send_recovery_key_as_email();
    public abstract void request_save_recovery_key_to_usb();
    public abstract void request_import_recovery_key();
    public abstract void append_text_to_current_card(string text);
    public abstract void log_activity(string kind,
                                      string message,
                                      string? project_id,
                                      string? card_id,
                                      ActivityDetails? details);
}

internal interface IToolboxEventSource : Object {
    public abstract signal void error_reported(string title_text, string details);
    public abstract signal void toast_requested(string message);
    public abstract signal void breadcrumb_navigation_requested(string tool_id,
                                                               int segment_index,
                                                               string? project_id,
                                                               string? card_id);
    public abstract signal void flowboard_card_open_requested(string card_id);
    public abstract signal void connections_card_open_requested(string card_id);
    public abstract signal void tags_card_open_requested(string card_id);
    public abstract signal void resources_card_open_requested(string card_id);
    public abstract signal void milestones_card_open_requested(string card_id);
    public abstract signal void resource_references_requested(ProjectResource resource);
    public abstract signal void connections_card_create_child_requested(string card_id);
    public abstract signal void flowboard_card_move_to_trash_requested(string card_id);
    public abstract signal void flowboard_move_intent_requested(string card_id,
                                                                string project_id,
                                                                string intent,
                                                                string? target_card_id,
                                                                string? parent_card_id);
    public abstract signal void flowboard_new_card_requested(string? parent_card_id);
    public abstract signal void history_copy_as_card_requested(string title, string content);
    public abstract signal void history_restore_succeeded(string card_id);
    public abstract signal void history_card_open_requested(string card_id);
    public abstract signal void history_ai_thread_open_requested(string thread_id);
    public abstract signal void send_card_as_email_requested();
    public abstract signal void send_recovery_key_as_email_requested();
    public abstract signal void save_recovery_key_to_usb_requested();
    public abstract signal void import_recovery_key_requested();
    public abstract signal void terminal_copy_to_card_requested(string text);
    public abstract signal void activity_requested(string kind,
                                                  string message,
                                                  string? project_id,
                                                  string? card_id,
                                                  ActivityDetails? details);
}

// from src/controllers/window_feedback_orchestrator.vala
internal interface IWindowFeedbackSink : Object {
    public abstract void add_toast(string message);
    public abstract void show_error(string title_text, string details);
}

// from src/controllers/window_action_binder.vala
internal interface IWindowActionSink : Object {
    public abstract void on_refresh_requested();
    public abstract void on_save_requested();
    public abstract void on_new_project_requested();
    public abstract void on_new_card_requested();
    public abstract void on_flowboard_new_child_card_requested();
    public abstract void on_move_selected_card_to_trash_requested();
    public abstract void on_toggle_toolbox_requested();
    public abstract void on_find_replace_requested();
    public abstract void on_print_requested();
    public abstract void on_show_local_info_requested();
    public abstract void on_show_preferences_requested();
    public abstract void on_show_about_requested();
}

// from src/views/adapters/window_sidebar_events.vala
internal interface ISidebarEventSink : Object {
    public abstract void on_sidebar_card_move_to_trash_requested(string card_id);
    public abstract void on_sidebar_card_context_selection_requested(string card_id);
    public abstract void on_sidebar_card_create_child_requested(string card_id);
}

internal interface ISidebarEventSource : Object {
    public abstract signal void card_move_to_trash_requested(string card_id);
    public abstract signal void card_context_selection_requested(string card_id);
    public abstract signal void card_create_child_requested(string card_id);
}

// from src/views/adapters/window_workspace_events.vala
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

// from src/controllers/window_flowboard_event_binder.vala
internal interface IWindowFlowboardEventSink : Object {
    public abstract void on_card_store_items_changed(uint position, uint removed, uint added);
    public abstract void on_flowboard_project_overview_requested(string project_id);
    public abstract void on_flowboard_context_load_requested(string project_id, string? parent_card_id);
}

// from src/views/adapters/window_selection_editor_events.vala
internal interface IWindowSelectionEditorEventSink : Object {
    public abstract void on_project_selection_changed();
    public abstract void on_card_selection_changed();
    public abstract void on_ai_thread_selection_changed();
    public abstract void on_editor_buffer_changed();
    public abstract void on_internal_link_click_pressed(Gtk.GestureClick gesture,
                                                        int n_press,
                                                        double x,
                                                        double y);
    public abstract bool on_internal_link_key_pressed(uint keyval,
                                                      uint keycode,
                                                      Gdk.ModifierType state);
}

// from src/views/adapters/window_lifecycle_events.vala
internal interface IWindowLifecycleEventSink : Object {
    public abstract void on_project_create_error_reported(string title_text, string details);
    public abstract bool on_window_close_requested();
}

// from src/views/adapters/window_state_events.vala
internal interface IWindowStateEventSink : Object {
    public abstract void on_root_paned_position_changed(int position);
    public abstract void on_app_state_changed();
    public abstract void on_navigation_loading_changed(bool loading);
}

// A tiny stand-in for src/controllers/trash.vala's TrashController: the only member
// window_event_endpoints.vala uses is this static predicate.
public class TrashController : Object {
    public const string ACTIVITY_KIND_RESTORED = "result.trash.restore";
    public static bool is_restored_activity(string kind) {
        return kind == ACTIVITY_KIND_RESTORED;
    }
}

// window_local_info.vala's classes are pure forwarding glue too, over the same MainWindow/
// MainController/ToolboxPane stand-ins as window_event_endpoints.vala, so this target covers both.

// from src/controllers/local_info.vala
public interface ILocalInfoLogger : Object {
    public abstract void log_debug(string message);
}

// from src/controllers/local_info_flow.vala
public interface ILocalInfoFlowContext : Object {
    public abstract IHolderApi? get_api_client();
}

// from src/views/adapters/local_info.vala
public interface ILocalInfoViewSink : Object {
    public abstract void set_editor_state(string text, bool editable);
    public abstract void show_editor_mode();
    public abstract void update_window_title(string title_text);
    public abstract void set_status(string text);
    public abstract void show_error(string title_text, string details);
}

// Signal-only stand-in: WindowMainControllerSignalSource only connects to these signals.
public class MainController : Object {
    public signal void status_changed(string text);
    public signal void editor_state_changed(string text, bool editable);
    public signal void validated_tag_occurrences_changed(CardTagOccurrence[] occurrences);
    public signal void editor_save_state_changed(string text);
    public signal void card_durable_save_completed(string project_id, string card_id, int64 updated_at);
    public signal void window_title_changed(string title_text);
    public signal void toast_requested(string message);
    public signal void error_reported(string title_text, string details);
    public signal void show_editor_requested();
    public signal void show_search_requested();
    public signal void search_summary_changed(string text);
    public signal void ai_status_refresh_requested();
    public signal void project_selection_requested(string? project_id);
    public signal void card_selection_requested(string? card_id);
    public signal void search_selection_requested(int position);
    public signal void ai_thread_title_changed(string? title_text);
    public signal void ai_thread_selection_requested(string? thread_id);
    public signal void api_client_ready(IHolderApi api_client);
    public signal void card_trashed(string card_id);
    public signal void activity_requested(string kind, string message, string? project_id, string? card_id, ActivityDetails? details);

    // Used by window_local_info.vala's WindowLocalInfoFlowContext.
    public IHolderApi? api_client = null;
    public IHolderApi? get_api_client() {
        return api_client;
    }
}

// Signal-only stand-in: WindowToolboxEventSource only connects to these signals.
// log_debug is used by window_local_info.vala's WindowLocalInfoLogger.
public class ToolboxPane : Object {
    public int log_debug_calls = 0;
    public string last_log_debug_message = "";
    public void log_debug(string message) {
        log_debug_calls++;
        last_log_debug_message = message;
    }

    public signal void error_reported(string title_text, string details);
    public signal void toast_requested(string message);
    public signal void breadcrumb_navigation_requested(string tool_id, int segment_index, string? project_id, string? card_id);
    public signal void flowboard_card_open_requested(string card_id);
    public signal void connections_card_open_requested(string card_id);
    public signal void tags_card_open_requested(string card_id);
    public signal void resources_card_open_requested(string card_id);
    public signal void milestones_card_open_requested(string card_id);
    public signal void resource_references_requested(ProjectResource resource);
    public signal void connections_card_create_child_requested(string card_id);
    public signal void flowboard_card_move_to_trash_requested(string card_id);
    public signal void flowboard_move_intent_requested(string card_id, string project_id, string intent, string? target_card_id, string? parent_card_id);
    public signal void flowboard_new_card_requested(string? parent_card_id);
    public signal void history_copy_as_card_requested(string title, string content);
    public signal void history_restore_succeeded(string _project_id, string card_id);
    public signal void history_card_open_requested(string card_id);
    public signal void history_ai_thread_open_requested(string thread_id);
    public signal void send_card_as_email_requested();
    public signal void send_recovery_key_as_email_requested();
    public signal void save_recovery_key_to_usb_requested();
    public signal void import_recovery_key_requested();
    public signal void terminal_copy_to_card_requested(string text);
    public signal void activity_requested(string kind, string message, string? project_id, string? card_id, ActivityDetails? details);
}

// Signal-only stand-in: WindowWorkspaceEventSource only connects to these signals.
public class WorkspacePane : Object {
    public signal void refresh_requested();
    public signal void new_project_requested();
    public signal void new_card_requested();
    public signal void explorer_panel_toggled(bool visible);
    public signal void ai_panel_toggled(bool visible);
    public signal void toolbox_toggled(bool visible);
    public signal void open_debug_panel_requested();
    public signal void search_activated();
    public signal void search_changed();
    public signal void search_cleared();
    public signal void search_focus_results_requested();
    public signal void search_result_activated(uint position);
    public signal void find_next_requested();
    public signal void replace_requested();
    public signal void replace_all_requested();
}

// Signal-only stand-in: WindowSidebarEventSource only connects to these signals.
public class SidebarPane : Object {
    public signal void card_move_to_trash_requested(string card_id);
    public signal void card_context_selection_requested(string card_id);
    public signal void card_create_child_requested(string card_id);
}

public class MainWindow : Object {
    public int calls = 0;
    public Gee.ArrayList<string> call_log = new Gee.ArrayList<string>();

    public int set_status_calls = 0;
    public string last_set_status_text = "";
    public int log_status_activity_calls = 0;
    public string last_log_status_activity_text = "";
    public int set_editor_state_calls = 0;
    public string last_set_editor_state_text = "";
    public bool last_set_editor_state_editable = false;
    public int set_validated_tag_occurrences_calls = 0;
    public CardTagOccurrence[]? last_set_validated_tag_occurrences_occurrences = null;
    public int set_editor_save_state_text_calls = 0;
    public string last_set_editor_save_state_text_text = "";
    public int refresh_milestones_after_card_save_calls = 0;
    public int refresh_history_after_card_save_calls = 0;
    public string last_refresh_history_after_card_save_project_id = "";
    public string last_refresh_history_after_card_save_card_id = "";
    public int update_window_title_calls = 0;
    public string last_update_window_title_title_text = "";
    public int add_toast_calls = 0;
    public string last_add_toast_msg = "";
    public int log_toast_activity_calls = 0;
    public string last_log_toast_activity_message = "";
    public int show_error_calls = 0;
    public string last_show_error_title_text = "";
    public string last_show_error_details = "";
    public int log_error_activity_calls = 0;
    public string last_log_error_activity_title_text = "";
    public string last_log_error_activity_details = "";
    public int show_editor_mode_calls = 0;
    public int show_search_mode_calls = 0;
    public int set_search_summary_text_calls = 0;
    public string last_set_search_summary_text_text = "";
    public int refresh_ai_status_calls = 0;
    public int request_project_selection_calls = 0;
    public string? last_request_project_selection_project_id = "";
    public int request_card_selection_calls = 0;
    public string? last_request_card_selection_card_id = "";
    public int request_search_selection_calls = 0;
    public int last_request_search_selection_position = 0;
    public int set_ai_thread_title_calls = 0;
    public string? last_set_ai_thread_title_title_text = "";
    public int request_ai_thread_selection_calls = 0;
    public string? last_request_ai_thread_selection_thread_id = "";
    public int on_api_client_connected_calls = 0;
    public IHolderApi? last_on_api_client_connected_api_client = null;
    public int refresh_trash_tool_calls = 0;
    public int log_activity_calls = 0;
    public string last_log_activity_kind = "";
    public string last_log_activity_message = "";
    public string? last_log_activity_project_id = "";
    public string? last_log_activity_card_id = "";
    public ActivityDetails? last_log_activity_details = null;
    public int log_debug_line_calls = 0;
    public string last_log_debug_line_message = "";
    public int on_trash_item_restored_calls = 0;
    public string? last_on_trash_item_restored_card_id = "";
    public int show_tool_help_page_calls = 0;
    public string last_show_tool_help_page_tool_id = "";
    public int confirm_move_card_to_trash_calls = 0;
    public string last_confirm_move_card_to_trash_card_id = "";
    public int reload_card_after_history_restore_calls = 0;
    public string last_reload_card_after_history_restore_card_id = "";
    public int select_ai_thread_from_history_calls = 0;
    public string last_select_ai_thread_from_history_thread_id = "";
    public int send_current_card_as_email_calls = 0;
    public int request_send_recovery_key_as_email_calls = 0;
    public int request_save_recovery_key_to_usb_calls = 0;
    public int request_import_recovery_key_calls = 0;
    public int append_text_to_current_card_calls = 0;
    public string last_append_text_to_current_card_text = "";
    public int handle_refresh_action_calls = 0;
    public int handle_save_action_calls = 0;
    public int handle_new_project_action_calls = 0;
    public int handle_new_card_action_calls = 0;
    public int handle_flowboard_new_child_card_action_calls = 0;
    public int handle_move_selected_card_to_trash_action_calls = 0;
    public int handle_toggle_toolbox_action_calls = 0;
    public int handle_find_replace_action_calls = 0;
    public int handle_print_action_calls = 0;
    public int handle_show_local_info_action_calls = 0;
    public int handle_show_preferences_action_calls = 0;
    public int handle_show_about_action_calls = 0;
    public int on_sidebar_card_move_to_trash_requested_calls = 0;
    public string last_on_sidebar_card_move_to_trash_requested_card_id = "";
    public int on_sidebar_card_context_selection_requested_calls = 0;
    public string last_on_sidebar_card_context_selection_requested_card_id = "";
    public int on_sidebar_card_create_child_requested_calls = 0;
    public string last_on_sidebar_card_create_child_requested_card_id = "";
    public int on_workspace_refresh_requested_calls = 0;
    public int on_workspace_new_project_requested_calls = 0;
    public int on_workspace_new_card_requested_calls = 0;
    public int on_workspace_explorer_panel_toggled_calls = 0;
    public bool last_on_workspace_explorer_panel_toggled_visible = false;
    public int on_workspace_ai_panel_toggled_calls = 0;
    public bool last_on_workspace_ai_panel_toggled_visible = false;
    public int on_workspace_toolbox_toggled_calls = 0;
    public bool last_on_workspace_toolbox_toggled_visible = false;
    public int on_workspace_open_debug_panel_requested_calls = 0;
    public int on_workspace_search_activated_calls = 0;
    public int on_workspace_search_changed_calls = 0;
    public int on_workspace_search_cleared_calls = 0;
    public int on_workspace_search_focus_results_requested_calls = 0;
    public int on_workspace_search_result_activated_calls = 0;
    public uint last_on_workspace_search_result_activated_position = 0;
    public int on_workspace_find_next_requested_calls = 0;
    public int on_workspace_replace_requested_calls = 0;
    public int on_workspace_replace_all_requested_calls = 0;
    public int on_project_selection_changed_calls = 0;
    public int on_card_selection_changed_calls = 0;
    public int on_ai_thread_selection_changed_calls = 0;
    public int on_editor_buffer_changed_calls = 0;
    public int on_internal_link_click_pressed_calls = 0;
    public Gtk.GestureClick? last_on_internal_link_click_pressed_gesture = null;
    public int last_on_internal_link_click_pressed_n_press = 0;
    public double last_on_internal_link_click_pressed_x = 0.0;
    public double last_on_internal_link_click_pressed_y = 0.0;
    public int on_internal_link_key_pressed_calls = 0;
    public uint last_on_internal_link_key_pressed_keyval = 0;
    public uint last_on_internal_link_key_pressed_keycode = 0;
    public bool on_internal_link_key_pressed_result = true;
    public int on_card_store_items_changed_calls = 0;
    public uint last_on_card_store_items_changed_position = 0;
    public uint last_on_card_store_items_changed_removed = 0;
    public uint last_on_card_store_items_changed_added = 0;
    public int on_flowboard_project_overview_requested_calls = 0;
    public string last_on_flowboard_project_overview_requested_project_id = "";
    public int on_flowboard_context_load_requested_calls = 0;
    public string last_on_flowboard_context_load_requested_project_id = "";
    public string? last_on_flowboard_context_load_requested_parent_card_id = "";
    public int on_project_create_error_reported_calls = 0;
    public string last_on_project_create_error_reported_title_text = "";
    public string last_on_project_create_error_reported_details = "";
    public int on_window_close_requested_calls = 0;
    public bool on_window_close_requested_result = true;
    public int on_root_paned_position_changed_calls = 0;
    public int last_on_root_paned_position_changed_position = 0;
    public int on_app_state_changed_calls = 0;
    public int on_navigation_loading_changed_calls = 0;
    public bool last_on_navigation_loading_changed_loading = false;

    public void set_status(string text) {
        set_status_calls++;
        calls++;
        call_log.add("set_status");
        last_set_status_text = text;
    }

    public void log_status_activity(string text) {
        log_status_activity_calls++;
        calls++;
        call_log.add("log_status_activity");
        last_log_status_activity_text = text;
    }

    public void set_editor_state(string text, bool editable) {
        set_editor_state_calls++;
        calls++;
        call_log.add("set_editor_state");
        last_set_editor_state_text = text;
        last_set_editor_state_editable = editable;
    }

    public void set_validated_tag_occurrences(CardTagOccurrence[] occurrences) {
        set_validated_tag_occurrences_calls++;
        calls++;
        call_log.add("set_validated_tag_occurrences");
        last_set_validated_tag_occurrences_occurrences = occurrences;
    }

    public void set_editor_save_state_text(string text) {
        set_editor_save_state_text_calls++;
        calls++;
        call_log.add("set_editor_save_state_text");
        last_set_editor_save_state_text_text = text;
    }

    public void refresh_milestones_after_card_save() {
        refresh_milestones_after_card_save_calls++;
        calls++;
        call_log.add("refresh_milestones_after_card_save");
    }

    public void refresh_history_after_card_save(string project_id, string card_id) {
        refresh_history_after_card_save_calls++;
        calls++;
        call_log.add("refresh_history_after_card_save");
        last_refresh_history_after_card_save_project_id = project_id;
        last_refresh_history_after_card_save_card_id = card_id;
    }

    public void update_window_title(string title_text) {
        update_window_title_calls++;
        calls++;
        call_log.add("update_window_title");
        last_update_window_title_title_text = title_text;
    }

    public void add_toast(string msg) {
        add_toast_calls++;
        calls++;
        call_log.add("add_toast");
        last_add_toast_msg = msg;
    }

    public void log_toast_activity(string message) {
        log_toast_activity_calls++;
        calls++;
        call_log.add("log_toast_activity");
        last_log_toast_activity_message = message;
    }

    public void show_error(string title_text, string details) {
        show_error_calls++;
        calls++;
        call_log.add("show_error");
        last_show_error_title_text = title_text;
        last_show_error_details = details;
    }

    public void log_error_activity(string title_text, string details) {
        log_error_activity_calls++;
        calls++;
        call_log.add("log_error_activity");
        last_log_error_activity_title_text = title_text;
        last_log_error_activity_details = details;
    }

    public void show_editor_mode() {
        show_editor_mode_calls++;
        calls++;
        call_log.add("show_editor_mode");
    }

    public void show_search_mode() {
        show_search_mode_calls++;
        calls++;
        call_log.add("show_search_mode");
    }

    public void set_search_summary_text(string text) {
        set_search_summary_text_calls++;
        calls++;
        call_log.add("set_search_summary_text");
        last_set_search_summary_text_text = text;
    }

    public void refresh_ai_status() {
        refresh_ai_status_calls++;
        calls++;
        call_log.add("refresh_ai_status");
    }

    public void request_project_selection(string? project_id) {
        request_project_selection_calls++;
        calls++;
        call_log.add("request_project_selection");
        last_request_project_selection_project_id = project_id;
    }

    public void request_card_selection(string? card_id) {
        request_card_selection_calls++;
        calls++;
        call_log.add("request_card_selection");
        last_request_card_selection_card_id = card_id;
    }

    public void request_search_selection(int position) {
        request_search_selection_calls++;
        calls++;
        call_log.add("request_search_selection");
        last_request_search_selection_position = position;
    }

    public void set_ai_thread_title(string? title_text) {
        set_ai_thread_title_calls++;
        calls++;
        call_log.add("set_ai_thread_title");
        last_set_ai_thread_title_title_text = title_text;
    }

    public void request_ai_thread_selection(string? thread_id) {
        request_ai_thread_selection_calls++;
        calls++;
        call_log.add("request_ai_thread_selection");
        last_request_ai_thread_selection_thread_id = thread_id;
    }

    public void on_api_client_connected(IHolderApi api_client) {
        on_api_client_connected_calls++;
        calls++;
        call_log.add("on_api_client_connected");
        last_on_api_client_connected_api_client = api_client;
    }

    public void refresh_trash_tool() {
        refresh_trash_tool_calls++;
        calls++;
        call_log.add("refresh_trash_tool");
    }

    public void log_activity(string kind, string message, string? project_id, string? card_id, ActivityDetails? details) {
        log_activity_calls++;
        calls++;
        call_log.add("log_activity");
        last_log_activity_kind = kind;
        last_log_activity_message = message;
        last_log_activity_project_id = project_id;
        last_log_activity_card_id = card_id;
        last_log_activity_details = details;
    }

    public void log_debug_line(string message) {
        log_debug_line_calls++;
        calls++;
        call_log.add("log_debug_line");
        last_log_debug_line_message = message;
    }

    public async void on_trash_item_restored(string? card_id) {
        on_trash_item_restored_calls++;
        calls++;
        call_log.add("on_trash_item_restored");
        last_on_trash_item_restored_card_id = card_id;
    }

    public void show_tool_help_page(string tool_id) {
        show_tool_help_page_calls++;
        calls++;
        call_log.add("show_tool_help_page");
        last_show_tool_help_page_tool_id = tool_id;
    }

    public void confirm_move_card_to_trash(string card_id) {
        confirm_move_card_to_trash_calls++;
        calls++;
        call_log.add("confirm_move_card_to_trash");
        last_confirm_move_card_to_trash_card_id = card_id;
    }

    public void reload_card_after_history_restore(string card_id) {
        reload_card_after_history_restore_calls++;
        calls++;
        call_log.add("reload_card_after_history_restore");
        last_reload_card_after_history_restore_card_id = card_id;
    }

    public void select_ai_thread_from_history(string thread_id) {
        select_ai_thread_from_history_calls++;
        calls++;
        call_log.add("select_ai_thread_from_history");
        last_select_ai_thread_from_history_thread_id = thread_id;
    }

    public void send_current_card_as_email() {
        send_current_card_as_email_calls++;
        calls++;
        call_log.add("send_current_card_as_email");
    }

    public void request_send_recovery_key_as_email() {
        request_send_recovery_key_as_email_calls++;
        calls++;
        call_log.add("request_send_recovery_key_as_email");
    }

    public void request_save_recovery_key_to_usb() {
        request_save_recovery_key_to_usb_calls++;
        calls++;
        call_log.add("request_save_recovery_key_to_usb");
    }

    public void request_import_recovery_key() {
        request_import_recovery_key_calls++;
        calls++;
        call_log.add("request_import_recovery_key");
    }

    public void append_text_to_current_card(string text) {
        append_text_to_current_card_calls++;
        calls++;
        call_log.add("append_text_to_current_card");
        last_append_text_to_current_card_text = text;
    }

    public void handle_refresh_action() {
        handle_refresh_action_calls++;
        calls++;
        call_log.add("handle_refresh_action");
    }

    public void handle_save_action() {
        handle_save_action_calls++;
        calls++;
        call_log.add("handle_save_action");
    }

    public void handle_new_project_action() {
        handle_new_project_action_calls++;
        calls++;
        call_log.add("handle_new_project_action");
    }

    public void handle_new_card_action() {
        handle_new_card_action_calls++;
        calls++;
        call_log.add("handle_new_card_action");
    }

    public void handle_flowboard_new_child_card_action() {
        handle_flowboard_new_child_card_action_calls++;
        calls++;
        call_log.add("handle_flowboard_new_child_card_action");
    }

    public void handle_move_selected_card_to_trash_action() {
        handle_move_selected_card_to_trash_action_calls++;
        calls++;
        call_log.add("handle_move_selected_card_to_trash_action");
    }

    public void handle_toggle_toolbox_action() {
        handle_toggle_toolbox_action_calls++;
        calls++;
        call_log.add("handle_toggle_toolbox_action");
    }

    public void handle_find_replace_action() {
        handle_find_replace_action_calls++;
        calls++;
        call_log.add("handle_find_replace_action");
    }

    public void handle_print_action() {
        handle_print_action_calls++;
        calls++;
        call_log.add("handle_print_action");
    }

    public void handle_show_local_info_action() {
        handle_show_local_info_action_calls++;
        calls++;
        call_log.add("handle_show_local_info_action");
    }

    public void handle_show_preferences_action() {
        handle_show_preferences_action_calls++;
        calls++;
        call_log.add("handle_show_preferences_action");
    }

    public void handle_show_about_action() {
        handle_show_about_action_calls++;
        calls++;
        call_log.add("handle_show_about_action");
    }

    public void on_sidebar_card_move_to_trash_requested(string card_id) {
        on_sidebar_card_move_to_trash_requested_calls++;
        calls++;
        call_log.add("on_sidebar_card_move_to_trash_requested");
        last_on_sidebar_card_move_to_trash_requested_card_id = card_id;
    }

    public void on_sidebar_card_context_selection_requested(string card_id) {
        on_sidebar_card_context_selection_requested_calls++;
        calls++;
        call_log.add("on_sidebar_card_context_selection_requested");
        last_on_sidebar_card_context_selection_requested_card_id = card_id;
    }

    public void on_sidebar_card_create_child_requested(string card_id) {
        on_sidebar_card_create_child_requested_calls++;
        calls++;
        call_log.add("on_sidebar_card_create_child_requested");
        last_on_sidebar_card_create_child_requested_card_id = card_id;
    }

    public void on_workspace_refresh_requested() {
        on_workspace_refresh_requested_calls++;
        calls++;
        call_log.add("on_workspace_refresh_requested");
    }

    public void on_workspace_new_project_requested() {
        on_workspace_new_project_requested_calls++;
        calls++;
        call_log.add("on_workspace_new_project_requested");
    }

    public void on_workspace_new_card_requested() {
        on_workspace_new_card_requested_calls++;
        calls++;
        call_log.add("on_workspace_new_card_requested");
    }

    public void on_workspace_explorer_panel_toggled(bool visible) {
        on_workspace_explorer_panel_toggled_calls++;
        calls++;
        call_log.add("on_workspace_explorer_panel_toggled");
        last_on_workspace_explorer_panel_toggled_visible = visible;
    }

    public void on_workspace_ai_panel_toggled(bool visible) {
        on_workspace_ai_panel_toggled_calls++;
        calls++;
        call_log.add("on_workspace_ai_panel_toggled");
        last_on_workspace_ai_panel_toggled_visible = visible;
    }

    public void on_workspace_toolbox_toggled(bool visible) {
        on_workspace_toolbox_toggled_calls++;
        calls++;
        call_log.add("on_workspace_toolbox_toggled");
        last_on_workspace_toolbox_toggled_visible = visible;
    }

    public void on_workspace_open_debug_panel_requested() {
        on_workspace_open_debug_panel_requested_calls++;
        calls++;
        call_log.add("on_workspace_open_debug_panel_requested");
    }

    public void on_workspace_search_activated() {
        on_workspace_search_activated_calls++;
        calls++;
        call_log.add("on_workspace_search_activated");
    }

    public void on_workspace_search_changed() {
        on_workspace_search_changed_calls++;
        calls++;
        call_log.add("on_workspace_search_changed");
    }

    public void on_workspace_search_cleared() {
        on_workspace_search_cleared_calls++;
        calls++;
        call_log.add("on_workspace_search_cleared");
    }

    public void on_workspace_search_focus_results_requested() {
        on_workspace_search_focus_results_requested_calls++;
        calls++;
        call_log.add("on_workspace_search_focus_results_requested");
    }

    public void on_workspace_search_result_activated(uint position) {
        on_workspace_search_result_activated_calls++;
        calls++;
        call_log.add("on_workspace_search_result_activated");
        last_on_workspace_search_result_activated_position = position;
    }

    public void on_workspace_find_next_requested() {
        on_workspace_find_next_requested_calls++;
        calls++;
        call_log.add("on_workspace_find_next_requested");
    }

    public void on_workspace_replace_requested() {
        on_workspace_replace_requested_calls++;
        calls++;
        call_log.add("on_workspace_replace_requested");
    }

    public void on_workspace_replace_all_requested() {
        on_workspace_replace_all_requested_calls++;
        calls++;
        call_log.add("on_workspace_replace_all_requested");
    }

    public void on_project_selection_changed() {
        on_project_selection_changed_calls++;
        calls++;
        call_log.add("on_project_selection_changed");
    }

    public void on_card_selection_changed() {
        on_card_selection_changed_calls++;
        calls++;
        call_log.add("on_card_selection_changed");
    }

    public void on_ai_thread_selection_changed() {
        on_ai_thread_selection_changed_calls++;
        calls++;
        call_log.add("on_ai_thread_selection_changed");
    }

    public void on_editor_buffer_changed() {
        on_editor_buffer_changed_calls++;
        calls++;
        call_log.add("on_editor_buffer_changed");
    }

    public void on_internal_link_click_pressed(Gtk.GestureClick gesture, int n_press, double x, double y) {
        on_internal_link_click_pressed_calls++;
        calls++;
        call_log.add("on_internal_link_click_pressed");
        last_on_internal_link_click_pressed_gesture = gesture;
        last_on_internal_link_click_pressed_n_press = n_press;
        last_on_internal_link_click_pressed_x = x;
        last_on_internal_link_click_pressed_y = y;
    }

    public bool on_internal_link_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state) {
        on_internal_link_key_pressed_calls++;
        calls++;
        call_log.add("on_internal_link_key_pressed");
        last_on_internal_link_key_pressed_keyval = keyval;
        last_on_internal_link_key_pressed_keycode = keycode;
        return on_internal_link_key_pressed_result;
    }

    public void on_card_store_items_changed(uint position, uint removed, uint added) {
        on_card_store_items_changed_calls++;
        calls++;
        call_log.add("on_card_store_items_changed");
        last_on_card_store_items_changed_position = position;
        last_on_card_store_items_changed_removed = removed;
        last_on_card_store_items_changed_added = added;
    }

    public void on_flowboard_project_overview_requested(string project_id) {
        on_flowboard_project_overview_requested_calls++;
        calls++;
        call_log.add("on_flowboard_project_overview_requested");
        last_on_flowboard_project_overview_requested_project_id = project_id;
    }

    public void on_flowboard_context_load_requested(string project_id, string? parent_card_id) {
        on_flowboard_context_load_requested_calls++;
        calls++;
        call_log.add("on_flowboard_context_load_requested");
        last_on_flowboard_context_load_requested_project_id = project_id;
        last_on_flowboard_context_load_requested_parent_card_id = parent_card_id;
    }

    public void on_project_create_error_reported(string title_text, string details) {
        on_project_create_error_reported_calls++;
        calls++;
        call_log.add("on_project_create_error_reported");
        last_on_project_create_error_reported_title_text = title_text;
        last_on_project_create_error_reported_details = details;
    }

    public bool on_window_close_requested() {
        on_window_close_requested_calls++;
        calls++;
        call_log.add("on_window_close_requested");
        return on_window_close_requested_result;
    }

    public void on_root_paned_position_changed(int position) {
        on_root_paned_position_changed_calls++;
        calls++;
        call_log.add("on_root_paned_position_changed");
        last_on_root_paned_position_changed_position = position;
    }

    public void on_app_state_changed() {
        on_app_state_changed_calls++;
        calls++;
        call_log.add("on_app_state_changed");
    }

    public void on_navigation_loading_changed(bool loading) {
        on_navigation_loading_changed_calls++;
        calls++;
        call_log.add("on_navigation_loading_changed");
        last_on_navigation_loading_changed_loading = loading;
    }

}

}

namespace HolderLinuxTests {

private Gtk.GestureClick make_gesture_click() {
    return new Gtk.GestureClick();
}

private void test_main_controller_signal_sink_forwards_every_event() {
    var mw = new HolderLinux.MainWindow();
    var sink = new HolderLinux.WindowMainControllerSignalSink(mw);

    sink.on_status_changed("status-text");
    assert(mw.set_status_calls == 1);
    assert(mw.last_set_status_text == "status-text");
    assert(mw.log_status_activity_calls == 1);
    assert(mw.last_log_status_activity_text == "status-text");

    sink.on_editor_state_changed("body", true);
    assert(mw.set_editor_state_calls == 1);
    assert(mw.last_set_editor_state_text == "body");
    assert(mw.last_set_editor_state_editable);

    var occurrences = new HolderLinux.CardTagOccurrence[] {
        new HolderLinux.CardTagOccurrence("todo", 0, 4)
    };
    sink.on_validated_tag_occurrences_changed(occurrences);
    assert(mw.set_validated_tag_occurrences_calls == 1);
    assert(mw.last_set_validated_tag_occurrences_occurrences != null);
    assert(((!) mw.last_set_validated_tag_occurrences_occurrences).length == 1);
    assert(((!) mw.last_set_validated_tag_occurrences_occurrences)[0] == occurrences[0]);

    sink.on_editor_save_state_changed("Saved");
    assert(mw.set_editor_save_state_text_calls == 1);
    assert(mw.last_set_editor_save_state_text_text == "Saved");

    sink.on_card_durable_save_completed("p1", "c1", 42);
    assert(mw.refresh_milestones_after_card_save_calls == 1);
    assert(mw.refresh_history_after_card_save_calls == 1);
    assert(mw.last_refresh_history_after_card_save_project_id == "p1");
    assert(mw.last_refresh_history_after_card_save_card_id == "c1");

    sink.on_window_title_changed("My Card");
    assert(mw.update_window_title_calls == 1);
    assert(mw.last_update_window_title_title_text == "My Card");

    sink.on_toast_requested("Saved.");
    assert(mw.add_toast_calls == 1);
    assert(mw.last_add_toast_msg == "Saved.");
    assert(mw.log_toast_activity_calls == 1);
    assert(mw.last_log_toast_activity_message == "Saved.");

    sink.on_error_reported("Bad", "Broken");
    assert(mw.show_error_calls == 1);
    assert(mw.last_show_error_title_text == "Bad");
    assert(mw.last_show_error_details == "Broken");
    assert(mw.log_error_activity_calls == 1);
    assert(mw.last_log_error_activity_title_text == "Bad");
    assert(mw.last_log_error_activity_details == "Broken");

    sink.on_show_editor_requested();
    assert(mw.show_editor_mode_calls == 1);

    sink.on_show_search_requested();
    assert(mw.show_search_mode_calls == 1);

    sink.on_search_summary_changed("3 of 5");
    assert(mw.set_search_summary_text_calls == 1);
    assert(mw.last_set_search_summary_text_text == "3 of 5");

    sink.on_ai_status_refresh_requested();
    assert(mw.refresh_ai_status_calls == 1);

    sink.on_project_selection_requested("p2");
    assert(mw.request_project_selection_calls == 1);
    assert(mw.last_request_project_selection_project_id == "p2");

    sink.on_card_selection_requested("c2");
    assert(mw.request_card_selection_calls == 1);
    assert(mw.last_request_card_selection_card_id == "c2");

    sink.on_search_selection_requested(7);
    assert(mw.request_search_selection_calls == 1);
    assert(mw.last_request_search_selection_position == 7);

    sink.on_ai_thread_title_changed("Thread A");
    assert(mw.set_ai_thread_title_calls == 1);
    assert(mw.last_set_ai_thread_title_title_text == "Thread A");

    sink.on_ai_thread_selection_requested("t1");
    assert(mw.request_ai_thread_selection_calls == 1);
    assert(mw.last_request_ai_thread_selection_thread_id == "t1");

    var api = new HolderLinuxTests.MainControllerFakeApi();
    sink.on_api_client_ready(api);
    assert(mw.on_api_client_connected_calls == 1);
    assert(mw.last_on_api_client_connected_api_client == api);

    sink.on_card_trashed("c3");
    assert(mw.refresh_trash_tool_calls == 1);

    var details = new HolderLinux.CardRenamedDetails("Old", "New", false);
    sink.on_activity_requested("kind.x", "msg", "p1", "c1", details);
    assert(mw.log_activity_calls == 1);
    assert(mw.last_log_activity_kind == "kind.x");
    assert(mw.last_log_activity_message == "msg");
    assert(mw.last_log_activity_project_id == "p1");
    assert(mw.last_log_activity_card_id == "c1");
    assert(mw.last_log_activity_details == details);
}

private void test_main_controller_signal_source_forwards_every_signal() {
    var mc = new HolderLinux.MainController();
    var src = new HolderLinux.WindowMainControllerSignalSource(mc);

    string last_status = "";
    src.status_changed.connect((text) => { last_status = text; });
    mc.status_changed("hello");
    assert(last_status == "hello");

    string editor_text = "";
    bool editor_editable = false;
    src.editor_state_changed.connect((text, editable) => { editor_text = text; editor_editable = editable; });
    mc.editor_state_changed("body", true);
    assert(editor_text == "body");
    assert(editor_editable);

    HolderLinux.CardTagOccurrence[]? occurrences_seen = null;
    src.validated_tag_occurrences_changed.connect((o) => { occurrences_seen = o; });
    var occurrences = new HolderLinux.CardTagOccurrence[] {
        new HolderLinux.CardTagOccurrence("todo", 0, 4)
    };
    mc.validated_tag_occurrences_changed(occurrences);
    assert(occurrences_seen != null);
    assert(((!) occurrences_seen).length == 1);
    assert(((!) occurrences_seen)[0] == occurrences[0]);

    string save_state_text = "";
    src.editor_save_state_changed.connect((text) => { save_state_text = text; });
    mc.editor_save_state_changed("Saved");
    assert(save_state_text == "Saved");

    string save_project_id = "";
    string save_card_id = "";
    int64 save_updated_at = 0;
    src.card_durable_save_completed.connect((p, c, u) => {
        save_project_id = p; save_card_id = c; save_updated_at = u;
    });
    mc.card_durable_save_completed("p1", "c1", 99);
    assert(save_project_id == "p1");
    assert(save_card_id == "c1");
    assert(save_updated_at == 99);

    string title_text = "";
    src.window_title_changed.connect((t) => { title_text = t; });
    mc.window_title_changed("My Card");
    assert(title_text == "My Card");

    string toast_text = "";
    src.toast_requested.connect((m) => { toast_text = m; });
    mc.toast_requested("Saved.");
    assert(toast_text == "Saved.");

    string error_title = "";
    string error_details = "";
    src.error_reported.connect((t, d) => { error_title = t; error_details = d; });
    mc.error_reported("Bad", "Broken");
    assert(error_title == "Bad");
    assert(error_details == "Broken");

    int show_editor_calls = 0;
    src.show_editor_requested.connect(() => { show_editor_calls++; });
    mc.show_editor_requested();
    assert(show_editor_calls == 1);

    int show_search_calls = 0;
    src.show_search_requested.connect(() => { show_search_calls++; });
    mc.show_search_requested();
    assert(show_search_calls == 1);

    string search_summary = "";
    src.search_summary_changed.connect((t) => { search_summary = t; });
    mc.search_summary_changed("3 of 5");
    assert(search_summary == "3 of 5");

    int ai_status_calls = 0;
    src.ai_status_refresh_requested.connect(() => { ai_status_calls++; });
    mc.ai_status_refresh_requested();
    assert(ai_status_calls == 1);

    string? project_selection_id = "unset";
    src.project_selection_requested.connect((id) => { project_selection_id = id; });
    mc.project_selection_requested("p2");
    assert(project_selection_id == "p2");

    string? card_selection_id = "unset";
    src.card_selection_requested.connect((id) => { card_selection_id = id; });
    mc.card_selection_requested("c2");
    assert(card_selection_id == "c2");

    int search_selection_position = -1;
    src.search_selection_requested.connect((p) => { search_selection_position = p; });
    mc.search_selection_requested(7);
    assert(search_selection_position == 7);

    string? ai_thread_title = "unset";
    src.ai_thread_title_changed.connect((t) => { ai_thread_title = t; });
    mc.ai_thread_title_changed("Thread A");
    assert(ai_thread_title == "Thread A");

    string? ai_thread_selection_id = "unset";
    src.ai_thread_selection_requested.connect((id) => { ai_thread_selection_id = id; });
    mc.ai_thread_selection_requested("t1");
    assert(ai_thread_selection_id == "t1");

    HolderLinux.IHolderApi? seen_api = null;
    src.api_client_ready.connect((api) => { seen_api = api; });
    var fake_api = new HolderLinuxTests.MainControllerFakeApi();
    mc.api_client_ready(fake_api);
    assert(seen_api == fake_api);

    string trashed_card_id = "";
    src.card_trashed.connect((id) => { trashed_card_id = id; });
    mc.card_trashed("c3");
    assert(trashed_card_id == "c3");

    string activity_kind = "";
    src.activity_requested.connect((kind, message, project_id, card_id, details) => {
        activity_kind = kind;
    });
    mc.activity_requested("kind.x", "msg", "p1", "c1", null);
    assert(activity_kind == "kind.x");
}

private void test_ai_panel_event_sink_forwards_and_restores_trashed_cards() {
    var mw = new HolderLinux.MainWindow();
    var sink = new HolderLinux.WindowAiPanelEventSink(mw);

    sink.set_status("Thinking...");
    assert(mw.set_status_calls == 1);
    assert(mw.last_set_status_text == "Thinking...");

    sink.show_error("Bad", "Broken");
    assert(mw.show_error_calls == 1);

    sink.add_toast("Done.");
    assert(mw.add_toast_calls == 1);
    assert(mw.last_add_toast_msg == "Done.");

    sink.log_debug("debug line");
    assert(mw.log_debug_line_calls == 1);
    assert(mw.last_log_debug_line_message == "debug line");

    // A non-restore activity must not trigger the trash-item refresh.
    sink.log_activity("other.kind", "msg", "p1", "c1", null);
    assert(mw.log_activity_calls == 1);
    assert(mw.on_trash_item_restored_calls == 0);

    // The restore activity kind (see TrashController.ACTIVITY_KIND_RESTORED) must trigger it, with
    // the same card id, and it runs from an async call so give it a turn to complete.
    sink.log_activity(HolderLinux.TrashController.ACTIVITY_KIND_RESTORED, "restored", "p1", "c9", null);
    assert(mw.log_activity_calls == 2);
    assert(wait_for_condition(() => mw.on_trash_item_restored_calls == 1));
    assert(mw.last_on_trash_item_restored_card_id == "c9");
}

private void test_toolbox_event_sink_forwards_every_event() {
    var mw = new HolderLinux.MainWindow();
    var sink = new HolderLinux.WindowToolboxEventSink(mw);

    sink.show_error("Bad", "Broken");
    assert(mw.show_error_calls == 1);

    sink.add_toast("Done.");
    assert(mw.add_toast_calls == 1);

    sink.show_tool_help_page("history");
    assert(mw.show_tool_help_page_calls == 1);
    assert(mw.last_show_tool_help_page_tool_id == "history");

    sink.confirm_move_card_to_trash("c1");
    assert(mw.confirm_move_card_to_trash_calls == 1);
    assert(mw.last_confirm_move_card_to_trash_card_id == "c1");

    sink.reload_card_after_history_restore("c2");
    assert(mw.reload_card_after_history_restore_calls == 1);
    assert(mw.last_reload_card_after_history_restore_card_id == "c2");

    sink.select_ai_thread_from_history("t1");
    assert(mw.select_ai_thread_from_history_calls == 1);
    assert(mw.last_select_ai_thread_from_history_thread_id == "t1");

    sink.send_current_card_as_email();
    assert(mw.send_current_card_as_email_calls == 1);

    sink.request_send_recovery_key_as_email();
    assert(mw.request_send_recovery_key_as_email_calls == 1);

    sink.request_save_recovery_key_to_usb();
    assert(mw.request_save_recovery_key_to_usb_calls == 1);

    sink.request_import_recovery_key();
    assert(mw.request_import_recovery_key_calls == 1);

    sink.append_text_to_current_card("more text");
    assert(mw.append_text_to_current_card_calls == 1);
    assert(mw.last_append_text_to_current_card_text == "more text");

    sink.log_activity("kind.x", "msg", "p1", "c1", null);
    assert(mw.log_activity_calls == 1);
}

private void test_toolbox_event_source_forwards_every_signal() {
    var toolbox = new HolderLinux.ToolboxPane();
    var src = new HolderLinux.WindowToolboxEventSource(toolbox);

    string error_title = "";
    src.error_reported.connect((t, d) => { error_title = t; });
    toolbox.error_reported("Bad", "Broken");
    assert(error_title == "Bad");

    string toast = "";
    src.toast_requested.connect((m) => { toast = m; });
    toolbox.toast_requested("Done.");
    assert(toast == "Done.");

    string bc_tool = "";
    int bc_index = -1;
    src.breadcrumb_navigation_requested.connect((tool_id, idx, p, c) => { bc_tool = tool_id; bc_index = idx; });
    toolbox.breadcrumb_navigation_requested("history", 2, "p1", "c1");
    assert(bc_tool == "history");
    assert(bc_index == 2);

    string flowboard_open = "";
    src.flowboard_card_open_requested.connect((id) => { flowboard_open = id; });
    toolbox.flowboard_card_open_requested("c1");
    assert(flowboard_open == "c1");

    string connections_open = "";
    src.connections_card_open_requested.connect((id) => { connections_open = id; });
    toolbox.connections_card_open_requested("c2");
    assert(connections_open == "c2");

    string tags_open = "";
    src.tags_card_open_requested.connect((id) => { tags_open = id; });
    toolbox.tags_card_open_requested("c3");
    assert(tags_open == "c3");

    string resources_open = "";
    src.resources_card_open_requested.connect((id) => { resources_open = id; });
    toolbox.resources_card_open_requested("c4");
    assert(resources_open == "c4");

    string milestones_open = "";
    src.milestones_card_open_requested.connect((id) => { milestones_open = id; });
    toolbox.milestones_card_open_requested("c5");
    assert(milestones_open == "c5");

    HolderLinux.ProjectResource? resource_seen = null;
    src.resource_references_requested.connect((r) => { resource_seen = r; });
    var resource = new HolderLinux.ProjectResource("r1", "p1", "image", "", "Res", null, 1, 2);
    toolbox.resource_references_requested(resource);
    assert(resource_seen == resource);

    string create_child = "";
    src.connections_card_create_child_requested.connect((id) => { create_child = id; });
    toolbox.connections_card_create_child_requested("c6");
    assert(create_child == "c6");

    string move_to_trash = "";
    src.flowboard_card_move_to_trash_requested.connect((id) => { move_to_trash = id; });
    toolbox.flowboard_card_move_to_trash_requested("c7");
    assert(move_to_trash == "c7");

    string move_card = "";
    string move_project = "";
    string move_intent = "";
    src.flowboard_move_intent_requested.connect((card_id, project_id, intent, target, parent) => {
        move_card = card_id; move_project = project_id; move_intent = intent;
    });
    toolbox.flowboard_move_intent_requested("c8", "p1", "before", "c9", "c10");
    assert(move_card == "c8");
    assert(move_project == "p1");
    assert(move_intent == "before");

    string? new_card_parent = "unset";
    src.flowboard_new_card_requested.connect((parent) => { new_card_parent = parent; });
    toolbox.flowboard_new_card_requested("c11");
    assert(new_card_parent == "c11");

    string copy_title = "";
    string copy_content = "";
    src.history_copy_as_card_requested.connect((title, content) => { copy_title = title; copy_content = content; });
    toolbox.history_copy_as_card_requested("Title", "Content");
    assert(copy_title == "Title");
    assert(copy_content == "Content");

    // The project id is dropped: the interface's own event only carries the card id.
    string restore_card = "";
    src.history_restore_succeeded.connect((id) => { restore_card = id; });
    toolbox.history_restore_succeeded("p1", "c12");
    assert(restore_card == "c12");

    string history_open = "";
    src.history_card_open_requested.connect((id) => { history_open = id; });
    toolbox.history_card_open_requested("c13");
    assert(history_open == "c13");

    string history_thread_open = "";
    src.history_ai_thread_open_requested.connect((id) => { history_thread_open = id; });
    toolbox.history_ai_thread_open_requested("t1");
    assert(history_thread_open == "t1");

    int send_email_calls = 0;
    src.send_card_as_email_requested.connect(() => { send_email_calls++; });
    toolbox.send_card_as_email_requested();
    assert(send_email_calls == 1);

    int send_recovery_calls = 0;
    src.send_recovery_key_as_email_requested.connect(() => { send_recovery_calls++; });
    toolbox.send_recovery_key_as_email_requested();
    assert(send_recovery_calls == 1);

    int save_recovery_calls = 0;
    src.save_recovery_key_to_usb_requested.connect(() => { save_recovery_calls++; });
    toolbox.save_recovery_key_to_usb_requested();
    assert(save_recovery_calls == 1);

    int import_recovery_calls = 0;
    src.import_recovery_key_requested.connect(() => { import_recovery_calls++; });
    toolbox.import_recovery_key_requested();
    assert(import_recovery_calls == 1);

    string terminal_copy_text = "";
    src.terminal_copy_to_card_requested.connect((t) => { terminal_copy_text = t; });
    toolbox.terminal_copy_to_card_requested("copied");
    assert(terminal_copy_text == "copied");

    string activity_kind = "";
    src.activity_requested.connect((kind, message, project_id, card_id, details) => { activity_kind = kind; });
    toolbox.activity_requested("kind.x", "msg", "p1", "c1", null);
    assert(activity_kind == "kind.x");
}

private void test_window_feedback_sink_forwards_toast_and_error() {
    var mw = new HolderLinux.MainWindow();
    var sink = new HolderLinux.WindowFeedbackSink(mw);

    sink.add_toast("Done.");
    assert(mw.add_toast_calls == 1);
    assert(mw.last_add_toast_msg == "Done.");

    sink.show_error("Bad", "Broken");
    assert(mw.show_error_calls == 1);
    assert(mw.last_show_error_title_text == "Bad");
    assert(mw.last_show_error_details == "Broken");
}

private void test_window_action_sink_forwards_every_action() {
    var mw = new HolderLinux.MainWindow();
    var sink = new HolderLinux.WindowActionSink(mw);

    sink.on_refresh_requested();
    assert(mw.handle_refresh_action_calls == 1);

    sink.on_save_requested();
    assert(mw.handle_save_action_calls == 1);

    sink.on_new_project_requested();
    assert(mw.handle_new_project_action_calls == 1);

    sink.on_new_card_requested();
    assert(mw.handle_new_card_action_calls == 1);

    sink.on_flowboard_new_child_card_requested();
    assert(mw.handle_flowboard_new_child_card_action_calls == 1);

    sink.on_move_selected_card_to_trash_requested();
    assert(mw.handle_move_selected_card_to_trash_action_calls == 1);

    sink.on_toggle_toolbox_requested();
    assert(mw.handle_toggle_toolbox_action_calls == 1);

    sink.on_find_replace_requested();
    assert(mw.handle_find_replace_action_calls == 1);

    sink.on_print_requested();
    assert(mw.handle_print_action_calls == 1);

    sink.on_show_local_info_requested();
    assert(mw.handle_show_local_info_action_calls == 1);

    sink.on_show_preferences_requested();
    assert(mw.handle_show_preferences_action_calls == 1);

    sink.on_show_about_requested();
    assert(mw.handle_show_about_action_calls == 1);
}

private void test_sidebar_event_sink_forwards_every_event() {
    var mw = new HolderLinux.MainWindow();
    var sink = new HolderLinux.WindowSidebarEventSink(mw);

    sink.on_sidebar_card_move_to_trash_requested("c1");
    assert(mw.on_sidebar_card_move_to_trash_requested_calls == 1);
    assert(mw.last_on_sidebar_card_move_to_trash_requested_card_id == "c1");

    sink.on_sidebar_card_context_selection_requested("c2");
    assert(mw.on_sidebar_card_context_selection_requested_calls == 1);
    assert(mw.last_on_sidebar_card_context_selection_requested_card_id == "c2");

    sink.on_sidebar_card_create_child_requested("c3");
    assert(mw.on_sidebar_card_create_child_requested_calls == 1);
    assert(mw.last_on_sidebar_card_create_child_requested_card_id == "c3");
}

private void test_sidebar_event_source_forwards_every_signal() {
    var sidebar = new HolderLinux.SidebarPane();
    var src = new HolderLinux.WindowSidebarEventSource(sidebar);

    string trash_id = "";
    src.card_move_to_trash_requested.connect((id) => { trash_id = id; });
    sidebar.card_move_to_trash_requested("c1");
    assert(trash_id == "c1");

    string context_id = "";
    src.card_context_selection_requested.connect((id) => { context_id = id; });
    sidebar.card_context_selection_requested("c2");
    assert(context_id == "c2");

    string child_id = "";
    src.card_create_child_requested.connect((id) => { child_id = id; });
    sidebar.card_create_child_requested("c3");
    assert(child_id == "c3");
}

private void test_workspace_event_sink_forwards_every_event() {
    var mw = new HolderLinux.MainWindow();
    var sink = new HolderLinux.WindowWorkspaceEventSink(mw);

    sink.on_workspace_refresh_requested();
    assert(mw.on_workspace_refresh_requested_calls == 1);

    sink.on_workspace_new_project_requested();
    assert(mw.on_workspace_new_project_requested_calls == 1);

    sink.on_workspace_new_card_requested();
    assert(mw.on_workspace_new_card_requested_calls == 1);

    sink.on_workspace_explorer_panel_toggled(true);
    assert(mw.on_workspace_explorer_panel_toggled_calls == 1);
    assert(mw.last_on_workspace_explorer_panel_toggled_visible);

    sink.on_workspace_ai_panel_toggled(true);
    assert(mw.on_workspace_ai_panel_toggled_calls == 1);

    sink.on_workspace_toolbox_toggled(true);
    assert(mw.on_workspace_toolbox_toggled_calls == 1);

    sink.on_workspace_open_debug_panel_requested();
    assert(mw.on_workspace_open_debug_panel_requested_calls == 1);

    sink.on_workspace_search_activated();
    assert(mw.on_workspace_search_activated_calls == 1);

    sink.on_workspace_search_changed();
    assert(mw.on_workspace_search_changed_calls == 1);

    sink.on_workspace_search_cleared();
    assert(mw.on_workspace_search_cleared_calls == 1);

    sink.on_workspace_search_focus_results_requested();
    assert(mw.on_workspace_search_focus_results_requested_calls == 1);

    sink.on_workspace_search_result_activated(5);
    assert(mw.on_workspace_search_result_activated_calls == 1);
    assert(mw.last_on_workspace_search_result_activated_position == 5);

    sink.on_workspace_find_next_requested();
    assert(mw.on_workspace_find_next_requested_calls == 1);

    sink.on_workspace_replace_requested();
    assert(mw.on_workspace_replace_requested_calls == 1);

    sink.on_workspace_replace_all_requested();
    assert(mw.on_workspace_replace_all_requested_calls == 1);
}

private void test_workspace_event_source_forwards_every_signal() {
    var workspace = new HolderLinux.WorkspacePane();
    var src = new HolderLinux.WindowWorkspaceEventSource(workspace);

    int refresh_calls = 0;
    src.refresh_requested.connect(() => { refresh_calls++; });
    workspace.refresh_requested();
    assert(refresh_calls == 1);

    int new_project_calls = 0;
    src.new_project_requested.connect(() => { new_project_calls++; });
    workspace.new_project_requested();
    assert(new_project_calls == 1);

    int new_card_calls = 0;
    src.new_card_requested.connect(() => { new_card_calls++; });
    workspace.new_card_requested();
    assert(new_card_calls == 1);

    bool explorer_visible = false;
    src.explorer_panel_toggled.connect((v) => { explorer_visible = v; });
    workspace.explorer_panel_toggled(true);
    assert(explorer_visible);

    bool ai_visible = false;
    src.ai_panel_toggled.connect((v) => { ai_visible = v; });
    workspace.ai_panel_toggled(true);
    assert(ai_visible);

    bool toolbox_visible = false;
    src.toolbox_toggled.connect((v) => { toolbox_visible = v; });
    workspace.toolbox_toggled(true);
    assert(toolbox_visible);

    int debug_panel_calls = 0;
    src.open_debug_panel_requested.connect(() => { debug_panel_calls++; });
    workspace.open_debug_panel_requested();
    assert(debug_panel_calls == 1);

    int search_activated_calls = 0;
    src.search_activated.connect(() => { search_activated_calls++; });
    workspace.search_activated();
    assert(search_activated_calls == 1);

    int search_changed_calls = 0;
    src.search_changed.connect(() => { search_changed_calls++; });
    workspace.search_changed();
    assert(search_changed_calls == 1);

    int search_cleared_calls = 0;
    src.search_cleared.connect(() => { search_cleared_calls++; });
    workspace.search_cleared();
    assert(search_cleared_calls == 1);

    int search_focus_calls = 0;
    src.search_focus_results_requested.connect(() => { search_focus_calls++; });
    workspace.search_focus_results_requested();
    assert(search_focus_calls == 1);

    uint search_result_position = 0;
    src.search_result_activated.connect((p) => { search_result_position = p; });
    workspace.search_result_activated(9);
    assert(search_result_position == 9);

    int find_next_calls = 0;
    src.find_next_requested.connect(() => { find_next_calls++; });
    workspace.find_next_requested();
    assert(find_next_calls == 1);

    int replace_calls = 0;
    src.replace_requested.connect(() => { replace_calls++; });
    workspace.replace_requested();
    assert(replace_calls == 1);

    int replace_all_calls = 0;
    src.replace_all_requested.connect(() => { replace_all_calls++; });
    workspace.replace_all_requested();
    assert(replace_all_calls == 1);
}

private void test_selection_editor_event_sink_forwards_every_event() {
    var mw = new HolderLinux.MainWindow();
    var sink = new HolderLinux.WindowSelectionEditorEventSink(mw);

    sink.on_project_selection_changed();
    assert(mw.on_project_selection_changed_calls == 1);

    sink.on_card_selection_changed();
    assert(mw.on_card_selection_changed_calls == 1);

    sink.on_ai_thread_selection_changed();
    assert(mw.on_ai_thread_selection_changed_calls == 1);

    sink.on_editor_buffer_changed();
    assert(mw.on_editor_buffer_changed_calls == 1);

    var gesture = make_gesture_click();
    sink.on_internal_link_click_pressed(gesture, 1, 12.5, 33.0);
    assert(mw.on_internal_link_click_pressed_calls == 1);
    assert(mw.last_on_internal_link_click_pressed_gesture == gesture);
    assert(mw.last_on_internal_link_click_pressed_n_press == 1);
    assert(mw.last_on_internal_link_click_pressed_x == 12.5);
    assert(mw.last_on_internal_link_click_pressed_y == 33.0);

    // The return value comes back from the window, unchanged.
    mw.on_internal_link_key_pressed_result = true;
    var handled = sink.on_internal_link_key_pressed(Gdk.Key.Return, 13, Gdk.ModifierType.CONTROL_MASK);
    assert(handled);
    assert(mw.on_internal_link_key_pressed_calls == 1);
    assert(mw.last_on_internal_link_key_pressed_keyval == Gdk.Key.Return);

    mw.on_internal_link_key_pressed_result = false;
    var not_handled = sink.on_internal_link_key_pressed(Gdk.Key.a, 0, 0);
    assert(!not_handled);
}

private void test_flowboard_event_sink_forwards_every_event() {
    var mw = new HolderLinux.MainWindow();
    var sink = new HolderLinux.WindowFlowboardEventSink(mw);

    sink.on_card_store_items_changed(2, 1, 3);
    assert(mw.on_card_store_items_changed_calls == 1);
    assert(mw.last_on_card_store_items_changed_position == 2);
    assert(mw.last_on_card_store_items_changed_removed == 1);
    assert(mw.last_on_card_store_items_changed_added == 3);

    sink.on_flowboard_project_overview_requested("p1");
    assert(mw.on_flowboard_project_overview_requested_calls == 1);
    assert(mw.last_on_flowboard_project_overview_requested_project_id == "p1");

    sink.on_flowboard_context_load_requested("p1", "c1");
    assert(mw.on_flowboard_context_load_requested_calls == 1);
    assert(mw.last_on_flowboard_context_load_requested_project_id == "p1");
    assert(mw.last_on_flowboard_context_load_requested_parent_card_id == "c1");
}

private void test_lifecycle_event_sink_forwards_every_event() {
    var mw = new HolderLinux.MainWindow();
    var sink = new HolderLinux.WindowLifecycleEventSink(mw);

    sink.on_project_create_error_reported("Bad", "Broken");
    assert(mw.on_project_create_error_reported_calls == 1);
    assert(mw.last_on_project_create_error_reported_title_text == "Bad");
    assert(mw.last_on_project_create_error_reported_details == "Broken");

    mw.on_window_close_requested_result = true;
    var allow_close = sink.on_window_close_requested();
    assert(allow_close);
    assert(mw.on_window_close_requested_calls == 1);

    mw.on_window_close_requested_result = false;
    var block_close = sink.on_window_close_requested();
    assert(!block_close);
}

private void test_state_event_sink_forwards_every_event() {
    var mw = new HolderLinux.MainWindow();
    var sink = new HolderLinux.WindowStateEventSink(mw);

    sink.on_root_paned_position_changed(240);
    assert(mw.on_root_paned_position_changed_calls == 1);
    assert(mw.last_on_root_paned_position_changed_position == 240);

    sink.on_app_state_changed();
    assert(mw.on_app_state_changed_calls == 1);

    sink.on_navigation_loading_changed(true);
    assert(mw.on_navigation_loading_changed_calls == 1);
    assert(mw.last_on_navigation_loading_changed_loading);
}

private void test_local_info_logger_forwards_to_toolbox() {
    var toolbox = new HolderLinux.ToolboxPane();
    var logger = new HolderLinux.WindowLocalInfoLogger(toolbox);

    logger.log_debug("info line");

    assert(toolbox.log_debug_calls == 1);
    assert(toolbox.last_log_debug_message == "info line");
}

private void test_local_info_flow_context_forwards_to_main_controller() {
    var mc = new HolderLinux.MainController();
    var context = new HolderLinux.WindowLocalInfoFlowContext(mc);

    assert(context.get_api_client() == null);

    mc.api_client = new HolderLinuxTests.MainControllerFakeApi();
    assert(context.get_api_client() == mc.api_client);
}

private void test_local_info_view_sink_forwards_every_event() {
    var mw = new HolderLinux.MainWindow();
    var sink = new HolderLinux.WindowLocalInfoViewSink(mw);

    sink.set_editor_state("body", true);
    assert(mw.set_editor_state_calls == 1);
    assert(mw.last_set_editor_state_text == "body");
    assert(mw.last_set_editor_state_editable);

    sink.show_editor_mode();
    assert(mw.show_editor_mode_calls == 1);

    sink.update_window_title("Local Info");
    assert(mw.update_window_title_calls == 1);
    assert(mw.last_update_window_title_title_text == "Local Info");

    sink.set_status("Ready");
    assert(mw.set_status_calls == 1);
    assert(mw.last_set_status_text == "Ready");

    sink.show_error("Bad", "Broken");
    assert(mw.show_error_calls == 1);
    assert(mw.last_show_error_title_text == "Bad");
    assert(mw.last_show_error_details == "Broken");
}

public static int main(string[] args) {
    Test.init(ref args);

    var prefix = "/holder/window-event-endpoints/";
    Test.add_func(prefix + "main-controller-signal-sink-forwards-every-event",
                  test_main_controller_signal_sink_forwards_every_event);
    Test.add_func(prefix + "main-controller-signal-source-forwards-every-signal",
                  test_main_controller_signal_source_forwards_every_signal);
    Test.add_func(prefix + "ai-panel-event-sink-forwards-and-restores-trashed-cards",
                  test_ai_panel_event_sink_forwards_and_restores_trashed_cards);
    Test.add_func(prefix + "toolbox-event-sink-forwards-every-event",
                  test_toolbox_event_sink_forwards_every_event);
    Test.add_func(prefix + "toolbox-event-source-forwards-every-signal",
                  test_toolbox_event_source_forwards_every_signal);
    Test.add_func(prefix + "window-feedback-sink-forwards-toast-and-error",
                  test_window_feedback_sink_forwards_toast_and_error);
    Test.add_func(prefix + "window-action-sink-forwards-every-action",
                  test_window_action_sink_forwards_every_action);
    Test.add_func(prefix + "sidebar-event-sink-forwards-every-event",
                  test_sidebar_event_sink_forwards_every_event);
    Test.add_func(prefix + "sidebar-event-source-forwards-every-signal",
                  test_sidebar_event_source_forwards_every_signal);
    Test.add_func(prefix + "workspace-event-sink-forwards-every-event",
                  test_workspace_event_sink_forwards_every_event);
    Test.add_func(prefix + "workspace-event-source-forwards-every-signal",
                  test_workspace_event_source_forwards_every_signal);
    Test.add_func(prefix + "selection-editor-event-sink-forwards-every-event",
                  test_selection_editor_event_sink_forwards_every_event);
    Test.add_func(prefix + "flowboard-event-sink-forwards-every-event",
                  test_flowboard_event_sink_forwards_every_event);
    Test.add_func(prefix + "lifecycle-event-sink-forwards-every-event",
                  test_lifecycle_event_sink_forwards_every_event);
    Test.add_func(prefix + "state-event-sink-forwards-every-event",
                  test_state_event_sink_forwards_every_event);
    Test.add_func(prefix + "local-info-logger-forwards-to-toolbox",
                  test_local_info_logger_forwards_to_toolbox);
    Test.add_func(prefix + "local-info-flow-context-forwards-to-main-controller",
                  test_local_info_flow_context_forwards_to_main_controller);
    Test.add_func(prefix + "local-info-view-sink-forwards-every-event",
                  test_local_info_view_sink_forwards_every_event);

    return Test.run();
}

}
