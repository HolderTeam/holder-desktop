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

    private bool suppress_editor_events = false;
    private bool ai_run_in_flight = false;
    private uint ai_poll_id = 0;
    private const uint AI_POLL_INTERVAL_MS = 2000;

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
            project_selection,
            card_store,
            card_selection,
            ai_thread_store,
            ai_thread_selection,
            search_store,
            search_selection,
            search_entry,
            editor_buffer
        );

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
            refresh_ai_panel.begin();
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
            if (visible) {
                refresh_ai_panel.begin();
            } else {
                stop_ai_polling();
            }
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
            on_ai_send_clicked();
        });
        ai_panel.new_thread_requested.connect(() => {
            create_ai_thread_from_prompt.begin();
        });
        ai_panel.status_refresh_requested.connect(() => {
            refresh_ai_panel.begin();
        });
        ai_panel.pull_model_requested.connect((model_tag) => {
            start_model_pull.begin(model_tag);
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
    }

    private async void refresh_ai_panel() {
        var api = controller.get_api_client();
        if (api == null) {
            return;
        }

        var project_id = selected_project_id();
        try {
            var capabilities = yield api.get_ai_capabilities(project_id);
            var status = yield api.get_ai_status();
            ai_panel.render_status(capabilities, status);
            update_ai_polling(status.active_pull_jobs > 0);
        } catch (Error e) {
            ai_panel.render_status_error(e.message);
            stop_ai_polling();
        }
    }

    private void on_ai_send_clicked() {
        if (ai_run_in_flight) {
            set_status("AI run already in progress...");
            return;
        }
        var prompt = ai_panel.get_prompt_text().strip();
        if (prompt.length == 0) {
            show_error("Prompt required", "Type a prompt before sending.");
            return;
        }
        if (controller.get_current_project() == null) {
            show_error("No project selected", "Select a project before using the assistant.");
            return;
        }
        if (controller.get_current_ai_thread() == null) {
            create_ai_thread_named.begin("Thread %s".printf(now_epoch_seconds().to_string()), true);
            return;
        }

        send_prompt_to_ai.begin(prompt);
    }

    private async void send_prompt_to_ai(string prompt) {
        var api = controller.get_api_client();
        var current_project = controller.get_current_project();
        var current_ai_thread = controller.get_current_ai_thread();
        var current_card = controller.get_current_card();
        if (api == null || current_project == null || current_ai_thread == null) {
            show_error("Cannot run AI", "Missing API, project, or thread context.");
            return;
        }

        ai_panel.append_output("You", prompt);
        ai_panel.clear_prompt();
        ai_panel.append_output("Assistant", "");

        ai_run_in_flight = true;
        ai_panel.set_send_enabled(false);
        set_status("Running AI...");
        try {
            var context_card_id = current_card != null ? current_card.card_id : null;
            var context_card_title = current_card != null ? current_card.title : null;
            var context_card_body = current_card != null ? current_card.content : null;
            yield api.run_ai_stream(
                prompt,
                current_project.project_id,
                current_ai_thread.thread_id,
                context_card_id,
                context_card_title,
                context_card_body,
                (event_name, data) => {
                    handle_ai_run_event(event_name, data);
                }
            );
            ai_panel.append_output_chunk("\n");
            set_status("AI run complete");
        } catch (Error e) {
            ai_panel.append_output("System", "AI run failed: %s".printf(e.message));
            show_error("AI run failed", e.message);
        } finally {
            ai_run_in_flight = false;
            ai_panel.set_send_enabled(true);
            refresh_ai_panel.begin();
        }
    }

    private async void create_ai_thread_from_prompt() {
        create_ai_thread_named.begin("Thread %s".printf(now_epoch_seconds().to_string()), false);
    }

    private async void create_ai_thread_named(string title, bool continue_send) {
        var current_project = controller.get_current_project();
        if (current_project == null) {
            show_error("Cannot create thread", "No project/API context.");
            return;
        }
        try {
            var thread_id = yield controller.create_ai_thread(title);
            yield reload_ai_threads_for_project(current_project.project_id);
            if (thread_id.length > 0) {
                select_ai_thread_by_id(thread_id);
            }
            add_toast("Created AI thread");
            if (continue_send) {
                on_ai_send_clicked();
            }
        } catch (Error e) {
            show_error("Failed to create AI thread", e.message);
        }
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

    private async void reload_ai_threads_for_project(string project_id) {
        yield controller.reload_ai_threads_for_project(project_id);
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

    private void update_ai_polling(bool should_poll) {
        if (!ai_split.get_show_sidebar()) {
            stop_ai_polling();
            return;
        }
        if (should_poll) {
            start_ai_polling();
        } else {
            stop_ai_polling();
        }
    }

    private void start_ai_polling() {
        if (ai_poll_id != 0) {
            return;
        }
        ai_poll_id = Timeout.add(AI_POLL_INTERVAL_MS, () => {
            if (!ai_split.get_show_sidebar()) {
                ai_poll_id = 0;
                return Source.REMOVE;
            }
            refresh_ai_panel.begin();
            return Source.CONTINUE;
        });
    }

    private void stop_ai_polling() {
        if (ai_poll_id == 0) {
            return;
        }
        Source.remove(ai_poll_id);
        ai_poll_id = 0;
    }

    protected override void dispose() {
        stop_ai_polling();
        base.dispose();
    }

    private string? selected_project_id() {
        return controller.selected_project_id();
    }

    private bool select_ai_thread_by_id(string thread_id) {
        return controller.select_ai_thread_by_id(thread_id);
    }

    private void handle_ai_run_event(string event_name, Json.Object data) {
        switch (event_name) {
            case "chunk":
                ai_panel.append_output_chunk(json_string_member_or_empty(data, "delta"));
                break;
            case "progress":
                var message = json_string_member_or_empty(data, "message");
                if (message.length > 0) {
                    ai_panel.append_output("System", message);
                }
                break;
            case "fallback":
                var model = json_string_member_or_empty(data, "model");
                var error = json_string_member_or_empty(data, "error");
                var detail = model.length > 0 ? "Fallback from %s".printf(model) : "Fallback";
                if (error.length > 0) {
                    detail += ": " + error;
                }
                ai_panel.append_output("System", detail);
                break;
            case "failed":
                var failed = json_string_member_or_empty(data, "error");
                ai_panel.append_output("System", failed.length > 0 ? failed : "Run failed.");
                break;
            case "done":
                var model_done = json_string_member_or_empty(data, "model");
                if (model_done.length > 0) {
                    ai_panel.append_output("System", "Completed with %s".printf(model_done));
                }
                break;
            default:
                break;
        }
    }

    private string json_string_member_or_empty(Json.Object obj, string key) {
        if (!obj.has_member(key)) {
            return "";
        }
        var node = obj.get_member(key);
        if (node == null || node.get_node_type() == Json.NodeType.NULL) {
            return "";
        }
        return obj.get_string_member(key);
    }

    private async void start_model_pull(string model_tag) {
        var api = controller.get_api_client();
        if (api == null) {
            return;
        }

        set_status("Starting pull for %s...".printf(model_tag));
        try {
            var job_id = yield api.start_ai_runner_pull(model_tag);
            add_toast("Started pull: %s".printf(model_tag));
            if (job_id.length > 0) {
                set_status("Pull job started: %s".printf(job_id));
            } else {
                set_status("Pull started: %s".printf(model_tag));
            }
            refresh_ai_panel.begin();
        } catch (Error e) {
            show_error("Failed to start model pull", e.message);
        }
    }

    private int64 now_epoch_seconds() {
        return new DateTime.now_utc().to_unix();
    }

}

}
