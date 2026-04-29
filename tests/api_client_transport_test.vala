using GLib;

namespace HolderLinuxTests {

private void test_request_json_ok_true_success() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"x\":1}}");

    bool done = false;
    Json.Object? root = null;
    HolderLinux.ApiClientTransport.request_json.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "GET",
        "/health",
        null,
        null,
        (obj, res) => {
            try {
                root = HolderLinux.ApiClientTransport.request_json.end(res);
            } catch (Error e) {
                root = null;
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(root != null);
    assert(root.get_boolean_member("ok"));
    assert(transport.last_method == "GET");
    assert(transport.last_uri == "http://127.0.0.1:8080/health");
}

private void test_request_json_requires_ok_true() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":false}");

    bool done = false;
    bool got_protocol = false;
    HolderLinux.ApiClientTransport.request_json.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "GET",
        "/health",
        null,
        null,
        (obj, res) => {
            try {
                HolderLinux.ApiClientTransport.request_json.end(res);
            } catch (Error e) {
                got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

private void test_request_json_unwrapped_sets_json_content_type_with_body() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");

    bool done = false;
    bool ok = false;
    HolderLinux.ApiClientTransport.request_json_unwrapped.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "POST",
        "/projects",
        "{\"name\":\"n\"}",
        null,
        (obj, res) => {
            try {
                HolderLinux.ApiClientTransport.request_json_unwrapped.end(res);
                ok = true;
            } catch (Error e) {
                ok = false;
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(ok);
    assert(transport.last_content_type == "application/json");
    assert(transport.last_auth == "Bearer token-123");
    assert(transport.last_accept == "application/json");
}

private void test_request_json_unwrapped_transport_error_maps_to_api_transport() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read_throw("dial failed");

    bool done = false;
    bool got_transport = false;
    HolderLinux.ApiClientTransport.request_json_unwrapped.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "GET",
        "/projects",
        null,
        null,
        (obj, res) => {
            try {
                HolderLinux.ApiClientTransport.request_json_unwrapped.end(res);
            } catch (Error e) {
                got_transport = (e is HolderLinux.ApiError.TRANSPORT);
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(got_transport);
}

private void test_request_json_unwrapped_parse_error_on_2xx_rethrows_parse() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "not-json");

    bool done = false;
    bool got_parse = false;
    HolderLinux.ApiClientTransport.request_json_unwrapped.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "GET",
        "/projects",
        null,
        null,
        (obj, res) => {
            try {
                HolderLinux.ApiClientTransport.request_json_unwrapped.end(res);
            } catch (Error e) {
                got_parse = (e is HolderLinux.ApiError.PARSE);
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(got_parse);
}

private void test_request_json_unwrapped_parse_error_on_non_2xx_maps_to_http() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(500, "not-json");

    bool done = false;
    bool got_http = false;
    HolderLinux.ApiClientTransport.request_json_unwrapped.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "GET",
        "/projects",
        null,
        null,
        (obj, res) => {
            try {
                HolderLinux.ApiClientTransport.request_json_unwrapped.end(res);
            } catch (Error e) {
                got_http = (e is HolderLinux.ApiError.HTTP);
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(got_http);
}

private void test_request_json_unwrapped_non_2xx_with_error_object_maps_to_http() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(409, "{\"error\":{\"code\":\"conflict\",\"message\":\"already exists\"}}");

    bool done = false;
    bool got_http = false;
    bool message_has_code = false;
    HolderLinux.ApiClientTransport.request_json_unwrapped.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "POST",
        "/resources",
        null,
        null,
        (obj, res) => {
            try {
                HolderLinux.ApiClientTransport.request_json_unwrapped.end(res);
            } catch (Error e) {
                got_http = (e is HolderLinux.ApiError.HTTP);
                message_has_code = e.message.contains("conflict") && e.message.contains("already exists");
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(got_http);
    assert(message_has_code);
}

private void test_request_json_unwrapped_non_2xx_with_error_object_missing_message_uses_default() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(422, "{\"error\":{\"code\":\"unprocessable\"}}");

    bool done = false;
    bool got_http = false;
    bool has_default_message = false;
    HolderLinux.ApiClientTransport.request_json_unwrapped.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "POST",
        "/resources",
        null,
        null,
        (obj, res) => {
            try {
                HolderLinux.ApiClientTransport.request_json_unwrapped.end(res);
            } catch (Error e) {
                got_http = (e is HolderLinux.ApiError.HTTP);
                has_default_message = e.message.contains("unprocessable")
                    && e.message.contains("Request failed");
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(got_http);
    assert(has_default_message);
}

private void test_request_json_unwrapped_non_2xx_without_error_object_maps_to_http() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(404, "{\"ok\":false}");

    bool done = false;
    bool got_http = false;
    HolderLinux.ApiClientTransport.request_json_unwrapped.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "GET",
        "/resources",
        null,
        null,
        (obj, res) => {
            try {
                HolderLinux.ApiClientTransport.request_json_unwrapped.end(res);
            } catch (Error e) {
                got_http = (e is HolderLinux.ApiError.HTTP);
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(got_http);
}

private void test_request_json_unwrapped_appends_query_params() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");

    var query = new HashTable<string, string>(str_hash, str_equal);
    query.set("project id", "abc 123");

    bool done = false;
    HolderLinux.ApiClientTransport.request_json_unwrapped.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "GET",
        "/cards",
        null,
        query,
        (obj, res) => {
            try {
                HolderLinux.ApiClientTransport.request_json_unwrapped.end(res);
            } catch (Error e) {
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(transport.last_uri.contains("/cards?"));
    assert(transport.last_uri.contains("project%20id=abc%20123"));
}

private void test_build_url_without_query() {
    var url = HolderLinux.ApiClientTransport.build_url("http://127.0.0.1:8080", "/health", null);
    assert(url == "http://127.0.0.1:8080/health");
}

private void test_json_string_from_builder_emits_json() {
    var builder = new Json.Builder();
    builder.begin_object();
    builder.set_member_name("k");
    builder.add_string_value("v");
    builder.end_object();

    var text = HolderLinux.ApiClientTransport.json_string_from_builder(builder);
    var parser = new Json.Parser();
    try {
        parser.load_from_data(text, -1);
    } catch (Error e) {
        assert_not_reached();
    }
    var root = parser.get_root();
    assert(root != null);
    assert(root.get_object().get_string_member("k") == "v");
}

private void test_json_object_from_text_or_raw_parses_object() {
    var obj = HolderLinux.ApiClientTransport.json_object_from_text_or_raw("{\"x\":\"y\"}");
    assert(obj.get_string_member("x") == "y");
}

private void test_json_object_from_text_or_raw_falls_back_to_raw_for_invalid_or_non_object() {
    var from_invalid = HolderLinux.ApiClientTransport.json_object_from_text_or_raw("not-json");
    assert(from_invalid.get_string_member("raw") == "not-json");

    var from_array = HolderLinux.ApiClientTransport.json_object_from_text_or_raw("[1,2,3]");
    assert(from_array.get_string_member("raw") == "[1,2,3]");
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/api_client_transport/request_json_ok_true_success",
                  test_request_json_ok_true_success);
    Test.add_func("/api_client_transport/request_json_requires_ok_true",
                  test_request_json_requires_ok_true);
    Test.add_func("/api_client_transport/request_json_unwrapped_sets_json_content_type_with_body",
                  test_request_json_unwrapped_sets_json_content_type_with_body);
    Test.add_func("/api_client_transport/request_json_unwrapped_transport_error_maps_to_api_transport",
                  test_request_json_unwrapped_transport_error_maps_to_api_transport);
    Test.add_func("/api_client_transport/request_json_unwrapped_parse_error_on_2xx_rethrows_parse",
                  test_request_json_unwrapped_parse_error_on_2xx_rethrows_parse);
    Test.add_func("/api_client_transport/request_json_unwrapped_parse_error_on_non_2xx_maps_to_http",
                  test_request_json_unwrapped_parse_error_on_non_2xx_maps_to_http);
    Test.add_func("/api_client_transport/request_json_unwrapped_non_2xx_with_error_object_maps_to_http",
                  test_request_json_unwrapped_non_2xx_with_error_object_maps_to_http);
    Test.add_func("/api_client_transport/request_json_unwrapped_non_2xx_with_error_object_missing_message_uses_default",
                  test_request_json_unwrapped_non_2xx_with_error_object_missing_message_uses_default);
    Test.add_func("/api_client_transport/request_json_unwrapped_non_2xx_without_error_object_maps_to_http",
                  test_request_json_unwrapped_non_2xx_without_error_object_maps_to_http);
    Test.add_func("/api_client_transport/request_json_unwrapped_appends_query_params",
                  test_request_json_unwrapped_appends_query_params);
    Test.add_func("/api_client_transport/build_url_without_query",
                  test_build_url_without_query);
    Test.add_func("/api_client_transport/json_string_from_builder_emits_json",
                  test_json_string_from_builder_emits_json);
    Test.add_func("/api_client_transport/json_object_from_text_or_raw_parses_object",
                  test_json_object_from_text_or_raw_parses_object);
    Test.add_func("/api_client_transport/json_object_from_text_or_raw_falls_back_to_raw_for_invalid_or_non_object",
                  test_json_object_from_text_or_raw_falls_back_to_raw_for_invalid_or_non_object);

    return Test.run();
}

}
