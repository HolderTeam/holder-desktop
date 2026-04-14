using GLib;

namespace HolderLinux {

internal class ExplorerSelectionController : Object {
    public uint project_target = Gtk.INVALID_LIST_POSITION;
    public uint card_target = Gtk.INVALID_LIST_POSITION;
    public uint thread_target = Gtk.INVALID_LIST_POSITION;

    public uint project_position_for_id(string? project_id) {
        return project_target;
    }

    public uint card_position_for_id(string? card_id) {
        return card_target;
    }

    public uint ai_thread_position_for_id(string? thread_id) {
        return thread_target;
    }
}

}

namespace HolderLinux.Tests {

private Gtk.SingleSelection selection_with_two_items() {
    var store = new GLib.ListStore(typeof(Object));
    store.append(new Object());
    store.append(new Object());
    return new Gtk.SingleSelection(store);
}

private void test_apply_from_snapshot_sets_all_three_selections() {
    var project_selection = selection_with_two_items();
    var card_selection = selection_with_two_items();
    var thread_selection = selection_with_two_items();
    var explorer = new HolderLinux.ExplorerSelectionController();
    explorer.project_target = 1;
    explorer.card_target = 0;
    explorer.thread_target = 1;
    var renderer = new HolderLinux.SidebarSelectionRenderer(
        project_selection,
        card_selection,
        thread_selection,
        explorer
    );

    renderer.apply_from_snapshot("proj-1", "card-1", "thread-1");

    assert(project_selection.get_selected() == 1);
    assert(card_selection.get_selected() == 0);
    assert(thread_selection.get_selected() == 1);
}

private void test_apply_from_snapshot_leaves_existing_selection_when_target_is_same() {
    var project_selection = selection_with_two_items();
    var card_selection = selection_with_two_items();
    var thread_selection = selection_with_two_items();
    project_selection.set_selected(0);
    card_selection.set_selected(1);
    thread_selection.set_selected(Gtk.INVALID_LIST_POSITION);

    var explorer = new HolderLinux.ExplorerSelectionController();
    explorer.project_target = 0;
    explorer.card_target = 1;
    explorer.thread_target = Gtk.INVALID_LIST_POSITION;
    var renderer = new HolderLinux.SidebarSelectionRenderer(
        project_selection,
        card_selection,
        thread_selection,
        explorer
    );

    renderer.apply_from_snapshot("proj-1", "card-1", null);

    assert(project_selection.get_selected() == 0);
    assert(card_selection.get_selected() == 1);
    assert(thread_selection.get_selected() == Gtk.INVALID_LIST_POSITION);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/sidebar-selection-renderer/apply-from-snapshot-sets-all-three-selections", test_apply_from_snapshot_sets_all_three_selections);
    Test.add_func("/holder/sidebar-selection-renderer/apply-from-snapshot-leaves-existing-selection-when-target-is-same", test_apply_from_snapshot_leaves_existing_selection_when_target_is_same);
    return Test.run();
}

}
