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
    assert(transport.last_accept == "application/json");
    assert(transport.last_auth == "Bearer token-123");
}

private void test_list_projects_parses_data() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"project_id\":\"p1\",\"name\":\"My Project\",\"root_path\":\"/tmp/p1\",\"created_at\":1,\"updated_at\":2}]}"
    );
    var client = make_client(transport);

    bool done = false;
    Gee.ArrayList<HolderLinux.Project>? projects = null;
    client.list_projects.begin((obj, res) => {
        try {
            projects = client.list_projects.end(res);
        } catch (Error e) {
            projects = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(projects != null);
    assert(projects.size == 1);
    assert(projects[0].project_id == "p1");
    assert(projects[0].name == "My Project");
}

private void test_create_project_sends_json_and_returns_id() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"project_id\":\"p-created\"}}");
    var client = make_client(transport);

    bool done = false;
    string created_id = "";
    client.create_project.begin("New Project", (obj, res) => {
        try {
            created_id = client.create_project.end(res);
        } catch (Error e) {
            created_id = "";
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(created_id == "p-created");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/projects"));
    assert(transport.last_content_type == "application/json");
}

private void test_list_cards_parses_data_and_query() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"card_id\":\"c1\",\"project_id\":\"p1\",\"title\":\"T1\",\"rel_path\":\"cards/t1.md\",\"created_at\":1,\"updated_at\":2}]}"
    );
    var client = make_client(transport);

    bool done = false;
    Gee.ArrayList<HolderLinux.CardSummary>? cards = null;
    string error_message = "";
    client.list_cards.begin("p1", (obj, res) => {
        try {
            cards = client.list_cards.end(res);
        } catch (Error e) {
            cards = null;
            error_message = e.message;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(error_message == "");
    assert(cards != null);
    assert(cards.size == 1);
    assert(cards[0].card_id == "c1");
    assert(cards[0].rel_path == "cards/t1.md");
    assert(transport.last_uri.contains("/cards?"));
    assert(transport.last_uri.contains("project_id=p1"));
}

private void test_get_card_parses_detail() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"card_id\":\"c1\",\"project_id\":\"p1\",\"title\":\"My card\",\"content\":\"Body\",\"updated_at\":123}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.CardDetail? card = null;
    string error_message = "";
    client.get_card.begin("c1", (obj, res) => {
        try {
            card = client.get_card.end(res);
        } catch (Error e) {
            card = null;
            error_message = e.message;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    if (error_message != "") {
        stderr.printf("get_card error: %s\n", error_message);
    }
    assert(error_message == "");
    assert(card != null);
    assert(card.card_id == "c1");
    assert(card.title == "My card");
    assert(card.content == "Body");
}

private void test_search_cards_parses_results() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"card_id\":\"c1\",\"title\":\"T\",\"updated_at\":2,\"created_at\":1,\"snippet\":\"snip\",\"rank\":0.9}]}"
    );
    var client = make_client(transport);

    bool done = false;
    Gee.ArrayList<HolderLinux.SearchCardResult>? results = null;
    client.search_cards.begin("p1", "hello", 10, (obj, res) => {
        try {
            results = client.search_cards.end(res);
        } catch (Error e) {
            results = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(results != null);
    assert(results.size == 1);
    assert(results[0].snippet == "snip");
    assert(transport.last_uri.contains("/search/cards?"));
    assert(transport.last_uri.contains("q=hello"));
    assert(transport.last_uri.contains("limit=10"));
}

private void test_get_ai_capabilities_parses_nested_data() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"runner_available\":true,\"error\":\"\",\"last_checked\":5,\"version\":\"1.2\",\"caste\":{\"name\":\"user\"},\"models\":[{\"name\":\"m1\"},{\"name\":\"m2\"}],\"recommended_install\":[{\"tag\":\"r1\"}]}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.AiCapabilitiesInfo? info = null;
    client.get_ai_capabilities.begin("p1", (obj, res) => {
        try {
            info = client.get_ai_capabilities.end(res);
        } catch (Error e) {
            info = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(info != null);
    assert(info.runner_available);
    assert(info.runner_version == "1.2");
    assert(info.caste_name == "user");
    assert(info.models.size == 2);
    assert(info.recommended_install.size == 1);
    assert(transport.last_uri.contains("project_id=p1"));
}

private void test_get_ai_status_parses_pull_jobs() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"checked_at\":10,\"runner_available\":true,\"runner_error\":\"\",\"active_runs\":2,\"active_pull_jobs\":1,\"cloud_configured_providers\":3,\"pulls\":[{\"model\":\"phi4\",\"status\":\"running\",\"progress\":{\"percent\":55.5}}]}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.AiStatusInfo? status = null;
    client.get_ai_status.begin((obj, res) => {
        try {
            status = client.get_ai_status.end(res);
        } catch (Error e) {
            status = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(status != null);
    assert(status.active_runs == 2);
    assert(status.active_pull_jobs == 1);
    assert(status.pull_jobs.size == 1);
    assert(status.pull_jobs[0].contains("55.5%"));
}

private void test_start_ai_runner_pull_parses_job_id_and_payload() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"job_id\":\"job-9\"}}");
    var client = make_client(transport);

    bool done = false;
    string job_id = "";
    client.start_ai_runner_pull.begin("phi4", (obj, res) => {
        try {
            job_id = client.start_ai_runner_pull.end(res);
        } catch (Error e) {
            job_id = "";
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(job_id == "job-9");
    assert(transport.last_uri.has_suffix("/ai/runner/pull"));
    assert(transport.last_content_type == "application/json");
}

private void test_list_ai_threads_and_create_ai_thread() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"thread_id\":\"t1\",\"project_id\":\"p1\",\"title\":\"Thread\",\"created_at\":1,\"updated_at\":2}]}"
    );
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"thread_id\":\"t2\"}}");
    var client = make_client(transport);

    bool done_list = false;
    Gee.ArrayList<HolderLinux.AiThreadSummary>? threads = null;
    client.list_ai_threads.begin("p1", (obj, res) => {
        try {
            threads = client.list_ai_threads.end(res);
        } catch (Error e) {
            threads = null;
        }
        done_list = true;
    });
    assert(wait_for_condition(() => done_list));
    assert(threads != null && threads.size == 1);
    assert(threads[0].thread_id == "t1");

    bool done_create = false;
    string created_thread = "";
    client.create_ai_thread.begin("p1", "Thread", (obj, res) => {
        try {
            created_thread = client.create_ai_thread.end(res);
        } catch (Error e) {
            created_thread = "";
        }
        done_create = true;
    });
    assert(wait_for_condition(() => done_create));
    assert(created_thread == "t2");
    assert(transport.last_uri.has_suffix("/ai/threads"));
}

private void test_list_ai_provider_catalog_parses_providers() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"providers\":[{\"id\":\"openai\",\"display_name\":\"OpenAI\",\"enabled\":true,\"configured\":false,\"setup_url\":\"https://s\",\"docs_url\":\"https://d\"}]}}"
    );
    var client = make_client(transport);

    bool done = false;
    Gee.ArrayList<HolderLinux.AiCatalogProvider>? providers = null;
    client.list_ai_provider_catalog.begin((obj, res) => {
        try {
            providers = client.list_ai_provider_catalog.end(res);
        } catch (Error e) {
            providers = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(providers != null);
    assert(providers.size == 1);
    assert(providers[0].id == "openai");
    assert(providers[0].enabled);
}

private void test_create_and_update_card_payloads() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"card_id\":\"c42\"}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done_create = false;
    string card_id = "";
    client.create_card.begin("p1", "Title", "Body", (obj, res) => {
        try {
            card_id = client.create_card.end(res);
        } catch (Error e) {
            card_id = "";
        }
        done_create = true;
    });
    assert(wait_for_condition(() => done_create));
    assert(card_id == "c42");
    assert(transport.last_uri.has_suffix("/cards"));
    assert(transport.last_content_type == "application/json");

    bool done_update = false;
    bool update_ok = false;
    client.update_card.begin("c42", "New title", "New body", 99, (obj, res) => {
        try {
            client.update_card.end(res);
            update_ok = true;
        } catch (Error e) {
            update_ok = false;
        }
        done_update = true;
    });
    assert(wait_for_condition(() => done_update));
    assert(update_ok);
    assert(transport.last_method == "PATCH");
    assert(transport.last_uri.has_suffix("/cards/c42"));
    assert(transport.last_content_type == "application/json");
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

private void test_request_json_transport_error_maps_to_api_transport() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read_throw("network down");
    var client = make_client(transport);

    bool done = false;
    bool got_transport = false;
    client.list_projects.begin((obj, res) => {
        try {
            client.list_projects.end(res);
        } catch (Error e) {
            got_transport = (e is HolderLinux.ApiError.TRANSPORT);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_transport);
}

private void test_request_json_http_error_parses_error_object() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(404, "{\"ok\":false,\"error\":{\"code\":\"not_found\",\"message\":\"Missing\"}}");
    var client = make_client(transport);

    bool done = false;
    bool got_http = false;
    bool message_has_code = false;
    client.list_projects.begin((obj, res) => {
        try {
            client.list_projects.end(res);
        } catch (Error e) {
            got_http = (e is HolderLinux.ApiError.HTTP);
            message_has_code = e.message.contains("not_found");
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_http);
    assert(message_has_code);
}

private void test_request_json_parse_error_on_success_response() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "this-is-not-json");
    var client = make_client(transport);

    bool done = false;
    bool got_parse = false;
    client.list_projects.begin((obj, res) => {
        try {
            client.list_projects.end(res);
        } catch (Error e) {
            got_parse = (e is HolderLinux.ApiError.PARSE);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_parse);
}

private void test_request_json_protocol_error_when_ok_missing() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"data\":[]}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.list_projects.begin((obj, res) => {
        try {
            client.list_projects.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

private void test_run_ai_stream_parses_sse_and_raw_data() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream(
        200,
        "event: progress\n" +
        "data: {\"message\":\"working\"}\n\n" +
        "event: chunk\n" +
        "data: {\"delta\":\"hi\"}\n\n" +
        "data: plain text payload\n\n" +
        "event: done\n" +
        "data: {\"model\":\"phi4\"}\n\n"
    );
    var client = make_client(transport);

    var event_names = new Gee.ArrayList<string>();
    bool saw_raw = false;
    bool done = false;
    bool ok = false;
    client.run_ai_stream.begin(
        "Prompt",
        "p1",
        "t1",
        null,
        null,
        null,
        (event_name, data) => {
            event_names.add(event_name);
            if (data.has_member("raw") && data.get_string_member("raw").contains("plain text payload")) {
                saw_raw = true;
            }
        },
        (obj, res) => {
            try {
                client.run_ai_stream.end(res);
                ok = true;
            } catch (Error e) {
                ok = false;
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(ok);
    assert(event_names.size == 4);
    assert(event_names[0] == "progress");
    assert(event_names[1] == "chunk");
    assert(event_names[2] == "message");
    assert(event_names[3] == "done");
    assert(saw_raw);
    assert(transport.last_accept == "text/event-stream");
}

private void test_run_ai_stream_http_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream(500, "");
    var client = make_client(transport);

    bool done = false;
    bool got_http = false;
    client.run_ai_stream.begin(
        "Prompt",
        "p1",
        "t1",
        null,
        null,
        null,
        (event_name, data) => {},
        (obj, res) => {
            try {
                client.run_ai_stream.end(res);
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
    transport.enqueue_stream_throw("socket closed");
    var client = make_client(transport);

    bool done = false;
    bool got_transport = false;
    client.run_ai_stream.begin(
        "Prompt",
        "p1",
        "t1",
        null,
        null,
        null,
        (event_name, data) => {},
        (obj, res) => {
            try {
                client.run_ai_stream.end(res);
            } catch (Error e) {
                got_transport = (e is HolderLinux.ApiError.TRANSPORT);
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(got_transport);
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/api_client/health_check_success", test_health_check_success);
    Test.add_func("/api_client/list_projects_parses_data", test_list_projects_parses_data);
    Test.add_func("/api_client/create_project_sends_json_and_returns_id",
                  test_create_project_sends_json_and_returns_id);
    Test.add_func("/api_client/list_cards_parses_data_and_query", test_list_cards_parses_data_and_query);
    Test.add_func("/api_client/get_card_parses_detail", test_get_card_parses_detail);
    Test.add_func("/api_client/search_cards_parses_results", test_search_cards_parses_results);
    Test.add_func("/api_client/get_ai_capabilities_parses_nested_data",
                  test_get_ai_capabilities_parses_nested_data);
    Test.add_func("/api_client/get_ai_status_parses_pull_jobs", test_get_ai_status_parses_pull_jobs);
    Test.add_func("/api_client/start_ai_runner_pull_parses_job_id_and_payload",
                  test_start_ai_runner_pull_parses_job_id_and_payload);
    Test.add_func("/api_client/list_ai_threads_and_create_ai_thread",
                  test_list_ai_threads_and_create_ai_thread);
    Test.add_func("/api_client/list_ai_provider_catalog_parses_providers",
                  test_list_ai_provider_catalog_parses_providers);
    Test.add_func("/api_client/create_and_update_card_payloads", test_create_and_update_card_payloads);
    Test.add_func("/api_client/health_check_missing_data_is_protocol_error",
                  test_health_check_missing_data_is_protocol_error);
    Test.add_func("/api_client/request_json_transport_error_maps_to_api_transport",
                  test_request_json_transport_error_maps_to_api_transport);
    Test.add_func("/api_client/request_json_http_error_parses_error_object",
                  test_request_json_http_error_parses_error_object);
    Test.add_func("/api_client/request_json_parse_error_on_success_response",
                  test_request_json_parse_error_on_success_response);
    Test.add_func("/api_client/request_json_protocol_error_when_ok_missing",
                  test_request_json_protocol_error_when_ok_missing);
    Test.add_func("/api_client/run_ai_stream_parses_sse_and_raw_data",
                  test_run_ai_stream_parses_sse_and_raw_data);
    Test.add_func("/api_client/run_ai_stream_http_error", test_run_ai_stream_http_error);
    Test.add_func("/api_client/run_ai_stream_transport_error", test_run_ai_stream_transport_error);

    return Test.run();
}

}
