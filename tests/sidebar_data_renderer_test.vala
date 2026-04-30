using GLib;

namespace HolderLinuxTests {

private Gee.ArrayList<HolderLinux.Project> make_projects(string project_id = "p1",
                                                         string name = "Project 1") {
    var projects = new Gee.ArrayList<HolderLinux.Project>();
    projects.add(new HolderLinux.Project(
        project_id,
        name,
        "private",
        "/tmp/project",
        1,
        2
    ));
    return projects;
}

private Gee.ArrayList<HolderLinux.CardSummary> make_cards(string project_id = "p1") {
    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    cards.add(new HolderLinux.CardSummary(
        "c1",
        project_id,
        "Card 1",
        "cards/c1.md",
        1.0,
        null,
        1,
        2
    ));
    return cards;
}

private Gee.ArrayList<HolderLinux.AiThreadSummary> make_threads(string project_id = "p1") {
    var threads = new Gee.ArrayList<HolderLinux.AiThreadSummary>();
    threads.add(new HolderLinux.AiThreadSummary(
        "t1",
        project_id,
        "Thread 1",
        1,
        2
    ));
    return threads;
}

private void test_apply_keeps_project_store_items_when_unchanged() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var ai_thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));
    var renderer = new HolderLinux.SidebarDataRenderer(project_store, card_store, ai_thread_store);

    renderer.apply(make_projects(), make_cards(), make_threads());
    assert(project_store.get_n_items() == 1);
    var first_item = project_store.get_item(0) as HolderLinux.Project;
    assert(first_item != null);

    // Apply an equivalent snapshot (new objects, same values) and verify no rebuild.
    renderer.apply(make_projects(), make_cards(), make_threads());
    assert(project_store.get_n_items() == 1);
    var second_item = project_store.get_item(0) as HolderLinux.Project;
    assert(second_item != null);
    assert(first_item == second_item);
}

private void test_apply_rebuilds_project_store_items_when_changed() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var ai_thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));
    var renderer = new HolderLinux.SidebarDataRenderer(project_store, card_store, ai_thread_store);

    renderer.apply(make_projects("p1", "Project 1"), make_cards(), make_threads());
    var first_item = project_store.get_item(0) as HolderLinux.Project;
    assert(first_item != null);

    renderer.apply(make_projects("p1", "Project Renamed"), make_cards(), make_threads());
    var second_item = project_store.get_item(0) as HolderLinux.Project;
    assert(second_item != null);
    assert(first_item != second_item);
    assert(((!) second_item).name == "Project Renamed");
}

private void test_apply_keeps_card_store_items_when_unchanged() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var ai_thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));
    var renderer = new HolderLinux.SidebarDataRenderer(project_store, card_store, ai_thread_store);

    renderer.apply(make_projects(), make_cards(), make_threads());
    assert(card_store.get_n_items() == 1);
    var first_item = card_store.get_item(0) as HolderLinux.CardSummary;
    assert(first_item != null);

    renderer.apply(make_projects(), make_cards(), make_threads());
    assert(card_store.get_n_items() == 1);
    var second_item = card_store.get_item(0) as HolderLinux.CardSummary;
    assert(second_item != null);
    assert(first_item == second_item);
}

private void test_apply_rebuilds_card_store_items_when_changed() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var ai_thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));
    var renderer = new HolderLinux.SidebarDataRenderer(project_store, card_store, ai_thread_store);

    renderer.apply(make_projects(), make_cards(), make_threads());
    var first_item = card_store.get_item(0) as HolderLinux.CardSummary;
    assert(first_item != null);

    var updated_cards = make_cards();
    updated_cards[(int) 0].title = "Card 1 Updated";
    renderer.apply(make_projects(), updated_cards, make_threads());

    var second_item = card_store.get_item(0) as HolderLinux.CardSummary;
    assert(second_item != null);
    assert(first_item != second_item);
    assert(((!) second_item).title == "Card 1 Updated");
}

private void test_apply_keeps_thread_store_items_when_unchanged() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var ai_thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));
    var renderer = new HolderLinux.SidebarDataRenderer(project_store, card_store, ai_thread_store);

    renderer.apply(make_projects(), make_cards(), make_threads());
    assert(ai_thread_store.get_n_items() == 1);
    var first_item = ai_thread_store.get_item(0) as HolderLinux.AiThreadSummary;
    assert(first_item != null);

    renderer.apply(make_projects(), make_cards(), make_threads());
    assert(ai_thread_store.get_n_items() == 1);
    var second_item = ai_thread_store.get_item(0) as HolderLinux.AiThreadSummary;
    assert(second_item != null);
    assert(first_item == second_item);
}

private void test_apply_rebuilds_thread_store_items_when_changed() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var ai_thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));
    var renderer = new HolderLinux.SidebarDataRenderer(project_store, card_store, ai_thread_store);

    renderer.apply(make_projects(), make_cards(), make_threads());
    var first_item = ai_thread_store.get_item(0) as HolderLinux.AiThreadSummary;
    assert(first_item != null);

    var updated_threads = make_threads();
    updated_threads[(int) 0].title = "Thread 1 Updated";
    renderer.apply(make_projects(), make_cards(), updated_threads);

    var second_item = ai_thread_store.get_item(0) as HolderLinux.AiThreadSummary;
    assert(second_item != null);
    assert(first_item != second_item);
    assert(((!) second_item).title == "Thread 1 Updated");
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func(
        "/holder/sidebar-data-renderer/apply-keeps-project-store-items-when-unchanged",
        test_apply_keeps_project_store_items_when_unchanged
    );
    Test.add_func(
        "/holder/sidebar-data-renderer/apply-rebuilds-project-store-items-when-changed",
        test_apply_rebuilds_project_store_items_when_changed
    );
    Test.add_func(
        "/holder/sidebar-data-renderer/apply-keeps-card-store-items-when-unchanged",
        test_apply_keeps_card_store_items_when_unchanged
    );
    Test.add_func(
        "/holder/sidebar-data-renderer/apply-rebuilds-card-store-items-when-changed",
        test_apply_rebuilds_card_store_items_when_changed
    );
    Test.add_func(
        "/holder/sidebar-data-renderer/apply-keeps-thread-store-items-when-unchanged",
        test_apply_keeps_thread_store_items_when_unchanged
    );
    Test.add_func(
        "/holder/sidebar-data-renderer/apply-rebuilds-thread-store-items-when-changed",
        test_apply_rebuilds_thread_store_items_when_changed
    );

    return Test.run();
}

}
