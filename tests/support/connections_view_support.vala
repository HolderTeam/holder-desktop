using GLib;

namespace HolderLinuxTests {

public HolderLinux.Project cv_project(string id,
                                      string name,
                                      int root_card_count = 1,
                                      int64 updated_at = 1700000000) {
    return new HolderLinux.Project(
        id, name, "plain", "/tmp/%s".printf(id), 1, updated_at, null, null, root_card_count, root_card_count
    );
}

public HolderLinux.CardSummary cv_card(string id,
                                       string project_id,
                                       string title,
                                       double sort_key = 10,
                                       string? parent_card_id = null,
                                       int64 updated_at = 1700000000) {
    return new HolderLinux.CardSummary(
        id, project_id, title, "cards/%s.md".printf(id), sort_key, parent_card_id, 1, updated_at
    );
}

// String equality that reports both sides on failure, since a bare assert only shows the expression.
public bool cv_eq(string? actual, string? expected) {
    if (actual != expected) {
        stderr.printf("expected: [%s]\n  actual: [%s]\n", expected ?? "(null)", actual ?? "(null)");
        return false;
    }
    return true;
}

public HolderLinux.CardLink cv_link(string from_id, string to_id, string kind = "ref", string to_type = "card") {
    return new HolderLinux.CardLink(from_id, to_id, to_type, kind, null, 1);
}

public Gee.ArrayList<Gtk.Widget> cv_descendants(Gtk.Widget root) {
    var found = new Gee.ArrayList<Gtk.Widget>();
    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        found.add((!) child);
        found.add_all(cv_descendants((!) child));
        child = ((!) child).get_next_sibling();
    }
    return found;
}

public bool cv_inside_button(Gtk.Widget widget) {
    Gtk.Widget? parent = widget.get_parent();
    while (parent != null) {
        if (parent is Gtk.Button) {
            return true;
        }
        parent = ((!) parent).get_parent();
    }
    return false;
}

public Gee.ArrayList<Gtk.Button> cv_node_buttons(Gtk.Widget root) {
    var nodes = new Gee.ArrayList<Gtk.Button>();
    foreach (var widget in cv_descendants(root)) {
        var button = widget as Gtk.Button;
        if (button != null && ((!) button).has_css_class("connections-board-node")) {
            nodes.add((!) button);
        }
    }
    return nodes;
}

// The labels inside one board node, in tree order: title, then the meta line.
public Gee.ArrayList<string> cv_node_texts(Gtk.Button node) {
    var texts = new Gee.ArrayList<string>();
    foreach (var widget in cv_descendants(node)) {
        var label = widget as Gtk.Label;
        if (label != null) {
            texts.add(((!) label).get_text());
        }
    }
    return texts;
}

public Gee.ArrayList<string> cv_node_titles(Gtk.Widget root) {
    var titles = new Gee.ArrayList<string>();
    foreach (var node in cv_node_buttons(root)) {
        titles.add(cv_node_texts(node)[0]);
    }
    return titles;
}

public Gtk.Button cv_node(Gtk.Widget root, string title) {
    foreach (var node in cv_node_buttons(root)) {
        if (cv_node_texts(node)[0] == title) {
            return node;
        }
    }
    assert_not_reached();
}

// Labels with markup enabled, in tree order: structure, outgoing, incoming, internal.
public Gee.ArrayList<Gtk.Label> cv_markup_labels(Gtk.Widget root) {
    var labels = new Gee.ArrayList<Gtk.Label>();
    foreach (var widget in cv_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label != null && ((!) label).get_use_markup()) {
            labels.add((!) label);
        }
    }
    assert(labels.size == 4);
    return labels;
}

public Gtk.Label cv_structure_label(Gtk.Widget root) {
    return cv_markup_labels(root)[0];
}

public Gtk.Label cv_outgoing_label(Gtk.Widget root) {
    return cv_markup_labels(root)[1];
}

public Gtk.Label cv_backlinks_label(Gtk.Widget root) {
    return cv_markup_labels(root)[2];
}

public Gtk.Label cv_internal_label(Gtk.Widget root) {
    return cv_markup_labels(root)[3];
}

// The relations panel heading (a title-5 label that is not part of a board node).
public Gtk.Label cv_relations_title(Gtk.Widget root) {
    foreach (var widget in cv_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label != null && ((!) label).has_css_class("title-5") && !cv_inside_button((!) label)) {
            return (!) label;
        }
    }
    assert_not_reached();
}

// The centered hint shown over the board when there is nothing to draw.
public Gtk.Label cv_empty_label(Gtk.Widget root) {
    foreach (var widget in cv_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label != null && ((!) label).has_css_class("dim-label")
            && ((!) label).get_halign() == Gtk.Align.CENTER && !cv_inside_button((!) label)) {
            return (!) label;
        }
    }
    assert_not_reached();
}

public Gtk.DrawingArea cv_canvas(Gtk.Widget root) {
    foreach (var widget in cv_descendants(root)) {
        var canvas = widget as Gtk.DrawingArea;
        if (canvas != null) {
            return (!) canvas;
        }
    }
    assert_not_reached();
}

public Gtk.Fixed cv_nodes_layer(Gtk.Widget root) {
    foreach (var widget in cv_descendants(root)) {
        var layer = widget as Gtk.Fixed;
        if (layer != null) {
            return (!) layer;
        }
    }
    assert_not_reached();
}

public Gtk.ScrolledWindow cv_relations_scroller(Gtk.Widget root) {
    foreach (var widget in cv_descendants(root)) {
        var scroller = widget as Gtk.ScrolledWindow;
        if (scroller != null && ((!) scroller).get_min_content_width() == 320) {
            return (!) scroller;
        }
    }
    assert_not_reached();
}

public Gee.ArrayList<string> cv_dropdown_items(Gtk.DropDown dropdown) {
    var items = new Gee.ArrayList<string>();
    var model = dropdown.get_model() as Gtk.StringList;
    assert(model != null);
    for (uint i = 0; i < ((!) model).get_n_items(); i++) {
        items.add(((!) model).get_string(i));
    }
    return items;
}

// Finds the dropdown that follows a caption label in the add-link dialog, either directly or as
// the first child of the box that follows it.
public Gtk.DropDown cv_dropdown(Gtk.Widget root, string caption) {
    foreach (var widget in cv_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label == null || ((!) label).get_text() != caption) {
            continue;
        }
        var next = ((!) label).get_next_sibling();
        if (next is Gtk.DropDown) {
            return (Gtk.DropDown) next;
        }
        if (next != null) {
            var inner = ((!) next).get_first_child();
            if (inner is Gtk.DropDown) {
                return (Gtk.DropDown) inner;
            }
        }
    }
    assert_not_reached();
}

public Gtk.Button cv_button_labeled(Gtk.Widget root, string label) {
    foreach (var widget in cv_descendants(root)) {
        var button = widget as Gtk.Button;
        if (button != null && ((!) button).get_label() == label) {
            return (!) button;
        }
    }
    assert_not_reached();
}

public Gtk.Entry cv_entry(Gtk.Widget root, string placeholder) {
    foreach (var widget in cv_descendants(root)) {
        var entry = widget as Gtk.Entry;
        if (entry != null && ((!) entry).get_placeholder_text() == placeholder) {
            return (!) entry;
        }
    }
    assert_not_reached();
}

// Runs a label's activate-link signal the way a click on a link would, and reports whether a
// handler claimed it. A trailing blocker stops GTK's default handler (which would launch the URI in
// a real browser) from running when the view declines the link.
public class CvLinkProbe : Object {
    public int blocked { get; set; default = 0; }
}

public bool cv_activate_link(Gtk.Label label, string uri, CvLinkProbe probe) {
    ulong blocker = label.activate_link.connect((link) => {
        probe.blocked++;
        return true;
    });
    var before = probe.blocked;
    label.activate_link(uri);
    label.disconnect(blocker);
    // The blocker only runs when every earlier handler (the view's) declined the URI.
    return probe.blocked == before;
}

public Gtk.DrawingArea? cv_find_drawing_area(Gtk.Widget widget) {
    if (widget is Gtk.DrawingArea) {
        return (Gtk.DrawingArea) widget;
    }
    for (var child = widget.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        var found = cv_find_drawing_area((!) child);
        if (found != null) {
            return found;
        }
    }
    return null;
}

// Renders the widget's own drawing (a Gtk.DrawingArea's draw function runs from snapshot()) into an
// image and counts the pixels that are not fully transparent.
public int cv_drawn_pixels(Gtk.DrawingArea canvas, int width, int height) {
    canvas.allocate(width, height, -1, null);
    var snapshot = new Gtk.Snapshot();
    canvas.snapshot(snapshot);
    var node = snapshot.to_node();
    if (node == null) {
        return 0;
    }
    var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, width, height);
    var cr = new Cairo.Context(surface);
    ((!) node).draw(cr);
    surface.flush();
    unowned uint8[] data = surface.get_data();
    int drawn = 0;
    int stride = surface.get_stride();
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            if (data[y * stride + x * 4 + 3] != 0) {
                drawn++;
            }
        }
    }
    return drawn;
}

public Gtk.Paned? cv_find_paned(Gtk.Widget widget) {
    if (widget is Gtk.Paned) {
        return (Gtk.Paned) widget;
    }
    for (var child = widget.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        var found = cv_find_paned((!) child);
        if (found != null) {
            return found;
        }
    }
    return null;
}

// Hosts a ConnectionsToolView in a real (never presented) Adw.Window so dialogs have a root to
// attach to, and records everything the view reports.
public class ConnectionsViewHarness : Object {
    public MainControllerFakeApi api = new MainControllerFakeApi();
    // The view schedules its graph refresh debounce and the empty-state check here instead of on
    // real timers; wait() fires the debounce, tests fire the empty-state check explicitly.
    public TestScheduler scheduler = new TestScheduler();
    public HolderLinux.ConnectionsToolView view;
    public Adw.Window window = new Adw.Window();
    public GLib.ListStore project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    public GLib.ListStore card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    public Gtk.SingleSelection projects;
    public Gtk.SingleSelection cards;
    public Gee.ArrayList<string> toasts = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> errors = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> logs = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> card_opens = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> project_overviews = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> child_requests = new Gee.ArrayList<string>();
    public int projects_root_requests { get; set; default = 0; }

    public ConnectionsViewHarness() {
        view = new HolderLinux.ConnectionsToolView(scheduler);
        projects = new Gtk.SingleSelection(project_store);
        cards = new Gtk.SingleSelection(card_store);
        // No card selected unless a test asks for one: a default SingleSelection would autoselect.
        cards.set_autoselect(false);
        cards.set_can_unselect(true);
        view.toast_requested.connect((message) => { toasts.add(message); });
        view.error_reported.connect((title, details) => { errors.add("%s|%s".printf(title, details)); });
        view.debug_log_requested.connect((line) => { logs.add(line); });
        view.card_open_requested.connect((card_id) => { card_opens.add(card_id); });
        view.project_overview_requested.connect((project_id) => { project_overviews.add(project_id); });
        view.card_create_child_requested.connect((card_id) => { child_requests.add(card_id); });
        view.projects_root_requested.connect(() => { projects_root_requests++; });
        window.set_content(view.widget);
    }

    // Binds the selection models and shows the tool, which triggers the first refresh.
    public void start(bool with_api = true) {
        if (with_api) {
            view.set_api_client(api);
        }
        view.bind_context(projects, card_store, cards);
        view.set_tool_visible(true);
    }

    public Gtk.Widget content() {
        return view.get_content_widget();
    }

    // Like wait_for_condition, but fires the pending refresh debounce on every poll. The longer
    // empty-state check is left alone so a test decides when it is due.
    public bool wait(ConditionFunc condition, uint timeout_ms = 1500) {
        return wait_for_condition(() => {
            fire_debounce();
            return condition();
        }, timeout_ms);
    }

    public int fire_debounce() {
        return scheduler.run_due(HolderLinux.ConnectionsRefreshPlanner.GRAPH_REFRESH_DEBOUNCE_MS);
    }

    public int fire_empty_state_check() {
        return scheduler.run_due(HolderLinux.ConnectionsRefreshPlanner.PROJECT_EMPTY_STATE_DELAY_MS);
    }

    public bool wait_for_nodes(uint count) {
        return wait(() => cv_node_buttons(content()).size == count);
    }

    public bool wait_for_empty_text(string text) {
        return wait(() => {
            var label = cv_empty_label(content());
            return label.get_visible() && label.get_text() == text;
        });
    }

    public bool wait_for_structure(string text) {
        return wait(() => cv_structure_label(content()).get_text().contains(text));
    }

    public bool wait_for_log(string needle) {
        return wait(() => {
            foreach (var line in logs) {
                if (line.contains(needle)) {
                    return true;
                }
            }
            return false;
        });
    }

    public Adw.AlertDialog? dialog() {
        return window.get_visible_dialog() as Adw.AlertDialog;
    }

    public bool wait_for_dialog() {
        return wait(() => dialog() != null);
    }

    // Runs the main loop until idle, flushing anything a response queued.
    public void settle() {
        while (MainContext.default().iteration(false)) {}
    }

    // Lets everything the view has queued finish without advancing time: fires the refresh
    // debounce and runs the main loop until idle, repeatedly, until no refresh is left. The
    // empty-state check is not fired.
    public void drain() {
        for (int i = 0; i < 50; i++) {
            var fired = fire_debounce();
            settle();
            if (fired == 0 && scheduler.pending_with_delay(HolderLinux.ConnectionsRefreshPlanner.GRAPH_REFRESH_DEBOUNCE_MS) == 0) {
                return;
            }
        }
        assert_not_reached();
    }

    public Gtk.Button add_button() {
        var actions = view.get_actions_widget();
        assert(actions != null);
        foreach (var widget in cv_descendants((!) actions)) {
            var button = widget as Gtk.Button;
            if (button != null && ((!) button).get_tooltip_text() == "Add graph connection") {
                return (!) button;
            }
        }
        assert_not_reached();
    }

    public Gtk.ToggleButton relations_toggle() {
        var actions = view.get_actions_widget();
        assert(actions != null);
        foreach (var widget in cv_descendants((!) actions)) {
            var toggle = widget as Gtk.ToggleButton;
            if (toggle != null) {
                return (!) toggle;
            }
        }
        assert_not_reached();
    }
}

public delegate void ConnectionsHarnessBody(ConnectionsViewHarness harness);

}
