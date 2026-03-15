namespace HolderLinux {

public class TrashToolView : Object, IToolShellAdapter {
    private TrashController controller;
    private Gtk.Box trash_actions_bar;
    private Gtk.DropDown filter_dropdown;
    private string scope_text_cache = "Projects / (none) / Trash";
    private Gtk.Label empty_label;
    private Gtk.Button empty_trash_btn;

    public Gtk.Widget widget { get; private set; }
    public string tool_id {
        owned get { return "trash"; }
    }
    public string tool_label {
        owned get { return "Trash"; }
    }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void breadcrumb_activated(int index);

    public TrashToolView() {
        controller = new TrashController();
        controller.state_changed.connect(() => {
            apply_state();
        });
        controller.error_reported.connect((title, details) => {
            error_reported(title, details);
        });
        controller.toast_requested.connect((message) => {
            toast_requested(message);
        });
        widget = build_ui();
    }

    public Gtk.Widget? get_actions_widget() {
        return trash_actions_bar;
    }

    public Gtk.Widget get_content_widget() {
        return widget;
    }

    public void set_api_client(IHolderApi? api) {
        controller.set_api_client(api);
    }

    public void set_project_selection(Gtk.SingleSelection? project_selection) {
        controller.set_project_selection(project_selection);
    }

    public void refresh() {
        controller.queue_refresh();
    }

    public ToolScopeSnapshot get_scope_snapshot(Project? selected_project, CardSummary? selected_card) {
        var project_id = selected_project != null ? selected_project.project_id : null;
        var project_label = selected_project != null ? selected_project.name : "(none)";
        var card_id = selected_card != null ? selected_card.card_id : null;
        var card_label = selected_card != null ? selected_card.title : "Overview";

        ToolScopeMode scope_mode = selected_card != null
            ? ToolScopeMode.CARD_FOCUS
            : ToolScopeMode.PROJECT_ROOT;
        if (project_id == null) {
            scope_mode = ToolScopeMode.PROJECTS_ROOT;
            project_label = "Projects";
            card_id = null;
            card_label = "Overview";
        }

        return new ToolScopeSnapshot(
            tool_id,
            tool_label,
            project_id,
            project_label,
            card_id,
            card_label,
            scope_mode,
            false
        );
    }

    public async bool navigate_to_projects_root(string? selected_project_id) {
        refresh();
        return true;
    }

    public async bool navigate_to_project_root(string project_id) {
        refresh();
        return true;
    }

    public async bool navigate_to_card(string card_id) {
        refresh();
        return true;
    }

    private Gtk.Widget build_ui() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

        trash_actions_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        trash_actions_bar.set_hexpand(true);
        var filter_options = new Gtk.StringList(null);
        filter_options.append("All");
        filter_options.append("Cards");
        filter_options.append("AI messages");
        filter_dropdown = new Gtk.DropDown(filter_options, null);
        filter_dropdown.set_selected(0);
        filter_dropdown.notify["selected"].connect(() => {
            controller.set_filter_index(filter_dropdown.get_selected());
        });
        trash_actions_bar.append(filter_dropdown);

        var refresh_btn = new Gtk.Button.from_icon_name("view-refresh-symbolic");
        refresh_btn.set_tooltip_text("Refresh trash");
        refresh_btn.clicked.connect(() => {
            controller.queue_refresh();
        });
        trash_actions_bar.append(refresh_btn);

        empty_trash_btn = new Gtk.Button.with_label("Empty Trash");
        empty_trash_btn.add_css_class("destructive-action");
        empty_trash_btn.clicked.connect(() => {
            confirm_empty_trash();
        });
        trash_actions_bar.append(empty_trash_btn);

        var selection = new Gtk.NoSelection(controller.items_store);
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
                    label.set_text(controller.pretty_type(trash_item.item_type));
                    break;
                case "title":
                    label.set_text(trash_item.title);
                    label.set_tooltip_text(trash_item.title);
                    break;
                case "deleted":
                    var ts = controller.format_epoch(trash_item.deleted_at);
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
                    controller.restore_item.begin(current);
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

    private void apply_state() {
        scope_text_cache = controller.scope_text;
        empty_label.set_text(controller.empty_text);
        empty_label.set_visible(controller.empty_visible);
        empty_trash_btn.set_sensitive(controller.empty_trash_sensitive);
    }

#if TRASH_TOOL_VIEW_TEST
    internal void set_filter_index_for_tests(uint idx) {
        filter_dropdown.set_selected(idx);
    }
#endif

    private void confirm_hard_delete(TrashItem item) {
        var root_window = widget.get_root() as Gtk.Window;
        if (root_window == null) {
            return;
        }
        var spec = controller.hard_delete_confirmation(item);

        var dialog = new Adw.MessageDialog(
            root_window,
            spec.title,
            spec.body
        );
        dialog.add_response(spec.cancel_response_id, spec.cancel_label);
        dialog.add_response(spec.confirm_response_id, spec.confirm_label);
        dialog.set_response_appearance(spec.confirm_response_id, Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.response.connect((response) => {
            if (response == spec.confirm_response_id) {
                controller.hard_delete_item.begin(item);
            }
            dialog.close();
        });
        dialog.present();
    }

#if TRASH_TOOL_VIEW_TEST
    internal async void restore_item_for_tests(TrashItem item) {
        yield controller.restore_item(item);
    }

    internal async void hard_delete_item_for_tests(TrashItem item) {
        yield controller.hard_delete_item(item);
    }
#endif

    private void confirm_empty_trash() {
        var project = controller.selected_project();
        if (project == null) {
            return;
        }

        var root_window = widget.get_root() as Gtk.Window;
        if (root_window == null) {
            return;
        }
        var spec = controller.empty_trash_confirmation(project);

        var dialog = new Adw.MessageDialog(
            root_window,
            spec.title,
            spec.body
        );
        dialog.add_response(spec.cancel_response_id, spec.cancel_label);
        dialog.add_response(spec.confirm_response_id, spec.confirm_label);
        dialog.set_response_appearance(spec.confirm_response_id, Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.response.connect((response) => {
            if (response == spec.confirm_response_id) {
                controller.empty_trash.begin(project.project_id);
            }
            dialog.close();
        });
        dialog.present();
    }

#if TRASH_TOOL_VIEW_TEST
    internal async void empty_trash_for_tests(string project_id) {
        yield controller.empty_trash(project_id);
    }

    internal uint item_count_for_tests() {
        return controller.items_store.get_n_items();
    }

    internal string scope_text_for_tests() {
        return scope_text_cache;
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
