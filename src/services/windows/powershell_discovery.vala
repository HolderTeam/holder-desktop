namespace HolderLinux {

[CCode (cname = "holder_windows_run_hidden")]
private extern static bool run_windows_process_hidden(
    string executable,
    string command_line,
    out int exit_code
) throws Error;

public enum PowerShellPrerequisiteStatus {
    READY,
    POWERSHELL_MISSING,
    POWERSHELL_UNSUPPORTED,
    POWERSHELL_QUERY_FAILED,
    WINDOWS_TERMINAL_MISSING
}

public class PowerShellPrerequisites : Object {
    public PowerShellPrerequisiteStatus status { get; construct; }
    public string? powershell_path { get; construct; }
    public string? powershell_version { get; construct; }
    public string? windows_terminal_path { get; construct; }
    public string? winget_path { get; construct; }
    public string details { get; construct; }

    public bool ready {
        get { return status == PowerShellPrerequisiteStatus.READY; }
    }

    public PowerShellPrerequisites(PowerShellPrerequisiteStatus status,
                                   string? powershell_path,
                                   string? powershell_version,
                                   string? windows_terminal_path,
                                   string? winget_path,
                                   string details = "") {
        Object(
            status: status,
            powershell_path: powershell_path,
            powershell_version: powershell_version,
            windows_terminal_path: windows_terminal_path,
            winget_path: winget_path,
            details: details
        );
    }
}

public class PowerShellDiscoveryService : Object {
    private Settings? settings;

    public PowerShellDiscoveryService(Settings? settings = null) {
        this.settings = settings;
    }

    public virtual string? find_program(string name) {
        return Environment.find_program_in_path(name);
    }

    public virtual string? get_environment_variable(string name) {
        return Environment.get_variable(name);
    }

    public virtual bool path_exists(string path) {
        return FileUtils.test(path, FileTest.EXISTS);
    }

    public virtual async PowerShellPrerequisites discover(bool force_refresh = false) {
        if (!force_refresh) {
            var cached = load_cached_prerequisites();
            if (cached != null) {
                return (!) cached;
            }
        }

        var powershell_candidates = find_powershell_candidates();
        var wt_path = find_windows_app("wt.exe", "wt");
        var winget_path = find_windows_app("winget.exe", "winget");

        if (powershell_candidates.length == 0) {
            clear_cache();
            return new PowerShellPrerequisites(
                PowerShellPrerequisiteStatus.POWERSHELL_MISSING,
                null,
                null,
                wt_path,
                winget_path
            );
        }

        string? pwsh_path = null;
        string? version = null;
        string query_details = "PowerShell version query failed.";
        foreach (var candidate in powershell_candidates) {
            try {
                version = yield query_version(candidate);
                pwsh_path = candidate;
                break;
            } catch (Error e) {
                query_details = "%s: %s".printf(candidate, e.message);
            }
        }
        if (pwsh_path == null || version == null) {
            clear_cache();
            return new PowerShellPrerequisites(
                PowerShellPrerequisiteStatus.POWERSHELL_QUERY_FAILED,
                powershell_candidates[0],
                null,
                wt_path,
                winget_path,
                query_details
            );
        }

        var major = parse_major_version((!) version);
        if (major < 7) {
            clear_cache();
            return new PowerShellPrerequisites(
                PowerShellPrerequisiteStatus.POWERSHELL_UNSUPPORTED,
                pwsh_path,
                (!) version,
                wt_path,
                winget_path,
                "Holder requires PowerShell 7 or newer."
            );
        }
        if (wt_path == null) {
            clear_cache();
            return new PowerShellPrerequisites(
                PowerShellPrerequisiteStatus.WINDOWS_TERMINAL_MISSING,
                pwsh_path,
                (!) version,
                null,
                winget_path
            );
        }
        var result = new PowerShellPrerequisites(
            PowerShellPrerequisiteStatus.READY,
            pwsh_path,
            (!) version,
            wt_path,
            winget_path
        );
        save_cache(result);
        return result;
    }

    internal PowerShellPrerequisites? load_cached_prerequisites() {
        if (settings == null) {
            return null;
        }
        var current = (!) settings;
        var powershell_path = current.get_string(AppSettings.KEY_TERMINAL_POWERSHELL_PATH);
        var version = current.get_string(AppSettings.KEY_TERMINAL_POWERSHELL_VERSION);
        var terminal_path = current.get_string(AppSettings.KEY_TERMINAL_WINDOWS_TERMINAL_PATH);
        if (powershell_path.length == 0
            || terminal_path.length == 0
            || parse_major_version(version) < 7
            || !path_exists(powershell_path)
            || !path_exists(terminal_path)) {
            clear_cache();
            return null;
        }
        var winget_path = current.get_string(AppSettings.KEY_TERMINAL_WINGET_PATH);
        if (winget_path.length == 0 || !path_exists(winget_path)) {
            winget_path = "";
        }
        return new PowerShellPrerequisites(
            PowerShellPrerequisiteStatus.READY,
            powershell_path,
            version,
            terminal_path,
            winget_path.length > 0 ? winget_path : null
        );
    }

    private void save_cache(PowerShellPrerequisites result) {
        if (settings == null || !result.ready) {
            return;
        }
        var current = (!) settings;
        current.set_string(AppSettings.KEY_TERMINAL_POWERSHELL_PATH, result.powershell_path ?? "");
        current.set_string(AppSettings.KEY_TERMINAL_POWERSHELL_VERSION, result.powershell_version ?? "");
        current.set_string(
            AppSettings.KEY_TERMINAL_WINDOWS_TERMINAL_PATH,
            result.windows_terminal_path ?? ""
        );
        current.set_string(AppSettings.KEY_TERMINAL_WINGET_PATH, result.winget_path ?? "");
    }

    public void clear_cache() {
        if (settings == null) {
            return;
        }
        var current = (!) settings;
        current.reset(AppSettings.KEY_TERMINAL_POWERSHELL_PATH);
        current.reset(AppSettings.KEY_TERMINAL_POWERSHELL_VERSION);
        current.reset(AppSettings.KEY_TERMINAL_WINDOWS_TERMINAL_PATH);
        current.reset(AppSettings.KEY_TERMINAL_WINGET_PATH);
    }

    internal string[] find_powershell_candidates() {
        var candidates = new Gee.ArrayList<string>();

        string[] program_file_variables = {
            "ProgramFiles",
            "ProgramW6432",
            "ProgramFiles(x86)"
        };
        foreach (var variable in program_file_variables) {
            var base_dir = get_environment_variable(variable);
            if (base_dir == null || ((!) base_dir).strip().length == 0) {
                continue;
            }
            var candidate = Path.build_filename((!) base_dir, "PowerShell", "7", "pwsh.exe");
            if (path_exists(candidate)) {
                add_unique_candidate(candidates, candidate);
            }
        }

        var discovered = find_program("pwsh.exe") ?? find_program("pwsh");
        if (discovered != null) {
            add_unique_candidate(candidates, (!) discovered);
        }

        var windows_apps = windows_apps_path("pwsh.exe");
        if (windows_apps != null) {
            add_unique_candidate(candidates, (!) windows_apps);
        }
        return candidates.to_array();
    }

    private static void add_unique_candidate(
        Gee.ArrayList<string> candidates,
        string candidate
    ) {
        foreach (var existing in candidates) {
            if (existing.down() == candidate.down()) {
                return;
            }
        }
        candidates.add(candidate);
    }

    internal string? find_windows_app(string executable_name, string path_name) {
        var discovered = find_program(executable_name) ?? find_program(path_name);
        return discovered ?? windows_apps_path(executable_name);
    }

    private string? windows_apps_path(string executable_name) {
        var local_app_data = get_environment_variable("LOCALAPPDATA");
        if (local_app_data == null || ((!) local_app_data).strip().length == 0) {
            return null;
        }
        var candidate = Path.build_filename(
            (!) local_app_data,
            "Microsoft",
            "WindowsApps",
            executable_name
        );
        return path_exists(candidate) ? candidate : null;
    }

    public virtual async string query_version(string powershell_path) throws Error {
        if (is_windows_apps_alias(powershell_path)) {
            return yield query_version_through_file(powershell_path);
        }
        var process = new Subprocess.newv(
            {
                powershell_path,
                "-NoLogo",
                "-NoProfile",
                "-NonInteractive",
                "-Command",
                "$PSVersionTable.PSVersion.ToString()"
            },
            SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE
        );
        string? stdout_text = null;
        string? stderr_text = null;
        yield process.communicate_utf8_async(
            null,
            null,
            out stdout_text,
            out stderr_text
        );
        if (!process.get_successful()) {
            var details = (stderr_text ?? "").strip();
            if (details.length == 0) {
                details = "PowerShell version query failed.";
            }
            throw new IOError.FAILED(details);
        }
        var version = (stdout_text ?? "").strip();
        if (parse_major_version(version) < 0) {
            return yield query_version_through_file(powershell_path);
        }
        return version;
    }

    private async string query_version_through_file(string powershell_path) throws Error {
        var temp_dir = DirUtils.make_tmp("holder-pwsh-version-XXXXXX");
        var output_path = Path.build_filename(temp_dir, "version.txt");
        try {
            var escaped_output_path = output_path.replace("'", "''");
            var script = "[IO.File]::WriteAllText('%s', $PSVersionTable.PSVersion.ToString())".printf(
                escaped_output_path
            );
            var command_line = "\"%s\" -NoLogo -NoProfile -NonInteractive -Command \"%s\"".printf(
                powershell_path,
                script
            );
            int exit_code;
            run_windows_process_hidden(powershell_path, command_line, out exit_code);
            if (exit_code != 0) {
                throw new IOError.FAILED(
                    "PowerShell version query exited with status %d.".printf(exit_code)
                );
            }
            string version;
            try {
                FileUtils.get_contents(output_path, out version);
            } catch (FileError e) {
                throw new IOError.INVALID_DATA(
                    "PowerShell returned no version output: %s".printf(e.message)
                );
            }
            version = version.strip();
            if (parse_major_version(version) < 0) {
                throw new IOError.INVALID_DATA(
                    "PowerShell returned an invalid version: %s".printf(version)
                );
            }
            return version;
        } finally {
            FileUtils.remove(output_path);
            DirUtils.remove(temp_dir);
        }
    }

    internal static bool is_windows_apps_alias(string path) {
        var normalised = path.replace("/", "\\").down();
        return normalised.contains("\\microsoft\\windowsapps\\");
    }

    internal static int parse_major_version(string? version) {
        if (version == null) {
            return -1;
        }
        var trimmed = ((!) version).strip();
        if (trimmed.length == 0) {
            return -1;
        }
        var pieces = trimmed.split(".", 2);
        if (pieces.length == 0 || pieces[0].length == 0) {
            return -1;
        }
        for (int i = 0; i < pieces[0].length; i++) {
            if (!pieces[0][i].isdigit()) {
                return -1;
            }
        }
        return int.parse(pieces[0]);
    }
}

}
