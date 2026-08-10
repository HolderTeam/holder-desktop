namespace HolderLinux {

public interface IRecoveryService : Object {
    public abstract string build_safe_filename(string project_name);
    public abstract string write_payload_to_temp_attachment(string project_name, string payload) throws Error;
    public abstract void open_email_with_attachment(string attachment_path) throws Error;
    public abstract void save_payload_to_path(string path, string payload) throws Error;
    public abstract string load_payload_from_path(string path) throws Error;
}

public class RecoveryService : Object, IRecoveryService {
    public string build_safe_filename(string project_name) {
        return "%s-recovery.hrk".printf(project_name.replace(" ", "-"));
    }

    public string write_payload_to_temp_attachment(string project_name, string payload) throws Error {
        if (payload.strip().length == 0) {
            throw new IOError.FAILED("Empty recovery token payload.");
        }

        string tmp_dir;
        try {
            tmp_dir = DirUtils.make_tmp("holder-recovery-key-XXXXXX");
        } catch (FileError e) {
            throw new IOError.FAILED("Could not create temporary directory: %s".printf(e.message)); // LCOV_EXCL_LINE GCOVR_EXCL_LINE: direct OS temp-dir failure wrapper
        }

        var attachment_path = Path.build_filename(tmp_dir, build_safe_filename(project_name));
        try {
            FileUtils.set_contents(attachment_path, payload);
        } catch (FileError e) {
            throw new IOError.FAILED("Could not create attachment: %s".printf(e.message)); // LCOV_EXCL_LINE GCOVR_EXCL_LINE: direct OS file-create failure wrapper
        }

        return attachment_path;
    }

    public void open_email_with_attachment(string attachment_path) throws Error {
        if (Path.DIR_SEPARATOR_S == "\\") {
            throw new IOError.NOT_SUPPORTED("Email attachments are not supported on this platform yet.");
        }

        string[] argv = {
            "xdg-email",
            "--subject",
            "Holder Recovery Key",
            "--body",
            "See attachment",
            "--attach",
            attachment_path,
            null
        };

        Pid child_pid;
        Process.spawn_async(
            null,
            argv,
            null,
            SpawnFlags.SEARCH_PATH,
            null,
            out child_pid
        );
    }

    public void save_payload_to_path(string path, string payload) throws Error {
        if (path.strip().length == 0) {
            throw new IOError.FAILED("Please choose a local filesystem path.");
        }
        if (payload.strip().length == 0) {
            throw new IOError.FAILED("Empty recovery token payload.");
        }

        try {
            FileUtils.set_contents(path, payload);
        } catch (FileError e) {
            throw new IOError.FAILED(e.message);
        }
    }

    public string load_payload_from_path(string path) throws Error {
        if (path.strip().length == 0) {
            throw new IOError.FAILED("Please choose a local filesystem path.");
        }

        string payload;
        try {
            FileUtils.get_contents(path, out payload);
        } catch (FileError e) {
            throw new IOError.FAILED(e.message);
        }

        if (payload.strip().length == 0) {
            throw new IOError.FAILED("Selected file is empty.");
        }

        return payload;
    }
}

}
