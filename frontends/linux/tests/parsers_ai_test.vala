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
        "{\"job_id\":\"job-1\",\"runner_id\":\"auto-local\",\"model\":\"m1\",\"status\":\"pulling\",\"progress\":{\"percent\":12.5,\"stage\":\"downloading\"}}," +
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
    assert(full.pulls.size == 3);
    assert(full.pulls[0].job_id == "job-1");
    assert(full.pulls[0].runner_id == "auto-local");
    assert(full.pulls[0].model == "m1");
    assert(full.pulls[0].status == "pulling");
    assert(full.pulls[0].percent == 12.5);
    assert(full.pulls[0].stage == "downloading");
    assert(full.pulls[1].runner_id == "");
    assert(full.pulls[1].model == "unknown");
    assert(full.pulls[1].status == "unknown");
    assert(full.pulls[1].percent == 0.0);
    assert(full.pulls[2].model == "m3");
    assert(full.pulls[2].status == "queued");

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
    assert(defaults.pulls.size == 0);
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

private void test_parse_ai_runners_full_and_defaults() {
    var root = parse_json_object(
        "{\"data\":{\"runners\":[" +
        "{\"runner_id\":\"auto-local\",\"name\":\"Local Ollama\",\"kind\":\"ollama\",\"source\":\"auto_local\",\"enabled\":true," +
        "\"runtime\":{\"configured\":true,\"available\":true,\"spawn_attempted\":false,\"last_checked\":5,\"version\":\"1.2.3\",\"error\":\"\"," +
        "\"models\":[{\"name\":\"m1\"},{\"digest\":\"skip\"}]," +
        "\"pulls\":[{\"job_id\":\"job-1\",\"runner_id\":\"auto-local\",\"model\":\"m2\",\"status\":\"pulling\",\"progress\":{\"percent\":10.5,\"stage\":\"downloading\"}}]}}," +
        "{\"runner_id\":\"manual-a\",\"name\":\"Office\",\"kind\":\"ollama\",\"base_url\":\"http://office:11434\",\"source\":\"manual\",\"enabled\":false}" +
        "]}}"
    );

    Gee.ArrayList<HolderLinux.AiRunnerInfo> runners;
    try {
        runners = HolderLinux.ApiParsersAi.parse_ai_runners(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(runners.size == 2);
    assert(runners[0].runner_id == "auto-local");
    assert(runners[0].runtime.available);
    assert(runners[0].runtime.models.size == 1);
    assert(runners[0].runtime.models[0] == "m1");
    assert(runners[0].runtime.pulls.size == 1);
    assert(runners[0].runtime.pulls[0].percent == 10.5);
    assert(runners[1].runner_id == "manual-a");
    assert(runners[1].base_url == "http://office:11434");
    assert(!runners[1].runtime.configured);
    assert(runners[1].runtime.models.size == 0);
}

private void test_parse_ai_runners_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");
    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_runners(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for ai runners response");
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
    Test.add_func("/parsers/ai/runners-full-and-defaults", test_parse_ai_runners_full_and_defaults);
    Test.add_func("/parsers/ai/runners-missing-data-protocol-error", test_parse_ai_runners_missing_data_is_protocol_error);
    Test.add_func("/parsers/ai/threads-full-and-defaults", test_parse_ai_threads_full_and_defaults);
    Test.add_func("/parsers/ai/threads-missing-data-protocol-error", test_parse_ai_threads_missing_data_is_protocol_error);
    Test.add_func("/parsers/ai/provider-catalog-paths", test_parse_ai_provider_catalog_paths);

    return Test.run();
}

}
