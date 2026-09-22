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
    assert(!dialog.inline_image_previews_row.get_active());
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

private void test_editor_font_style_maps_style_and_stretch_to_css() {
    var css = HolderLinux.EditorFontStyle.css_for_font_description("Sans Italic 12", "c");
    assert(css.contains("font-style: italic;"));
    css = HolderLinux.EditorFontStyle.css_for_font_description("Sans Oblique 12", "c");
    assert(css.contains("font-style: oblique;"));
    css = HolderLinux.EditorFontStyle.css_for_font_description("Sans 12", "c");
    assert(css.contains("font-style: normal;"));
    assert(css.contains("font-stretch: normal;"));

    string[,] stretches = {
        {"Ultra-Condensed", "ultra-condensed"},
        {"Extra-Condensed", "extra-condensed"},
        {"Condensed", "condensed"},
        {"Semi-Condensed", "semi-condensed"},
        {"Semi-Expanded", "semi-expanded"},
        {"Expanded", "expanded"},
        {"Extra-Expanded", "extra-expanded"},
        {"Ultra-Expanded", "ultra-expanded"}
    };
    for (int i = 0; i < stretches.length[0]; i++) {
        css = HolderLinux.EditorFontStyle.css_for_font_description(
            "Sans %s 12".printf(stretches[i, 0]), "c"
        );
        assert(css.contains("font-stretch: %s;".printf(stretches[i, 1])));
    }

    css = HolderLinux.EditorFontStyle.css_for_font_description("Quote\"Face 12px", "c");
    assert(css.contains("font-family: \"Quote\\\"Face\", monospace;"));
    assert(css.contains("px;"));
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

private void test_inline_image_previews_are_opt_in_and_persisted() {
    var settings = new Settings(HolderLinux.AppSettings.SCHEMA_ID);
    settings.reset(HolderLinux.AppSettings.KEY_SHOW_INLINE_IMAGE_PREVIEWS);
    var buffer = new GtkSource.Buffer(null);
    var view = new GtkSource.View.with_buffer(buffer);
    var dialog = new HolderLinux.PreferencesDialog(
        buffer,
        view,
        null,
        settings,
        new HolderLinux.EditorFontStyle(view)
    );
    bool? changed_to = null;
    dialog.inline_image_previews_changed.connect((enabled) => {
        changed_to = enabled;
    });

    assert(!dialog.inline_image_previews_row.get_active());
    dialog.inline_image_previews_row.set_active(true);
    assert(settings.get_boolean(HolderLinux.AppSettings.KEY_SHOW_INLINE_IMAGE_PREVIEWS));
    assert(changed_to == true);

    dialog.inline_image_previews_row.set_active(false);
    assert(!settings.get_boolean(HolderLinux.AppSettings.KEY_SHOW_INLINE_IMAGE_PREVIEWS));
    assert(changed_to == false);
    settings.reset(HolderLinux.AppSettings.KEY_SHOW_INLINE_IMAGE_PREVIEWS);
}

private void test_editor_font_style_removes_its_css_class_when_released() {
    var view = new GtkSource.View.with_buffer(new GtkSource.Buffer(null));
    var classes_before = view.get_css_classes().length;

    HolderLinux.EditorFontStyle? font_style = new HolderLinux.EditorFontStyle(view);
    assert(view.get_css_classes().length == classes_before + 1);

    font_style = null;
    assert(view.get_css_classes().length == classes_before);
}

// ---- release-quality pass: every switch, the variant combo, style schemes and the font chooser ----

private class PrefSpellcheck : Object, HolderLinux.IEditorSpellcheckPreference {
    public bool requested_value = true;
    public bool safe_value = true;
    public bool available_value = true;
    public Gee.ArrayList<bool> preferences = new Gee.ArrayList<bool>();
    public bool requested_enabled { get { return requested_value; } }
    public bool buffer_safe { get { return safe_value; } }
    public bool backend_available { get { return available_value; } }

    public void set_enabled_preference(bool enabled) {
        requested_value = enabled;
        preferences.add(enabled);
    }
}

private class PrefFontPicker : Object, HolderLinux.IFontPicker {
    public Pango.FontDescription? answer { get; set; default = null; }
    public Error? failure = null;
    public int asked = 0;
    public string? last_initial = null;

    public async Pango.FontDescription? pick_font(Gtk.Window? parent,
                                                  Pango.FontDescription initial) throws Error {
        asked++;
        last_initial = initial.to_string();
        if (failure != null) throw failure;
        return answer;
    }
}

private class PrefHarness : Object {
    public GtkSource.Buffer buffer = new GtkSource.Buffer(null);
    public GtkSource.View view;
    public HolderLinux.EditorFontStyle font_style;
    public HolderLinux.PreferencesDialog dialog;
    public Settings? settings;

    public PrefHarness(Settings? settings = null,
                       HolderLinux.IEditorSpellcheckPreference? spellcheck = null,
                       HolderLinux.IFontPicker? picker = null) {
        this.settings = settings;
        view = new GtkSource.View.with_buffer(buffer);
        font_style = new HolderLinux.EditorFontStyle(view);
        dialog = new HolderLinux.PreferencesDialog(buffer, view, spellcheck, settings, font_style, picker);
    }

    // An Adw.PreferencesDialog only parents its content when presented, so search from its child.
    public Gtk.Widget content() {
        var child = dialog.get_child();
        assert(child != null);
        return (!) child;
    }

    public Adw.SwitchRow switch_row(string title) {
        var found = pref_find_switch(content(), title);
        assert(found != null);
        return (!) found;
    }
}

private Adw.SwitchRow? pref_find_switch(Gtk.Widget root, string title) {
    if (root is Adw.SwitchRow && ((Adw.SwitchRow) root).get_title() == title) return (Adw.SwitchRow) root;
    var child = root.get_first_child();
    while (child != null) {
        var found = pref_find_switch(child, title);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private Adw.ComboRow? pref_find_combo(Gtk.Widget root) {
    if (root is Adw.ComboRow) return (Adw.ComboRow) root;
    var child = root.get_first_child();
    while (child != null) {
        var found = pref_find_combo(child);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private void pref_collect_previews(Gtk.Widget root, Gee.ArrayList<GtkSource.StyleSchemePreview> found) {
    if (root is GtkSource.StyleSchemePreview) found.add((GtkSource.StyleSchemePreview) root);
    var child = root.get_first_child();
    while (child != null) {
        pref_collect_previews(child, found);
        child = child.get_next_sibling();
    }
}

// The chooser's answer is delivered from an idle callback even when the fake answers at once.
private void pref_settle() {
    while (MainContext.default().iteration(false)) {}
}

private Settings pref_fresh_settings(string[] keys) {
    var settings = new Settings(HolderLinux.AppSettings.SCHEMA_ID);
    foreach (var key in keys) settings.reset(key);
    return settings;
}

private void test_pref_the_style_variant_row_applies_and_persists_the_choice() {
    var settings = pref_fresh_settings({ HolderLinux.AppSettings.KEY_STYLE_VARIANT });
    var manager = Adw.StyleManager.get_default();
    var original = manager.get_color_scheme();
    var h = new PrefHarness(settings);
    var combo = pref_find_combo(h.content());
    assert(combo != null);
    assert(((!) combo).get_selected() == 0);

    ((!) combo).set_selected(2);
    assert(manager.get_color_scheme() == Adw.ColorScheme.FORCE_DARK);
    assert(settings.get_string(HolderLinux.AppSettings.KEY_STYLE_VARIANT) ==
           HolderLinux.AppSettings.color_scheme_to_key(Adw.ColorScheme.FORCE_DARK));

    ((!) combo).set_selected(1);
    assert(manager.get_color_scheme() == Adw.ColorScheme.FORCE_LIGHT);
    assert(settings.get_string(HolderLinux.AppSettings.KEY_STYLE_VARIANT) ==
           HolderLinux.AppSettings.color_scheme_to_key(Adw.ColorScheme.FORCE_LIGHT));

    manager.set_color_scheme(original);
    settings.reset(HolderLinux.AppSettings.KEY_STYLE_VARIANT);
}

private void test_pref_the_line_number_switch_updates_the_editor_and_persists() {
    var settings = pref_fresh_settings({ HolderLinux.AppSettings.KEY_SHOW_LINE_NUMBERS });
    var h = new PrefHarness(settings);
    var row = h.switch_row("Show line numbers");
    var initial = row.get_active();
    assert(h.settings.get_boolean(HolderLinux.AppSettings.KEY_SHOW_LINE_NUMBERS) == initial);

    row.set_active(!initial);

    assert(h.view.get_show_line_numbers() == !initial);
    assert(settings.get_boolean(HolderLinux.AppSettings.KEY_SHOW_LINE_NUMBERS) == !initial);
    settings.reset(HolderLinux.AppSettings.KEY_SHOW_LINE_NUMBERS);
}

private void test_pref_spell_checking_states_follow_the_backend_and_the_buffer() {
    var unavailable = new PrefSpellcheck() { available_value = false };
    var h1 = new PrefHarness(null, unavailable);
    assert(!h1.switch_row("Show spell checking").get_sensitive());
    assert(h1.switch_row("Show spell checking").get_subtitle() == "Spell checking backend is unavailable.");

    var paused = new PrefSpellcheck() { safe_value = false };
    var h2 = new PrefHarness(null, paused);
    assert(h2.switch_row("Show spell checking").get_sensitive());
    assert(h2.switch_row("Show spell checking").get_subtitle() ==
           "Spell checking is paused while inline images are displayed.");

    var ready = new PrefSpellcheck();
    var h3 = new PrefHarness(null, ready);
    assert(h3.switch_row("Show spell checking").get_subtitle() == "Underline misspelled words in the editor.");
}

private void test_pref_the_spell_switch_starts_from_the_controller_and_tells_it_the_choice() {
    // Without settings the row shows what the controller was last asked for.
    var controller = new PrefSpellcheck() { requested_value = false };
    var h = new PrefHarness(null, controller);
    assert(!h.switch_row("Show spell checking").get_active());
    h.switch_row("Show spell checking").set_active(true);
    assert(controller.preferences.size == 1 && controller.preferences[0]);

    // With settings, the choice is persisted as well.
    var settings = pref_fresh_settings({ HolderLinux.AppSettings.KEY_SHOW_SPELL_CHECKING });
    var second = new PrefSpellcheck();
    var h2 = new PrefHarness(settings, second);
    var row = h2.switch_row("Show spell checking");
    var initial = row.get_active();
    row.set_active(!initial);
    assert(second.preferences.size == 1 && second.preferences[0] == !initial);
    assert(settings.get_boolean(HolderLinux.AppSettings.KEY_SHOW_SPELL_CHECKING) == !initial);
    settings.reset(HolderLinux.AppSettings.KEY_SHOW_SPELL_CHECKING);
}

private void test_pref_preserving_whitespace_hides_the_two_trim_switches_and_everything_persists() {
    var settings = pref_fresh_settings({
        HolderLinux.AppSettings.KEY_PRESERVE_TRAILING_WHITESPACE,
        HolderLinux.AppSettings.KEY_TRIM_TWO_SPACE_HARD_BREAKS,
        HolderLinux.AppSettings.KEY_TRIM_WHITESPACE_IN_CODE_BLOCKS
    });
    var h = new PrefHarness(settings);
    var preserve = h.switch_row("Preserve trailing whitespace");
    var hard_breaks = h.switch_row("Trim two-space hard breaks");
    var code = h.switch_row("Trim trailing whitespace in code");
    assert(!preserve.get_active());
    assert(hard_breaks.get_visible() && code.get_visible());

    preserve.set_active(true);
    assert(settings.get_boolean(HolderLinux.AppSettings.KEY_PRESERVE_TRAILING_WHITESPACE));
    assert(!hard_breaks.get_visible() && !code.get_visible());

    preserve.set_active(false);
    assert(!settings.get_boolean(HolderLinux.AppSettings.KEY_PRESERVE_TRAILING_WHITESPACE));
    assert(hard_breaks.get_visible() && code.get_visible());

    var hard_breaks_before = hard_breaks.get_active();
    hard_breaks.set_active(!hard_breaks_before);
    assert(settings.get_boolean(HolderLinux.AppSettings.KEY_TRIM_TWO_SPACE_HARD_BREAKS) == !hard_breaks_before);
    var code_before = code.get_active();
    code.set_active(!code_before);
    assert(settings.get_boolean(HolderLinux.AppSettings.KEY_TRIM_WHITESPACE_IN_CODE_BLOCKS) == !code_before);

    // A stored "preserve" starts with the two moot switches hidden.
    settings.set_boolean(HolderLinux.AppSettings.KEY_PRESERVE_TRAILING_WHITESPACE, true);
    var h2 = new PrefHarness(settings);
    assert(h2.switch_row("Preserve trailing whitespace").get_active());
    assert(!h2.switch_row("Trim two-space hard breaks").get_visible());
    assert(!h2.switch_row("Trim trailing whitespace in code").get_visible());
    settings.reset(HolderLinux.AppSettings.KEY_PRESERVE_TRAILING_WHITESPACE);
    settings.reset(HolderLinux.AppSettings.KEY_TRIM_TWO_SPACE_HARD_BREAKS);
    settings.reset(HolderLinux.AppSettings.KEY_TRIM_WHITESPACE_IN_CODE_BLOCKS);
}

private void test_pref_choosing_a_theme_applies_it_persists_it_and_marks_the_preview() {
    var settings = pref_fresh_settings({ HolderLinux.AppSettings.KEY_STYLE_SCHEME_ID });
    var h = new PrefHarness(settings);
    var previews = new Gee.ArrayList<GtkSource.StyleSchemePreview>();
    pref_collect_previews(h.content(), previews);
    assert(previews.size >= 2);

    var current = h.buffer.get_style_scheme();
    var current_id = current != null ? ((!) current).get_id() : "";
    GtkSource.StyleSchemePreview? chosen = null;
    foreach (var preview in previews) {
        if (preview.get_scheme().get_id() != current_id) {
            chosen = preview;
            break;
        }
    }
    assert(chosen != null);
    var chosen_id = ((!) chosen).get_scheme().get_id();

    ((!) chosen).activate();

    assert(h.buffer.get_style_scheme() != null);
    assert(((!) h.buffer.get_style_scheme()).get_id() == chosen_id);
    assert(settings.get_string(HolderLinux.AppSettings.KEY_STYLE_SCHEME_ID) == chosen_id);
    assert(((!) chosen).selected);
    foreach (var preview in previews) {
        if (preview != chosen) assert(!preview.selected);
    }
    settings.reset(HolderLinux.AppSettings.KEY_STYLE_SCHEME_ID);
}

private void test_pref_the_font_chooser_applies_and_persists_the_picked_font() {
    var settings = pref_fresh_settings({
        HolderLinux.AppSettings.KEY_USE_CUSTOM_EDITOR_FONT, HolderLinux.AppSettings.KEY_CUSTOM_EDITOR_FONT
    });
    var picker = new PrefFontPicker() { answer = Pango.FontDescription.from_string("Cantarell Italic 14") };
    var h = new PrefHarness(settings, null, picker);
    h.dialog.custom_font_row.set_active(true);
    var before = h.dialog.custom_font_choice_row.get_title();

    h.dialog.custom_font_choice_row.activated();
    pref_settle();

    assert(picker.asked == 1);
    assert(picker.last_initial == Pango.FontDescription.from_string(before).to_string());
    assert(h.dialog.custom_font_choice_row.get_title() == "Cantarell Italic 14");
    assert(settings.get_string(HolderLinux.AppSettings.KEY_CUSTOM_EDITOR_FONT) == "Cantarell Italic 14");
    assert(h.font_style.enabled && h.font_style.font_description == "Cantarell Italic 14");
    settings.reset(HolderLinux.AppSettings.KEY_USE_CUSTOM_EDITOR_FONT);
    settings.reset(HolderLinux.AppSettings.KEY_CUSTOM_EDITOR_FONT);
}

private void test_pref_cancelling_or_dismissing_the_font_chooser_changes_nothing() {
    var settings = pref_fresh_settings({ HolderLinux.AppSettings.KEY_CUSTOM_EDITOR_FONT });
    var picker = new PrefFontPicker() { failure = new IOError.CANCELLED("closed") };
    var h = new PrefHarness(settings, null, picker);
    var before = h.dialog.custom_font_choice_row.get_title();

    // GLib's tests make any warning fatal, so a cancel mistaken for an error would abort right here.
    h.dialog.custom_font_choice_row.activated();
    pref_settle();
    assert(picker.asked == 1);
    assert(h.dialog.custom_font_choice_row.get_title() == before);

    // A chooser that answers with nothing leaves the font alone too.
    picker.failure = null;
    picker.answer = null;
    h.dialog.custom_font_choice_row.activated();
    pref_settle();
    assert(picker.asked == 2);
    assert(h.dialog.custom_font_choice_row.get_title() == before);
    assert(settings.get_string(HolderLinux.AppSettings.KEY_CUSTOM_EDITOR_FONT) ==
           settings.get_default_value(HolderLinux.AppSettings.KEY_CUSTOM_EDITOR_FONT).get_string());
}

private void test_pref_a_failing_font_chooser_is_logged_and_changes_nothing() {
    var picker = new PrefFontPicker() { failure = new IOError.FAILED("no fonts") };
    var h = new PrefHarness(null, null, picker);
    var before = h.dialog.custom_font_choice_row.get_title();
    Test.expect_message(null, LogLevelFlags.LEVEL_WARNING, "*Unable to choose an editor font: no fonts*");

    h.dialog.custom_font_choice_row.activated();
    pref_settle();

    Test.assert_expected_messages();
    assert(picker.asked == 1);
    assert(h.dialog.custom_font_choice_row.get_title() == before);
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
    Test.add_func("/preferences_dialog/editor_font_style_maps_style_and_stretch_to_css",
                  test_editor_font_style_maps_style_and_stretch_to_css);
    Test.add_func("/preferences_dialog/custom_font_toggle_applies_session_only_style",
                  test_custom_font_toggle_applies_session_only_style);
    Test.add_func("/holder/preferences/editor-font-style-removes-css-class-when-released", test_editor_font_style_removes_its_css_class_when_released);
    Test.add_func("/preferences_dialog/custom_font_selection_persists_family_size_and_disabled_choice",
                  test_custom_font_selection_persists_family_size_and_disabled_choice);
    Test.add_func("/preferences_dialog/plaintext_recovery_opt_out_is_persisted",
                  test_plaintext_recovery_opt_out_is_persisted);
    Test.add_func("/preferences_dialog/inline_image_previews_are_opt_in_and_persisted",
                  test_inline_image_previews_are_opt_in_and_persisted);
    Test.add_func("/preferences_dialog/style-variant", test_pref_the_style_variant_row_applies_and_persists_the_choice);
    Test.add_func("/preferences_dialog/line-numbers", test_pref_the_line_number_switch_updates_the_editor_and_persists);
    Test.add_func("/preferences_dialog/spell-states", test_pref_spell_checking_states_follow_the_backend_and_the_buffer);
    Test.add_func("/preferences_dialog/spell-switch", test_pref_the_spell_switch_starts_from_the_controller_and_tells_it_the_choice);
    Test.add_func("/preferences_dialog/whitespace", test_pref_preserving_whitespace_hides_the_two_trim_switches_and_everything_persists);
    Test.add_func("/preferences_dialog/theme-choice", test_pref_choosing_a_theme_applies_it_persists_it_and_marks_the_preview);
    Test.add_func("/preferences_dialog/font-chooser", test_pref_the_font_chooser_applies_and_persists_the_picked_font);
    Test.add_func("/preferences_dialog/font-chooser-cancel", test_pref_cancelling_or_dismissing_the_font_chooser_changes_nothing);
    Test.add_func("/preferences_dialog/font-chooser-failure", test_pref_a_failing_font_chooser_is_logged_and_changes_nothing);

    return Test.run();
}

}
