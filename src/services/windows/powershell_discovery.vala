namespace HolderLinux {

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
    public virtual string? find_program(string name) {
        return Environment.find_program_in_path(name);
    }

    public virtual string? get_environment_variable(string name) {
        return Environment.get_variable(name);
    }

    public virtual bool path_exists(string path) {
        return FileUtils.test(path, FileTest.EXISTS);
    }

    public virtual async PowerShellPrerequisites discover() {
        var pwsh_path = find_powershell();
        var wt_path = find_windows_app("wt.exe", "wt");
        var winget_path = find_windows_app("winget.exe", "winget");

        if (pwsh_path == null) {
            return new PowerShellPrerequisites(
                PowerShellPrerequisiteStatus.POWERSHELL_MISSING,
                null,
                null,
                wt_path,
                winget_path
            );
        }

        string version;
        try {
            version = yield query_version((!) pwsh_path);
        } catch (Error e) {
            return new PowerShellPrerequisites(
                PowerShellPrerequisiteStatus.POWERSHELL_QUERY_FAILED,
                pwsh_path,
                null,
                wt_path,
                winget_path,
                e.message
            );
        }

        var major = parse_major_version(version);
        if (major < 7) {
            return new PowerShellPrerequisites(
                PowerShellPrerequisiteStatus.POWERSHELL_UNSUPPORTED,
                pwsh_path,
                version,
                wt_path,
                winget_path,
                "Holder requires PowerShell 7 or newer."
            );
        }
        if (wt_path == null) {
            return new PowerShellPrerequisites(
                PowerShellPrerequisiteStatus.WINDOWS_TERMINAL_MISSING,
                pwsh_path,
                version,
                null,
                winget_path
            );
        }
        return new PowerShellPrerequisites(
            PowerShellPrerequisiteStatus.READY,
            pwsh_path,
            version,
            wt_path,
            winget_path
        );
    }

    internal string? find_powershell() {
        var discovered = find_program("pwsh.exe") ?? find_program("pwsh");
        if (discovered != null) {
            return discovered;
        }

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
                return candidate;
            }
        }

        return windows_apps_path("pwsh.exe");
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
            throw new IOError.INVALID_DATA("PowerShell returned an invalid version: %s".printf(version));
        }
        return version;
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
