using GLib;
using Gtk;
using Adw;

namespace HolderLinux {

// Test stub used by src/app.vala so we can exercise activate() without compiling the full UI window.
public class MainWindow : Gtk.ApplicationWindow {
    public static int created_count = 0;

    public MainWindow(Adw.Application app, int startup_width, int startup_height) {
        Object(application: app);
        created_count++;
    }
}

}

namespace HolderLinuxTests {

private bool contains_strv(string[] values, string wanted) {
    foreach (unowned string value in values) {
        if (value == wanted) {
            return true;
        }
    }
    return false;
}

private bool has_primary_or_control_q(string[] values) {
    return contains_strv(values, "<Primary>q") || contains_strv(values, "<Control>q");
}

private void test_constructor_registers_quit_action() {
    var app = new HolderLinux.App();
    var action = app.lookup_action("quit");
    assert(action != null);
}

private void test_constructor_uses_default_application_id() {
    Environment.unset_variable("HOLDER_DESKTOP_APPLICATION_ID");
    var app = new HolderLinux.App();
    assert(app.get_application_id() == "team.holder.Holder");
}

private void test_constructor_uses_development_application_id_override() {
    Environment.set_variable("HOLDER_DESKTOP_APPLICATION_ID", "team.holder.Holder.Devel", true);
    var app = new HolderLinux.App();
    Environment.unset_variable("HOLDER_DESKTOP_APPLICATION_ID");
    assert(app.get_application_id() == "team.holder.Holder.Devel");
}

private void test_quit_action_activate_is_callable() {
    var app = new HolderLinux.App();
    var action = app.lookup_action("quit");
    assert(action != null);
    action.activate(null);
}

private void test_constructor_registers_expected_accels() {
    var app = new HolderLinux.App();

    var quit = app.get_accels_for_action("app.quit");
    assert(quit.length == 1);
    assert(has_primary_or_control_q(quit));

    var new_card = app.get_accels_for_action("win.new-card");
    assert(new_card.length == 1);
    assert(contains_strv(new_card, "<Primary>n") || contains_strv(new_card, "<Control>n"));

    var save = app.get_accels_for_action("win.save");
    assert(save.length == 1);
    assert(contains_strv(save, "<Primary>s") || contains_strv(save, "<Control>s"));

    var flowboard_child = app.get_accels_for_action("win.flowboard-new-child-card");
    assert(flowboard_child.length == 1);
    assert(contains_strv(flowboard_child, "<Primary><Alt>n") || contains_strv(flowboard_child, "<Control><Alt>n"));

    var find_replace = app.get_accels_for_action("win.find-replace");
    assert(find_replace.length == 2);
    assert(contains_strv(find_replace, "<Primary>f") || contains_strv(find_replace, "<Control>f"));
    assert(contains_strv(find_replace, "<Primary>h") || contains_strv(find_replace, "<Control>h"));

    var preferences = app.get_accels_for_action("win.show-preferences");
    assert(preferences.length == 1);
    assert(contains_strv(preferences, "<Primary>comma") || contains_strv(preferences, "<Control>comma"));
}

private void test_activate_creates_main_window_once() {
    if (Gdk.Display.get_default() == null) {
        return;
    }

    HolderLinux.MainWindow.created_count = 0;
    var app = new HolderLinux.App(1000, 700);

    app.activate();
    app.activate();

    assert(HolderLinux.MainWindow.created_count == 1);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/app/constructor_registers_quit_action",
                  test_constructor_registers_quit_action);
    Test.add_func("/app/constructor_uses_default_application_id",
                  test_constructor_uses_default_application_id);
    Test.add_func("/app/constructor_uses_development_application_id_override",
                  test_constructor_uses_development_application_id_override);
    Test.add_func("/app/quit_action_activate_is_callable",
                  test_quit_action_activate_is_callable);
    Test.add_func("/app/constructor_registers_expected_accels",
                  test_constructor_registers_expected_accels);
    Test.add_func("/app/activate_creates_main_window_once",
                  test_activate_creates_main_window_once);

    return Test.run();
}

}
