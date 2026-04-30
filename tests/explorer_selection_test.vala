using GLib;

namespace HolderLinux.Tests {

private HolderLinux.ExplorerSelectionController make_controller(out GLib.ListStore project_store,
                                                               out GLib.ListStore card_store,
                                                               out GLib.ListStore ai_thread_store) {
    project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    ai_thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));

    project_store.append(new HolderLinux.Project("proj-1", "Project One", "plain", "/tmp/proj-1", 10, 20));
    project_store.append(new HolderLinux.Project("proj-2", "Project Two", "plain", "/tmp/proj-2", 11, 21));

    card_store.append(new HolderLinux.CardSummary("card-1", "proj-1", "Card One", "cards/card-1.md", 1.0, null, 10, 20));
    card_store.append(new HolderLinux.CardSummary("card-2", "proj-1", "Card Two", "cards/card-2.md", 2.0, "card-1", 11, 21));

    ai_thread_store.append(new HolderLinux.AiThreadSummary("thread-1", "proj-1", "Thread One", 10, 20));
    ai_thread_store.append(new HolderLinux.AiThreadSummary("thread-2", "proj-1", "Thread Two", 11, 21));

    return new HolderLinux.ExplorerSelectionController(project_store, card_store, ai_thread_store);
}

private void test_project_position_for_id_covers_invalid_found_and_missing() {
    GLib.ListStore project_store;
    GLib.ListStore card_store;
    GLib.ListStore ai_thread_store;
    var controller = make_controller(out project_store, out card_store, out ai_thread_store);

    assert(controller.project_position_for_id(null) == Gtk.INVALID_LIST_POSITION);
    assert(controller.project_position_for_id("") == Gtk.INVALID_LIST_POSITION);
    assert(controller.project_position_for_id("   ") == Gtk.INVALID_LIST_POSITION);
    assert(controller.project_position_for_id("proj-1") == 0);
    assert(controller.project_position_for_id("proj-2") == 1);
    assert(controller.project_position_for_id("missing") == Gtk.INVALID_LIST_POSITION);
}

private void test_card_position_for_id_covers_invalid_found_and_missing() {
    GLib.ListStore project_store;
    GLib.ListStore card_store;
    GLib.ListStore ai_thread_store;
    var controller = make_controller(out project_store, out card_store, out ai_thread_store);

    assert(controller.card_position_for_id(null) == Gtk.INVALID_LIST_POSITION);
    assert(controller.card_position_for_id("") == Gtk.INVALID_LIST_POSITION);
    assert(controller.card_position_for_id("   ") == Gtk.INVALID_LIST_POSITION);
    assert(controller.card_position_for_id("card-1") == 0);
    assert(controller.card_position_for_id("card-2") == 1);
    assert(controller.card_position_for_id("missing") == Gtk.INVALID_LIST_POSITION);
}

private void test_ai_thread_position_for_id_covers_invalid_found_and_missing() {
    GLib.ListStore project_store;
    GLib.ListStore card_store;
    GLib.ListStore ai_thread_store;
    var controller = make_controller(out project_store, out card_store, out ai_thread_store);

    assert(controller.ai_thread_position_for_id(null) == Gtk.INVALID_LIST_POSITION);
    assert(controller.ai_thread_position_for_id("") == Gtk.INVALID_LIST_POSITION);
    assert(controller.ai_thread_position_for_id("   ") == Gtk.INVALID_LIST_POSITION);
    assert(controller.ai_thread_position_for_id("thread-1") == 0);
    assert(controller.ai_thread_position_for_id("thread-2") == 1);
    assert(controller.ai_thread_position_for_id("missing") == Gtk.INVALID_LIST_POSITION);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/explorer-selection/project-position-for-id", test_project_position_for_id_covers_invalid_found_and_missing);
    Test.add_func("/holder/explorer-selection/card-position-for-id", test_card_position_for_id_covers_invalid_found_and_missing);
    Test.add_func("/holder/explorer-selection/ai-thread-position-for-id", test_ai_thread_position_for_id_covers_invalid_found_and_missing);
    return Test.run();
}

}
