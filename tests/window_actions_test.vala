using GLib;

namespace HolderLinuxTests {

// Each test gets its own never-presented window as the dialog's parent. libadwaita 1.5 (the minimum
// the project supports) never removes a closed dialog from a window that is not shown, so a shared
// window would hand later tests an earlier test's dialog.
private class ActionsDialogHost : Object {
    public Adw.Window window = new Adw.Window();
}

private void test_show_preferences_presents_the_dialog_and_returns_it() {
    var host = new ActionsDialogHost();
    var adapter = new HolderLinux.WindowActionsAdapter(host.window);
    var buffer = new GtkSource.Buffer(null);
    var view = new GtkSource.View.with_buffer(buffer);
    var font_style = new HolderLinux.EditorFontStyle(view);

    var dialog = adapter.show_preferences(buffer, view, null, null, font_style);

    assert(dialog != null);
    assert(host.window.get_visible_dialog() == dialog);
}

private void test_show_about_presents_the_version_and_body() {
    var host = new ActionsDialogHost();
    var adapter = new HolderLinux.WindowActionsAdapter(host.window);

    adapter.show_about();

    var shown = host.window.get_visible_dialog();
    assert(shown != null);
    assert(shown is Adw.AlertDialog);
    var about = (Adw.AlertDialog) shown;
    assert(about.get_heading() == "Holder " + HolderLinux.VERSION);
    assert(about.get_body() == "Holder desktop frontend");
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping window actions tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    var prefix = "/holder/window-actions/";
    Test.add_func(prefix + "show-preferences-presents-the-dialog-and-returns-it",
                  test_show_preferences_presents_the_dialog_and_returns_it);
    Test.add_func(prefix + "show-about-presents-the-version-and-body",
                  test_show_about_presents_the_version_and_body);

    return Test.run();
}

}
