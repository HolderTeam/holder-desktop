using GLib;

namespace HolderLinuxTests {

// IHolderApi + IResourceStorageApi in one object, as the real ApiClient is. The resources view
// casts its api to IResourceStorageApi for everything storage related.
public class ResourcesViewFakeApi : MainControllerFakeApi, HolderLinux.IResourceStorageApi {
    public FakeStorageLocationApi storage = new FakeStorageLocationApi();
    public bool stall_next_list = false;
    private SourceFunc? stalled_list = null;

    public bool has_stalled_list() {
        return stalled_list != null;
    }

    public void release_stalled_list() {
        if (stalled_list != null) {
            var resume = (owned) stalled_list;
            stalled_list = null;
            resume();
        }
    }

    public async HolderLinux.StorageLocationList list_storage_locations(string project_id) throws Error {
        if (stall_next_list) {
            stall_next_list = false;
            stalled_list = list_storage_locations.callback;
            yield;
        }
        return yield storage.list_storage_locations(project_id);
    }

    public async string create_storage_location(string project_id, string name, string provider,
                                                Gee.HashMap<string, string> configuration) throws Error {
        return yield storage.create_storage_location(project_id, name, provider, configuration);
    }

    public async void bind_storage_location(string location_id, Gee.HashMap<string, string> values,
                                            string preview) throws Error {
        yield storage.bind_storage_location(location_id, values, preview);
    }

    public async void prefer_storage_location(string project_id, string location_id) throws Error {
        yield storage.prefer_storage_location(project_id, location_id);
    }

    public async void test_storage_location(string location_id) throws Error {
        yield storage.test_storage_location(location_id);
    }

    public async void delete_storage_location(string location_id) throws Error {
        yield storage.delete_storage_location(location_id);
    }

    public async string start_google_drive_oauth(string location_id) throws Error {
        return yield storage.start_google_drive_oauth(location_id);
    }

    public async HolderLinux.AssetImportJob start_asset_import(string project_id, string card_id,
                                                               string location_id,
                                                               string source_path) throws Error {
        return yield storage.start_asset_import(project_id, card_id, location_id, source_path);
    }

    public async HolderLinux.AssetImportJob get_asset_import_job(string job_id) throws Error {
        return yield storage.get_asset_import_job(job_id);
    }

    public async void download_asset(string resource_id, string asset_id, string destination_path) throws Error {
        yield storage.download_asset(resource_id, asset_id, destination_path);
    }
}

// Records what the view asks the desktop to open, and can be told to refuse.
public class RvFakeUriLauncher : Object, HolderLinux.IUriLauncher {
    public Gee.ArrayList<string> launched = new Gee.ArrayList<string>();
    public string? error = null;

    public void launch(string uri) throws Error {
        if (error != null) {
            throw new IOError.FAILED((!) error);
        }
        launched.add(uri);
    }
}

// Answers the view's file and folder questions without a real chooser. Set `choice` to what the
// user "picked", `cancel` to dismiss the chooser, or `error` to make it fail.
public class RvFakeFilePicker : Object, HolderLinux.IFilePicker {
    public File? choice = null;
    public bool cancel = false;
    public string? error = null;
    public Gee.ArrayList<string> requests = new Gee.ArrayList<string>();

    public async File? pick_folder(Gtk.Window parent, string title) throws Error {
        requests.add("folder|" + title);
        return answer();
    }

    public async File? pick_file(Gtk.Window parent, string title, bool images_only) throws Error {
        requests.add("file|%s|%s".printf(title, images_only ? "images" : "any"));
        return answer();
    }

    private File? answer() throws Error {
        if (cancel) {
            throw new IOError.CANCELLED("Dismissed by user");
        }
        if (error != null) {
            throw new IOError.FAILED((!) error);
        }
        return choice;
    }
}

public Gtk.SingleSelection rv_project_selection() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    store.append(new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 10, 10));
    store.append(new HolderLinux.Project("p2", "Project 2", "encrypted_git", "/tmp/p2", 11, 11));
    var selection = new Gtk.SingleSelection(store);
    selection.set_selected(0);
    return selection;
}

public HolderLinux.ProjectResource rv_resource(string id,
                                               string kind,
                                               string uri,
                                               string label,
                                               string? desc = null,
                                               Gee.HashMap<string, Gee.ArrayList<string>>? metadata = null,
                                               Gee.ArrayList<HolderLinux.ResourceAsset>? assets = null,
                                               Gee.ArrayList<HolderLinux.ResourceCardReference>? references = null) {
    return new HolderLinux.ProjectResource(
        id, "p1", kind, uri, label, desc, 1700000000, 1700000100, metadata, assets, references
    );
}

// Hosts a ResourcesToolView in a real (never presented) Adw.Window so dialogs have a root to attach
// to, and records everything the view reports.
public class ResourcesViewHarness : Object {
    public ResourcesViewFakeApi api = new ResourcesViewFakeApi();
    public HolderLinux.ResourcesToolView view;
    public RvFakeUriLauncher launcher = new RvFakeUriLauncher();
    public RvFakeFilePicker picker = new RvFakeFilePicker();
    public TestScheduler scheduler = new TestScheduler();
    public Adw.Window window = new Adw.Window();
    public Gtk.SingleSelection? projects = null;
    public Gee.ArrayList<string> toasts = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> errors = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> previews = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> card_opens = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> reference_requests = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> loaded_projects = new Gee.ArrayList<string>();
    public int activity_count { get; set; default = 0; }
    // Every activity the view asked to log, as "kind|message|project_id|resource_id".
    public Gee.ArrayList<string> activities = new Gee.ArrayList<string>();

    // The view gets fakes for everything it would otherwise hand to the desktop: the browser, the
    // 1 s polling timer and the file chooser.
    public ResourcesViewHarness(bool with_project = true, bool attach_window = true) {
        view = new HolderLinux.ResourcesToolView(launcher, scheduler, picker);
        view.toast_requested.connect((message) => { toasts.add(message); });
        view.error_reported.connect((title, details) => { errors.add("%s|%s".printf(title, details)); });
        view.asset_preview_requested.connect((resource, asset) => {
            previews.add("%s|%s".printf(resource.resource_id, asset.asset_id));
        });
        view.card_open_requested.connect((card_id) => { card_opens.add(card_id); });
        view.resource_references_requested.connect((resource) => { reference_requests.add(resource.resource_id); });
        view.project_resources_loaded.connect((project_id, resources) => { loaded_projects.add(project_id); });
        view.activity_requested.connect((kind, message, project_id, resource_id, details) => {
            activity_count++;
            activities.add("%s|%s|%s|%s".printf(kind, message, project_id ?? "(none)", resource_id ?? "(none)"));
        });
        if (attach_window) {
            window.set_content(view.widget);
        }
        view.set_api_client(api);
        if (with_project) {
            projects = rv_project_selection();
            view.set_project_selection(projects);
        }
    }

    public bool wait_for_resources(uint count) {
        return wait_for_condition(() => rv_item_count(view) == count);
    }

    public bool wait_for_locations_refresh() {
        return wait_for_condition(() => api.storage.list_calls > 0);
    }

    public bool wait_for_toast(string message) {
        return wait_for_condition(() => toasts.contains(message));
    }

    public Adw.AlertDialog? dialog() {
        return window.get_visible_dialog() as Adw.AlertDialog;
    }

    public bool wait_for_dialog() {
        return wait_for_condition(() => dialog() != null);
    }

    // Whether a closed dialog is removed from the window is libadwaita's own bookkeeping, and with
    // libadwaita 1.5 it never completes for a window that is not shown, so tests assert on what the
    // view did instead. Running the main loop until idle flushes anything a response queued.
    public void settle() {
        while (MainContext.default().iteration(false)) {}
    }

    public Gtk.Widget actions() {
        var actions = view.get_actions_widget();
        assert(actions != null);
        return (!) actions;
    }
}

public Gee.ArrayList<Gtk.Widget> rv_descendants(Gtk.Widget root) {
    var found = new Gee.ArrayList<Gtk.Widget>();
    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        found.add((!) child);
        found.add_all(rv_descendants((!) child));
        child = ((!) child).get_next_sibling();
    }
    return found;
}

public Gtk.Button? rv_button_labeled(Gtk.Widget root, string label) {
    foreach (var widget in rv_descendants(root)) {
        var button = widget as Gtk.Button;
        if (button != null && ((!) button).get_label() == label) {
            return button;
        }
    }
    return null;
}

public Gee.ArrayList<Gtk.Button> rv_buttons_with_tooltip(Gtk.Widget root, string tooltip) {
    var found = new Gee.ArrayList<Gtk.Button>();
    foreach (var widget in rv_descendants(root)) {
        var button = widget as Gtk.Button;
        if (button != null && ((!) button).get_tooltip_text() == tooltip) {
            found.add((!) button);
        }
    }
    return found;
}

public Gtk.Button rv_button(Gtk.Widget root, string label) {
    var button = rv_button_labeled(root, label);
    assert(button != null);
    return (!) button;
}

public Gtk.Button rv_tooltip_button(Gtk.Widget root, string tooltip, int index = 0) {
    var buttons = rv_buttons_with_tooltip(root, tooltip);
    assert(index < buttons.size);
    return buttons[index];
}

public Gtk.Entry rv_entry(Gtk.Widget root, string placeholder) {
    foreach (var widget in rv_descendants(root)) {
        var entry = widget as Gtk.Entry;
        if (entry != null && ((!) entry).get_placeholder_text() == placeholder) {
            return (!) entry;
        }
    }
    assert_not_reached();
}

public Gtk.Entry rv_entry_after_label(Gtk.Widget root, string label_text) {
    // Entries without a placeholder (label, description) follow their caption label in the box.
    Gtk.Widget? sibling = null;
    foreach (var widget in rv_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label != null && ((!) label).get_text() == label_text) {
            sibling = ((!) label).get_next_sibling();
            break;
        }
    }
    assert(sibling != null);
    return (Gtk.Entry) sibling;
}

public Gee.ArrayList<string> rv_label_texts(Gtk.Widget root) {
    var texts = new Gee.ArrayList<string>();
    foreach (var widget in rv_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label != null) {
            texts.add(((!) label).get_text());
        }
    }
    return texts;
}

public Gtk.Label? rv_named_label(Gtk.Widget root, string name) {
    foreach (var widget in rv_descendants(root)) {
        if (widget is Gtk.Label && widget.get_name() == name) {
            return (Gtk.Label) widget;
        }
    }
    return null;
}

public Gtk.DropDown rv_dropdown(Gtk.Widget root) {
    foreach (var widget in rv_descendants(root)) {
        if (widget is Gtk.DropDown) {
            return (Gtk.DropDown) widget;
        }
    }
    assert_not_reached();
}

// The details TextView lives in a collapsed Gtk.Expander, which only parents its child while
// expanded, so reach it through the expander rather than by walking widgets.
public Gtk.TextView rv_text_view(Gtk.Widget root) {
    foreach (var widget in rv_descendants(root)) {
        var expander = widget as Gtk.Expander;
        if (expander != null) {
            var scroller = ((!) expander).get_child() as Gtk.ScrolledWindow;
            assert(scroller != null);
            var view = ((!) scroller).get_child() as Gtk.TextView;
            assert(view != null);
            return (!) view;
        }
    }
    assert_not_reached();
}

public Gtk.ColumnView rv_column_view(HolderLinux.ResourcesToolView view) {
    foreach (var widget in rv_descendants(view.widget)) {
        if (widget is Gtk.ColumnView) {
            return (Gtk.ColumnView) widget;
        }
    }
    assert_not_reached();
}

public uint rv_item_count(HolderLinux.ResourcesToolView view) {
    var model = rv_column_view(view).get_model();
    assert(model != null);
    return ((!) model).get_n_items();
}

public Gtk.SingleSelection rv_selection(HolderLinux.ResourcesToolView view) {
    var selection = rv_column_view(view).get_model() as Gtk.SingleSelection;
    assert(selection != null);
    return (!) selection;
}

public string? rv_selected_id(HolderLinux.ResourcesToolView view) {
    var selected = rv_selection(view).get_selected_item() as HolderLinux.ProjectResource;
    return selected != null ? ((!) selected).resource_id : null;
}

public string rv_text_of(Gtk.TextView view) {
    Gtk.TextIter start;
    Gtk.TextIter end;
    view.get_buffer().get_bounds(out start, out end);
    return view.get_buffer().get_text(start, end, false);
}

// Gtk.ColumnView only creates row widgets when it is allocated. The harness window is never
// presented, so give the list a size explicitly.
public void rv_allocate(Gtk.Widget widget, int width = 900, int height = 700) {
    int minimum;
    int natural;
    widget.measure(Gtk.Orientation.VERTICAL, width, out minimum, out natural, null, null);
    widget.allocate(width, int.max(height, minimum), -1, null);
}

}
