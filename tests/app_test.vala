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

    var toolbox = app.get_accels_for_action("win.toggle-toolbox");
    assert(toolbox.length == 0);

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

private void run_icon_theme_startup_test(bool with_fallback) {
    if (!Gtk.init_check()) {
        Test.skip("A display is required to exercise application startup");
        return;
    }

    // A fresh process keeps the fixture isolated from GTK's cached theme state.
    if (!Test.subprocess()) {
        Test.trap_subprocess(null, 10 * 1000000, 0);
        Test.trap_assert_passed();
        if (with_fallback) {
            Test.trap_assert_stderr_unmatched("*Holder cannot start*");
        } else {
            Test.trap_assert_stderr("*Holder cannot start*image-missing*Icon search paths:*");
            if (HolderLinux.PLATFORM == "darwin") {
                Test.trap_assert_stderr("*brew install adwaita-icon-theme*");
            }
        }
        return;
    }

    try {
        var root = DirUtils.make_tmp("holder-startup-icons-XXXXXX");
        var theme_dir = Path.build_filename(root, "hicolor");
        var icons_dir = Path.build_filename(theme_dir, "16x16", "status");
        DirUtils.create_with_parents(icons_dir, 0700);
        var index_path = Path.build_filename(theme_dir, "index.theme");
        FileUtils.set_contents(index_path,
            "[Icon Theme]\nName=Startup test\nDirectories=16x16/status\n" +
            "[16x16/status]\nSize=16\nType=Fixed\nContext=Status\n");
        var icon_path = Path.build_filename(icons_dir, "image-missing.svg");
        if (with_fallback) {
            FileUtils.set_contents(icon_path,
                "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\">" +
                "<rect width=\"16\" height=\"16\"/></svg>");
        }

        HolderLinux.MainWindow.created_count = 0;
        var app = new HolderLinux.App();
        app.flags |= ApplicationFlags.NON_UNIQUE;
        app.startup.connect(() => {
            var theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
            theme.set_search_path({root});
            theme.set_resource_path({});
        });
        app.activate.connect_after(() => {
            // End the successful case before rendering the intentionally sparse fixture.
            app.quit();
        });
        app.run({"holder-startup-test"});
        assert(app.startup_failed == !with_fallback);
        assert(HolderLinux.MainWindow.created_count == (with_fallback ? 1 : 0));

        if (with_fallback) {
            FileUtils.remove(icon_path);
        }
        FileUtils.remove(index_path);
        DirUtils.remove(icons_dir);
        DirUtils.remove(Path.get_dirname(icons_dir));
        DirUtils.remove(theme_dir);
        DirUtils.remove(root);
    } catch (Error e) {
        Test.fail_printf("Startup fixture failed: %s", e.message);
    }
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
    Test.add_func("/app/startup_missing_icons", () => run_icon_theme_startup_test(false));
    Test.add_func("/app/startup_with_fallback_icon", () => run_icon_theme_startup_test(true));

    return Test.run();
}

}
