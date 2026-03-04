namespace HolderLinux {

public class AppSettings : Object {
    public delegate void WarningSink(string message);
    public const string SCHEMA_ID = "io.holder.linux";
    public const string KEY_STYLE_VARIANT = "style-variant";
    public const string KEY_STYLE_SCHEME_ID = "style-scheme-id";
    public const string KEY_SHOW_LINE_NUMBERS = "show-line-numbers";
    public const string KEY_SHOW_SPELL_CHECKING = "show-spell-checking";
    public const string KEY_WINDOW_WIDTH = "window-width";
    public const string KEY_WINDOW_HEIGHT = "window-height";
    public const string KEY_WINDOW_MAXIMIZED = "window-maximized";
    public const string KEY_SIDEBAR_WIDTH = "sidebar-width";
    public const string KEY_TINY_CLOSE_STREAK = "tiny-close-streak";
    public const string KEY_CUSTOM_CARD_LINK_KINDS = "custom-card-link-kinds";
    public const string KEY_GIT_GITHUB_USERNAME = "git-github-username";
    private static WarningSink? warning_sink = null;
    internal static bool force_read_link_failure_for_tests = false;
    internal static bool skip_default_schema_lookup_for_tests = false;

    public static void set_warning_sink(owned WarningSink? sink) {
        warning_sink = (owned) sink;
    }

    private static void emit_warning(string message) {
        if (warning_sink != null) {
            warning_sink(message);
            return;
        }
        warning("%s", message);
    }

    public static Settings? open_or_null() {
        return open_or_null_for_executable_path(null);
    }

    public static Settings? open_or_null_for_executable_path(string? executable_path) {
        var default_source = SettingsSchemaSource.get_default();
        if (!skip_default_schema_lookup_for_tests && default_source != null) {
            var schema = default_source.lookup(SCHEMA_ID, true);
            if (schema != null) {
                return new Settings(SCHEMA_ID);
            }
        }

        var local_source = load_local_schema_source(default_source, executable_path);
        if (local_source == null) {
            emit_warning("GSettings schema '%s' not found; preferences will be session-only.".printf(SCHEMA_ID));
            return null;
        }

        var local_schema = local_source.lookup(SCHEMA_ID, false);
        if (local_schema == null) {
            emit_warning("Schema '%s' missing from local schema directory.".printf(SCHEMA_ID));
            return null;
        }

        return new Settings.full(local_schema, null, null);
    }

    public static string schema_candidate_dir_for_executable_path(string executable_path) {
        var exe_dir = Path.get_dirname(executable_path);
        return Path.build_filename(exe_dir, "data");
    }

    public static bool has_compiled_schema_in_dir(string candidate_dir) {
        var compiled_path = Path.build_filename(candidate_dir, "gschemas.compiled");
        return FileUtils.test(compiled_path, FileTest.EXISTS);
    }

    private static SettingsSchemaSource? load_local_schema_source(SettingsSchemaSource? parent,
                                                                  string? executable_path) {
        string resolved_exe_path;
        if (executable_path == null || executable_path.strip().length == 0) {
            try {
                if (force_read_link_failure_for_tests) {
                    throw new FileError.NOENT("forced read_link failure");
                }
                resolved_exe_path = FileUtils.read_link("/proc/self/exe");
            } catch (Error e) {
                return null;
            }
        } else {
            resolved_exe_path = executable_path;
        }

        var candidate_dir = schema_candidate_dir_for_executable_path(resolved_exe_path);
        if (!has_compiled_schema_in_dir(candidate_dir)) {
            return null;
        }

        try {
            return new SettingsSchemaSource.from_directory(candidate_dir, parent, false);
        } catch (Error e) {
            emit_warning("Failed to load schema dir '%s': %s".printf(candidate_dir, e.message));
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
