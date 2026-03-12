using GLib;

namespace HolderLinuxTests {

private HolderLinux.ApiClient make_client(FakeApiHttpTransport transport) {
    return new HolderLinux.ApiClient("http://127.0.0.1:8080", "token-123", transport);
}

private void test_list_projects_and_create_project() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"project_id\":\"p1\",\"name\":\"Project One\",\"root_path\":\"/tmp/p1\",\"created_at\":1,\"updated_at\":2}]}"
    );
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"project_id\":\"p-created\"}}");
    var client = make_client(transport);

    bool done_list = false;
    Gee.ArrayList<HolderLinux.Project>? projects = null;
    client.list_projects.begin((obj, res) => {
        try { projects = client.list_projects.end(res); } catch (Error e) { projects = null; }
        done_list = true;
    });
    assert(wait_for_condition(() => done_list));
    assert(projects != null);
    assert(projects.size == 1);
    assert(projects[0].project_id == "p1");
    assert(transport.last_uri.contains("/projects"));
    assert(transport.last_uri.contains("count=true"));

    bool done_create = false;
    string created = "";
    client.create_project.begin("New Project", "encrypted_git", (obj, res) => {
        try { created = client.create_project.end(res); } catch (Error e) { created = ""; }
        done_create = true;
    });
    assert(wait_for_condition(() => done_create));
    assert(created == "p-created");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.contains("/projects"));
}

private void test_export_and_import_project_recovery_token() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"key_id\":\"k1\",\"recovery_token\":\"{\\\"x\\\":1}\"}}"
    );
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"project_id\":\"p1\"}}");
    var client = make_client(transport);

    bool done_export = false;
    HolderLinux.ProjectRecoveryTokenExport? exported = null;
    client.export_project_recovery_token.begin("p1", "1234", (obj, res) => {
        try { exported = client.export_project_recovery_token.end(res); } catch (Error e) { exported = null; }
        done_export = true;
    });
    assert(wait_for_condition(() => done_export));
    assert(exported != null);
    assert(exported.project_id == "p1");
    assert(exported.key_id == "k1");
    assert(transport.last_uri.contains("/projects/p1/recovery-token/export"));

    bool done_import = false;
    bool ok_import = false;
    client.import_project_recovery_token.begin("p1", "1234", "{\"x\":1}", (obj, res) => {
        try { client.import_project_recovery_token.end(res); ok_import = true; } catch (Error e) { ok_import = false; }
        done_import = true;
    });
    assert(wait_for_condition(() => done_import));
    assert(ok_import);
    assert(transport.last_uri.contains("/projects/p1/recovery-token/import"));
}

private void test_export_project_recovery_token_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.export_project_recovery_token.begin("p1", "1234", (obj, res) => {
        try { client.export_project_recovery_token.end(res); } catch (Error e) { got_protocol = (e is HolderLinux.ApiError.PROTOCOL); }
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

private void test_import_recovery_token_parses_outcome_and_optional_errors() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        201,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"project_created\":true,\"remote_hint_present\":true,\"remote_configured\":false,\"remote_error\":\"set remote failed\",\"pull_status\":\"not_attempted\",\"pull_error\":null}}"
    );
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p2\",\"project_created\":false,\"remote_hint_present\":false,\"remote_configured\":false,\"remote_error\":null,\"pull_status\":\"failed\",\"pull_error\":\"git pull failed\"}}"
    );
    var client = make_client(transport);

    bool done_first = false;
    HolderLinux.RecoveryTokenImportResult? first = null;
    client.import_recovery_token.begin("1234", "{\"x\":1}", (obj, res) => {
        try { first = client.import_recovery_token.end(res); } catch (Error e) { first = null; }
        done_first = true;
    });
    assert(wait_for_condition(() => done_first));
    assert(first != null);
    assert(first.project_id == "p1");
    assert(first.project_created);
    assert(first.remote_error == "set remote failed");
    assert(first.pull_error == "");

    bool done_second = false;
    HolderLinux.RecoveryTokenImportResult? second = null;
    client.import_recovery_token.begin("1234", "{\"x\":1}", (obj, res) => {
        try { second = client.import_recovery_token.end(res); } catch (Error e) { second = null; }
        done_second = true;
    });
    assert(wait_for_condition(() => done_second));
    assert(second != null);
    assert(second.project_id == "p2");
    assert(second.pull_error == "git pull failed");
}

private void test_import_recovery_token_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.import_recovery_token.begin("1234", "{\"x\":1}", (obj, res) => {
        try { client.import_recovery_token.end(res); } catch (Error e) { got_protocol = (e is HolderLinux.ApiError.PROTOCOL); }
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/api_client_projects/list_projects_and_create_project",
                  test_list_projects_and_create_project);
    Test.add_func("/api_client_projects/export_and_import_project_recovery_token",
                  test_export_and_import_project_recovery_token);
    Test.add_func("/api_client_projects/export_project_recovery_token_missing_data_is_protocol_error",
                  test_export_project_recovery_token_missing_data_is_protocol_error);
    Test.add_func("/api_client_projects/import_recovery_token_parses_outcome_and_optional_errors",
                  test_import_recovery_token_parses_outcome_and_optional_errors);
    Test.add_func("/api_client_projects/import_recovery_token_missing_data_is_protocol_error",
                  test_import_recovery_token_missing_data_is_protocol_error);

    return Test.run();
}

}
