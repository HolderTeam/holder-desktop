namespace HolderLinux {

public class PreferencesDialog : Adw.PreferencesDialog {
    private GtkSource.Buffer editor_buffer;
    private GtkSource.View editor_view;
    private Spelling.TextBufferAdapter? spelling_adapter;
    private Settings? settings;
    private Gee.HashMap<string, GtkSource.StyleSchemePreview> scheme_previews;

    public PreferencesDialog(GtkSource.Buffer editor_buffer,
                             GtkSource.View editor_view,
                             Spelling.TextBufferAdapter? spelling_adapter,
                             Settings? settings) {
        Object();
        this.editor_buffer = editor_buffer;
        this.editor_view = editor_view;
        this.spelling_adapter = spelling_adapter;
        this.settings = settings;
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
        } else if (spelling_adapter != null) {
            spell_row.set_active(spelling_adapter.get_enabled());
        } else {
            spell_row.set_active(true);
        }
        if (spelling_adapter == null) {
            spell_row.set_sensitive(false);
            spell_row.set_subtitle("Spell checking backend is unavailable.");
        }
        spell_row.notify["active"].connect(() => {
            var enabled = spell_row.get_active();
            if (spelling_adapter != null) {
                spelling_adapter.set_enabled(enabled);
            }
            if (settings != null) {
                settings.set_boolean(AppSettings.KEY_SHOW_SPELL_CHECKING, enabled);
            }
        });
        editor_group.add(spell_row);

        page.add(editor_group);
        add(page);
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
            return color_scheme_to_index(
                AppSettings.key_to_color_scheme(settings.get_string(AppSettings.KEY_STYLE_VARIANT))
            );
        }
        return color_scheme_to_index(Adw.StyleManager.get_default().get_color_scheme());
    }

    private uint color_scheme_to_index(Adw.ColorScheme scheme) {
        switch (scheme) {
        case Adw.ColorScheme.FORCE_LIGHT:
            return 1;
        case Adw.ColorScheme.FORCE_DARK:
            return 2;
        default:
            return 0;
        }
    }

    private Adw.ColorScheme index_to_color_scheme(uint idx) {
        switch (idx) {
        case 1:
            return Adw.ColorScheme.FORCE_LIGHT;
        case 2:
            return Adw.ColorScheme.FORCE_DARK;
        default:
            return Adw.ColorScheme.DEFAULT;
        }
    }
}

}
