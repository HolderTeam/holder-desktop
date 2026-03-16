using GLib;

namespace HolderLinuxTests {

private Json.Object parse_json_object(string payload) {
    var parser = new Json.Parser();
    try {
        parser.load_from_data(payload, -1);
    } catch (Error e) {
        assert_not_reached();
    }
    return parser.get_root().get_object();
}

private void test_parse_health_info_full_fields() {
    var root = parse_json_object(
        "{\"data\":{\"db_ok\":true,\"uptime_ms\":1234,\"api_version\":\"v1\",\"server_version\":\"s1\",\"pid\":99}}"
    );

    HolderLinux.HealthInfo info;
    try {
        info = HolderLinux.ApiParsersHealth.parse_health_info(root);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(info.db_ok == true);
    assert(info.uptime_ms == 1234);
    assert(info.api_version == "v1");
    assert(info.server_version == "s1");
    assert(info.pid == 99);
}

private void test_parse_health_info_defaults_when_fields_missing_or_null() {
    var root = parse_json_object(
        "{\"data\":{\"api_version\":null,\"server_version\":null}}"
    );

    HolderLinux.HealthInfo info;
    try {
        info = HolderLinux.ApiParsersHealth.parse_health_info(root);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(info.db_ok == false);
    assert(info.uptime_ms == 0);
    assert(info.api_version == "");
    assert(info.server_version == "");
    assert(info.pid == 0);
}

private void test_parse_health_info_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");

    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersHealth.parse_health_info(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for health response");
    }

    assert(got_protocol);
}

private void test_parse_health_info_false_and_zero_values() {
    var root = parse_json_object(
        "{\"data\":{\"db_ok\":false,\"uptime_ms\":0,\"api_version\":\"\",\"server_version\":\"\",\"pid\":0}}"
    );

    HolderLinux.HealthInfo info;
    try {
        info = HolderLinux.ApiParsersHealth.parse_health_info(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(info.db_ok == false);
    assert(info.uptime_ms == 0);
    assert(info.api_version == "");
    assert(info.server_version == "");
    assert(info.pid == 0);
}

private void test_parse_health_info_ignores_extra_fields() {
    var root = parse_json_object(
        "{\"data\":{\"db_ok\":true,\"uptime_ms\":7,\"api_version\":\"v\",\"server_version\":\"s\",\"pid\":1,\"extra\":\"ignored\"}}"
    );

    HolderLinux.HealthInfo info;
    try {
        info = HolderLinux.ApiParsersHealth.parse_health_info(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(info.db_ok == true);
    assert(info.uptime_ms == 7);
    assert(info.api_version == "v");
    assert(info.server_version == "s");
    assert(info.pid == 1);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/parsers/health/full-fields", test_parse_health_info_full_fields);
    Test.add_func("/parsers/health/defaults-missing-or-null", test_parse_health_info_defaults_when_fields_missing_or_null);
    Test.add_func("/parsers/health/missing-data-protocol-error", test_parse_health_info_missing_data_is_protocol_error);
    Test.add_func("/parsers/health/false-and-zero-values", test_parse_health_info_false_and_zero_values);
    Test.add_func("/parsers/health/ignores-extra-fields", test_parse_health_info_ignores_extra_fields);

    return Test.run();
}

}
