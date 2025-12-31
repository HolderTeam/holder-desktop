using Gtk;
using Adw;
using GtkSource;

public class ZetMockup : Adw.Application {
    public ZetMockup () {
        Object(application_id: "com.example.ZetMockup");
    }

    protected override void activate () {
        var win = new Adw.ApplicationWindow(this) {
            default_width = 1200,
            default_height = 800,
            title = "Zet Mockup"
        };

        // Root split: left sidebar + main content
        var root_split = new Adw.OverlaySplitView();
        root_split.set_sidebar_position(Gtk.PackType.START);
        win.set_content(root_split);

        // ----- Sidebar (left) -----
        var sidebar_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

        var sidebar_header = new Adw.HeaderBar();
        sidebar_header.set_title_widget(new Gtk.Label("Notes"));
        sidebar_box.append(sidebar_header);

        var note_store = new GLib.ListStore(typeof(MockItem));
        for (int i = 1; i <= 30; i++) {
            var title = "Note " + i.to_string();
            var preview = "A short preview line...";
            var body = "# " + title + "\n\n"
                + "This is a mock note body for **" + title + "**.\n\n"
                + "- Bullet one\n"
                + "- Bullet two with `inline code`\n\n"
                + "> A short quote block to show styling.\n\n"
                + "```vala\n"
                + "public void example () {\n"
                + "    stdout.printf(\"Hello\\n\");\n"
                + "}\n"
                + "```\n";
            note_store.append(new MockItem(title, preview, body));
        }

        var nav_selection = new Gtk.SingleSelection(note_store);
        var nav_factory = new Gtk.SignalListItemFactory();
        nav_factory.setup.connect((obj) => {
            var li = (Gtk.ListItem) obj;
            var label = new Gtk.Label("") { xalign = 0.0f };
            label.set_margin_top(8);
            label.set_margin_bottom(8);
            label.set_margin_start(12);
            label.set_margin_end(12);
            label.add_css_class("title-4");
            li.set_child(label);
        });
        nav_factory.bind.connect((obj) => {
            var li = (Gtk.ListItem) obj;
            var item = li.get_item() as MockItem;
            var label = li.get_child() as Gtk.Label;
            label.set_text(item.title);
        });

        var nav_list = new Gtk.ListView(nav_selection, nav_factory);
        var nav_scroll = new Gtk.ScrolledWindow();
        nav_scroll.set_child(nav_list);
        nav_scroll.set_vexpand(true);
        sidebar_box.append(nav_scroll);

        root_split.set_sidebar(sidebar_box);
        root_split.set_show_sidebar(true);

        // ----- Workspace page (this is your existing app UI) -----
        var workspace_vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        workspace_vbox.set_vexpand(true);

        // Top header bar (toolbar)
        var header = new Adw.HeaderBar();
        workspace_vbox.append(header);

        var btn_editor = new Gtk.Button.with_label("Editor");
        var btn_board  = new Gtk.Button.with_label("Corkboard");
        var btn_ai     = new Gtk.ToggleButton.with_label("AI");
        var btn_tools  = new Gtk.ToggleButton.with_label("Tools");

        header.pack_start(btn_editor);
        header.pack_start(btn_board);
        header.pack_end(btn_tools);
        header.pack_end(btn_ai);

        // Main work area: center + right AI panel
        var work_split = new Adw.OverlaySplitView();
        work_split.set_vexpand(true);
        work_split.set_sidebar_position(Gtk.PackType.END);
        workspace_vbox.append(work_split);

        // ViewStack in the center: editor vs corkboard
        var stack = new Adw.ViewStack();
        work_split.set_content(stack);

        // Editor view
        var editor_buffer = new GtkSource.Buffer(null);
        editor_buffer.set_highlight_syntax(true);
        editor_buffer.set_highlight_matching_brackets(true);

        var lang_manager = GtkSource.LanguageManager.get_default();
        var markdown_language = lang_manager.get_language("markdown");
        if (markdown_language == null) {
            markdown_language = lang_manager.get_language("markdown-extra");
        }
        if (markdown_language == null) {
            markdown_language = lang_manager.get_language("iotas-markdown");
        }
        if (markdown_language == null) {
            markdown_language = lang_manager.guess_language("note.md", null);
        }
        if (markdown_language != null) {
            editor_buffer.set_language(markdown_language);
        }
        var scheme_manager = GtkSource.StyleSchemeManager.get_default();

        var scheme = scheme_manager.get_scheme("cobalt");
        if (scheme == null) {
            scheme = scheme_manager.get_scheme("tango");
        }
        if (scheme == null) {
            scheme = scheme_manager.get_scheme("Adwaita");
        }
        if (scheme == null) {
            scheme = scheme_manager.get_scheme("classic");
        }
        if (scheme == null) {
            foreach (var scheme_id in scheme_manager.get_scheme_ids()) {
                scheme = scheme_manager.get_scheme(scheme_id);
                if (scheme != null) {
                    break;
                }
            }
        }
        if (scheme != null) {
            editor_buffer.set_style_scheme(scheme);
        }

        var editor = new GtkSource.View.with_buffer(editor_buffer);
        editor.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        editor.set_monospace(true);
        editor.set_show_line_numbers(true);
        editor.set_highlight_current_line(true);

        var editor_scroller = new Gtk.ScrolledWindow();
        editor_scroller.set_child(editor);
        stack.add_titled(editor_scroller, "editor", "Editor");

        // Corkboard view (GridView)
        var sel = new Gtk.SingleSelection(note_store);

        var factory = new Gtk.SignalListItemFactory();

        factory.setup.connect((obj) => {
            var li = (Gtk.ListItem) obj;

            var clamp = new Adw.Clamp();
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            box.set_margin_top(10);
            box.set_margin_bottom(10);
            box.set_margin_start(10);
            box.set_margin_end(10);

            var title = new Gtk.Label("") { xalign = 0.0f };
            title.add_css_class("title-3");

            var preview = new Gtk.Label("") { xalign = 0.0f };
            preview.set_wrap(true);
            preview.set_max_width_chars(24);
            preview.add_css_class("dim-label");

            box.append(title);
            box.append(preview);
            clamp.set_child(box);

            li.set_child(clamp);
        });

        factory.bind.connect((obj) => {
            var li = (Gtk.ListItem) obj;
            var item = li.get_item() as MockItem;

            var clamp = li.get_child() as Adw.Clamp;
            var box = clamp.get_child() as Gtk.Box;

            var title = box.get_first_child() as Gtk.Label;
            var preview = title.get_next_sibling() as Gtk.Label;

            title.set_text(item.title);
            preview.set_text(item.preview);
        });

        var grid = new Gtk.GridView(sel, factory);
        grid.set_max_columns(4);
        grid.set_min_columns(2);

        var board_scroller = new Gtk.ScrolledWindow();
        board_scroller.set_child(grid);
        stack.add_titled(board_scroller, "board", "Corkboard");

        // AI panel on the right
        var ai_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        ai_box.set_margin_top(10);
        ai_box.set_margin_bottom(10);
        ai_box.set_margin_start(10);
        ai_box.set_margin_end(10);

        var ai_title = new Gtk.Label("AI Assistant") { xalign = 0.0f };
        ai_title.add_css_class("title-3");

        var ai_text = new Gtk.TextView();
        ai_text.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        ai_text.set_editable(false);

        var ai_scroll = new Gtk.ScrolledWindow();
        ai_scroll.set_child(ai_text);

        var ai_prompt = new Gtk.Entry();
        ai_prompt.set_placeholder_text("Type prompt here (mock)…");

        var ai_export = new Gtk.Button.with_label("Export Prompt");

        ai_box.append(ai_title);
        ai_box.append(ai_scroll);
        ai_box.append(ai_prompt);
        ai_box.append(ai_export);

        work_split.set_sidebar(ai_box);
        work_split.set_show_sidebar(false); // starts hidden


        // Bottom toolbox (24 lines-ish)
        var tools_revealer = new Gtk.Revealer();
        tools_revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_UP);
        tools_revealer.set_reveal_child(false);

        root_split.set_content(workspace_vbox);


        // Frame-ish container
        var tools_frame = new Adw.Clamp();

        var tools_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        tools_box.set_margin_top(10);
        tools_box.set_margin_bottom(10);
        tools_box.set_margin_start(10);
        tools_box.set_margin_end(10);

        var tools_title = new Gtk.Label("Toolbox") { xalign = 0.0f };
        tools_title.add_css_class("title-3");
        tools_box.append(tools_title);

        // Text view + scroller
        var tools_text = new Gtk.TextView();
        tools_text.set_monospace(true);
        tools_text.set_editable(false);
        tools_text.set_wrap_mode(Gtk.WrapMode.NONE);

        var tools_scroll = new Gtk.ScrolledWindow();
        tools_scroll.set_child(tools_text);

        // Populate text

        var buf = tools_text.get_buffer();
        string demo = "";
        for (int i = 1; i <= 24; i++) {
            demo += "tool line " + i.to_string() + "\n";
        }
        buf.set_text(demo, -1);

        // Approx height for 24 lines. Tweak this number to taste.
        tools_scroll.set_min_content_height(24 * 18);  // ~18px per line
        tools_scroll.set_vexpand(false);

        tools_box.append(tools_scroll);
        tools_frame.set_child(tools_box);

        tools_revealer.set_child(tools_frame);
        workspace_vbox.append(tools_revealer);

        // Wiring buttons
        btn_editor.clicked.connect(() => stack.set_visible_child_name("editor"));
        btn_board.clicked.connect(() => stack.set_visible_child_name("board"));

        btn_ai.toggled.connect(() => {
            work_split.set_show_sidebar(btn_ai.active);
        });

        btn_tools.toggled.connect(() => {
            tools_revealer.set_reveal_child(btn_tools.active);
        });

        nav_selection.notify["selected"].connect(() => {
            var item = nav_selection.get_selected_item() as MockItem;
            if (item != null) {
                editor_buffer.set_text(item.body, -1);
                if (markdown_language != null) {
                    editor_buffer.set_language(markdown_language);
                }
                if (scheme != null) {
                    editor_buffer.set_style_scheme(scheme);
                }
                editor_buffer.set_highlight_syntax(true);
                GLib.Idle.add(() => {
                    Gtk.TextIter idle_start;
                    Gtk.TextIter idle_end;
                    editor_buffer.get_bounds(out idle_start, out idle_end);
                    editor_buffer.ensure_highlight(idle_start, idle_end);
                    return GLib.Source.REMOVE;
                });
                stack.set_visible_child_name("editor");
            }
        });
        nav_selection.set_selected(0);

        win.present();
    }

    public static int main (string[] args) {
        Adw.init();
        GtkSource.init();
        return new ZetMockup().run(args);
    }
}

public class MockItem : Object {
    public string title { get; construct; }
    public string preview { get; construct; }
    public string body { get; construct; }

    public MockItem(string title, string preview, string body) {
        Object(title: title, preview: preview, body: body);
    }
}
