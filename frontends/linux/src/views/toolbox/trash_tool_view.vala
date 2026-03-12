namespace HolderLinux {

public class TrashToolView : Object {
    private IHolderApi? api;
    private Gtk.SingleSelection? project_selection;
    private GLib.ListStore items_store;
    private Gtk.Label scope_label;
    private Gtk.Label empty_label;
    private Gtk.DropDown filter_dropdown;
    private Gtk.Button empty_trash_btn;
    private uint refresh_serial = 0;

    public Gtk.Widget widget { get; private set; }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);

    public TrashToolView() {
        widget = build_ui();
    }

    public void set_api_client(IHolderApi? api) {
        this.api = api;
        queue_refresh();
    }

    public void set_project_selection(Gtk.SingleSelection? project_selection) {
        this.project_selection = project_selection;
        if (this.project_selection != null) {
            this.project_selection.notify["selected"].connect(() => {
                queue_refresh();
            });
        }
        queue_refresh();
    }

    private Gtk.Widget build_ui() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

        var header = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        scope_label = new Gtk.Label("Projects / (none) / Trash") { xalign = 0.0f };
        scope_label.add_css_class("dim-label");
        header.append(scope_label);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var filter_options = new Gtk.StringList(null);
        filter_options.append("All");
        filter_options.append("Cards");
        filter_options.append("AI messages");
        filter_dropdown = new Gtk.DropDown(filter_options, null);
        filter_dropdown.set_selected(0);
        filter_dropdown.notify["selected"].connect(() => {
            queue_refresh();
        });
        actions.append(filter_dropdown);

        var refresh_btn = new Gtk.Button.from_icon_name("view-refresh-symbolic");
        refresh_btn.set_tooltip_text("Refresh trash");
        refresh_btn.clicked.connect(() => {
            queue_refresh();
        });
        actions.append(refresh_btn);

        empty_trash_btn = new Gtk.Button.with_label("Empty Trash");
        empty_trash_btn.add_css_class("destructive-action");
        empty_trash_btn.clicked.connect(() => {
            confirm_empty_trash();
        });
        actions.append(empty_trash_btn);

        header.append(actions);
        root.append(header);

        items_store = new GLib.ListStore(typeof(TrashItem));
        var selection = new Gtk.NoSelection(items_store);
        var view = new Gtk.ColumnView(selection);
        view.set_vexpand(true);
        view.append_column(build_text_column("Type", "type"));
        view.append_column(build_text_column("Title", "title"));
        view.append_column(build_text_column("Deleted", "deleted"));
        view.append_column(build_actions_column());

        var scroller = new Gtk.ScrolledWindow();
        scroller.set_vexpand(true);
        scroller.set_child(view);
        root.append(scroller);

        empty_label = new Gtk.Label("No deleted items in this project.") { xalign = 0.0f };
        empty_label.add_css_class("dim-label");
        empty_label.set_visible(false);
        root.append(empty_label);

        return root;
    }

    private Gtk.ColumnViewColumn build_text_column(string title, string field) {
        var factory = new Gtk.SignalListItemFactory();
        factory.setup.connect((item_obj) => {
            var item = item_obj as Gtk.ListItem;
            if (item == null) {
                return;
            }
            var label = new Gtk.Label("") { xalign = 0.0f };
            label.set_ellipsize(Pango.EllipsizeMode.END);
            item.set_child(label);
        });
        factory.bind.connect((item_obj) => {
            var item = item_obj as Gtk.ListItem;
            if (item == null) {
                return;
            }
            var trash_item = item.get_item() as TrashItem;
            var label = item.get_child() as Gtk.Label;
            if (trash_item == null || label == null) {
                return;
            }
            switch (field) {
                case "type":
                    label.set_text(pretty_type(trash_item.item_type));
                    break;
                case "title":
                    label.set_text(trash_item.title);
                    label.set_tooltip_text(trash_item.title);
                    break;
                case "deleted":
                    var ts = format_epoch(trash_item.deleted_at);
                    label.set_text(ts);
                    label.set_tooltip_text(trash_item.deleted_at.to_string());
                    break;
                default:
                    label.set_text("");
                    break;
            }
        });

        return new Gtk.ColumnViewColumn(title, factory);
    }

    private Gtk.ColumnViewColumn build_actions_column() {
        var factory = new Gtk.SignalListItemFactory();
        factory.setup.connect((item_obj) => {
            var item = item_obj as Gtk.ListItem;
            if (item == null) {
                return;
            }

            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);

            var restore_btn = new Gtk.Button.with_label("Restore");
            restore_btn.clicked.connect(() => {
                var current = item.get_item() as TrashItem;
                if (current != null) {
                    restore_item.begin(current);
                }
            });
            box.append(restore_btn);

            var delete_btn = new Gtk.Button.with_label("Delete");
            delete_btn.add_css_class("destructive-action");
            delete_btn.clicked.connect(() => {
                var current = item.get_item() as TrashItem;
                if (current != null) {
                    confirm_hard_delete(current);
                }
            });
            box.append(delete_btn);

            item.set_child(box);
        });

        return new Gtk.ColumnViewColumn("Actions", factory);
    }

    private string selected_filter_type() {
        var idx = filter_dropdown != null ? filter_dropdown.get_selected() : 0;
        switch (idx) {
            case 1:
                return "card";
            case 2:
                return "ai_message";
            default:
                return "all";
        }
    }

#if TRASH_TOOL_VIEW_TEST
    internal void set_filter_index_for_tests(uint idx) {
        filter_dropdown.set_selected(idx);
    }
#endif

    private void queue_refresh() {
        refresh_serial++;
        refresh.begin(refresh_serial);
    }

    private async void refresh(uint serial) {
        clear_store();

        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;

        if (project == null) {
            scope_label.set_text("Projects / (none) / Trash");
            empty_label.set_text("Select a project to view trash.");
            empty_label.set_visible(true);
            empty_trash_btn.set_sensitive(false);
            return;
        }

        scope_label.set_text("Projects / %s / Trash".printf(project.name));

        if (api == null) {
            empty_label.set_text("API unavailable.");
            empty_label.set_visible(true);
            empty_trash_btn.set_sensitive(false);
            return;
        }

        try {
            var items = yield api.list_trash_items(project.project_id, selected_filter_type());
            if (serial != refresh_serial) {
                return;
            }
            foreach (var item in items) {
                items_store.append(item);
            }
            empty_label.set_visible(items_store.get_n_items() == 0);
            if (items_store.get_n_items() == 0) {
                empty_label.set_text("No deleted items in this project.");
            }
            empty_trash_btn.set_sensitive(items_store.get_n_items() > 0);
        } catch (Error e) {
            if (serial != refresh_serial) {
                return;
            }
            empty_label.set_text("Failed to load trash.");
            empty_label.set_visible(true);
            empty_trash_btn.set_sensitive(false);
            error_reported("Trash refresh failed", e.message);
        }
    }

    private void clear_store() {
        while (items_store.get_n_items() > 0) {
            items_store.remove(items_store.get_n_items() - 1);
        }
    }

    private async void restore_item(TrashItem item) {
        if (api == null) {
            return;
        }
        try {
            yield api.restore_trash_item(item.item_type, item.item_id);
            toast_requested("Item restored.");
            queue_refresh();
        } catch (Error e) {
            error_reported("Failed to restore item", e.message);
        }
    }

#if TRASH_TOOL_VIEW_TEST
    internal async void restore_item_for_tests(TrashItem item) {
        yield restore_item(item);
    }
#endif

    private void confirm_hard_delete(TrashItem item) {
        var root_window = widget.get_root() as Gtk.Window;
        if (root_window == null) {
            return;
        }

        var dialog = new Adw.MessageDialog(
            root_window,
            "Delete Permanently",
            "Permanently delete \"%s\"?".printf(item.title)
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("delete", "Delete");
        dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.response.connect((response) => {
            if (response == "delete") {
                hard_delete_item.begin(item);
            }
            dialog.close();
        });
        dialog.present();
    }

    private async void hard_delete_item(TrashItem item) {
        if (api == null) {
            return;
        }
        try {
            yield api.hard_delete_trash_item(item.item_type, item.item_id);
            toast_requested("Item permanently deleted.");
            queue_refresh();
        } catch (Error e) {
            error_reported("Failed to permanently delete item", e.message);
        }
    }

#if TRASH_TOOL_VIEW_TEST
    internal async void hard_delete_item_for_tests(TrashItem item) {
        yield hard_delete_item(item);
    }
#endif

    private void confirm_empty_trash() {
        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        if (project == null) {
            return;
        }

        var root_window = widget.get_root() as Gtk.Window;
        if (root_window == null) {
            return;
        }

        var dialog = new Adw.MessageDialog(
            root_window,
            "Empty Trash",
            "Permanently delete all trash items in %s?".printf(project.name)
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("empty", "Empty Trash");
        dialog.set_response_appearance("empty", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.response.connect((response) => {
            if (response == "empty") {
                empty_trash.begin(project.project_id);
            }
            dialog.close();
        });
        dialog.present();
    }

    private async void empty_trash(string project_id) {
        if (api == null) {
            return;
        }
        try {
            yield api.empty_trash(project_id, "all");
            toast_requested("Trash emptied.");
            queue_refresh();
        } catch (Error e) {
            error_reported("Failed to empty trash", e.message);
        }
    }

#if TRASH_TOOL_VIEW_TEST
    internal async void empty_trash_for_tests(string project_id) {
        yield empty_trash(project_id);
    }
#endif

    private string pretty_type(string item_type) {
        switch (item_type) {
            case "card":
                return "Card";
            case "ai_message":
                return "AI message";
            default:
                return item_type;
        }
    }

    private string format_epoch(int64 epoch_seconds) {
        if (epoch_seconds <= 0) {
            return "";
        }
        var dt = new DateTime.from_unix_local(epoch_seconds);
        return dt.format("%Y-%m-%d %H:%M");
    }

#if TRASH_TOOL_VIEW_TEST
    internal uint item_count_for_tests() {
        return items_store.get_n_items();
    }

    internal string scope_text_for_tests() {
        return scope_label.get_text();
    }

    internal string empty_text_for_tests() {
        return empty_label.get_text();
    }

    internal bool empty_visible_for_tests() {
        return empty_label.get_visible();
    }

    internal bool empty_trash_sensitive_for_tests() {
        return empty_trash_btn.get_sensitive();
    }
#endif
}

}
