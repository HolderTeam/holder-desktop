namespace HolderLinuxTests {

private class FakeClock : Object, HolderLinux.IClock {
    public int64 now_value { get; set; default = 1000; }

    public int64 now_epoch_seconds() {
        return now_value;
    }
}

private class FakeUpdateMetadataTransport : Object, HolderLinux.IUpdateMetadataTransport {
    public string body { get; set; default = ""; }
    public bool fail { get; set; default = false; }
    public int calls { get; private set; default = 0; }
    public string last_url { get; private set; default = ""; }

    public async string fetch_text(string url) throws Error {
        calls++;
        last_url = url;
        if (fail) {
            throw new IOError.FAILED("network failed");
        }
        return body;
    }
}

private string metadata(string version,
                        string product = "Holder",
                        string channel = "stable",
                        string windows_url = "https://holder.team/downloads/Holder-windows.exe",
                        string release_url = "https://holder.team/releases/holder") {
    return """
{
  "schema": 1,
  "product": "%s",
  "channel": "%s",
  "version": "%s",
  "message": "Holder %s is ready.",
  "release_url": "%s",
  "downloads": {
    "linux": "https://holder.team/linux",
    "macos": "https://holder.team/mac",
    "windows": "%s"
  }
}
""".printf(product, channel, version, version, release_url, windows_url);
}

private Settings fresh_settings() {
    var settings = new Settings(HolderLinux.AppSettings.SCHEMA_ID);
    settings.set_int64(HolderLinux.AppSettings.KEY_UPDATE_LAST_CHECK_AT, 0);
    settings.set_string(HolderLinux.AppSettings.KEY_UPDATE_LAST_PROMPT_VERSION, "");
    settings.set_int64(HolderLinux.AppSettings.KEY_UPDATE_LAST_PROMPT_AT, 0);
    return settings;
}

private HolderLinux.UpdateCandidate? run_check_if_due(HolderLinux.UpdateCheckService service,
                                                      Settings? settings,
                                                      string current_version) {
    var loop = new MainLoop();
    HolderLinux.UpdateCandidate? result = null;
    service.check_if_due.begin(settings, current_version, (obj, res) => {
        result = service.check_if_due.end(res);
        loop.quit();
    });
    loop.run();
    return result;
}

private HolderLinux.UpdateCandidate? run_fetch_candidate(HolderLinux.UpdateCheckService service,
                                                         string current_version) throws Error {
    var loop = new MainLoop();
    HolderLinux.UpdateCandidate? result = null;
    Error? caught_error = null;
    service.fetch_update_candidate.begin(current_version, (obj, res) => {
        try {
            result = service.fetch_update_candidate.end(res);
        } catch (Error e) {
            caught_error = e;
        }
        loop.quit();
    });
    loop.run();
    if (caught_error != null) {
        throw caught_error;
    }
    return result;
}

private void test_compare_versions() {
    assert(HolderLinux.UpdateCheckService.compare_versions("0.1.8", "0.1.7") > 0);
    assert(HolderLinux.UpdateCheckService.compare_versions("0.1.7", "0.1.7") == 0);
    assert(HolderLinux.UpdateCheckService.compare_versions("0.1.7", "0.1.8") < 0);
    assert(HolderLinux.UpdateCheckService.compare_versions("0.1.7.1", "0.1.7") > 0);
    assert(HolderLinux.UpdateCheckService.compare_versions("0.2.0", "0.10.0") < 0);
    assert(HolderLinux.UpdateCheckService.compare_versions("bad", "0.1.7") == 0);
}

private void test_parse_valid_metadata_uses_platform_download() {
    var transport = new FakeUpdateMetadataTransport();
    var service = new HolderLinux.UpdateCheckService(transport, new FakeClock(), null, "windows");

    var candidate = service.parse_metadata(metadata("0.1.8"));

    assert(candidate != null);
    assert(candidate.version == "0.1.8");
    assert(candidate.download_url == "https://holder.team/downloads/Holder-windows.exe");
    assert(candidate.message.contains("0.1.8"));
}

private void test_parse_invalid_metadata_is_ignored() {
    var service = new HolderLinux.UpdateCheckService(new FakeUpdateMetadataTransport(), new FakeClock(), null, "linux");

    assert(service.parse_metadata(metadata("0.1.8", "Other")) == null);
    assert(service.parse_metadata(metadata("0.1.8", "Holder", "dev")) == null);
    assert(service.parse_metadata(metadata("0.1.8-beta")) == null);
    assert(service.parse_metadata("""{"schema": 2, "product": "Holder"}""") == null);
    assert(service.parse_metadata("not json") == null);
}

private void test_parse_falls_back_to_release_url() {
    var service = new HolderLinux.UpdateCheckService(new FakeUpdateMetadataTransport(), new FakeClock(), null, "freebsd");

    var candidate = service.parse_metadata(metadata("0.1.8"));

    assert(candidate != null);
    assert(candidate.download_url == "https://holder.team/releases/holder");
}

private void test_fetch_candidate_ignores_current_or_older_versions() {
    var transport = new FakeUpdateMetadataTransport();
    transport.body = metadata("0.1.7");
    var service = new HolderLinux.UpdateCheckService(transport, new FakeClock(), "https://example.test/version.json", "linux");

    try {
        assert(run_fetch_candidate(service, "0.1.7") == null);
        transport.body = metadata("0.1.6");
        assert(run_fetch_candidate(service, "0.1.7") == null);
    } catch (Error e) {
        assert_not_reached();
    }
}

private void test_check_if_due_throttles_daily_checks() {
    var clock = new FakeClock();
    clock.now_value = 10000;
    var transport = new FakeUpdateMetadataTransport();
    transport.body = metadata("0.1.8");
    var service = new HolderLinux.UpdateCheckService(transport, clock, "https://example.test/version.json", "linux");
    var settings = fresh_settings();

    assert(run_check_if_due(service, settings, "0.1.7") != null);
    assert(transport.calls == 1);
    assert(settings.get_int64(HolderLinux.AppSettings.KEY_UPDATE_LAST_CHECK_AT) == 10000);

    clock.now_value = 10000 + HolderLinux.UpdateCheckService.CHECK_INTERVAL_SECONDS - 1;
    assert(run_check_if_due(service, settings, "0.1.7") == null);
    assert(transport.calls == 1);
}

private void test_check_if_due_is_quiet_on_network_failure() {
    var clock = new FakeClock();
    clock.now_value = 20000;
    var transport = new FakeUpdateMetadataTransport();
    transport.fail = true;
    var service = new HolderLinux.UpdateCheckService(transport, clock, "https://example.test/version.json", "linux");
    var settings = fresh_settings();

    assert(run_check_if_due(service, settings, "0.1.7") == null);
    assert(transport.calls == 1);
    assert(settings.get_int64(HolderLinux.AppSettings.KEY_UPDATE_LAST_CHECK_AT) == 20000);
}

private void test_prompt_policy_is_weekly_for_same_version() {
    var clock = new FakeClock();
    clock.now_value = 30000;
    var service = new HolderLinux.UpdateCheckService(new FakeUpdateMetadataTransport(), clock, null, "linux");
    var settings = fresh_settings();

    assert(service.should_prompt(settings, "0.1.8", clock.now_value));
    service.record_prompt(settings, "0.1.8");

    assert(!service.should_prompt(settings, "0.1.8",
        clock.now_value + HolderLinux.UpdateCheckService.PROMPT_INTERVAL_SECONDS - 1));
    assert(service.should_prompt(settings, "0.1.8",
        clock.now_value + HolderLinux.UpdateCheckService.PROMPT_INTERVAL_SECONDS));
    assert(service.should_prompt(settings, "0.1.9", clock.now_value + 1));
}

private class LocalMetadataServer : Object {
    public Soup.Server server;
    public uint status { get; set; default = 200; }
    public uint8[] body = {};
    public string url = "";

    public LocalMetadataServer() {
        server = new Soup.Server(null);
        server.add_handler("/version.json", (srv, msg, path, query) => {
            msg.set_status(status, null);
            msg.set_response("application/json", Soup.MemoryUse.COPY, body);
        });
        try {
            server.listen_local(0, 0);
        } catch (Error e) {
            assert_not_reached();
        }
        url = "http://127.0.0.1:%d/version.json".printf(server.get_uris().data.get_port());
    }

    public void set_text(string text, bool nul_terminated = false) {
        var bytes = new uint8[text.length + (nul_terminated ? 1 : 0)];
        for (int i = 0; i < text.length; i++) {
            bytes[i] = text.data[i];
        }
        body = bytes;
    }
}

private string? fetch_text_via(HolderLinux.IUpdateMetadataTransport transport, string url, out Error? failure) {
    var loop = new MainLoop();
    string? text = null;
    Error? caught = null;
    transport.fetch_text.begin(url, (obj, res) => {
        try {
            text = transport.fetch_text.end(res);
        } catch (Error e) {
            caught = e;
        }
        loop.quit();
    });
    loop.run();
    failure = caught;
    return text;
}

private void test_soup_transport_fetches_text_and_trims_trailing_nul() {
    var server = new LocalMetadataServer();
    var transport = new HolderLinux.SoupUpdateMetadataTransport();

    server.set_text(metadata("0.1.8"));
    Error? failure;
    var text = fetch_text_via(transport, server.url, out failure);
    assert(failure == null);
    assert(text == metadata("0.1.8"));

    server.set_text(metadata("0.1.9"), true);
    text = fetch_text_via(transport, server.url, out failure);
    assert(failure == null);
    assert(text == metadata("0.1.9"));

    server.set_text("");
    text = fetch_text_via(new HolderLinux.SoupUpdateMetadataTransport(new Soup.Session()), server.url, out failure);
    assert(failure == null);
    assert(text == "");
}

private void test_soup_transport_rejects_non_success_status() {
    var server = new LocalMetadataServer();
    server.status = 503;
    server.set_text("unavailable");
    var transport = new HolderLinux.SoupUpdateMetadataTransport();

    Error? failure;
    var text = fetch_text_via(transport, server.url, out failure);
    assert(text == null);
    assert(failure is HolderLinux.UpdateCheckError.INVALID_METADATA);
    assert(failure.message.contains("HTTP 503"));
}

private void test_service_checks_a_real_http_endpoint() {
    var server = new LocalMetadataServer();
    server.set_text(metadata("0.1.8"));
    var service = new HolderLinux.UpdateCheckService(
        new HolderLinux.SoupUpdateMetadataTransport(), new FakeClock(), server.url, "linux"
    );

    var candidate = run_check_if_due(service, fresh_settings(), "0.1.7");
    assert(candidate != null);
    assert(candidate.version == "0.1.8");
    assert(candidate.download_url == "https://holder.team/linux");
}

private void test_check_if_due_without_settings_is_a_noop() {
    var transport = new FakeUpdateMetadataTransport();
    var service = new HolderLinux.UpdateCheckService(transport, new FakeClock(), null, "linux");

    assert(run_check_if_due(service, null, "0.1.7") == null);
    assert(transport.calls == 0);
    service.record_prompt(null, "0.1.8");
}

private void test_check_if_due_returns_null_when_no_newer_candidate() {
    var transport = new FakeUpdateMetadataTransport();
    transport.body = metadata("0.1.7");
    var service = new HolderLinux.UpdateCheckService(transport, new FakeClock(), null, "linux");

    assert(run_check_if_due(service, fresh_settings(), "0.1.7") == null);
    assert(transport.calls == 1);
}

private void test_check_if_due_suppresses_recently_prompted_candidate() {
    var clock = new FakeClock();
    clock.now_value = 10000;
    var transport = new FakeUpdateMetadataTransport();
    transport.body = metadata("0.1.8");
    var service = new HolderLinux.UpdateCheckService(transport, clock, null, "linux");
    var settings = fresh_settings();

    var candidate = run_check_if_due(service, settings, "0.1.7");
    assert(candidate != null);
    service.record_prompt(settings, candidate.version);

    clock.now_value += HolderLinux.UpdateCheckService.CHECK_INTERVAL_SECONDS;
    assert(run_check_if_due(service, settings, "0.1.7") == null);
    assert(transport.calls == 2);
}

private void test_fetch_candidate_ignores_unparseable_metadata() {
    var transport = new FakeUpdateMetadataTransport();
    transport.body = "not json";
    var service = new HolderLinux.UpdateCheckService(transport, new FakeClock(), null, "linux");

    try {
        assert(run_fetch_candidate(service, "0.1.7") == null);
    } catch (Error e) {
        assert_not_reached();
    }
}

private void test_parse_metadata_without_any_download_url_is_ignored() {
    var service = new HolderLinux.UpdateCheckService(new FakeUpdateMetadataTransport(), new FakeClock(), null, "linux");

    assert(service.parse_metadata(
        """{"schema":1,"product":"Holder","channel":"stable","version":"0.2.0"}"""
    ) == null);
    assert(service.parse_metadata(
        """{"schema":1,"product":"Holder","channel":"stable","version":"0.2.0","downloads":{"linux":""}}"""
    ) == null);
}

private void test_parse_metadata_defaults_message_and_tolerates_odd_downloads() {
    var service = new HolderLinux.UpdateCheckService(new FakeUpdateMetadataTransport(), new FakeClock(), null, "linux");

    var candidate = service.parse_metadata(
        """{"schema":1,"product":"Holder","channel":"stable","version":"0.2.0","release_url":"https://holder.team/r","downloads":"nope"}"""
    );
    assert(candidate != null);
    assert(candidate.message == "A new Holder release is available.");
    assert(candidate.download_url == "https://holder.team/r");

    candidate = service.parse_metadata(
        """{"schema":1,"product":"Holder","channel":"stable","version":"0.2.0","release_url":"https://holder.team/r","downloads":{"linux":{"nested":true}}}"""
    );
    assert(candidate != null);
    assert(candidate.download_url == "https://holder.team/r");
}

private void test_dotted_version_validation_rejects_malformed_versions() {
    assert(!HolderLinux.UpdateCheckService.is_dotted_numeric_version(""));
    assert(!HolderLinux.UpdateCheckService.is_dotted_numeric_version("  "));
    assert(!HolderLinux.UpdateCheckService.is_dotted_numeric_version("1..2"));
    assert(!HolderLinux.UpdateCheckService.is_dotted_numeric_version("1.x"));
    assert(!HolderLinux.UpdateCheckService.is_dotted_numeric_version("1.-2"));
    assert(HolderLinux.UpdateCheckService.is_dotted_numeric_version(" 1.2.3 "));
}

private string download_url_for_platform_env(string? platform_env) {
    var previous = Environment.get_variable("HOLDER_DESKTOP_TEST_PLATFORM");
    if (platform_env == null) {
        Environment.unset_variable("HOLDER_DESKTOP_TEST_PLATFORM");
    } else {
        Environment.set_variable("HOLDER_DESKTOP_TEST_PLATFORM", platform_env, true);
    }
    var service = new HolderLinux.UpdateCheckService(new FakeUpdateMetadataTransport(), new FakeClock());
    if (previous == null) {
        Environment.unset_variable("HOLDER_DESKTOP_TEST_PLATFORM");
    } else {
        Environment.set_variable("HOLDER_DESKTOP_TEST_PLATFORM", previous, true);
    }
    var candidate = service.parse_metadata(metadata("0.2.0"));
    assert(candidate != null);
    return candidate.download_url;
}

private void test_platform_key_is_resolved_from_the_environment() {
    assert(download_url_for_platform_env("darwin") == "https://holder.team/mac");
    assert(download_url_for_platform_env("MacOS") == "https://holder.team/mac");
    assert(download_url_for_platform_env("windows") == "https://holder.team/downloads/Holder-windows.exe");
    assert(download_url_for_platform_env("mingw") == "https://holder.team/downloads/Holder-windows.exe");
    assert(download_url_for_platform_env("linux") == "https://holder.team/linux");
    assert(download_url_for_platform_env("plan9") == "https://holder.team/linux");
    // Falls back to the compiled-in platform when the override is absent.
    assert(download_url_for_platform_env(null).length > 0);
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/update_check/compare_versions", test_compare_versions);
    Test.add_func("/update_check/parse_valid_metadata_uses_platform_download", test_parse_valid_metadata_uses_platform_download);
    Test.add_func("/update_check/parse_invalid_metadata_is_ignored", test_parse_invalid_metadata_is_ignored);
    Test.add_func("/update_check/parse_falls_back_to_release_url", test_parse_falls_back_to_release_url);
    Test.add_func("/update_check/fetch_candidate_ignores_current_or_older_versions", test_fetch_candidate_ignores_current_or_older_versions);
    Test.add_func("/update_check/check_if_due_throttles_daily_checks", test_check_if_due_throttles_daily_checks);
    Test.add_func("/update_check/check_if_due_is_quiet_on_network_failure", test_check_if_due_is_quiet_on_network_failure);
    Test.add_func("/update_check/prompt_policy_is_weekly_for_same_version", test_prompt_policy_is_weekly_for_same_version);

    Test.add_func("/update_check/soup_transport_fetches_text_and_trims_trailing_nul", test_soup_transport_fetches_text_and_trims_trailing_nul);
    Test.add_func("/update_check/soup_transport_rejects_non_success_status", test_soup_transport_rejects_non_success_status);
    Test.add_func("/update_check/service_checks_a_real_http_endpoint", test_service_checks_a_real_http_endpoint);
    Test.add_func("/update_check/check_if_due_without_settings_is_a_noop", test_check_if_due_without_settings_is_a_noop);
    Test.add_func("/update_check/check_if_due_returns_null_when_no_newer_candidate", test_check_if_due_returns_null_when_no_newer_candidate);
    Test.add_func("/update_check/check_if_due_suppresses_recently_prompted_candidate", test_check_if_due_suppresses_recently_prompted_candidate);
    Test.add_func("/update_check/fetch_candidate_ignores_unparseable_metadata", test_fetch_candidate_ignores_unparseable_metadata);
    Test.add_func("/update_check/parse_metadata_without_any_download_url_is_ignored", test_parse_metadata_without_any_download_url_is_ignored);
    Test.add_func("/update_check/parse_metadata_defaults_message_and_tolerates_odd_downloads", test_parse_metadata_defaults_message_and_tolerates_odd_downloads);
    Test.add_func("/update_check/dotted_version_validation_rejects_malformed_versions", test_dotted_version_validation_rejects_malformed_versions);
    Test.add_func("/update_check/platform_key_is_resolved_from_the_environment", test_platform_key_is_resolved_from_the_environment);

    return Test.run();
}

}
