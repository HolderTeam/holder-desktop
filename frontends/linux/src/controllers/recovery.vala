namespace HolderLinux {

public class RecoveryController : Object {
    private IRecoveryContext context;
    private IRecoveryService service;

    public RecoveryController(IRecoveryContext context, IRecoveryService? service = null) {
        this.context = context;
        this.service = service ?? new RecoveryService();
    }

    public async string export_recovery_token(string project_id, string pin) throws Error {
        var api = context.get_api_client();
        if (api == null) {
            throw new IOError.FAILED("API client not connected.");
        }

        var exported = yield api.export_project_recovery_token(project_id, pin);
        if (exported.recovery_token == null || exported.recovery_token.strip().length == 0) {
            throw new IOError.FAILED("Empty recovery token payload.");
        }

        return exported.recovery_token;
    }

    public string build_default_filename(string project_name) {
        return service.build_safe_filename(project_name);
    }

    public string write_payload_to_temp_attachment(string project_name, string payload) throws Error {
        return service.write_payload_to_temp_attachment(project_name, payload);
    }

    public void open_email_with_attachment(string attachment_path) throws Error {
        service.open_email_with_attachment(attachment_path);
    }

    public void save_payload_to_path(string path, string payload) throws Error {
        service.save_payload_to_path(path, payload);
    }

    public string load_payload_from_path(string path) throws Error {
        return service.load_payload_from_path(path);
    }

    public async RecoveryTokenImportResult import_recovery_token(string pin, string payload) throws Error {
        var api = context.get_api_client();
        if (api == null) {
            throw new IOError.FAILED("API client not connected.");
        }

        var result = yield api.import_recovery_token(pin, payload);
        yield context.reload_everything();
        return result;
    }
}

}
