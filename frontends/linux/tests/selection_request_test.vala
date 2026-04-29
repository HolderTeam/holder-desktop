using GLib;

namespace HolderLinux {

internal class ExplorerSelectionController : Object {
    public uint project_target = Gtk.INVALID_LIST_POSITION;
    public uint card_target = Gtk.INVALID_LIST_POSITION;
    public uint thread_target = Gtk.INVALID_LIST_POSITION;
    public string? last_project_id = null;
    public string? last_card_id = null;
    public string? last_thread_id = null;

    public uint project_position_for_id(string? project_id) {
        last_project_id = project_id;
        return project_target;
    }

    public uint card_position_for_id(string? card_id) {
        last_card_id = card_id;
        return card_target;
    }

    public uint ai_thread_position_for_id(string? thread_id) {
        last_thread_id = thread_id;
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

private void test_request_project_applies_lookup_result() {
    var explorer = new HolderLinux.ExplorerSelectionController();
    explorer.project_target = 1;
    var controller = new HolderLinux.SelectionRequestController(explorer);
    var selection = selection_with_two_items();

    controller.request_project(selection, "proj-1");

    assert(explorer.last_project_id == "proj-1");
    assert(selection.get_selected() == 1);
}

private void test_request_card_and_ai_thread_leave_selection_unchanged_when_already_selected() {
    var explorer = new HolderLinux.ExplorerSelectionController();
    explorer.card_target = 0;
    explorer.thread_target = 1;
    var controller = new HolderLinux.SelectionRequestController(explorer);

    var card_selection = selection_with_two_items();
    card_selection.set_selected(0);
    controller.request_card(card_selection, "card-1");
    assert(explorer.last_card_id == "card-1");
    assert(card_selection.get_selected() == 0);

    var thread_selection = selection_with_two_items();
    thread_selection.set_selected(1);
    controller.request_ai_thread(thread_selection, "thread-1");
    assert(explorer.last_thread_id == "thread-1");
    assert(thread_selection.get_selected() == 1);
}

private void test_request_methods_can_clear_to_invalid_position() {
    var explorer = new HolderLinux.ExplorerSelectionController();
    var controller = new HolderLinux.SelectionRequestController(explorer);
    var selection = selection_with_two_items();
    selection.set_selected(1);

    controller.request_project(selection, null);

    assert(selection.get_selected() == Gtk.INVALID_LIST_POSITION);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/selection-request/request-project-applies-lookup-result", test_request_project_applies_lookup_result);
    Test.add_func("/holder/selection-request/request-card-and-ai-thread-leave-selection-unchanged-when-already-selected", test_request_card_and_ai_thread_leave_selection_unchanged_when_already_selected);
    Test.add_func("/holder/selection-request/request-methods-can-clear-to-invalid-position", test_request_methods_can_clear_to_invalid_position);
    return Test.run();
}

}
