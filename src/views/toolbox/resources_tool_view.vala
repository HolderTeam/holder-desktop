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
    private Gtk.ListBox locations_list;
    private Gtk.Label locations_empty_label;
    private string? preferred_location_id;
    private Gee.ArrayList<ProjectResource> all_resources = new Gee.ArrayList<ProjectResource>();
    private uint resources_refresh_serial = 0;
    private bool has_committed_resources = false;
    private string? pending_resource_selection_id;

    public Gtk.Widget widget { get; private set; }
    public string tool_id {
        owned get { return "resources"; }
    }
    public string tool_label {
        owned get { return "Resources"; }
    }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void asset_preview_requested(ProjectResource resource, ResourceAsset asset);
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

        resources_store = new GLib.ListStore(typeof(ProjectResource));
        resources_selection = new Gtk.SingleSelection(resources_store);
        resources_selection.set_autoselect(true);
        resources_selection.notify["selected-item"].connect(() => {
            refresh_resource_action_state();
        });

        var view = new Gtk.ColumnView(resources_selection);
        view.set_vexpand(true);
        view.set_single_click_activate(false);
        view.activate.connect((position) => {
            resources_selection.set_selected(position);
            open_selected_resource();
        });
        view.append_column(build_resource_text_column("Label", "label"));
        view.append_column(build_resource_text_column("Type", "kind"));
        view.append_column(build_resource_text_column("Assets", "assets"));
        view.append_column(build_resource_text_column("Description", "desc"));
        view.append_column(build_resource_text_column("Updated", "updated"));

        var scroller = new Gtk.ScrolledWindow();
        scroller.set_vexpand(true);
        scroller.set_child(view);
        root.append(scroller);

        var scope_label = new Gtk.Label("All project Resources") { xalign = 0.0f };
        scope_label.add_css_class("dim-label");
        scope_label.set_margin_start(4);
        root.prepend(scope_label);

        resources_empty_label = new Gtk.Label("No resources in this project.") { xalign = 0.0f };
        resources_empty_label.set_name("resources-empty-state");
        resources_empty_label.add_css_class("dim-label");
        resources_empty_label.set_visible(false);
        root.append(resources_empty_label);

        var separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        separator.set_margin_top(6);
        root.append(separator);

        var locations_header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var locations_title = new Gtk.Label("Storage Locations") { xalign = 0.0f, hexpand = true };
        locations_title.add_css_class("heading");
        locations_header.append(locations_title);
        var add_local = new Gtk.Button.with_label("Add Folder");
        add_local.clicked.connect(() => { open_location_dialog(false); });
        locations_header.append(add_local);
        var add_s3 = new Gtk.Button.with_label("Add S3-compatible");
        add_s3.clicked.connect(() => { open_location_dialog(true); });
        locations_header.append(add_s3);
        root.append(locations_header);

        locations_list = new Gtk.ListBox();
        locations_list.set_selection_mode(Gtk.SelectionMode.NONE);
        locations_list.add_css_class("boxed-list");
        root.append(locations_list);
        locations_empty_label = new Gtk.Label("No storage location configured for this project.") {
            xalign = 0.0f
        };
        locations_empty_label.add_css_class("dim-label");
        root.append(locations_empty_label);

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
                case "assets":
                    label.set_text(resource.assets.size.to_string());
                    label.set_tooltip_text(
                        resource.assets.size == 1 ? "1 attached asset" : "%d attached assets".printf(resource.assets.size)
                    );
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
        refresh_locations.begin(resources_refresh_serial);
    }

    private async void refresh_locations(uint request_serial) {
        if (locations_list == null) {
            return;
        }
        clear_locations();
        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var storage_api = api as IResourceStorageApi;
        if (project == null || storage_api == null) {
            locations_empty_label.set_visible(true);
            return;
        }
        try {
            var result = yield storage_api.list_storage_locations(project.project_id);
            if (request_serial != resources_refresh_serial) {
                return;
            }
            preferred_location_id = result.preferred_location_id;
            foreach (var location in result.locations) {
                locations_list.append(build_location_row(project, location));
            }
            locations_empty_label.set_visible(result.locations.size == 0);
        } catch (Error e) {
            locations_empty_label.set_text("Failed to load storage locations.");
            locations_empty_label.set_visible(true);
            error_reported("Storage Locations refresh failed", e.message);
        }
    }

    private void clear_locations() {
        var child = locations_list.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            locations_list.remove(child);
            child = next;
        }
    }

    private Gtk.Widget build_location_row(Project project, StorageLocation location) {
        var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        row.set_margin_top(8);
        row.set_margin_bottom(8);
        row.set_margin_start(10);
        row.set_margin_end(10);
        var text = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
        text.set_hexpand(true);
        var title = new Gtk.Label(location.name) { xalign = 0.0f };
        title.add_css_class("heading");
        text.append(title);
        var summary_text = location.provider == "local_directory" ? "Local folder" : "S3-compatible storage";
        if (location.binding_preview != null) {
            summary_text += " · " + (!) location.binding_preview;
        } else {
            summary_text += " · Configuration required";
        }
        var summary = new Gtk.Label(summary_text) { xalign = 0.0f };
        summary.add_css_class("dim-label");
        text.append(summary);
        row.append(text);
        if (preferred_location_id == location.location_id) {
            var preferred = new Gtk.Label("Preferred");
            preferred.add_css_class("accent");
            row.append(preferred);
        } else if (location.bound) {
            var prefer = new Gtk.Button.with_label("Use by default");
            prefer.clicked.connect(() => { prefer_location.begin(project.project_id, location.location_id); });
            row.append(prefer);
        }
        var test = new Gtk.Button.from_icon_name("emblem-ok-symbolic");
        test.set_tooltip_text("Test storage location");
        test.set_sensitive(location.bound);
        test.clicked.connect(() => { test_location.begin(location.location_id); });
        row.append(test);
        var remove = new Gtk.Button.from_icon_name("user-trash-symbolic");
        remove.set_tooltip_text("Delete storage location");
        remove.clicked.connect(() => { delete_location.begin(location.location_id); });
        row.append(remove);
        return row;
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
        var previous = selected_resource();
        var previous_id = pending_resource_selection_id ??
            (previous != null ? previous.resource_id : null);
        clear_visible_resources();

        var query = resources_search_entry != null ? resources_search_entry.get_text() : "";
        var result = controller.apply_resources_filter_flow(all_resources, query);
        uint index = 0;
        uint selected_index = Gtk.INVALID_LIST_POSITION;
        foreach (var resource in result.filtered) {
            resources_store.append(resource);
            if (previous_id != null && resource.resource_id == previous_id) {
                selected_index = index;
            }
            index++;
        }
        if (selected_index != Gtk.INVALID_LIST_POSITION) {
            resources_selection.set_selected(selected_index);
            pending_resource_selection_id = null;
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

    private void open_location_dialog(bool s3_compatible) {
        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var storage_api = api as IResourceStorageApi;
        var root_window = widget.get_root() as Gtk.Window;
        if (project == null || storage_api == null || root_window == null) {
            toast_requested("Select a project and connect to Holder first.");
            return;
        }

        var dialog = new Adw.MessageDialog(
            root_window,
            s3_compatible ? "Add S3-compatible Storage" : "Add Storage Folder",
            s3_compatible
                ? "The endpoint and bucket are shared through Git. Credentials stay in this device's keyring."
                : "The folder path stays private to this device."
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("save", "Add");
        dialog.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("save");
        dialog.set_close_response("cancel");

        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var project_notice = new Gtk.Label("Project: %s".printf(project.name)) { xalign = 0.0f };
        project_notice.add_css_class("heading");
        content.append(project_notice);
        var name = new Gtk.Entry();
        name.set_placeholder_text(s3_compatible ? "Family Assets" : "Assets on this computer");
        content.append(new Gtk.Label("Name") { xalign = 0.0f });
        content.append(name);

        var path = new Gtk.Entry();
        var endpoint = new Gtk.Entry();
        var region = new Gtk.Entry();
        var bucket = new Gtk.Entry();
        var prefix = new Gtk.Entry();
        var access_key = new Gtk.Entry();
        var secret_key = new Gtk.Entry();
        var session_token = new Gtk.Entry();
        access_key.set_visibility(false);
        secret_key.set_visibility(false);
        session_token.set_visibility(false);
        if (!s3_compatible) {
            var path_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            path.set_hexpand(true);
            path.set_placeholder_text("/path/to/assets");
            path_row.append(path);
            var choose = new Gtk.Button.with_label("Choose…");
            choose.clicked.connect(() => {
                var picker = new Gtk.FileDialog();
                picker.set_title("Choose Storage Folder");
                picker.select_folder.begin(root_window, null, (obj, result) => {
                    try {
                        var folder = picker.select_folder.end(result);
                        if (folder != null && folder.get_path() != null) path.set_text((!) folder.get_path());
                    } catch (Error e) {
                        if (!(e is IOError.CANCELLED)) error_reported("Failed to choose folder", e.message);
                    }
                });
            });
            path_row.append(choose);
            content.append(new Gtk.Label("Folder") { xalign = 0.0f });
            content.append(path_row);
        } else {
            endpoint.set_placeholder_text("https://s3.example.com");
            region.set_placeholder_text("us-east-1");
            bucket.set_placeholder_text("holder-family-assets");
            prefix.set_placeholder_text("optional/prefix");
            access_key.set_placeholder_text("Access key ID");
            secret_key.set_placeholder_text("Secret access key");
            session_token.set_placeholder_text("Session token (optional)");
            content.append(new Gtk.Label("Endpoint") { xalign = 0.0f }); content.append(endpoint);
            content.append(new Gtk.Label("Region") { xalign = 0.0f }); content.append(region);
            content.append(new Gtk.Label("Bucket") { xalign = 0.0f }); content.append(bucket);
            content.append(new Gtk.Label("Object prefix (optional)") { xalign = 0.0f }); content.append(prefix);
            content.append(new Gtk.Separator(Gtk.Orientation.HORIZONTAL));
            content.append(new Gtk.Label("Credentials for this device") { xalign = 0.0f });
            content.append(access_key); content.append(secret_key); content.append(session_token);
        }
        dialog.set_extra_child(content);
        dialog.response.connect((response) => {
            if (response != "save") {
                dialog.close();
                return;
            }
            var location_name = name.get_text().strip();
            if (location_name.length == 0) {
                toast_requested("A storage location name is required.");
                return;
            }
            var configuration = new Gee.HashMap<string, string>();
            var values = new Gee.HashMap<string, string>();
            string preview;
            if (s3_compatible) {
                if (endpoint.get_text().strip().length == 0 ||
                    region.get_text().strip().length == 0 ||
                    bucket.get_text().strip().length == 0 ||
                    access_key.get_text().strip().length == 0 ||
                    secret_key.get_text().length == 0) {
                    toast_requested("Endpoint, region, bucket and credentials are required.");
                    return;
                }
                configuration.set("endpoint", endpoint.get_text().strip());
                configuration.set("region", region.get_text().strip());
                configuration.set("bucket", bucket.get_text().strip());
                configuration.set("prefix", prefix.get_text().strip());
                configuration.set("addressing_style", "path");
                values.set("access_key_id", access_key.get_text().strip());
                values.set("secret_access_key", secret_key.get_text());
                if (session_token.get_text().length > 0) values.set("session_token", session_token.get_text());
                preview = "%s / %s".printf(endpoint.get_text().strip(), bucket.get_text().strip());
            } else {
                if (path.get_text().strip().length == 0) {
                    toast_requested("Choose a storage folder.");
                    return;
                }
                values.set("root_path", path.get_text().strip());
                preview = path.get_text().strip();
            }
            create_and_bind_location.begin(
                project.project_id,
                location_name,
                s3_compatible ? "s3_compatible" : "local_directory",
                configuration,
                values,
                preview
            );
            dialog.close();
        });
        dialog.present();
    }

    private async void create_and_bind_location(string project_id,
                                                string name,
                                                string provider,
                                                Gee.HashMap<string, string> configuration,
                                                Gee.HashMap<string, string> values,
                                                string preview) {
        var storage_api = api as IResourceStorageApi;
        if (storage_api == null) return;
        try {
            var location_id = yield storage_api.create_storage_location(
                project_id, name, provider, configuration
            );
            yield storage_api.bind_storage_location(location_id, values, preview);
            if (preferred_location_id == null) {
                yield storage_api.prefer_storage_location(project_id, location_id);
            }
            toast_requested("Storage location added.");
            queue_resources_refresh();
        } catch (Error e) {
            error_reported("Failed to add storage location", e.message);
        }
    }

    private async void prefer_location(string project_id, string location_id) {
        var storage_api = api as IResourceStorageApi;
        if (storage_api == null) return;
        try {
            yield storage_api.prefer_storage_location(project_id, location_id);
            toast_requested("Preferred storage location updated.");
            queue_resources_refresh();
        } catch (Error e) {
            error_reported("Failed to update preferred location", e.message);
        }
    }

    private async void test_location(string location_id) {
        var storage_api = api as IResourceStorageApi;
        if (storage_api == null) return;
        try {
            yield storage_api.test_storage_location(location_id);
            toast_requested("Storage location is available.");
        } catch (Error e) {
            error_reported("Storage location test failed", e.message);
        }
    }

    private async void delete_location(string location_id) {
        var storage_api = api as IResourceStorageApi;
        if (storage_api == null) return;
        try {
            yield storage_api.delete_storage_location(location_id);
            toast_requested("Storage location removed.");
            queue_resources_refresh();
        } catch (Error e) {
            error_reported("Failed to remove storage location", e.message);
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
            is_edit ? "Update the Resource's basic metadata." : "Describe a thing in this Project."
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("save", "Save");
        dialog.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("save");
        dialog.set_close_response("cancel");

        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var project_notice = new Gtk.Label("Project: %s".printf(project.name)) { xalign = 0.0f };
        project_notice.add_css_class("heading");
        content.append(project_notice);
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

        var uri_label = new Gtk.Label("Identifier (optional)") { xalign = 0.0f };
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

        var details_view = new Gtk.TextView();
        details_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        details_view.set_monospace(true);
        details_view.set_top_margin(6);
        details_view.set_bottom_margin(6);
        details_view.set_left_margin(6);
        details_view.set_right_margin(6);
        var details_scroll = new Gtk.ScrolledWindow();
        details_scroll.set_min_content_height(100);
        details_scroll.set_child(details_view);
        var details_expander = new Gtk.Expander("Additional Details");
        details_expander.set_tooltip_text("One property: value entry per line; repeat a property for multiple values.");
        details_expander.set_child(details_scroll);
        content.append(details_expander);

        if (existing != null) {
            uri_entry.set_text(existing.uri);
            label_entry.set_text(existing.label);
            desc_entry.set_text(existing.desc ?? "");
            details_view.get_buffer().set_text(controller.format_additional_metadata(existing));
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
            if (label.length == 0) {
                toast_requested("A label is required.");
                return;
            }

            string kind = "thing";
            var selected = kind_dropdown.get_selected();
            if (selected < kind_options.get_n_items() - 1) {
                kind = kind_options.get_string(selected);
            } else {
                var custom = custom_kind_entry.get_text().strip();
                kind = custom.length > 0 ? custom : "thing";
            }

            var desc = desc_raw.length > 0 ? desc_raw : null;
            Gtk.TextIter details_start;
            Gtk.TextIter details_end;
            details_view.get_buffer().get_bounds(out details_start, out details_end);
            Gee.HashMap<string, Gee.ArrayList<string>> extra_metadata;
            try {
                extra_metadata = controller.parse_additional_metadata(
                    details_view.get_buffer().get_text(details_start, details_end, false)
                );
            } catch (Error e) {
                toast_requested(e.message);
                return;
            }
            if (existing != null) {
                foreach (var entry in existing.metadata.entries) {
                    if (entry.key != "identifier" && entry.key != "description" &&
                        !extra_metadata.has_key(entry.key)) {
                        extra_metadata.set(entry.key, new Gee.ArrayList<string>());
                    }
                }
            }
            if (existing != null) {
                update_resource.begin(existing.resource_id, kind, uri, label, desc, extra_metadata);
            } else {
                create_resource.begin(project.project_id, kind, uri, label, desc, extra_metadata);
            }
            dialog.close();
        });
        dialog.present();
    }

    internal async void create_resource(string project_id,
                                        string kind,
                                        string uri,
                                        string label,
                                        string? desc,
                                        Gee.HashMap<string, Gee.ArrayList<string>>? extra_metadata = null) {
        var result = yield controller.create_resource_flow(
            api, project_id, kind, uri, label, desc, extra_metadata
        );
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
                                        string? desc,
                                        Gee.HashMap<string, Gee.ArrayList<string>>? extra_metadata = null) {
        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var project_id = project != null ? project.project_id : null;
        var result = yield controller.update_resource_flow_scoped(
            api, resource_id, project_id, kind, uri, label, desc, extra_metadata
        );
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
        if (selected.assets.size > 0) {
            asset_preview_requested(selected, selected.assets[0]);
            return;
        }
        if (selected.uri.strip().length == 0) {
            toast_requested("This Resource has no Asset or identifier to open.");
            return;
        }
        try {
            AppInfo.launch_default_for_uri(selected.uri, null);
        } catch (Error e) {
            error_reported("Failed to open resource", e.message);
        }
    }

    public void request_refresh(string? select_resource_id = null) {
        if (select_resource_id != null) {
            pending_resource_selection_id = select_resource_id;
        }
        queue_resources_refresh();
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
