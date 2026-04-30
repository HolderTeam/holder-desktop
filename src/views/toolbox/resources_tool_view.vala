namespace HolderLinux {

public class ResourcesToolView : Object, IToolShellAdapter {
    private ResourcesController controller;
    private IHolderApi? api;
    private Gtk.SingleSelection? project_selection;
    private Gtk.Box resources_actions_bar;
    private GLib.ListStore resources_store;
    private Gtk.SingleSelection resources_selection;
    private Gtk.SearchEntry resources_search_entry;
    private Gtk.Label resources_empty_label;
    private Gtk.Button resources_open_btn;
    private Gtk.Button resources_edit_btn;
    private Gtk.Button resources_delete_btn;
    private Gee.ArrayList<ProjectResource> all_resources = new Gee.ArrayList<ProjectResource>();
    private uint resources_refresh_serial = 0;
    private bool has_committed_resources = false;

    public Gtk.Widget widget { get; private set; }
    public string tool_id {
        owned get { return "resources"; }
    }
    public string tool_label {
        owned get { return "Resources"; }
    }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void activity_requested(string kind,
                                          string message,
                                          string? project_id,
                                          string? resource_id,
                                          ActivityDetails? details);

    public ResourcesToolView() {
        controller = new ResourcesController();
        controller.activity_requested.connect((kind, message, project_id, resource_id, details) => {
            activity_requested(kind, message, project_id, resource_id, details);
        });
        widget = build_resources_tab();
    }

    public Gtk.Widget? get_actions_widget() {
        return resources_actions_bar;
    }

    public Gtk.Widget get_content_widget() {
        return widget;
    }

    public void set_api_client(IHolderApi? api) {
        this.api = api;
        queue_resources_refresh();
    }

    public void set_project_selection(Gtk.SingleSelection? project_selection) {
        this.project_selection = project_selection;
        if (this.project_selection != null) {
            this.project_selection.notify["selected"].connect(() => {
                queue_resources_refresh();
            });
        }
        queue_resources_refresh();
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
        queue_resources_refresh();
        return true;
    }

    public async bool navigate_to_project_root(string project_id) {
        queue_resources_refresh();
        return true;
    }

    public async bool navigate_to_card(string card_id) {
        queue_resources_refresh();
        return true;
    }

    private Gtk.Widget build_resources_tab() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

        resources_actions_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        resources_actions_bar.set_hexpand(true);
        resources_search_entry = new Gtk.SearchEntry();
        resources_search_entry.set_placeholder_text("Filter resources...");
        resources_search_entry.set_hexpand(true);
        resources_search_entry.search_changed.connect(() => {
            apply_resources_filter();
        });
        resources_actions_bar.append(resources_search_entry);

        var add_btn = new Gtk.Button.from_icon_name("list-add-symbolic");
        add_btn.set_tooltip_text("Add resource");
        add_btn.clicked.connect(() => {
            open_resource_dialog(null);
        });
        resources_actions_bar.append(add_btn);

        var refresh_btn = new Gtk.Button.from_icon_name("view-refresh-symbolic");
        refresh_btn.set_tooltip_text("Refresh resources");
        refresh_btn.clicked.connect(() => {
            queue_resources_refresh();
        });
        resources_actions_bar.append(refresh_btn);

        resources_store = new GLib.ListStore(typeof(ProjectResource));
        resources_selection = new Gtk.SingleSelection(resources_store);
        resources_selection.set_autoselect(false);
        resources_selection.notify["selected-item"].connect(() => {
            refresh_resource_action_state();
        });

        var view = new Gtk.ColumnView(resources_selection);
        view.set_vexpand(true);
        view.append_column(build_resource_text_column("Label", "label"));
        view.append_column(build_resource_text_column("Kind", "kind"));
        view.append_column(build_resource_text_column("URI", "uri"));
        view.append_column(build_resource_text_column("Desc", "desc"));
        view.append_column(build_resource_text_column("Updated", "updated"));

        var scroller = new Gtk.ScrolledWindow();
        scroller.set_vexpand(true);
        scroller.set_child(view);
        root.append(scroller);

        resources_empty_label = new Gtk.Label("No resources in this project.") { xalign = 0.0f };
        resources_empty_label.add_css_class("dim-label");
        resources_empty_label.set_visible(false);
        root.append(resources_empty_label);

        resources_open_btn = new Gtk.Button.with_label("Open");
        resources_open_btn.clicked.connect(() => {
            open_selected_resource();
        });
        resources_actions_bar.append(resources_open_btn);

        resources_edit_btn = new Gtk.Button.with_label("Edit");
        resources_edit_btn.clicked.connect(() => {
            var selected = selected_resource();
            if (selected != null) {
                open_resource_dialog(selected);
            }
        });
        resources_actions_bar.append(resources_edit_btn);

        resources_delete_btn = new Gtk.Button.with_label("Delete");
        resources_delete_btn.add_css_class("destructive-action");
        resources_delete_btn.clicked.connect(() => {
            confirm_delete_selected_resource();
        });
        resources_actions_bar.append(resources_delete_btn);

        refresh_resource_action_state();
        return root;
    }

    private Gtk.ColumnViewColumn build_resource_text_column(string title, string field) {
        var factory = new Gtk.SignalListItemFactory();
        factory.setup.connect((item_obj) => {
            var item = item_obj as Gtk.ListItem;
            if (item == null) {
                return;
            }
            var label = new Gtk.Label("") { xalign = 0.0f };
            label.set_wrap(false);
            label.set_ellipsize(Pango.EllipsizeMode.END);
            item.set_child(label);
        });
        factory.bind.connect((item_obj) => {
            var item = item_obj as Gtk.ListItem;
            if (item == null) {
                return;
            }
            var resource = item.get_item() as ProjectResource;
            var label = item.get_child() as Gtk.Label;
            if (resource == null || label == null) {
                return;
            }
            switch (field) {
                case "label":
                    label.set_text(controller.ellipsize_title(resource.label));
                    label.set_tooltip_text(resource.label);
                    break;
                case "kind":
                    label.set_text(resource.kind);
                    label.set_tooltip_text(resource.kind);
                    break;
                case "uri":
                    label.set_text(controller.ellipsize_title(resource.uri));
                    label.set_tooltip_text(resource.uri);
                    break;
                case "desc":
                    var desc = resource.desc ?? "";
                    label.set_text(controller.ellipsize_title(desc));
                    label.set_tooltip_text(desc);
                    break;
                case "updated":
                    label.set_text(controller.format_epoch(resource.updated_at));
                    label.set_tooltip_text(resource.updated_at.to_string());
                    break;
                default:
                    label.set_text("");
                    break;
            }
        });

        return new Gtk.ColumnViewColumn(title, factory);
    }

    private void queue_resources_refresh() {
        resources_refresh_serial++;
        refresh_resources.begin(resources_refresh_serial);
    }

    private async void refresh_resources(uint request_serial) {
        if (request_serial != resources_refresh_serial) {
            return;
        }
        if (resources_store == null) {
            return;
        }

        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var result = yield controller.refresh_resources_flow(api, project);
        if (request_serial != resources_refresh_serial) {
            return;
        }
        if (result.success) {
            all_resources = result.resources;
            apply_resources_filter();
            has_committed_resources = true;
            return;
        }

        if (result.has_error && has_committed_resources) {
            error_reported(result.error_title, result.error_details);
            return;
        }

        clear_visible_resources();
        all_resources.clear();
        has_committed_resources = false;
        resources_empty_label.set_text(result.empty_text);
        resources_empty_label.set_visible(true);
        if (result.has_error) {
            error_reported(result.error_title, result.error_details);
        }
        refresh_resource_action_state();
    }

    private void apply_resources_filter() {
        if (resources_store == null) {
            return;
        }
        clear_visible_resources();

        var query = resources_search_entry != null ? resources_search_entry.get_text() : "";
        var result = controller.apply_resources_filter_flow(all_resources, query);
        foreach (var resource in result.filtered) {
            resources_store.append(resource);
        }

        resources_empty_label.set_visible(result.empty);
        if (result.empty) {
            resources_empty_label.set_text(result.empty_text);
        }
        refresh_resource_action_state();
    }

    private void clear_visible_resources() {
        while (resources_store.get_n_items() > 0) {
            resources_store.remove(resources_store.get_n_items() - 1);
        }
    }

    private ProjectResource? selected_resource() {
        return resources_selection != null
            ? resources_selection.get_selected_item() as ProjectResource
            : null;
    }

    private void refresh_resource_action_state() {
        var selected = selected_resource();
        if (resources_open_btn != null) {
            resources_open_btn.set_sensitive(selected != null);
        }
        if (resources_edit_btn != null) {
            resources_edit_btn.set_sensitive(selected != null);
        }
        if (resources_delete_btn != null) {
            resources_delete_btn.set_sensitive(selected != null);
        }
    }

    private void open_resource_dialog(ProjectResource? existing) {
        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        if (project == null) {
            toast_requested("Select a project first.");
            return;
        }

        var root_window = widget.get_root() as Gtk.Window;
        if (root_window == null) {
            return;
        }

        var is_edit = existing != null;
        var dialog = new Adw.MessageDialog(
            root_window,
            is_edit ? "Edit Resource" : "Add Resource",
            is_edit ? "Update resource pointer fields." : "Create a project resource pointer."
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("save", "Save");
        dialog.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("save");
        dialog.set_close_response("cancel");

        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var kind_label = new Gtk.Label("Kind") { xalign = 0.0f };
        var kind_options = new Gtk.StringList(null);
        foreach (var kind in controller.default_resource_kinds()) {
            kind_options.append(kind);
        }
        kind_options.append("custom");
        var kind_dropdown = new Gtk.DropDown(kind_options, null);
        var custom_kind_entry = new Gtk.Entry();
        custom_kind_entry.set_placeholder_text("custom kind");
        custom_kind_entry.set_visible(false);
        kind_dropdown.notify["selected"].connect(() => {
            var idx = kind_dropdown.get_selected();
            custom_kind_entry.set_visible(idx == kind_options.get_n_items() - 1);
            if (!custom_kind_entry.get_visible()) {
                custom_kind_entry.set_text("");
            }
        });
        content.append(kind_label);
        content.append(kind_dropdown);
        content.append(custom_kind_entry);

        var uri_label = new Gtk.Label("URI") { xalign = 0.0f };
        var uri_entry = new Gtk.Entry();
        uri_entry.set_placeholder_text("https://..., file:///..., /path/to/file");
        content.append(uri_label);
        content.append(uri_entry);

        var label_label = new Gtk.Label("Label") { xalign = 0.0f };
        var label_entry = new Gtk.Entry();
        content.append(label_label);
        content.append(label_entry);

        var local_picker_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var pick_file_btn = new Gtk.Button.with_label("Pick File...");
        pick_file_btn.clicked.connect(() => {
            open_local_resource_picker(root_window, uri_entry, label_entry, false);
        });
        local_picker_row.append(pick_file_btn);
        var pick_image_btn = new Gtk.Button.with_label("Pick Image...");
        pick_image_btn.clicked.connect(() => {
            open_local_resource_picker(root_window, uri_entry, label_entry, true);
        });
        local_picker_row.append(pick_image_btn);
        content.append(local_picker_row);

        var desc_label = new Gtk.Label("Description (optional)") { xalign = 0.0f };
        var desc_entry = new Gtk.Entry();
        content.append(desc_label);
        content.append(desc_entry);

        if (existing != null) {
            uri_entry.set_text(existing.uri);
            label_entry.set_text(existing.label);
            desc_entry.set_text(existing.desc ?? "");
            int match = -1;
            for (uint i = 0; i < kind_options.get_n_items(); i++) {
                var option = kind_options.get_string(i);
                if (option == existing.kind) {
                    match = (int) i;
                    break;
                }
            }
            if (match >= 0) {
                kind_dropdown.set_selected((uint) match);
            } else {
                kind_dropdown.set_selected(kind_options.get_n_items() - 1);
                custom_kind_entry.set_visible(true);
                custom_kind_entry.set_text(existing.kind);
            }
        } else {
            kind_dropdown.set_selected(0);
        }

        dialog.set_extra_child(content);
        dialog.response.connect((response) => {
            if (response != "save") {
                dialog.close();
                return;
            }

            var uri = uri_entry.get_text().strip();
            var label = label_entry.get_text().strip();
            var desc_raw = desc_entry.get_text().strip();
            if (uri.length == 0 || label.length == 0) {
                toast_requested("URI and label are required.");
                return;
            }

            string kind = "url";
            var selected = kind_dropdown.get_selected();
            if (selected < kind_options.get_n_items() - 1) {
                kind = kind_options.get_string(selected);
            } else {
                var custom = custom_kind_entry.get_text().strip();
                kind = custom.length > 0 ? custom : "url";
            }

            var desc = desc_raw.length > 0 ? desc_raw : null;
            if (existing != null) {
                update_resource.begin(existing.resource_id, kind, uri, label, desc);
            } else {
                create_resource.begin(project.project_id, kind, uri, label, desc);
            }
            dialog.close();
        });
        dialog.present();
    }

    internal async void create_resource(string project_id,
                                        string kind,
                                        string uri,
                                        string label,
                                        string? desc) {
        var result = yield controller.create_resource_flow(api, project_id, kind, uri, label, desc);
        if (result.ignored) {
            return;
        }
        if (result.success) {
            if (result.toast_message.strip().length > 0) {
                toast_requested(result.toast_message);
            }
            queue_resources_refresh();
            return;
        }
        error_reported(result.error_title, result.error_details);
    }

    internal async void update_resource(string resource_id,
                                        string kind,
                                        string uri,
                                        string label,
                                        string? desc) {
        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var project_id = project != null ? project.project_id : null;
        var result = yield controller.update_resource_flow_scoped(api, resource_id, project_id, kind, uri, label, desc);
        if (result.ignored) {
            return;
        }
        if (result.success) {
            if (result.toast_message.strip().length > 0) {
                toast_requested(result.toast_message);
            }
            queue_resources_refresh();
            return;
        }
        error_reported(result.error_title, result.error_details);
    }

    private void open_selected_resource() {
        var selected = selected_resource();
        if (selected == null) {
            return;
        }
        try {
            AppInfo.launch_default_for_uri(selected.uri, null);
        } catch (Error e) {
            error_reported("Failed to open resource", e.message);
        }
    }

    private void confirm_delete_selected_resource() {
        var selected = selected_resource();
        if (selected == null) {
            return;
        }
        var root_window = widget.get_root() as Gtk.Window;
        if (root_window == null) {
            return;
        }

        var dialog = new Adw.MessageDialog(
            root_window,
            "Delete Resource",
            "Delete \"%s\"?".printf(selected.label)
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("delete", "Delete");
        dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.response.connect((response) => {
            if (response == "delete") {
                delete_resource.begin(selected.resource_id);
            }
            dialog.close();
        });
        dialog.present();
    }

    internal async void delete_resource(string resource_id) {
        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var project_id = project != null ? project.project_id : "";
        var selected = selected_resource();
        var resource_label = selected != null ? selected.label : "resource";
        var result = yield controller.delete_resource_flow_scoped(api, resource_id, project_id, resource_label);
        if (result.ignored) {
            return;
        }
        if (result.success) {
            if (result.toast_message.strip().length > 0) {
                toast_requested(result.toast_message);
            }
            queue_resources_refresh();
            return;
        }
        error_reported(result.error_title, result.error_details);
    }

    private void open_local_resource_picker(Gtk.Window root_window,
                                            Gtk.Entry uri_entry,
                                            Gtk.Entry? label_entry,
                                            bool images_only) {
        var dialog = new Gtk.FileDialog();
        dialog.set_title(images_only ? "Choose Image" : "Choose File");

        if (images_only) {
            var image_filter = new Gtk.FileFilter();
            image_filter.add_mime_type("image/*");
            var filters = new GLib.ListStore(typeof(Gtk.FileFilter));
            filters.append(image_filter);
            dialog.set_filters(filters);
            dialog.set_default_filter(image_filter);
        }

        dialog.open.begin(root_window, null, (obj, res) => {
            try {
                var file = dialog.open.end(res);
                if (file == null) {
                    return;
                }
                var uri = file.get_uri();
                if (uri != null && uri.length > 0) {
                    uri_entry.set_text(uri);
                }
                if (label_entry != null && label_entry.get_text().strip().length == 0) {
                    var basename = file.get_basename();
                    if (basename != null && basename.length > 0) {
                        label_entry.set_text(basename);
                    }
                }
            } catch (Error e) {
                if (!(e is IOError.CANCELLED)) {
                    error_reported("Failed to choose file", e.message);
                }
            }
        });
    }
}

}
