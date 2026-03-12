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
    assert(transport.last_method == "GET");
    assert(transport.last_uri.contains("/health"));
}

private void test_health_check_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.health_check.begin((obj, res) => {
        try {
            client.health_check.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

private void test_get_health_info_parses_data() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"db_ok\":true,\"uptime_ms\":4321,\"api_version\":\"0.1\",\"server_version\":\"1.2.3\",\"pid\":999}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.HealthInfo? info = null;
    client.get_health_info.begin((obj, res) => {
        try {
            info = client.get_health_info.end(res);
        } catch (Error e) {
            info = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(info != null);
    assert(info.db_ok);
    assert(info.uptime_ms == 4321);
    assert(info.api_version == "0.1");
    assert(info.server_version == "1.2.3");
    assert(info.pid == 999);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/api_client_health/health_check_success", test_health_check_success);
    Test.add_func("/api_client_health/health_check_missing_data_is_protocol_error",
                  test_health_check_missing_data_is_protocol_error);
    Test.add_func("/api_client_health/get_health_info_parses_data",
                  test_get_health_info_parses_data);

    return Test.run();
}

}
