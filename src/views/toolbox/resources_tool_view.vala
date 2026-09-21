namespace HolderLinux {

public class ResourcesToolView : Object, IToolShellAdapter {
    private ResourcesController controller; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private StorageLocationsController locations_controller = new StorageLocationsController();
    private IHolderApi? api; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.SingleSelection? project_selection; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Box resources_actions_bar; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private GLib.ListStore resources_store; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.SingleSelection resources_selection; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.SearchEntry resources_search_entry; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label resources_empty_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Button resources_open_btn; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Button resources_edit_btn; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Button resources_delete_btn; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.ListBox locations_list; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label locations_empty_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private string? preferred_location_id; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gee.ArrayList<ProjectResource> all_resources = new Gee.ArrayList<ProjectResource>();
    private uint resources_refresh_serial = 0; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private ulong project_selection_handler_id = 0; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private bool has_committed_resources = false; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private string? pending_resource_selection_id; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private IUriLauncher uri_launcher; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private IScheduler scheduler; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private IFilePicker file_picker; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer

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
    public signal void card_open_requested(string card_id);
    public signal void resource_references_requested(ProjectResource resource);
    public signal void project_resources_loaded(string project_id,
                                                Gee.ArrayList<ProjectResource> resources);
    public signal void activity_requested(string kind,
                                          string message,
                                          string? project_id,
                                          string? resource_id,
                                          ActivityDetails? details);

    // The launcher, scheduler and file picker default to the real desktop implementations; tests pass
    // fakes so they need no browser, timers or file chooser.
    public ResourcesToolView(IUriLauncher? uri_launcher = null,
                             IScheduler? scheduler = null,
                             IFilePicker? file_picker = null) {
        this.uri_launcher = uri_launcher ?? new AppInfoUriLauncher();
        this.scheduler = scheduler ?? new MainLoopScheduler();
        this.file_picker = file_picker ?? new GtkFilePicker();
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
        if (this.project_selection != null && project_selection_handler_id != 0) {
            this.project_selection.disconnect(project_selection_handler_id);
        }
        project_selection_handler_id = 0;
        this.project_selection = project_selection;
        if (this.project_selection != null) {
            project_selection_handler_id = this.project_selection.notify["selected"].connect(() => {
                queue_resources_refresh();
            });
        }
        queue_resources_refresh();
    }

    public ToolScopeSnapshot get_scope_snapshot(Project? selected_project, CardSummary? selected_card) {
        return ToolScopePresenter.snapshot(tool_id, tool_label, selected_project, selected_card);
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
        view.append_column(build_resource_usage_column());
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
        var add_google_drive = new Gtk.Button.with_label("Add Google Drive");
        add_google_drive.clicked.connect(() => { open_google_drive_connect_flow(); });
        locations_header.append(add_google_drive);
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
                return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: defensive; GTK hands these callbacks the ListItem, item and child set up here
            }
            var label = new Gtk.Label("") { xalign = 0.0f };
            label.set_wrap(false);
            label.set_ellipsize(Pango.EllipsizeMode.END);
            item.set_child(label);
        });
        factory.bind.connect((item_obj) => {
            var item = item_obj as Gtk.ListItem;
            if (item == null) {
                return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: defensive; GTK hands these callbacks the ListItem, item and child set up here
            }
            var resource = item.get_item() as ProjectResource;
            var label = item.get_child() as Gtk.Label;
            if (resource == null || label == null) {
                return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: defensive; GTK hands these callbacks the ListItem, item and child set up here
            }
            var cell = ResourcesPresenter.cell(controller, resource, field);
            label.set_text(cell.text);
            if (cell.tooltip != null) {
                label.set_tooltip_text(cell.tooltip);
            }
        });

        return new Gtk.ColumnViewColumn(title, factory);
    }

    private Gtk.ColumnViewColumn build_resource_usage_column() {
        var factory = new Gtk.SignalListItemFactory();
        factory.setup.connect((item_obj) => {
            var item = item_obj as Gtk.ListItem;
            if (item == null) {
                return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: defensive; GTK hands these callbacks the ListItem, item and child set up here
            }
            var links = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
            links.set_hexpand(true);
            item.set_child(links);
        });
        factory.bind.connect((item_obj) => {
            var item = item_obj as Gtk.ListItem;
            if (item == null) {
                return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: defensive; GTK hands these callbacks the ListItem, item and child set up here
            }
            var resource = item.get_item() as ProjectResource;
            var links = item.get_child() as Gtk.Box;
            if (resource == null || links == null) {
                return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: defensive; GTK hands these callbacks the ListItem, item and child set up here
            }
            clear_box(links);
            populate_resource_usage(links, resource);
        });

        var column = new Gtk.ColumnViewColumn("Used by", factory);
        column.set_expand(true);
        return column;
    }

    private void populate_resource_usage(Gtk.Box links, ProjectResource resource) {
        var usage = ResourcesPresenter.usage(resource);
        if (usage.is_unused) {
            var none = new Gtk.Label("—") { xalign = 0.0f };
            none.add_css_class("dim-label");
            links.append(none);
            return;
        }

        for (int index = 0; index < usage.visible_references.size; index++) {
            if (index > 0) {
                var separator = new Gtk.Label("·");
                separator.add_css_class("dim-label");
                links.append(separator);
            }
            links.append(build_card_reference_button(usage.visible_references[index]));
        }

        if (usage.remaining_count > 0) {
            var separator = new Gtk.Label("·");
            separator.add_css_class("dim-label");
            links.append(separator);
            var more = new Gtk.Button.with_label(usage.overflow_label);
            more.add_css_class("flat");
            more.add_css_class("accent");
            more.set_tooltip_text(usage.overflow_tooltip);
            more.clicked.connect(() => {
                resource_references_requested(resource);
            });
            links.append(more);
        }
    }

    private Gtk.Button build_card_reference_button(ResourceCardReference reference) {
        var button = new Gtk.Button.with_label(reference.title);
        button.add_css_class("flat");
        button.add_css_class("accent");
        button.set_tooltip_text(ResourcesPresenter.reference_tooltip(reference));
        var label = button.get_child() as Gtk.Label;
        if (label != null) {
            label.set_ellipsize(Pango.EllipsizeMode.END);
            label.set_max_width_chars(24);
        }
        button.clicked.connect(() => {
            card_open_requested(reference.card_id);
        });
        return button;
    }

    private static void clear_box(Gtk.Box box) {
        var child = box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling(); // LCOV_EXCL_LINE GCOVR_EXCL_LINE: only runs when GTK recycles a bound row for another resource, which needs a scrolled, presented list
            box.remove(child); // LCOV_EXCL_LINE GCOVR_EXCL_LINE: see above
            child = next; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: see above
        }
    }

    private void queue_resources_refresh() {
        resources_refresh_serial++;
        refresh_resources.begin(resources_refresh_serial);
        refresh_locations.begin(resources_refresh_serial);
    }

    private async void refresh_locations(uint request_serial) {
        clear_locations();
        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var result = yield locations_controller.refresh_flow(api as IResourceStorageApi, project);
        if (request_serial != resources_refresh_serial) {
            // A newer refresh owns the list now; a stale failure must not overwrite its empty text or
            // report an error for a project that is no longer shown.
            return;
        }
        locations_empty_label.set_text(result.empty_text);
        locations_empty_label.set_visible(result.empty_visible);
        if (result.success) {
            preferred_location_id = result.preferred_location_id;
            foreach (var location in result.locations) {
                locations_list.append(build_location_row(project, location));
            }
        }
        if (result.has_error) {
            error_reported(result.error_title, result.error_details);
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
        var presentation = StorageLocationPresenter.row(location, preferred_location_id);
        var title = new Gtk.Label(presentation.title) { xalign = 0.0f };
        title.add_css_class("heading");
        text.append(title);
        var summary = new Gtk.Label(presentation.summary) { xalign = 0.0f };
        summary.add_css_class("dim-label");
        text.append(summary);
        row.append(text);
        if (presentation.is_preferred) {
            var preferred = new Gtk.Label("Preferred");
            preferred.add_css_class("accent");
            row.append(preferred);
        } else if (presentation.offers_use_by_default) {
            var prefer = new Gtk.Button.with_label("Use by default");
            prefer.clicked.connect(() => { prefer_location.begin(project.project_id, location.location_id); });
            row.append(prefer);
        }
        var test = new Gtk.Button.from_icon_name("emblem-ok-symbolic");
        test.set_tooltip_text("Test storage location");
        test.set_sensitive(presentation.test_enabled);
        test.clicked.connect(() => { test_location.begin(location.location_id); });
        row.append(test);
        var remove = new Gtk.Button.from_icon_name("user-trash-symbolic");
        remove.set_tooltip_text("Delete storage location");
        remove.clicked.connect(() => { delete_location.begin(location.location_id); });
        row.append(remove);
        return row;
    }

    private async void refresh_resources(uint request_serial) {
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
            if (project != null) {
                project_resources_loaded(project.project_id, result.resources);
            }
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
        var previous = selected_resource();
        var previous_id = pending_resource_selection_id ??
            (previous != null ? previous.resource_id : null);
        clear_visible_resources();

        var query = resources_search_entry.get_text();
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
        return resources_selection.get_selected_item() as ProjectResource;
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

        var dialog = new Adw.AlertDialog(
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
                choose_storage_folder.begin(root_window, path);
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
        dialog.set_response_enabled("save", location_draft_from_entries(
            s3_compatible, name, path, endpoint, region, bucket, prefix,
            access_key, secret_key, session_token
        ).can_save());
        Gtk.Entry[] validation_entries = {
            name, path, endpoint, region, bucket, access_key, secret_key
        };
        foreach (var validation_entry in validation_entries) {
            validation_entry.changed.connect(() => {
                dialog.set_response_enabled("save", location_draft_from_entries(
                    s3_compatible, name, path, endpoint, region, bucket, prefix,
                    access_key, secret_key, session_token
                ).can_save());
            });
        }
        dialog.response.connect((response) => {
            if (response != "save") {
                return;
            }
            var draft = location_draft_from_entries(
                s3_compatible, name, path, endpoint, region, bucket, prefix,
                access_key, secret_key, session_token
            );
            var validation_error = draft.validation_error();
            if (validation_error != null) {
                toast_requested((!) validation_error);
                return;
            }
            create_and_bind_location.begin(project.project_id, draft.location_name, draft.build_spec());
        });
        dialog.present(root_window);
    }

    private static StorageLocationDraft location_draft_from_entries(bool s3_compatible,
                                                                    Gtk.Entry name,
                                                                    Gtk.Entry path,
                                                                    Gtk.Entry endpoint,
                                                                    Gtk.Entry region,
                                                                    Gtk.Entry bucket,
                                                                    Gtk.Entry prefix,
                                                                    Gtk.Entry access_key,
                                                                    Gtk.Entry secret_key,
                                                                    Gtk.Entry session_token) {
        return new StorageLocationDraft(
            s3_compatible,
            name.get_text(),
            path.get_text(),
            endpoint.get_text(),
            region.get_text(),
            bucket.get_text(),
            prefix.get_text(),
            access_key.get_text(),
            secret_key.get_text(),
            session_token.get_text()
        );
    }

    private async void create_and_bind_location(string project_id,
                                                string name,
                                                StorageLocationSpec spec) {
        var result = yield locations_controller.create_and_bind_flow(
            api as IResourceStorageApi, project_id, name, spec, () => preferred_location_id
        );
        apply_location_result(result);
    }

    private void apply_location_result(ResourcesMutationResult result) {
        if (result.ignored) {
            return;
        }
        if (!result.success) {
            error_reported(result.error_title, result.error_details);
            return;
        }
        toast_requested(result.toast_message);
        if (result.should_refresh) {
            queue_resources_refresh();
        }
    }

    private void open_google_drive_connect_flow() {
        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var storage_api = api as IResourceStorageApi;
        var root_window = widget.get_root() as Gtk.Window;
        if (project == null || storage_api == null || root_window == null) {
            toast_requested("Select a project and connect to Holder first.");
            return;
        }
        connect_google_drive.begin(project.project_id, root_window);
    }

    private async void connect_google_drive(string project_id, Gtk.Window root_window) {
        var storage_api = api as IResourceStorageApi;
        if (storage_api == null) return;

        var spinner = new Gtk.Spinner();
        spinner.start();
        var status_label = new Gtk.Label("Preparing…") { xalign = 0.0f, wrap = true, hexpand = true };
        var status_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        status_row.append(spinner);
        status_row.append(status_label);

        var dialog = new Adw.AlertDialog(
            "Connect Google Drive",
            "You'll be sent to your browser to sign in and allow access. Come back here " +
                "when you're done."
        );
        dialog.add_response("cancel", "Cancel");
        dialog.set_close_response("cancel");
        dialog.set_extra_child(status_row);

        var flow = new GoogleDriveConnectFlow(
            storage_api, uri_launcher, scheduler, () => preferred_location_id
        );
        flow.status_changed.connect((text) => { status_label.set_text(text); });
        dialog.response.connect(() => { flow.cancel(); });
        dialog.present(root_window);

        var result = yield flow.run(project_id);
        switch (result.outcome) {
            case GoogleDriveConnectOutcome.CANCELLED:
                return;
            case GoogleDriveConnectOutcome.CONNECTED:
                dialog.close();
                toast_requested(result.toast_message);
                queue_resources_refresh();
                return;
            default:
                dialog.close();
                error_reported(result.error_title, result.error_details);
                return;
        }
    }

    private async void prefer_location(string project_id, string location_id) {
        apply_location_result(yield locations_controller.prefer_flow(
            api as IResourceStorageApi, project_id, location_id
        ));
    }

    private async void test_location(string location_id) {
        apply_location_result(yield locations_controller.test_flow(
            api as IResourceStorageApi, location_id
        ));
    }

    private async void delete_location(string location_id) {
        apply_location_result(yield locations_controller.delete_flow(
            api as IResourceStorageApi, location_id
        ));
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
        var dialog = new Adw.AlertDialog(
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
        var kind_choices = ResourceDraft.kind_options(controller);
        var kind_options = new Gtk.StringList(kind_choices);
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

        var label_label = new Gtk.Label("Label (required)") { xalign = 0.0f };
        var label_entry = new Gtk.Entry();
        content.append(label_label);
        content.append(label_entry);

        var local_picker_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var pick_file_btn = new Gtk.Button.with_label("Pick File...");
        pick_file_btn.clicked.connect(() => {
            open_local_resource_picker.begin(root_window, uri_entry, label_entry, false);
        });
        local_picker_row.append(pick_file_btn);
        var pick_image_btn = new Gtk.Button.with_label("Pick Image...");
        pick_image_btn.clicked.connect(() => {
            open_local_resource_picker.begin(root_window, uri_entry, label_entry, true);
        });
        local_picker_row.append(pick_image_btn);
        content.append(local_picker_row);

        var desc_label = new Gtk.Label("Description (optional)") { xalign = 0.0f };
        var desc_entry = new Gtk.Entry();
        content.append(desc_label);
        content.append(desc_entry);

        var details_view = new Gtk.TextView();
        details_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        WindowsMonospace.apply(details_view);
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
        var details_error = new Gtk.Label("") { xalign = 0.0f, wrap = true, visible = false };
        details_error.add_css_class("error");
        content.append(details_error);

        if (existing != null) {
            uri_entry.set_text(existing.uri);
            label_entry.set_text(existing.label);
            desc_entry.set_text(existing.desc ?? "");
            details_view.get_buffer().set_text(controller.format_additional_metadata(existing));
        }
        var kind_selection = ResourceDraft.select_kind(kind_choices, existing);
        kind_dropdown.set_selected(kind_selection.index);
        if (kind_selection.custom_text.length > 0) {
            custom_kind_entry.set_text(kind_selection.custom_text);
        }

        dialog.set_extra_child(content);
        update_resource_dialog_save_state(dialog, label_entry, details_view, details_error);
        label_entry.changed.connect(() => {
            update_resource_dialog_save_state(dialog, label_entry, details_view, details_error);
        });
        details_view.get_buffer().changed.connect(() => {
            update_resource_dialog_save_state(dialog, label_entry, details_view, details_error);
        });
        dialog.response.connect((response) => {
            if (response != "save") {
                return;
            }

            var kind = ResourceDraft.resolve_kind(
                kind_choices, kind_dropdown.get_selected(), custom_kind_entry.get_text()
            );
            var draft = ResourceDraft.build(
                controller,
                existing,
                kind,
                uri_entry.get_text(),
                label_entry.get_text(),
                desc_entry.get_text(),
                buffer_text(details_view)
            );
            if (draft.error_message != null) {
                toast_requested((!) draft.error_message);
                return;
            }
            if (existing != null) {
                update_resource.begin(
                    existing.resource_id, draft.kind, draft.uri, draft.label, draft.desc, draft.extra_metadata,
                    own_project_id(existing)
                );
            } else {
                create_resource.begin(
                    project.project_id, draft.kind, draft.uri, draft.label, draft.desc, draft.extra_metadata
                );
            }
        });
        dialog.present(root_window);
    }

    private static string buffer_text(Gtk.TextView view) {
        Gtk.TextIter start;
        Gtk.TextIter end;
        view.get_buffer().get_bounds(out start, out end);
        return view.get_buffer().get_text(start, end, false);
    }

    private void update_resource_dialog_save_state(Adw.AlertDialog dialog,
                                                   Gtk.Entry label_entry,
                                                   Gtk.TextView details_view,
                                                   Gtk.Label details_error) {
        var state = ResourceDraft.save_state(controller, label_entry.get_text(), buffer_text(details_view));
        if (state.error_message != null) {
            details_error.set_text((!) state.error_message);
        }
        details_error.set_visible(state.error_message != null);
        dialog.set_response_enabled("save", state.enabled);
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

    // The Resource's own project, or null when it does not say (the caller then falls back to
    // whatever project is selected).
    private static string? own_project_id(ProjectResource resource) {
        return resource.project_id.strip().length > 0 ? resource.project_id : null;
    }

    // resource_project_id is the project the Resource belongs to; it is what the activity log
    // records, so a selection that moved while a dialog was open cannot file it elsewhere.
    internal async void update_resource(string resource_id,
                                        string kind,
                                        string uri,
                                        string label,
                                        string? desc,
                                        Gee.HashMap<string, Gee.ArrayList<string>>? extra_metadata = null,
                                        string? resource_project_id = null) {
        var project_id = resource_project_id;
        if (project_id == null) {
            var project = project_selection != null
                ? project_selection.get_selected_item() as Project
                : null;
            project_id = project != null ? project.project_id : null;
        }
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
        var action = ResourcesPresenter.open_action(selected);
        switch (action.kind) {
            case ResourceOpenKind.PREVIEW_ASSET:
                asset_preview_requested(selected, (!) action.asset);
                return;
            case ResourceOpenKind.TOAST:
                toast_requested(action.text);
                return;
            default:
                break;
        }
        try {
            uri_launcher.launch(action.text);
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

        var dialog = new Adw.AlertDialog(
            "Delete Resource",
            "Delete \"%s\"?".printf(selected.label)
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("delete", "Delete");
        dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.response.connect((response) => {
            if (response == "delete") {
                delete_resource.begin(selected.resource_id, own_project_id(selected), selected.label);
            }
        });
        dialog.present(root_window);
    }

    // resource_project_id and resource_label describe the Resource being deleted; without them the
    // selected project and Resource are used.
    internal async void delete_resource(string resource_id,
                                        string? resource_project_id = null,
                                        string? resource_label = null) {
        var project_id = resource_project_id;
        if (project_id == null) {
            var project = project_selection != null
                ? project_selection.get_selected_item() as Project
                : null;
            project_id = project != null ? project.project_id : "";
        }
        var label = resource_label;
        if (label == null) {
            var selected = selected_resource();
            label = selected != null ? selected.label : "resource";
        }
        var result = yield controller.delete_resource_flow_scoped(api, resource_id, project_id, label);
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

    private async void choose_storage_folder(Gtk.Window root_window, Gtk.Entry path_entry) {
        try {
            var folder = yield file_picker.pick_folder(root_window, "Choose Storage Folder");
            if (folder != null && ((!) folder).get_path() != null) {
                path_entry.set_text((!) ((!) folder).get_path());
            }
        } catch (Error e) {
            if (!(e is IOError.CANCELLED)) {
                error_reported("Failed to choose folder", e.message);
            }
        }
    }

    private async void open_local_resource_picker(Gtk.Window root_window,
                                                  Gtk.Entry uri_entry,
                                                  Gtk.Entry? label_entry,
                                                  bool images_only) {
        try {
            var file = yield file_picker.pick_file(
                root_window, images_only ? "Choose Image" : "Choose File", images_only
            );
            if (file == null) {
                return;
            }
            var uri = ((!) file).get_uri();
            if (uri != null && uri.length > 0) {
                uri_entry.set_text(uri);
            }
            if (label_entry != null) {
                var picked_label = ResourcesPresenter.picked_file_label(
                    label_entry.get_text(), ((!) file).get_basename()
                );
                if (picked_label != null) {
                    label_entry.set_text((!) picked_label);
                }
            }
        } catch (Error e) {
            if (!(e is IOError.CANCELLED)) {
                error_reported("Failed to choose file", e.message);
            }
        }
    }
}

}
