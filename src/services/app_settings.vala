namespace HolderLinux {

public class AppSettings : Object {
    public delegate void WarningSink(string message);
    public const string SCHEMA_ID = "team.holder.Holder";
    public const string KEY_STYLE_VARIANT = "style-variant";
    public const string KEY_STYLE_SCHEME_ID = "style-scheme-id";
    public const string KEY_USE_CUSTOM_EDITOR_FONT = "use-custom-editor-font";
    public const string KEY_CUSTOM_EDITOR_FONT = "custom-editor-font";
    public const string KEY_SHOW_LINE_NUMBERS = "show-line-numbers";
    public const string KEY_SHOW_SPELL_CHECKING = "show-spell-checking";
    public const string KEY_PRESERVE_TRAILING_WHITESPACE = "preserve-trailing-whitespace";
    public const string KEY_TRIM_TWO_SPACE_HARD_BREAKS = "trim-two-space-hard-breaks";
    public const string KEY_TRIM_WHITESPACE_IN_CODE_BLOCKS = "trim-whitespace-in-code-blocks";
    public const string KEY_WINDOW_WIDTH = "window-width";
    public const string KEY_WINDOW_HEIGHT = "window-height";
    public const string KEY_WINDOW_MAXIMIZED = "window-maximized";
    public const string KEY_SIDEBAR_WIDTH = "sidebar-width";
    public const string KEY_AI_PANEL_WIDTH = "ai-panel-width";
    public const string KEY_ASSET_PREVIEW_WIDTH = "asset-preview-width";
    public const string KEY_TINY_CLOSE_STREAK = "tiny-close-streak";
    public const string KEY_CUSTOM_CARD_LINK_KINDS = "custom-card-link-kinds";
    public const string KEY_GIT_GITHUB_USERNAME = "git-github-username";
    public const string KEY_UPDATE_LAST_CHECK_AT = "update-last-check-at";
    public const string KEY_UPDATE_LAST_PROMPT_VERSION = "update-last-prompt-version";
    public const string KEY_UPDATE_LAST_PROMPT_AT = "update-last-prompt-at";
    public const string KEY_TERMINAL_POWERSHELL_PATH = "terminal-powershell-path";
    public const string KEY_TERMINAL_POWERSHELL_VERSION = "terminal-powershell-version";
    public const string KEY_TERMINAL_WINDOWS_TERMINAL_PATH = "terminal-windows-terminal-path";
    public const string KEY_TERMINAL_WINGET_PATH = "terminal-winget-path";
    private const string GNOME_INTERFACE_SCHEMA_ID = "org.gnome.desktop.interface";
    private const string GNOME_COLOR_SCHEME_KEY = "color-scheme";
    private static WarningSink? warning_sink = null;
    internal static bool force_read_link_failure_for_tests = false;
    internal static bool skip_default_schema_lookup_for_tests = false;
    internal static bool force_schema_source_null_for_tests = false;
    internal static bool force_gnome_schema_missing_for_tests = false;

    private static SettingsSchemaSource? resolve_schema_source() {
        if (force_schema_source_null_for_tests) {
            return null;
        }
        return SettingsSchemaSource.get_default();
    }

    private static SettingsSchema? lookup_gnome_interface_schema(SettingsSchemaSource source) {
        if (force_gnome_schema_missing_for_tests) {
            return null;
        }
        return source.lookup(GNOME_INTERFACE_SCHEMA_ID, true);
    }

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

    public static Adw.ColorScheme gnome_color_scheme_to_color_scheme(string value) {
        switch (value) {
        case "prefer-dark":
            return Adw.ColorScheme.FORCE_DARK;
        case "prefer-light":
            return Adw.ColorScheme.FORCE_LIGHT;
        default:
            return Adw.ColorScheme.DEFAULT;
        }
    }

    public static Adw.ColorScheme resolve_default_color_scheme() {
        var source = resolve_schema_source();
        if (source == null) {
            return Adw.ColorScheme.DEFAULT;
        }

        var schema = lookup_gnome_interface_schema(source);
        if (schema == null) {
            return Adw.ColorScheme.DEFAULT;
        }

        var settings = new Settings.full(schema, null, null);
        return gnome_color_scheme_to_color_scheme(settings.get_string(GNOME_COLOR_SCHEME_KEY));
    }

    public static Adw.ColorScheme effective_color_scheme_for_key(string value) {
        var configured = key_to_color_scheme(value);
        if (configured != Adw.ColorScheme.DEFAULT) {
            return configured;
        }
        return resolve_default_color_scheme();
    }
}

}
