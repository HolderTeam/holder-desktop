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

private void test_parse_ai_capabilities_full_and_defaults() {
    var root_full = parse_json_object(
        "{\"data\":{" +
        "\"runner_available\":true," +
        "\"error\":\"none\"," +
        "\"last_checked\":123," +
        "\"version\":\"1.2.3\"," +
        "\"caste\":{\"name\":\"CasteX\"}," +
        "\"models\":[{\"name\":\"m1\"},{\"id\":\"skip\"}]," +
        "\"recommended_install\":[{\"tag\":\"t1\"},{\"id\":\"skip\"}]" +
        "}}"
    );

    HolderLinux.AiCapabilitiesInfo full;
    try {
        full = HolderLinux.ApiParsersAi.parse_ai_capabilities(root_full);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(full.runner_available);
    assert(full.runner_error == "none");
    assert(full.last_checked == 123);
    assert(full.runner_version == "1.2.3");
    assert(full.caste_name == "CasteX");
    assert(full.models.size == 1);
    assert(full.models[0] == "m1");
    assert(full.recommended_install.size == 1);
    assert(full.recommended_install[0] == "t1");

    var root_defaults = parse_json_object("{\"data\":{}}");
    HolderLinux.AiCapabilitiesInfo defaults;
    try {
        defaults = HolderLinux.ApiParsersAi.parse_ai_capabilities(root_defaults);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(!defaults.runner_available);
    assert(defaults.runner_error == "");
    assert(defaults.last_checked == 0);
    assert(defaults.runner_version == "");
    assert(defaults.caste_name == "");
    assert(defaults.models.size == 0);
    assert(defaults.recommended_install.size == 0);
}

private void test_parse_ai_capabilities_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");
    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_capabilities(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for ai capabilities response");
    }
    assert(got_protocol);
}

private void test_parse_ai_status_full_and_defaults() {
    var root_full = parse_json_object(
        "{\"data\":{" +
        "\"checked_at\":321," +
        "\"runner_available\":true," +
        "\"runner_error\":\"\"," +
        "\"active_runs\":2," +
        "\"active_pull_jobs\":3," +
        "\"cloud_configured_providers\":4," +
        "\"pulls\":[" +
        "{\"model\":\"m1\",\"status\":\"pulling\",\"progress\":{\"percent\":12.5}}," +
        "{\"progress\":{}," +
        "\"unused\":true}," +
        "{\"model\":\"m3\",\"status\":\"queued\"}" +
        "]" +
        "}}"
    );

    HolderLinux.AiStatusInfo full;
    try {
        full = HolderLinux.ApiParsersAi.parse_ai_status(root_full);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(full.checked_at == 321);
    assert(full.runner_available);
    assert(full.runner_error == "");
    assert(full.active_runs == 2);
    assert(full.active_pull_jobs == 3);
    assert(full.cloud_configured_providers == 4);
    assert(full.pull_jobs.size == 3);
    assert(full.pull_jobs[0] == "m1 (pulling, 12.5%)");
    assert(full.pull_jobs[1] == "unknown (unknown, 0.0%)");
    assert(full.pull_jobs[2] == "m3 (queued, 0.0%)");

    var root_defaults = parse_json_object("{\"data\":{}}");
    HolderLinux.AiStatusInfo defaults;
    try {
        defaults = HolderLinux.ApiParsersAi.parse_ai_status(root_defaults);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(defaults.checked_at == 0);
    assert(!defaults.runner_available);
    assert(defaults.runner_error == "");
    assert(defaults.active_runs == 0);
    assert(defaults.active_pull_jobs == 0);
    assert(defaults.cloud_configured_providers == 0);
    assert(defaults.pull_jobs.size == 0);
}

private void test_parse_ai_status_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");
    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_status(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for ai status response");
    }
    assert(got_protocol);
}

private void test_parse_ai_threads_full_and_defaults() {
    var root = parse_json_object(
        "{\"data\":[" +
        "{\"thread_id\":\"t1\",\"project_id\":\"p1\",\"title\":\"A\",\"created_at\":10,\"updated_at\":20}," +
        "{\"thread_id\":\"t2\",\"project_id\":\"p2\",\"title\":\"B\"}" +
        "]}"
    );

    Gee.ArrayList<HolderLinux.AiThreadSummary> threads;
    try {
        threads = HolderLinux.ApiParsersAi.parse_ai_threads(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(threads.size == 2);
    assert(threads[0].thread_id == "t1");
    assert(threads[0].project_id == "p1");
    assert(threads[0].title == "A");
    assert(threads[0].created_at == 10);
    assert(threads[0].updated_at == 20);
    assert(threads[1].thread_id == "t2");
    assert(threads[1].project_id == "p2");
    assert(threads[1].title == "B");
    assert(threads[1].created_at == 0);
    assert(threads[1].updated_at == 0);
}

private void test_parse_ai_threads_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");
    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_threads(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for ai threads response");
    }
    assert(got_protocol);
}

private void test_parse_ai_provider_catalog_paths() {
    Gee.ArrayList<HolderLinux.AiCatalogProvider> providers;

    var no_models = parse_json_object("{\"x\":1}");
    try {
        providers = HolderLinux.ApiParsersAi.parse_ai_provider_catalog(no_models);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(providers.size == 0);

    var no_defaults = parse_json_object("{\"models\":{}}");
    try {
        providers = HolderLinux.ApiParsersAi.parse_ai_provider_catalog(no_defaults);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(providers.size == 0);

    var with_entries = parse_json_object(
        "{\"models\":{\"provider_defaults\":{" +
        "\"obj_enabled\":{\"provider\":\"Obj Name\",\"enabled\":true,\"setup_url\":\"s\",\"docs_url\":\"d\"}," +
        "\"obj_fallback\":{\"provider\":\"\",\"setup_url\":\"s2\"}," +
        "\"not_object\":1" +
        "}}}"
    );
    try {
        providers = HolderLinux.ApiParsersAi.parse_ai_provider_catalog(with_entries);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(providers.size == 2);
    assert(providers[0].id == "obj_enabled");
    assert(providers[0].display_name == "Obj Name");
    assert(providers[0].enabled);
    assert(providers[0].setup_url == "s");
    assert(providers[0].docs_url == "d");

    assert(providers[1].id == "obj_fallback");
    assert(providers[1].display_name == "obj_fallback");
    assert(!providers[1].enabled);
    assert(providers[1].setup_url == "s2");
    assert(providers[1].docs_url == "");
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/parsers/ai/capabilities-full-and-defaults", test_parse_ai_capabilities_full_and_defaults);
    Test.add_func("/parsers/ai/capabilities-missing-data-protocol-error", test_parse_ai_capabilities_missing_data_is_protocol_error);
    Test.add_func("/parsers/ai/status-full-and-defaults", test_parse_ai_status_full_and_defaults);
    Test.add_func("/parsers/ai/status-missing-data-protocol-error", test_parse_ai_status_missing_data_is_protocol_error);
    Test.add_func("/parsers/ai/threads-full-and-defaults", test_parse_ai_threads_full_and_defaults);
    Test.add_func("/parsers/ai/threads-missing-data-protocol-error", test_parse_ai_threads_missing_data_is_protocol_error);
    Test.add_func("/parsers/ai/provider-catalog-paths", test_parse_ai_provider_catalog_paths);

    return Test.run();
}

}
