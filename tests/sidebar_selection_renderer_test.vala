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
    var selection = new Gtk.SingleSelection(store);
    selection.set_autoselect(false);
    selection.set_can_unselect(true);
    return selection;
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

private Gtk.SingleSelection default_selection_with_two_items() {
    var store = new GLib.ListStore(typeof(Object));
    store.append(new Object());
    store.append(new Object());
    // Gtk.SingleSelection defaults to autoselect on with the first item selected, which is how the
    // sidebar models start out in the app.
    return new Gtk.SingleSelection(store);
}

private void test_apply_from_snapshot_clears_selections_when_targets_are_missing() {
    var project_selection = default_selection_with_two_items();
    var card_selection = default_selection_with_two_items();
    var thread_selection = default_selection_with_two_items();
    // Guard against a vacuous test: the invalid-target branch is only reached when something is
    // currently selected.
    assert(project_selection.get_selected() == 0);
    assert(card_selection.get_selected() == 0);
    assert(thread_selection.get_selected() == 0);
    assert(project_selection.get_autoselect());
    assert(!project_selection.get_can_unselect());

    var explorer = new HolderLinux.ExplorerSelectionController();
    var renderer = new HolderLinux.SidebarSelectionRenderer(
        project_selection,
        card_selection,
        thread_selection,
        explorer
    );

    renderer.apply_from_snapshot(null, null, null);

    assert(project_selection.get_selected() == Gtk.INVALID_LIST_POSITION);
    assert(card_selection.get_selected() == Gtk.INVALID_LIST_POSITION);
    assert(thread_selection.get_selected() == Gtk.INVALID_LIST_POSITION);
    // Clearing has to turn autoselect off and allow unselecting, or GTK would reselect item 0.
    assert(!project_selection.get_autoselect());
    assert(project_selection.get_can_unselect());
}

private void test_apply_from_snapshot_clears_only_the_selection_whose_target_is_missing() {
    var project_selection = default_selection_with_two_items();
    var card_selection = default_selection_with_two_items();
    var thread_selection = default_selection_with_two_items();
    var explorer = new HolderLinux.ExplorerSelectionController();
    explorer.project_target = 1;
    explorer.card_target = Gtk.INVALID_LIST_POSITION;
    explorer.thread_target = 0;
    var renderer = new HolderLinux.SidebarSelectionRenderer(
        project_selection,
        card_selection,
        thread_selection,
        explorer
    );
    assert(card_selection.get_selected() == 0);

    renderer.apply_from_snapshot("proj-1", "missing-card", "thread-1");

    assert(project_selection.get_selected() == 1);
    assert(card_selection.get_selected() == Gtk.INVALID_LIST_POSITION);
    assert(thread_selection.get_selected() == 0);
    // Only the cleared selection has its autoselect turned off.
    assert(project_selection.get_autoselect());
    assert(!card_selection.get_autoselect());
    assert(thread_selection.get_autoselect());
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/sidebar-selection-renderer/apply-from-snapshot-sets-all-three-selections", test_apply_from_snapshot_sets_all_three_selections);
    Test.add_func("/holder/sidebar-selection-renderer/apply-from-snapshot-leaves-existing-selection-when-target-is-same", test_apply_from_snapshot_leaves_existing_selection_when_target_is_same);
    Test.add_func("/holder/sidebar-selection-renderer/apply-from-snapshot-clears-selections-when-targets-are-missing", test_apply_from_snapshot_clears_selections_when_targets_are_missing);
    Test.add_func("/holder/sidebar-selection-renderer/apply-from-snapshot-clears-only-the-selection-whose-target-is-missing", test_apply_from_snapshot_clears_only_the_selection_whose_target_is_missing);
    return Test.run();
}

}
