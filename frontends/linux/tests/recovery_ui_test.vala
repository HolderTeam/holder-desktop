using GLib;

namespace HolderLinux {

internal errordomain TestRecoveryError {
    FAILED
}

public class Project : Object {
    public string project_id { get; construct; }
    public string name { get; construct; }

    public Project(string project_id, string name) {
        Object(project_id: project_id, name: name);
    }
}

public class RecoveryTokenImportResult : Object {
    public string project_id { get; construct; }
    public bool project_created { get; construct; }
    public bool remote_hint_present { get; construct; }
    public bool remote_configured { get; construct; }
    public string pull_status { get; construct; }
    public string pull_error { get; construct; }
    public string remote_error { get; construct; }

    public RecoveryTokenImportResult(string project_id,
                                     bool project_created,
                                     bool remote_hint_present,
                                     bool remote_configured,
                                     string pull_status,
                                     string pull_error,
                                     string remote_error) {
        Object(
            project_id: project_id,
            project_created: project_created,
            remote_hint_present: remote_hint_present,
            remote_configured: remote_configured,
            pull_status: pull_status,
            pull_error: pull_error,
            remote_error: remote_error
        );
    }
}

public class RecoveryController : Object {
    public string export_payload = "payload";
    public string default_filename = "recovery.txt";
    public string temp_attachment_path = "/tmp/recovery.txt";
    public string loaded_payload = "loaded";
    public HolderLinux.RecoveryTokenImportResult import_result =
        new HolderLinux.RecoveryTokenImportResult("proj-1", true, true, false, "", "", "");

    public Error? export_error = null;
    public Error? save_error = null;
    public Error? load_error = null;
    public Error? import_error = null;

    public int export_calls = 0;
    public int save_calls = 0;
    public int load_calls = 0;
    public int import_calls = 0;
    public int open_email_calls = 0;
    public string last_project_id = "";
    public string last_pin = "";
    public string last_project_name = "";
    public string last_path = "";
    public string last_payload = "";
    public string last_attachment_path = "";

    public async string export_recovery_token(string project_id, string pin) throws Error {
        export_calls++;
        last_project_id = project_id;
        last_pin = pin;
        if (export_error != null) {
            throw export_error;
        }
        return export_payload;
    }

    public string build_default_filename(string project_name) {
        last_project_name = project_name;
        return default_filename;
    }

    public string write_payload_to_temp_attachment(string project_name, string payload) throws Error {
        last_project_name = project_name;
        last_payload = payload;
        return temp_attachment_path;
    }

    public void open_email_with_attachment(string attachment_path) throws Error {
        open_email_calls++;
        last_attachment_path = attachment_path;
    }

    public void save_payload_to_path(string path, string payload) throws Error {
        save_calls++;
        last_path = path;
        last_payload = payload;
        if (save_error != null) {
            throw save_error;
        }
    }

    public string load_payload_from_path(string path) throws Error {
        load_calls++;
        last_path = path;
        if (load_error != null) {
            throw load_error;
        }
        return loaded_payload;
    }

    public async HolderLinux.RecoveryTokenImportResult import_recovery_token(string pin, string payload) throws Error {
        import_calls++;
        last_pin = pin;
        last_payload = payload;
        if (import_error != null) {
            throw import_error;
        }
        return import_result;
    }
}

}

namespace HolderLinux.Tests {

private class BoolFlag : Object {
    public bool value = false;
}

private void wait_for_bool(BoolFlag done) {
    var loop = new MainLoop();
    Timeout.add(10, () => {
        if (done.value) {
            loop.quit();
            return Source.REMOVE;
        }
        return Source.CONTINUE;
    });
    Timeout.add(2000, () => {
        assert_not_reached();
    });
    loop.run();
}

private void test_validate_pin_and_export_prepare_behaviour() {
    var recovery = new HolderLinux.RecoveryController();
    var controller = new HolderLinux.RecoveryUiController(recovery);
    string? last_toast = null;
    string? error_title = null;
    string? error_details = null;
    controller.toast_requested.connect((message) => { last_toast = message; });
    controller.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });

    assert(!controller.validate_pin("   "));
    assert(last_toast == "PIN is required.");
    assert(controller.validate_pin("1234"));

    var export_no_project_done = new BoolFlag();
    controller.export_for_email.begin(null, "1234", (obj, res) => {
        controller.export_for_email.end(res);
        export_no_project_done.value = true;
    });
    wait_for_bool(export_no_project_done);
    assert(last_toast == "Select a project first.");

    var project = new HolderLinux.Project("proj-1", "Demo");
    var export_done = new BoolFlag();
    controller.export_for_email.begin(project, "1234", (obj, res) => {
        controller.export_for_email.end(res);
        export_done.value = true;
    });
    wait_for_bool(export_done);
    assert(recovery.export_calls == 1);
    assert(recovery.open_email_calls == 1);
    assert(last_toast == "Opened default email app with recovery key attachment.");

    recovery.export_error = new HolderLinux.TestRecoveryError.FAILED("email export failed");
    var export_error_done = new BoolFlag();
    controller.export_for_email.begin(project, "1234", (obj, res) => {
        controller.export_for_email.end(res);
        export_error_done.value = true;
    });
    wait_for_bool(export_error_done);
    assert(error_title == "Recovery key email failed");
    assert(error_details == "email export failed");

    var prepare_no_project_done = new BoolFlag();
    HolderLinux.RecoverySavePreparation? prep = null;
    controller.prepare_export_save.begin(null, "1234", (obj, res) => {
        prep = controller.prepare_export_save.end(res);
        prepare_no_project_done.value = true;
    });
    wait_for_bool(prepare_no_project_done);
    assert(prep == null);
    assert(last_toast == "Select a project first.");

    recovery.export_error = new HolderLinux.TestRecoveryError.FAILED("export failed");
    var prepare_done = new BoolFlag();
    controller.prepare_export_save.begin(project, "1234", (obj, res) => {
        prep = controller.prepare_export_save.end(res);
        prepare_done.value = true;
    });
    wait_for_bool(prepare_done);
    assert(prep == null);
    assert(error_title == "Recovery key export failed");
    assert(error_details == "export failed");

    recovery.export_error = null;
    var prepare_ok_done = new BoolFlag();
    controller.prepare_export_save.begin(project, "1234", (obj, res) => {
        prep = controller.prepare_export_save.end(res);
        prepare_ok_done.value = true;
    });
    wait_for_bool(prepare_ok_done);
    assert(prep != null);
    assert(((!) prep).payload == "payload");
    assert(((!) prep).default_filename == "recovery.txt");
}

private void test_save_load_import_and_summary_behaviour() {
    var recovery = new HolderLinux.RecoveryController();
    var controller = new HolderLinux.RecoveryUiController(recovery);
    string? last_toast = null;
    string? error_title = null;
    string? error_details = null;
    controller.toast_requested.connect((message) => { last_toast = message; });
    controller.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });

    controller.save_payload_to_path("   ", "payload");
    assert(error_title == "Recovery key export failed");
    assert(error_details == "Please choose a local filesystem path.");

    recovery.save_error = new HolderLinux.TestRecoveryError.FAILED("save failed");
    controller.save_payload_to_path("/tmp/out.txt", "payload");
    assert(error_details == "save failed");

    recovery.save_error = null;
    controller.save_payload_to_path("/tmp/out.txt", "payload");
    assert(last_toast == "Saved recovery key.");

    var loaded = controller.load_import_payload_from_path("   ");
    assert(loaded == null);
    assert(error_title == "Recovery key import failed");

    recovery.load_error = new HolderLinux.TestRecoveryError.FAILED("load failed");
    loaded = controller.load_import_payload_from_path("/tmp/in.txt");
    assert(loaded == null);
    assert(error_details == "load failed");

    recovery.load_error = null;
    loaded = controller.load_import_payload_from_path("/tmp/in.txt");
    assert(loaded == "loaded");

    recovery.import_error = new HolderLinux.TestRecoveryError.FAILED("import failed");
    var import_fail_done = new BoolFlag();
    HolderLinux.RecoveryTokenImportResult? import_result = null;
    controller.import_payload.begin("1234", "token", (obj, res) => {
        import_result = controller.import_payload.end(res);
        import_fail_done.value = true;
    });
    wait_for_bool(import_fail_done);
    assert(import_result == null);
    assert(error_details == "import failed");

    recovery.import_error = null;
    recovery.import_result = new HolderLinux.RecoveryTokenImportResult(
        "proj-9", true, false, true, "pulled", "", "remote down"
    );
    var import_ok_done = new BoolFlag();
    controller.import_payload.begin("1234", "token", (obj, res) => {
        import_result = controller.import_payload.end(res);
        import_ok_done.value = true;
    });
    wait_for_bool(import_ok_done);
    assert(import_result != null);

    var summary = controller.import_summary_body((!) import_result);
    assert(summary.index_of("Project ID: proj-9") >= 0);
    assert(summary.index_of("Project created: yes") >= 0);
    assert(summary.index_of("Remote hint in key: no") >= 0);
    assert(summary.index_of("Remote configured: yes") >= 0);
    assert(summary.index_of("Pull status: pulled") >= 0);
    assert(summary.index_of("Pull error: none") >= 0);
    assert(summary.index_of("Remote error: remote down") >= 0);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/recovery-ui/validate-pin-and-export-prepare-behaviour", test_validate_pin_and_export_prepare_behaviour);
    Test.add_func("/holder/recovery-ui/save-load-import-and-summary-behaviour", test_save_load_import_and_summary_behaviour);
    return Test.run();
}

}
