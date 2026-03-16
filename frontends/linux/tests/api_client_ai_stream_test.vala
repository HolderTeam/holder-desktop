using GLib;

namespace HolderLinuxTests {

private void test_run_ai_stream_parses_sse_and_raw_data() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream(
        200,
        "event: token\n"
        + "data: {\"piece\":\"Hello\"}\n"
        + "\n"
        + "event: done\n"
        + "data: not-json\n"
        + "\n"
    );

    bool done = false;
    bool ok = true;
    string first_event = "";
    string first_piece = "";
    string second_event = "";
    string second_raw = "";

    HolderLinux.ApiClientAiStream.run.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "hello",
        "project-1",
        "thread-1",
        "card-1",
        "Card",
        "Body",
        (event_name, payload) => {
            if (first_event == "") {
                first_event = event_name;
                first_piece = payload.get_string_member("piece");
            } else {
                second_event = event_name;
                second_raw = payload.get_string_member("raw");
            }
        },
        (obj, res) => {
            try {
                HolderLinux.ApiClientAiStream.run.end(res);
            } catch (Error e) {
                ok = false;
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(ok);
    assert(first_event == "token");
    assert(first_piece == "Hello");
    assert(second_event == "done");
    assert(second_raw == "not-json");
    assert(transport.last_method == "POST");
    assert(transport.last_uri == "http://127.0.0.1:8080/ai/runs");
    assert(transport.last_accept == "text/event-stream");
    assert(transport.last_auth == "Bearer token-123");
    assert(transport.last_content_type == "application/json");
}

private void test_run_ai_stream_http_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream(503, "{\"error\":\"down\"}");

    bool done = false;
    bool got_http = false;
    HolderLinux.ApiClientAiStream.run.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "hello",
        null,
        null,
        null,
        null,
        null,
        (event_name, payload) => {},
        (obj, res) => {
            try {
                HolderLinux.ApiClientAiStream.run.end(res);
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
    transport.enqueue_stream_throw("dial failed");

    bool done = false;
    bool got_transport = false;
    HolderLinux.ApiClientAiStream.run.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "hello",
        null,
        null,
        null,
        null,
        null,
        (event_name, payload) => {},
        (obj, res) => {
            try {
                HolderLinux.ApiClientAiStream.run.end(res);
            } catch (Error e) {
                got_transport = (e is HolderLinux.ApiError.TRANSPORT);
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(got_transport);
}

private void test_run_ai_stream_sse_read_error_maps_to_transport() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream_read_throw(200, "read failed");

    bool done = false;
    bool got_transport = false;
    bool message_has_prefix = false;
    HolderLinux.ApiClientAiStream.run.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "hello",
        null,
        null,
        null,
        null,
        null,
        (event_name, payload) => {},
        (obj, res) => {
            try {
                HolderLinux.ApiClientAiStream.run.end(res);
            } catch (Error e) {
                got_transport = (e is HolderLinux.ApiError.TRANSPORT);
                message_has_prefix = e.message.contains("SSE read error:");
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(got_transport);
    assert(message_has_prefix);
}

private void test_run_ai_stream_eof_without_blank_line_emits_last_event() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream(200, "event: done\ndata: {\"ok\":true}\n");

    bool done = false;
    bool ok = true;
    string event_name = "";
    bool payload_ok = false;
    HolderLinux.ApiClientAiStream.run.begin(
        transport,
        "http://127.0.0.1:8080",
        "token-123",
        "hello",
        null,
        null,
        null,
        null,
        null,
        (name, payload) => {
            event_name = name;
            payload_ok = payload.get_boolean_member("ok");
        },
        (obj, res) => {
            try {
                HolderLinux.ApiClientAiStream.run.end(res);
            } catch (Error e) {
                ok = false;
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(ok);
    assert(event_name == "done");
    assert(payload_ok);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/api_client_ai_stream/run_ai_stream_parses_sse_and_raw_data",
                  test_run_ai_stream_parses_sse_and_raw_data);
    Test.add_func("/api_client_ai_stream/run_ai_stream_http_error",
                  test_run_ai_stream_http_error);
    Test.add_func("/api_client_ai_stream/run_ai_stream_transport_error",
                  test_run_ai_stream_transport_error);
    Test.add_func("/api_client_ai_stream/run_ai_stream_sse_read_error_maps_to_transport",
                  test_run_ai_stream_sse_read_error_maps_to_transport);
    Test.add_func("/api_client_ai_stream/run_ai_stream_eof_without_blank_line_emits_last_event",
                  test_run_ai_stream_eof_without_blank_line_emits_last_event);

    return Test.run();
}

}
