using Gtk;
using Adw;
using GtkSource;
using Gdk;

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

        var css = new Gtk.CssProvider();
        css.load_from_string(
            ".nav-actions row { min-height: 48px; padding: 10px 10px; }\n" +
            ".nav-actions list row { min-height: 48px; padding: 10px 10px; }\n" +
            ".nav-actions row > box { margin-top: 2px; margin-bottom: 2px; }"
        );
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        // Root split: left sidebar + main content
        var root_split = new Adw.OverlaySplitView();
        root_split.set_sidebar_position(Gtk.PackType.START);
        win.set_content(root_split);

        // ----- Sidebar (left) -----
        var sidebar_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        sidebar_box.add_css_class("navigation-sidebar");

        var sidebar_header = new Adw.HeaderBar();
        sidebar_header.set_title_widget(new Gtk.Label("Navigation"));
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

        int next_note_id = 31;

        var nav_stack = new Gtk.Stack();
        var new_card_page = new Gtk.Label("New Card");
        nav_stack.add_titled(new_card_page, "new-card", "New Card");
        nav_stack.get_page(new_card_page).set_icon_name("document-new-symbolic");

        var nav_sidebar = new Gtk.StackSidebar();
        nav_sidebar.set_stack(nav_stack);
        nav_sidebar.add_css_class("navigation-sidebar");
        nav_sidebar.add_css_class("nav-actions");
        nav_sidebar.set_margin_top(6);
        nav_sidebar.set_margin_bottom(6);
        nav_sidebar.set_margin_start(6);
        nav_sidebar.set_margin_end(6);

        var nav_separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);

        var nav_actions_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        nav_actions_box.append(nav_sidebar);
        nav_actions_box.append(nav_separator);
        nav_actions_box.set_vexpand(false);
        sidebar_box.append(nav_actions_box);

        var sidebar_scroll = new Gtk.ScrolledWindow();
        sidebar_scroll.set_vexpand(true);
        sidebar_scroll.set_margin_top(6);
        sidebar_box.append(sidebar_scroll);

        var sidebar_content = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        sidebar_content.set_margin_top(6);
        sidebar_content.set_margin_bottom(6);
        sidebar_content.set_margin_start(6);
        sidebar_content.set_margin_end(6);
        sidebar_scroll.set_child(sidebar_content);

        var projects_label = new Gtk.Label("Projects") { xalign = 0.0f };
        projects_label.add_css_class("heading");
        sidebar_content.append(projects_label);

        var project_store = new GLib.ListStore(typeof(ProjectItem));
        project_store.append(new ProjectItem("Zettel Core"));
        project_store.append(new ProjectItem("Design Notes"));
        project_store.append(new ProjectItem("Research Drafts"));
        project_store.append(new ProjectItem("Code Experiments"));

        var project_selection = new Gtk.SingleSelection(project_store);
        var project_factory = new Gtk.SignalListItemFactory();
        project_factory.setup.connect((obj) => {
            var li = (Gtk.ListItem) obj;
            var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var icon = new Gtk.Image.from_icon_name("folder-symbolic");
            var label = new Gtk.Label("") { xalign = 0.0f };
            label.add_css_class("title-4");
            row.append(icon);
            row.append(label);
            li.set_child(row);
        });
        project_factory.bind.connect((obj) => {
            var li = (Gtk.ListItem) obj;
            var item = li.get_item() as ProjectItem;
            var row = li.get_child() as Gtk.Box;
            var label = row.get_last_child() as Gtk.Label;
            label.set_text(item.name);
        });

        var project_list = new Gtk.ListView(project_selection, project_factory);
        project_list.add_css_class("navigation-sidebar");
        sidebar_content.append(project_list);

        var separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        sidebar_content.append(separator);

        var cards_label = new Gtk.Label("Your Cards") { xalign = 0.0f };
        cards_label.add_css_class("heading");
        sidebar_content.append(cards_label);

        var card_selection = new Gtk.SingleSelection(note_store);
        var card_factory = new Gtk.SignalListItemFactory();
        card_factory.setup.connect((obj) => {
            var li = (Gtk.ListItem) obj;
            var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var icon = new Gtk.Image.from_icon_name("text-x-generic-symbolic");
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            var title = new Gtk.Label("") { xalign = 0.0f };
            title.add_css_class("title-4");
            var preview = new Gtk.Label("") { xalign = 0.0f };
            preview.add_css_class("dim-label");
            preview.set_wrap(true);
            preview.set_max_width_chars(22);
            box.append(title);
            box.append(preview);
            row.append(icon);
            row.append(box);
            li.set_child(row);
        });
        card_factory.bind.connect((obj) => {
            var li = (Gtk.ListItem) obj;
            var item = li.get_item() as MockItem;
            var row = li.get_child() as Gtk.Box;
            var box = row.get_last_child() as Gtk.Box;
            var title = box.get_first_child() as Gtk.Label;
            var preview = title.get_next_sibling() as Gtk.Label;
            title.set_text(item.title);
            preview.set_text(item.preview);
        });

        var card_list = new Gtk.ListView(card_selection, card_factory);
        card_list.add_css_class("navigation-sidebar");
        sidebar_content.append(card_list);

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
        var btn_search = new Gtk.Button.with_label("Search");
        var btn_ai     = new Gtk.ToggleButton.with_label("AI");
        var btn_tools  = new Gtk.ToggleButton.with_label("Tools");

        header.pack_start(btn_editor);
        header.pack_start(btn_board);
        header.pack_start(btn_search);
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

        var fence_highlighter = new FenceHighlighter(editor_buffer, lang_manager, scheme);
        editor_buffer.changed.connect(() => {
            fence_highlighter.schedule_update();
        });

        void set_editor_from_note(MockItem item) {
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
                fence_highlighter.schedule_update();
                return GLib.Source.REMOVE;
            });
            stack.set_visible_child_name("editor");
        }

        void show_search() {
            editor_buffer.set_text("# Search\n\nType to search your notes.\n", -1);
            if (markdown_language != null) {
                editor_buffer.set_language(markdown_language);
            }
            stack.set_visible_child_name("editor");
        }

        // Wiring buttons
        btn_editor.clicked.connect(() => stack.set_visible_child_name("editor"));
        btn_board.clicked.connect(() => stack.set_visible_child_name("board"));
        btn_search.clicked.connect(() => show_search());

        btn_ai.toggled.connect(() => {
            work_split.set_show_sidebar(btn_ai.active);
        });

        btn_tools.toggled.connect(() => {
            tools_revealer.set_reveal_child(btn_tools.active);
        });

        card_selection.notify["selected"].connect(() => {
            var item = card_selection.get_selected_item() as MockItem;
            if (item != null) {
                set_editor_from_note(item);
            }
        });

        project_selection.notify["selected"].connect(() => {
            var item = project_selection.get_selected_item() as ProjectItem;
            if (item != null) {
                editor_buffer.set_text(
                    "# Project: " + item.name + "\n\nRecent activity (mock)...\n",
                    -1
                );
                if (markdown_language != null) {
                    editor_buffer.set_language(markdown_language);
                }
                stack.set_visible_child_name("editor");
            }
        });

        nav_stack.notify["visible-child-name"].connect(() => {
            var name = nav_stack.get_visible_child_name();
            if (name == "new-card") {
                var title = "Note " + next_note_id.to_string();
                next_note_id++;
                var preview = "New card created...";
                var body = "# " + title + "\n\nStart writing here.\n";
                var item = new MockItem(title, preview, body);
                note_store.append(item);
                card_selection.set_selected(note_store.get_n_items() - 1);
            }
        });

        nav_stack.set_visible_child_name("new-card");
        card_selection.set_selected(0);

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

public class ProjectItem : Object {
    public string name { get; construct; }

    public ProjectItem(string name) {
        Object(name: name);
    }
}

public class FenceHighlighter : Object {
    private GtkSource.Buffer buffer;
    private GtkSource.LanguageManager lang_manager;
    private GtkSource.StyleScheme? scheme;
    private uint update_id = 0;
    private Gee.ArrayList<Gtk.TextTag> fence_tags = new Gee.ArrayList<Gtk.TextTag>();
    private int tag_serial = 0;

    public FenceHighlighter(GtkSource.Buffer buffer,
                            GtkSource.LanguageManager lang_manager,
                            GtkSource.StyleScheme? scheme) {
        this.buffer = buffer;
        this.lang_manager = lang_manager;
        this.scheme = scheme;
    }

    public void schedule_update() {
        if (update_id != 0) {
            return;
        }
        update_id = GLib.Timeout.add(150, () => {
            update_id = 0;
            update_highlighting();
            return GLib.Source.REMOVE;
        });
    }

    private void update_highlighting() {
        Gtk.TextIter buf_start;
        Gtk.TextIter buf_end;
        buffer.get_bounds(out buf_start, out buf_end);

        remove_previous_tags(buf_start, buf_end);

        var text = buffer.get_text(buf_start, buf_end, false);
        tag_serial = 0;

        bool in_fence = false;
        string? fence_lang = null;
        int fence_content_start = 0;

        int line_start = 0;
        for (int i = 0; i <= text.length; i++) {
            bool line_end = (i == text.length) || (text.get_char(i) == '\n');
            if (!line_end) {
                continue;
            }

            string line = text.substring(line_start, i - line_start);
            string trimmed = line.strip();

            if (trimmed.has_prefix("```")) {
                if (!in_fence) {
                    in_fence = true;
                    fence_lang = parse_fence_language(trimmed);
                    fence_content_start = i + 1;
                } else {
                    int fence_content_end = line_start;
                    if (fence_content_end >= fence_content_start) {
                        var language = resolve_fence_language(fence_lang);
                        if (language != null) {
                            var code = text.substring(
                                fence_content_start,
                                fence_content_end - fence_content_start
                            );
                            apply_language_tags(code, fence_content_start, language);
                        }
                    }
                    in_fence = false;
                    fence_lang = null;
                }
            }

            line_start = i + 1;
        }
    }

    private void remove_previous_tags(Gtk.TextIter buf_start, Gtk.TextIter buf_end) {
        var tag_table = buffer.get_tag_table();
        foreach (var tag in fence_tags) {
            if (tag != null) {
                buffer.remove_tag(tag, buf_start, buf_end);
                tag_table.remove(tag);
            }
        }
        fence_tags.clear();
    }

    private string? parse_fence_language(string trimmed) {
        if (!trimmed.has_prefix("```")) {
            return null;
        }
        var after = trimmed.substring(3).strip();
        if (after.length == 0) {
            return null;
        }
        var parts = after.split(" ");
        return parts.length > 0 ? parts[0].down() : null;
    }

    private GtkSource.Language? resolve_fence_language(string? fence_lang) {
        if (fence_lang == null || fence_lang.strip().length == 0) {
            return null;
        }
        var id = fence_lang.down();
        switch (id) {
            case "js":
            case "javascript":
                id = "js";
                break;
            case "ts":
            case "typescript":
                id = "typescript";
                break;
            case "py":
                id = "python";
                break;
            case "c++":
            case "cpp":
                id = "cpp";
                break;
            case "c#":
            case "csharp":
                id = "c-sharp";
                break;
            case "bash":
            case "shell":
                id = "sh";
                break;
            case "yml":
                id = "yaml";
                break;
            case "md":
                id = "markdown";
                break;
        }

        var lang = lang_manager.get_language(id);
        if (lang != null) {
            return lang;
        }
        return lang_manager.guess_language("file." + id, null);
    }

    private void apply_language_tags(string code,
                                     int start_offset,
                                     GtkSource.Language language) {
        var code_buffer = new GtkSource.Buffer(null);
        code_buffer.set_highlight_syntax(true);
        code_buffer.set_language(language);
        if (scheme != null) {
            code_buffer.set_style_scheme(scheme);
        }
        code_buffer.set_text(code, -1);

        Gtk.TextIter code_start;
        Gtk.TextIter code_end;
        code_buffer.get_bounds(out code_start, out code_end);
        code_buffer.ensure_highlight(code_start, code_end);

        var code_table = code_buffer.get_tag_table();
        code_table.foreach((tag) => {
            apply_tag_ranges(tag, code_buffer, start_offset);
        });
    }

    private void apply_tag_ranges(Gtk.TextTag source_tag,
                                  GtkSource.Buffer code_buffer,
                                  int start_offset) {
        Gtk.TextIter iter;
        code_buffer.get_start_iter(out iter);

        bool in_tag = iter.has_tag(source_tag);
        Gtk.TextIter range_start = iter;

        while (iter.forward_to_tag_toggle(source_tag)) {
            if (in_tag) {
                apply_tag_range(source_tag, range_start, iter, start_offset);
            }
            in_tag = iter.has_tag(source_tag);
            if (in_tag) {
                range_start = iter;
            }
        }

        if (in_tag) {
            Gtk.TextIter end_iter;
            code_buffer.get_end_iter(out end_iter);
            apply_tag_range(source_tag, range_start, end_iter, start_offset);
        }
    }

    private void apply_tag_range(Gtk.TextTag source_tag,
                                 Gtk.TextIter range_start,
                                 Gtk.TextIter range_end,
                                 int start_offset) {
        int range_start_offset = range_start.get_offset();
        int range_end_offset = range_end.get_offset();
        if (range_end_offset <= range_start_offset) {
            return;
        }

        string tag_name = "fence-tag-" + tag_serial.to_string();
        tag_serial++;

        var tag_table = buffer.get_tag_table();
        var dest_tag = tag_table.lookup(tag_name);
        if (dest_tag == null) {
            dest_tag = new Gtk.TextTag(tag_name);
            copy_tag_style(source_tag, dest_tag);
            tag_table.add(dest_tag);
            fence_tags.add(dest_tag);
        }

        Gtk.TextIter main_start;
        Gtk.TextIter main_end;
        buffer.get_iter_at_offset(out main_start, start_offset + range_start_offset);
        buffer.get_iter_at_offset(out main_end, start_offset + range_end_offset);
        buffer.apply_tag(dest_tag, main_start, main_end);
    }

    private void copy_tag_style(Gtk.TextTag source_tag, Gtk.TextTag dest_tag) {
        copy_rgba_property(source_tag, dest_tag, "foreground-rgba", "foreground-set");
        copy_rgba_property(source_tag, dest_tag, "background-rgba", "background-set");
        copy_enum_property(source_tag, dest_tag, "style", "style-set", typeof(Pango.Style));
        copy_enum_property(source_tag, dest_tag, "underline", "underline-set", typeof(Pango.Underline));
        copy_int_property(source_tag, dest_tag, "weight", "weight-set");
        copy_bool_property(source_tag, dest_tag, "strikethrough", "strikethrough-set");
        copy_double_property(source_tag, dest_tag, "scale", "scale-set");
    }

    private bool get_bool_property(Gtk.TextTag tag, string name) {
        GLib.Value val = GLib.Value(typeof(bool));
        tag.get_property(name, ref val);
        return (bool) val;
    }

    private void copy_rgba_property(Gtk.TextTag source_tag,
                                    Gtk.TextTag dest_tag,
                                    string value_prop,
                                    string set_prop) {
        if (!get_bool_property(source_tag, set_prop)) {
            return;
        }
        GLib.Value val = GLib.Value(typeof(Gdk.RGBA));
        source_tag.get_property(value_prop, ref val);
        dest_tag.set_property(value_prop, val);
        dest_tag.set_property(set_prop, true);
    }

    private void copy_int_property(Gtk.TextTag source_tag,
                                   Gtk.TextTag dest_tag,
                                   string value_prop,
                                   string set_prop) {
        if (!get_bool_property(source_tag, set_prop)) {
            return;
        }
        GLib.Value val = GLib.Value(typeof(int));
        source_tag.get_property(value_prop, ref val);
        dest_tag.set_property(value_prop, val);
        dest_tag.set_property(set_prop, true);
    }

    private void copy_enum_property(Gtk.TextTag source_tag,
                                    Gtk.TextTag dest_tag,
                                    string value_prop,
                                    string set_prop,
                                    Type enum_type) {
        if (!get_bool_property(source_tag, set_prop)) {
            return;
        }
        GLib.Value val = GLib.Value(enum_type);
        source_tag.get_property(value_prop, ref val);
        dest_tag.set_property(value_prop, val);
        dest_tag.set_property(set_prop, true);
    }

    private void copy_double_property(Gtk.TextTag source_tag,
                                      Gtk.TextTag dest_tag,
                                      string value_prop,
                                      string set_prop) {
        if (!get_bool_property(source_tag, set_prop)) {
            return;
        }
        GLib.Value val = GLib.Value(typeof(double));
        source_tag.get_property(value_prop, ref val);
        dest_tag.set_property(value_prop, val);
        dest_tag.set_property(set_prop, true);
    }

    private void copy_bool_property(Gtk.TextTag source_tag,
                                    Gtk.TextTag dest_tag,
                                    string value_prop,
                                    string set_prop) {
        if (!get_bool_property(source_tag, set_prop)) {
            return;
        }
        GLib.Value val = GLib.Value(typeof(bool));
        source_tag.get_property(value_prop, ref val);
        dest_tag.set_property(value_prop, val);
        dest_tag.set_property(set_prop, true);
    }
}
