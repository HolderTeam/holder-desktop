namespace HolderLinux {

public class WorkspacePane : Object {
    private Gtk.Label title_label;
    private Gtk.ToggleButton toolbox_toggle_btn;
    public Gtk.Widget widget { get; private set; }
    public GtkSource.Buffer editor_buffer { get; private set; }
    public GtkSource.View editor_view { get; private set; }
    public Gtk.SearchEntry search_entry { get; private set; }
    public Gtk.Stack content_stack { get; private set; }
    public Gtk.Label search_summary_label { get; private set; }
    public Gtk.SingleSelection search_selection { get; private set; }
    public Gtk.ListView search_list { get; private set; }
    public Adw.OverlaySplitView ai_split { get; private set; }
    public AiPanel ai_panel { get; private set; }
    public ToolboxPane toolbox { get; private set; }

    public signal void refresh_requested();
    public signal void new_project_requested();
    public signal void new_card_requested();
    public signal void ai_panel_toggled(bool visible);
    public signal void toolbox_toggled(bool visible);
    public signal void search_activated();
    public signal void search_changed();
    public signal void search_cleared();
    public signal void search_focus_results_requested();
    public signal void search_result_activated(uint position);

    public WorkspacePane(GLib.ListModel search_model) {
        widget = build_ui(search_model);
    }

    public void set_window_title_text(string title_text) {
        title_label.set_text(title_text);
    }

    public void set_editor_state(string text, bool editable) {
        editor_buffer.set_text(text, -1);
        editor_view.set_editable(editable);
    }

    public void show_editor_mode() {
        content_stack.set_visible_child_name("editor");
    }

    public void show_search_mode() {
        content_stack.set_visible_child_name("search");
    }

    public void toggle_toolbox() {
        if (toolbox_toggle_btn == null) {
            return;
        }
        toolbox_toggle_btn.set_active(!toolbox_toggle_btn.get_active());
    }

    private Gtk.Widget build_ui(GLib.ListModel search_model) {
        var outer = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

        var header = new Adw.HeaderBar();
        title_label = new Gtk.Label("Editor");
        header.set_title_widget(title_label);

        var refresh_btn = new Gtk.Button.from_icon_name("view-refresh-symbolic");
        refresh_btn.set_tooltip_text("Refresh projects and cards");
        refresh_btn.clicked.connect(() => {
            refresh_requested();
        });

        var new_project_btn = new Gtk.Button.from_icon_name("folder-new-symbolic");
        new_project_btn.set_tooltip_text("Create a new project");
        new_project_btn.clicked.connect(() => {
            new_project_requested();
        });

        var new_card_btn = new Gtk.Button.from_icon_name("list-add-symbolic");
        new_card_btn.set_tooltip_text("Create a new card");
        new_card_btn.clicked.connect(() => {
            new_card_requested();
        });

        var ai_toggle_btn = new Gtk.ToggleButton();
        ai_toggle_btn.set_icon_name("preferences-desktop-keyboard-symbolic");
        ai_toggle_btn.set_tooltip_text("Toggle AI status panel");
        ai_toggle_btn.toggled.connect(() => {
            ai_panel_toggled(ai_toggle_btn.get_active());
        });

        toolbox_toggle_btn = new Gtk.ToggleButton();
        toolbox_toggle_btn.set_icon_name("utilities-terminal-symbolic");
        toolbox_toggle_btn.set_tooltip_text("Toggle toolbox panel");
        toolbox_toggle_btn.toggled.connect(() => {
            toolbox_toggled(toolbox_toggle_btn.get_active());
        });

        header.pack_start(refresh_btn);
        header.pack_end(toolbox_toggle_btn);
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
            search_activated();
        });
        search_entry.search_changed.connect(() => {
            search_changed();
        });

        var search_key = new Gtk.EventControllerKey();
        search_key.key_pressed.connect((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Down) {
                search_focus_results_requested();
                return true;
            }
            return false;
        });
        search_entry.add_controller(search_key);

        var clear_search_btn = new Gtk.Button.from_icon_name("edit-clear-symbolic");
        clear_search_btn.set_tooltip_text("Clear search");
        clear_search_btn.clicked.connect(() => {
            search_cleared();
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

        var search_page = build_search_page(search_model);

        content_stack = new Gtk.Stack();
        content_stack.set_vexpand(true);
        content_stack.set_hexpand(true);
        content_stack.add_named(editor_scroll, "editor");
        content_stack.add_named(search_page, "search");
        content_stack.set_visible_child_name("editor");

        ai_panel = new AiPanel();
        ai_split = new Adw.OverlaySplitView();
        ai_split.set_sidebar_position(Gtk.PackType.END);
        ai_split.set_content(content_stack);
        ai_split.set_sidebar(ai_panel.widget);
        ai_split.set_show_sidebar(false);
        ai_split.set_vexpand(true);

        toolbox = new ToolboxPane();

        outer.append(ai_split);
        outer.append(toolbox.widget);
        return outer;
    }

    private Gtk.Widget build_search_page(GLib.ListModel search_model) {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_start(8);
        box.set_margin_end(8);

        search_summary_label = new Gtk.Label("Search results will appear here.") { xalign = 0.0f };
        search_summary_label.add_css_class("dim-label");
        box.append(search_summary_label);

        search_selection = new Gtk.SingleSelection(search_model);
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
            search_result_activated((uint) position);
        });

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_vexpand(true);
        scroll.set_child(search_list);
        box.append(scroll);

        return box;
    }
}

}
