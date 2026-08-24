namespace HolderLinux {

public class MainWindow : Adw.ApplicationWindow {
    private delegate void StateApplyFunc();

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
    private EditorFontStyle editor_font_style;
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
    private WindowInternalLinkNavigator internal_link_navigator;
    private LocalInfoController local_info_controller;
    private LocalInfoFlowController local_info_flow_controller;
    private LocalInfoPresenter local_info_presenter;
    private LocalInfoViewAdapter local_info_view_adapter;
    private LocalInfoUiController local_info_ui_controller;
    private WindowEditorRenderer editor_renderer;
    private WindowActivityFeedback activity_feedback;
    private WindowActionsAdapter window_actions_adapter;
    private UpdateCheckService update_check_service;
    private UpdateDialogAdapter update_dialog_adapter;
    private CardActionDialogAdapter card_action_dialog_adapter;
    private ProjectCreateDialogAdapter project_create_dialog_adapter;
    private PrintService print_service;
    private PrintAdapter print_ui_controller;
    private AiRunController ai_run_controller;
    private AiNudgeController ai_nudge_controller;
    private AiPanelEventOrchestrator ai_panel_event_orchestrator;
    private FindReplaceController find_replace_controller;
    private FlowboardController flowboard_controller;
    private FlowboardContextController flowboard_context_controller;
    private ToolHelpController tool_help_controller;
    private AppStateStore app_state_store;
    private ActivityLogStore activity_log_store;
    private ActivityLogController activity_log_controller;
    private IActivityReducer activity_reducer;
    private AppTransitionController app_transition_controller;
    private MainControllerSignalBinder main_controller_signal_binder;
    private Settings? settings;
    private uint flowboard_refresh_idle_id = 0;
    private bool sidebar_visible = true;
    private int last_sidebar_position = WindowGeometry.DEFAULT_SIDEBAR_WIDTH;

    private uint applying_state_depth = 0;
    private uint rendered_sidebar_data_version = uint.MAX;

    public MainWindow(Adw.Application app, int startup_width = 0, int startup_height = 0) {
        var boot_settings = AppSettings.open_or_null();
        var startup_geometry = resolve_startup_window_state(
            boot_settings,
            startup_width,
            startup_height
        );
        Object(
            application: app,
            default_width: startup_geometry.width,
            default_height: startup_geometry.height,
            title: "Holder"
        );
        var icon_name = app.get_application_id();
        if (icon_name == null || icon_name == "") {
            icon_name = "team.holder.Holder";
        }
        set_icon_name(icon_name);

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
        workspace.file_dropped.connect((file) => {
            import_dropped_file.begin(file);
        });
        editor_buffer = workspace.editor_buffer;
        editor_view = workspace.editor_view;
        editor_font_style = new EditorFontStyle(editor_view);
        spelling_adapter = workspace.spelling_adapter;
        settings = boot_settings;
        if (settings != null) {
            last_sidebar_position = WindowGeometry.clamp_sidebar_width(
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
        editor_renderer = new WindowEditorRenderer(this, workspace, search_summary_label, ai_panel);
        editor_renderer.content_rendered.connect(() => {
            refresh_connections_internal_links_from_editor();
        });
        editor_renderer.apply();
        local_info_controller = new LocalInfoController(new WindowLocalInfoLogger(toolbox));
        local_info_presenter = new LocalInfoPresenter();
        app_state_store = new AppStateStore();
        activity_log_store = new ActivityLogStore();
        activity_reducer = new SessionActivityReducer();
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
        activity_log_controller = new ActivityLogController(activity_log_store, controller);
        activity_feedback = new WindowActivityFeedback(
            workspace,
            toolbox,
            toast_overlay,
            activity_log_controller,
            controller
        );
        update_check_service = new UpdateCheckService();
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
        update_dialog_adapter = new UpdateDialogAdapter(this);
        card_action_dialog_adapter = new CardActionDialogAdapter(this);
        project_create_dialog_adapter = new ProjectCreateDialogAdapter(this);
        print_service = new PrintService();
        print_ui_controller = new PrintAdapter(print_service);
        recovery_controller = new RecoveryController(new WindowRecoveryContext(controller));
        recovery_ui_controller = new RecoveryUiController(recovery_controller);
        recovery_dialog_adapter = new RecoveryDialogAdapter(this, recovery_ui_controller);
        ai_run_controller = new AiRunController(controller);
        ai_nudge_controller = new AiNudgeController(controller);
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
            search_selection_controller,
            (kind, message, project_id, card_id) => {
                log_activity(kind, message, project_id, card_id, null);
            }
        );
        internal_link_navigator = new WindowInternalLinkNavigator(
            new InternalLinkController(),
            new TagNavigationController(),
            editor_buffer,
            editor_view,
            card_store,
            controller,
            selection_intent_orchestrator,
            card_action_dialog_adapter,
            toolbox,
            workspace,
            toast_overlay
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
            new WindowToolboxEventSource(toolbox),
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
            new WindowSidebarEventSource(sidebar),
            new WindowSidebarEventSink(this)
        );
        window_workspace_event_binder = new WindowWorkspaceEventBinder(
            new WindowWorkspaceEventSource(workspace),
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
            new GtkWindowCloseRequestSource(this),
            new WindowLifecycleEventSink(this)
        );
        window_state_event_binder = new WindowStateEventBinder(
            new GtkPanedPositionSource(root_paned),
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
            new WindowMainControllerSignalSource(controller),
            new WindowMainControllerSignalSink(this)
        );
        main_controller_signal_binder.bind();
        ai_panel_event_orchestrator.bind();
        ai_nudge_controller.debug_log_requested.connect((message) => {
            log_debug_line(message);
        });
        ai_nudge_controller.nudges_refresh_requested.connect((project_id, card_id) => {
            ai_panel.refresh_nudges(project_id, card_id);
        });
        ai_panel.title_suggestion_apply_requested.connect((nudge_id, card_id, title_text) => {
            ai_nudge_controller.apply_title_suggestion.begin(nudge_id, card_id, title_text);
        });
        toolbox_event_orchestrator.bind();
        window_feedback_orchestrator.bind();
        window_action_binder.bind();
        window_sidebar_event_binder.bind();
        window_workspace_event_binder.bind();
        window_selection_editor_event_binder.bind();

        toolbox.set_settings(settings);
        toolbox.set_activity_log_store(activity_log_store);
        toolbox.bind_connections_context(project_selection, card_store, card_selection);
        toolbox.bind_flowboard_controller(flowboard_controller);
        activity_log_store.entry_added.connect((entry) => {
            foreach (var candidate in activity_reducer.reduce(activity_log_store.snapshot())) {
                ai_nudge_controller.evaluate_candidate.begin(candidate);
            }
            if (workspace.is_ai_panel_visible() && entry.kind == "result.card.autosave") {
                ai_nudge_controller.evaluate_title_suggestion_for_current_card.begin();
            }
        });
        window_flowboard_event_binder.bind();
        window_lifecycle_event_binder.bind();
        window_state_event_binder.bind();

        if (startup_geometry.start_maximized) {
            maximize();
        }

        controller.bootstrap.begin();
        queue_update_check();
    }

    private void queue_update_check() {
        Idle.add(() => {
            run_update_check.begin();
            return Source.REMOVE;
        });
    }

    private async void run_update_check() {
        var candidate = yield update_check_service.check_if_due(settings, HolderLinux.VERSION);
        if (candidate == null) {
            return;
        }
        update_dialog_adapter.show(candidate, HolderLinux.VERSION, (shown_candidate) => {
            update_check_service.record_prompt(settings, shown_candidate.version);
        });
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

    private static WindowStartupGeometry resolve_startup_window_state(
        Settings? settings,
        int startup_width,
        int startup_height
    ) {
        if (settings == null) {
            return WindowGeometry.resolve_startup_geometry(startup_width, startup_height, false);
        }

        return WindowGeometry.resolve_startup_geometry(
            startup_width,
            startup_height,
            true,
            settings.get_int(AppSettings.KEY_WINDOW_WIDTH),
            settings.get_int(AppSettings.KEY_WINDOW_HEIGHT),
            settings.get_boolean(AppSettings.KEY_WINDOW_MAXIMIZED),
            settings.get_int(AppSettings.KEY_TINY_CLOSE_STREAK)
        );
    }

    private void persist_window_state() {
        if (settings == null) {
            return;
        }

        settings.set_int(
            AppSettings.KEY_SIDEBAR_WIDTH,
            WindowGeometry.clamp_sidebar_width(last_sidebar_position)
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

            settings.set_int(
                AppSettings.KEY_TINY_CLOSE_STREAK,
                WindowGeometry.next_tiny_close_streak(
                    false,
                    width,
                    height,
                    settings.get_int(AppSettings.KEY_TINY_CLOSE_STREAK)
                )
            );
            return;
        }

        settings.set_int(AppSettings.KEY_TINY_CLOSE_STREAK, 0);
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

    internal void handle_flowboard_new_child_card_action() {
        var selected_card_id = controller.selected_card_id();
        if (selected_card_id == null || selected_card_id.strip().length == 0) {
            return;
        }
        log_activity(
            "intent.card.create_child",
            "Create child card requested from Flowboard shortcut",
            controller.selected_project_id(),
            selected_card_id
        );
        controller.create_card.begin(selected_card_id);
    }

    internal void handle_move_selected_card_to_trash_action() {
        var selected_card_id = controller.selected_card_id();
        if (selected_card_id == null || selected_card_id.strip().length == 0) {
            return;
        }
        confirm_move_card_to_trash(selected_card_id);
    }

    internal void handle_toggle_toolbox_action() {
        workspace.toggle_toolbox();
    }

    internal void handle_find_replace_action() {
        workspace.toggle_find_replace_bar(true);
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
        selection_intent_orchestrator.open_card_with_transition.begin(
            card_id,
            "sidebar-context-card-open"
        );
    }

    internal void on_sidebar_card_create_child_requested(string card_id) {
        log_activity(
            "intent.card.create_child",
            "Create child card requested",
            controller.selected_project_id(),
            card_id
        );
        controller.create_card.begin(card_id);
    }

    internal void on_workspace_refresh_requested() {
        controller.reload_everything.begin();
    }

    internal void on_workspace_new_project_requested() {
        activity_log_controller.log_new_project_requested();
        show_new_project_dialog();
    }

    internal void on_workspace_new_card_requested() {
        activity_log_controller.log_new_card_requested();
        controller.create_card.begin();
    }

    internal void on_workspace_explorer_panel_toggled(bool visible) {
        sidebar_visible = visible;
        if (visible) {
            root_paned.set_start_child(sidebar.widget);
            root_paned.set_position(WindowGeometry.clamp_sidebar_width(last_sidebar_position));
            return;
        }
        if (root_paned.get_position() > 0) {
            last_sidebar_position = WindowGeometry.clamp_sidebar_width(root_paned.get_position());
        }
        root_paned.set_start_child(null);
    }

    internal void on_workspace_ai_panel_toggled(bool visible) {
        workspace.set_ai_panel_visible(visible);
        ai_run_controller.set_panel_visible(visible);
        if (visible) {
            ai_panel.refresh_config(controller.selected_project_id());
            ai_panel.refresh_nudges(controller.selected_project_id(), controller.selected_card_id());
            ai_nudge_controller.evaluate_title_suggestion_for_current_card.begin();
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

    internal void on_workspace_open_debug_panel_requested() {
        workspace.set_toolbox_visible(true);
        toolbox.show_tool("debug");
        toolbox.log_debug("Toolbox opened");
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
        if (selected == null) {
            // Ignore transient deselection events emitted while list models
            // are being rebuilt during state/data updates.
            return;
        }
        // Optimistically mirror user intent so sidebar highlight does not
        // bounce back to last committed selection before transition begin.
        app_state_store.set_selection_snapshot(selected.project_id, null, null);
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
        ai_run_controller.refresh_selected_thread_output.begin();
    }

    internal void on_editor_buffer_changed() {
        if (editor_renderer.is_applying_content || controller.get_current_card() == null) {
            return;
        }
        refresh_connections_internal_links_from_editor();
        controller.on_editor_content_changed();
        controller.schedule_autosave();
    }

    internal void on_internal_link_click_pressed(Gtk.GestureClick gesture,
                                                 int n_press,
                                                 double x,
                                                 double y) {
        if (internal_link_navigator != null) {
            internal_link_navigator.handle_click(gesture, n_press, x, y);
        }
    }

    internal bool on_internal_link_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state) {
        return internal_link_navigator != null
            ? internal_link_navigator.handle_key(keyval, keycode, state)
            : false;
    }

    internal void on_card_store_items_changed(uint position, uint removed, uint added) {
        queue_flowboard_refresh();
    }

    internal void on_flowboard_project_overview_requested(string project_id) {
        selection_intent_orchestrator.select_project_with_transition.begin(project_id);
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
            last_sidebar_position = WindowGeometry.clamp_sidebar_width(position);
        }
    }

    internal void on_app_state_changed() {
        apply_sidebar_from_state();
        if (workspace.is_ai_panel_visible()) {
            ai_panel.refresh_nudges(app_state_store.selection.project_id, app_state_store.selection.card_id);
            ai_nudge_controller.evaluate_title_suggestion_for_current_card.begin();
        }
    }

    internal void on_navigation_loading_changed(bool loading) {
        toolbox.set_navigation_loading(loading);
    }

    internal void set_status(string text) {
        activity_feedback.set_status(text);
    }

    private async void import_dropped_file(File file) {
        var storage_api = controller.get_api_client() as IResourceStorageApi;
        var project = controller.get_current_project();
        var card = controller.get_current_card();
        var source_path = file.get_path();
        if (storage_api == null || project == null || card == null || source_path == null) {
            add_toast("Select a Card before dropping local files.");
            return;
        }
        try {
            var locations = yield storage_api.list_storage_locations(project.project_id);
            if (locations.preferred_location_id == null) {
                workspace.set_toolbox_visible(true);
                toolbox.show_tool("resources");
                add_toast("Add and choose a preferred Storage Location first.");
                return;
            }
            set_status("Importing %s…".printf(file.get_basename() ?? "asset"));
            var job = yield storage_api.start_asset_import(
                project.project_id,
                card.card_id,
                (!) locations.preferred_location_id,
                source_path
            );
            for (int attempt = 0; attempt < 600; attempt++) {
                job = yield storage_api.get_asset_import_job(job.job_id);
                if (job.status == "completed") {
                    set_status("Imported %s".printf(file.get_basename() ?? "asset"));
                    add_toast("Asset attached to this Card.");
                    toolbox.show_tool("resources");
                    return;
                }
                if (job.status == "failed") {
                    throw new ApiError.PROTOCOL(job.error ?? "Asset import failed");
                }
                set_status("Importing %s · %s".printf(file.get_basename() ?? "asset", job.status));
                yield wait_for_import_poll();
            }
            throw new ApiError.TRANSPORT("Asset import timed out");
        } catch (Error e) {
            show_error("Failed to import Asset", e.message);
        }
    }

    private async void wait_for_import_poll() {
        Timeout.add(100, () => {
            wait_for_import_poll.callback();
            return Source.REMOVE;
        });
        yield;
    }

    internal void set_editor_state(string text, bool editable) {
        editor_renderer.set_editor_state(text, editable);
        var card = controller.get_current_card();
        if (card != null && card.content == text) {
            workspace.set_validated_tag_occurrences(card.tag_occurrences);
        } else {
            workspace.clear_validated_tag_highlights();
        }
    }

    internal void update_window_title(string title_text) {
        editor_renderer.update_window_title(title_text);
    }

    internal void set_editor_save_state_text(string text) {
        editor_renderer.set_save_state_text(text);
    }

    internal void set_search_summary_text(string text) {
        editor_renderer.set_search_summary_text(text);
    }

    internal void refresh_ai_status() {
        if (!workspace.is_ai_panel_visible()) {
            return;
        }
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
        editor_renderer.set_ai_thread_title(title_text);
    }

    internal void request_ai_thread_selection(string? thread_id) {
        with_state_apply(() => {
            selection_request_controller.request_ai_thread(ai_thread_selection, thread_id);
        });
        selection_intent_orchestrator.on_ai_thread_selection_changed();
    }

    internal void on_api_client_connected(IHolderApi api_client) {
        ai_panel.set_api_client(api_client);
        if (workspace.is_ai_panel_visible()) {
            ai_panel.refresh_config(controller.selected_project_id());
            ai_panel.refresh_nudges(controller.selected_project_id(), controller.selected_card_id());
            ai_nudge_controller.evaluate_title_suggestion_for_current_card.begin();
        }
        toolbox.set_api_client(api_client);
    }

    internal void refresh_trash_tool() {
        toolbox.refresh_trash();
    }

    internal async void on_trash_item_restored(string? card_id) {
        if (!(yield controller.reload_selected_project_cards_data())) {
            return;
        }
        if (card_id != null && card_id.strip().length > 0 && controller.has_card_summary(card_id)) {
            controller.card_selection_requested(card_id);
        }
    }

    internal void log_debug_line(string message) {
        activity_feedback.log_debug_line(message);
    }

    internal void log_activity(string kind,
                               string message,
                               string? project_id = null,
                               string? card_id = null,
                               ActivityDetails? details = null) {
        activity_feedback.log_activity(kind, message, project_id, card_id, details);
    }

    internal void log_status_activity(string text) {
        activity_feedback.log_status_activity(text);
    }

    internal void log_toast_activity(string message) {
        activity_feedback.log_toast_activity(message);
    }

    internal void log_error_activity(string title_text, string details) {
        activity_feedback.log_error_activity(title_text, details);
    }

    internal void add_toast(string msg) {
        activity_feedback.add_toast(msg);
    }

    internal void show_error(string title_text, string details) {
        activity_feedback.show_error(title_text, details);
    }

    internal void show_editor_mode() {
        editor_renderer.show_editor_mode();
    }

    internal void show_search_mode() {
        editor_renderer.show_search_mode();
    }

    private void apply_persisted_preferences() {
        if (settings == null) {
            Adw.StyleManager.get_default().set_color_scheme(AppSettings.resolve_default_color_scheme());
            return;
        }

        var style_key = settings.get_string(AppSettings.KEY_STYLE_VARIANT);
        Adw.StyleManager.get_default().set_color_scheme(AppSettings.effective_color_scheme_for_key(style_key));

        editor_view.set_show_line_numbers(settings.get_boolean(AppSettings.KEY_SHOW_LINE_NUMBERS));
        editor_font_style.apply(
            settings.get_boolean(AppSettings.KEY_USE_CUSTOM_EDITOR_FONT),
            settings.get_string(AppSettings.KEY_CUSTOM_EDITOR_FONT)
        );
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

    private void show_preferences_dialog() {
        window_actions_adapter.show_preferences(
            editor_buffer,
            editor_view,
            spelling_adapter,
            settings,
            editor_font_style
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
        if (internal_link_navigator == null) {
            return;
        }
        internal_link_navigator.refresh_connections_from_editor();
    }

    protected override void dispose() {
        ai_run_controller.stop();
        base.dispose();
    }

}

}
