namespace HolderLinux {

// Gives text views a monospace face: GTK's own monospace switch elsewhere, and a Cascadia/Consolas
// stack on Windows where the generic monospace alias resolves poorly.
public class WindowsMonospace { // LCOV_EXCL_LINE: declaration-only coverage artifact
    private const string CSS_CLASS = "holder-windows-monospace";
    internal static bool css_installed = false;

    [CCode(cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
    private static extern void gtk_style_context_add_provider_for_display(
        Gdk.Display display,
        Gtk.StyleProvider provider,
        uint priority
    );

    public static void apply(Gtk.TextView view) {
        apply_for_platform(view, Path.DIR_SEPARATOR_S == "\\", Gdk.Display.get_default());
    }

    // The platform and display are parameters so both branches can be exercised on any host.
    internal static void apply_for_platform(Gtk.TextView view, bool windows, Gdk.Display? display) {
        if (!windows) {
            view.set_monospace(true);
            return;
        }

        ensure_css(display);
        view.add_css_class(CSS_CLASS);
    }

    private static void ensure_css(Gdk.Display? display) {
        if (css_installed) {
            return;
        }
        if (display == null) {
            return;
        }

        var provider = new Gtk.CssProvider();
        provider.load_from_string("""
.holder-windows-monospace,
.holder-windows-monospace text {
  font-family: "Cascadia Mono", "Consolas", monospace;
}
""");
        gtk_style_context_add_provider_for_display(
            display,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
        css_installed = true;
    }
}

}
