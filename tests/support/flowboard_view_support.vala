using GLib;

namespace HolderLinuxTests {

// ---------------------------------------------------------------------------------------------
// Helpers shared by the flowboard pane and tool view tests.
// ---------------------------------------------------------------------------------------------

public HolderLinux.FlowboardTile fv_tile(string id,
                                         string title = "",
                                         bool container = false,
                                         string? parent = null,
                                         int sibling_count = 1,
                                         int sibling_index = 0,
                                         int64 updated_at = 100) {
    return new HolderLinux.FlowboardTile(
        "card:%s".printf(id),
        title.length > 0 ? title : "Card %s".printf(id),
        updated_at,
        container,
        id,
        null,
        parent,
        sibling_count,
        sibling_index,
        container ? 2 : 0
    );
}

public HolderLinux.FlowboardTile fv_project_tile(string id, string name) {
    return new HolderLinux.FlowboardTile(
        "project:%s".printf(id),
        name,
        100,
        true,
        null,
        id,
        null,
        0,
        0,
        1
    );
}

public string fv_join(Gee.ArrayList<string> parts, string separator = "|") {
    var joined = new StringBuilder();
    bool first = true;
    foreach (var part in parts) {
        if (!first) {
            joined.append(separator);
        }
        joined.append(part);
        first = false;
    }
    return joined.str;
}

// Tests that show a window and click inside it are only run on Linux, where a display is a given
// in CI; other platforms have to realise real surfaces for it.
public bool fv_skip_unless_linux() {
    if (Environment.get_variable("HOLDER_DESKTOP_TEST_PLATFORM") != "linux") {
        Test.skip("needs a mapped window, which is only exercised on Linux");
        return true;
    }
    return false;
}

public bool fv_skip_popover_tests() {
    if (Environment.get_variable("HOLDER_DESKTOP_TEST_PLATFORM") == "darwin") {
        // A popover realises a native surface on macOS, and GDK's macOS backend then warns
        // "gdk_frame_timings_presented() called on skipped frame", which GLib's test harness turns
        // into a fatal SIGTRAP.
        Test.skip("popovers create native surfaces on macOS, where GDK's frame warning is fatal");
        return true;
    }
    return false;
}

public Gtk.Widget? fv_find_type(Gtk.Widget root, Type type) {
    if (root.get_type().is_a(type)) {
        return root;
    }
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        var match = fv_find_type((!) child, type);
        if (match != null) {
            return match;
        }
    }
    return null;
}

public void fv_collect_rows(Gtk.Widget root, Gee.ArrayList<Gtk.Widget> rows) {
    if (root.has_css_class("flowboard-tile")) {
        rows.add(root);
    }
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        fv_collect_rows((!) child, rows);
    }
}

public Gee.ArrayList<Gtk.Widget> fv_rows(Gtk.Widget root) {
    var rows = new Gee.ArrayList<Gtk.Widget>();
    fv_collect_rows(root, rows);
    return rows;
}

// The tile widget currently bound to a card (list items are recycled, so match on the bound id).
public Gtk.Widget? fv_row_for_card(Gtk.Widget root, string card_id) {
    foreach (var row in fv_rows(root)) {
        if (row.get_data<string>("flowboard-card-id") == card_id) {
            return row;
        }
    }
    return null;
}

public Gtk.Label fv_title_label(Gtk.Widget row) {
    var label = row.get_data<Gtk.Label>("flowboard-title-label");
    assert(label != null);
    return (!) label;
}

public Gtk.Label fv_meta_label(Gtk.Widget row) {
    var label = row.get_data<Gtk.Label>("flowboard-meta-label");
    assert(label != null);
    return (!) label;
}

public Gtk.DropTarget fv_drop_target(Gtk.Widget widget) {
    var controllers = widget.observe_controllers();
    for (uint i = 0; i < controllers.get_n_items(); i++) {
        var target = controllers.get_item(i) as Gtk.DropTarget;
        if (target != null) {
            return (!) target;
        }
    }
    assert_not_reached();
}

public Gtk.DragSource fv_drag_source(Gtk.Widget widget) {
    var controllers = widget.observe_controllers();
    for (uint i = 0; i < controllers.get_n_items(); i++) {
        var source = controllers.get_item(i) as Gtk.DragSource;
        if (source != null) {
            return (!) source;
        }
    }
    assert_not_reached();
}

public Gtk.EventControllerKey fv_key_controller(Gtk.Widget widget) {
    var controllers = widget.observe_controllers();
    for (uint i = 0; i < controllers.get_n_items(); i++) {
        var keys = controllers.get_item(i) as Gtk.EventControllerKey;
        if (keys != null) {
            return (!) keys;
        }
    }
    assert_not_reached();
}

public Gtk.GestureClick fv_click(Gtk.Widget widget, uint button) {
    var controllers = widget.observe_controllers();
    for (uint i = 0; i < controllers.get_n_items(); i++) {
        var click = controllers.get_item(i) as Gtk.GestureClick;
        if (click != null && ((!) click).get_button() == button) {
            return (!) click;
        }
    }
    assert_not_reached();
}

public Value fv_string_value(string text) {
    Value value = Value(typeof(string));
    value.set_string(text);
    return value;
}

public int fv_popover_count(Gtk.Widget widget) {
    int count = 0;
    for (var child = widget.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        if (child is Gtk.Popover) {
            count++;
        }
    }
    return count;
}

public Gtk.Popover? fv_popover(Gtk.Widget widget) {
    for (var child = widget.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        if (child is Gtk.Popover) {
            return (Gtk.Popover) child;
        }
    }
    return null;
}

public void fv_buttons(Gtk.Widget root, Gee.ArrayList<Gtk.Button> buttons) {
    var button = root as Gtk.Button;
    if (button != null) {
        buttons.add((!) button);
    }
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        fv_buttons((!) child, buttons);
    }
}

public Gtk.Button fv_button_labeled(Gtk.Widget root, string label) {
    var buttons = new Gee.ArrayList<Gtk.Button>();
    fv_buttons(root, buttons);
    foreach (var button in buttons) {
        if (button.get_label() == label) {
            return button;
        }
    }
    assert_not_reached();
}

public Gee.ArrayList<string> fv_button_labels(Gtk.Widget root) {
    var buttons = new Gee.ArrayList<Gtk.Button>();
    fv_buttons(root, buttons);
    var labels = new Gee.ArrayList<string>();
    foreach (var button in buttons) {
        labels.add(button.get_label() ?? "");
    }
    return labels;
}

public void fv_settle() {
    var context = MainContext.default();
    for (int i = 0; i < 20; i++) {
        while (context.iteration(false)) {}
    }
}

// ---------------------------------------------------------------------------------------------
// FlowboardPane in an (unpresented) window, recording every signal it emits.
// ---------------------------------------------------------------------------------------------

public class FlowboardPaneHarness : Object {
    public HolderLinux.FlowboardPane pane = new HolderLinux.FlowboardPane();
    public GLib.ListStore store = new GLib.ListStore(typeof(HolderLinux.FlowboardTile));
    public Adw.Window window = new Adw.Window();
    public Gee.ArrayList<string> events = new Gee.ArrayList<string>();

    public FlowboardPaneHarness() {
        window.set_default_size(800, 600);
        window.set_content(pane.widget);
        pane.set_model(store);

        pane.tile_activated.connect((position) => { events.add("activated:%u".printf(position)); });
        pane.navigate_up_requested.connect(() => { events.add("up"); });
        pane.card_drop_requested.connect((source, target, fraction) => {
            events.add("drop:%s>%s@%.2f".printf(source, target, fraction));
        });
        pane.background_drop_requested.connect((source) => { events.add("background-drop:%s".printf(source)); });
        pane.background_new_card_requested.connect(() => { events.add("background-new"); });
        pane.card_open_requested.connect((id) => { events.add("open:%s".printf(id)); });
        pane.card_create_child_requested.connect((id) => { events.add("child:%s".printf(id)); });
        pane.card_move_to_trash_requested.connect((id) => { events.add("trash:%s".printf(id)); });
        pane.card_move_up_level_requested.connect((id) => { events.add("up-level:%s".printf(id)); });
        pane.card_move_left_requested.connect((id) => { events.add("left:%s".printf(id)); });
        pane.card_move_right_requested.connect((id) => { events.add("right:%s".printf(id)); });
        pane.card_move_to_start_requested.connect((id) => { events.add("start:%s".printf(id)); });
        pane.card_move_to_end_requested.connect((id) => { events.add("end:%s".printf(id)); });
    }

    public void add(HolderLinux.FlowboardTile tile) {
        store.append(tile);
        fv_settle();
    }

    public string log() {
        return fv_join(events);
    }

    public Gtk.GridView grid() {
        var grid = fv_find_type(pane.widget, typeof(Gtk.GridView)) as Gtk.GridView;
        assert(grid != null);
        return (!) grid;
    }

    public Gtk.Stack stack() {
        var found = fv_find_type(pane.widget, typeof(Gtk.Stack)) as Gtk.Stack;
        assert(found != null);
        return (!) found;
    }

    public Gtk.SelectionModel selection() {
        var model = grid().get_model() as Gtk.SelectionModel;
        assert(model != null);
        return (!) model;
    }

    public Gtk.Widget row(string card_id) {
        var found = fv_row_for_card(pane.widget, card_id);
        assert(found != null);
        return (!) found;
    }

    // Picking only finds mapped widgets, so a click can only land on a tile once the window is shown.
    // Returns the centre of the tile for `card_id` in grid coordinates; call destroy_window() after.
    public Graphene.Point present_and_centre_of(string card_id) {
        window.present();
        for (int i = 0; i < 400 && !grid().get_mapped(); i++) {
            fv_settle();
            Thread.usleep(5000);
        }
        assert(grid().get_mapped());
        fv_settle();
        var target = row(card_id);
        Graphene.Rect bounds;
        assert(target.compute_bounds(grid(), out bounds));
        assert(bounds.get_width() > 0.0f && bounds.get_height() > 0.0f);
        var centre = Graphene.Point();
        centre.x = bounds.get_x() + bounds.get_width() / 2.0f;
        centre.y = bounds.get_y() + bounds.get_height() / 2.0f;
        return centre;
    }

    public void destroy_window() {
        window.destroy();
        fv_settle();
    }

    // A project tile (no card id): its bound card id is the empty string.
    public Gtk.Widget row_without_card() {
        var found = fv_row_for_card(pane.widget, "");
        assert(found != null);
        return (!) found;
    }

    // Unpresented tiles have no width, so give one an allocation the drop hints can measure.
    public Gtk.Widget sized_row(string card_id, int width = 200) {
        var found = row(card_id);
        found.allocate(width, 80, -1, null);
        assert(found.get_width() > 0);
        return found;
    }

    public bool has_drop_hint(Gtk.Widget row, string kind) {
        return row.has_css_class("flowboard-drop-%s".printf(kind));
    }
}

// ---------------------------------------------------------------------------------------------
// FlowboardToolView bound to a real FlowboardController fed from list stores.
// ---------------------------------------------------------------------------------------------

private string? fv_normalize(string? id) {
    if (id == null) {
        return null;
    }
    var trimmed = ((!) id).strip();
    return trimmed.length == 0 ? null : trimmed;
}

private HolderLinux.CardSummary? fv_find_card(GLib.ListStore cards, string card_id) {
    for (uint i = 0; i < cards.get_n_items(); i++) {
        var card = cards.get_item(i) as HolderLinux.CardSummary;
        if (card != null && ((!) card).card_id == card_id) {
            return card;
        }
    }
    return null;
}

private int fv_child_count(GLib.ListStore cards, string card_id) {
    int count = 0;
    for (uint i = 0; i < cards.get_n_items(); i++) {
        var card = cards.get_item(i) as HolderLinux.CardSummary;
        if (card != null && fv_normalize(((!) card).parent_card_id) == card_id) {
            count++;
        }
    }
    return count;
}

public HolderLinux.CardContextData fv_build_context(GLib.ListStore projects,
                                                    GLib.ListStore cards,
                                                    string project_id,
                                                    string? parent_card_id) {
    string project_name = project_id;
    for (uint i = 0; i < projects.get_n_items(); i++) {
        var project = projects.get_item(i) as HolderLinux.Project;
        if (project != null && ((!) project).project_id == project_id) {
            project_name = ((!) project).name;
            break;
        }
    }

    var breadcrumbs = new Gee.ArrayList<HolderLinux.CardContextBreadcrumb>();
    breadcrumbs.add(new HolderLinux.CardContextBreadcrumb("project", project_name, project_id, null));

    var chain = new Gee.ArrayList<HolderLinux.CardSummary>();
    var cursor = fv_normalize(parent_card_id);
    int guard = 0;
    while (cursor != null && guard < 256) {
        var card = fv_find_card(cards, (!) cursor);
        if (card == null) {
            break;
        }
        chain.add((!) card);
        cursor = fv_normalize(((!) card).parent_card_id);
        guard++;
    }
    for (int i = chain.size - 1; i >= 0; i--) {
        breadcrumbs.add(new HolderLinux.CardContextBreadcrumb("card", chain[i].title, null, chain[i].card_id));
    }

    var context_cards = new Gee.ArrayList<HolderLinux.CardContextCard>();
    for (uint i = 0; i < cards.get_n_items(); i++) {
        var card = cards.get_item(i) as HolderLinux.CardSummary;
        if (card == null || ((!) card).project_id != project_id) {
            continue;
        }
        if (fv_normalize(((!) card).parent_card_id) != fv_normalize(parent_card_id)) {
            continue;
        }
        context_cards.add(new HolderLinux.CardContextCard(
            ((!) card).card_id,
            ((!) card).project_id,
            ((!) card).title,
            ((!) card).rel_path,
            ((!) card).sort_key,
            ((!) card).parent_card_id,
            ((!) card).created_at,
            ((!) card).updated_at,
            fv_child_count(cards, ((!) card).card_id)
        ));
    }

    return new HolderLinux.CardContextData(
        new HolderLinux.CardContextProject(project_id, project_name),
        fv_normalize(parent_card_id),
        breadcrumbs,
        context_cards
    );
}

public HolderLinux.CardSummary fv_card(string id,
                                       string project_id,
                                       string title,
                                       double sort_key,
                                       string? parent_id = null,
                                       int64 updated_at = 100) {
    return new HolderLinux.CardSummary(id, project_id, title, "%s.md".printf(id), sort_key, parent_id, 0, updated_at);
}

public HolderLinux.Project fv_project(string id, string name) {
    return new HolderLinux.Project(id, name, "encrypted_git", "/tmp/%s".printf(id), 0, 10, null, null, 0, 0);
}

public class FvPendingContext : Object {
    public HolderLinux.FlowboardController controller { get; construct; }
    public string project_id { get; construct; }
    public string? parent_card_id { get; construct; }
    public HolderLinux.CardContextData context { get; construct; }

    public FvPendingContext(HolderLinux.FlowboardController controller,
                            string project_id,
                            string? parent_card_id,
                            HolderLinux.CardContextData context) {
        Object(controller: controller, project_id: project_id, parent_card_id: parent_card_id, context: context);
    }
}

public class FlowboardToolViewHarness : Object {
    public GLib.ListStore projects = new GLib.ListStore(typeof(HolderLinux.Project));
    public GLib.ListStore cards = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    public Gtk.SingleSelection project_selection;
    public HolderLinux.FlowboardController controller;
    public HolderLinux.FlowboardToolView view = new HolderLinux.FlowboardToolView();
    public Adw.Window window = new Adw.Window();
    public Gee.ArrayList<string> events = new Gee.ArrayList<string>();
    public int context_requests = 0;
    // While true, context loads are queued instead of applied, like a slow backend answering late.
    public bool hold_contexts { get; set; default = false; }
    public Gee.ArrayList<FvPendingContext> pending = new Gee.ArrayList<FvPendingContext>();

    // Two projects and a small tree: Alpha { Leaf, Folder { Inner } }, Beta.
    public FlowboardToolViewHarness(bool bind = true) {
        project_selection = new Gtk.SingleSelection(projects);
        projects.append(fv_project("p1", "Project One"));
        projects.append(fv_project("p2", "Project Two"));
        cards.append(fv_card("a", "p1", "Alpha", 1024.0));
        cards.append(fv_card("b", "p1", "Bravo", 2048.0));
        cards.append(fv_card("f", "p1", "Folder", 3072.0));
        cards.append(fv_card("i", "p1", "Inner", 1024.0, "f"));
        cards.append(fv_card("z", "p2", "Zulu", 1024.0));
        project_selection.set_selected(0);

        controller = make_controller();
        window.set_default_size(800, 600);
        window.set_content(view.widget);

        view.card_open_requested.connect((id) => { events.add("open:%s".printf(id)); });
        view.card_move_to_trash_requested.connect((id) => { events.add("trash:%s".printf(id)); });
        view.move_intent_requested.connect((id, project_id, intent, target, parent) => {
            events.add("move:%s:%s:%s:%s:%s".printf(id, project_id, intent, target ?? "-", parent ?? "-"));
        });
        view.new_card_requested.connect((parent) => { events.add("new:%s".printf(parent ?? "-")); });
        view.toast_requested.connect((message) => { events.add("toast:%s".printf(message)); });

        if (bind) {
            view.bind_controller(controller);
            fv_settle();
        }
    }

    // A controller over the same stores that answers context requests from them, like the window.
    public HolderLinux.FlowboardController make_controller() {
        var created = new HolderLinux.FlowboardController(projects, project_selection, cards);
        created.context_load_requested.connect((project_id, parent_card_id) => {
            context_requests++;
            var context = fv_build_context(projects, cards, project_id, parent_card_id);
            if (hold_contexts) {
                pending.add(new FvPendingContext(created, project_id, parent_card_id, context));
                return;
            }
            created.apply_card_context(project_id, parent_card_id, context);
        });
        return created;
    }

    // Answers every queued context load, oldest first.
    public void release_contexts() {
        var answers = new Gee.ArrayList<FvPendingContext>();
        answers.add_all(pending);
        pending.clear();
        foreach (var answer in answers) {
            answer.controller.apply_card_context(answer.project_id, answer.parent_card_id, answer.context);
        }
        fv_settle();
    }

    public void select_project(uint position) {
        project_selection.set_selected(position);
        controller.refresh();
        fv_settle();
    }

    public string log() {
        return fv_join(events);
    }

    public Gtk.Widget content() {
        return view.get_content_widget();
    }

    public Gtk.Widget row(string card_id) {
        var found = fv_row_for_card(content(), card_id);
        assert(found != null);
        return (!) found;
    }

    public int row_count() {
        return fv_rows(content()).size;
    }

    public Gtk.GridView grid() {
        var grid = fv_find_type(content(), typeof(Gtk.GridView)) as Gtk.GridView;
        assert(grid != null);
        return (!) grid;
    }

    public Gtk.Label empty_label() {
        var stack = fv_find_type(content(), typeof(Gtk.Stack)) as Gtk.Stack;
        assert(stack != null);
        var page = ((!) stack).get_child_by_name("empty");
        assert(page != null);
        var label = fv_find_type((!) page, typeof(Gtk.Label)) as Gtk.Label;
        assert(label != null);
        return (!) label;
    }

    public Gtk.Stack stack() {
        var found = fv_find_type(content(), typeof(Gtk.Stack)) as Gtk.Stack;
        assert(found != null);
        return (!) found;
    }
}

}
