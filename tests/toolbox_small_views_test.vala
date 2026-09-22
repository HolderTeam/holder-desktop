using GLib;

namespace HolderLinuxTests {

private Gtk.Widget? nth_child(Gtk.Widget parent, int index) {
    Gtk.Widget? child = parent.get_first_child();
    int i = 0;
    while (child != null) {
        if (i == index) {
            return child;
        }
        child = child.get_next_sibling();
        i++;
    }
    return null;
}

private Gtk.Button? find_button_with_label(Gtk.Widget root, string label) {
    if (root is Gtk.Button) {
        var button = (Gtk.Button) root;
        if (button.get_label() == label) {
            return button;
        }
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_button_with_label(child, label);
        if (match != null) {
            return match;
        }
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.TextView? find_text_view(Gtk.Widget root) {
    if (root is Gtk.TextView) {
        return (Gtk.TextView) root;
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_text_view(child);
        if (match != null) {
            return match;
        }
        child = child.get_next_sibling();
    }
    return null;
}

private string text_buffer_contents(Gtk.TextBuffer buffer) {
    Gtk.TextIter start;
    Gtk.TextIter end;
    buffer.get_bounds(out start, out end);
    return buffer.get_text(start, end, false);
}

private HolderLinux.Project project() {
    return new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 10, 10);
}

private HolderLinux.CardSummary card() {
    return new HolderLinux.CardSummary("c1", "p1", "Card 1", "Card 1.md", 1.0, null, 10, 20);
}

private void assert_project_root_scope(HolderLinux.IToolShellAdapter view, string tool_id, string label) {
    var scope = view.get_scope_snapshot(project(), null);
    assert(scope.tool_id == tool_id);
    assert(scope.tool_label == label);
    assert(scope.project_id == "p1");
    assert(scope.project_label == "Project 1");
    assert(scope.card_id == null);
    assert(scope.card_label == "Overview");
    assert(scope.scope_mode == HolderLinux.ToolScopeMode.PROJECT_ROOT);
}

private void assert_card_scope(HolderLinux.IToolShellAdapter view, string tool_id, string label) {
    var scope = view.get_scope_snapshot(project(), card());
    assert(scope.tool_id == tool_id);
    assert(scope.tool_label == label);
    assert(scope.project_id == "p1");
    assert(scope.card_id == "c1");
    assert(scope.card_label == "Card 1");
    assert(scope.scope_mode == HolderLinux.ToolScopeMode.CARD_FOCUS);
}

private void assert_projects_root_scope(HolderLinux.IToolShellAdapter view, string tool_id, string label) {
    var scope = view.get_scope_snapshot(null, card());
    assert(scope.tool_id == tool_id);
    assert(scope.tool_label == label);
    assert(scope.project_id == null);
    assert(scope.project_label == "Projects");
    assert(scope.card_id == null);
    assert(scope.card_label == "Overview");
    assert(scope.scope_mode == HolderLinux.ToolScopeMode.PROJECTS_ROOT);
}

private void test_navigation_breadcrumbs_renders_and_emits_segment_index() {
    var breadcrumbs = new HolderLinux.NavigationBreadcrumbs();
    var segments = new Gee.ArrayList<HolderLinux.NavigationBreadcrumbSegment>();
    segments.add(new HolderLinux.NavigationBreadcrumbSegment("Projects", false, true, 0));
    segments.add(new HolderLinux.NavigationBreadcrumbSegment("Project 1", false, true, 1));
    segments.add(new HolderLinux.NavigationBreadcrumbSegment("Card 1", true, false, 2));

    int activated = -1;
    breadcrumbs.segment_activated.connect((index) => {
        activated = index;
    });
    breadcrumbs.set_segments(segments);

    var root = breadcrumbs.widget;
    assert(nth_child(root, 0) is Gtk.Button);
    assert(nth_child(root, 1) is Gtk.Label);
    assert(nth_child(root, 2) is Gtk.Button);
    assert(nth_child(root, 3) is Gtk.Label);
    assert(nth_child(root, 4) is Gtk.Label);
    assert(((Gtk.Button) (!) nth_child(root, 0)).get_label() == "Projects");
    assert(((Gtk.Button) (!) nth_child(root, 2)).get_label() == "Project 1");
    assert(((Gtk.Label) (!) nth_child(root, 4)).get_text() == "Card 1");

    ((Gtk.Button) (!) nth_child(root, 2)).clicked();
    assert(activated == 1);

    breadcrumbs.set_segments(new Gee.ArrayList<HolderLinux.NavigationBreadcrumbSegment>());
    assert(root.get_first_child() == null);
}

private void test_debug_view_appends_and_clears_log_text() {
    var view = new HolderLinux.DebugToolView();
    view.append_log_line("first line");

    var text_view = find_text_view(view.widget);
    assert(text_view != null);
    var text = text_buffer_contents(((!) text_view).get_buffer());
    assert(text.contains("first line"));

    var clear_btn = find_button_with_label((!) view.get_actions_widget(), "Clear");
    assert(clear_btn != null);
    ((!) clear_btn).clicked();
    assert(text_buffer_contents(((!) text_view).get_buffer()) == "");

    view.append_log_line("second line");
    var store = new HolderLinux.ActivityLogStore();
    view.bind_activity_log(store);
    store.clear();
    assert(text_buffer_contents(((!) text_view).get_buffer()) == "");

    assert_project_root_scope(view, "debug", "Debug");
    assert_card_scope(view, "debug", "Debug");
    assert_projects_root_scope(view, "debug", "Debug");
}

private void test_recovery_key_view_buttons_emit_signals_and_scope() {
    var view = new HolderLinux.RecoveryKeyToolView();
    int email_calls = 0;
    int usb_calls = 0;
    int import_calls = 0;
    view.send_recovery_key_as_email_requested.connect(() => {
        email_calls++;
    });
    view.save_recovery_key_to_usb_requested.connect(() => {
        usb_calls++;
    });
    view.import_recovery_key_requested.connect(() => {
        import_calls++;
    });

    var email_btn = find_button_with_label(view.widget, "Email Recovery Key");
    var usb_btn = find_button_with_label(view.widget, "Save Recovery Key to USB Drive");
    var import_btn = find_button_with_label(view.widget, "Import Recovery Key");
    assert(email_btn != null);
    assert(usb_btn != null);
    assert(import_btn != null);

    ((!) email_btn).clicked();
    ((!) usb_btn).clicked();
    ((!) import_btn).clicked();
    assert(email_calls == 1);
    assert(usb_calls == 1);
    assert(import_calls == 1);

    assert_project_root_scope(view, "recovery", "Recovery Key");
    assert_card_scope(view, "recovery", "Recovery Key");
    assert_projects_root_scope(view, "recovery", "Recovery Key");
}

private void test_sharing_view_button_state_signal_and_scope() {
    var view = new HolderLinux.SharingToolView();
    int send_calls = 0;
    view.send_card_as_email_requested.connect(() => {
        send_calls++;
    });

    var email_btn = find_button_with_label(view.widget, "Send card as email");
    assert(email_btn != null);

    view.set_has_selected_card(false);
    assert(!((!) email_btn).get_sensitive());
    view.set_has_selected_card(true);
    assert(((!) email_btn).get_sensitive());
    ((!) email_btn).clicked();
    assert(send_calls == 1);

    assert_project_root_scope(view, "sharing", "Sharing");
    assert_card_scope(view, "sharing", "Sharing");
    assert_projects_root_scope(view, "sharing", "Sharing");
}

// ---- release-quality pass: shell surface, scrolling and activity-log binding ----

// Runs a tool view's three async navigations and reports whether each answered "handled".
private bool small_navigation_is_handled(HolderLinux.IToolShellAdapter view) {
    bool root_ok = false;
    bool project_ok = false;
    bool card_ok = false;
    bool done = false;
    int finished = 0;
    view.navigate_to_projects_root.begin(null, (obj, res) => { root_ok = view.navigate_to_projects_root.end(res); finished++; });
    view.navigate_to_project_root.begin("p1", (obj, res) => { project_ok = view.navigate_to_project_root.end(res); finished++; });
    view.navigate_to_card.begin("c1", (obj, res) => { card_ok = view.navigate_to_card.end(res); finished++; });
    while (finished < 3) {
        MainContext.default().iteration(true);
    }
    done = true;
    return done && root_ok && project_ok && card_ok;
}

private void test_small_views_expose_their_widgets_and_answer_every_navigation() {
    var debug = new HolderLinux.DebugToolView();
    assert(debug.tool_id == "debug" && debug.tool_label == "Debug");
    assert(debug.get_content_widget() == debug.widget);
    assert(debug.get_actions_widget() != null);
    assert(small_navigation_is_handled(debug));

    var recovery = new HolderLinux.RecoveryKeyToolView();
    assert(recovery.tool_id == "recovery" && recovery.tool_label == "Recovery Key");
    assert(recovery.get_content_widget() == recovery.widget);
    assert(recovery.get_actions_widget() == null);
    assert(small_navigation_is_handled(recovery));

    var sharing = new HolderLinux.SharingToolView();
    assert(sharing.tool_id == "sharing" && sharing.tool_label == "Sharing");
    assert(sharing.get_content_widget() == sharing.widget);
    assert(sharing.get_actions_widget() == null);
    assert(small_navigation_is_handled(sharing));
}

private void test_debug_view_scrolls_the_cursor_to_the_newest_line() {
    var view = new HolderLinux.DebugToolView();
    var text_view = find_text_view(view.widget);
    assert(text_view != null);
    var buffer = ((!) text_view).get_buffer();
    view.append_log_line("first");
    while (MainContext.default().iteration(false)) {}

    // Park the cursor at the start so the move to the end is something the view had to do.
    Gtk.TextIter start;
    buffer.get_start_iter(out start);
    buffer.place_cursor(start);
    view.append_log_line("second");
    Gtk.TextIter cursor;
    buffer.get_iter_at_mark(out cursor, buffer.get_insert());
    assert(cursor.get_offset() == 0);

    while (MainContext.default().iteration(false)) {}

    buffer.get_iter_at_mark(out cursor, buffer.get_insert());
    assert(cursor.get_offset() == buffer.get_char_count());
    assert(text_buffer_contents(buffer).contains("second"));
}

private void test_debug_clear_goes_through_the_bound_activity_log() {
    var view = new HolderLinux.DebugToolView();
    var store = new HolderLinux.ActivityLogStore();
    store.append("test.kind", "something happened");
    assert(store.snapshot().size == 1);
    view.bind_activity_log(store);
    view.append_log_line("visible line");
    var text_view = find_text_view(view.widget);
    assert(text_view != null);
    assert(text_buffer_contents(((!) text_view).get_buffer()).contains("visible line"));

    var clear_btn = find_button_with_label((!) view.get_actions_widget(), "Clear");
    assert(clear_btn != null);
    ((!) clear_btn).clicked();

    // The store is cleared, and its cleared signal is what empties the view.
    assert(store.snapshot().size == 0);
    assert(text_buffer_contents(((!) text_view).get_buffer()) == "");
}

private void test_debug_view_only_listens_to_the_activity_log_bound_last() {
    var view = new HolderLinux.DebugToolView();
    var first = new HolderLinux.ActivityLogStore();
    var second = new HolderLinux.ActivityLogStore();
    view.bind_activity_log(first);
    view.bind_activity_log(second);
    view.append_log_line("still here");
    var text_view = find_text_view(view.widget);
    assert(text_view != null);

    // The replaced store no longer has a say ...
    first.clear();
    assert(text_buffer_contents(((!) text_view).get_buffer()).contains("still here"));

    // ... and the current one still does.
    second.clear();
    assert(text_buffer_contents(((!) text_view).get_buffer()) == "");
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping small toolbox view tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/holder/navigation-breadcrumbs/render-and-activate",
                  test_navigation_breadcrumbs_renders_and_emits_segment_index);
    Test.add_func("/holder/debug-view/appends-and-clears", test_debug_view_appends_and_clears_log_text);
    Test.add_func("/holder/recovery-key-view/buttons-and-scope", test_recovery_key_view_buttons_emit_signals_and_scope);
    Test.add_func("/holder/sharing-view/button-state-signal-and-scope", test_sharing_view_button_state_signal_and_scope);
    Test.add_func("/holder/small-views/shell-surface", test_small_views_expose_their_widgets_and_answer_every_navigation);
    Test.add_func("/holder/debug-view/scrolls-to-newest", test_debug_view_scrolls_the_cursor_to_the_newest_line);
    Test.add_func("/holder/debug-view/clear-through-activity-log", test_debug_clear_goes_through_the_bound_activity_log);
    Test.add_func("/holder/debug-view/rebinding-activity-log", test_debug_view_only_listens_to_the_activity_log_bound_last);
    return Test.run();
}

}
