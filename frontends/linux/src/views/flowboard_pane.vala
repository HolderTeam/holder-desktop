namespace HolderLinux {

namespace GtkCompat {
    [CCode(cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
    public extern static void add_provider_for_display(Gdk.Display display, Gtk.StyleProvider provider, uint priority);
}

public class FlowboardPane : Object {
    private const string DROP_BEFORE_CLASS = "flowboard-drop-before";
    private const string DROP_INTO_CLASS = "flowboard-drop-into";
    private const string DROP_AFTER_CLASS = "flowboard-drop-after";
    private const string DRAG_ACTIVE_CLASS = "flowboard-drag-active";
    private static bool drop_css_installed = false;

    private Gtk.Box breadcrumb_bar;
    private Gtk.Label empty_label;
    private Gtk.Stack state_stack;
    private Gtk.MultiSelection selection;
    private Gtk.GridView grid_view;
    private GLib.ListModel? model;

    public Gtk.Widget widget { get; private set; }

    public signal void tile_activated(uint position);
    public signal void navigate_up_requested();
    public signal void card_drop_requested(string source_card_id, string target_card_id, double target_y_fraction);
    public signal void background_drop_requested(string source_card_id);
    public signal void breadcrumb_segment_activated(int index);

    public FlowboardPane() {
        ensure_drop_css();
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

    public void set_breadcrumb_segments(Gee.ArrayList<FlowboardBreadcrumbSegment> segments) {
        clear_box_children(breadcrumb_bar);
        for (int i = 0; i < segments.size; i++) {
            var segment = segments[i];
            var btn = new Gtk.Button.with_label(segment.label);
            btn.add_css_class("flat");
            btn.clicked.connect(() => {
                breadcrumb_segment_activated(i);
            });
            breadcrumb_bar.append(btn);
            if (i < segments.size - 1) {
                var sep = new Gtk.Label(" / ");
                sep.add_css_class("dim-label");
                breadcrumb_bar.append(sep);
            }
        }
    }

    public void set_empty_message(string text) {
        empty_label.set_text(text);
    }

    private Gtk.Widget build_ui() {
        var outer = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);

        breadcrumb_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        outer.append(breadcrumb_bar);

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
            install_drag_and_drop(card);
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
            if (tile.is_container) {
                meta.set_text("Folder");
            } else {
                meta.set_text(TextUtils.format_relative_time(new DateTime.now_utc().to_unix(), tile.updated_at));
            }

            if (!tile.is_container && tile.card_id != null) {
                card.set_data<string>("flowboard-card-id", tile.card_id);
            } else {
                card.set_data<string>("flowboard-card-id", "");
            }
        });

        grid_view = new Gtk.GridView(selection, factory);
        grid_view.add_css_class("flowboard-grid");
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

        var pointer_click = new Gtk.GestureClick();
        pointer_click.set_button(Gdk.BUTTON_PRIMARY);
        pointer_click.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);
        pointer_click.pressed.connect((n_press, x, y) => {
            if (n_press != 1) {
                return;
            }
            var picked = grid_view.pick(x, y, Gtk.PickFlags.DEFAULT);
            var background_press = (picked == null || picked == grid_view);
            grid_view.set_enable_rubberband(background_press);

            var state = pointer_click.get_current_event_state();
            if (background_press &&
                (state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK)) == 0) {
                selection.unselect_all();
            }
        });
        pointer_click.released.connect((n_press, x, y) => {
            grid_view.set_enable_rubberband(true);
        });
        grid_view.add_controller(pointer_click);

        var grid_drop = new Gtk.DropTarget(typeof(string), Gdk.DragAction.MOVE);
        grid_drop.enter.connect((x, y) => {
            grid_view.add_css_class(DRAG_ACTIVE_CLASS);
            return Gdk.DragAction.MOVE;
        });
        grid_drop.drop.connect((value, x, y) => {
            string? source_card_id = value.get_string();
            if (source_card_id == null || source_card_id.strip().length == 0) {
                grid_view.remove_css_class(DRAG_ACTIVE_CLASS);
                return false;
            }
            grid_view.remove_css_class(DRAG_ACTIVE_CLASS);
            background_drop_requested(source_card_id);
            return true;
        });
        grid_drop.leave.connect(() => {
            grid_view.remove_css_class(DRAG_ACTIVE_CLASS);
        });
        grid_view.add_controller(grid_drop);

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

    private void install_drag_and_drop(Gtk.Widget row_widget) {
        row_widget.add_css_class("flowboard-drop-target");
        var drag_source = new Gtk.DragSource();
        drag_source.set_actions(Gdk.DragAction.MOVE);
        drag_source.prepare.connect((x, y) => {
            var card_id = row_widget.get_data<string>("flowboard-card-id");
            if (card_id == null || card_id.strip().length == 0) {
                return null;
            }
            Value payload = Value(typeof(string));
            payload.set_string(card_id);
            return new Gdk.ContentProvider.for_value(payload);
        });
        row_widget.add_controller(drag_source);

        var drop_target = new Gtk.DropTarget(typeof(string), Gdk.DragAction.MOVE);
        drop_target.enter.connect((x, y) => {
            grid_view.add_css_class(DRAG_ACTIVE_CLASS);
            update_drop_hint(row_widget, y);
            return Gdk.DragAction.MOVE;
        });
        drop_target.motion.connect((x, y) => {
            update_drop_hint(row_widget, y);
            return Gdk.DragAction.MOVE;
        });
        drop_target.leave.connect(() => {
            clear_drop_hint(row_widget);
            grid_view.remove_css_class(DRAG_ACTIVE_CLASS);
        });
        drop_target.drop.connect((value, x, y) => {
            string? source_card_id = value.get_string();
            var target_card_id = row_widget.get_data<string>("flowboard-card-id");
            if (target_card_id == null || target_card_id.strip().length == 0) {
                clear_drop_hint(row_widget);
                grid_view.remove_css_class(DRAG_ACTIVE_CLASS);
                return false;
            }
            if (source_card_id == null || source_card_id.strip().length == 0 || source_card_id == target_card_id) {
                clear_drop_hint(row_widget);
                grid_view.remove_css_class(DRAG_ACTIVE_CLASS);
                return false;
            }
            var height = row_widget.get_height();
            double y_fraction = 0.5;
            if (height > 0) {
                y_fraction = y / (double) height;
            }
            if (y_fraction < 0.0) {
                y_fraction = 0.0;
            } else if (y_fraction > 1.0) {
                y_fraction = 1.0;
            }
            clear_drop_hint(row_widget);
            grid_view.remove_css_class(DRAG_ACTIVE_CLASS);
            card_drop_requested(source_card_id, target_card_id, y_fraction);
            return true;
        });
        row_widget.add_controller(drop_target);
    }

    private static void ensure_drop_css() {
        if (drop_css_installed) {
            return;
        }
        var display = Gdk.Display.get_default();
        if (display == null) {
            return;
        }
        var provider = new Gtk.CssProvider();
        provider.load_from_string("""
            .flowboard-grid:drop(active) {
                outline: none;
                box-shadow: none;
                border-color: transparent;
            }
            .flowboard-drop-target {
                transition: 120ms ease;
            }
            .flowboard-drag-active .flowboard-drop-target {
                opacity: 0.45;
            }
            .flowboard-drag-active .flowboard-drop-before,
            .flowboard-drag-active .flowboard-drop-into,
            .flowboard-drag-active .flowboard-drop-after {
                opacity: 1.0;
            }
            .flowboard-drop-before {
                border-top: 0;
                box-shadow: 0 -6px 0 0 @accent_color;
            }
            .flowboard-drop-into {
                outline: 3px solid @accent_color;
                outline-offset: -3px;
                background-color: alpha(@accent_color, 0.16);
            }
            .flowboard-drop-after {
                border-bottom: 0;
                box-shadow: 0 6px 0 0 @accent_color;
            }
        """);
        GtkCompat.add_provider_for_display(
            display,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
        drop_css_installed = true;
    }

    private void clear_drop_hint(Gtk.Widget row_widget) {
        row_widget.remove_css_class(DROP_BEFORE_CLASS);
        row_widget.remove_css_class(DROP_INTO_CLASS);
        row_widget.remove_css_class(DROP_AFTER_CLASS);
    }

    private void update_drop_hint(Gtk.Widget row_widget, double y) {
        ensure_drop_css();
        clear_drop_hint(row_widget);
        var height = row_widget.get_height();
        double y_fraction = 0.5;
        if (height > 0) {
            y_fraction = y / (double) height;
        }
        if (y_fraction < 0.30) {
            row_widget.add_css_class(DROP_BEFORE_CLASS);
            return;
        }
        if (y_fraction > 0.70) {
            row_widget.add_css_class(DROP_AFTER_CLASS);
            return;
        }
        row_widget.add_css_class(DROP_INTO_CLASS);
    }

    private void clear_box_children(Gtk.Box box) {
        Gtk.Widget? child = box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            box.remove(child);
            child = next;
        }
    }
}

}
