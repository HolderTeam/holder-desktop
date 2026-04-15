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
        "\"caste\":{\"name\":\"CasteX\"}," +
        "\"runners\":[" +
        "{\"runner_id\":\"auto-local\",\"name\":\"Local Ollama\",\"kind\":\"ollama\",\"source\":\"auto_local\",\"enabled\":true," +
        "\"runtime\":{\"configured\":true,\"available\":true,\"spawn_attempted\":false,\"last_checked\":123,\"version\":\"1.2.3\",\"error\":\"none\"," +
        "\"models\":[{\"name\":\"m1\"},{\"digest\":\"skip\"}],\"pulls\":[]}}" +
        "]," +
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
        "\"active_runs\":2," +
        "\"cloud\":[{\"provider\":\"switchyard\"},{\"provider\":\"openrouter\"}]," +
        "\"runners\":[" +
        "{\"runner_id\":\"auto-local\",\"name\":\"Local Ollama\",\"kind\":\"ollama\",\"source\":\"auto_local\",\"enabled\":true," +
        "\"runtime\":{\"configured\":true,\"available\":true,\"spawn_attempted\":false,\"last_checked\":9,\"version\":\"1.2.3\",\"error\":\"\"," +
        "\"models\":[]," +
        "\"pulls\":[" +
        "{\"job_id\":\"job-1\",\"runner_id\":\"auto-local\",\"model\":\"m1\",\"status\":\"downloading\",\"progress\":{\"percent\":12.5,\"stage\":\"downloading\"}}," +
        "{\"progress\":{},\"unused\":true}," +
        "{\"model\":\"m3\",\"status\":\"queued\"}" +
        "]}}," +
        "{\"runner_id\":\"manual-a\",\"name\":\"Office\",\"kind\":\"ollama\",\"source\":\"manual\",\"enabled\":true," +
        "\"runtime\":{\"configured\":true,\"available\":false,\"spawn_attempted\":false,\"last_checked\":10,\"version\":\"\",\"error\":\"offline\"," +
        "\"models\":[]," +
        "\"pulls\":[{\"job_id\":\"job-9\",\"runner_id\":\"manual-a\",\"model\":\"m4\",\"status\":\"completed\",\"progress\":{\"percent\":100.0,\"stage\":\"done\"}}]}}" +
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
    assert(full.active_pull_jobs == 2);
    assert(full.cloud_configured_providers == 2);
    assert(full.pulls.size == 4);
    assert(full.pulls[0].job_id == "job-1");
    assert(full.pulls[0].runner_id == "auto-local");
    assert(full.pulls[0].model == "m1");
    assert(full.pulls[0].status == "downloading");
    assert(full.pulls[0].percent == 12.5);
    assert(full.pulls[0].stage == "downloading");
    assert(full.pulls[1].runner_id == "");
    assert(full.pulls[1].model == "unknown");
    assert(full.pulls[1].status == "unknown");
    assert(full.pulls[1].percent == 0.0);
    assert(full.pulls[2].model == "m3");
    assert(full.pulls[2].status == "queued");
    assert(full.pulls[3].runner_id == "manual-a");
    assert(full.pulls[3].status == "completed");

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
        "\"pulls\":[" +
        "{\"job_id\":\"job-1\",\"runner_id\":\"auto-local\",\"model\":\"m2\",\"status\":\"pulling\",\"progress\":{\"percent\":10.5,\"stage\":\"downloading\"}}," +
        "{\"job_id\":\"job-2\",\"runner_id\":\"auto-local\",\"model\":\"\",\"status\":\"\"}" +
        "]}}," +
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
    assert(runners[0].runtime.pulls.size == 2);
    assert(runners[0].runtime.pulls[0].percent == 10.5);
    assert(runners[0].runtime.pulls[1].model == "unknown");
    assert(runners[0].runtime.pulls[1].status == "unknown");
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

private void test_parse_ai_runner_protocol_error_paths() {
    bool got_missing_runners = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_runners(parse_json_object("{\"data\":{}}"));
    } catch (Error e) {
        got_missing_runners = e.message.contains("Missing data.runners for ai runners response");
    }
    assert(got_missing_runners);

    bool got_missing_runner_detail = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_runner_detail(parse_json_object("{\"ok\":true}"));
    } catch (Error e) {
        got_missing_runner_detail = e.message.contains("Missing data for ai runner response");
    }
    assert(got_missing_runner_detail);
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

private void test_parse_ai_messages_paths() {
    var root = parse_json_object(
        "{\"data\":[" +
        "{\"message_id\":\"m1\",\"thread_id\":\"t1\",\"role\":\"assistant\",\"source\":\"cloud\",\"provider\":\"openrouter\",\"model\":\"gpt-x\",\"content\":\"Hello\",\"created_at\":10}," +
        "{\"message_id\":\"m2\",\"thread_id\":\"t1\",\"role\":\"user\",\"source\":\"local\",\"provider\":null,\"model\":null,\"content\":\"Hi\"}" +
        "]}"
    );

    Gee.ArrayList<HolderLinux.AiMessage> messages;
    try {
        messages = HolderLinux.ApiParsersAi.parse_ai_messages(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(messages.size == 2);
    assert(messages[0].provider == "openrouter");
    assert(messages[0].model == "gpt-x");
    assert(messages[1].provider == null);
    assert(messages[1].model == null);
    assert(messages[1].created_at == 0);

    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_messages(parse_json_object("{\"ok\":true}"));
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for ai messages response");
    }
    assert(got_protocol);
}

private void test_parse_ai_runtime_providers_and_local_model_config_paths() {
    Gee.ArrayList<HolderLinux.AiRuntimeProvider> providers;
    try {
        providers = HolderLinux.ApiParsersAi.parse_ai_runtime_providers(parse_json_object(
            "{\"data\":{\"providers\":[{\"id\":\"switchyard\",\"display_name\":\"Switchyard\",\"enabled\":true,\"configured\":false,\"setup_url\":\"s\",\"docs_url\":\"d\"}]}}"
        ));
    } catch (Error e) {
        assert_not_reached();
    }
    assert(providers.size == 1);
    assert(providers[0].id == "switchyard");
    assert(providers[0].display_name == "Switchyard");

    bool got_missing_data = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_runtime_providers(parse_json_object("{\"ok\":true}"));
    } catch (Error e) {
        got_missing_data = e.message.contains("Missing data for ai runtime providers response");
    }
    assert(got_missing_data);

    bool got_missing_providers = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_runtime_providers(parse_json_object("{\"data\":{}}"));
    } catch (Error e) {
        got_missing_providers = e.message.contains("Missing data.providers for ai runtime providers response");
    }
    assert(got_missing_providers);

    HolderLinux.AiLocalModelConfigInfo config;
    try {
        config = HolderLinux.ApiParsersAi.parse_ai_local_model_config(parse_json_object(
            "{\"data\":{\"fast_model\":\"m-fast\",\"strong_model\":null,\"deep_model\":\"m-deep\",\"updated_at\":42}}"
        ));
    } catch (Error e) {
        assert_not_reached();
    }
    assert(config.fast_model == "m-fast");
    assert(config.strong_model == null);
    assert(config.deep_model == "m-deep");
    assert(config.updated_at == 42);

    bool got_missing_config_data = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_local_model_config(parse_json_object("{\"ok\":true}"));
    } catch (Error e) {
        got_missing_config_data = e.message.contains("Missing data for ai local model config response");
    }
    assert(got_missing_config_data);
}

private void test_parse_ai_provider_credentials_and_settings_paths() {
    Gee.ArrayList<HolderLinux.AiProviderCredentialState> credentials;
    try {
        credentials = HolderLinux.ApiParsersAi.parse_ai_provider_credentials(parse_json_object(
            "{\"data\":{\"providers\":[{\"provider\":\"switchyard\",\"configured\":true,\"api_key_preview\":\"sk-***\",\"updated_at\":7}]}}"
        ));
    } catch (Error e) {
        assert_not_reached();
    }
    assert(credentials.size == 1);
    assert(credentials[0].provider == "switchyard");
    assert(credentials[0].configured);

    bool got_missing_credentials_data = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_provider_credentials(parse_json_object("{\"ok\":true}"));
    } catch (Error e) {
        got_missing_credentials_data = e.message.contains("Missing data for ai provider credentials response");
    }
    assert(got_missing_credentials_data);

    bool got_missing_credentials_providers = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_provider_credentials(parse_json_object("{\"data\":{}}"));
    } catch (Error e) {
        got_missing_credentials_providers = e.message.contains("Missing data.providers for ai provider credentials response");
    }
    assert(got_missing_credentials_providers);

    Gee.ArrayList<HolderLinux.AiProviderSettingState> settings;
    try {
        settings = HolderLinux.ApiParsersAi.parse_ai_provider_settings(parse_json_object(
            "{\"data\":{\"providers\":[{\"provider\":\"openrouter\",\"enabled\":true,\"updated_at\":9}]}}"
        ));
    } catch (Error e) {
        assert_not_reached();
    }
    assert(settings.size == 1);
    assert(settings[0].provider == "openrouter");
    assert(settings[0].enabled);

    bool got_missing_settings_data = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_provider_settings(parse_json_object("{\"ok\":true}"));
    } catch (Error e) {
        got_missing_settings_data = e.message.contains("Missing data for ai provider settings response");
    }
    assert(got_missing_settings_data);

    bool got_missing_settings_providers = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_provider_settings(parse_json_object("{\"data\":{}}"));
    } catch (Error e) {
        got_missing_settings_providers = e.message.contains("Missing data.providers for ai provider settings response");
    }
    assert(got_missing_settings_providers);
}

private void test_parse_nudge_evaluation_and_nudge_list_paths() {
    HolderLinux.NudgeEvaluationResult evaluation;
    try {
        evaluation = HolderLinux.ApiParsersAi.parse_nudge_evaluation(parse_json_object(
            "{\"data\":{\"kind\":\"card.title_only\",\"accepted\":true,\"should_nudge\":true,\"reason\":\"good\",\"nudge\":{\"nudge_id\":\"n1\",\"kind\":\"card.title_only\",\"project_id\":\"p1\",\"card_id\":\"c1\",\"title\":\"T\",\"body\":\"B\",\"basis_fingerprint\":\"fp\",\"basis_commit\":\"abc\",\"created_at\":11}}}"
        ));
    } catch (Error e) {
        assert_not_reached();
    }
    assert(evaluation.kind == "card.title_only");
    assert(evaluation.accepted);
    assert(evaluation.should_nudge);
    assert(evaluation.reason == "good");
    assert(evaluation.nudge != null);
    assert(((!) evaluation.nudge).nudge_id == "n1");

    bool got_missing_eval_data = false;
    try {
        HolderLinux.ApiParsersAi.parse_nudge_evaluation(parse_json_object("{\"ok\":true}"));
    } catch (Error e) {
        got_missing_eval_data = e.message.contains("Missing data for nudge evaluation response");
    }
    assert(got_missing_eval_data);

    Gee.ArrayList<HolderLinux.AiNudge> nudges;
    try {
        nudges = HolderLinux.ApiParsersAi.parse_ai_nudge_list(parse_json_object(
            "{\"data\":{\"nudges\":[{\"nudge_id\":\"n2\",\"kind\":\"git.push_failed_repeated\",\"project_id\":\"p2\",\"card_id\":\"\",\"title\":\"Title\",\"body\":\"Body\",\"basis_fingerprint\":\"\",\"basis_commit\":\"\",\"created_at\":12}]}}"
        ));
    } catch (Error e) {
        assert_not_reached();
    }
    assert(nudges.size == 1);
    assert(nudges[0].nudge_id == "n2");
    assert(nudges[0].kind == "git.push_failed_repeated");

    bool got_missing_nudges_data = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_nudge_list(parse_json_object("{\"ok\":true}"));
    } catch (Error e) {
        got_missing_nudges_data = e.message.contains("Missing data for ai nudge list response");
    }
    assert(got_missing_nudges_data);

    bool got_missing_nudges_list = false;
    try {
        HolderLinux.ApiParsersAi.parse_ai_nudge_list(parse_json_object("{\"data\":{}}"));
    } catch (Error e) {
        got_missing_nudges_list = e.message.contains("Missing data.nudges for ai nudge list response");
    }
    assert(got_missing_nudges_list);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/parsers/ai/capabilities-full-and-defaults", test_parse_ai_capabilities_full_and_defaults);
    Test.add_func("/parsers/ai/capabilities-missing-data-protocol-error", test_parse_ai_capabilities_missing_data_is_protocol_error);
    Test.add_func("/parsers/ai/status-full-and-defaults", test_parse_ai_status_full_and_defaults);
    Test.add_func("/parsers/ai/status-missing-data-protocol-error", test_parse_ai_status_missing_data_is_protocol_error);
    Test.add_func("/parsers/ai/runners-full-and-defaults", test_parse_ai_runners_full_and_defaults);
    Test.add_func("/parsers/ai/runners-missing-data-protocol-error", test_parse_ai_runners_missing_data_is_protocol_error);
    Test.add_func("/parsers/ai/runner-protocol-error-paths", test_parse_ai_runner_protocol_error_paths);
    Test.add_func("/parsers/ai/threads-full-and-defaults", test_parse_ai_threads_full_and_defaults);
    Test.add_func("/parsers/ai/threads-missing-data-protocol-error", test_parse_ai_threads_missing_data_is_protocol_error);
    Test.add_func("/parsers/ai/provider-catalog-paths", test_parse_ai_provider_catalog_paths);
    Test.add_func("/parsers/ai/messages-paths", test_parse_ai_messages_paths);
    Test.add_func("/parsers/ai/runtime-providers-and-local-model-config-paths", test_parse_ai_runtime_providers_and_local_model_config_paths);
    Test.add_func("/parsers/ai/provider-credentials-and-settings-paths", test_parse_ai_provider_credentials_and_settings_paths);
    Test.add_func("/parsers/ai/nudge-evaluation-and-list-paths", test_parse_nudge_evaluation_and_nudge_list_paths);

    return Test.run();
}

}
