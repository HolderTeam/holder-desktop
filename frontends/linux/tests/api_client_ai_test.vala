using GLib;

namespace HolderLinuxTests {

private HolderLinux.ApiClient make_client(FakeApiHttpTransport transport) {
    return new HolderLinux.ApiClient("http://127.0.0.1:8080", "token-123", transport);
}

private void test_get_ai_capabilities_with_project_query() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"runner_available\":true,\"error\":\"\",\"last_checked\":100,\"version\":\"1.0\",\"caste\":{\"name\":\"caste\"},\"models\":[{\"name\":\"m1\"}],\"recommended_install\":[{\"tag\":\"r1\"}]}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.AiCapabilitiesInfo? info = null;
    client.get_ai_capabilities.begin("p1", (obj, res) => {
        try {
            info = client.get_ai_capabilities.end(res);
        } catch (Error e) {
            info = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(info != null);
    assert(info.runner_available);
    assert(info.runner_version == "1.0");
    assert(info.models.size == 1);
    assert(info.models[0] == "m1");
    assert(transport.last_uri.contains("/ai/capabilities"));
    assert(transport.last_uri.contains("project_id=p1"));
}

private void test_get_ai_capabilities_without_project_query() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"runner_available\":false,\"error\":\"none\",\"last_checked\":0,\"version\":\"\",\"models\":[],\"recommended_install\":[]}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.AiCapabilitiesInfo? info = null;
    client.get_ai_capabilities.begin(null, (obj, res) => {
        try {
            info = client.get_ai_capabilities.end(res);
        } catch (Error e) {
            info = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(info != null);
    assert(!info.runner_available);
    assert(transport.last_uri.contains("/ai/capabilities"));
    assert(!transport.last_uri.contains("project_id="));
}

private void test_get_ai_status_parses_response() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"checked_at\":9,\"runner_available\":true,\"runner_error\":\"\",\"active_runs\":1,\"active_pull_jobs\":1,\"cloud_configured_providers\":2,\"pulls\":[{\"model\":\"phi4\",\"status\":\"running\",\"progress\":{\"percent\":12.5}}]}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.AiStatusInfo? status = null;
    client.get_ai_status.begin((obj, res) => {
        try {
            status = client.get_ai_status.end(res);
        } catch (Error e) {
            status = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(status != null);
    assert(status.runner_available);
    assert(status.active_runs == 1);
    assert(status.pull_jobs.size == 1);
    assert(transport.last_uri.contains("/ai/status"));
}

private void test_start_ai_runner_pull_success() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"job_id\":\"job-1\"}}");
    var client = make_client(transport);

    bool done = false;
    string job_id = "";
    client.start_ai_runner_pull.begin("phi4", (obj, res) => {
        try {
            job_id = client.start_ai_runner_pull.end(res);
        } catch (Error e) {
            job_id = "";
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(job_id == "job-1");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.contains("/ai/runner/pull"));
    assert(transport.last_content_type == "application/json");
}

private void test_start_ai_runner_pull_missing_data_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.start_ai_runner_pull.begin("phi4", (obj, res) => {
        try {
            client.start_ai_runner_pull.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

private void test_start_ai_runner_pull_missing_job_id_returns_empty_string() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done = false;
    string job_id = "not-empty";
    client.start_ai_runner_pull.begin("phi4", (obj, res) => {
        try {
            job_id = client.start_ai_runner_pull.end(res);
        } catch (Error e) {
            job_id = "error";
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(job_id == "");
}

private void test_list_and_create_ai_thread() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"thread_id\":\"t1\",\"project_id\":\"p1\",\"title\":\"Thread 1\",\"created_at\":1,\"updated_at\":2}]}"
    );
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"thread_id\":\"t-new\"}}");
    var client = make_client(transport);

    bool done_list = false;
    Gee.ArrayList<HolderLinux.AiThreadSummary>? threads = null;
    client.list_ai_threads.begin("p1", (obj, res) => {
        try {
            threads = client.list_ai_threads.end(res);
        } catch (Error e) {
            threads = null;
        }
        done_list = true;
    });

    assert(wait_for_condition(() => done_list));
    assert(threads != null);
    assert(threads.size == 1);
    assert(threads[0].thread_id == "t1");
    assert(transport.last_uri.contains("/ai/threads"));
    assert(transport.last_uri.contains("project_id=p1"));

    bool done_create = false;
    string thread_id = "";
    client.create_ai_thread.begin("p1", "Thread New", (obj, res) => {
        try {
            thread_id = client.create_ai_thread.end(res);
        } catch (Error e) {
            thread_id = "";
        }
        done_create = true;
    });

    assert(wait_for_condition(() => done_create));
    assert(thread_id == "t-new");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.contains("/ai/threads"));
}

private void test_create_ai_thread_missing_data_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.create_ai_thread.begin("p1", "Thread New", (obj, res) => {
        try {
            client.create_ai_thread.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

private void test_list_ai_provider_catalog_parses_unwrapped_response() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"models\":{\"provider_defaults\":{\"switchyard\":{\"provider\":\"Switchyard\",\"enabled\":true,\"setup_url\":\"https://setup\",\"docs_url\":\"https://docs\"}}}}"
    );
    var client = make_client(transport);

    bool done = false;
    Gee.ArrayList<HolderLinux.AiCatalogProvider>? providers = null;
    client.list_ai_provider_catalog.begin((obj, res) => {
        try {
            providers = client.list_ai_provider_catalog.end(res);
        } catch (Error e) {
            providers = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(providers != null);
    assert(providers.size == 1);
    assert(providers[0].id == "switchyard");
    assert(providers[0].display_name == "Switchyard");
    assert(transport.last_uri.contains("/ai_catalog.json"));
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/api_client_ai/get_ai_capabilities_with_project_query",
                  test_get_ai_capabilities_with_project_query);
    Test.add_func("/api_client_ai/get_ai_capabilities_without_project_query",
                  test_get_ai_capabilities_without_project_query);
    Test.add_func("/api_client_ai/get_ai_status_parses_response",
                  test_get_ai_status_parses_response);
    Test.add_func("/api_client_ai/start_ai_runner_pull_success",
                  test_start_ai_runner_pull_success);
    Test.add_func("/api_client_ai/start_ai_runner_pull_missing_data_protocol_error",
                  test_start_ai_runner_pull_missing_data_protocol_error);
    Test.add_func("/api_client_ai/start_ai_runner_pull_missing_job_id_returns_empty_string",
                  test_start_ai_runner_pull_missing_job_id_returns_empty_string);
    Test.add_func("/api_client_ai/list_and_create_ai_thread",
                  test_list_and_create_ai_thread);
    Test.add_func("/api_client_ai/create_ai_thread_missing_data_protocol_error",
                  test_create_ai_thread_missing_data_protocol_error);
    Test.add_func("/api_client_ai/list_ai_provider_catalog_parses_unwrapped_response",
                  test_list_ai_provider_catalog_parses_unwrapped_response);

    return Test.run();
}

}
