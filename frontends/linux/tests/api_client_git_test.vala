using GLib;

namespace HolderLinuxTests {

private HolderLinux.ApiClient make_client(FakeApiHttpTransport transport) {
    return new HolderLinux.ApiClient("http://127.0.0.1:8080", "token-123", transport);
}

private void test_list_git_provider_catalog_parses_providers() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"providers\":[{\"id\":\"github\",\"name\":\"GitHub\",\"kind\":\"public\",\"defaults\":{\"preferred_transport\":\"https\"},\"git\":{\"transports\":[\"https\",\"ssh\"],\"examples\":{\"ssh\":\"git@github.com:owner/repo.git\",\"https\":\"https://github.com/owner/repo.git\"}}}]}"
    );
    var client = make_client(transport);

    bool done = false;
    Gee.ArrayList<HolderLinux.GitProviderCatalogEntry>? providers = null;
    client.list_git_provider_catalog.begin((obj, res) => {
        try { providers = client.list_git_provider_catalog.end(res); } catch (Error e) { providers = null; }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(providers != null);
    assert(providers.size == 1);
    assert(providers[0].id == "github");
    assert(providers[0].name == "GitHub");
    assert(transport.last_uri.contains("/git_providers.json"));
}

private void test_set_project_git_remote_handles_null_and_non_empty_url() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done_null = false;
    bool ok_null = false;
    client.set_project_git_remote.begin("p1", null, 11, (obj, res) => {
        try { client.set_project_git_remote.end(res); ok_null = true; } catch (Error e) { ok_null = false; }
        done_null = true;
    });
    assert(wait_for_condition(() => done_null));
    assert(ok_null);
    assert(transport.last_method == "PATCH");
    assert(transport.last_uri.contains("/projects/p1"));

    bool done_url = false;
    bool ok_url = false;
    client.set_project_git_remote.begin("p1", "git@github.com:me/repo.git", 12, (obj, res) => {
        try { client.set_project_git_remote.end(res); ok_url = true; } catch (Error e) { ok_url = false; }
        done_url = true;
    });
    assert(wait_for_condition(() => done_url));
    assert(ok_url);
}

private void test_test_remote_and_push_success_paths() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"remote_url\":\"git@github.com:me/repo.git\",\"branch\":\"cards\",\"status\":\"ok\",\"remote_has_head\":true,\"error_code\":\"\",\"error_message\":\"\"}}"
    );
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"remote_url\":\"git@github.com:me/repo.git\",\"branch\":\"cards\",\"status\":\"ok\",\"ahead_count\":0,\"behind_count\":0,\"error_code\":\"\",\"error_message\":\"\",\"next_action\":\"\"}}"
    );
    var client = make_client(transport);

    bool done_test = false;
    HolderLinux.GitTestRemoteResult? test_result = null;
    client.test_project_git_remote.begin("p1", "git@github.com:me/repo.git", "cards", (obj, res) => {
        try { test_result = client.test_project_git_remote.end(res); } catch (Error e) { test_result = null; }
        done_test = true;
    });
    assert(wait_for_condition(() => done_test));
    assert(test_result != null);
    assert(test_result.status == "ok");
    assert(test_result.branch == "cards");
    assert(transport.last_uri.contains("/projects/p1/git/test-remote"));

    bool done_push = false;
    HolderLinux.GitPushResult? push_result = null;
    client.push_project_git.begin("p1", "cards", true, (obj, res) => {
        try { push_result = client.push_project_git.end(res); } catch (Error e) { push_result = null; }
        done_push = true;
    });
    assert(wait_for_condition(() => done_push));
    assert(push_result != null);
    assert(push_result.status == "ok");
    assert(push_result.branch == "cards");
    assert(transport.last_uri.contains("/projects/p1/git/push"));
}

private void test_test_remote_whitespace_remote_and_push_without_branch() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"remote_url\":\"\",\"branch\":\"\",\"status\":\"error\",\"remote_has_head\":false,\"error_code\":\"remote_unset\",\"error_message\":\"unset\"}}"
    );
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"remote_url\":\"\",\"branch\":\"\",\"status\":\"error\",\"ahead_count\":0,\"behind_count\":0,\"error_code\":\"remote_unset\",\"error_message\":\"unset\",\"next_action\":\"set_remote\"}}"
    );
    var client = make_client(transport);

    bool done_test = false;
    HolderLinux.GitTestRemoteResult? test_result = null;
    client.test_project_git_remote.begin("p1", "   ", "", (obj, res) => {
        try { test_result = client.test_project_git_remote.end(res); } catch (Error e) { test_result = null; }
        done_test = true;
    });
    assert(wait_for_condition(() => done_test));
    assert(test_result != null);
    assert(test_result.status == "error");
    assert(test_result.error_code == "remote_unset");

    bool done_push = false;
    HolderLinux.GitPushResult? push_result = null;
    client.push_project_git.begin("p1", "", false, (obj, res) => {
        try { push_result = client.push_project_git.end(res); } catch (Error e) { push_result = null; }
        done_push = true;
    });
    assert(wait_for_condition(() => done_push));
    assert(push_result != null);
    assert(push_result.status == "error");
    assert(push_result.error_code == "remote_unset");
}

private void test_missing_data_errors_for_test_remote_and_push() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done_test = false;
    bool got_test_protocol = false;
    client.test_project_git_remote.begin("p1", null, "", (obj, res) => {
        try { client.test_project_git_remote.end(res); } catch (Error e) { got_test_protocol = (e is HolderLinux.ApiError.PROTOCOL); }
        done_test = true;
    });
    assert(wait_for_condition(() => done_test));
    assert(got_test_protocol);

    bool done_push = false;
    bool got_push_protocol = false;
    client.push_project_git.begin("p1", "", true, (obj, res) => {
        try { client.push_project_git.end(res); } catch (Error e) { got_push_protocol = (e is HolderLinux.ApiError.PROTOCOL); }
        done_push = true;
    });
    assert(wait_for_condition(() => done_push));
    assert(got_push_protocol);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/api_client_git/list_git_provider_catalog_parses_providers",
                  test_list_git_provider_catalog_parses_providers);
    Test.add_func("/api_client_git/set_project_git_remote_handles_null_and_non_empty_url",
                  test_set_project_git_remote_handles_null_and_non_empty_url);
    Test.add_func("/api_client_git/test_remote_and_push_success_paths",
                  test_test_remote_and_push_success_paths);
    Test.add_func("/api_client_git/test_remote_whitespace_remote_and_push_without_branch",
                  test_test_remote_whitespace_remote_and_push_without_branch);
    Test.add_func("/api_client_git/missing_data_errors_for_test_remote_and_push",
                  test_missing_data_errors_for_test_remote_and_push);

    return Test.run();
}

}
