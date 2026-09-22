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

private void test_create_and_update_resource_with_metadata_map() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"resource_id\":\"r1\"}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    var metadata = new Gee.HashMap<string, Gee.ArrayList<string>>();
    var creators = new Gee.ArrayList<string>();
    creators.add("Ada");
    metadata.set("creator", creators);
    // These keys are carried separately (identifier/description) and must be skipped
    // by add_metadata_values so they are not emitted twice.
    var skipped = new Gee.ArrayList<string>();
    skipped.add("ignored");
    metadata.set("identifier", skipped);
    metadata.set("description", skipped);

    bool done_create = false;
    string created_id = "";
    client.create_resource.begin("p1", "url", "https://example.com", "Example", "Docs", metadata, (obj, res) => {
        try {
            created_id = client.create_resource.end(res);
        } catch (Error e) {
            created_id = "";
        }
        done_create = true;
    });
    assert(wait_for_condition(() => done_create));
    assert(created_id == "r1");

    bool done_update = false;
    bool ok_update = false;
    client.update_resource.begin("r1", null, null, null, null, 42, metadata, (obj, res) => {
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
}

private void test_storage_location_lifecycle() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"location_id\":\"l1\",\"project_id\":\"p1\",\"name\":\"Drive\",\"provider\":\"google-drive\",\"configuration\":{\"folder\":\"root\"},\"bound\":true,\"binding_preview\":\"Folder: root\"}],\"preferred_location_id\":\"l1\"}"
    );
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"location_id\":\"l2\"}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done_list = false;
    HolderLinux.StorageLocationList? list = null;
    client.list_storage_locations.begin("p1", (obj, res) => {
        try {
            list = client.list_storage_locations.end(res);
        } catch (Error e) {
            list = null;
        }
        done_list = true;
    });
    assert(wait_for_condition(() => done_list));
    assert(transport.last_method == "GET");
    assert(transport.last_uri.contains("/locations"));
    assert(transport.last_uri.contains("project_id=p1"));
    assert(list != null);
    assert(list.locations.size == 1);
    assert(list.locations[0].location_id == "l1");
    assert(list.locations[0].bound);
    assert(list.preferred_location_id == "l1");

    var config = new Gee.HashMap<string, string>();
    config.set("folder", "root");
    bool done_create_location = false;
    string created_location_id = "";
    client.create_storage_location.begin("p1", "Drive", "google-drive", config, (obj, res) => {
        try {
            created_location_id = client.create_storage_location.end(res);
        } catch (Error e) {
            created_location_id = "";
        }
        done_create_location = true;
    });
    assert(wait_for_condition(() => done_create_location));
    assert(created_location_id == "l2");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.contains("/locations"));

    var values = new Gee.HashMap<string, string>();
    values.set("token", "abc");
    bool done_bind = false;
    bool ok_bind = false;
    client.bind_storage_location.begin("l2", values, "Preview", (obj, res) => {
        try {
            client.bind_storage_location.end(res);
            ok_bind = true;
        } catch (Error e) {
            ok_bind = false;
        }
        done_bind = true;
    });
    assert(wait_for_condition(() => done_bind));
    assert(ok_bind);
    assert(transport.last_method == "PUT");
    assert(transport.last_uri.contains("/locations/l2/binding"));

    bool done_prefer = false;
    bool ok_prefer = false;
    client.prefer_storage_location.begin("p1", "l2", (obj, res) => {
        try {
            client.prefer_storage_location.end(res);
            ok_prefer = true;
        } catch (Error e) {
            ok_prefer = false;
        }
        done_prefer = true;
    });
    assert(wait_for_condition(() => done_prefer));
    assert(ok_prefer);
    assert(transport.last_method == "PUT");
    assert(transport.last_uri.contains("/locations/preferred"));

    bool done_test = false;
    bool ok_test = false;
    client.test_storage_location.begin("l2", (obj, res) => {
        try {
            client.test_storage_location.end(res);
            ok_test = true;
        } catch (Error e) {
            ok_test = false;
        }
        done_test = true;
    });
    assert(wait_for_condition(() => done_test));
    assert(ok_test);
    assert(transport.last_method == "POST");
    assert(transport.last_uri.contains("/locations/l2/test"));

    bool done_delete = false;
    bool ok_delete = false;
    client.delete_storage_location.begin("l2", (obj, res) => {
        try {
            client.delete_storage_location.end(res);
            ok_delete = true;
        } catch (Error e) {
            ok_delete = false;
        }
        done_delete = true;
    });
    assert(wait_for_condition(() => done_delete));
    assert(ok_delete);
    assert(transport.last_method == "DELETE");
    assert(transport.last_uri.contains("/locations/l2"));
}

private void test_asset_import_start_and_poll() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"job_id\":\"j1\",\"status\":\"pending\",\"resource_id\":null,\"asset_id\":null,\"duplicate_reused\":false,\"link_created\":false,\"error\":null}}"
    );
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"job_id\":\"j1\",\"status\":\"completed\",\"resource_id\":\"r1\",\"asset_id\":\"a1\",\"duplicate_reused\":false,\"link_created\":true,\"error\":null}}"
    );
    var client = make_client(transport);

    bool done_start = false;
    HolderLinux.AssetImportJob? started = null;
    client.start_asset_import.begin("p1", "c1", "l1", "/tmp/file.png", (obj, res) => {
        try {
            started = client.start_asset_import.end(res);
        } catch (Error e) {
            started = null;
        }
        done_start = true;
    });
    assert(wait_for_condition(() => done_start));
    assert(transport.last_method == "POST");
    assert(transport.last_uri.contains("/imports"));
    assert(started != null);
    assert(started.job_id == "j1");
    assert(started.status == "pending");
    assert(started.resource_id == null);

    bool done_poll = false;
    HolderLinux.AssetImportJob? polled = null;
    client.get_asset_import_job.begin("j1", (obj, res) => {
        try {
            polled = client.get_asset_import_job.end(res);
        } catch (Error e) {
            polled = null;
        }
        done_poll = true;
    });
    assert(wait_for_condition(() => done_poll));
    assert(transport.last_method == "GET");
    assert(transport.last_uri.contains("/imports/j1"));
    assert(polled != null);
    assert(polled.status == "completed");
    assert(polled.link_created);
    assert(polled.resource_id == "r1");
}

private string make_download_dir() {
    try {
        return DirUtils.make_tmp("holder-api-download-XXXXXX");
    } catch (Error e) {
        assert_not_reached();
    }
}

private Error? run_download(HolderLinux.ApiClient client, string resource_id, string asset_id, string destination) {
    bool done = false;
    Error? failure = null;
    client.download_asset.begin(resource_id, asset_id, destination, (obj, res) => {
        try {
            client.download_asset.end(res);
        } catch (Error e) {
            failure = e;
        }
        done = true;
    });
    assert(wait_for_condition(() => done));
    return failure;
}

private void test_download_asset_streams_content_to_the_destination_file() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream(200, "asset-bytes");
    var client = make_client(transport);
    var destination = Path.build_filename(make_download_dir(), "asset.bin");

    assert(run_download(client, "r 1", "a/2", destination) == null);
    assert(transport.last_method == "GET");
    assert(transport.last_uri.contains("/resources/r%201/assets/a%2F2/content"));
    assert(transport.last_auth == "Bearer token-123");
    string contents;
    try {
        FileUtils.get_contents(destination, out contents);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(contents == "asset-bytes");
}

private void test_download_asset_reports_http_and_transport_failures() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream(404, "");
    transport.enqueue_stream_throw("connection reset");
    var client = make_client(transport);
    var destination = Path.build_filename(make_download_dir(), "asset.bin");

    var http_failure = run_download(client, "r1", "a1", destination);
    assert(http_failure is HolderLinux.ApiError.HTTP);
    assert(http_failure.message.contains("HTTP 404"));
    assert(!FileUtils.test(destination, FileTest.EXISTS));

    var transport_failure = run_download(client, "r1", "a1", destination);
    assert(transport_failure is HolderLinux.ApiError.TRANSPORT);
    assert(transport_failure.message.contains("connection reset"));
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
    Test.add_func("/api_client_resources/create_and_update_resource_with_metadata_map",
                  test_create_and_update_resource_with_metadata_map);
    Test.add_func("/api_client_resources/storage_location_lifecycle",
                  test_storage_location_lifecycle);
    Test.add_func("/api_client_resources/asset_import_start_and_poll",
                  test_asset_import_start_and_poll);
    Test.add_func("/api_client_resources/download_asset_streams_content_to_the_destination_file",
                  test_download_asset_streams_content_to_the_destination_file);
    Test.add_func("/api_client_resources/download_asset_reports_http_and_transport_failures",
                  test_download_asset_reports_http_and_transport_failures);

    return Test.run();
}

}
