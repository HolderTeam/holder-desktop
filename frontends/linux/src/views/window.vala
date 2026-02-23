namespace HolderLinux {

public class MainWindow : Adw.ApplicationWindow {
    private const int DEFAULT_WINDOW_WIDTH = 1200;
    private const int DEFAULT_WINDOW_HEIGHT = 800;
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
    private Adw.OverlaySplitView ai_split;
    private AiPanel ai_panel;
    private ToolboxPane toolbox;
    private MainController controller;
    private AiRunController ai_run_controller;
    private Settings? settings;

    private bool suppress_editor_events = false;

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

        var root_split = new Adw.OverlaySplitView();
        root_split.set_sidebar_position(Gtk.PackType.START);

        toast_overlay = new Adw.ToastOverlay();
        toast_overlay.set_child(root_split);
        set_content(toast_overlay);

        workspace = new WorkspacePane(search_store);
        editor_buffer = workspace.editor_buffer;
        editor_view = workspace.editor_view;
        spelling_adapter = workspace.spelling_adapter;
        settings = boot_settings;
        apply_persisted_preferences();
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
            workspace.set_toolbox_visible(visible);
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

        close_request.connect(() => {
            persist_window_state();
            return false;
        });

        if (start_maximized) {
            maximize();
        }

        controller.bootstrap.begin();
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

    private void apply_persisted_preferences() {
        if (settings == null) {
            return;
        }

        var style_key = settings.get_string(AppSettings.KEY_STYLE_VARIANT);
        Adw.StyleManager.get_default().set_color_scheme(AppSettings.key_to_color_scheme(style_key));

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

    private void show_preferences_dialog() {
        var dialog = new PreferencesDialog(editor_buffer, editor_view, spelling_adapter, settings);
        dialog.present(this);
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
        if (text == null || text.strip().length == 0) {
            add_toast("Nothing to print.");
            return;
        }

        string tmp_dir;
        try {
            tmp_dir = DirUtils.make_tmp("holder-print-XXXXXX");
        } catch (FileError e) {
            show_error("Print failed", "Could not create temporary print directory: %s".printf(e.message));
            return;
        }
        var tmp_path = Path.build_filename(tmp_dir, "card.txt");
        try {
            FileUtils.set_contents(tmp_path, text);
        } catch (FileError e) {
            show_error("Print failed", "Could not prepare print file: %s".printf(e.message));
            return;
        }

        var dialog = new Gtk.PrintDialog();
        dialog.set_title("Print");
        try {
            yield dialog.print_file(this, null, File.new_for_path(tmp_path), null);
        } catch (Error e) {
            show_error("Print failed", e.message);
        } finally {
            FileUtils.remove(tmp_path);
            DirUtils.remove(tmp_dir);
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

    protected override void dispose() {
        ai_run_controller.stop();
        base.dispose();
    }

}

}
