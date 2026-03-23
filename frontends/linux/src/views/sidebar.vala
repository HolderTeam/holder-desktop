namespace HolderLinux {

public class SidebarPane : Object {
    public Gtk.Widget widget { get; private set; }
    private Gtk.Label threads_title;
    private Gtk.ScrolledWindow thread_scroll;
    public signal void card_move_to_trash_requested(string card_id);
    public signal void card_context_selection_requested(string card_id);
    public signal void card_create_child_requested(string card_id);

    public SidebarPane(Gtk.SelectionModel project_selection,
                       Gtk.SelectionModel card_selection,
                       Gtk.SelectionModel ai_thread_selection) {
        widget = build_ui(project_selection, card_selection, ai_thread_selection);
        ai_thread_selection.items_changed.connect((position, removed, added) => {
            update_ai_threads_visibility(ai_thread_selection);
        });
        update_ai_threads_visibility(ai_thread_selection);
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
        sidebar_header.set_show_start_title_buttons(false);
        sidebar_header.set_show_end_title_buttons(false);
        sidebar_header.set_title_widget(new Gtk.Label("Holder"));
        box.append(sidebar_header);

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
        project_list.set_vexpand(false);

        var project_scroll = new Gtk.ScrolledWindow();
        project_scroll.set_propagate_natural_height(true);
        project_scroll.set_max_content_height(336);
        project_scroll.set_vexpand(false);
        project_scroll.set_child(project_list);
        box.append(project_scroll);

        threads_title = new Gtk.Label("AI Threads") { xalign = 0.0f };
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
        thread_list.set_vexpand(false);
        thread_scroll = new Gtk.ScrolledWindow();
        thread_scroll.set_propagate_natural_height(true);
        thread_scroll.set_max_content_height(216);
        thread_scroll.set_vexpand(false);
        thread_scroll.set_child(thread_list);
        box.append(thread_scroll);

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

            var context_click = new Gtk.GestureClick();
            context_click.set_button(Gdk.BUTTON_SECONDARY);
            context_click.pressed.connect((n_press, x, y) => {
                if (n_press != 1) {
                    return;
                }
                var card_id = row.get_data<string>("sidebar-card-id");
                if (card_id == null || card_id.strip().length == 0) {
                    return;
                }
                card_context_selection_requested(card_id);
                show_card_menu_at(row, card_id, x, y);
            });
            row.add_controller(context_click);
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
                row.set_data<string>("sidebar-card-id", "");
                return;
            }
            title.set_text(card.title);
            updated.set_text("Updated %s".printf(format_relative_time(card.updated_at)));
            row.set_data<string>("sidebar-card-id", card.card_id);
        });

        var card_list = new Gtk.ListView(card_selection, card_factory);
        card_list.set_vexpand(true);

        var card_scroll = new Gtk.ScrolledWindow();
        card_scroll.set_vexpand(true);
        card_scroll.set_child(card_list);
        box.append(card_scroll);

        var card_keys = new Gtk.EventControllerKey();
        card_keys.key_pressed.connect((keyval, keycode, state) => {
            if (keyval != Gdk.Key.Delete && keyval != Gdk.Key.KP_Delete) {
                return false;
            }
            var single = card_selection as Gtk.SingleSelection;
            if (single == null) {
                return false;
            }
            var selected_card = single.get_selected_item() as CardSummary;
            if (selected_card == null) {
                return false;
            }
            card_move_to_trash_requested(selected_card.card_id);
            return true;
        });
        card_list.add_controller(card_keys);

        return box;
    }

    private void update_ai_threads_visibility(Gtk.SelectionModel ai_thread_selection) {
        bool has_threads = ai_thread_selection.get_n_items() > 0;
        threads_title.set_visible(has_threads);
        thread_scroll.set_visible(has_threads);
    }

    private string format_relative_time(int64 timestamp) {
        return TextUtils.format_relative_time(new DateTime.now_utc().to_unix(), timestamp);
    }

    private void show_card_menu_at(Gtk.Widget row_widget, string card_id, double x, double y) {
        var popover = new Gtk.Popover();
        popover.set_autohide(true);
        popover.set_parent(row_widget);

        var menu_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        var child_btn = new Gtk.Button.with_label("Create Child Card");
        child_btn.add_css_class("flat");
        child_btn.clicked.connect(() => {
            popover.popdown();
            card_create_child_requested(card_id);
        });
        menu_box.append(child_btn);

        var trash_btn = new Gtk.Button.with_label("Move to Trash");
        trash_btn.add_css_class("flat");
        trash_btn.clicked.connect(() => {
            popover.popdown();
            card_move_to_trash_requested(card_id);
        });
        menu_box.append(trash_btn);
        popover.set_child(menu_box);

        var rect = Gdk.Rectangle();
        rect.x = (int) x;
        rect.y = (int) y;
        rect.width = 1;
        rect.height = 1;
        popover.set_pointing_to(rect);
        popover.popup();
    }
}

}
