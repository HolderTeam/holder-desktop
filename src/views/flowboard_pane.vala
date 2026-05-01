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

    private Gtk.Label empty_label;
    private Gtk.Stack state_stack;
    private Gtk.MultiSelection selection;
    private Gtk.GridView grid_view;
    private Gtk.Popover? background_menu_popover;
    private GLib.ListModel? model;

    public Gtk.Widget widget { get; private set; }

    public signal void tile_activated(uint position);
    public signal void navigate_up_requested();
    public signal void card_drop_requested(string source_card_id, string target_card_id, double target_x_fraction);
    public signal void background_drop_requested(string source_card_id);
    public signal void background_new_card_requested();
    public signal void card_open_requested(string card_id);
    public signal void card_create_child_requested(string card_id);
    public signal void card_move_to_trash_requested(string card_id);
    public signal void card_move_up_level_requested(string card_id);
    public signal void card_move_left_requested(string card_id);
    public signal void card_move_right_requested(string card_id);
    public signal void card_move_to_start_requested(string card_id);
    public signal void card_move_to_end_requested(string card_id);

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

    public void set_empty_message(string text) {
        empty_label.set_text(text);
    }

    private Gtk.Widget build_ui() {
        var outer = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);

        var factory = new Gtk.SignalListItemFactory();
        factory.setup.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var card = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            card.add_css_class("card");
            card.add_css_class("flowboard-tile");
            card.set_margin_top(6);
            card.set_margin_bottom(6);
            card.set_margin_start(6);
            card.set_margin_end(6);

            var folder_tab = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            folder_tab.add_css_class("flowboard-folder-tab");
            folder_tab.set_halign(Gtk.Align.FILL);
            folder_tab.set_hexpand(true);
            folder_tab.set_size_request(-1, 12);
            card.set_data<Gtk.Widget>("flowboard-folder-tab", folder_tab);
            card.append(folder_tab);

            var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            card.set_data<Gtk.Widget>("flowboard-header-box", header);
            header.set_margin_start(8);
            header.set_margin_end(8);

            var title = new Gtk.Label("") { xalign = 0.0f };
            title.add_css_class("title-5");
            title.set_wrap(true);
            title.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
            title.set_lines(2);
            title.set_ellipsize(Pango.EllipsizeMode.END);

            title.set_hexpand(true);
            header.append(title);

            var meta = new Gtk.Label("") { xalign = 0.0f };
            meta.add_css_class("dim-label");
            meta.set_margin_start(8);
            meta.set_margin_end(8);
            meta.set_margin_bottom(10);
            meta.set_xalign(1.0f);
            meta.set_halign(Gtk.Align.END);

            var spacer = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            spacer.set_vexpand(true);
            card.set_data<Gtk.Label>("flowboard-title-label", title);
            card.set_data<Gtk.Label>("flowboard-meta-label", meta);
            card.append(header);
            card.append(spacer);
            card.append(meta);
            install_drag_and_drop(card);
            list_item.set_child(card);
        });
        factory.bind.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var tile = list_item.get_item() as FlowboardTile;
            var card = list_item.get_child() as Gtk.Box;
            var folder_tab = card.get_data<Gtk.Widget>("flowboard-folder-tab");
            var header = card.get_data<Gtk.Widget>("flowboard-header-box");
            var title = card.get_data<Gtk.Label>("flowboard-title-label");
            var meta = card.get_data<Gtk.Label>("flowboard-meta-label");
            if (folder_tab == null || header == null || title == null || meta == null) {
                return;
            }
            var presentation = FlowboardPresenter.tile(tile, new DateTime.now_utc().to_unix());
            title.set_text(presentation.title);
            meta.set_text(presentation.meta_text);
            folder_tab.set_visible(presentation.folder_tab_visible);
            header.set_margin_top(presentation.header_margin_top);
            if (presentation.branch_css) {
                card.add_css_class("flowboard-branch");
            } else {
                card.remove_css_class("flowboard-branch");
            }
            card.set_data<string>("flowboard-card-id", presentation.card_id);
            card.set_data<string>("flowboard-parent-card-id", presentation.parent_card_id);
            card.set_data<int>("flowboard-sibling-count", presentation.sibling_count);
            card.set_data<int>("flowboard-sibling-index", presentation.sibling_index);
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
            } else if (keyval == Gdk.Key.Delete || keyval == Gdk.Key.KP_Delete) {
                var selected_set = selection.get_selection();
                if (selected_set.get_size() > 0) {
                    var selected_tile = visible_tiles_item(selected_set.get_minimum());
                    if (selected_tile != null && selected_tile.card_id != null) {
                        card_move_to_trash_requested(selected_tile.card_id);
                        return true;
                    }
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

        var context_click = new Gtk.GestureClick();
        context_click.set_button(Gdk.BUTTON_SECONDARY);
        context_click.pressed.connect((n_press, x, y) => {
            if (n_press != 1) {
                return;
            }
            var picked = grid_view.pick(x, y, Gtk.PickFlags.DEFAULT);
            var background_press = (picked == null || picked == grid_view);
            if (!background_press) {
                return;
            }
            show_background_menu_at(x, y);
        });
        grid_view.add_controller(context_click);

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
            update_drop_hint(row_widget, x);
            return Gdk.DragAction.MOVE;
        });
        drop_target.motion.connect((x, y) => {
            update_drop_hint(row_widget, x);
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
            var x_fraction = FlowboardPresenter.drop_fraction(x, row_widget.get_width());
            clear_drop_hint(row_widget);
            grid_view.remove_css_class(DRAG_ACTIVE_CLASS);
            card_drop_requested(source_card_id, target_card_id, x_fraction);
            return true;
        });
        row_widget.add_controller(drop_target);

        var context_click = new Gtk.GestureClick();
        context_click.set_button(Gdk.BUTTON_SECONDARY);
        context_click.pressed.connect((n_press, x, y) => {
            if (n_press != 1) {
                return;
            }
            var card_id = row_widget.get_data<string>("flowboard-card-id");
            if (card_id == null || card_id.strip().length == 0) {
                return;
            }
            show_card_menu_at(row_widget, card_id, x, y);
        });
        row_widget.add_controller(context_click);
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
            .flowboard-tile {
                border-radius: 8px;
                border: 1px solid alpha(@borders, 0.65);
                background-color: alpha(@card_bg_color, 0.35);
                min-height: 76px;
            }
            .flowboard-branch {
                margin-top: 0;
                border: 1px solid alpha(@borders, 0.65);
                background-color: alpha(@card_bg_color, 0.35);
            }
            .flowboard-folder-tab {
                background-color: alpha(@card_bg_color, 0.50);
                border-top-left-radius: 8px;
                border-top-right-radius: 8px;
                margin-top: 0;
                margin-left: 0;
                margin-right: 0;
                margin-bottom: 3px;
                border-bottom: 1px solid alpha(@borders, 0.65);
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
                box-shadow: -6px 0 0 0 @accent_color;
            }
            .flowboard-drop-into {
                outline: 3px solid @accent_color;
                outline-offset: -3px;
                background-color: alpha(@accent_color, 0.16);
            }
            .flowboard-drop-after {
                box-shadow: 6px 0 0 0 @accent_color;
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

    private void update_drop_hint(Gtk.Widget row_widget, double x) {
        ensure_drop_css();
        clear_drop_hint(row_widget);
        switch (FlowboardPresenter.drop_hint(x, row_widget.get_width())) {
        case FlowboardDropHint.BEFORE:
            row_widget.add_css_class(DROP_BEFORE_CLASS);
            return;
        case FlowboardDropHint.AFTER:
            row_widget.add_css_class(DROP_AFTER_CLASS);
            return;
        case FlowboardDropHint.INTO:
            row_widget.add_css_class(DROP_INTO_CLASS);
            return;
        }
    }

    private void show_background_menu_at(double x, double y) {
        if (background_menu_popover == null) {
            var popover = new Gtk.Popover();
            popover.set_autohide(true);
            var menu_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            var new_card_button = new Gtk.Button.with_label("New Card");
            new_card_button.add_css_class("flat");
            new_card_button.clicked.connect(() => {
                popover.popdown();
                background_new_card_requested();
            });
            menu_box.append(new_card_button);
            popover.set_child(menu_box);
            popover.set_parent(grid_view);
            background_menu_popover = popover;
        }
        var rect = Gdk.Rectangle();
        rect.x = (int) x;
        rect.y = (int) y;
        rect.width = 1;
        rect.height = 1;
        background_menu_popover.set_pointing_to(rect);
        background_menu_popover.popup();
    }

    private void show_card_menu_at(Gtk.Widget row_widget, string card_id, double x, double y) {
        var popover = new Gtk.Popover();
        popover.set_autohide(true);
        popover.set_parent(row_widget);

        var menu_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

        var open_btn = new Gtk.Button.with_label("Open");
        open_btn.add_css_class("flat");
        open_btn.clicked.connect(() => {
            popover.popdown();
            card_open_requested(card_id);
        });
        menu_box.append(open_btn);

        var create_child_btn = new Gtk.Button.with_label("Create Child Card");
        create_child_btn.add_css_class("flat");
        create_child_btn.clicked.connect(() => {
            popover.popdown();
            card_create_child_requested(card_id);
        });
        menu_box.append(create_child_btn);

        var move_up_btn = new Gtk.Button.with_label("Move Up a Level");
        move_up_btn.add_css_class("flat");
        var parent_card_id = row_widget.get_data<string>("flowboard-parent-card-id");
        move_up_btn.set_sensitive(FlowboardPresenter.move_up_sensitive(parent_card_id));
        move_up_btn.clicked.connect(() => {
            popover.popdown();
            card_move_up_level_requested(card_id);
        });
        menu_box.append(move_up_btn);

        var move_to_trash_btn = new Gtk.Button.with_label("Move to Trash");
        move_to_trash_btn.add_css_class("flat");
        move_to_trash_btn.clicked.connect(() => {
            popover.popdown();
            card_move_to_trash_requested(card_id);
        });
        menu_box.append(move_to_trash_btn);

        var sibling_count = row_widget.get_data<int>("flowboard-sibling-count");
        var sibling_index = row_widget.get_data<int>("flowboard-sibling-index");

        var move_left_btn = new Gtk.Button.with_label("Move Left");
        move_left_btn.add_css_class("flat");
        move_left_btn.set_sensitive(FlowboardPresenter.move_left_sensitive(sibling_count, sibling_index));
        move_left_btn.clicked.connect(() => {
            popover.popdown();
            card_move_left_requested(card_id);
        });
        menu_box.append(move_left_btn);

        var move_right_btn = new Gtk.Button.with_label("Move Right");
        move_right_btn.add_css_class("flat");
        move_right_btn.set_sensitive(FlowboardPresenter.move_right_sensitive(sibling_count, sibling_index));
        move_right_btn.clicked.connect(() => {
            popover.popdown();
            card_move_right_requested(card_id);
        });
        menu_box.append(move_right_btn);

        var move_start_btn = new Gtk.Button.with_label("Move to Start");
        move_start_btn.add_css_class("flat");
        move_start_btn.set_sensitive(FlowboardPresenter.move_to_boundary_sensitive(sibling_count));
        move_start_btn.clicked.connect(() => {
            popover.popdown();
            card_move_to_start_requested(card_id);
        });
        menu_box.append(move_start_btn);

        var move_end_btn = new Gtk.Button.with_label("Move to End");
        move_end_btn.add_css_class("flat");
        move_end_btn.set_sensitive(FlowboardPresenter.move_to_boundary_sensitive(sibling_count));
        move_end_btn.clicked.connect(() => {
            popover.popdown();
            card_move_to_end_requested(card_id);
        });
        menu_box.append(move_end_btn);

        popover.set_child(menu_box);

        var rect = Gdk.Rectangle();
        rect.x = (int) x;
        rect.y = (int) y;
        rect.width = 1;
        rect.height = 1;
        popover.set_pointing_to(rect);
        popover.popup();
    }

    private FlowboardTile? visible_tiles_item(uint position) {
        if (model == null || position >= model.get_n_items()) {
            return null;
        }
        return model.get_item(position) as FlowboardTile;
    }
}

}
