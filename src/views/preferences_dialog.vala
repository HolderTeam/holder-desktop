namespace HolderLinux {

public class PreferencesDialog : Adw.PreferencesDialog {
    private GtkSource.Buffer editor_buffer;
    private GtkSource.View editor_view;
    private EditorSpellcheckController? editor_spellcheck;
    private Settings? settings;
    private EditorFontStyle editor_font_style;
    private Gee.HashMap<string, GtkSource.StyleSchemePreview> scheme_previews;
    internal Adw.SwitchRow custom_font_row { get; private set; }
    internal Adw.ActionRow custom_font_choice_row { get; private set; }

    public PreferencesDialog(GtkSource.Buffer editor_buffer,
                             GtkSource.View editor_view,
                             EditorSpellcheckController? editor_spellcheck,
                             Settings? settings,
                             EditorFontStyle editor_font_style) {
        Object();
        this.editor_buffer = editor_buffer;
        this.editor_view = editor_view;
        this.editor_spellcheck = editor_spellcheck;
        this.settings = settings;
        this.editor_font_style = editor_font_style;
        this.scheme_previews = new Gee.HashMap<string, GtkSource.StyleSchemePreview>();
        this.set_title("Preferences");
        build_appearance_page();
    }

    private void build_appearance_page() {
        var page = new Adw.PreferencesPage();
        page.set_name("appearance");
        page.set_title("Appearance");
        page.set_icon_name("preferences-desktop-theme-symbolic");

        var style_group = new Adw.PreferencesGroup();
        style_group.set_title("Style");

        var variant_model = new Gtk.StringList(null);
        variant_model.append("Follow System");
        variant_model.append("Force Light");
        variant_model.append("Force Dark");

        var variant_row = new Adw.ComboRow();
        variant_row.set_title("Style Variant");
        variant_row.set_model(variant_model);
        variant_row.set_expression(new Gtk.PropertyExpression(typeof(Gtk.StringObject), null, "string"));
        variant_row.set_selected(current_variant_index());
        variant_row.notify["selected"].connect(() => {
            var scheme = index_to_color_scheme(variant_row.get_selected());
            Adw.StyleManager.get_default().set_color_scheme(scheme);
            if (settings != null) {
                settings.set_string(AppSettings.KEY_STYLE_VARIANT, AppSettings.color_scheme_to_key(scheme));
            }
        });
        style_group.add(variant_row);

        page.add(style_group);

        var scheme_group = new Adw.PreferencesGroup();
        scheme_group.set_title("Editor Theme");
        scheme_group.set_description("Pick the syntax highlighting theme used by the editor.");

        var flowbox = new Gtk.FlowBox();
        flowbox.set_selection_mode(Gtk.SelectionMode.NONE);
        flowbox.set_valign(Gtk.Align.START);
        flowbox.set_max_children_per_line(3);
        flowbox.set_row_spacing(8);
        flowbox.set_column_spacing(8);
        flowbox.set_margin_top(8);
        flowbox.set_margin_bottom(8);

        populate_style_schemes(flowbox);

        var schemes_scroll = new Gtk.ScrolledWindow();
        schemes_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        schemes_scroll.set_min_content_height(320);
        schemes_scroll.set_child(flowbox);
        scheme_group.add(schemes_scroll);

        page.add(scheme_group);

        build_font_group(page);

        var editor_group = new Adw.PreferencesGroup();
        editor_group.set_title("Editor");

        var line_numbers_row = new Adw.SwitchRow();
        line_numbers_row.set_title("Show line numbers");
        line_numbers_row.set_subtitle("Display line numbers in the editor gutter.");
        if (settings != null) {
            line_numbers_row.set_active(settings.get_boolean(AppSettings.KEY_SHOW_LINE_NUMBERS));
        } else {
            line_numbers_row.set_active(editor_view.get_show_line_numbers());
        }
        line_numbers_row.notify["active"].connect(() => {
            var enabled = line_numbers_row.get_active();
            editor_view.set_show_line_numbers(enabled);
            if (settings != null) {
                settings.set_boolean(AppSettings.KEY_SHOW_LINE_NUMBERS, enabled);
            }
        });
        editor_group.add(line_numbers_row);

        var spell_row = new Adw.SwitchRow();
        spell_row.set_title("Show spell checking");
        spell_row.set_subtitle("Underline misspelled words in the editor.");
        if (settings != null) {
            spell_row.set_active(settings.get_boolean(AppSettings.KEY_SHOW_SPELL_CHECKING));
        } else if (editor_spellcheck != null) {
            spell_row.set_active(editor_spellcheck.requested_enabled);
        } else {
            spell_row.set_active(true);
        }
        if (editor_spellcheck == null || !editor_spellcheck.backend_available) {
            spell_row.set_sensitive(false);
            spell_row.set_subtitle("Spell checking backend is unavailable.");
        } else if (!editor_spellcheck.buffer_safe) {
            spell_row.set_subtitle("Spell checking is paused while inline images are displayed.");
        }
        spell_row.notify["active"].connect(() => {
            var enabled = spell_row.get_active();
            if (editor_spellcheck != null) {
                editor_spellcheck.set_enabled_preference(enabled);
            }
            if (settings != null) {
                settings.set_boolean(AppSettings.KEY_SHOW_SPELL_CHECKING, enabled);
            }
        });
        editor_group.add(spell_row);

        var preserve_whitespace_row = new Adw.SwitchRow();
        preserve_whitespace_row.set_title("Preserve trailing whitespace");
        preserve_whitespace_row.set_subtitle("Keeps spaces and tabs at the ends of lines.");
        if (settings != null) {
            preserve_whitespace_row.set_active(
                settings.get_boolean(AppSettings.KEY_PRESERVE_TRAILING_WHITESPACE)
            );
        }
        editor_group.add(preserve_whitespace_row);

        var trim_hard_breaks_row = new Adw.SwitchRow();
        trim_hard_breaks_row.set_title("Trim two-space hard breaks");
        trim_hard_breaks_row.set_subtitle("Two invisible trailing spaces can force a Markdown line break.");
        if (settings != null) {
            trim_hard_breaks_row.set_active(
                settings.get_boolean(AppSettings.KEY_TRIM_TWO_SPACE_HARD_BREAKS)
            );
        }
        trim_hard_breaks_row.set_visible(!preserve_whitespace_row.get_active());
        editor_group.add(trim_hard_breaks_row);

        var trim_code_whitespace_row = new Adw.SwitchRow();
        trim_code_whitespace_row.set_title("Trim trailing whitespace in code");
        trim_code_whitespace_row.set_subtitle("Code blocks normally preserve their contents literally.");
        if (settings != null) {
            trim_code_whitespace_row.set_active(
                settings.get_boolean(AppSettings.KEY_TRIM_WHITESPACE_IN_CODE_BLOCKS)
            );
        }
        trim_code_whitespace_row.set_visible(!preserve_whitespace_row.get_active());
        editor_group.add(trim_code_whitespace_row);

        // Preserve is the escape hatch: the other two have no effect while it's on, so hide
        // them rather than leave two moot switches visible.
        preserve_whitespace_row.notify["active"].connect(() => {
            var preserve = preserve_whitespace_row.get_active();
            if (settings != null) {
                settings.set_boolean(AppSettings.KEY_PRESERVE_TRAILING_WHITESPACE, preserve);
            }
            trim_hard_breaks_row.set_visible(!preserve);
            trim_code_whitespace_row.set_visible(!preserve);
        });
        trim_hard_breaks_row.notify["active"].connect(() => {
            if (settings != null) {
                settings.set_boolean(
                    AppSettings.KEY_TRIM_TWO_SPACE_HARD_BREAKS,
                    trim_hard_breaks_row.get_active()
                );
            }
        });
        trim_code_whitespace_row.notify["active"].connect(() => {
            if (settings != null) {
                settings.set_boolean(
                    AppSettings.KEY_TRIM_WHITESPACE_IN_CODE_BLOCKS,
                    trim_code_whitespace_row.get_active()
                );
            }
        });

        page.add(editor_group);
        add(page);
    }

    private void build_font_group(Adw.PreferencesPage page) {
        var font_group = new Adw.PreferencesGroup();

        var stored_font = settings != null
            ? settings.get_string(AppSettings.KEY_CUSTOM_EDITOR_FONT)
            : editor_font_style.font_description;
        stored_font = EditorFontStyle.canonical_font_description(stored_font);

        custom_font_row = new Adw.SwitchRow();
        custom_font_row.set_title("Custom Font");
        custom_font_row.set_active(
            settings != null
                ? settings.get_boolean(AppSettings.KEY_USE_CUSTOM_EDITOR_FONT)
                : editor_font_style.enabled
        );
        font_group.add(custom_font_row);

        custom_font_choice_row = new Adw.ActionRow();
        custom_font_choice_row.set_title(stored_font);
        custom_font_choice_row.set_activatable(true);
        custom_font_choice_row.set_visible(custom_font_row.get_active());

        var chevron = new Gtk.Image.from_icon_name("go-next-symbolic");
        chevron.set_accessible_role(Gtk.AccessibleRole.PRESENTATION);
        custom_font_choice_row.add_suffix(chevron);
        custom_font_choice_row.activated.connect(() => {
            choose_custom_font.begin();
        });
        font_group.add(custom_font_choice_row);

        editor_font_style.apply(custom_font_row.get_active(), stored_font);
        custom_font_row.notify["active"].connect(() => {
            var enabled = custom_font_row.get_active();
            custom_font_choice_row.set_visible(enabled);
            editor_font_style.apply(enabled, custom_font_choice_row.get_title());
            if (settings != null) {
                settings.set_boolean(AppSettings.KEY_USE_CUSTOM_EDITOR_FONT, enabled);
            }
        });

        page.add(font_group);
    }

    private async void choose_custom_font() {
        var font_dialog = new Gtk.FontDialog();
        font_dialog.set_title("Pick a Font");
        var initial = Pango.FontDescription.from_string(custom_font_choice_row.get_title());
        var parent = get_root() as Gtk.Window;

        try {
            var selected = yield font_dialog.choose_font(parent, initial, null);
            if (selected != null) {
                select_custom_font(selected);
            }
        } catch (IOError.CANCELLED e) {
            // Closing the chooser leaves the current font unchanged.
        } catch (Error e) {
            warning("Unable to choose an editor font: %s", e.message);
        }
    }

    internal void select_custom_font(Pango.FontDescription description) {
        var selected = EditorFontStyle.canonical_font_description(description.to_string());
        custom_font_choice_row.set_title(selected);
        editor_font_style.apply(custom_font_row.get_active(), selected);
        if (settings != null) {
            settings.set_string(AppSettings.KEY_CUSTOM_EDITOR_FONT, selected);
        }
    }

    private void populate_style_schemes(Gtk.FlowBox flowbox) {
        var manager = GtkSource.StyleSchemeManager.get_default();
        var ids = manager.get_scheme_ids();
        if (ids == null) {
            return;
        }

        foreach (var scheme_id in ids) {
            var scheme = manager.get_scheme(scheme_id);
            if (scheme == null) {
                continue;
            }

            var preview = new GtkSource.StyleSchemePreview(scheme);
            preview.set_hexpand(true);
            preview.set_vexpand(false);
            preview.set_margin_top(2);
            preview.set_margin_bottom(2);
            preview.set_margin_start(2);
            preview.set_margin_end(2);
            preview.activate.connect(() => {
                apply_style_scheme(scheme_id);
            });

            scheme_previews.set(scheme_id, preview);
            flowbox.insert(preview, -1);
        }

        sync_selected_style_scheme();
    }

    private void apply_style_scheme(string scheme_id) {
        var manager = GtkSource.StyleSchemeManager.get_default();
        var scheme = manager.get_scheme(scheme_id);
        if (scheme == null) {
            return;
        }
        editor_buffer.set_style_scheme(scheme);
        if (settings != null) {
            settings.set_string(AppSettings.KEY_STYLE_SCHEME_ID, scheme_id);
        }
        sync_selected_style_scheme();
    }

    private void sync_selected_style_scheme() {
        var current = editor_buffer.get_style_scheme();
        var current_id = current != null ? current.get_id() : "";

        foreach (var entry in scheme_previews.entries) {
            entry.value.set_selected(entry.key == current_id);
        }
    }

    private uint current_variant_index() {
        if (settings != null) {
            return color_scheme_to_index_value(
                AppSettings.key_to_color_scheme(settings.get_string(AppSettings.KEY_STYLE_VARIANT))
            );
        }
        return color_scheme_to_index_value(Adw.StyleManager.get_default().get_color_scheme());
    }

    internal static uint color_scheme_to_index_value(Adw.ColorScheme scheme) {
        switch (scheme) {
        case Adw.ColorScheme.FORCE_LIGHT:
            return 1;
        case Adw.ColorScheme.FORCE_DARK:
            return 2;
        default:
            return 0;
        }
    }

    internal static Adw.ColorScheme index_to_color_scheme_value(uint idx) {
        switch (idx) {
        case 1:
            return Adw.ColorScheme.FORCE_LIGHT;
        case 2:
            return Adw.ColorScheme.FORCE_DARK;
        default:
            return Adw.ColorScheme.DEFAULT;
        }
    }

    private Adw.ColorScheme index_to_color_scheme(uint idx) {
        return index_to_color_scheme_value(idx);
    }
}

}
