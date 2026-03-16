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

private void test_set_content_widget_replaces_content_and_keeps_action_row() {
    var breadcrumbs = new HolderLinux.NavigationBreadcrumbs();
    var switcher = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
    var shell = new HolderLinux.ToolShell(breadcrumbs, switcher);

    var action_widget = new Gtk.Button.with_label("Action");
    shell.set_actions_widget(action_widget);

    var first_content = new Gtk.Label("one");
    var second_content = new Gtk.Label("two");

    shell.set_content_widget(first_content);
    shell.set_content_widget(second_content);

    var root = shell.widget;
    var action_row = nth_child(root, 1);
    var content_row = nth_child(root, 2);
    assert(action_row != null);
    assert(content_row != null);

    var actions_slot = ((!) action_row).get_first_child();
    assert(actions_slot != null);
    assert(((!) actions_slot).get_first_child() == action_widget);

    var content_child = ((!) content_row).get_first_child();
    assert(content_child == second_content);
    assert(((!) content_child).get_next_sibling() == null);
}

private void test_set_loading_toggles_spinner_visibility() {
    var breadcrumbs = new HolderLinux.NavigationBreadcrumbs();
    var switcher = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
    var shell = new HolderLinux.ToolShell(breadcrumbs, switcher);

    shell.set_actions_widget(new Gtk.Button.with_label("Action"));

    var action_row = nth_child(shell.widget, 1);
    assert(action_row != null);
    var spinner = nth_child((!) action_row, 1) as Gtk.Spinner;
    assert(spinner != null);

    shell.set_loading(true);
    assert(((!) spinner).get_visible());

    shell.set_loading(false);
    assert(!((!) spinner).get_visible());
}

private void test_set_actions_widget_null_hides_action_row() {
    var breadcrumbs = new HolderLinux.NavigationBreadcrumbs();
    var switcher = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
    var shell = new HolderLinux.ToolShell(breadcrumbs, switcher);

    shell.set_actions_widget(new Gtk.Button.with_label("Action"));

    var action_row = nth_child(shell.widget, 1);
    assert(action_row != null);
    assert(((!) action_row).get_visible());

    shell.set_actions_widget(null);
    assert(!((!) action_row).get_visible());
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping tool shell tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/holder/tool-shell/content-replacement-keeps-action-row",
                  test_set_content_widget_replaces_content_and_keeps_action_row);
    Test.add_func("/holder/tool-shell/loading-spinner-toggle",
                  test_set_loading_toggles_spinner_visibility);
    Test.add_func("/holder/tool-shell/null-actions-hide-action-row",
                  test_set_actions_widget_null_hides_action_row);

    return Test.run();
}

}
