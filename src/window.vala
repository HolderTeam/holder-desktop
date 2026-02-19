namespace HolderLinux {

public class MainWindow : Adw.ApplicationWindow {
    private Adw.ToastOverlay toast_overlay;
    private Gtk.Label status_label;
    private Gtk.Label title_label;

    private GLib.ListStore project_store;
    private Gtk.SingleSelection project_selection;
    private GLib.ListStore card_store;
    private Gtk.SingleSelection card_selection;
    private GLib.ListStore ai_thread_store;
    private Gtk.SingleSelection ai_thread_selection;
    private GLib.ListStore search_store;

    private GtkSource.Buffer editor_buffer;
    private GtkSource.View editor_view;
    private Gtk.SearchEntry search_entry;
    private Gtk.Stack content_stack;
    private Gtk.Label search_summary_label;
    private Gtk.SingleSelection search_selection;
    private Gtk.ListView search_list;
    private Adw.OverlaySplitView ai_split;
    private Gtk.Label ai_summary_label;
    private Gtk.Label ai_models_label;
    private Gtk.Label ai_recommended_label;
    private Gtk.Box ai_recommended_buttons_box;
    private Gtk.Label ai_runtime_label;
    private Gtk.Label ai_pulls_label;
    private Gtk.TextBuffer ai_output_buffer;
    private Gtk.TextView ai_output_view;
    private Gtk.TextView ai_prompt_view;
    private Gtk.Label ai_assistant_thread_label;
    private ApiClient? api;

    private Project? current_project;
    private CardDetail? current_card;
    private AiThreadSummary? current_ai_thread;

    private bool suppress_editor_events = false;
    private bool suppress_project_selection_events = false;
    private bool suppress_card_selection_events = false;
    private bool create_card_in_flight = false;
    private bool ai_run_in_flight = false;
    private uint autosave_id = 0;
    private uint search_debounce_id = 0;
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

        root_split.set_sidebar(build_sidebar());
        root_split.set_content(build_workspace());
        root_split.set_show_sidebar(true);

        project_selection.notify["selected"].connect(() => {
            if (suppress_project_selection_events) {
                return;
            }
            on_project_selected();
        });

        card_selection.notify["selected"].connect(() => {
            if (suppress_card_selection_events) {
                return;
            }
            on_card_selected();
        });

        ai_thread_selection.notify["selected"].connect(() => {
            on_ai_thread_selected();
        });

        editor_buffer.changed.connect(() => {
            if (suppress_editor_events || current_card == null) {
                return;
            }
            schedule_autosave();
        });

        bootstrap.begin();
    }

    construct {
        var refresh_action = new SimpleAction("refresh", null);
        refresh_action.activate.connect(() => {
            reload_everything.begin();
        });
        add_action(refresh_action);

        var new_project_action = new SimpleAction("new-project", null);
        new_project_action.activate.connect(() => {
            show_new_project_dialog();
        });
        add_action(new_project_action);

        var new_card_action = new SimpleAction("new-card", null);
        new_card_action.activate.connect(() => {
            create_card.begin();
        });
        add_action(new_card_action);
    }

    private Gtk.Widget build_sidebar() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        box.add_css_class("navigation-sidebar");
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_start(8);
        box.set_margin_end(8);

        var sidebar_header = new Adw.HeaderBar();
        sidebar_header.set_title_widget(new Gtk.Label("Holder"));
        box.append(sidebar_header);

        status_label = new Gtk.Label("Connecting to Holder...") { xalign = 0.0f };
        status_label.add_css_class("caption");
        status_label.add_css_class("dim-label");
        box.append(status_label);

        var projects_title = new Gtk.Label("Projects") { xalign = 0.0f };
        projects_title.add_css_class("heading");
        box.append(projects_title);

        var project_factory = new Gtk.SignalListItemFactory();
        project_factory.setup.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var label = new Gtk.Label("") { xalign = 0.0f };
            label.add_css_class("title-4");
            list_item.set_child(label);
        });
        project_factory.bind.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var project = list_item.get_item() as Project;
            var label = list_item.get_child() as Gtk.Label;
            label.set_text(project != null ? project.name : "");
        });

        var project_list = new Gtk.ListView(project_selection, project_factory);
        project_list.set_vexpand(true);

        var project_scroll = new Gtk.ScrolledWindow();
        project_scroll.set_min_content_height(140);
        project_scroll.set_vexpand(true);
        project_scroll.set_child(project_list);
        box.append(project_scroll);

        var cards_title = new Gtk.Label("Cards") { xalign = 0.0f };
        cards_title.add_css_class("heading");
        box.append(cards_title);

        var card_factory = new Gtk.SignalListItemFactory();
        card_factory.setup.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            var title = new Gtk.Label("") { xalign = 0.0f };
            title.add_css_class("title-5");
            title.set_ellipsize(Pango.EllipsizeMode.END);
            var updated = new Gtk.Label("") { xalign = 0.0f };
            updated.add_css_class("dim-label");
            updated.add_css_class("caption");
            row.append(title);
            row.append(updated);
            list_item.set_child(row);
        });
        card_factory.bind.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var card = list_item.get_item() as CardSummary;
            var row = list_item.get_child() as Gtk.Box;
            var title = row.get_first_child() as Gtk.Label;
            var updated = title.get_next_sibling() as Gtk.Label;
            if (card == null) {
                title.set_text("");
                updated.set_text("");
                return;
            }
            title.set_text(card.title);
            updated.set_text("Updated %s".printf(format_relative_time(card.updated_at)));
        });

        var card_list = new Gtk.ListView(card_selection, card_factory);
        card_list.set_vexpand(true);

        var card_scroll = new Gtk.ScrolledWindow();
        card_scroll.set_vexpand(true);
        card_scroll.set_child(card_list);
        box.append(card_scroll);

        var threads_title = new Gtk.Label("AI Threads") { xalign = 0.0f };
        threads_title.add_css_class("heading");
        box.append(threads_title);

        var thread_factory = new Gtk.SignalListItemFactory();
        thread_factory.setup.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            var title = new Gtk.Label("") { xalign = 0.0f };
            title.add_css_class("title-5");
            title.set_ellipsize(Pango.EllipsizeMode.END);
            var updated = new Gtk.Label("") { xalign = 0.0f };
            updated.add_css_class("dim-label");
            updated.add_css_class("caption");
            row.append(title);
            row.append(updated);
            list_item.set_child(row);
        });
        thread_factory.bind.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var thread = list_item.get_item() as AiThreadSummary;
            var row = list_item.get_child() as Gtk.Box;
            var title = row.get_first_child() as Gtk.Label;
            var updated = title.get_next_sibling() as Gtk.Label;
            if (thread == null) {
                title.set_text("");
                updated.set_text("");
                return;
            }
            title.set_text(thread.title);
            updated.set_text("Updated %s".printf(format_relative_time(thread.updated_at)));
        });

        var thread_list = new Gtk.ListView(ai_thread_selection, thread_factory);
        thread_list.set_vexpand(true);
        var thread_scroll = new Gtk.ScrolledWindow();
        thread_scroll.set_min_content_height(120);
        thread_scroll.set_vexpand(true);
        thread_scroll.set_child(thread_list);
        box.append(thread_scroll);

        return box;
    }

    private Gtk.Widget build_workspace() {
        var outer = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

        var header = new Adw.HeaderBar();
        title_label = new Gtk.Label("Editor");
        header.set_title_widget(title_label);

        var refresh_btn = new Gtk.Button.from_icon_name("view-refresh-symbolic");
        refresh_btn.set_tooltip_text("Refresh projects and cards");
        refresh_btn.set_action_name("win.refresh");

        var new_project_btn = new Gtk.Button.from_icon_name("folder-new-symbolic");
        new_project_btn.set_tooltip_text("Create a new project");
        new_project_btn.set_action_name("win.new-project");

        var new_card_btn = new Gtk.Button.from_icon_name("list-add-symbolic");
        new_card_btn.set_tooltip_text("Create a new card");
        new_card_btn.set_action_name("win.new-card");

        var ai_toggle_btn = new Gtk.ToggleButton();
        ai_toggle_btn.set_icon_name("utilities-terminal-symbolic");
        ai_toggle_btn.set_tooltip_text("Toggle AI status panel");
        ai_toggle_btn.toggled.connect(() => {
            ai_split.set_show_sidebar(ai_toggle_btn.get_active());
            if (ai_toggle_btn.get_active()) {
                refresh_ai_panel.begin();
            } else {
                stop_ai_polling();
            }
        });

        header.pack_start(refresh_btn);
        header.pack_end(ai_toggle_btn);
        header.pack_end(new_project_btn);
        header.pack_end(new_card_btn);
        outer.append(header);

        var search_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        search_row.set_margin_top(8);
        search_row.set_margin_bottom(8);
        search_row.set_margin_start(8);
        search_row.set_margin_end(8);

        search_entry = new Gtk.SearchEntry();
        search_entry.set_placeholder_text("Search cards in current project...");
        search_entry.set_hexpand(true);
        search_entry.activate.connect(() => {
            cancel_pending_search();
            run_search.begin();
        });
        search_entry.search_changed.connect(() => {
            var q = search_entry.get_text().strip();
            if (q.length == 0) {
                cancel_pending_search();
                clear_search_results();
                show_editor_mode();
                return;
            }
            schedule_search();
        });

        var search_key = new Gtk.EventControllerKey();
        search_key.key_pressed.connect((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Down) {
                if (search_store.get_n_items() > 0) {
                    show_search_mode();
                    if (search_selection.get_selected() == Gtk.INVALID_LIST_POSITION) {
                        search_selection.set_selected(0);
                    }
                    search_list.grab_focus();
                    return true;
                }
            }
            return false;
        });
        search_entry.add_controller(search_key);

        var clear_search_btn = new Gtk.Button.from_icon_name("edit-clear-symbolic");
        clear_search_btn.set_tooltip_text("Clear search");
        clear_search_btn.clicked.connect(() => {
            search_entry.set_text("");
            clear_search_results();
            show_editor_mode();
        });

        search_row.append(search_entry);
        search_row.append(clear_search_btn);
        outer.append(search_row);

        editor_buffer = new GtkSource.Buffer(null);
        editor_buffer.set_highlight_syntax(true);
        editor_buffer.set_highlight_matching_brackets(true);

        var lm = GtkSource.LanguageManager.get_default();
        var markdown = lm.get_language("markdown");
        if (markdown == null) {
            markdown = lm.guess_language("note.md", null);
        }
        if (markdown != null) {
            editor_buffer.set_language(markdown);
        }

        editor_view = new GtkSource.View.with_buffer(editor_buffer);
        editor_view.set_monospace(true);
        editor_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        editor_view.set_show_line_numbers(true);
        editor_view.set_vexpand(true);
        editor_view.set_hexpand(true);

        var editor_scroll = new Gtk.ScrolledWindow();
        editor_scroll.set_child(editor_view);
        editor_scroll.set_vexpand(true);

        var search_page = build_search_page();

        content_stack = new Gtk.Stack();
        content_stack.set_vexpand(true);
        content_stack.set_hexpand(true);
        content_stack.add_named(editor_scroll, "editor");
        content_stack.add_named(search_page, "search");
        content_stack.set_visible_child_name("editor");

        ai_split = new Adw.OverlaySplitView();
        ai_split.set_sidebar_position(Gtk.PackType.END);
        ai_split.set_content(content_stack);
        ai_split.set_sidebar(build_ai_panel());
        ai_split.set_show_sidebar(false);
        ai_split.set_vexpand(true);

        outer.append(ai_split);
        return outer;
    }

    private Gtk.Widget build_ai_panel() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_start(8);
        box.set_margin_end(8);

        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var title = new Gtk.Label("AI Status");
        title.add_css_class("title-4");
        title.set_halign(Gtk.Align.START);
        title.set_hexpand(true);
        var refresh = new Gtk.Button.from_icon_name("view-refresh-symbolic");
        refresh.set_tooltip_text("Refresh AI status");
        refresh.clicked.connect(() => {
            refresh_ai_panel.begin();
        });
        header.append(title);
        header.append(refresh);
        box.append(header);

        var stack = new Gtk.Stack();
        stack.set_vexpand(true);
        stack.set_hexpand(true);
        var switcher = new Gtk.StackSwitcher();
        switcher.set_stack(stack);
        switcher.set_halign(Gtk.Align.START);
        box.append(switcher);

        var assistant = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        ai_assistant_thread_label = new Gtk.Label("Thread: none selected") { xalign = 0.0f };
        ai_assistant_thread_label.add_css_class("dim-label");
        assistant.append(ai_assistant_thread_label);

        ai_output_buffer = new Gtk.TextBuffer(null);
        ai_output_view = new Gtk.TextView.with_buffer(ai_output_buffer);
        ai_output_view.set_editable(false);
        ai_output_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        ai_output_view.set_vexpand(true);

        var output_scroll = new Gtk.ScrolledWindow();
        output_scroll.set_vexpand(true);
        output_scroll.set_child(ai_output_view);
        assistant.append(output_scroll);

        ai_prompt_view = new Gtk.TextView();
        ai_prompt_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        ai_prompt_view.set_vexpand(false);
        ai_prompt_view.set_size_request(-1, 96);

        var prompt_scroll = new Gtk.ScrolledWindow();
        prompt_scroll.set_vexpand(false);
        prompt_scroll.set_child(ai_prompt_view);
        assistant.append(prompt_scroll);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var send_btn = new Gtk.Button.with_label("Send");
        send_btn.clicked.connect(() => {
            on_ai_send_clicked();
        });
        var new_thread_btn = new Gtk.Button.with_label("New Thread");
        new_thread_btn.clicked.connect(() => {
            create_ai_thread_from_prompt.begin();
        });
        actions.append(send_btn);
        actions.append(new_thread_btn);
        assistant.append(actions);

        var status_page = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        ai_summary_label = new Gtk.Label("Not loaded") { xalign = 0.0f };
        ai_summary_label.set_wrap(true);
        ai_models_label = new Gtk.Label("") { xalign = 0.0f };
        ai_models_label.set_wrap(true);
        ai_recommended_label = new Gtk.Label("") { xalign = 0.0f };
        ai_recommended_label.set_wrap(true);
        ai_recommended_buttons_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        ai_runtime_label = new Gtk.Label("") { xalign = 0.0f };
        ai_runtime_label.set_wrap(true);
        ai_pulls_label = new Gtk.Label("") { xalign = 0.0f };
        ai_pulls_label.set_wrap(true);

        status_page.append(ai_summary_label);
        status_page.append(ai_models_label);
        status_page.append(ai_recommended_label);
        status_page.append(ai_recommended_buttons_box);
        status_page.append(ai_runtime_label);
        status_page.append(ai_pulls_label);

        stack.add_titled(assistant, "assistant", "Assistant");
        stack.add_titled(status_page, "status", "Status");
        stack.set_visible_child_name("assistant");

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_vexpand(true);
        scroll.set_child(stack);
        box.append(scroll);

        return box;
    }

    private Gtk.Widget build_search_page() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_start(8);
        box.set_margin_end(8);

        search_summary_label = new Gtk.Label("Search results will appear here.") { xalign = 0.0f };
        search_summary_label.add_css_class("dim-label");
        box.append(search_summary_label);

        search_selection = new Gtk.SingleSelection(search_store);
        var search_factory = new Gtk.SignalListItemFactory();
        search_factory.setup.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            var title = new Gtk.Label("") { xalign = 0.0f };
            title.add_css_class("title-5");
            title.set_ellipsize(Pango.EllipsizeMode.END);
            var snippet = new Gtk.Label("") { xalign = 0.0f };
            snippet.add_css_class("dim-label");
            snippet.set_wrap(true);
            snippet.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
            snippet.set_max_width_chars(80);
            row.append(title);
            row.append(snippet);
            list_item.set_child(row);
        });
        search_factory.bind.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var result = list_item.get_item() as SearchCardResult;
            var row = list_item.get_child() as Gtk.Box;
            var title = row.get_first_child() as Gtk.Label;
            var snippet = title.get_next_sibling() as Gtk.Label;
            if (result == null) {
                title.set_text("");
                snippet.set_text("");
                return;
            }
            title.set_text(result.title);
            snippet.set_text(result.snippet);
        });

        search_list = new Gtk.ListView(search_selection, search_factory);
        search_list.activate.connect((position) => {
            open_search_result_at.begin((uint) position);
        });

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_vexpand(true);
        scroll.set_child(search_list);
        box.append(scroll);

        return box;
    }

    private async void bootstrap() {
        set_status("Discovering local server...");
        set_editor_state("# Loading\n\nDiscovering local server...", false);

        ServerInfo info;
        try {
            info = Discovery.discover_server();
        } catch (Error e) {
            set_status(e.message);
            set_editor_state(
                "# Holder Not Found\n\n" +
                "Start the backend first, then reopen this app.\n\n" +
                "Expected file:\n`%s`\n".printf(Discovery.holder_info_path())
                ,
                false
            );
            return;
        }

        api = new ApiClient(info.base_url(), info.auth_token);
        set_status("Checking API health...");
        set_editor_state("# Loading\n\nChecking API health...", false);
        try {
            yield api.health_check();
        } catch (Error e) {
            set_status("Health check failed");
            set_editor_state(
                "# Health Check Failed\n\n" +
                "Could not connect to the Holder API.\n\n" +
                e.message,
                false
            );
            show_error("Health check failed", e.message);
            return;
        }

        set_status("Connected to %s:%d (API %s)".printf(info.bind, info.port, info.api_version));
        yield ensure_first_project();
        yield reload_everything();
        refresh_ai_panel.begin();
    }

    private async void ensure_first_project() {
        if (api == null) {
            return;
        }

        try {
            var projects = yield api.list_projects();
            if (projects.size == 0) {
                var project_id = yield api.create_project("My Project");
                add_toast("Created first project (%s)".printf(project_id));
            }
        } catch (Error e) {
            show_error("Project bootstrap failed", e.message);
        }
    }

    private async void reload_everything() {
        var preferred_project_id = selected_project_id();
        var preferred_card_id = selected_card_id();
        yield reload_everything_with_selection(preferred_project_id, preferred_card_id);
    }

    private async void reload_everything_with_selection(string? preferred_project_id,
                                                        string? preferred_card_id) {
        if (api == null) {
            return;
        }

        set_status("Refreshing projects...");
        try {
            var projects = yield api.list_projects();
            replace_projects(projects);
            if (project_store.get_n_items() == 0) {
                current_project = null;
                clear_cards();
                set_editor_state("# No Projects\n\nCreate a project to start writing.", false);
                return;
            }

            var selected = false;
            if (preferred_project_id != null) {
                selected = select_project_by_id(preferred_project_id);
            }
            if (!selected) {
                suppress_project_selection_events = true;
                project_selection.set_selected(0);
                suppress_project_selection_events = false;
            }
            yield reload_cards_for_selected_project(preferred_card_id);
            refresh_ai_panel.begin();
        } catch (Error e) {
            show_error("Failed to refresh", e.message);
        }
    }

    private void on_project_selected() {
        reload_cards_for_selected_project.begin();
    }

    private async void reload_cards_for_selected_project(string? preferred_card_id = null) {
        if (api == null) {
            return;
        }

        var selected = project_selection.get_selected_item() as Project;
        if (selected == null) {
            current_project = null;
            clear_cards();
            return;
        }

        current_project = selected;
        update_window_title(selected.name);
        set_status("Loading cards for %s...".printf(selected.name));

        try {
            var cards = yield api.list_cards(selected.project_id);
            replace_cards(cards);
            yield reload_ai_threads_for_project(selected.project_id);
            if (card_store.get_n_items() == 0) {
                current_card = null;
                set_editor_state(
                    "# %s\n\nNo cards yet. Create one with the + button.".printf(selected.name),
                    false
                );
                return;
            }

            var selected_card = false;
            if (preferred_card_id != null) {
                selected_card = select_card_by_id(preferred_card_id);
            }
            if (!selected_card) {
                suppress_card_selection_events = true;
                card_selection.set_selected(0);
                suppress_card_selection_events = false;
            }
            load_selected_card.begin();
        } catch (Error e) {
            show_error("Failed to load cards", e.message);
        }
    }

    private void on_card_selected() {
        load_selected_card.begin();
    }

    private void on_ai_thread_selected() {
        var selected = ai_thread_selection.get_selected_item() as AiThreadSummary;
        current_ai_thread = selected;
        if (selected == null) {
            ai_assistant_thread_label.set_text("Thread: none selected");
            return;
        }
        ai_assistant_thread_label.set_text("Thread: %s".printf(selected.title));
    }

    private async void load_selected_card() {
        if (api == null) {
            return;
        }

        var selected = card_selection.get_selected_item() as CardSummary;
        if (selected == null) {
            current_card = null;
            set_editor_state("# No Card Selected\n\nSelect a card from the sidebar.", false);
            return;
        }

        set_status("Loading card...");
        set_editor_state("Loading card...", false);
        try {
            var card = yield api.get_card(selected.card_id);
            current_card = card;
            set_editor_state(card.content, true);
            show_editor_mode();
            update_window_title(card.title);
            set_status("Loaded %s".printf(card.title));
        } catch (Error e) {
            set_editor_state(
                "# Error\n\nFailed to load card `%s`.\n\n%s".printf(selected.card_id, e.message),
                false
            );
            show_error("Failed to load card", e.message);
        }
    }

    private async void create_card() {
        if (create_card_in_flight) {
            set_status("Create card already in progress...");
            return;
        }
        if (api == null) {
            show_error("Create card unavailable", "API client is not connected.");
            return;
        }

        if (current_project == null) {
            var selected = project_selection.get_selected_item() as Project;
            if (selected != null) {
                current_project = selected;
            }
        }
        if (current_project == null) {
            show_error("No project selected", "Select or create a project first.");
            return;
        }

        var initial_title = "Untitled";
        var initial_body = "# Untitled\n\n";

        create_card_in_flight = true;
        set_status("Creating new card...");
        try {
            var new_id = yield api.create_card(current_project.project_id, initial_title, initial_body);
            var cards = yield api.list_cards(current_project.project_id);
            replace_cards(cards);

            for (uint i = 0; i < card_store.get_n_items(); i++) {
                var item = card_store.get_item(i) as CardSummary;
                if (item != null && item.card_id == new_id) {
                    card_selection.set_selected(i);
                    break;
                }
            }

            add_toast("New card created");
            set_status("Created new card");
        } catch (Error e) {
            show_error("Failed to create card", e.message);
        } finally {
            create_card_in_flight = false;
        }
    }

    private async void run_search() {
        if (api == null) {
            return;
        }
        if (current_project == null) {
            show_error("Search unavailable", "No project selected.");
            return;
        }

        var query_text = search_entry.get_text().strip();
        if (query_text.length == 0) {
            clear_search_results();
            show_editor_mode();
            return;
        }

        set_status("Searching for \"%s\"...".printf(query_text));
        try {
            var results = yield api.search_cards(current_project.project_id, query_text);
            replace_search_results(results);
            search_summary_label.set_text("%d result(s) for \"%s\"".printf(results.size, query_text));
            show_search_mode();
            set_status("Search complete");
        } catch (Error e) {
            show_error("Search failed", e.message);
        }
    }

    private async void refresh_ai_panel() {
        if (api == null) {
            return;
        }

        var project_id = selected_project_id();
        try {
            var capabilities = yield api.get_ai_capabilities(project_id);
            var status = yield api.get_ai_status();
            render_ai_panel(capabilities, status);
            update_ai_polling(status.active_pull_jobs > 0);
        } catch (Error e) {
            ai_summary_label.set_text("AI status unavailable");
            ai_models_label.set_text("");
            ai_recommended_label.set_text("");
            ai_runtime_label.set_text(e.message);
            ai_pulls_label.set_text("");
            stop_ai_polling();
        }
    }

    private void on_ai_send_clicked() {
        if (ai_run_in_flight) {
            set_status("AI run already in progress...");
            return;
        }
        var prompt = ai_prompt_text().strip();
        if (prompt.length == 0) {
            show_error("Prompt required", "Type a prompt before sending.");
            return;
        }
        if (current_project == null) {
            show_error("No project selected", "Select a project before using the assistant.");
            return;
        }
        if (current_ai_thread == null) {
            create_ai_thread_named.begin("Thread %s".printf(now_epoch_seconds().to_string()), true);
            return;
        }

        send_prompt_to_ai.begin(prompt);
    }

    private async void send_prompt_to_ai(string prompt) {
        if (api == null || current_project == null || current_ai_thread == null) {
            show_error("Cannot run AI", "Missing API, project, or thread context.");
            return;
        }

        append_ai_output("You", prompt);
        clear_ai_prompt();
        append_ai_output("Assistant", "");

        ai_run_in_flight = true;
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
            append_ai_output_chunk("\n");
            set_status("AI run complete");
        } catch (Error e) {
            append_ai_output("System", "AI run failed: %s".printf(e.message));
            show_error("AI run failed", e.message);
        } finally {
            ai_run_in_flight = false;
            refresh_ai_panel.begin();
        }
    }

    private async void create_ai_thread_from_prompt() {
        create_ai_thread_named.begin("Thread %s".printf(now_epoch_seconds().to_string()), false);
    }

    private async void create_ai_thread_named(string title, bool continue_send) {
        if (api == null || current_project == null) {
            show_error("Cannot create thread", "No project/API context.");
            return;
        }
        try {
            var thread_id = yield api.create_ai_thread(current_project.project_id, title);
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

    private void render_ai_panel(AiCapabilitiesInfo capabilities, AiStatusInfo status) {
        ai_summary_label.set_text(
            "Runner: %s | Caste: %s | Version: %s".printf(
                capabilities.runner_available ? "available" : "unavailable",
                capabilities.caste_name.length > 0 ? capabilities.caste_name : "unknown",
                capabilities.runner_version.length > 0 ? capabilities.runner_version : "unknown"
            )
        );
        if (capabilities.runner_error.length > 0) {
            ai_summary_label.set_text(ai_summary_label.get_text() + "\nError: " + capabilities.runner_error);
        }

        ai_models_label.set_text(
            "Installed models (%d): %s".printf(
                capabilities.models.size,
                join_list(capabilities.models)
            )
        );
        ai_recommended_label.set_text(
            "Recommended install: %s".printf(join_list(capabilities.recommended_install))
        );
        rebuild_recommended_pull_buttons(capabilities.recommended_install);
        ai_runtime_label.set_text(
            "Active runs: %lld | Active pulls: %lld | Cloud providers configured: %lld".printf(
                status.active_runs,
                status.active_pull_jobs,
                status.cloud_configured_providers
            )
        );
        ai_pulls_label.set_text("Pull jobs: %s".printf(join_list(status.pull_jobs)));
    }

    private void schedule_search() {
        if (search_debounce_id != 0) {
            Source.remove(search_debounce_id);
        }
        search_debounce_id = Timeout.add(300, () => {
            search_debounce_id = 0;
            run_search.begin();
            return Source.REMOVE;
        });
    }

    private void cancel_pending_search() {
        if (search_debounce_id == 0) {
            return;
        }
        Source.remove(search_debounce_id);
        search_debounce_id = 0;
    }

    private async void open_search_result_at(uint position) {
        var item = search_store.get_item(position) as SearchCardResult;
        if (item == null) {
            return;
        }

        if (!select_card_by_id(item.card_id)) {
            yield reload_cards_for_selected_project(item.card_id);
        } else {
            load_selected_card.begin();
        }
    }

    private void schedule_autosave() {
        if (autosave_id != 0) {
            Source.remove(autosave_id);
        }

        autosave_id = Timeout.add(900, () => {
            autosave_id = 0;
            autosave_current_card.begin();
            return Source.REMOVE;
        });
    }

    private async void autosave_current_card() {
        if (api == null || current_card == null) {
            return;
        }

        Gtk.TextIter start;
        Gtk.TextIter end;
        editor_buffer.get_bounds(out start, out end);
        var text = editor_buffer.get_text(start, end, false);
        var title = title_from_content(text);
        var updated_at = now_epoch_seconds();

        try {
            yield api.update_card(current_card.card_id, title, text, updated_at);
            current_card.title = title;
            current_card.content = text;
            current_card.updated_at = updated_at;
            update_selected_card_summary(title, updated_at);
            update_window_title(title);
            set_status("Saved %s".printf(format_relative_time(updated_at)));
        } catch (Error e) {
            show_error("Autosave failed", e.message);
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
        if (api == null) {
            return;
        }

        set_status("Creating project...");
        try {
            var project_id = yield api.create_project(name);
            add_toast("Created project: %s".printf(name));
            set_status("Project created");
            yield reload_everything_with_selection(project_id, null);
        } catch (Error e) {
            show_error("Failed to create project", e.message);
        }
    }

    private async void reload_ai_threads_for_project(string project_id) {
        if (api == null) {
            return;
        }
        try {
            var threads = yield api.list_ai_threads(project_id);
            replace_ai_threads(threads);
            if (ai_thread_store.get_n_items() > 0) {
                ai_thread_selection.set_selected(0);
            } else {
                current_ai_thread = null;
                ai_assistant_thread_label.set_text("Thread: none selected");
            }
        } catch (Error e) {
            show_error("Failed to load AI threads", e.message);
        }
    }

    private void replace_projects(Gee.ArrayList<Project> projects) {
        project_store.remove_all();
        foreach (var project in projects) {
            project_store.append(project);
        }
    }

    private void replace_cards(Gee.ArrayList<CardSummary> cards) {
        card_store.remove_all();
        foreach (var card in cards) {
            card_store.append(card);
        }
    }

    private void replace_ai_threads(Gee.ArrayList<AiThreadSummary> threads) {
        ai_thread_store.remove_all();
        foreach (var thread in threads) {
            ai_thread_store.append(thread);
        }
    }

    private void clear_cards() {
        card_store.remove_all();
        current_card = null;
        ai_thread_store.remove_all();
        current_ai_thread = null;
        ai_assistant_thread_label.set_text("Thread: none selected");
    }

    private void replace_search_results(Gee.ArrayList<SearchCardResult> results) {
        search_store.remove_all();
        foreach (var result in results) {
            search_store.append(result);
        }
        if (results.size > 0) {
            search_selection.set_selected(0);
        }
    }

    private void clear_search_results() {
        search_store.remove_all();
        search_summary_label.set_text("Search results will appear here.");
    }

    private void set_status(string text) {
        status_label.set_text(text);
    }

    private void set_editor_state(string text, bool editable) {
        suppress_editor_events = true;
        editor_buffer.set_text(text, -1);
        editor_view.set_editable(editable);
        suppress_editor_events = false;
    }

    private void update_window_title(string title_text) {
        title_label.set_text(title_text);
        title = title_text;
    }

    private void add_toast(string msg) {
        toast_overlay.add_toast(new Adw.Toast(msg));
    }

    private void show_error(string title_text, string details) {
        set_status("%s: %s".printf(title_text, details));
        add_toast("%s".printf(title_text));
    }

    private void show_editor_mode() {
        content_stack.set_visible_child_name("editor");
    }

    private void show_search_mode() {
        content_stack.set_visible_child_name("search");
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
        var selected = project_selection.get_selected_item() as Project;
        if (selected == null) {
            return null;
        }
        return selected.project_id;
    }

    private string? selected_card_id() {
        var selected = card_selection.get_selected_item() as CardSummary;
        if (selected == null) {
            return null;
        }
        return selected.card_id;
    }

    private bool select_project_by_id(string project_id) {
        for (uint i = 0; i < project_store.get_n_items(); i++) {
            var project = project_store.get_item(i) as Project;
            if (project != null && project.project_id == project_id) {
                suppress_project_selection_events = true;
                project_selection.set_selected(i);
                suppress_project_selection_events = false;
                return true;
            }
        }
        return false;
    }

    private bool select_card_by_id(string card_id) {
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null && card.card_id == card_id) {
                suppress_card_selection_events = true;
                card_selection.set_selected(i);
                suppress_card_selection_events = false;
                return true;
            }
        }
        return false;
    }

    private bool select_ai_thread_by_id(string thread_id) {
        for (uint i = 0; i < ai_thread_store.get_n_items(); i++) {
            var thread = ai_thread_store.get_item(i) as AiThreadSummary;
            if (thread != null && thread.thread_id == thread_id) {
                ai_thread_selection.set_selected(i);
                return true;
            }
        }
        return false;
    }

    private void update_selected_card_summary(string title, int64 updated_at) {
        if (current_card == null) {
            return;
        }
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null || card.card_id != current_card.card_id) {
                continue;
            }
            var replacement = new CardSummary(
                card.card_id,
                card.project_id,
                title,
                card.rel_path,
                card.created_at,
                updated_at
            );
            var selected_pos = card_selection.get_selected();
            card_store.remove(i);
            card_store.insert(i, replacement);
            if (selected_pos == i) {
                suppress_card_selection_events = true;
                card_selection.set_selected(i);
                suppress_card_selection_events = false;
            }
            break;
        }
    }

    private string join_list(Gee.ArrayList<string> values) {
        if (values.size == 0) {
            return "none";
        }
        var builder = new StringBuilder();
        for (int i = 0; i < values.size; i++) {
            if (i > 0) {
                builder.append(", ");
            }
            builder.append(values[i]);
        }
        return builder.str;
    }

    private string ai_prompt_text() {
        var buffer = ai_prompt_view.get_buffer();
        Gtk.TextIter start;
        Gtk.TextIter end;
        buffer.get_bounds(out start, out end);
        return buffer.get_text(start, end, false);
    }

    private void clear_ai_prompt() {
        var buffer = ai_prompt_view.get_buffer();
        buffer.set_text("", -1);
    }

    private void append_ai_output(string role, string text) {
        Gtk.TextIter start;
        Gtk.TextIter end;
        ai_output_buffer.get_bounds(out start, out end);
        var existing = ai_output_buffer.get_text(start, end, false);
        var prefix = existing.length > 0 ? "\n\n" : "";
        var next = "%s%s:\n%s".printf(prefix, role, text);
        ai_output_buffer.insert(ref end, next, -1);
    }

    private void append_ai_output_chunk(string text) {
        Gtk.TextIter end;
        ai_output_buffer.get_end_iter(out end);
        ai_output_buffer.insert(ref end, text, -1);
    }

    private void handle_ai_run_event(string event_name, Json.Object data) {
        switch (event_name) {
            case "chunk":
                append_ai_output_chunk(json_string_member_or_empty(data, "delta"));
                break;
            case "progress":
                var message = json_string_member_or_empty(data, "message");
                if (message.length > 0) {
                    append_ai_output("System", message);
                }
                break;
            case "fallback":
                var model = json_string_member_or_empty(data, "model");
                var error = json_string_member_or_empty(data, "error");
                var detail = model.length > 0 ? "Fallback from %s".printf(model) : "Fallback";
                if (error.length > 0) {
                    detail += ": " + error;
                }
                append_ai_output("System", detail);
                break;
            case "failed":
                var failed = json_string_member_or_empty(data, "error");
                append_ai_output("System", failed.length > 0 ? failed : "Run failed.");
                break;
            case "done":
                var model_done = json_string_member_or_empty(data, "model");
                if (model_done.length > 0) {
                    append_ai_output("System", "Completed with %s".printf(model_done));
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

    private void rebuild_recommended_pull_buttons(Gee.ArrayList<string> recommended_models) {
        Gtk.Widget? child = ai_recommended_buttons_box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            ai_recommended_buttons_box.remove(child);
            child = next;
        }

        if (recommended_models.size == 0) {
            var label = new Gtk.Label("No recommended model pulls right now.") { xalign = 0.0f };
            label.add_css_class("dim-label");
            ai_recommended_buttons_box.append(label);
            return;
        }

        for (int i = 0; i < recommended_models.size; i++) {
            var model_tag = recommended_models[i];
            var btn = new Gtk.Button.with_label("Pull %s".printf(model_tag));
            btn.set_halign(Gtk.Align.START);
            btn.clicked.connect(() => {
                start_model_pull.begin(model_tag);
            });
            ai_recommended_buttons_box.append(btn);
        }
    }

    private async void start_model_pull(string model_tag) {
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

    private string title_from_content(string text) {
        return TextUtils.title_from_content(text);
    }

    private string format_relative_time(int64 timestamp) {
        return TextUtils.format_relative_time(now_epoch_seconds(), timestamp);
    }
}

}
