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

public class MainWindow : Adw.ApplicationWindow {
    private delegate void RecoveryPinHandler(string pin);
    private delegate void StateApplyFunc();

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
    private SelectionController selection_controller;
    private RecoveryController recovery_controller;
    private LocalInfoController local_info_controller;
    private LocalInfoFlowController local_info_flow_controller;
    private LocalInfoPresenter local_info_presenter;
    private LocalInfoViewAdapter local_info_view_adapter;
    private PrintService print_service;
    private AiRunController ai_run_controller;
    private FlowboardController flowboard_controller;
    private AppStateStore app_state_store;
    private AppTransitionController app_transition_controller;
    private Settings? settings;
    private uint flowboard_refresh_idle_id = 0;
    private uint flowboard_context_request_serial = 0;
    private bool sidebar_visible = true;
    private int last_sidebar_position = DEFAULT_SIDEBAR_WIDTH;

    private bool suppress_editor_events = false;
    private uint applying_state_depth = 0;
    private uint rendered_sidebar_data_version = uint.MAX;

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
        root_paned.notify["position"].connect(() => {
            if (sidebar_visible && root_paned.get_position() > 0) {
                last_sidebar_position = clamp_sidebar_width(root_paned.get_position());
            }
        });
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
        local_info_controller = new LocalInfoController(new WindowLocalInfoLogger(toolbox));
        local_info_presenter = new LocalInfoPresenter();
        app_state_store = new AppStateStore();
        app_transition_controller = new AppTransitionController(app_state_store);
        controller = new MainController(
            project_store,
            new GtkSingleSelectionState(project_selection),
            card_store,
            new GtkSingleSelectionState(card_selection),
            ai_thread_store,
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
        selection_controller = new SelectionController(controller);
        local_info_flow_controller = new LocalInfoFlowController(
            new WindowLocalInfoFlowContext(controller),
            local_info_controller
        );
        local_info_view_adapter = new LocalInfoViewAdapter(
            new WindowLocalInfoViewSink(this),
            local_info_presenter
        );
        print_service = new PrintService();
        recovery_controller = new RecoveryController(new WindowRecoveryContext(controller));
        ai_run_controller = new AiRunController(controller);
        flowboard_controller = new FlowboardController(project_store, project_selection, card_store);

        sidebar = new SidebarPane(project_selection, card_selection, ai_thread_selection);
        sidebar.card_move_to_trash_requested.connect((card_id) => {
            confirm_move_card_to_trash(card_id);
        });
        sidebar.card_context_selection_requested.connect((card_id) => {
            request_card_selection(card_id);
        });

        app_state_store.state_changed.connect(() => {
            apply_sidebar_from_state();
        });
        root_paned.set_start_child(sidebar.widget);
        root_paned.set_end_child(workspace.widget);
        root_paned.set_resize_start_child(true);
        root_paned.set_shrink_start_child(false);
        root_paned.set_position(last_sidebar_position);

        controller.status_changed.connect((text) => {
            set_status(text);
        });
        controller.editor_state_changed.connect((text, editable) => {
            set_editor_state(text, editable);
        });
        controller.window_title_changed.connect((title_text) => {
            update_window_title(title_text);
        });
        controller.toast_requested.connect((message) => {
            add_toast(message);
        });
        controller.error_reported.connect((title_text, details) => {
            show_error(title_text, details);
        });
        controller.show_editor_requested.connect(() => {
            show_editor_mode();
        });
        controller.show_search_requested.connect(() => {
            show_search_mode();
        });
        controller.search_summary_changed.connect((text) => {
            search_summary_label.set_text(text);
        });
        controller.ai_status_refresh_requested.connect(() => {
            ai_run_controller.refresh_status.begin();
        });
        controller.project_selection_requested.connect((project_id) => {
            request_project_selection(project_id);
        });
        controller.card_selection_requested.connect((card_id) => {
            request_card_selection(card_id);
        });
        controller.search_selection_requested.connect((position) => {
            request_search_selection(position);
        });
        controller.ai_thread_title_changed.connect((title_text) => {
            ai_panel.set_thread_title(title_text);
        });
        controller.ai_thread_selection_requested.connect((thread_id) => {
            request_ai_thread_selection(thread_id);
        });
        controller.api_client_ready.connect((api_client) => {
            ai_panel.set_api_client(api_client);
            ai_panel.refresh_catalog();
            toolbox.set_api_client(api_client);
        });
        controller.card_trashed.connect((_card_id) => {
            toolbox.refresh_trash();
        });

        workspace.refresh_requested.connect(() => {
            controller.reload_everything.begin();
        });
        workspace.new_project_requested.connect(() => {
            show_new_project_dialog();
        });
        workspace.new_card_requested.connect(() => {
            controller.create_card.begin();
        });
        workspace.explorer_panel_toggled.connect((visible) => {
            sidebar_visible = visible;
            if (visible) {
                root_paned.set_start_child(sidebar.widget);
                root_paned.set_position(clamp_sidebar_width(last_sidebar_position));
            } else {
                if (root_paned.get_position() > 0) {
                    last_sidebar_position = clamp_sidebar_width(root_paned.get_position());
                }
                root_paned.set_start_child(null);
            }
        });
        workspace.ai_panel_toggled.connect((visible) => {
            workspace.set_ai_panel_visible(visible);
            ai_run_controller.set_panel_visible(visible);
            if (visible) {
                ai_panel.refresh_catalog();
            }
        });
        workspace.toolbox_toggled.connect((visible) => {
            workspace.set_toolbox_visible(visible);
            if (visible) {
                toolbox.log_debug("Toolbox opened");
                toolbox.refresh_trash();
            } else {
                toolbox.log_debug("Toolbox closed");
            }
        });
        workspace.search_activated.connect(() => {
            controller.cancel_pending_search();
            controller.run_search.begin();
        });
        workspace.search_changed.connect(() => {
            var q = search_entry.get_text().strip();
            if (q.length == 0) {
                controller.cancel_pending_search();
                controller.clear_search_results();
                show_editor_mode();
                return;
            }
            controller.schedule_search();
        });
        workspace.search_cleared.connect(() => {
            search_entry.set_text("");
            controller.clear_search_results();
            show_editor_mode();
        });
        workspace.search_focus_results_requested.connect(() => {
            if (search_store.get_n_items() == 0) {
                return;
            }
            show_search_mode();
            if (search_selection.get_selected() == Gtk.INVALID_LIST_POSITION) {
                request_search_selection(0);
            }
            search_list.grab_focus();
        });
        workspace.search_result_activated.connect((position) => {
            handle_search_result_activation_intent.begin(position);
        });
        workspace.find_next_requested.connect(() => {
            var find_text = workspace.get_find_text().strip();
            if (find_text.length == 0) {
                add_toast("Enter text to find.");
                return;
            }
            perform_find_next(find_text);
        });
        workspace.replace_requested.connect(() => {
            var find_text = workspace.get_find_text().strip();
            if (find_text.length == 0) {
                add_toast("Enter text to find.");
                return;
            }
            perform_replace_next(find_text, workspace.get_replace_text());
        });
        workspace.replace_all_requested.connect(() => {
            var find_text = workspace.get_find_text().strip();
            if (find_text.length == 0) {
                add_toast("Enter text to find.");
                return;
            }
            perform_replace_all(find_text, workspace.get_replace_text());
        });

        project_selection.notify["selected"].connect(() => {
            if (is_applying_state()) {
                return;
            }
            handle_project_selection_intent.begin();
        });

        card_selection.notify["selected"].connect(() => {
            if (is_applying_state()) {
                return;
            }
            handle_card_selection_intent.begin();
        });

        ai_thread_selection.notify["selected"].connect(() => {
            if (is_applying_state()) {
                return;
            }
            handle_ai_thread_selection_intent();
        });

        editor_buffer.changed.connect(() => {
            if (suppress_editor_events || controller.get_current_card() == null) {
                return;
            }
            refresh_connections_internal_links_from_editor();
            controller.schedule_autosave();
        });

        var internal_link_click = new Gtk.GestureClick();
        internal_link_click.set_button(Gdk.BUTTON_PRIMARY);
        internal_link_click.pressed.connect((n_press, x, y) => {
            if (n_press != 1) {
                return;
            }
            var sequence = internal_link_click.get_current_sequence();
            var event = internal_link_click.get_last_event(sequence);
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
                internal_link_click.set_state(Gtk.EventSequenceState.CLAIMED);
            }
        });
        editor_view.add_controller(internal_link_click);

        var internal_link_key = new Gtk.EventControllerKey();
        internal_link_key.key_pressed.connect((keyval, keycode, state) => {
            if ((state & Gdk.ModifierType.CONTROL_MASK) == 0) {
                return false;
            }
            if (keyval != Gdk.Key.Return && keyval != Gdk.Key.KP_Enter) {
                return false;
            }
            Gtk.TextIter cursor;
            editor_buffer.get_iter_at_mark(out cursor, editor_buffer.get_insert());
            return navigate_internal_link_at_iter(cursor);
        });
        editor_view.add_controller(internal_link_key);

        ai_panel.send_requested.connect(() => {
            ai_run_controller.on_send_clicked(ai_panel.get_prompt_text());
        });
        ai_panel.new_thread_requested.connect(() => {
            ai_run_controller.create_thread_from_prompt.begin();
        });
        ai_panel.status_refresh_requested.connect(() => {
            ai_run_controller.refresh_status.begin();
        });
        ai_panel.error_reported.connect((title_text, details) => {
            show_error(title_text, details);
        });
        ai_panel.debug_log_requested.connect((line) => {
            toolbox.log_debug(line);
        });
        ai_panel.pull_model_requested.connect((model_tag) => {
            ai_run_controller.start_model_pull.begin(model_tag);
        });

        ai_run_controller.status_changed.connect((text) => {
            set_status(text);
        });
        ai_run_controller.error_reported.connect((title_text, details) => {
            show_error(title_text, details);
        });
        ai_run_controller.toast_requested.connect((message) => {
            add_toast(message);
        });
        ai_run_controller.render_status_requested.connect((capabilities, status) => {
            ai_panel.render_status(capabilities, status);
        });
        ai_run_controller.render_status_error_requested.connect((message) => {
            ai_panel.render_status_error(message);
        });
        ai_run_controller.append_output_requested.connect((role, text) => {
            ai_panel.append_output(role, text);
        });
        ai_run_controller.append_output_chunk_requested.connect((text) => {
            ai_panel.append_output_chunk(text);
        });
        ai_run_controller.clear_prompt_requested.connect(() => {
            ai_panel.clear_prompt();
        });
        ai_run_controller.set_send_enabled_requested.connect((enabled) => {
            ai_panel.set_send_enabled(enabled);
        });

        toolbox.error_reported.connect((title, details) => {
            show_error(title, details);
        });
        toolbox.toast_requested.connect((message) => {
            add_toast(message);
        });
        toolbox.breadcrumb_navigation_requested.connect((tool_id, segment_index, project_id, card_id) => {
            navigate_toolbox_breadcrumb.begin(tool_id, segment_index, project_id, card_id);
        });
        toolbox.flowboard_card_open_requested.connect((card_id) => {
            open_card_from_flowboard(card_id);
        });
        toolbox.connections_card_open_requested.connect((card_id) => {
            open_card_from_flowboard(card_id);
        });
        toolbox.flowboard_card_move_to_trash_requested.connect((card_id) => {
            confirm_move_card_to_trash(card_id);
        });
        toolbox.flowboard_move_intent_requested.connect((card_id, _project_id, intent, target_card_id, parent_card_id) => {
            controller.move_card_by_intent.begin(card_id, intent, target_card_id, parent_card_id);
        });
        toolbox.flowboard_new_card_requested.connect((parent_card_id) => {
            controller.create_card.begin(parent_card_id);
        });
        toolbox.send_card_as_email_requested.connect(() => {
            send_current_card_as_email();
        });
        toolbox.send_recovery_key_as_email_requested.connect(() => {
            request_recovery_key_pin(
                "Email Recovery Key",
                "Set a recovery key PIN to export and email your `.hrk` file.",
                (pin) => {
                    send_recovery_key_as_email.begin(pin);
                }
            );
        });
        toolbox.save_recovery_key_to_usb_requested.connect(() => {
            request_recovery_key_pin(
                "Save Recovery Key",
                "Set a recovery key PIN to export a `.hrk` file.",
                (pin) => {
                    save_recovery_key_to_usb.begin(pin);
                }
            );
        });
        toolbox.import_recovery_key_requested.connect(() => {
            import_recovery_key_from_file();
        });
        toolbox.terminal_copy_to_card_requested.connect((text) => {
            append_text_to_current_card(text);
        });
        toolbox.set_settings(settings);
        toolbox.bind_connections_context(project_selection, card_store, card_selection);
        toolbox.bind_flowboard_controller(flowboard_controller);
        card_store.items_changed.connect((position, removed, added) => {
            queue_flowboard_refresh();
        });
        flowboard_controller.project_overview_requested.connect((project_id) => {
            controller.show_project_overview_for.begin(project_id);
        });
        flowboard_controller.context_load_requested.connect((project_id, parent_card_id) => {
            flowboard_context_request_serial++;
            load_flowboard_context.begin(flowboard_context_request_serial, project_id, parent_card_id);
        });

        close_request.connect(() => {
            persist_window_state();
            return false;
        });

        if (start_maximized) {
            maximize();
        }

        controller.bootstrap.begin();
    }

    private void apply_sidebar_from_state() {
        var snapshot = app_state_store.selection;
        with_state_apply(() => {
            if (rendered_sidebar_data_version != app_state_store.data_version) {
                apply_sidebar_list_data_from_state();
                rendered_sidebar_data_version = app_state_store.data_version;
            }
            apply_project_selection_from_state(snapshot.project_id);
            apply_card_selection_from_state(snapshot.card_id);
            apply_ai_thread_selection_from_state(snapshot.ai_thread_id);
        });
    }

    private void apply_sidebar_list_data_from_state() {
        project_store.remove_all();
        foreach (var project in app_state_store.projects) {
            project_store.append(project);
        }

        card_store.remove_all();
        foreach (var card in app_state_store.cards) {
            card_store.append(card);
        }

        ai_thread_store.remove_all();
        foreach (var thread in app_state_store.ai_threads) {
            ai_thread_store.append(thread);
        }
    }

    private void apply_project_selection_from_state(string? project_id) {
        if (project_id == null || project_id.strip().length == 0) {
            if (project_selection.get_selected() != Gtk.INVALID_LIST_POSITION) {
                project_selection.set_selected(Gtk.INVALID_LIST_POSITION);
            }
            return;
        }

        for (uint i = 0; i < project_store.get_n_items(); i++) {
            var project = project_store.get_item(i) as Project;
            if (project != null && project.project_id == project_id) {
                if (project_selection.get_selected() != i) {
                    project_selection.set_selected(i);
                }
                return;
            }
        }

        if (project_selection.get_selected() != Gtk.INVALID_LIST_POSITION) {
            project_selection.set_selected(Gtk.INVALID_LIST_POSITION);
        }
    }

    private void apply_card_selection_from_state(string? card_id) {
        if (card_id == null || card_id.strip().length == 0) {
            if (card_selection.get_selected() != Gtk.INVALID_LIST_POSITION) {
                card_selection.set_selected(Gtk.INVALID_LIST_POSITION);
            }
            return;
        }

        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null && card.card_id == card_id) {
                if (card_selection.get_selected() != i) {
                    card_selection.set_selected(i);
                }
                return;
            }
        }

        if (card_selection.get_selected() != Gtk.INVALID_LIST_POSITION) {
            card_selection.set_selected(Gtk.INVALID_LIST_POSITION);
        }
    }

    private void apply_ai_thread_selection_from_state(string? thread_id) {
        if (thread_id == null || thread_id.strip().length == 0) {
            if (ai_thread_selection.get_selected() != Gtk.INVALID_LIST_POSITION) {
                ai_thread_selection.set_selected(Gtk.INVALID_LIST_POSITION);
            }
            return;
        }

        for (uint i = 0; i < ai_thread_store.get_n_items(); i++) {
            var thread = ai_thread_store.get_item(i) as AiThreadSummary;
            if (thread != null && thread.thread_id == thread_id) {
                if (ai_thread_selection.get_selected() != i) {
                    ai_thread_selection.set_selected(i);
                }
                return;
            }
        }

        if (ai_thread_selection.get_selected() != Gtk.INVALID_LIST_POSITION) {
            ai_thread_selection.set_selected(Gtk.INVALID_LIST_POSITION);
        }
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

    private async void navigate_toolbox_breadcrumb(string tool_id,
                                                   int segment_index,
                                                   string? project_id,
                                                   string? card_id) {
        var seq = app_transition_controller.begin(
            "toolbox-breadcrumb",
            project_id,
            card_id
        );
        toolbox.set_navigation_loading(true);
        try {
            if (segment_index == 0) {
                if (tool_id == "flowboard") {
                    toolbox.show_flowboard_projects_root();
                } else {
                    show_tool_help_page(tool_id);
                }
                return;
            }

            if (segment_index == 1) {
                if (project_id == null || project_id.strip().length == 0) {
                    return;
                }
                if (tool_id == "flowboard") {
                    toolbox.show_flowboard_project_root();
                    return;
                }
                yield controller.show_project_overview();
                return;
            }

            if (segment_index == 2) {
                if (card_id == null || card_id.strip().length == 0) {
                    return;
                }
                if (tool_id == "flowboard" || tool_id == "connections") {
                    open_card_from_flowboard(card_id);
                }
                return;
            }
        } finally {
            if (app_transition_controller.is_current(seq)) {
                toolbox.set_navigation_loading(false);
                app_transition_controller.finish(seq);
            }
        }
    }

    private async void handle_project_selection_intent() {
        var selected = project_selection.get_selected_item() as Project;
        var project_id = selected != null ? selected.project_id : null;
        var seq = app_transition_controller.begin("project-selection", project_id, null, null);
        toolbox.set_navigation_loading(true);
        try {
            app_transition_controller.commit_selection(seq, project_id, null, null);
            yield selection_controller.on_project_selected();
            if (!app_transition_controller.is_current(seq)) {
                return;
            }
            flowboard_controller.refresh();
        } finally {
            if (app_transition_controller.is_current(seq)) {
                toolbox.set_navigation_loading(false);
                app_transition_controller.finish(seq);
            }
        }
    }

    private async void handle_card_selection_intent() {
        var selected = card_selection.get_selected_item() as CardSummary;
        if (selected == null) {
            return;
        }
        var seq = app_transition_controller.begin("card-selection", selected.project_id, selected.card_id, null);
        toolbox.set_navigation_loading(true);
        try {
            app_transition_controller.commit_selection(seq, selected.project_id, selected.card_id, null);
            yield selection_controller.on_card_selected();
            if (!app_transition_controller.is_current(seq)) {
                return;
            }
        } finally {
            if (app_transition_controller.is_current(seq)) {
                toolbox.set_navigation_loading(false);
                app_transition_controller.finish(seq);
            }
        }
    }

    private async void handle_search_result_activation_intent(uint position) {
        var target_card_id = yield controller.prepare_search_result_card_at(position);
        var seq = app_transition_controller.begin(
            "search-result-activation",
            controller.selected_project_id(),
            target_card_id,
            null
        );
        toolbox.set_navigation_loading(true);
        try {
            if (target_card_id == null || target_card_id.strip().length == 0) {
                return;
            }
            var selected_card = select_card_in_sidebar_by_id(target_card_id);
            if (selected_card == null) {
                return;
            }
            app_transition_controller.commit_selection(
                seq,
                selected_card.project_id,
                selected_card.card_id,
                null
            );
            yield controller.load_selected_card();
            if (!app_transition_controller.is_current(seq)) {
                return;
            }
        } finally {
            if (app_transition_controller.is_current(seq)) {
                toolbox.set_navigation_loading(false);
                app_transition_controller.finish(seq);
            }
        }
    }

    private void handle_ai_thread_selection_intent() {
        var selected = ai_thread_selection.get_selected_item() as AiThreadSummary;
        var seq = app_transition_controller.begin(
            "ai-thread-selection",
            controller.selected_project_id(),
            controller.selected_card_id(),
            selected != null ? selected.thread_id : null
        );
        try {
            controller.on_ai_thread_selected();
            if (!app_transition_controller.is_current(seq)) {
                return;
            }
            app_transition_controller.commit_selection(
                seq,
                controller.selected_project_id(),
                controller.selected_card_id(),
                selected != null ? selected.thread_id : null
            );
        } finally {
            if (app_transition_controller.is_current(seq)) {
                app_transition_controller.finish(seq);
            }
        }
    }

    private void request_ai_thread_selection(string? thread_id) {
        if (thread_id == null || thread_id.strip().length == 0) {
            with_state_apply(() => {
                ai_thread_selection.set_selected(Gtk.INVALID_LIST_POSITION);
            });
            handle_ai_thread_selection_intent();
            return;
        }

        for (uint i = 0; i < ai_thread_store.get_n_items(); i++) {
            var thread = ai_thread_store.get_item(i) as AiThreadSummary;
            if (thread == null || thread.thread_id != thread_id) {
                continue;
            }
            with_state_apply(() => {
                ai_thread_selection.set_selected(i);
            });
            handle_ai_thread_selection_intent();
            return;
        }

        with_state_apply(() => {
            ai_thread_selection.set_selected(Gtk.INVALID_LIST_POSITION);
        });
        handle_ai_thread_selection_intent();
    }

    private void request_project_selection(string? project_id) {
        if (project_id == null || project_id.strip().length == 0) {
            with_state_apply(() => {
                project_selection.set_selected(Gtk.INVALID_LIST_POSITION);
            });
            return;
        }
        for (uint i = 0; i < project_store.get_n_items(); i++) {
            var project = project_store.get_item(i) as Project;
            if (project == null || project.project_id != project_id) {
                continue;
            }
            with_state_apply(() => {
                project_selection.set_selected(i);
            });
            return;
        }
    }

    private void request_card_selection(string? card_id) {
        if (card_id == null || card_id.strip().length == 0) {
            with_state_apply(() => {
                card_selection.set_selected(Gtk.INVALID_LIST_POSITION);
            });
            return;
        }
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null || card.card_id != card_id) {
                continue;
            }
            with_state_apply(() => {
                card_selection.set_selected(i);
            });
            return;
        }
    }

    private void request_search_selection(int position) {
        if (position < 0) {
            with_state_apply(() => {
                search_selection.set_selected(Gtk.INVALID_LIST_POSITION);
            });
            return;
        }

        var target = (uint) position;
        if (target >= search_store.get_n_items()) {
            with_state_apply(() => {
                search_selection.set_selected(Gtk.INVALID_LIST_POSITION);
            });
            return;
        }

        with_state_apply(() => {
            search_selection.set_selected(target);
        });
    }

    private async void load_flowboard_context(uint request_serial,
                                              string project_id,
                                              string? parent_card_id) {
        var api = controller.get_api_client();
        if (api == null) {
            return;
        }
        try {
            var context = yield api.get_card_context(project_id, parent_card_id);
            if (request_serial != flowboard_context_request_serial) {
                return;
            }
            flowboard_controller.apply_card_context(project_id, parent_card_id, context);
        } catch (Error e) {
            warning("Flowboard context load failed for %s: %s", project_id, e.message);
        }
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

    construct {
        var refresh_action = new SimpleAction("refresh", null);
        refresh_action.activate.connect(() => {
            controller.reload_everything.begin();
        });
        add_action(refresh_action);

        var new_project_action = new SimpleAction("new-project", null);
        new_project_action.activate.connect(() => {
            show_new_project_dialog();
        });
        add_action(new_project_action);

        var new_card_action = new SimpleAction("new-card", null);
        new_card_action.activate.connect(() => {
            controller.create_card.begin();
        });
        add_action(new_card_action);

        var toggle_toolbox_action = new SimpleAction("toggle-toolbox", null);
        toggle_toolbox_action.activate.connect(() => {
            workspace.toggle_toolbox();
        });
        add_action(toggle_toolbox_action);

        var find_replace_action = new SimpleAction("find-replace", null);
        find_replace_action.activate.connect(() => {
            workspace.show_find_replace_bar(true);
        });
        add_action(find_replace_action);

        var print_action = new SimpleAction("print", null);
        print_action.activate.connect(() => {
            print_current_card.begin();
        });
        add_action(print_action);

        register_local_info_action();

        var show_preferences_action = new SimpleAction("show-preferences", null);
        show_preferences_action.activate.connect(() => {
            show_preferences_dialog();
        });
        add_action(show_preferences_action);

        var show_about_action = new SimpleAction("show-about", null);
        show_about_action.activate.connect(() => {
            show_about_dialog();
        });
        add_action(show_about_action);
    }

    private void register_local_info_action() {
        var show_local_info_action = new SimpleAction("show-local-info", null);
        show_local_info_action.activate.connect(() => {
            show_local_info_page.begin();
        });
        add_action(show_local_info_action);
    }


    private void show_new_project_dialog() {
        var dialog = new Adw.MessageDialog(
            this,
            "New Project",
            "Enter a project name."
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("create", "Create");
        dialog.set_response_appearance("create", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("create");
        dialog.set_close_response("cancel");

        var entry = new Gtk.Entry();
        entry.set_placeholder_text("Project name");
        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        content.append(entry);

        var chooser_label = new Gtk.Label("Choose project visibility");
        chooser_label.set_halign(Gtk.Align.CENTER);
        content.append(chooser_label);

        var privacy_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        privacy_row.set_halign(Gtk.Align.CENTER);
        var private_btn = new Gtk.CheckButton.with_label("Private");
        var shared_btn = new Gtk.CheckButton.with_label("Shared");
        shared_btn.set_group(private_btn);
        private_btn.set_active(true);
        privacy_row.append(private_btn);
        privacy_row.append(shared_btn);
        content.append(privacy_row);

        var help = new Gtk.Label(
            "A private project is encrypted, only you can read it.\n\n" +
            "A shared project is useful for collaboration. You must be very careful not store sensitive information (passwords, personal data, private notes)."
        );
        help.set_xalign(0.0f);
        help.set_wrap(true);
        help.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        help.add_css_class("dim-label");
        content.append(help);

        dialog.set_extra_child(content);

        dialog.response.connect((response) => {
            if (response == "create") {
                var name = entry.get_text().strip();
                if (name.length == 0) {
                    show_error("Project name required", "Please enter a non-empty project name.");
                } else {
                    var privacy_mode = private_btn.get_active() ? "encrypted_git" : "plain";
                    create_project_named.begin(name, privacy_mode);
                }
            }
            dialog.close();
        });

        dialog.present();
    }

    private async void create_project_named(string name, string privacy_mode = "encrypted_git") {
        yield controller.create_project_named(name, privacy_mode);
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
        suppress_editor_events = true;
        workspace.set_editor_state(text, editable);
        suppress_editor_events = false;
        refresh_connections_internal_links_from_editor();
    }

    internal void update_window_title(string title_text) {
        workspace.set_window_title_text(title_text);
        title = title_text;
    }

    private void add_toast(string msg) {
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
        workspace.show_editor_mode();
    }

    private void show_search_mode() {
        workspace.show_search_mode();
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

    private void open_card_from_flowboard(string card_id) {
        open_card_with_transition.begin(card_id, "tool-card-open");
    }

    private async void open_card_with_transition(string card_id, string reason) {
        var selected_card = select_card_in_sidebar_by_id(card_id);
        if (selected_card == null) {
            return;
        }
        var seq = app_transition_controller.begin(reason, selected_card.project_id, selected_card.card_id, null);
        toolbox.set_navigation_loading(true);
        try {
            app_transition_controller.commit_selection(
                seq,
                selected_card.project_id,
                selected_card.card_id,
                null
            );
            yield controller.load_selected_card();
            if (!app_transition_controller.is_current(seq)) {
                return;
            }
        } finally {
            if (app_transition_controller.is_current(seq)) {
                toolbox.set_navigation_loading(false);
                app_transition_controller.finish(seq);
            }
        }
    }

    private CardSummary? select_card_in_sidebar_by_id(string card_id) {
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null || card.card_id != card_id) {
                continue;
            }
            with_state_apply(() => {
                card_selection.set_selected(i);
            });
            return card;
        }
        return null;
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

    private void show_tool_help_page(string tool_id) {
        string title;
        switch (tool_id) {
        case "flowboard":
            title = "Flowboard";
            break;
        case "connections":
            title = "Connections";
            break;
        case "resources":
            title = "Resources";
            break;
        case "sharing":
            title = "Sharing";
            break;
        case "terminals":
            title = "Terminals";
            break;
        case "git":
            title = "Git Sync";
            break;
        case "recovery":
            title = "Recovery Key";
            break;
        case "trash":
            title = "Trash";
            break;
        case "debug":
            title = "Debug";
            break;
        default:
            var readable = tool_id.replace("-", " ").replace("_", " ");
            if (readable.strip().length == 0) {
                title = "Tool Help";
            } else {
                title = readable.substring(0, 1).up() + readable.substring(1);
            }
            break;
        }

        string markdown;
        string resource_path = "/io/holder/linux/help/toolbox/%s.md".printf(tool_id);
        try {
            var bytes = resources_lookup_data(resource_path, ResourceLookupFlags.NONE);
            markdown = (string) bytes.get_data();
        } catch (Error e) {
            markdown = "# %s\n\nHelp page resource missing: %s".printf(title, e.message);
        }
        set_editor_state(markdown, false);
        update_window_title(title);
        show_editor_mode();
        set_status("Loaded %s help.".printf(title));
    }

    private void confirm_move_card_to_trash(string card_id) {
        if (card_id.strip().length == 0) {
            return;
        }

        var title_text = card_title_for_id(card_id);
        var dialog = new Adw.MessageDialog(
            this,
            "Move to Trash",
            "Move \"%s\" to Trash?\n\nYou can restore it from the Trash tool.".printf(title_text)
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("trash", "Move to Trash");
        dialog.set_response_appearance("trash", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("trash");
        dialog.set_close_response("cancel");
        dialog.response.connect((response) => {
            if (response == "trash") {
                controller.move_card_to_trash.begin(card_id);
            }
            dialog.close();
        });
        dialog.present();
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
        if (cursor_byte_offset < 0) {
            return null;
        }
        if (cursor_byte_offset > line_text.length) {
            cursor_byte_offset = line_text.length;
        }

        var search_upto = line_text.substring(0, cursor_byte_offset);
        int open_pos = search_upto.last_index_of("[[");
        if (open_pos < 0 && cursor_byte_offset < line_text.length) {
            search_upto = line_text.substring(0, cursor_byte_offset + 1);
            open_pos = search_upto.last_index_of("[[");
        }
        if (open_pos < 0) {
            return null;
        }

        int close_pos = line_text.index_of("]]", open_pos + 2);
        if (close_pos < 0) {
            return null;
        }

        if (cursor_byte_offset < open_pos || cursor_byte_offset > close_pos + 2) {
            return null;
        }

        var raw_target = line_text.substring(open_pos + 2, close_pos - (open_pos + 2));
        var target = raw_target.strip();
        return target.length > 0 ? target : null;
    }

    private string? resolve_internal_link_target_card_id(string target) {
        var project_id = controller.selected_project_id();
        if (project_id == null || target.length == 0) {
            return null;
        }

        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null || card.project_id != project_id) {
                continue;
            }
            if (card.card_id == target) {
                return card.card_id;
            }
        }

        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null || card.project_id != project_id) {
                continue;
            }
            if (card.title == target) {
                return card.card_id;
            }
        }

        var lowered_target = target.down();
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null || card.project_id != project_id) {
                continue;
            }
            if (card.title.down() == lowered_target) {
                return card.card_id;
            }
        }

        return null;
    }

    private bool navigate_internal_link_at_iter(Gtk.TextIter iter) {
        var target = internal_link_target_at_iter(iter);
        if (target == null) {
            return false;
        }

        var card_id = resolve_internal_link_target_card_id(target);
        if (card_id == null) {
            add_toast("No card matches [[%s]].".printf(target));
            var target_copy = target;
            Idle.add(() => {
                show_create_internal_link_card_dialog(target_copy);
                return Source.REMOVE;
            });
            return true;
        }

        open_card_from_flowboard(card_id);
        return true;
    }

    private void show_create_internal_link_card_dialog(string target) {
        var dialog = new Adw.MessageDialog(
            this,
            "Create Linked Card?",
            "No card matches [[%s]] in this project.".printf(target)
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("create", "Create Card");
        dialog.set_response_appearance("create", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("create");
        dialog.set_close_response("cancel");

        dialog.response.connect((response) => {
            if (response == "create") {
                controller.create_card_with_title.begin(target);
            }
            dialog.close();
        });

        dialog.present();
    }

    private void show_preferences_dialog() {
        var dialog = new PreferencesDialog(editor_buffer, editor_view, spelling_adapter, settings);
        dialog.present(this);
    }

    private void send_current_card_as_email() {
        var card = controller.get_current_card();
        if (card == null) {
            add_toast("Select a card first.");
            return;
        }

        Gtk.TextIter start;
        Gtk.TextIter end;
        editor_buffer.get_bounds(out start, out end);
        var body_text = editor_buffer.get_text(start, end, false);
        var subject = Uri.escape_string(card.title, null, false);
        var body = Uri.escape_string(body_text, null, false);
        var mailto_uri = "mailto:?subject=%s&body=%s".printf(subject, body);
        try {
            AppInfo.launch_default_for_uri(mailto_uri, null);
            add_toast("Opened default email app.");
        } catch (Error e) {
            show_error("Email share failed", e.message);
        }
    }

    private void request_recovery_key_pin(string title,
                                          string body,
                                          owned RecoveryPinHandler on_pin) {
        var dialog = new Adw.MessageDialog(this, title, body);
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("continue", "Continue");
        dialog.set_response_appearance("continue", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("continue");
        dialog.set_close_response("cancel");

        var pin_entry = new Gtk.Entry();
        pin_entry.set_placeholder_text("PIN");
        pin_entry.set_input_purpose(Gtk.InputPurpose.PASSWORD);
        pin_entry.set_visibility(false);
        pin_entry.set_activates_default(true);

        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        var pin_label = new Gtk.Label("PIN") { xalign = 0.0f };
        content.append(pin_label);
        content.append(pin_entry);
        dialog.set_extra_child(content);

        dialog.response.connect((response) => {
            if (response != "continue") {
                dialog.close();
                return;
            }
            var pin = pin_entry.get_text().strip();
            if (pin.length == 0) {
                add_toast("PIN is required.");
                return;
            }
            on_pin(pin);
            dialog.close();
        });
        dialog.present();
    }

    private async void send_recovery_key_as_email(string pin) {
        var project = controller.get_current_project();
        if (project == null) {
            add_toast("Select a project first.");
            return;
        }
        try {
            var payload = yield recovery_controller.export_recovery_token(project.project_id, pin);
            var attachment_path = recovery_controller.write_payload_to_temp_attachment(project.name, payload);
            recovery_controller.open_email_with_attachment(attachment_path);
            add_toast("Opened default email app with recovery key attachment.");
        } catch (Error e) {
            show_error("Recovery key email failed", e.message);
        }
    }

    private async void save_recovery_key_to_usb(string pin) {
        var project = controller.get_current_project();
        if (project == null) {
            add_toast("Select a project first.");
            return;
        }
        string payload;
        try {
            payload = yield recovery_controller.export_recovery_token(project.project_id, pin);
        } catch (Error e) {
            show_error("Recovery key export failed", e.message);
            return;
        }

        var dialog = new Gtk.FileDialog();
        dialog.set_title("Save Recovery Key");
        dialog.set_initial_name(recovery_controller.build_default_filename(project.name));
        dialog.save.begin(this, null, (obj, res) => {
            try {
                var file = dialog.save.end(res);
                if (file == null) {
                    return;
                }
                var path = file.get_path();
                if (path == null || path.strip().length == 0) {
                    show_error("Recovery key export failed", "Please choose a local filesystem path.");
                    return;
                }
                recovery_controller.save_payload_to_path(path, payload);
                add_toast("Saved recovery key.");
            } catch (IOError.CANCELLED e) {
                // User cancelled.
            } catch (Error e) {
                show_error("Recovery key export failed", e.message);
            }
        });
    }

    private void import_recovery_key_from_file() {
        var dialog = new Gtk.FileDialog();
        dialog.set_title("Import Recovery Key");
        dialog.open.begin(this, null, (obj, res) => {
            try {
                var file = dialog.open.end(res);
                if (file == null) {
                    return;
                }
                var path = file.get_path();
                if (path == null || path.strip().length == 0) {
                    show_error("Recovery key import failed", "Please choose a local filesystem path.");
                    return;
                }
                var recovery_token = recovery_controller.load_payload_from_path(path);
                request_recovery_key_pin(
                    "Unlock Recovery Key",
                    "Set your recovery key PIN to unlock and import this `.hrk` file.",
                    (pin) => {
                        import_recovery_key_payload.begin(pin, recovery_token);
                    }
                );
            } catch (IOError.CANCELLED e) {
                // User cancelled.
            } catch (Error e) {
                show_error("Recovery key import failed", e.message);
            }
        });
    }

    private async void import_recovery_key_payload(string pin, string recovery_token) {
        RecoveryTokenImportResult result;
        try {
            result = yield recovery_controller.import_recovery_token(pin, recovery_token);
        } catch (Error e) {
            show_error("Recovery key import failed", e.message);
            return;
        }

        show_recovery_import_summary(result);
        add_toast("Recovery key imported.");
    }

    private void show_recovery_import_summary(RecoveryTokenImportResult result) {
        var project_created_text = result.project_created ? "yes" : "no";
        var remote_hint_text = result.remote_hint_present ? "yes" : "no";
        var remote_configured_text = result.remote_configured ? "yes" : "no";
        var pull_status_text = result.pull_status.length > 0 ? result.pull_status : "not_attempted";
        var pull_error_text = result.pull_error.length > 0 ? result.pull_error : "none";
        var remote_error_text = result.remote_error.length > 0 ? result.remote_error : "none";

        var body = "Project ID: %s\n".printf(result.project_id) +
                   "Project created: %s\n".printf(project_created_text) +
                   "Remote hint in key: %s\n".printf(remote_hint_text) +
                   "Remote configured: %s\n".printf(remote_configured_text) +
                   "Pull status: %s\n".printf(pull_status_text) +
                   "Pull error: %s\n".printf(pull_error_text) +
                   "Remote error: %s".printf(remote_error_text);

        var dialog = new Adw.MessageDialog(
            this,
            "Recovery Key Imported",
            body
        );
        dialog.add_response("ok", "OK");
        dialog.set_default_response("ok");
        dialog.set_close_response("ok");
        dialog.present();
    }

    private void append_text_to_current_card(string text) {
        var card = controller.get_current_card();
        if (card == null) {
            add_toast("Select a card first.");
            return;
        }
        if (text == null || text.length == 0) {
            add_toast("Nothing to copy.");
            return;
        }

        Gtk.TextIter end_iter;
        editor_buffer.get_end_iter(out end_iter);
        Gtk.TextIter start_iter;
        editor_buffer.get_start_iter(out start_iter);
        var existing = editor_buffer.get_text(
            start_iter,
            end_iter,
            false
        );

        var needs_gap = existing.length > 0 && !existing.has_suffix("\n");
        var prefix = needs_gap ? "\n\n" : "\n";
        var insert_text = "%s%s".printf(prefix, text);
        editor_buffer.insert(ref end_iter, insert_text, -1);
        show_editor_mode();
        add_toast("Copied terminal output into card.");
    }

    private GtkSource.SearchContext create_search_context(string find_text) {
        var search_settings = new GtkSource.SearchSettings();
        search_settings.set_case_sensitive(false);
        search_settings.set_regex_enabled(false);
        search_settings.set_wrap_around(true);
        search_settings.set_search_text(find_text);
        return new GtkSource.SearchContext(editor_buffer, search_settings);
    }

    private bool find_match(GtkSource.SearchContext context, out Gtk.TextIter match_start, out Gtk.TextIter match_end) {
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

    private void perform_find_next(string find_text) {
        var context = create_search_context(find_text);
        Gtk.TextIter match_start;
        Gtk.TextIter match_end;
        if (!find_match(context, out match_start, out match_end)) {
            add_toast("No match found.");
            return;
        }
        editor_buffer.select_range(match_start, match_end);
        workspace.editor_view.scroll_to_iter(match_start, 0.1, false, 0, 0);
    }

    private void perform_replace_next(string find_text, string replace_text) {
        var context = create_search_context(find_text);
        Gtk.TextIter match_start;
        Gtk.TextIter match_end;
        if (!find_match(context, out match_start, out match_end)) {
            add_toast("No match found.");
            return;
        }
        try {
            context.replace(match_start, match_end, replace_text, -1);
            add_toast("Replaced one match.");
        } catch (Error e) {
            show_error("Replace failed", e.message);
            return;
        }
        perform_find_next(find_text);
    }

    private void perform_replace_all(string find_text, string replace_text) {
        var context = create_search_context(find_text);
        try {
            var replaced = context.replace_all(replace_text, -1);
            add_toast("Replaced %u matches.".printf(replaced));
        } catch (Error e) {
            show_error("Replace all failed", e.message);
        }
    }

    private async void print_current_card() {
        Gtk.TextIter start;
        Gtk.TextIter end;
        editor_buffer.get_bounds(out start, out end);
        var text = editor_buffer.get_text(start, end, false);
        try {
            yield print_service.print_text(this, text);
        } catch (Error e) {
            if (e.message == "Nothing to print.") {
                add_toast("Nothing to print.");
                return;
            }
            show_error("Print failed", e.message);
        }
    }

    private async void show_local_info_page() {
        var result = yield local_info_flow_controller.load();
        switch (result.state) {
        case LocalInfoLoadState.NOT_CONNECTED:
            local_info_view_adapter.render_not_connected();
            break;
        case LocalInfoLoadState.SUCCESS:
            local_info_view_adapter.render_success(result.markdown);
            break;
        case LocalInfoLoadState.FAILURE:
            local_info_view_adapter.render_failure(result.error_details);
            break;
        }
    }

    private void show_about_dialog() {
        var about = new Gtk.AboutDialog();
        about.set_transient_for(this);
        about.set_modal(true);
        about.set_program_name("Holder");
        about.set_version("0.1.0");
        about.set_comments("Holder Linux frontend");
        about.set_website("https://github.com/HolderTeam");
        about.present();
    }

    private void refresh_connections_internal_links_from_editor() {
        Gtk.TextIter start;
        Gtk.TextIter end;
        editor_buffer.get_bounds(out start, out end);
        var text = editor_buffer.get_text(start, end, false);
        var links = extract_internal_links(text);
        toolbox.set_connections_internal_links(links);
    }

    private Gee.ArrayList<string> extract_internal_links(string text) {
        var results = new Gee.ArrayList<string>();
        if (text == null || text.length == 0) {
            return results;
        }
        var seen = new Gee.HashSet<string>();
        try {
            var regex = new Regex("\\[\\[([^\\]\\n]+)\\]\\]");
            MatchInfo match_info;
            if (!regex.match(text, 0, out match_info)) {
                return results;
            }
            do {
                var target = match_info.fetch(1).strip();
                if (target.length == 0 || seen.contains(target)) {
                    continue;
                }
                seen.add(target);
                results.add(target);
            } while (match_info.next());
        } catch (RegexError e) {
            toolbox.log_debug("Internal links parse failed: %s".printf(e.message));
        }
        return results;
    }

    protected override void dispose() {
        ai_run_controller.stop();
        base.dispose();
    }

}

}
