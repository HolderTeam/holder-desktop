using GLib;

namespace HolderLinuxTests {

private Gtk.Label? find_label(Gtk.Widget root, string text) {
    if (root is Gtk.Label) {
        var label = (Gtk.Label) root;
        if (label.get_text() == text) {
            return label;
        }
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_label(child, text);
        if (match != null) {
            return match;
        }
        child = child.get_next_sibling();
    }
    return null;
}

private void sb_settle() {
    var context = MainContext.default();
    for (int i = 0; i < 20; i++) {
        while (context.iteration(false)) {}
    }
}

private bool sb_skip_popover_tests() {
    if (Environment.get_variable("HOLDER_DESKTOP_TEST_PLATFORM") == "darwin") {
        // A popover realises a native surface on macOS, and GDK's macOS backend then warns
        // "gdk_frame_timings_presented() called on skipped frame", which GLib's test harness turns
        // into a fatal SIGTRAP.
        Test.skip("popovers create native surfaces on macOS, where GDK's frame warning is fatal");
        return true;
    }
    return false;
}

private void sb_collect_labels(Gtk.Widget root, Gee.ArrayList<string> texts) {
    if (root is Gtk.Label) {
        texts.add(((Gtk.Label) root).get_text());
    }
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        sb_collect_labels((!) child, texts);
    }
}

private Gee.ArrayList<string> sb_labels(Gtk.Widget root) {
    var texts = new Gee.ArrayList<string>();
    sb_collect_labels(root, texts);
    return texts;
}

private void sb_collect_list_views(Gtk.Widget root, Gee.ArrayList<Gtk.ListView> views) {
    if (root is Gtk.ListView) {
        views.add((Gtk.ListView) root);
    }
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        sb_collect_list_views((!) child, views);
    }
}

// Rows are the boxes the card factory tags with the id of the card they show.
private void sb_collect_card_rows(Gtk.Widget root, Gee.ArrayList<Gtk.Widget> rows) {
    if (root is Gtk.Box && root.get_data<string>("sidebar-card-id") != null) {
        rows.add(root);
        return;
    }
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        sb_collect_card_rows((!) child, rows);
    }
}

private Gtk.Button? sb_find_button(Gtk.Widget root, string label) {
    if (root is Gtk.Button && ((Gtk.Button) root).get_label() == label) {
        return (Gtk.Button) root;
    }
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        var found = sb_find_button((!) child, label);
        if (found != null) {
            return found;
        }
    }
    return null;
}

private Gtk.Popover? sb_popover(Gtk.Widget widget) {
    for (var child = widget.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        if (child is Gtk.Popover) {
            return (Gtk.Popover) child;
        }
    }
    return null;
}

private int sb_popover_count(Gtk.Widget widget) {
    int count = 0;
    for (var child = widget.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        if (child is Gtk.Popover) {
            count++;
        }
    }
    return count;
}

private void sb_secondary_press(Gtk.Widget row, int n_press = 1) {
    var controllers = row.observe_controllers();
    for (uint i = 0; i < controllers.get_n_items(); i++) {
        var click = controllers.get_item(i) as Gtk.GestureClick;
        if (click != null && ((!) click).get_button() == Gdk.BUTTON_SECONDARY) {
            ((!) click).pressed(n_press, 6.0, 7.0);
            return;
        }
    }
    assert_not_reached();
}

private int64 sb_hours_ago(int hours) {
    return new DateTime.now_utc().to_unix() - hours * 3600;
}

private class SidebarHarness : Object {
    public GLib.ListStore projects;
    public GLib.ListStore cards;
    public GLib.ListStore threads;
    public Gtk.SelectionModel project_selection;
    public Gtk.SelectionModel card_selection;
    public Gtk.SelectionModel thread_selection;
    public HolderLinux.SidebarPane pane;
    public Adw.Window window = new Adw.Window();
    public Gee.ArrayList<string> trash_requests = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> context_requests = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> child_requests = new Gee.ArrayList<string>();
    public int event_count { get; set; default = 0; }

    // Pass plain Objects to a store's type to get rows that are not projects/cards/threads.
    public SidebarHarness(bool plain_objects = false, bool multi_card_selection = false) {
        var project_type = plain_objects ? typeof(Object) : typeof(HolderLinux.Project);
        var card_type = plain_objects ? typeof(Object) : typeof(HolderLinux.CardSummary);
        var thread_type = plain_objects ? typeof(Object) : typeof(HolderLinux.AiThreadSummary);
        projects = new GLib.ListStore(project_type);
        cards = new GLib.ListStore(card_type);
        threads = new GLib.ListStore(thread_type);
        project_selection = new Gtk.SingleSelection(projects);
        card_selection = multi_card_selection ? (Gtk.SelectionModel) new Gtk.MultiSelection(cards)
                                              : (Gtk.SelectionModel) new Gtk.SingleSelection(cards);
        thread_selection = new Gtk.SingleSelection(threads);
        pane = new HolderLinux.SidebarPane(project_selection, card_selection, thread_selection);
        pane.card_move_to_trash_requested.connect((card_id) => { trash_requests.add(card_id); event_count++; });
        pane.card_context_selection_requested.connect((card_id) => { context_requests.add(card_id); event_count++; });
        pane.card_create_child_requested.connect((card_id) => { child_requests.add(card_id); event_count++; });
    }

    public void show() {
        window.set_content(pane.widget);
        sb_settle();
    }

    public Gee.ArrayList<Gtk.Widget> card_rows() {
        var rows = new Gee.ArrayList<Gtk.Widget>();
        sb_collect_card_rows(pane.widget, rows);
        return rows;
    }

    public Gtk.Widget row_for(string card_id) {
        foreach (var row in card_rows()) {
            if (row.get_data<string>("sidebar-card-id") == card_id) {
                return row;
            }
        }
        assert_not_reached();
    }

    // The three lists in the order the sidebar builds them: projects, AI threads, cards.
    public Gtk.ListView card_list() {
        var views = new Gee.ArrayList<Gtk.ListView>();
        sb_collect_list_views(pane.widget, views);
        assert(views.size == 3);
        return views[2];
    }

    public Gtk.EventControllerKey card_keys() {
        var controllers = card_list().observe_controllers();
        for (uint i = 0; i < controllers.get_n_items(); i++) {
            var keys = controllers.get_item(i) as Gtk.EventControllerKey;
            if (keys != null) {
                return (!) keys;
            }
        }
        assert_not_reached();
    }

    public void add_card(string card_id, string title, int64 updated_at = 0) {
        cards.append(new HolderLinux.CardSummary(card_id, "p1", title, title + ".md", 1.0, null, 1, updated_at));
    }

    public void no_card_selected() {
        var single = (Gtk.SingleSelection) card_selection;
        single.set_autoselect(false);
        single.set_can_unselect(true);
        single.unselect_item(single.get_selected());
        assert(single.get_selected() == Gtk.INVALID_LIST_POSITION);
    }
}

private void test_sidebar_pane_builds_sections_and_toggles_ai_threads() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    project_store.append(new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 10, 20));
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    card_store.append(new HolderLinux.CardSummary("c1", "p1", "Card 1", "Card 1.md", 1.0, null, 10, 20));
    var thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));

    var sidebar = new HolderLinux.SidebarPane(
        new Gtk.SingleSelection(project_store),
        new Gtk.SingleSelection(card_store),
        new Gtk.SingleSelection(thread_store)
    );

    assert(find_label(sidebar.widget, "Holder") != null);
    assert(find_label(sidebar.widget, "Projects") != null);
    assert(find_label(sidebar.widget, "Cards") != null);

    var threads_title = find_label(sidebar.widget, "AI Threads");
    assert(threads_title != null);
    assert(!((!) threads_title).get_visible());

    thread_store.append(new HolderLinux.AiThreadSummary("t1", "p1", "Thread 1", 10, 20));
    assert(((!) threads_title).get_visible());
}

private void test_the_ai_threads_section_hides_again_when_the_last_thread_goes() {
    var h = new SidebarHarness();
    var title = find_label(h.pane.widget, "AI Threads");
    assert(title != null);
    assert(!((!) title).get_visible());

    h.threads.append(new HolderLinux.AiThreadSummary("t1", "p1", "Thread 1", 1, 2));
    assert(((!) title).get_visible());
    h.threads.append(new HolderLinux.AiThreadSummary("t2", "p1", "Thread 2", 1, 2));
    h.threads.remove(0);
    assert(((!) title).get_visible());

    h.threads.remove_all();
    assert(!((!) title).get_visible());
}

private void test_a_sidebar_built_over_existing_threads_shows_the_section_immediately() {
    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    var card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    var thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));
    thread_store.append(new HolderLinux.AiThreadSummary("t1", "p1", "Thread 1", 1, 2));

    var sidebar = new HolderLinux.SidebarPane(
        new Gtk.SingleSelection(project_store),
        new Gtk.SingleSelection(card_store),
        new Gtk.SingleSelection(thread_store)
    );

    var title = find_label(sidebar.widget, "AI Threads");
    assert(title != null && ((!) title).get_visible());
}

private void test_rows_show_project_names_thread_titles_and_card_titles_with_their_age() {
    var h = new SidebarHarness();
    h.projects.append(new HolderLinux.Project("p1", "Runbook", "encrypted_git", "/tmp/p1", 10, 20));
    h.threads.append(new HolderLinux.AiThreadSummary("t1", "p1", "Planning chat", 1, sb_hours_ago(3)));
    h.add_card("c1", "First card", sb_hours_ago(2));
    h.add_card("c2", "Untouched card", 0);
    h.show();

    var labels = sb_labels(h.pane.widget);
    assert(labels.contains("Runbook"));
    assert(labels.contains("Planning chat"));
    assert(labels.contains("Updated 3h ago"));
    assert(labels.contains("First card"));
    assert(labels.contains("Updated 2h ago"));
    assert(labels.contains("Untouched card"));
    assert(labels.contains("Updated unknown"));
}

private void test_rows_for_items_that_are_not_summaries_are_blank() {
    var h = new SidebarHarness(true);
    h.projects.append(new Object());
    h.threads.append(new Object());
    h.cards.append(new Object());
    h.show();

    // Precondition: the card row exists, so the blank binding really ran.
    var rows = h.card_rows();
    assert(rows.size == 1);
    assert(rows[0].get_data<string>("sidebar-card-id") == "");
    var labels = sb_labels(h.pane.widget);
    assert(!labels.contains("Updated unknown"));
    foreach (var text in labels) {
        assert(!text.has_prefix("Updated"));
    }
}

private void test_a_card_row_is_tagged_with_the_card_it_shows_and_retagged_when_reused() {
    var h = new SidebarHarness();
    h.add_card("c1", "One");
    h.add_card("c2", "Two");
    h.show();

    var ids = new Gee.ArrayList<string>();
    foreach (var row in h.card_rows()) {
        ids.add(row.get_data<string>("sidebar-card-id"));
    }
    assert(ids.size == 2);
    assert(ids.contains("c1") && ids.contains("c2"));

    h.cards.remove(0);
    sb_settle();
    ids.clear();
    foreach (var row in h.card_rows()) {
        ids.add(row.get_data<string>("sidebar-card-id"));
    }
    assert(ids.size == 1);
    assert(ids[0] == "c2");
}

private void test_right_clicking_a_card_selects_it_and_offers_create_child_and_trash() {
    if (sb_skip_popover_tests()) {
        return;
    }
    var h = new SidebarHarness();
    h.add_card("c1", "One");
    h.add_card("c2", "Two");
    h.show();
    var row = h.row_for("c2");
    assert(sb_popover(row) == null);

    sb_secondary_press(row);

    assert(h.context_requests.size == 1 && h.context_requests[0] == "c2");
    var popover = sb_popover(row);
    assert(popover != null);
    var child = sb_find_button((!) popover, "Create Child Card");
    var trash = sb_find_button((!) popover, "Move to Trash");
    assert(child != null && trash != null);
    assert(h.child_requests.size == 0 && h.trash_requests.size == 0);

    ((!) child).clicked();
    assert(h.child_requests.size == 1 && h.child_requests[0] == "c2");
    assert(h.trash_requests.size == 0);
    ((!) trash).clicked();
    assert(h.trash_requests.size == 1 && h.trash_requests[0] == "c2");
}

private void test_repeated_right_clicks_leave_a_single_menu_on_the_row() {
    if (sb_skip_popover_tests()) {
        return;
    }
    var h = new SidebarHarness();
    h.add_card("c1", "One");
    h.show();
    var row = h.row_for("c1");

    sb_secondary_press(row);
    assert(sb_popover_count(row) == 1);
    sb_secondary_press(row);
    sb_secondary_press(row);

    // Every click used to parent another popover to the row and never remove the old one.
    assert(h.context_requests.size == 3);
    assert(sb_popover_count(row) == 1);
    // The surviving menu belongs to the latest click and still works.
    var latest = (!) sb_popover(row);
    ((!) sb_find_button(latest, "Move to Trash")).clicked();
    assert(h.trash_requests.size == 1 && h.trash_requests[0] == "c1");
}

private void test_a_double_right_click_or_a_row_with_no_card_opens_nothing() {
    var h = new SidebarHarness();
    h.add_card("c1", "One");
    h.show();
    var row = h.row_for("c1");
    var events_before = h.event_count;

    sb_secondary_press(row, 2);

    assert(h.event_count == events_before);
    assert(sb_popover(row) == null);

    var blank = new SidebarHarness(true);
    blank.cards.append(new Object());
    blank.show();
    var blank_row = blank.card_rows()[0];
    assert(blank_row.get_data<string>("sidebar-card-id") == "");

    sb_secondary_press(blank_row);

    assert(blank.event_count == 0);
    assert(sb_popover(blank_row) == null);
}

private void test_delete_moves_the_selected_card_to_trash() {
    var h = new SidebarHarness();
    h.add_card("c1", "One");
    h.add_card("c2", "Two");
    h.show();
    ((Gtk.SingleSelection) h.card_selection).set_selected(1);
    assert(((Gtk.SingleSelection) h.card_selection).get_selected() == 1);

    var keys = h.card_keys();
    assert(keys.key_pressed(Gdk.Key.Delete, 0, 0));
    assert(h.trash_requests.size == 1 && h.trash_requests[0] == "c2");

    ((Gtk.SingleSelection) h.card_selection).set_selected(0);
    assert(keys.key_pressed(Gdk.Key.KP_Delete, 0, 0));
    assert(h.trash_requests.size == 2 && h.trash_requests[1] == "c1");
}

private void test_other_keys_and_unusable_selections_do_not_trash_anything() {
    var h = new SidebarHarness();
    h.add_card("c1", "One");
    h.show();
    var keys = h.card_keys();

    // Another key is not handled.
    assert(!keys.key_pressed(Gdk.Key.a, 0, 0));
    assert(h.trash_requests.size == 0);

    // Delete with nothing selected is not handled either.
    h.no_card_selected();
    assert(!keys.key_pressed(Gdk.Key.Delete, 0, 0));
    assert(h.trash_requests.size == 0);

    // A selection that is not a single selection cannot name one card.
    var multi = new SidebarHarness(false, true);
    multi.add_card("c1", "One");
    multi.show();
    assert(!multi.card_keys().key_pressed(Gdk.Key.Delete, 0, 0));
    assert(multi.trash_requests.size == 0);

    // A selected row that is not a card is ignored.
    var plain = new SidebarHarness(true);
    plain.cards.append(new Object());
    plain.show();
    assert(((Gtk.SingleSelection) plain.card_selection).get_selected() == 0);
    assert(!plain.card_keys().key_pressed(Gdk.Key.Delete, 0, 0));
    assert(plain.trash_requests.size == 0);
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping sidebar pane tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/holder/sidebar-pane/builds-sections-and-toggles-ai-threads",
                  test_sidebar_pane_builds_sections_and_toggles_ai_threads);
    Test.add_func("/holder/sidebar-pane/ai-threads-hide-again",
                  test_the_ai_threads_section_hides_again_when_the_last_thread_goes);
    Test.add_func("/holder/sidebar-pane/ai-threads-shown-immediately",
                  test_a_sidebar_built_over_existing_threads_shows_the_section_immediately);
    Test.add_func("/holder/sidebar-pane/rows", test_rows_show_project_names_thread_titles_and_card_titles_with_their_age);
    Test.add_func("/holder/sidebar-pane/blank-rows", test_rows_for_items_that_are_not_summaries_are_blank);
    Test.add_func("/holder/sidebar-pane/card-row-tags", test_a_card_row_is_tagged_with_the_card_it_shows_and_retagged_when_reused);
    Test.add_func("/holder/sidebar-pane/context-menu", test_right_clicking_a_card_selects_it_and_offers_create_child_and_trash);
    Test.add_func("/holder/sidebar-pane/context-menu-single", test_repeated_right_clicks_leave_a_single_menu_on_the_row);
    Test.add_func("/holder/sidebar-pane/context-menu-guards", test_a_double_right_click_or_a_row_with_no_card_opens_nothing);
    Test.add_func("/holder/sidebar-pane/delete-key", test_delete_moves_the_selected_card_to_trash);
    Test.add_func("/holder/sidebar-pane/delete-key-guards", test_other_keys_and_unusable_selections_do_not_trash_anything);

    return Test.run();
}

}
