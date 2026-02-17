namespace HolderLinux {

public class MainWindow : Adw.ApplicationWindow {
    private Adw.ToastOverlay toast_overlay;
    private Gtk.Label status_label;
    private Gtk.Label title_label;

    private GLib.ListStore project_store;
    private Gtk.SingleSelection project_selection;
    private GLib.ListStore card_store;
    private Gtk.SingleSelection card_selection;

    private GtkSource.Buffer editor_buffer;
    private ApiClient? api;

    private Project? current_project;
    private CardDetail? current_card;

    private bool suppress_editor_events = false;
    private uint autosave_id = 0;

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

        var root_split = new Adw.OverlaySplitView();
        root_split.set_sidebar_position(Gtk.PackType.START);

        toast_overlay = new Adw.ToastOverlay();
        toast_overlay.set_child(root_split);
        set_content(toast_overlay);

        root_split.set_sidebar(build_sidebar());
        root_split.set_content(build_workspace());
        root_split.set_show_sidebar(true);

        project_selection.notify["selected"].connect(() => {
            on_project_selected();
        });

        card_selection.notify["selected"].connect(() => {
            on_card_selected();
        });

        editor_buffer.changed.connect(() => {
            if (suppress_editor_events || current_card == null) {
                return;
            }
            schedule_autosave();
        });

        bootstrap.begin();
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

        return box;
    }

    private Gtk.Widget build_workspace() {
        var outer = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

        var header = new Adw.HeaderBar();
        title_label = new Gtk.Label("Editor");
        header.set_title_widget(title_label);

        var refresh_btn = new Gtk.Button.from_icon_name("view-refresh-symbolic");
        refresh_btn.set_tooltip_text("Refresh projects and cards");
        refresh_btn.clicked.connect(() => {
            reload_everything.begin();
        });

        var new_card_btn = new Gtk.Button.from_icon_name("list-add-symbolic");
        new_card_btn.set_tooltip_text("Create a new card");
        new_card_btn.clicked.connect(() => {
            create_card.begin();
        });

        header.pack_start(refresh_btn);
        header.pack_end(new_card_btn);
        outer.append(header);

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

        var editor_view = new GtkSource.View.with_buffer(editor_buffer);
        editor_view.set_monospace(true);
        editor_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        editor_view.set_show_line_numbers(true);
        editor_view.set_vexpand(true);
        editor_view.set_hexpand(true);

        var editor_scroll = new Gtk.ScrolledWindow();
        editor_scroll.set_child(editor_view);
        editor_scroll.set_vexpand(true);

        outer.append(editor_scroll);
        return outer;
    }

    private async void bootstrap() {
        set_status("Discovering local server...");

        ServerInfo info;
        try {
            info = Discovery.discover_server();
        } catch (Error e) {
            set_status(e.message);
            set_editor_message(
                "# Holder Not Found\n\n" +
                "Start the backend first, then reopen this app.\n\n" +
                "Expected file:\n`%s`\n".printf(Discovery.holder_info_path())
            );
            return;
        }

        api = new ApiClient(info.base_url(), info.auth_token);
        set_status("Checking API health...");
        try {
            yield api.health_check();
        } catch (Error e) {
            set_status("Health check failed");
            show_error("Health check failed", e.message);
            return;
        }

        set_status("Connected to %s:%d (API %s)".printf(info.bind, info.port, info.api_version));
        yield ensure_first_project();
        yield reload_everything();
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
        if (api == null) {
            return;
        }

        try {
            var projects = yield api.list_projects();
            replace_projects(projects);
            if (project_store.get_n_items() == 0) {
                current_project = null;
                clear_cards();
                set_editor_message("# No Projects\n\nCreate a project to start writing.");
                return;
            }

            if (project_selection.get_selected() == Gtk.INVALID_LIST_POSITION) {
                project_selection.set_selected(0);
            } else {
                yield reload_cards_for_selected_project();
            }
        } catch (Error e) {
            show_error("Failed to refresh", e.message);
        }
    }

    private void on_project_selected() {
        reload_cards_for_selected_project.begin();
    }

    private async void reload_cards_for_selected_project() {
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

        try {
            var cards = yield api.list_cards(selected.project_id);
            replace_cards(cards);
            if (card_store.get_n_items() == 0) {
                current_card = null;
                set_editor_message("# %s\n\nNo cards yet. Create one with the + button.".printf(selected.name));
                return;
            }
            card_selection.set_selected(0);
        } catch (Error e) {
            show_error("Failed to load cards", e.message);
        }
    }

    private void on_card_selected() {
        load_selected_card.begin();
    }

    private async void load_selected_card() {
        if (api == null) {
            return;
        }

        var selected = card_selection.get_selected_item() as CardSummary;
        if (selected == null) {
            current_card = null;
            return;
        }

        try {
            var card = yield api.get_card(selected.card_id);
            current_card = card;
            suppress_editor_events = true;
            editor_buffer.set_text(card.content, -1);
            suppress_editor_events = false;
            update_window_title(card.title);
        } catch (Error e) {
            show_error("Failed to load card", e.message);
        }
    }

    private async void create_card() {
        if (api == null || current_project == null) {
            return;
        }

        var initial_title = "Untitled";
        var initial_body = "# Untitled\n\n";

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
        } catch (Error e) {
            show_error("Failed to create card", e.message);
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
            set_status("Saved %s".printf(format_relative_time(updated_at)));
        } catch (Error e) {
            show_error("Autosave failed", e.message);
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

    private void clear_cards() {
        card_store.remove_all();
        current_card = null;
    }

    private void set_status(string text) {
        status_label.set_text(text);
    }

    private void set_editor_message(string text) {
        suppress_editor_events = true;
        editor_buffer.set_text(text, -1);
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

    private int64 now_epoch_seconds() {
        return new DateTime.now_utc().to_unix();
    }

    private string title_from_content(string text) {
        var lines = text.split("\n");
        foreach (var raw_line in lines) {
            var line = raw_line.strip();
            if (line.length == 0) {
                continue;
            }
            if (line.has_prefix("#")) {
                line = line.substring(1).strip();
            }
            return ellipsize(line, 80);
        }
        return "Untitled";
    }

    private string ellipsize(string value, int max_len) {
        if (value.length <= max_len) {
            return value;
        }
        if (max_len <= 3) {
            return value.substring(0, max_len);
        }
        return value.substring(0, max_len - 3) + "...";
    }

    private string format_relative_time(int64 timestamp) {
        if (timestamp <= 0) {
            return "unknown";
        }

        var now = now_epoch_seconds();
        var delta = now - timestamp;
        if (delta < 0) {
            return "just now";
        }
        if (delta < 60) {
            return "%llds ago".printf(delta);
        }
        if (delta < 3600) {
            return "%lldm ago".printf(delta / 60);
        }
        if (delta < 86400) {
            return "%lldh ago".printf(delta / 3600);
        }
        return "%lldd ago".printf(delta / 86400);
    }
}

}
