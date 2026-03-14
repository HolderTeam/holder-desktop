namespace HolderLinux {

internal class RecoverySavePreparation : Object {
    public string payload { get; construct; }
    public string default_filename { get; construct; }

    public RecoverySavePreparation(string payload, string default_filename) {
        Object(payload: payload, default_filename: default_filename);
    }
}

internal class RecoveryUiController : Object {
    private RecoveryController recovery_controller;

    public signal void toast_requested(string message);
    public signal void error_reported(string title, string details);

    public RecoveryUiController(RecoveryController recovery_controller) {
        this.recovery_controller = recovery_controller;
    }

    public bool validate_pin(string pin) {
        if (pin.strip().length > 0) {
            return true;
        }
        toast_requested("PIN is required.");
        return false;
    }

    public async void export_for_email(Project? project, string pin) {
        if (project == null) {
            toast_requested("Select a project first.");
            return;
        }
        try {
            var payload = yield recovery_controller.export_recovery_token(project.project_id, pin);
            var attachment_path = recovery_controller.write_payload_to_temp_attachment(project.name, payload);
            recovery_controller.open_email_with_attachment(attachment_path);
            toast_requested("Opened default email app with recovery key attachment.");
        } catch (Error e) {
            error_reported("Recovery key email failed", e.message);
        }
    }

    public async RecoverySavePreparation? prepare_export_save(Project? project, string pin) {
        if (project == null) {
            toast_requested("Select a project first.");
            return null;
        }
        try {
            var payload = yield recovery_controller.export_recovery_token(project.project_id, pin);
            return new RecoverySavePreparation(
                payload,
                recovery_controller.build_default_filename(project.name)
            );
        } catch (Error e) {
            error_reported("Recovery key export failed", e.message);
            return null;
        }
    }

    public void save_payload_to_path(string? path, string payload) {
        if (path == null || path.strip().length == 0) {
            error_reported(
                "Recovery key export failed",
                "Please choose a local filesystem path."
            );
            return;
        }
        try {
            recovery_controller.save_payload_to_path(path, payload);
            toast_requested("Saved recovery key.");
        } catch (Error e) {
            error_reported("Recovery key export failed", e.message);
        }
    }

    public string? load_import_payload_from_path(string? path) {
        if (path == null || path.strip().length == 0) {
            error_reported(
                "Recovery key import failed",
                "Please choose a local filesystem path."
            );
            return null;
        }
        try {
            return recovery_controller.load_payload_from_path(path);
        } catch (Error e) {
            error_reported("Recovery key import failed", e.message);
            return null;
        }
    }

    public async RecoveryTokenImportResult? import_payload(string pin, string recovery_token) {
        try {
            return yield recovery_controller.import_recovery_token(pin, recovery_token);
        } catch (Error e) {
            error_reported("Recovery key import failed", e.message);
            return null;
        }
    }

    public string import_summary_body(RecoveryTokenImportResult result) {
        var project_created_text = result.project_created ? "yes" : "no";
        var remote_hint_text = result.remote_hint_present ? "yes" : "no";
        var remote_configured_text = result.remote_configured ? "yes" : "no";
        var pull_status_text = result.pull_status.length > 0 ? result.pull_status : "not_attempted";
        var pull_error_text = result.pull_error.length > 0 ? result.pull_error : "none";
        var remote_error_text = result.remote_error.length > 0 ? result.remote_error : "none";

        return "Project ID: %s\n".printf(result.project_id) +
               "Project created: %s\n".printf(project_created_text) +
               "Remote hint in key: %s\n".printf(remote_hint_text) +
               "Remote configured: %s\n".printf(remote_configured_text) +
               "Pull status: %s\n".printf(pull_status_text) +
               "Pull error: %s\n".printf(pull_error_text) +
               "Remote error: %s".printf(remote_error_text);
    }
}

}
