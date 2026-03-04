using GLib;

namespace HolderLinuxTests {

private string setup_temp_data_home() {
    string dir;
    try {
        dir = DirUtils.make_tmp("holder-linux-discovery-test-XXXXXX");
    } catch (FileError e) {
        assert_not_reached();
    }
    Environment.set_variable("XDG_DATA_HOME", dir, true);
    return dir;
}

private string holder_info_path_for_current_env() {
    return Path.build_filename(
        Environment.get_user_data_dir(),
        "holder",
        "server",
        "holder.json"
    );
}

private void write_holder_json(string text) {
    var path = holder_info_path_for_current_env();
    var dir = Path.get_dirname(path);
    DirUtils.create_with_parents(dir, 0755);
    try {
        FileUtils.set_contents(path, text);
    } catch (FileError e) {
        assert_not_reached();
    }
}

private void test_holder_info_path_uses_user_data_dir() {
    var temp_home = setup_temp_data_home();
    var expected = Path.build_filename(temp_home, "holder", "server", "holder.json");
    var actual = HolderLinux.Discovery.holder_info_path();
    assert(actual == expected);
}

private void test_discover_server_not_found() {
    setup_temp_data_home();

    bool got_not_found = false;
    try {
        HolderLinux.Discovery.discover_server();
    } catch (Error e) {
        got_not_found = (e is HolderLinux.DiscoveryError.NOT_FOUND);
    }
    assert(got_not_found);
}

private void test_discover_server_invalid_json() {
    setup_temp_data_home();
    write_holder_json("{ this is not valid json");

    bool got_invalid = false;
    try {
        HolderLinux.Discovery.discover_server();
    } catch (Error e) {
        got_invalid = (e is HolderLinux.DiscoveryError.INVALID_FORMAT);
    }
    assert(got_invalid);
}

private void test_discover_server_invalid_root() {
    setup_temp_data_home();
    write_holder_json("[]");

    bool got_invalid = false;
    try {
        HolderLinux.Discovery.discover_server();
    } catch (Error e) {
        got_invalid = (e is HolderLinux.DiscoveryError.INVALID_FORMAT);
    }
    assert(got_invalid);
}

private void test_discover_server_missing_required_fields() {
    setup_temp_data_home();
    write_holder_json("{\"pid\":1,\"bind\":\"127.0.0.1\"}");

    bool got_invalid = false;
    try {
        HolderLinux.Discovery.discover_server();
    } catch (Error e) {
        got_invalid = (e is HolderLinux.DiscoveryError.INVALID_FORMAT);
    }
    assert(got_invalid);
}

private void test_discover_server_read_failure_when_path_is_directory() {
    setup_temp_data_home();
    var path = holder_info_path_for_current_env();
    var dir = Path.get_dirname(path);
    DirUtils.create_with_parents(dir, 0755);
    try {
        FileUtils.set_contents(path, "{\"pid\":1}");
    } catch (FileError e) {
        assert_not_reached();
    }

    int chmod_status = -1;
    try {
        Process.spawn_command_line_sync("chmod 000 %s".printf(Shell.quote(path)),
                                        null, null, out chmod_status);
    } catch (SpawnError e) {
        assert_not_reached();
    }
    assert(chmod_status == 0);

    bool got_invalid = false;
    bool got_read_failure_message = false;
    try {
        HolderLinux.Discovery.discover_server();
    } catch (Error e) {
        got_invalid = (e is HolderLinux.DiscoveryError.INVALID_FORMAT);
        got_read_failure_message = e.message.contains("Failed to read");
    }
    assert(got_invalid);
    assert(got_read_failure_message);

    int restore_status = -1;
    try {
        Process.spawn_command_line_sync("chmod 600 %s".printf(Shell.quote(path)),
                                        null, null, out restore_status);
    } catch (SpawnError e) {
        assert_not_reached();
    }
    assert(restore_status == 0);
}

private void test_discover_server_success() {
    setup_temp_data_home();
    write_holder_json(
        "{" +
        "\"pid\":1234," +
        "\"bind\":\"127.0.0.1\"," +
        "\"port\":8080," +
        "\"started_at\":100," +
        "\"api_version\":\"0.1\"," +
        "\"server_version\":\"1.2.3\"," +
        "\"auth_token\":\"token\"" +
        "}"
    );

    HolderLinux.ServerInfo? info = null;
    try {
        info = HolderLinux.Discovery.discover_server();
    } catch (Error e) {
        info = null;
    }

    assert(info != null);
    assert(info.pid == 1234);
    assert(info.bind == "127.0.0.1");
    assert(info.port == 8080);
    assert(info.auth_token == "token");
}

private void test_file_server_discovery_delegates() {
    setup_temp_data_home();
    write_holder_json(
        "{" +
        "\"pid\":77," +
        "\"bind\":\"0.0.0.0\"," +
        "\"port\":9090," +
        "\"started_at\":50," +
        "\"api_version\":\"0.2\"," +
        "\"server_version\":\"2.0.0\"," +
        "\"auth_token\":\"abc\"" +
        "}"
    );

    var discovery = new HolderLinux.FileServerDiscovery();
    HolderLinux.ServerInfo? info = null;
    try {
        info = discovery.discover_server();
    } catch (Error e) {
        info = null;
    }

    assert(info != null);
    assert(discovery.holder_info_path().has_suffix("holder/server/holder.json"));
    assert(info.port == 9090);
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/discovery/holder_info_path_uses_user_data_dir", test_holder_info_path_uses_user_data_dir);
    Test.add_func("/discovery/discover_server_not_found", test_discover_server_not_found);
    Test.add_func("/discovery/discover_server_invalid_json", test_discover_server_invalid_json);
    Test.add_func("/discovery/discover_server_invalid_root", test_discover_server_invalid_root);
    Test.add_func("/discovery/discover_server_missing_required_fields", test_discover_server_missing_required_fields);
    Test.add_func("/discovery/discover_server_read_failure_when_path_is_directory",
                  test_discover_server_read_failure_when_path_is_directory);
    Test.add_func("/discovery/discover_server_success", test_discover_server_success);
    Test.add_func("/discovery/file_server_discovery_delegates", test_file_server_discovery_delegates);

    return Test.run();
}

}
