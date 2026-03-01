namespace HolderLinux {

public class SidebarPane : Object {
    public Gtk.Widget widget { get; private set; }
    private Gtk.Label status_label;

    public SidebarPane(Gtk.SelectionModel project_selection,
                       Gtk.SelectionModel card_selection,
                       Gtk.SelectionModel ai_thread_selection) {
        widget = build_ui(project_selection, card_selection, ai_thread_selection);
        set_status_text("Connecting to Holder...");
    }

    public void set_status_text(string text) {
        status_label.set_text(text);
    }

    private Gtk.Widget build_ui(Gtk.SelectionModel project_selection,
                                Gtk.SelectionModel card_selection,
                                Gtk.SelectionModel ai_thread_selection) {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        box.add_css_class("navigation-sidebar");
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_start(8);
        box.set_margin_end(8);

        var sidebar_header = new Adw.HeaderBar();
        sidebar_header.set_title_widget(new Gtk.Label("Holder"));
        box.append(sidebar_header);

        status_label = new Gtk.Label("") { xalign = 0.0f };
        status_label.add_css_class("caption");
        status_label.add_css_class("dim-label");
        status_label.set_wrap(true);
        status_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        status_label.set_ellipsize(Pango.EllipsizeMode.NONE);
        status_label.set_max_width_chars(30);
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

    private string format_relative_time(int64 timestamp) {
        return TextUtils.format_relative_time(new DateTime.now_utc().to_unix(), timestamp);
    }
}

}
