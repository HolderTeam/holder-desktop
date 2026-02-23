namespace HolderLinux {

public class FlowboardPane : Object {
    private Gtk.Label breadcrumb_label;
    private Gtk.Label empty_label;
    private Gtk.Stack state_stack;
    private Gtk.MultiSelection selection;
    private Gtk.GridView grid_view;
    private GLib.ListModel? model;

    public Gtk.Widget widget { get; private set; }

    public signal void tile_activated(uint position);
    public signal void navigate_up_requested();

    public FlowboardPane() {
        selection = new Gtk.MultiSelection(null);
        widget = build_ui();
    }

    public void set_model(GLib.ListModel model) {
        this.model = model;
        selection.set_model(model);
        model.items_changed.connect((position, removed, added) => {
            update_state_visibility();
        });
        update_state_visibility();
    }

    public void set_breadcrumb(string text) {
        breadcrumb_label.set_text(text);
    }

    public void set_empty_message(string text) {
        empty_label.set_text(text);
    }

    private Gtk.Widget build_ui() {
        var outer = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);

        breadcrumb_label = new Gtk.Label("Projects") { xalign = 0.0f };
        breadcrumb_label.add_css_class("dim-label");
        outer.append(breadcrumb_label);

        var factory = new Gtk.SignalListItemFactory();
        factory.setup.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var card = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            card.add_css_class("card");
            card.set_margin_top(6);
            card.set_margin_bottom(6);
            card.set_margin_start(6);
            card.set_margin_end(6);

            var title = new Gtk.Label("") { xalign = 0.0f };
            title.add_css_class("title-5");
            title.set_wrap(true);
            title.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
            var meta = new Gtk.Label("") { xalign = 0.0f };
            meta.add_css_class("dim-label");
            card.append(title);
            card.append(meta);
            list_item.set_child(card);
        });
        factory.bind.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var tile = list_item.get_item() as FlowboardTile;
            var card = list_item.get_child() as Gtk.Box;
            var title = card.get_first_child() as Gtk.Label;
            var meta = title.get_next_sibling() as Gtk.Label;
            if (tile == null) {
                title.set_text("");
                meta.set_text("");
                return;
            }
            title.set_text(tile.title);
            meta.set_text(TextUtils.format_relative_time(new DateTime.now_utc().to_unix(), tile.updated_at));
        });

        grid_view = new Gtk.GridView(selection, factory);
        grid_view.set_enable_rubberband(true);
        grid_view.set_single_click_activate(false);
        grid_view.activate.connect((position) => {
            tile_activated(position);
        });

        var keys = new Gtk.EventControllerKey();
        keys.key_pressed.connect((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                var selected_set = selection.get_selection();
                if (selected_set.get_size() > 0) {
                    tile_activated(selected_set.get_minimum());
                    return true;
                }
            } else if (keyval == Gdk.Key.BackSpace) {
                navigate_up_requested();
                return true;
            }
            return false;
        });
        grid_view.add_controller(keys);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_vexpand(true);
        scroll.set_hexpand(true);
        scroll.set_child(grid_view);

        empty_label = new Gtk.Label("No cards yet.") { xalign = 0.0f };
        empty_label.add_css_class("dim-label");
        var empty_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        empty_box.append(empty_label);

        state_stack = new Gtk.Stack();
        state_stack.set_vexpand(true);
        state_stack.set_hexpand(true);
        state_stack.add_named(scroll, "grid");
        state_stack.add_named(empty_box, "empty");
        state_stack.set_visible_child_name("empty");

        outer.append(state_stack);
        return outer;
    }

    private void update_state_visibility() {
        if (model == null || model.get_n_items() == 0) {
            state_stack.set_visible_child_name("empty");
            return;
        }
        state_stack.set_visible_child_name("grid");
    }
}

}
