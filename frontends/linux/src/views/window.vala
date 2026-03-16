namespace HolderLinux {

private class WindowLocalInfoLogger : Object, ILocalInfoLogger {
    private ToolboxPane toolbox;

    public WindowLocalInfoLogger(ToolboxPane toolbox) {
        this.toolbox = toolbox;
    }

    public void log_debug(string message) {
        toolbox.log_debug(message);
    }
}

private class WindowLocalInfoFlowContext : Object, ILocalInfoFlowContext {
    private MainController owner;

    public WindowLocalInfoFlowContext(MainController owner) {
        this.owner = owner;
    }

    public IHolderApi? get_api_client() {
        return owner.get_api_client();
    }
}

private class WindowLocalInfoViewSink : Object, ILocalInfoViewSink {
    private MainWindow owner;

    public WindowLocalInfoViewSink(MainWindow owner) {
        this.owner = owner;
    }

    public void set_editor_state(string text, bool editable) {
        owner.set_editor_state(text, editable);
    }

    public void show_editor_mode() {
        owner.show_editor_mode();
    }

    public void update_window_title(string title_text) {
        owner.update_window_title(title_text);
    }

    public void set_status(string text) {
        owner.set_status(text);
    }

    public void show_error(string title_text, string details) {
        owner.show_error(title_text, details);
    }
}

private class WindowRecoveryContext : Object, IRecoveryContext {
    private MainController owner;

    public WindowRecoveryContext(MainController owner) {
        this.owner = owner;
    }

    public IHolderApi? get_api_client() {
        return owner.get_api_client();
    }

    public async void reload_everything() {
        yield owner.reload_everything();
    }
}

private class WindowFindReplaceOps : Object, IFindReplaceOps {
    private GtkSource.Buffer editor_buffer;
    private GtkSource.View editor_view;

    public WindowFindReplaceOps(GtkSource.Buffer editor_buffer, GtkSource.View editor_view) {
        this.editor_buffer = editor_buffer;
        this.editor_view = editor_view;
    }

    public bool find_next(string find_text) {
        var context = create_search_context(find_text);
        Gtk.TextIter match_start;
        Gtk.TextIter match_end;
        if (!find_match(context, out match_start, out match_end)) {
            return false;
        }
        editor_buffer.select_range(match_start, match_end);
        editor_view.scroll_to_iter(match_start, 0.1, false, 0, 0);
        return true;
    }

    public bool replace_next(string find_text, string replace_text) throws Error {
        var context = create_search_context(find_text);
        Gtk.TextIter match_start;
        Gtk.TextIter match_end;
        if (!find_match(context, out match_start, out match_end)) {
            return false;
        }
        context.replace(match_start, match_end, replace_text, -1);
        return true;
    }

    public uint replace_all(string find_text, string replace_text) throws Error {
        var context = create_search_context(find_text);
        return context.replace_all(replace_text, -1);
    }

    private GtkSource.SearchContext create_search_context(string find_text) {
        var search_settings = new GtkSource.SearchSettings();
        search_settings.set_case_sensitive(false);
        search_settings.set_regex_enabled(false);
        search_settings.set_wrap_around(true);
        search_settings.set_search_text(find_text);
        return new GtkSource.SearchContext(editor_buffer, search_settings);
    }

    private bool find_match(GtkSource.SearchContext context,
                            out Gtk.TextIter match_start,
                            out Gtk.TextIter match_end) {
        bool has_wrapped = false;
        Gtk.TextIter start_from;
        if (editor_buffer.get_has_selection()) {
            Gtk.TextIter sel_start;
            Gtk.TextIter sel_end;
            editor_buffer.get_selection_bounds(out sel_start, out sel_end);
            start_from = sel_end;
        } else {
            editor_buffer.get_iter_at_mark(out start_from, editor_buffer.get_insert());
        }
        return context.forward(start_from, out match_start, out match_end, out has_wrapped);
    }
}

private class WindowMainControllerSignalSink : Object, IMainControllerSignalSink {
    private MainWindow owner;

    public WindowMainControllerSignalSink(MainWindow owner) {
        this.owner = owner;
    }

    public void on_status_changed(string text) {
        owner.set_status(text);
    }

    public void on_editor_state_changed(string text, bool editable) {
        owner.set_editor_state(text, editable);
    }

    public void on_window_title_changed(string title_text) {
        owner.update_window_title(title_text);
    }

    public void on_toast_requested(string message) {
        owner.add_toast(message);
    }

    public void on_error_reported(string title_text, string details) {
        owner.show_error(title_text, details);
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
}

private class WindowAiPanelEventSink : Object, IAiPanelEventSink {
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
}

private class WindowToolboxEventSink : Object, IToolboxEventSink {
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
}

private class WindowFeedbackSink : Object, IWindowFeedbackSink {
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

private class WindowActionSink : Object, IWindowActionSink {
    private MainWindow owner;

    public WindowActionSink(MainWindow owner) {
        this.owner = owner;
    }

    public void on_refresh_requested() {
        owner.handle_refresh_action();
    }

    public void on_new_project_requested() {
        owner.handle_new_project_action();
    }

    public void on_new_card_requested() {
        owner.handle_new_card_action();
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

private class WindowSidebarEventSink : Object, ISidebarEventSink {
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
}

private class WindowWorkspaceEventSink : Object, IWorkspaceEventSink {
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

private class WindowSelectionEditorEventSink : Object, IWindowSelectionEditorEventSink {
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

private class WindowFlowboardEventSink : Object, IWindowFlowboardEventSink {
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

private class WindowLifecycleEventSink : Object, IWindowLifecycleEventSink {
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

private class WindowStateEventSink : Object, IWindowStateEventSink {
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

public class MainWindow : Adw.ApplicationWindow {
    private delegate void StateApplyFunc();

    private class EditorRenderState : Object {
        public string text = "";
        public bool editable = false;
        public bool show_search = false;
        public string window_title = "Holder";
        public string search_summary = "";
        public string? ai_thread_title = null;
    }

    private const int DEFAULT_WINDOW_WIDTH = 1200;
    private const int DEFAULT_WINDOW_HEIGHT = 800;
    private const int DEFAULT_SIDEBAR_WIDTH = 280;
    private const int MIN_SIDEBAR_WIDTH = 180;
    private const int MAX_SIDEBAR_WIDTH = 700;
    private const int MIN_RESTORE_WIDTH = 690;
    private const int MIN_RESTORE_HEIGHT = 590;
    private const int TINY_CLOSE_STRIKE_LIMIT = 3;

    private Adw.ToastOverlay toast_overlay;

    private GLib.ListStore project_store;
    private Gtk.SingleSelection project_selection;
    private GLib.ListStore card_store;
    private Gtk.SingleSelection card_selection;
    private GLib.ListStore ai_thread_store;
    private Gtk.SingleSelection ai_thread_selection;
    private GLib.ListStore search_store;

    private WorkspacePane workspace;
    private GtkSource.Buffer editor_buffer;
    private GtkSource.View editor_view;
    private Spelling.TextBufferAdapter? spelling_adapter;
    private Gtk.SearchEntry search_entry;
    private Gtk.Label search_summary_label;
    private Gtk.SingleSelection search_selection;
    private Gtk.ListView search_list;
    private SidebarPane sidebar;
    private Gtk.Paned root_paned;
    private AiPanel ai_panel;
    private ToolboxPane toolbox;
    private MainController controller;
    private ProjectCreateController project_create_controller;
    private ExplorerSelectionController explorer_selection_controller;
    private SidebarDataRenderer sidebar_data_renderer;
    private SidebarSelectionRenderer sidebar_selection_renderer;
    private SearchSelectionController search_selection_controller;
    private SelectionRequestController selection_request_controller;
    private SelectionIntentController selection_intent_controller;
    private SelectionIntentOrchestrator selection_intent_orchestrator;
    private SelectionController selection_controller;
    private SelectionTransitionController selection_transition_controller;
    private ToolboxBreadcrumbController toolbox_breadcrumb_controller;
    private ToolboxEventOrchestrator toolbox_event_orchestrator;
    private WindowFeedbackOrchestrator window_feedback_orchestrator;
    private WindowActionBinder window_action_binder;
    private WindowSidebarEventBinder window_sidebar_event_binder;
    private WindowWorkspaceEventBinder window_workspace_event_binder;
    private WindowSelectionEditorEventBinder window_selection_editor_event_binder;
    private WindowFlowboardEventBinder window_flowboard_event_binder;
    private WindowLifecycleEventBinder window_lifecycle_event_binder;
    private WindowStateEventBinder window_state_event_binder;
    private ShareController share_controller;
    private CardAppendController card_append_controller;
    private RecoveryController recovery_controller;
    private RecoveryUiController recovery_ui_controller;
    private RecoveryDialogAdapter recovery_dialog_adapter;
    private InternalLinkController internal_link_controller;
    private LocalInfoController local_info_controller;
    private LocalInfoFlowController local_info_flow_controller;
    private LocalInfoPresenter local_info_presenter;
    private LocalInfoViewAdapter local_info_view_adapter;
    private LocalInfoUiController local_info_ui_controller;
    private WindowActionsAdapter window_actions_adapter;
    private CardActionDialogAdapter card_action_dialog_adapter;
    private ProjectCreateDialogAdapter project_create_dialog_adapter;
    private PrintService print_service;
    private PrintUiController print_ui_controller;
    private AiRunController ai_run_controller;
    private AiPanelEventOrchestrator ai_panel_event_orchestrator;
    private FindReplaceController find_replace_controller;
    private FlowboardController flowboard_controller;
    private FlowboardContextController flowboard_context_controller;
    private ToolHelpController tool_help_controller;
    private AppStateStore app_state_store;
    private AppTransitionController app_transition_controller;
    private MainControllerSignalBinder main_controller_signal_binder;
    private Settings? settings;
    private uint flowboard_refresh_idle_id = 0;
    private bool sidebar_visible = true;
    private int last_sidebar_position = DEFAULT_SIDEBAR_WIDTH;

    private bool suppress_editor_events = false;
    private uint applying_state_depth = 0;
    private uint rendered_sidebar_data_version = uint.MAX;
    private EditorRenderState editor_render_state;

    public MainWindow(Adw.Application app, int startup_width = 0, int startup_height = 0) {
        var boot_settings = AppSettings.open_or_null();
        int initial_width;
        int initial_height;
        bool start_maximized;
        resolve_startup_window_state(
            boot_settings,
            startup_width,
            startup_height,
            out initial_width,
            out initial_height,
            out start_maximized
        );
        Object(
            application: app,
            default_width: initial_width,
            default_height: initial_height,
            title: "Holder"
        );

        project_store = new GLib.ListStore(typeof(Project));
        project_selection = new Gtk.SingleSelection(project_store);

        card_store = new GLib.ListStore(typeof(CardSummary));
        card_selection = new Gtk.SingleSelection(card_store);
        ai_thread_store = new GLib.ListStore(typeof(AiThreadSummary));
        ai_thread_selection = new Gtk.SingleSelection(ai_thread_store);
        search_store = new GLib.ListStore(typeof(SearchCardResult));

        toast_overlay = new Adw.ToastOverlay();
        root_paned = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
        root_paned.set_wide_handle(true);
        root_paned.set_position(last_sidebar_position);
        toast_overlay.set_child(root_paned);
        set_content(toast_overlay);

        workspace = new WorkspacePane(search_store);
        editor_buffer = workspace.editor_buffer;
        editor_view = workspace.editor_view;
        spelling_adapter = workspace.spelling_adapter;
        settings = boot_settings;
        if (settings != null) {
            last_sidebar_position = clamp_sidebar_width(
                settings.get_int(AppSettings.KEY_SIDEBAR_WIDTH)
            );
            workspace.set_ai_panel_width(settings.get_int(AppSettings.KEY_AI_PANEL_WIDTH));
        }
        apply_persisted_preferences();
        search_entry = workspace.search_entry;
        search_summary_label = workspace.search_summary_label;
        search_selection = workspace.search_selection;
        search_list = workspace.search_list;
        ai_panel = workspace.ai_panel;
        toolbox = workspace.toolbox;
        internal_link_controller = new InternalLinkController();
        editor_render_state = new EditorRenderState();
        apply_editor_from_state();
        local_info_controller = new LocalInfoController(new WindowLocalInfoLogger(toolbox));
        local_info_presenter = new LocalInfoPresenter();
        app_state_store = new AppStateStore();
        app_transition_controller = new AppTransitionController(app_state_store);
        selection_transition_controller = new SelectionTransitionController(app_transition_controller);
        var controller_project_store = new GLib.ListStore(typeof(Project));
        var controller_card_store = new GLib.ListStore(typeof(CardSummary));
        var controller_ai_thread_store = new GLib.ListStore(typeof(AiThreadSummary));
        controller = new MainController(
            controller_project_store,
            new GtkSingleSelectionState(project_selection),
            controller_card_store,
            new GtkSingleSelectionState(card_selection),
            controller_ai_thread_store,
            new GtkSingleSelectionState(ai_thread_selection),
            search_store,
            new SearchEntryTextProvider(search_entry),
            new SourceBufferTextProvider(editor_buffer),
            new DefaultApiFactory(),
            new FileServerDiscovery(),
            null,
            null,
            null,
            app_state_store
        );
        project_create_controller = new ProjectCreateController();
        explorer_selection_controller = new ExplorerSelectionController(
            project_store,
            card_store,
            ai_thread_store
        );
        sidebar_data_renderer = new SidebarDataRenderer(
            project_store,
            card_store,
            ai_thread_store
        );
        sidebar_selection_renderer = new SidebarSelectionRenderer(
            project_selection,
            card_selection,
            ai_thread_selection,
            explorer_selection_controller
        );
        search_selection_controller = new SearchSelectionController(search_store);
        selection_request_controller = new SelectionRequestController(
            explorer_selection_controller
        );
        selection_intent_controller = new SelectionIntentController();
        selection_controller = new SelectionController(controller);
        share_controller = new ShareController();
        card_append_controller = new CardAppendController();
        local_info_flow_controller = new LocalInfoFlowController(
            new WindowLocalInfoFlowContext(controller),
            local_info_controller
        );
        local_info_view_adapter = new LocalInfoViewAdapter(
            new WindowLocalInfoViewSink(this),
            local_info_presenter
        );
        local_info_ui_controller = new LocalInfoUiController(
            local_info_flow_controller,
            local_info_view_adapter
        );
        window_actions_adapter = new WindowActionsAdapter(this);
        card_action_dialog_adapter = new CardActionDialogAdapter(this);
        project_create_dialog_adapter = new ProjectCreateDialogAdapter(this);
        print_service = new PrintService();
        print_ui_controller = new PrintUiController(print_service);
        recovery_controller = new RecoveryController(new WindowRecoveryContext(controller));
        recovery_ui_controller = new RecoveryUiController(recovery_controller);
        recovery_dialog_adapter = new RecoveryDialogAdapter(this, recovery_ui_controller);
        ai_run_controller = new AiRunController(controller);
        find_replace_controller = new FindReplaceController(
            new WindowFindReplaceOps(editor_buffer, editor_view)
        );
        flowboard_controller = new FlowboardController(project_store, project_selection, card_store);
        flowboard_context_controller = new FlowboardContextController();
        selection_intent_orchestrator = new SelectionIntentOrchestrator(
            selection_intent_controller,
            selection_transition_controller,
            selection_controller,
            controller,
            flowboard_controller,
            project_selection,
            card_selection,
            ai_thread_selection,
            search_selection,
            card_store,
            search_selection_controller
        );
        toolbox_breadcrumb_controller = new ToolboxBreadcrumbController(
            selection_intent_orchestrator,
            toolbox
        );
        ai_panel_event_orchestrator = new AiPanelEventOrchestrator(
            ai_panel,
            ai_run_controller,
            new WindowAiPanelEventSink(this)
        );
        tool_help_controller = new ToolHelpController();
        toolbox_event_orchestrator = new ToolboxEventOrchestrator(
            toolbox,
            toolbox_breadcrumb_controller,
            selection_intent_orchestrator,
            controller,
            new WindowToolboxEventSink(this)
        );
        window_feedback_orchestrator = new WindowFeedbackOrchestrator(
            find_replace_controller,
            share_controller,
            card_append_controller,
            recovery_ui_controller,
            recovery_dialog_adapter,
            print_ui_controller,
            new WindowFeedbackSink(this)
        );
        window_action_binder = new WindowActionBinder(this, new WindowActionSink(this));

        sidebar = new SidebarPane(project_selection, card_selection, ai_thread_selection);
        window_sidebar_event_binder = new WindowSidebarEventBinder(
            sidebar,
            new WindowSidebarEventSink(this)
        );
        window_workspace_event_binder = new WindowWorkspaceEventBinder(
            workspace,
            new WindowWorkspaceEventSink(this)
        );
        window_selection_editor_event_binder = new WindowSelectionEditorEventBinder(
            project_selection,
            card_selection,
            ai_thread_selection,
            editor_buffer,
            editor_view,
            new WindowSelectionEditorEventSink(this)
        );
        window_flowboard_event_binder = new WindowFlowboardEventBinder(
            card_store,
            flowboard_controller,
            new WindowFlowboardEventSink(this)
        );
        window_lifecycle_event_binder = new WindowLifecycleEventBinder(
            project_create_controller,
            this,
            new WindowLifecycleEventSink(this)
        );
        window_state_event_binder = new WindowStateEventBinder(
            root_paned,
            app_state_store,
            selection_transition_controller,
            new WindowStateEventSink(this)
        );
        root_paned.set_start_child(sidebar.widget);
        root_paned.set_end_child(workspace.widget);
        root_paned.set_resize_start_child(true);
        root_paned.set_shrink_start_child(false);
        root_paned.set_position(last_sidebar_position);

        main_controller_signal_binder = new MainControllerSignalBinder(
            controller,
            new WindowMainControllerSignalSink(this)
        );
        main_controller_signal_binder.bind();
        ai_panel_event_orchestrator.bind();
        toolbox_event_orchestrator.bind();
        window_feedback_orchestrator.bind();
        window_action_binder.bind();
        window_sidebar_event_binder.bind();
        window_workspace_event_binder.bind();
        window_selection_editor_event_binder.bind();

        toolbox.set_settings(settings);
        toolbox.bind_connections_context(project_selection, card_store, card_selection);
        toolbox.bind_flowboard_controller(flowboard_controller);
        window_flowboard_event_binder.bind();
        window_lifecycle_event_binder.bind();
        window_state_event_binder.bind();

        if (start_maximized) {
            maximize();
        }

        controller.bootstrap.begin();
    }

    private void apply_sidebar_from_state() {
        var snapshot = app_state_store.selection;
        var transition = app_state_store.transition;
        string? effective_project_id = snapshot.project_id;
        string? effective_card_id = snapshot.card_id;
        string? effective_ai_thread_id = snapshot.ai_thread_id;
        if (transition.in_flight) {
            if (transition.pending_selection.project_id != null) {
                effective_project_id = transition.pending_selection.project_id;
            } else {
                var live_project = project_selection.get_selected_item() as Project;
                if (live_project != null) {
                    effective_project_id = live_project.project_id;
                }
            }
            if (transition.pending_selection.project_id != null
                || transition.pending_selection.card_id != null) {
                effective_card_id = transition.pending_selection.card_id;
            }
            if (transition.pending_selection.ai_thread_id != null
                || transition.pending_selection.project_id != null) {
                effective_ai_thread_id = transition.pending_selection.ai_thread_id;
            }
        }
        with_state_apply(() => {
            if (rendered_sidebar_data_version != app_state_store.data_version) {
                sidebar_data_renderer.apply(
                    app_state_store.projects,
                    app_state_store.cards,
                    app_state_store.ai_threads
                );
                rendered_sidebar_data_version = app_state_store.data_version;
            }
            sidebar_selection_renderer.apply_from_snapshot(
                effective_project_id,
                effective_card_id,
                effective_ai_thread_id
            );
        });
    }

    private void queue_flowboard_refresh() {
        if (flowboard_refresh_idle_id != 0) {
            return;
        }
        flowboard_refresh_idle_id = Idle.add(() => {
            flowboard_refresh_idle_id = 0;
            flowboard_controller.refresh();
            return Source.REMOVE;
        });
    }

    private static void resolve_startup_window_state(
        Settings? settings,
        int startup_width,
        int startup_height,
        out int width,
        out int height,
        out bool start_maximized
    ) {
        if (startup_width > 0 || startup_height > 0) {
            width = startup_width > 0 ? startup_width : DEFAULT_WINDOW_WIDTH;
            height = startup_height > 0 ? startup_height : DEFAULT_WINDOW_HEIGHT;
            start_maximized = false;
            return;
        }

        width = DEFAULT_WINDOW_WIDTH;
        height = DEFAULT_WINDOW_HEIGHT;
        start_maximized = false;
        if (settings == null) {
            return;
        }

        var saved_width = settings.get_int(AppSettings.KEY_WINDOW_WIDTH);
        var saved_height = settings.get_int(AppSettings.KEY_WINDOW_HEIGHT);
        var saved_tiny = is_tiny_size(saved_width, saved_height);
        var streak = settings.get_int(AppSettings.KEY_TINY_CLOSE_STREAK);

        if (!saved_tiny || streak >= TINY_CLOSE_STRIKE_LIMIT) {
            width = saved_width;
            height = saved_height;
        }

        start_maximized = settings.get_boolean(AppSettings.KEY_WINDOW_MAXIMIZED);
    }

    private static bool is_tiny_size(int width, int height) {
        return width < MIN_RESTORE_WIDTH || height < MIN_RESTORE_HEIGHT;
    }

    private void persist_window_state() {
        if (settings == null) {
            return;
        }

        settings.set_int(
            AppSettings.KEY_SIDEBAR_WIDTH,
            clamp_sidebar_width(last_sidebar_position)
        );
        settings.set_int(
            AppSettings.KEY_AI_PANEL_WIDTH,
            workspace.get_ai_panel_width_for_persist()
        );

        var maximized = is_maximized();
        settings.set_boolean(AppSettings.KEY_WINDOW_MAXIMIZED, maximized);

        if (!maximized) {
            var width = get_width();
            var height = get_height();
            settings.set_int(AppSettings.KEY_WINDOW_WIDTH, width);
            settings.set_int(AppSettings.KEY_WINDOW_HEIGHT, height);

            if (is_tiny_size(width, height)) {
                var streak = settings.get_int(AppSettings.KEY_TINY_CLOSE_STREAK);
                settings.set_int(AppSettings.KEY_TINY_CLOSE_STREAK, streak + 1);
            } else {
                settings.set_int(AppSettings.KEY_TINY_CLOSE_STREAK, 0);
            }
            return;
        }

        settings.set_int(AppSettings.KEY_TINY_CLOSE_STREAK, 0);
    }

    private static int clamp_sidebar_width(int width) {
        if (width < MIN_SIDEBAR_WIDTH) {
            return MIN_SIDEBAR_WIDTH;
        }
        if (width > MAX_SIDEBAR_WIDTH) {
            return MAX_SIDEBAR_WIDTH;
        }
        return width;
    }

    private void show_new_project_dialog() {
        project_create_dialog_adapter.show((raw_name, is_private_mode) => {
            var submission = project_create_controller.build_submission(raw_name, is_private_mode);
            if (submission == null) {
                return;
            }
            controller.create_project_named.begin(submission.name, submission.privacy_mode);
        });
    }

    internal void handle_refresh_action() {
        controller.reload_everything.begin();
    }

    internal void handle_new_project_action() {
        show_new_project_dialog();
    }

    internal void handle_new_card_action() {
        controller.create_card.begin();
    }

    internal void handle_toggle_toolbox_action() {
        workspace.toggle_toolbox();
    }

    internal void handle_find_replace_action() {
        workspace.show_find_replace_bar(true);
    }

    internal void handle_print_action() {
        print_current_card.begin();
    }

    internal void handle_show_local_info_action() {
        local_info_ui_controller.show_page.begin();
    }

    internal void handle_show_preferences_action() {
        show_preferences_dialog();
    }

    internal void handle_show_about_action() {
        show_about_dialog();
    }

    internal void on_sidebar_card_move_to_trash_requested(string card_id) {
        confirm_move_card_to_trash(card_id);
    }

    internal void on_sidebar_card_context_selection_requested(string card_id) {
        with_state_apply(() => {
            selection_request_controller.request_card(card_selection, card_id);
        });
    }

    internal void on_workspace_refresh_requested() {
        controller.reload_everything.begin();
    }

    internal void on_workspace_new_project_requested() {
        show_new_project_dialog();
    }

    internal void on_workspace_new_card_requested() {
        controller.create_card.begin();
    }

    internal void on_workspace_explorer_panel_toggled(bool visible) {
        sidebar_visible = visible;
        if (visible) {
            root_paned.set_start_child(sidebar.widget);
            root_paned.set_position(clamp_sidebar_width(last_sidebar_position));
            return;
        }
        if (root_paned.get_position() > 0) {
            last_sidebar_position = clamp_sidebar_width(root_paned.get_position());
        }
        root_paned.set_start_child(null);
    }

    internal void on_workspace_ai_panel_toggled(bool visible) {
        workspace.set_ai_panel_visible(visible);
        ai_run_controller.set_panel_visible(visible);
        if (visible) {
            ai_panel.refresh_catalog();
        }
    }

    internal void on_workspace_toolbox_toggled(bool visible) {
        workspace.set_toolbox_visible(visible);
        if (visible) {
            toolbox.log_debug("Toolbox opened");
            toolbox.refresh_trash();
            return;
        }
        toolbox.log_debug("Toolbox closed");
    }

    internal void on_workspace_search_activated() {
        controller.cancel_pending_search();
        controller.run_search.begin();
    }

    internal void on_workspace_search_changed() {
        var q = search_entry.get_text().strip();
        if (q.length == 0) {
            controller.cancel_pending_search();
            controller.clear_search_results();
            show_editor_mode();
            return;
        }
        controller.schedule_search();
    }

    internal void on_workspace_search_cleared() {
        search_entry.set_text("");
        controller.clear_search_results();
        show_editor_mode();
    }

    internal void on_workspace_search_focus_results_requested() {
        if (search_store.get_n_items() == 0) {
            return;
        }
        show_search_mode();
        if (search_selection.get_selected() == Gtk.INVALID_LIST_POSITION) {
            request_search_selection(0);
        }
        search_list.grab_focus();
    }

    internal void on_workspace_search_result_activated(uint position) {
        selection_intent_orchestrator.on_search_result_activation.begin(position);
    }

    internal void on_workspace_find_next_requested() {
        find_replace_controller.on_find_next_requested(workspace.get_find_text());
    }

    internal void on_workspace_replace_requested() {
        find_replace_controller.on_replace_requested(
            workspace.get_find_text(),
            workspace.get_replace_text()
        );
    }

    internal void on_workspace_replace_all_requested() {
        find_replace_controller.on_replace_all_requested(
            workspace.get_find_text(),
            workspace.get_replace_text()
        );
    }

    internal void on_project_selection_changed() {
        if (is_applying_state()) {
            return;
        }
        var selected = project_selection.get_selected_item() as Project;
        if (selected != null) {
            // Optimistically mirror user intent so sidebar highlight does not
            // bounce back to last committed selection before transition begin.
            app_state_store.set_selection_snapshot(selected.project_id, null, null);
        }
        selection_intent_orchestrator.on_project_selection_changed.begin();
    }

    internal void on_card_selection_changed() {
        if (is_applying_state()) {
            return;
        }
        selection_intent_orchestrator.on_card_selection_changed.begin();
    }

    internal void on_ai_thread_selection_changed() {
        if (is_applying_state()) {
            return;
        }
        selection_intent_orchestrator.on_ai_thread_selection_changed();
    }

    internal void on_editor_buffer_changed() {
        if (suppress_editor_events || controller.get_current_card() == null) {
            return;
        }
        refresh_connections_internal_links_from_editor();
        controller.schedule_autosave();
    }

    internal void on_internal_link_click_pressed(Gtk.GestureClick gesture,
                                                 int n_press,
                                                 double x,
                                                 double y) {
        if (n_press != 1) {
            return;
        }
        var sequence = gesture.get_current_sequence();
        var event = gesture.get_last_event(sequence);
        if (event == null) {
            return;
        }
        if ((event.get_modifier_state() & Gdk.ModifierType.CONTROL_MASK) == 0) {
            return;
        }

        int buffer_x;
        int buffer_y;
        editor_view.window_to_buffer_coords(
            Gtk.TextWindowType.WIDGET,
            (int) x,
            (int) y,
            out buffer_x,
            out buffer_y
        );
        Gtk.TextIter iter;
        if (!editor_view.get_iter_at_location(out iter, buffer_x, buffer_y)) {
            return;
        }
        if (navigate_internal_link_at_iter(iter)) {
            gesture.set_state(Gtk.EventSequenceState.CLAIMED);
        }
    }

    internal bool on_internal_link_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state) {
        if ((state & Gdk.ModifierType.CONTROL_MASK) == 0) {
            return false;
        }
        if (keyval != Gdk.Key.Return && keyval != Gdk.Key.KP_Enter) {
            return false;
        }
        Gtk.TextIter cursor;
        editor_buffer.get_iter_at_mark(out cursor, editor_buffer.get_insert());
        return navigate_internal_link_at_iter(cursor);
    }

    internal void on_card_store_items_changed(uint position, uint removed, uint added) {
        queue_flowboard_refresh();
    }

    internal void on_flowboard_project_overview_requested(string project_id) {
        selection_intent_orchestrator.on_project_selection_requested.begin(project_id);
    }

    internal void on_flowboard_context_load_requested(string project_id, string? parent_card_id) {
        var request_serial = flowboard_context_controller.begin_request();
        flowboard_context_controller.load_context.begin(
            request_serial,
            project_id,
            parent_card_id,
            controller.get_api_client(),
            flowboard_controller
        );
    }

    internal void on_project_create_error_reported(string title_text, string details) {
        show_error(title_text, details);
    }

    internal bool on_window_close_requested() {
        persist_window_state();
        return false;
    }

    internal void on_root_paned_position_changed(int position) {
        if (sidebar_visible && position > 0) {
            last_sidebar_position = clamp_sidebar_width(position);
        }
    }

    internal void on_app_state_changed() {
        apply_sidebar_from_state();
    }

    internal void on_navigation_loading_changed(bool loading) {
        toolbox.set_navigation_loading(loading);
    }

    internal void set_status(string text) {
        if (sidebar != null) {
            sidebar.set_status_text(text);
        }
        if (toolbox != null) {
            toolbox.log_debug("STATUS: %s".printf(text));
        }
    }

    internal void set_editor_state(string text, bool editable) {
        editor_render_state.text = text;
        editor_render_state.editable = editable;
        apply_editor_from_state();
    }

    internal void update_window_title(string title_text) {
        editor_render_state.window_title = title_text;
        apply_editor_from_state();
    }

    internal void set_search_summary_text(string text) {
        editor_render_state.search_summary = text;
        apply_editor_from_state();
    }

    internal void refresh_ai_status() {
        ai_run_controller.refresh_status.begin();
    }

    internal void request_project_selection(string? project_id) {
        with_state_apply(() => {
            selection_request_controller.request_project(project_selection, project_id);
        });
        selection_intent_orchestrator.on_project_selection_changed.begin();
    }

    internal void request_card_selection(string? card_id) {
        with_state_apply(() => {
            selection_request_controller.request_card(card_selection, card_id);
        });
        selection_intent_orchestrator.on_card_selection_changed.begin();
    }

    internal void request_search_selection(int position) {
        with_state_apply(() => {
            selection_intent_orchestrator.on_search_selection_requested(position);
        });
    }

    internal void set_ai_thread_title(string? title_text) {
        editor_render_state.ai_thread_title = title_text;
        apply_editor_from_state();
    }

    internal void request_ai_thread_selection(string? thread_id) {
        with_state_apply(() => {
            selection_request_controller.request_ai_thread(ai_thread_selection, thread_id);
        });
        selection_intent_orchestrator.on_ai_thread_selection_changed();
    }

    internal void on_api_client_connected(IHolderApi api_client) {
        ai_panel.set_api_client(api_client);
        ai_panel.refresh_catalog();
        toolbox.set_api_client(api_client);
    }

    internal void refresh_trash_tool() {
        toolbox.refresh_trash();
    }

    internal void log_debug_line(string message) {
        if (toolbox != null) {
            toolbox.log_debug(message);
        }
    }

    internal void add_toast(string msg) {
        toast_overlay.add_toast(new Adw.Toast(msg));
    }

    internal void show_error(string title_text, string details) {
        set_status("%s: %s".printf(title_text, details));
        add_toast("%s".printf(title_text));
        if (toolbox != null) {
            toolbox.log_debug("ERROR: %s | %s".printf(title_text, details));
        }
    }

    internal void show_editor_mode() {
        editor_render_state.show_search = false;
        apply_editor_from_state();
    }

    internal void show_search_mode() {
        editor_render_state.show_search = true;
        apply_editor_from_state();
    }

    private void apply_persisted_preferences() {
        if (settings == null) {
            Adw.StyleManager.get_default().set_color_scheme(AppSettings.resolve_default_color_scheme());
            return;
        }

        var style_key = settings.get_string(AppSettings.KEY_STYLE_VARIANT);
        Adw.StyleManager.get_default().set_color_scheme(AppSettings.effective_color_scheme_for_key(style_key));

        editor_view.set_show_line_numbers(settings.get_boolean(AppSettings.KEY_SHOW_LINE_NUMBERS));
        if (spelling_adapter != null) {
            spelling_adapter.set_enabled(settings.get_boolean(AppSettings.KEY_SHOW_SPELL_CHECKING));
        }

        var scheme_id = settings.get_string(AppSettings.KEY_STYLE_SCHEME_ID);
        if (scheme_id == null || scheme_id.length == 0) {
            return;
        }

        var scheme = GtkSource.StyleSchemeManager.get_default().get_scheme(scheme_id);
        if (scheme != null) {
            editor_buffer.set_style_scheme(scheme);
        }

    }

    internal void open_card_from_flowboard(string card_id) {
        selection_intent_orchestrator.open_card_with_transition.begin(card_id, "tool-card-open");
    }

    private bool is_applying_state() {
        return applying_state_depth > 0;
    }

    private void with_state_apply(owned StateApplyFunc apply_fn) {
        applying_state_depth++;
        try {
            apply_fn();
        } finally {
            if (applying_state_depth > 0) {
                applying_state_depth--;
            }
        }
    }

    private void apply_editor_from_state() {
        suppress_editor_events = true;
        workspace.set_editor_state(editor_render_state.text, editor_render_state.editable);
        suppress_editor_events = false;
        refresh_connections_internal_links_from_editor();

        workspace.set_window_title_text(editor_render_state.window_title);
        title = editor_render_state.window_title;
        search_summary_label.set_text(editor_render_state.search_summary);
        ai_panel.set_thread_title(editor_render_state.ai_thread_title);

        if (editor_render_state.show_search) {
            workspace.show_search_mode();
        } else {
            workspace.show_editor_mode();
        }
    }

    private string card_title_for_id(string card_id) {
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null && card.card_id == card_id) {
                return card.title;
            }
        }
        return "this card";
    }

    internal void show_tool_help_page(string tool_id) {
        var help = tool_help_controller.load(tool_id);
        set_editor_state(help.markdown, false);
        update_window_title(help.title);
        show_editor_mode();
        set_status(help.status_text);
    }

    internal void confirm_move_card_to_trash(string card_id) {
        if (card_id.strip().length == 0) {
            return;
        }

        var title_text = card_title_for_id(card_id);
        card_action_dialog_adapter.confirm_move_to_trash(title_text, () => {
            controller.move_card_to_trash.begin(card_id);
        });
    }

    private string? internal_link_target_at_iter(Gtk.TextIter iter) {
        Gtk.TextIter line_start = iter;
        line_start.set_line_offset(0);
        Gtk.TextIter line_end = line_start;
        line_end.forward_to_line_end();

        var line_text = editor_buffer.get_text(line_start, line_end, false);
        if (line_text == null || line_text.length == 0) {
            return null;
        }

        var before_cursor = editor_buffer.get_text(line_start, iter, false);
        var cursor_byte_offset = before_cursor.length;
        return internal_link_controller.extract_target_from_line(line_text, cursor_byte_offset);
    }

    private Gee.ArrayList<CardSummary> project_cards_for_selected_project() {
        var project_cards = new Gee.ArrayList<CardSummary>();
        var project_id = controller.selected_project_id();
        if (project_id == null) {
            return project_cards;
        }

        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null && card.project_id == project_id) {
                project_cards.add(card);
            }
        }
        return project_cards;
    }

    private bool navigate_internal_link_at_iter(Gtk.TextIter iter) {
        var decision = internal_link_controller.decide_navigation(
            internal_link_target_at_iter(iter),
            project_cards_for_selected_project()
        );
        if (!decision.handled) {
            return false;
        }

        if (decision.open_card_id == null) {
            if (decision.toast_message != null) {
                add_toast(decision.toast_message);
            }
            var target_copy = decision.create_target;
            Idle.add(() => {
                if (target_copy != null) {
                    card_action_dialog_adapter.confirm_create_linked_card(target_copy, () => {
                        controller.create_card_with_title.begin(target_copy);
                    });
                }
                return Source.REMOVE;
            });
            return true;
        }

        open_card_from_flowboard((!) decision.open_card_id);
        return true;
    }

    private void show_preferences_dialog() {
        window_actions_adapter.show_preferences(
            editor_buffer,
            editor_view,
            spelling_adapter,
            settings
        );
    }

    internal void send_current_card_as_email() {
        var card = controller.get_current_card();
        Gtk.TextIter start;
        Gtk.TextIter end;
        editor_buffer.get_bounds(out start, out end);
        var body_text = editor_buffer.get_text(start, end, false);
        share_controller.send_card_as_email(card, body_text);
    }

    internal void request_send_recovery_key_as_email() {
        recovery_dialog_adapter.request_pin(
            "Email Recovery Key",
            "Set a recovery key PIN to export and email your `.hrk` file.",
            (pin) => {
                send_recovery_key_as_email.begin(pin);
            }
        );
    }

    internal void request_save_recovery_key_to_usb() {
        recovery_dialog_adapter.request_pin(
            "Save Recovery Key",
            "Set a recovery key PIN to export a `.hrk` file.",
            (pin) => {
                save_recovery_key_to_usb.begin(pin);
            }
        );
    }

    internal void request_import_recovery_key() {
        recovery_dialog_adapter.open_import_dialog((pin, recovery_token) => {
            import_recovery_key_payload.begin(pin, recovery_token);
        });
    }

    private async void send_recovery_key_as_email(string pin) {
        yield recovery_ui_controller.export_for_email(controller.get_current_project(), pin);
    }

    private async void save_recovery_key_to_usb(string pin) {
        var prepared = yield recovery_ui_controller.prepare_export_save(
            controller.get_current_project(),
            pin
        );
        if (prepared == null) {
            return;
        }

        recovery_dialog_adapter.open_save_dialog(prepared.default_filename, (path) => {
            recovery_ui_controller.save_payload_to_path(path, prepared.payload);
        });
    }

    private async void import_recovery_key_payload(string pin, string recovery_token) {
        var result = yield recovery_ui_controller.import_payload(pin, recovery_token);
        if (result == null) {
            return;
        }

        recovery_dialog_adapter.show_import_summary(result);
        add_toast("Recovery key imported.");
    }

    internal void append_text_to_current_card(string text) {
        Gtk.TextIter end_iter;
        editor_buffer.get_end_iter(out end_iter);
        Gtk.TextIter start_iter;
        editor_buffer.get_start_iter(out start_iter);
        var existing = editor_buffer.get_text(
            start_iter,
            end_iter,
            false
        );
        var insert_text = card_append_controller.build_append_suffix(
            controller.get_current_card() != null,
            existing,
            text
        );
        if (insert_text == null) {
            return;
        }
        editor_buffer.insert(ref end_iter, insert_text, -1);
        show_editor_mode();
    }

    private async void print_current_card() {
        Gtk.TextIter start;
        Gtk.TextIter end;
        editor_buffer.get_bounds(out start, out end);
        var text = editor_buffer.get_text(start, end, false);
        yield print_ui_controller.print_text(this, text);
    }

    private void show_about_dialog() {
        window_actions_adapter.show_about();
    }

    private void refresh_connections_internal_links_from_editor() {
        if (internal_link_controller == null || toolbox == null) {
            return;
        }
        Gtk.TextIter start;
        Gtk.TextIter end;
        editor_buffer.get_bounds(out start, out end);
        var text = editor_buffer.get_text(start, end, false);
        var links = internal_link_controller.extract_internal_links(text);
        toolbox.set_connections_internal_links(links);
    }

    protected override void dispose() {
        ai_run_controller.stop();
        base.dispose();
    }

}

}
