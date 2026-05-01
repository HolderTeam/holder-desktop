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

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping sidebar pane tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/holder/sidebar-pane/builds-sections-and-toggles-ai-threads",
                  test_sidebar_pane_builds_sections_and_toggles_ai_threads);

    return Test.run();
}

}
