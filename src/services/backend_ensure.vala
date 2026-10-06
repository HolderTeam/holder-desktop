namespace HolderLinux {

// Runs a program with no console window and returns its standard output and error together. GLib's
// spawn functions show a console window for a console program run from a GUI program on Windows,
// and this does not. It returns when the program exits, whether or not a child it started is still
// holding its output open (the daemon that holderctl starts is exactly that).
[CCode (cname = "holder_windows_capture_async", finish_name = "holder_windows_capture_finish")]
private extern static async string capture_hidden_command(
    [CCode (array_length = false, array_null_terminated = true)] string[] argv,
    out int exit_code
) throws Error;

[CCode (cname = "holder_windows_program_directory")]
private extern static string? windows_program_directory();

[CCode (cname = "holder_macos_program_directory")]
private extern static string? macos_program_directory();

// Makes sure a compatible daemon is running by running `holderctl ensure`, which knows how to
// start one on each platform and reports through one JSON object and its exit status
// (daemon/docs/ensure.md in holder-framework). A daemon started this way stops itself after
// IDLE_EXIT_SECONDS without a client; an already-running daemon, such as the Linux systemd
// service, is left as it is.
public class BackendEnsure : Object, IBackendStarter {
    // Long enough to ride out a restart of the window or a dropped event stream.
    public const int IDLE_EXIT_SECONDS = 60;

    private string holderctl_path;

    public BackendEnsure(string holderctl_path) {
        this.holderctl_path = holderctl_path;
    }

    public static string[] build_command(string holderctl_path,
                                         string api_min,
                                         string api_max_exclusive,
                                         int idle_exit_seconds) {
        string[] command = { holderctl_path, "ensure", "--json" };
        if (api_min != "") {
            command += "--api-min";
            command += api_min;
        }
        if (api_max_exclusive != "") {
            command += "--api-max-exclusive";
            command += api_max_exclusive;
        }
        command += "--idle-exit";
        command += idle_exit_seconds.to_string();
        return command;
    }

    // Windows only treats files with an executable extension as programs.
    public static string program_file_name() {
        return Path.DIR_SEPARATOR_S == "\\" ? "holderctl.exe" : "holderctl";
    }

    // Finds holderctl: the HOLDER_CTL override when it names an executable (for running from a
    // source tree), then beside the running program (where the packages install both), then in a
    // macOS bundle's Contents/Resources/bin when the program is Contents/MacOS/*, then on PATH.
    public static string? locate_holderctl(string? program_dir, string? on_path, string? override_path = null) {
        if (override_path != null && (!) override_path != ""
            && FileUtils.test((!) override_path, FileTest.IS_EXECUTABLE)) {
            return override_path;
        }
        if (program_dir != null) {
            var beside = Path.build_filename((!) program_dir, program_file_name());
            if (FileUtils.test(beside, FileTest.IS_EXECUTABLE)) {
                return beside;
            }
            // A macOS app bundle whose main executable is the desktop (Contents/MacOS) keeps
            // holderctl with the other tools, in Contents/Resources/bin.
            var contents = Path.get_dirname((!) program_dir);
            if (Path.get_basename((!) program_dir) == "MacOS" && Path.get_basename(contents) == "Contents") {
                var in_bundle = Path.build_filename(contents, "Resources", "bin", program_file_name());
                if (FileUtils.test(in_bundle, FileTest.IS_EXECUTABLE)) {
                    return in_bundle;
                }
            }
        }
        return on_path;
    }

    // The directory this program runs from, or null if the system cannot say.
    public static string? program_directory() {
        if (Path.DIR_SEPARATOR_S == "\\") {
            return windows_program_directory();
        }
        if (PLATFORM == "darwin") {
            return macos_program_directory();
        }
        try {
            return Path.get_dirname(FileUtils.read_link("/proc/self/exe"));
        } catch (FileError e) {
            debug("Cannot tell where this program is installed: %s", e.message);
            return null;
        }
    }

    public static string? locate_holderctl_for_this_program() {
        return locate_holderctl(
            program_directory(),
            Environment.find_program_in_path("holderctl"),
            Environment.get_variable("HOLDER_CTL")
        );
    }

    // Reads the single JSON object `holderctl ensure --json` prints. Invalid options leave
    // standard output empty and put the error on standard error, so the exit status and standard
    // error are the fallback.
    public static EnsureOutcome parse_result(string stdout_text, string stderr_text, int exit_status) {
        var parser = new Json.Parser();
        try {
            parser.load_from_data(stdout_text);
            var root = parser.get_root();
            if (root != null && ((!) root).get_node_type() == Json.NodeType.OBJECT) {
                var object = ((!) root).get_object();
                var ok = object.has_member("ok") && object.get_boolean_member("ok");
                var state = object.has_member("state") ? object.get_string_member("state") : "failed";
                var message = "";
                if (object.has_member("error")) {
                    var error = object.get_object_member("error");
                    if (error.has_member("message")) {
                        message = error.get_string_member("message");
                    }
                }
                if (!ok && message == "") {
                    message = "holderctl ensure failed (exit status %d)".printf(exit_status);
                }
                return new EnsureOutcome(ok && exit_status == 0, state, message);
            }
        } catch (Error e) {
            debug("holderctl ensure printed no usable JSON: %s", e.message);
        }
        var detail = stderr_text.strip();
        if (detail == "") {
            detail = "holderctl ensure exited with status %d".printf(exit_status);
        }
        return new EnsureOutcome(false, "failed", detail);
    }

    public async EnsureOutcome ensure() throws Error {
        var command = build_command(holderctl_path, DAEMON_API_MIN, DAEMON_API_MAX_EXCLUSIVE, IDLE_EXIT_SECONDS);
        string? out_text = null;
        string? err_text = null;
        int status = -1;
        if (Path.DIR_SEPARATOR_S == "\\") {
            // Standard output and error arrive together, which parse_result copes with: the JSON
            // object is on one of them, and an options error prints only that.
            out_text = yield capture_hidden_command(command, out status);
            err_text = "";
        } else {
            var process = new Subprocess.newv(command, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            yield process.communicate_utf8_async(null, null, out out_text, out err_text);
            status = process.get_if_exited() ? process.get_exit_status() : -1;
        }
        var outcome = parse_result(out_text ?? "", err_text ?? "", status);
        var details = "%s (exit status %d)".printf(string.joinv(" ", command), status);
        var stderr_text = (err_text ?? "").strip();
        if (stderr_text != "") {
            details += "; stderr: " + stderr_text;
        }
        return new EnsureOutcome(outcome.ok, outcome.state, outcome.message, details);
    }
}

}
