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
    var font_style = new HolderLinux.EditorFontStyle(view);
    view.set_show_line_numbers(true);

    var dialog = new HolderLinux.PreferencesDialog(buffer, view, null, null, font_style);
    assert(dialog.get_title() == "Preferences");
    assert(!dialog.custom_font_row.get_active());
    assert(!dialog.custom_font_choice_row.get_visible());
    assert(dialog.custom_font_choice_row.get_title() ==
           HolderLinux.EditorFontStyle.DEFAULT_FONT_DESCRIPTION);
    assert(!dialog.no_plaintext_recovery_row.get_active());
}

private void test_editor_font_style_canonicalizes_and_builds_css() {
    assert(HolderLinux.EditorFontStyle.canonical_font_description(null) ==
           HolderLinux.EditorFontStyle.DEFAULT_FONT_DESCRIPTION);
    assert(HolderLinux.EditorFontStyle.canonical_font_description("") ==
           HolderLinux.EditorFontStyle.DEFAULT_FONT_DESCRIPTION);
    assert(HolderLinux.EditorFontStyle.canonical_font_description("Sans") ==
           HolderLinux.EditorFontStyle.DEFAULT_FONT_DESCRIPTION);

    var canonical = HolderLinux.EditorFontStyle.canonical_font_description("Fira Code Bold 13");
    assert(canonical == "Fira Code Bold 13");

    var css = HolderLinux.EditorFontStyle.css_for_font_description(canonical, "holder-test-font");
    assert(css.contains(".holder-test-font text"));
    assert(css.contains("font-family: \"Fira Code\", monospace"));
    assert(css.contains("font-size: 13.000pt"));
    assert(css.contains("font-weight: 700"));
}

private void test_custom_font_toggle_applies_session_only_style() {
    var buffer = new GtkSource.Buffer(null);
    var view = new GtkSource.View.with_buffer(buffer);
    var font_style = new HolderLinux.EditorFontStyle(view);
    var dialog = new HolderLinux.PreferencesDialog(buffer, view, null, null, font_style);

    dialog.custom_font_row.set_active(true);
    assert(dialog.custom_font_choice_row.get_visible());
    assert(font_style.enabled);
    assert(font_style.font_description == HolderLinux.EditorFontStyle.DEFAULT_FONT_DESCRIPTION);

    dialog.custom_font_row.set_active(false);
    assert(!dialog.custom_font_choice_row.get_visible());
    assert(!font_style.enabled);
}

private void test_custom_font_selection_persists_family_size_and_disabled_choice() {
    var settings = new Settings(HolderLinux.AppSettings.SCHEMA_ID);
    settings.reset(HolderLinux.AppSettings.KEY_USE_CUSTOM_EDITOR_FONT);
    settings.reset(HolderLinux.AppSettings.KEY_CUSTOM_EDITOR_FONT);

    var buffer = new GtkSource.Buffer(null);
    var view = new GtkSource.View.with_buffer(buffer);
    var font_style = new HolderLinux.EditorFontStyle(view);
    var dialog = new HolderLinux.PreferencesDialog(buffer, view, null, settings, font_style);

    dialog.custom_font_row.set_active(true);
    dialog.select_custom_font(Pango.FontDescription.from_string("Cantarell Italic 14"));

    assert(settings.get_boolean(HolderLinux.AppSettings.KEY_USE_CUSTOM_EDITOR_FONT));
    assert(settings.get_string(HolderLinux.AppSettings.KEY_CUSTOM_EDITOR_FONT) ==
           "Cantarell Italic 14");
    assert(font_style.enabled);
    assert(font_style.font_description == "Cantarell Italic 14");

    dialog.custom_font_row.set_active(false);
    assert(!settings.get_boolean(HolderLinux.AppSettings.KEY_USE_CUSTOM_EDITOR_FONT));
    assert(settings.get_string(HolderLinux.AppSettings.KEY_CUSTOM_EDITOR_FONT) ==
           "Cantarell Italic 14");

    settings.reset(HolderLinux.AppSettings.KEY_USE_CUSTOM_EDITOR_FONT);
    settings.reset(HolderLinux.AppSettings.KEY_CUSTOM_EDITOR_FONT);
}

private void test_plaintext_recovery_opt_out_is_persisted() {
    var settings = new Settings(HolderLinux.AppSettings.SCHEMA_ID);
    settings.reset(HolderLinux.AppSettings.KEY_NO_PLAINTEXT_RECOVERY_FILES);
    var buffer = new GtkSource.Buffer(null);
    var view = new GtkSource.View.with_buffer(buffer);
    var dialog = new HolderLinux.PreferencesDialog(
        buffer,
        view,
        null,
        settings,
        new HolderLinux.EditorFontStyle(view)
    );

    assert(!dialog.no_plaintext_recovery_row.get_active());
    dialog.no_plaintext_recovery_row.set_active(true);
    assert(settings.get_boolean(HolderLinux.AppSettings.KEY_NO_PLAINTEXT_RECOVERY_FILES));
    settings.reset(HolderLinux.AppSettings.KEY_NO_PLAINTEXT_RECOVERY_FILES);
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
    Test.add_func("/preferences_dialog/editor_font_style_canonicalizes_and_builds_css",
                  test_editor_font_style_canonicalizes_and_builds_css);
    Test.add_func("/preferences_dialog/custom_font_toggle_applies_session_only_style",
                  test_custom_font_toggle_applies_session_only_style);
    Test.add_func("/preferences_dialog/custom_font_selection_persists_family_size_and_disabled_choice",
                  test_custom_font_selection_persists_family_size_and_disabled_choice);
    Test.add_func("/preferences_dialog/plaintext_recovery_opt_out_is_persisted",
                  test_plaintext_recovery_opt_out_is_persisted);

    return Test.run();
}

}
