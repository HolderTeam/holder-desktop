using GLib;

namespace HolderLinuxTests {

private HolderLinux.ApiClient make_client(FakeApiHttpTransport transport) {
    return new HolderLinux.ApiClient("http://127.0.0.1:8080", "token-123", transport);
}

private void test_health_check_success() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done = false;
    bool ok = false;
    client.health_check.begin((obj, res) => {
        try {
            client.health_check.end(res);
            ok = true;
        } catch (Error e) {
            ok = false;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(ok);
    assert(transport.last_accept == "application/json");
    assert(transport.last_auth == "Bearer token-123");
}

private void test_list_projects_parses_data() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"project_id\":\"p1\",\"name\":\"My Project\",\"root_path\":\"/tmp/p1\",\"created_at\":1,\"updated_at\":2}]}"
    );
    var client = make_client(transport);

    bool done = false;
    Gee.ArrayList<HolderLinux.Project>? projects = null;
    client.list_projects.begin((obj, res) => {
        try {
            projects = client.list_projects.end(res);
        } catch (Error e) {
            projects = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(projects != null);
    assert(projects.size == 1);
    assert(projects[0].project_id == "p1");
    assert(projects[0].name == "My Project");
}

private void test_request_json_transport_error_maps_to_api_transport() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read_throw("network down");
    var client = make_client(transport);

    bool done = false;
    bool got_transport = false;
    client.list_projects.begin((obj, res) => {
        try {
            client.list_projects.end(res);
        } catch (Error e) {
            got_transport = (e is HolderLinux.ApiError.TRANSPORT);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_transport);
}

private void test_request_json_http_error_parses_error_object() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(404, "{\"ok\":false,\"error\":{\"code\":\"not_found\",\"message\":\"Missing\"}}");
    var client = make_client(transport);

    bool done = false;
    bool got_http = false;
    bool message_has_code = false;
    client.list_projects.begin((obj, res) => {
        try {
            client.list_projects.end(res);
        } catch (Error e) {
            got_http = (e is HolderLinux.ApiError.HTTP);
            message_has_code = e.message.contains("not_found");
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_http);
    assert(message_has_code);
}

private void test_request_json_parse_error_on_success_response() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "this-is-not-json");
    var client = make_client(transport);

    bool done = false;
    bool got_parse = false;
    client.list_projects.begin((obj, res) => {
        try {
            client.list_projects.end(res);
        } catch (Error e) {
            got_parse = (e is HolderLinux.ApiError.PARSE);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_parse);
}

private void test_request_json_protocol_error_when_ok_missing() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"data\":[]}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.list_projects.begin((obj, res) => {
        try {
            client.list_projects.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

private void test_run_ai_stream_parses_sse_and_raw_data() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream(
        200,
        "event: progress\n" +
        "data: {\"message\":\"working\"}\n\n" +
        "event: chunk\n" +
        "data: {\"delta\":\"hi\"}\n\n" +
        "data: plain text payload\n\n" +
        "event: done\n" +
        "data: {\"model\":\"phi4\"}\n\n"
    );
    var client = make_client(transport);

    var event_names = new Gee.ArrayList<string>();
    bool saw_raw = false;
    bool done = false;
    bool ok = false;
    client.run_ai_stream.begin(
        "Prompt",
        "p1",
        "t1",
        null,
        null,
        null,
        (event_name, data) => {
            event_names.add(event_name);
            if (data.has_member("raw") && data.get_string_member("raw").contains("plain text payload")) {
                saw_raw = true;
            }
        },
        (obj, res) => {
            try {
                client.run_ai_stream.end(res);
                ok = true;
            } catch (Error e) {
                ok = false;
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(ok);
    assert(event_names.size == 4);
    assert(event_names[0] == "progress");
    assert(event_names[1] == "chunk");
    assert(event_names[2] == "message");
    assert(event_names[3] == "done");
    assert(saw_raw);
    assert(transport.last_accept == "text/event-stream");
}

private void test_run_ai_stream_http_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream(500, "");
    var client = make_client(transport);

    bool done = false;
    bool got_http = false;
    client.run_ai_stream.begin(
        "Prompt",
        "p1",
        "t1",
        null,
        null,
        null,
        (event_name, data) => {},
        (obj, res) => {
            try {
                client.run_ai_stream.end(res);
            } catch (Error e) {
                got_http = (e is HolderLinux.ApiError.HTTP);
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(got_http);
}

private void test_run_ai_stream_transport_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream_throw("socket closed");
    var client = make_client(transport);

    bool done = false;
    bool got_transport = false;
    client.run_ai_stream.begin(
        "Prompt",
        "p1",
        "t1",
        null,
        null,
        null,
        (event_name, data) => {},
        (obj, res) => {
            try {
                client.run_ai_stream.end(res);
            } catch (Error e) {
                got_transport = (e is HolderLinux.ApiError.TRANSPORT);
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(got_transport);
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/api_client/health_check_success", test_health_check_success);
    Test.add_func("/api_client/list_projects_parses_data", test_list_projects_parses_data);
    Test.add_func("/api_client/request_json_transport_error_maps_to_api_transport",
                  test_request_json_transport_error_maps_to_api_transport);
    Test.add_func("/api_client/request_json_http_error_parses_error_object",
                  test_request_json_http_error_parses_error_object);
    Test.add_func("/api_client/request_json_parse_error_on_success_response",
                  test_request_json_parse_error_on_success_response);
    Test.add_func("/api_client/request_json_protocol_error_when_ok_missing",
                  test_request_json_protocol_error_when_ok_missing);
    Test.add_func("/api_client/run_ai_stream_parses_sse_and_raw_data",
                  test_run_ai_stream_parses_sse_and_raw_data);
    Test.add_func("/api_client/run_ai_stream_http_error", test_run_ai_stream_http_error);
    Test.add_func("/api_client/run_ai_stream_transport_error", test_run_ai_stream_transport_error);

    return Test.run();
}

}
