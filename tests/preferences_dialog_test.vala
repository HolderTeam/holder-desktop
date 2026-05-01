using GLib;

namespace HolderLinuxTests {

private void test_color_scheme_to_index_value_maps_all_supported_variants() {
    assert(HolderLinux.PreferencesDialog.color_scheme_to_index_value(Adw.ColorScheme.DEFAULT) == 0);
    assert(HolderLinux.PreferencesDialog.color_scheme_to_index_value(Adw.ColorScheme.FORCE_LIGHT) == 1);
    assert(HolderLinux.PreferencesDialog.color_scheme_to_index_value(Adw.ColorScheme.FORCE_DARK) == 2);
}

private void test_index_to_color_scheme_value_maps_unknown_to_default() {
    assert(HolderLinux.PreferencesDialog.index_to_color_scheme_value(0) == Adw.ColorScheme.DEFAULT);
    assert(HolderLinux.PreferencesDialog.index_to_color_scheme_value(1) == Adw.ColorScheme.FORCE_LIGHT);
    assert(HolderLinux.PreferencesDialog.index_to_color_scheme_value(2) == Adw.ColorScheme.FORCE_DARK);
    assert(HolderLinux.PreferencesDialog.index_to_color_scheme_value(99) == Adw.ColorScheme.DEFAULT);
}

private void test_preferences_dialog_constructs_appearance_page() {
    var buffer = new GtkSource.Buffer(null);
    var view = new GtkSource.View.with_buffer(buffer);
    view.set_show_line_numbers(true);

    var dialog = new HolderLinux.PreferencesDialog(buffer, view, null, null);
    assert(dialog.get_title() == "Preferences");
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping preferences dialog tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/preferences_dialog/color_scheme_to_index_value_maps_all_supported_variants",
                  test_color_scheme_to_index_value_maps_all_supported_variants);
    Test.add_func("/preferences_dialog/index_to_color_scheme_value_maps_unknown_to_default",
                  test_index_to_color_scheme_value_maps_unknown_to_default);
    Test.add_func("/preferences_dialog/constructs_appearance_page",
                  test_preferences_dialog_constructs_appearance_page);

    return Test.run();
}

}
