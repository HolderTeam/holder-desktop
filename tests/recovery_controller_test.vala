using GLib;

namespace HolderLinuxTests {

private class FakeRecoveryService : Object, HolderLinux.IRecoveryService {
    public string last_project_name = "";
    public string last_payload = "";
    public string last_path = "";
    public string next_loaded_payload = "loaded";

    public string build_safe_filename(string project_name) {
        return "%s-safe.hrk".printf(project_name);
    }

    public string write_payload_to_temp_attachment(string project_name, string payload) throws Error {
        last_project_name = project_name;
        last_payload = payload;
        return "/tmp/fake.hrk";
    }

    public void open_email_with_attachment(string attachment_path) throws Error {
        last_path = attachment_path;
    }

    public void save_payload_to_path(string path, string payload) throws Error {
        last_path = path;
        last_payload = payload;
    }

    public string load_payload_from_path(string path) throws Error {
        last_path = path;
        return next_loaded_payload;
    }
}

private class FakeRecoveryContext : Object, HolderLinux.IRecoveryContext {
    public HolderLinux.IHolderApi? api;
    public int reload_calls = 0;

    public HolderLinux.IHolderApi? get_api_client() {
        return api;
    }

    public async void reload_everything() {
        reload_calls++;
    }
}

private void test_export_recovery_token_requires_api() {
    var context = new FakeRecoveryContext();
    var service = new FakeRecoveryService();
    var controller = new HolderLinux.RecoveryController(context, service);

    bool done = false;
    bool got_error = false;
    controller.export_recovery_token.begin("p1", "1234", (obj, res) => {
        try {
            controller.export_recovery_token.end(res);
        } catch (Error e) {
            got_error = e.message.contains("API client not connected");
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_error);
}

private void test_export_recovery_token_returns_payload() {
    var context = new FakeRecoveryContext();
    var api = new AiRunFakeApi();
    api.export_recovery_token_payload = "{\"token\":\"abc\"}";
    context.api = api;
    var service = new FakeRecoveryService();
    var controller = new HolderLinux.RecoveryController(context, service);

    bool done = false;
    string payload = "";
    controller.export_recovery_token.begin("p1", "1234", (obj, res) => {
        try {
            payload = controller.export_recovery_token.end(res);
        } catch (Error e) {
            payload = "";
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(payload == "{\"token\":\"abc\"}");
}

private void test_export_recovery_token_rejects_empty_payload() {
    var context = new FakeRecoveryContext();
    var api = new AiRunFakeApi();
    api.export_recovery_token_payload = "   ";
    context.api = api;
    var service = new FakeRecoveryService();
    var controller = new HolderLinux.RecoveryController(context, service);

    bool done = false;
    bool got_error = false;
    controller.export_recovery_token.begin("p1", "1234", (obj, res) => {
        try {
            controller.export_recovery_token.end(res);
        } catch (Error e) {
            got_error = e.message.contains("Empty recovery token payload");
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_error);
}

private void test_import_recovery_token_calls_reload() {
    var context = new FakeRecoveryContext();
    context.api = new AiRunFakeApi();
    var service = new FakeRecoveryService();
    var controller = new HolderLinux.RecoveryController(context, service);

    bool done = false;
    HolderLinux.RecoveryTokenImportResult? result = null;
    controller.import_recovery_token.begin("1234", "{\"token\":\"x\"}", (obj, res) => {
        try {
            result = controller.import_recovery_token.end(res);
        } catch (Error e) {
            result = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(result != null);
    assert(result.project_id == "p1");
    assert(context.reload_calls == 1);
}

private void test_import_recovery_token_requires_api() {
    var context = new FakeRecoveryContext();
    var service = new FakeRecoveryService();
    var controller = new HolderLinux.RecoveryController(context, service);

    bool done = false;
    bool got_error = false;
    controller.import_recovery_token.begin("1234", "{\"token\":\"x\"}", (obj, res) => {
        try {
            controller.import_recovery_token.end(res);
        } catch (Error e) {
            got_error = e.message.contains("API client not connected");
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_error);
    assert(context.reload_calls == 0);
}

private void test_service_passthrough_methods() {
    var context = new FakeRecoveryContext();
    var service = new FakeRecoveryService();
    var controller = new HolderLinux.RecoveryController(context, service);

    assert(controller.build_default_filename("Home") == "Home-safe.hrk");

    string attachment = "";
    try {
        attachment = controller.write_payload_to_temp_attachment("Home", "payload");
    } catch (Error e) {
        assert_not_reached();
    }
    assert(attachment == "/tmp/fake.hrk");
    assert(service.last_project_name == "Home");
    assert(service.last_payload == "payload");

    try {
        controller.open_email_with_attachment("/tmp/fake.hrk");
    } catch (Error e) {
        assert_not_reached();
    }
    assert(service.last_path == "/tmp/fake.hrk");

    try {
        controller.save_payload_to_path("/tmp/out.hrk", "payload-2");
    } catch (Error e) {
        assert_not_reached();
    }
    assert(service.last_path == "/tmp/out.hrk");
    assert(service.last_payload == "payload-2");

    service.next_loaded_payload = "from-file";
    string loaded = "";
    try {
        loaded = controller.load_payload_from_path("/tmp/in.hrk");
    } catch (Error e) {
        assert_not_reached();
    }
    assert(service.last_path == "/tmp/in.hrk");
    assert(loaded == "from-file");
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/recovery_controller/export_recovery_token_requires_api",
                  test_export_recovery_token_requires_api);
    Test.add_func("/recovery_controller/export_recovery_token_returns_payload",
                  test_export_recovery_token_returns_payload);
    Test.add_func("/recovery_controller/export_recovery_token_rejects_empty_payload",
                  test_export_recovery_token_rejects_empty_payload);
    Test.add_func("/recovery_controller/import_recovery_token_calls_reload",
                  test_import_recovery_token_calls_reload);
    Test.add_func("/recovery_controller/import_recovery_token_requires_api",
                  test_import_recovery_token_requires_api);
    Test.add_func("/recovery_controller/service_passthrough_methods",
                  test_service_passthrough_methods);

    return Test.run();
}

}
