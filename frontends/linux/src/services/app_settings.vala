namespace HolderLinux {

public class AppSettings : Object {
    public const string SCHEMA_ID = "io.holder.linux";
    public const string KEY_STYLE_VARIANT = "style-variant";
    public const string KEY_STYLE_SCHEME_ID = "style-scheme-id";
    public const string KEY_SHOW_LINE_NUMBERS = "show-line-numbers";

    public static Settings? open_or_null() {
        var default_source = SettingsSchemaSource.get_default();
        if (default_source != null) {
            var schema = default_source.lookup(SCHEMA_ID, true);
            if (schema != null) {
                return new Settings(SCHEMA_ID);
            }
        }

        var local_source = load_local_schema_source(default_source);
        if (local_source == null) {
            warning("GSettings schema '%s' not found; preferences will be session-only.", SCHEMA_ID);
            return null;
        }

        var local_schema = local_source.lookup(SCHEMA_ID, false);
        if (local_schema == null) {
            warning("Schema '%s' missing from local schema directory.", SCHEMA_ID);
            return null;
        }

        return new Settings.full(local_schema, null, null);
    }

    private static SettingsSchemaSource? load_local_schema_source(SettingsSchemaSource? parent) {
        string exe_path;
        try {
            exe_path = FileUtils.read_link("/proc/self/exe");
        } catch (Error e) {
            return null;
        }

        var exe_dir = Path.get_dirname(exe_path);
        var candidate_dir = Path.build_filename(exe_dir, "data");
        var compiled_path = Path.build_filename(candidate_dir, "gschemas.compiled");

        if (!FileUtils.test(compiled_path, FileTest.EXISTS)) {
            return null;
        }

        try {
            return new SettingsSchemaSource.from_directory(candidate_dir, parent, false);
        } catch (Error e) {
            warning("Failed to load schema dir '%s': %s", candidate_dir, e.message);
            return null;
        }
    }

    public static string color_scheme_to_key(Adw.ColorScheme scheme) {
        switch (scheme) {
        case Adw.ColorScheme.FORCE_LIGHT:
            return "force-light";
        case Adw.ColorScheme.FORCE_DARK:
            return "force-dark";
        default:
            return "default";
        }
    }

    public static Adw.ColorScheme key_to_color_scheme(string value) {
        switch (value) {
        case "force-light":
            return Adw.ColorScheme.FORCE_LIGHT;
        case "force-dark":
            return Adw.ColorScheme.FORCE_DARK;
        default:
            return Adw.ColorScheme.DEFAULT;
        }
    }
}

}
