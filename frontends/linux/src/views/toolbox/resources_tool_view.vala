namespace HolderLinux {

public class ResourcesToolView : Object {
    private ResourcesController controller;
    private IHolderApi? api;
    private Gtk.SingleSelection? project_selection;
    private GLib.ListStore resources_store;
    private Gtk.SingleSelection resources_selection;
    private Gtk.SearchEntry resources_search_entry;
    private Gtk.Label resources_empty_label;
    private Gtk.Button resources_open_btn;
    private Gtk.Button resources_edit_btn;
    private Gtk.Button resources_delete_btn;
    private Gee.ArrayList<ProjectResource> all_resources = new Gee.ArrayList<ProjectResource>();
    private uint resources_refresh_serial = 0;

    public Gtk.Widget widget { get; private set; }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);

    public ResourcesToolView() {
        controller = new ResourcesController();
        widget = build_resources_tab();
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

    private Gtk.Widget build_resources_tab() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        resources_search_entry = new Gtk.SearchEntry();
        resources_search_entry.set_placeholder_text("Filter resources...");
        resources_search_entry.set_hexpand(true);
        resources_search_entry.search_changed.connect(() => {
            apply_resources_filter();
        });
        header.append(resources_search_entry);

        var add_btn = new Gtk.Button.from_icon_name("list-add-symbolic");
        add_btn.set_tooltip_text("Add resource");
        add_btn.clicked.connect(() => {
            open_resource_dialog(null);
        });
        header.append(add_btn);

        var refresh_btn = new Gtk.Button.from_icon_name("view-refresh-symbolic");
        refresh_btn.set_tooltip_text("Refresh resources");
        refresh_btn.clicked.connect(() => {
            queue_resources_refresh();
        });
        header.append(refresh_btn);
        root.append(header);

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

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        resources_open_btn = new Gtk.Button.with_label("Open");
        resources_open_btn.clicked.connect(() => {
            open_selected_resource();
        });
        actions.append(resources_open_btn);

        resources_edit_btn = new Gtk.Button.with_label("Edit");
        resources_edit_btn.clicked.connect(() => {
            var selected = selected_resource();
            if (selected != null) {
                open_resource_dialog(selected);
            }
        });
        actions.append(resources_edit_btn);

        resources_delete_btn = new Gtk.Button.with_label("Delete");
        resources_delete_btn.add_css_class("destructive-action");
        resources_delete_btn.clicked.connect(() => {
            confirm_delete_selected_resource();
        });
        actions.append(resources_delete_btn);
        root.append(actions);

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
        if (resources_store == null) {
            return;
        }
        while (resources_store.get_n_items() > 0) {
            resources_store.remove(resources_store.get_n_items() - 1);
        }
        all_resources.clear();

        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        if (project == null) {
            resources_empty_label.set_text("Select a project to view resources.");
            resources_empty_label.set_visible(true);
            refresh_resource_action_state();
            return;
        }
        if (api == null) {
            resources_empty_label.set_text("API unavailable.");
            resources_empty_label.set_visible(true);
            refresh_resource_action_state();
            return;
        }

        try {
            var resources = yield controller.list_resources(api, project.project_id);
            if (request_serial != resources_refresh_serial) {
                return;
            }
            all_resources = resources;
            apply_resources_filter();
        } catch (Error e) {
            if (request_serial != resources_refresh_serial) {
                return;
            }
            resources_empty_label.set_text("Failed to load resources.");
            resources_empty_label.set_visible(true);
            error_reported("Resources refresh failed", e.message);
            refresh_resource_action_state();
        }
    }

    private void apply_resources_filter() {
        if (resources_store == null) {
            return;
        }
        while (resources_store.get_n_items() > 0) {
            resources_store.remove(resources_store.get_n_items() - 1);
        }

        var query = resources_search_entry != null ? resources_search_entry.get_text() : "";
        var filtered = controller.filter_resources(all_resources, query);
        foreach (var resource in filtered) {
            resources_store.append(resource);
        }

        resources_empty_label.set_visible(resources_store.get_n_items() == 0);
        if (resources_store.get_n_items() == 0) {
            resources_empty_label.set_text(
                query.strip().length > 0 ? "No resources match this filter." : "No resources in this project."
            );
        }
        refresh_resource_action_state();
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

    private async void create_resource(string project_id,
                                       string kind,
                                       string uri,
                                       string label,
                                       string? desc) {
        if (api == null) {
            return;
        }
        try {
            yield controller.create_resource(api, project_id, kind, uri, label, desc);
            toast_requested("Resource added.");
            queue_resources_refresh();
        } catch (Error e) {
            error_reported("Failed to create resource", e.message);
        }
    }

    private async void update_resource(string resource_id,
                                       string kind,
                                       string uri,
                                       string label,
                                       string? desc) {
        if (api == null) {
            return;
        }
        try {
            yield controller.update_resource(api, resource_id, kind, uri, label, desc);
            toast_requested("Resource updated.");
            queue_resources_refresh();
        } catch (Error e) {
            error_reported("Failed to update resource", e.message);
        }
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

    private async void delete_resource(string resource_id) {
        if (api == null) {
            return;
        }
        try {
            yield controller.delete_resource(api, resource_id);
            toast_requested("Resource deleted.");
            queue_resources_refresh();
        } catch (Error e) {
            error_reported("Failed to delete resource", e.message);
        }
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
