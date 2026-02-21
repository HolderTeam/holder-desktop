namespace HolderLinux {

public class MainWindow : Adw.ApplicationWindow {
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
    private Gtk.SearchEntry search_entry;
    private Gtk.Label search_summary_label;
    private Gtk.SingleSelection search_selection;
    private Gtk.ListView search_list;
    private SidebarPane sidebar;
    private Adw.OverlaySplitView ai_split;
    private AiPanel ai_panel;
    private ToolboxPane toolbox;
    private MainController controller;
    private AiRunController ai_run_controller;

    private bool suppress_editor_events = false;

    public MainWindow(Adw.Application app) {
        Object(
            application: app,
            default_width: 1200,
            default_height: 800,
            title: "Holder"
        );

        project_store = new GLib.ListStore(typeof(Project));
        project_selection = new Gtk.SingleSelection(project_store);

        card_store = new GLib.ListStore(typeof(CardSummary));
        card_selection = new Gtk.SingleSelection(card_store);
        ai_thread_store = new GLib.ListStore(typeof(AiThreadSummary));
        ai_thread_selection = new Gtk.SingleSelection(ai_thread_store);
        search_store = new GLib.ListStore(typeof(SearchCardResult));

        var root_split = new Adw.OverlaySplitView();
        root_split.set_sidebar_position(Gtk.PackType.START);

        toast_overlay = new Adw.ToastOverlay();
        toast_overlay.set_child(root_split);
        set_content(toast_overlay);

        workspace = new WorkspacePane(search_store);
        editor_buffer = workspace.editor_buffer;
        search_entry = workspace.search_entry;
        search_summary_label = workspace.search_summary_label;
        search_selection = workspace.search_selection;
        search_list = workspace.search_list;
        ai_split = workspace.ai_split;
        ai_panel = workspace.ai_panel;
        toolbox = workspace.toolbox;
        controller = new MainController(
            project_store,
            new GtkSingleSelectionState(project_selection),
            card_store,
            new GtkSingleSelectionState(card_selection),
            ai_thread_store,
            new GtkSingleSelectionState(ai_thread_selection),
            search_store,
            new GtkSingleSelectionState(search_selection),
            new SearchEntryTextProvider(search_entry),
            new SourceBufferTextProvider(editor_buffer),
            new DefaultApiFactory(),
            new FileServerDiscovery()
        );
        ai_run_controller = new AiRunController(controller);

        sidebar = new SidebarPane(project_selection, card_selection, ai_thread_selection);
        root_split.set_sidebar(sidebar.widget);
        root_split.set_content(workspace.widget);
        root_split.set_show_sidebar(true);

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
        controller.ai_thread_title_changed.connect((title_text) => {
            ai_panel.set_thread_title(title_text);
        });
        controller.api_client_ready.connect((api_client) => {
            toolbox.set_api_client(api_client);
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
        workspace.ai_panel_toggled.connect((visible) => {
            ai_split.set_show_sidebar(visible);
            ai_run_controller.set_panel_visible(visible);
        });
        workspace.toolbox_toggled.connect((visible) => {
            toolbox.set_reveal_child(visible);
            if (visible) {
                toolbox.log_debug("Toolbox opened");
                toolbox.refresh_ai_catalog.begin();
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
                search_selection.set_selected(0);
            }
            search_list.grab_focus();
        });
        workspace.search_result_activated.connect((position) => {
            controller.open_search_result_at.begin(position);
        });

        project_selection.notify["selected"].connect(() => {
            if (controller.should_ignore_project_selection_events()) {
                return;
            }
            controller.on_project_selected();
        });

        card_selection.notify["selected"].connect(() => {
            if (controller.should_ignore_card_selection_events()) {
                return;
            }
            controller.on_card_selected();
        });

        ai_thread_selection.notify["selected"].connect(() => {
            controller.on_ai_thread_selected();
        });

        editor_buffer.changed.connect(() => {
            if (suppress_editor_events || controller.get_current_card() == null) {
                return;
            }
            controller.schedule_autosave();
        });
        ai_panel.send_requested.connect(() => {
            ai_run_controller.on_send_clicked(ai_panel.get_prompt_text());
        });
        ai_panel.new_thread_requested.connect(() => {
            ai_run_controller.create_thread_from_prompt.begin();
        });
        ai_panel.status_refresh_requested.connect(() => {
            ai_run_controller.refresh_status.begin();
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

        controller.bootstrap.begin();
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
        dialog.set_extra_child(entry);

        dialog.response.connect((response) => {
            if (response == "create") {
                var name = entry.get_text().strip();
                if (name.length == 0) {
                    show_error("Project name required", "Please enter a non-empty project name.");
                } else {
                    create_project_named.begin(name);
                }
            }
            dialog.close();
        });

        dialog.present();
    }

    private async void create_project_named(string name) {
        yield controller.create_project_named(name);
    }

    private void set_status(string text) {
        if (sidebar != null) {
            sidebar.set_status_text(text);
        }
        if (toolbox != null) {
            toolbox.log_debug("STATUS: %s".printf(text));
        }
    }

    private void set_editor_state(string text, bool editable) {
        suppress_editor_events = true;
        workspace.set_editor_state(text, editable);
        suppress_editor_events = false;
    }

    private void update_window_title(string title_text) {
        workspace.set_window_title_text(title_text);
        title = title_text;
    }

    private void add_toast(string msg) {
        toast_overlay.add_toast(new Adw.Toast(msg));
    }

    private void show_error(string title_text, string details) {
        set_status("%s: %s".printf(title_text, details));
        add_toast("%s".printf(title_text));
        if (toolbox != null) {
            toolbox.log_debug("ERROR: %s | %s".printf(title_text, details));
        }
    }

    private void show_editor_mode() {
        workspace.show_editor_mode();
    }

    private void show_search_mode() {
        workspace.show_search_mode();
    }

    protected override void dispose() {
        ai_run_controller.stop();
        base.dispose();
    }

}

}
