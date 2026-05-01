using GLib;

namespace HolderLinuxTests {

private Gtk.Widget? find_widget_by_type(Gtk.Widget root, Type type) {
    if (root.get_type().is_a(type)) {
        return root;
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_widget_by_type(child, type);
        if (match != null) {
            return match;
        }
        child = child.get_next_sibling();
    }
    return null;
}

private HolderLinux.FlowboardTile flowboard_tile(string id, bool is_container = false) {
    return new HolderLinux.FlowboardTile(
        "node-%s".printf(id),
        "Flowboard Card %s".printf(id),
        100,
        is_container,
        id,
        "project-1",
        null,
        1,
        0,
        is_container ? 2 : 0
    );
}

private void test_flowboard_pane_empty_and_grid_state() {
    var pane = new HolderLinux.FlowboardPane();
    pane.set_empty_message("Nothing here yet.");

    var stack = find_widget_by_type(pane.widget, typeof(Gtk.Stack)) as Gtk.Stack;
    assert(stack != null);
    assert(((!) stack).get_visible_child_name() == "empty");

    var store = new GLib.ListStore(typeof(HolderLinux.FlowboardTile));
    pane.set_model(store);
    assert(((!) stack).get_visible_child_name() == "empty");

    store.append(flowboard_tile("card-1"));
    assert(((!) stack).get_visible_child_name() == "grid");

    store.remove(0);
    assert(((!) stack).get_visible_child_name() == "empty");
}

private void test_flowboard_pane_grid_activation_emits_tile_position() {
    var pane = new HolderLinux.FlowboardPane();
    var store = new GLib.ListStore(typeof(HolderLinux.FlowboardTile));
    store.append(flowboard_tile("card-1", true));
    pane.set_model(store);

    uint activated_position = uint.MAX;
    pane.tile_activated.connect((position) => {
        activated_position = position;
    });

    var grid = find_widget_by_type(pane.widget, typeof(Gtk.GridView)) as Gtk.GridView;
    assert(grid != null);
    ((!) grid).activate(0);
    assert(activated_position == 0);
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping flowboard pane tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/holder/flowboard-pane/empty-and-grid-state",
                  test_flowboard_pane_empty_and_grid_state);
    Test.add_func("/holder/flowboard-pane/grid-activation-emits-position",
                  test_flowboard_pane_grid_activation_emits_tile_position);

    return Test.run();
}

}
