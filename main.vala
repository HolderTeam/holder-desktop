using Gtk;
using Adw;

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
        sidebar_header.set_title_widget(new Gtk.Label("Navigation"));
        sidebar_box.append(sidebar_header);

        var nav_list = new Gtk.ListBox();
        nav_list.append(make_row("Recents"));
        nav_list.append(make_row("Inbox"));
        nav_list.append(make_row("Projects"));
        nav_list.append(make_row("Search"));
        sidebar_box.append(nav_list);

        root_split.set_sidebar(sidebar_box);
        root_split.set_show_sidebar(true);

        // ----- Main content (right) -----
        var content_vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        root_split.set_content(content_vbox);

        // Top header bar (toolbar)
        var header = new Adw.HeaderBar();
        content_vbox.append(header);

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
        work_split.set_sidebar_position(Gtk.PackType.END);
        content_vbox.append(work_split);

        // ViewStack in the center: editor vs corkboard
        var stack = new Adw.ViewStack();
        work_split.set_content(stack);

        // Editor view
        var editor = new Gtk.TextView();
        editor.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        editor.set_monospace(true);

        var editor_scroller = new Gtk.ScrolledWindow();
        editor_scroller.set_child(editor);
        stack.add_titled(editor_scroller, "editor", "Editor");

        // Corkboard view (GridView)
        var store = new GLib.ListStore(typeof(MockItem));
        for (int i = 1; i <= 30; i++) {
            store.append(new MockItem("Card " + i.to_string(), "A short preview line…"));
        }

        var sel = new Gtk.SingleSelection(store);

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

        // Bottom toolbox (simple mock)
        var tools_revealer = new Gtk.Revealer();
        tools_revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_UP);
        tools_revealer.set_reveal_child(false);

        var tools_frame = new Adw.Clamp();
        var tools_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        tools_box.set_margin_top(10);
        tools_box.set_margin_bottom(10);
        tools_box.set_margin_start(10);
        tools_box.set_margin_end(10);

        var tools_title = new Gtk.Label("Toolbox") { xalign = 0.0f };
        tools_title.add_css_class("title-3");

        var tools_label = new Gtk.Label("Terminal / logs / model output could live here.")
            { xalign = 0.0f };
        tools_label.set_wrap(true);

        tools_box.append(tools_title);
        tools_box.append(tools_label);
        tools_frame.set_child(tools_box);

        tools_revealer.set_child(tools_frame);
        content_vbox.append(tools_revealer);

        // Wiring buttons
        btn_editor.clicked.connect(() => stack.set_visible_child_name("editor"));
        btn_board.clicked.connect(() => stack.set_visible_child_name("board"));

        btn_ai.toggled.connect(() => {
            work_split.set_show_sidebar(btn_ai.active);
        });

        btn_tools.toggled.connect(() => {
            tools_revealer.set_reveal_child(btn_tools.active);
        });

        win.present();
    }

    private static Gtk.ListBoxRow make_row(string text) {
        var row = new Gtk.ListBoxRow();
        var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_start(10);
        box.set_margin_end(10);

        var label = new Gtk.Label(text) { xalign = 0.0f };
        box.append(label);
        row.set_child(box);
        return row;
    }

    public static int main (string[] args) {
        Adw.init();
        return new ZetMockup().run(args);
    }
}

public class MockItem : Object {
    public string title { get; construct; }
    public string preview { get; construct; }

    public MockItem(string title, string preview) {
        Object(title: title, preview: preview);
    }
}
