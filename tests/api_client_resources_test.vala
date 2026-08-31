using GLib;

namespace HolderLinuxTests {

private HolderLinux.ApiClient make_client(FakeApiHttpTransport transport) {
    return new HolderLinux.ApiClient("http://127.0.0.1:8080", "token-123", transport);
}

private void test_list_resources_parses_results_and_query() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"resource_id\":\"r1\",\"project_id\":\"p1\",\"type\":\"website\",\"label\":\"Example\",\"metadata\":{\"identifier\":[\"https://example.com\"],\"description\":[\"Docs\"]},\"assets\":[],\"created_at\":1,\"updated_at\":2}]}"
    );
    var client = make_client(transport);

    bool done = false;
    Gee.ArrayList<HolderLinux.ProjectResource>? resources = null;
    client.list_resources.begin("p1", (obj, res) => {
        try {
            resources = client.list_resources.end(res);
        } catch (Error e) {
            resources = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(resources != null);
    assert(resources.size == 1);
    assert(resources[0].resource_id == "r1");
    assert(resources[0].project_id == "p1");
    assert(resources[0].resource_type == "website");
    assert(resources[0].uri == "https://example.com");
    assert(resources[0].desc == "Docs");
    assert(resources[0].label == "Example");
    assert(transport.last_method == "GET");
    assert(transport.last_uri.contains("/resources"));
    assert(transport.last_uri.contains("project_id=p1"));
}

private void test_create_resource_with_and_without_desc() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"resource_id\":\"r1\"}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"resource_id\":\"r2\"}}");
    var client = make_client(transport);

    bool done_first = false;
    string first_id = "";
    client.create_resource.begin("p1", "url", "https://example.com", "Example", "Docs", null, (obj, res) => {
        try {
            first_id = client.create_resource.end(res);
        } catch (Error e) {
            first_id = "";
        }
        done_first = true;
    });

    assert(wait_for_condition(() => done_first));
    assert(first_id == "r1");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.contains("/resources"));
    assert(transport.last_content_type == "application/json");

    bool done_second = false;
    string second_id = "";
    client.create_resource.begin("p1", "file", "file:///tmp/x", "Local", null, null, (obj, res) => {
        try {
            second_id = client.create_resource.end(res);
        } catch (Error e) {
            second_id = "";
        }
        done_second = true;
    });

    assert(wait_for_condition(() => done_second));
    assert(second_id == "r2");
}

private void test_create_resource_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.create_resource.begin("p1", "url", "https://example.com", "Example", null, null, (obj, res) => {
        try {
            client.create_resource.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

private void test_update_resource_and_delete_resource_paths() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done_update = false;
    bool ok_update = false;
    client.update_resource.begin("r 1/2", "url", null, "New Label", null, 123, null, (obj, res) => {
        try {
            client.update_resource.end(res);
            ok_update = true;
        } catch (Error e) {
            ok_update = false;
        }
        done_update = true;
    });

    assert(wait_for_condition(() => done_update));
    assert(ok_update);
    assert(transport.last_method == "PATCH");
    assert(transport.last_uri.contains("/resources/r%201%2F2"));
    assert(transport.last_content_type == "application/json");

    bool done_delete = false;
    bool ok_delete = false;
    client.delete_resource.begin("r 1/2", (obj, res) => {
        try {
            client.delete_resource.end(res);
            ok_delete = true;
        } catch (Error e) {
            ok_delete = false;
        }
        done_delete = true;
    });

    assert(wait_for_condition(() => done_delete));
    assert(ok_delete);
    assert(transport.last_method == "DELETE");
    assert(transport.last_uri.contains("/resources/r%201%2F2"));
}

private void test_start_google_drive_oauth_posts_and_returns_the_authorization_url() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"authorization_url\":\"https://accounts.google.com/o/oauth2/v2/auth?state=abc\"}}"
    );
    var client = make_client(transport);

    bool done = false;
    string? url = null;
    client.start_google_drive_oauth.begin("loc 1/2", (obj, res) => {
        try {
            url = client.start_google_drive_oauth.end(res);
        } catch (Error e) {
            url = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(url == "https://accounts.google.com/o/oauth2/v2/auth?state=abc");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.contains("/locations/loc%201%2F2/oauth/google-drive/authorize"));
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/api_client_resources/list_resources_parses_results_and_query",
                  test_list_resources_parses_results_and_query);
    Test.add_func("/api_client_resources/create_resource_with_and_without_desc",
                  test_create_resource_with_and_without_desc);
    Test.add_func("/api_client_resources/create_resource_missing_data_is_protocol_error",
                  test_create_resource_missing_data_is_protocol_error);
    Test.add_func("/api_client_resources/update_resource_and_delete_resource_paths",
                  test_update_resource_and_delete_resource_paths);
    Test.add_func(
        "/api_client_resources/start_google_drive_oauth_posts_and_returns_the_authorization_url",
        test_start_google_drive_oauth_posts_and_returns_the_authorization_url
    );

    return Test.run();
}

}
