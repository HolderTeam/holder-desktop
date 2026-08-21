namespace HolderLinux {

public class EditorFontStyle : Object {
    public const string DEFAULT_FONT_DESCRIPTION = "Monospace 11";

    [CCode(cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
    private static extern void gtk_style_context_add_provider_for_display(
        Gdk.Display display,
        Gtk.StyleProvider provider,
        uint priority
    );

    [CCode(cname = "gtk_style_context_remove_provider_for_display", cheader_filename = "gtk/gtk.h")]
    private static extern void gtk_style_context_remove_provider_for_display(
        Gdk.Display display,
        Gtk.StyleProvider provider
    );

    private static uint next_css_id = 0;

    private GtkSource.View editor_view;
    private Gtk.CssProvider provider;
    private Gdk.Display display;
    private string css_class;

    public bool enabled { get; private set; default = false; }
    public string font_description { get; private set; default = DEFAULT_FONT_DESCRIPTION; }

    public EditorFontStyle(GtkSource.View editor_view) {
        this.editor_view = editor_view;
        this.provider = new Gtk.CssProvider();
        this.display = editor_view.get_display();
        this.css_class = "holder-editor-font-%u".printf(++next_css_id);

        editor_view.add_css_class(css_class);
        gtk_style_context_add_provider_for_display(
            display,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1
        );
    }

    ~EditorFontStyle() {
        editor_view.remove_css_class(css_class);
        gtk_style_context_remove_provider_for_display(display, provider);
    }

    public void apply(bool enabled, string font_description) {
        this.enabled = enabled;
        this.font_description = canonical_font_description(font_description);

        if (!enabled) {
            provider.load_from_string("");
            return;
        }

        provider.load_from_string(css_for_font_description(this.font_description, css_class));
    }

    internal static string canonical_font_description(string? value) {
        if (value == null || value.strip().length == 0) {
            return DEFAULT_FONT_DESCRIPTION;
        }

        var description = Pango.FontDescription.from_string(value.strip());
        var family = description.get_family();
        if (family == null || family.strip().length == 0 || description.get_size() <= 0) {
            return DEFAULT_FONT_DESCRIPTION;
        }
        return description.to_string();
    }

    internal static string css_for_font_description(string value, string css_class) {
        var canonical = canonical_font_description(value);
        var description = Pango.FontDescription.from_string(canonical);
        var family = description.get_family() ?? "Monospace";
        var size = css_size(description.get_size());
        var size_unit = description.get_size_is_absolute() ? "px" : "pt";

        return """
.%s,
.%s text {
  font-family: %s, monospace;
  font-size: %s%s;
  font-style: %s;
  font-weight: %d;
  font-stretch: %s;
}
""".printf(
            css_class,
            css_class,
            css_quote(family),
            size,
            size_unit,
            css_style(description.get_style()),
            (int) description.get_weight(),
            css_stretch(description.get_stretch())
        );
    }

    private static string css_size(int pango_size) {
        var whole = pango_size / Pango.SCALE;
        var thousandths = ((pango_size % Pango.SCALE) * 1000) / Pango.SCALE;
        return "%d.%03d".printf(whole, thousandths);
    }

    private static string css_quote(string value) {
        return "\"%s\"".printf(
            value.replace("\\", "\\\\")
                 .replace("\"", "\\\"")
                 .replace("\n", " ")
                 .replace("\r", " ")
                 .replace("\f", " ")
        );
    }

    private static string css_style(Pango.Style style) {
        switch (style) {
        case Pango.Style.ITALIC:
            return "italic";
        case Pango.Style.OBLIQUE:
            return "oblique";
        default:
            return "normal";
        }
    }

    private static string css_stretch(Pango.Stretch stretch) {
        switch (stretch) {
        case Pango.Stretch.ULTRA_CONDENSED:
            return "ultra-condensed";
        case Pango.Stretch.EXTRA_CONDENSED:
            return "extra-condensed";
        case Pango.Stretch.CONDENSED:
            return "condensed";
        case Pango.Stretch.SEMI_CONDENSED:
            return "semi-condensed";
        case Pango.Stretch.SEMI_EXPANDED:
            return "semi-expanded";
        case Pango.Stretch.EXPANDED:
            return "expanded";
        case Pango.Stretch.EXTRA_EXPANDED:
            return "extra-expanded";
        case Pango.Stretch.ULTRA_EXPANDED:
            return "ultra-expanded";
        default:
            return "normal";
        }
    }
}

}
