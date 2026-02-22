namespace HolderLinux {

public class PreferencesDialog : Adw.PreferencesDialog {
    private GtkSource.Buffer editor_buffer;
    private Gee.HashMap<string, GtkSource.StyleSchemePreview> scheme_previews;

    public PreferencesDialog(GtkSource.Buffer editor_buffer) {
        Object();
        this.editor_buffer = editor_buffer;
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
        variant_row.set_selected(color_scheme_to_index(Adw.StyleManager.get_default().get_color_scheme()));
        variant_row.notify["selected"].connect(() => {
            Adw.StyleManager.get_default().set_color_scheme(index_to_color_scheme(variant_row.get_selected()));
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
        sync_selected_style_scheme();
    }

    private void sync_selected_style_scheme() {
        var current = editor_buffer.get_style_scheme();
        var current_id = current != null ? current.get_id() : "";

        foreach (var entry in scheme_previews.entries) {
            entry.value.set_selected(entry.key == current_id);
        }
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
