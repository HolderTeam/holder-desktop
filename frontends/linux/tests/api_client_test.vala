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
    client.create_project.begin("New Project", "encrypted_git", (obj, res) => {
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

private void test_export_and_import_project_recovery_token() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"key_id\":\"k1\",\"recovery_token\":\"{\\\"x\\\":1}\"}}"
    );
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"project_id\":\"p1\"}}");
    var client = make_client(transport);

    bool done_export = false;
    HolderLinux.ProjectRecoveryTokenExport? exported = null;
    client.export_project_recovery_token.begin("p1", "1234", (obj, res) => {
        try {
            exported = client.export_project_recovery_token.end(res);
        } catch (Error e) {
            exported = null;
        }
        done_export = true;
    });

    assert(wait_for_condition(() => done_export));
    assert(exported != null);
    assert(exported.project_id == "p1");
    assert(exported.key_id == "k1");
    assert(exported.recovery_token.contains("\"x\":1"));
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/projects/p1/recovery-token/export"));

    bool done_import = false;
    bool ok_import = false;
    client.import_project_recovery_token.begin("p1", "1234", "{\"x\":1}", (obj, res) => {
        try {
            client.import_project_recovery_token.end(res);
            ok_import = true;
        } catch (Error e) {
            ok_import = false;
        }
        done_import = true;
    });

    assert(wait_for_condition(() => done_import));
    assert(ok_import);
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/projects/p1/recovery-token/import"));
}

private void test_import_recovery_token_parses_outcome() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        201,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"project_created\":true,\"remote_hint_present\":true,\"remote_configured\":false,\"remote_error\":\"set remote failed\",\"pull_status\":\"not_attempted\",\"pull_error\":null}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.RecoveryTokenImportResult? imported = null;
    client.import_recovery_token.begin("1234", "{\"x\":1}", (obj, res) => {
        try {
            imported = client.import_recovery_token.end(res);
        } catch (Error e) {
            imported = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(imported != null);
    assert(imported.project_id == "p1");
    assert(imported.project_created);
    assert(imported.remote_hint_present);
    assert(!imported.remote_configured);
    assert(imported.remote_error == "set remote failed");
    assert(imported.pull_status == "not_attempted");
    assert(imported.pull_error == "");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/recovery-token/import"));
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
    client.list_cards.begin("p1", "root", null, (obj, res) => {
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
    assert(transport.last_uri.contains("scope=root"));
}

private void test_list_cards_with_parent_query() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":[]}");
    var client = make_client(transport);

    bool done = false;
    client.list_cards.begin("p1", "children", "parent-1", (obj, res) => {
        try {
            client.list_cards.end(res);
        } catch (Error e) {
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(transport.last_uri.contains("/cards?"));
    assert(transport.last_uri.contains("project_id=p1"));
    assert(transport.last_uri.contains("scope=children"));
    assert(transport.last_uri.contains("parent_card_id=parent-1"));
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

private void test_list_card_links_and_backlinks_parse_data() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"from_card_id\":\"c1\",\"to_card_id\":\"c2\",\"to_type\":\"card\",\"kind\":\"depends_on\",\"label\":\"critical\",\"created_at\":12}]}"
    );
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"from_card_id\":\"c3\",\"to_card_id\":\"c1\",\"to_type\":\"card\",\"kind\":\"ref\",\"created_at\":13}]}"
    );
    var client = make_client(transport);

    bool done_links = false;
    Gee.ArrayList<HolderLinux.CardLink>? links = null;
    client.list_card_links.begin("c1", (obj, res) => {
        try {
            links = client.list_card_links.end(res);
        } catch (Error e) {
            links = null;
        }
        done_links = true;
    });
    assert(wait_for_condition(() => done_links));
    assert(links != null && links.size == 1);
    assert(links[0].kind == "depends_on");
    assert(links[0].label == "critical");
    assert(transport.last_uri.has_suffix("/cards/c1/links"));

    bool done_backlinks = false;
    Gee.ArrayList<HolderLinux.CardLink>? backlinks = null;
    client.list_card_backlinks.begin("c1", (obj, res) => {
        try {
            backlinks = client.list_card_backlinks.end(res);
        } catch (Error e) {
            backlinks = null;
        }
        done_backlinks = true;
    });
    assert(wait_for_condition(() => done_backlinks));
    assert(backlinks != null && backlinks.size == 1);
    assert(backlinks[0].from_card_id == "c3");
    assert(transport.last_uri.has_suffix("/cards/c1/backlinks"));
}

private void test_create_card_link_posts_payload_and_parses_response() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        201,
        "{\"ok\":true,\"data\":{\"from_card_id\":\"c1\",\"to_card_id\":\"c2\",\"to_type\":\"card\",\"kind\":\"depends_on\",\"label\":\"critical\",\"created_at\":50}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.CardLink? created = null;
    client.create_card_link.begin("c1", "c2", "depends_on", "critical", "card", (obj, res) => {
        try {
            created = client.create_card_link.end(res);
        } catch (Error e) {
            created = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(created != null);
    assert(created.from_card_id == "c1");
    assert(created.to_card_id == "c2");
    assert(created.kind == "depends_on");
    assert(created.label == "critical");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/cards/c1/links"));
    assert(transport.last_content_type == "application/json");
}

private void test_delete_card_link_sends_delete_payload() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done = false;
    bool ok = false;
    client.delete_card_link.begin("c1", "c2", "depends_on", "card", (obj, res) => {
        try {
            client.delete_card_link.end(res);
            ok = true;
        } catch (Error e) {
            ok = false;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(ok);
    assert(transport.last_method == "DELETE");
    assert(transport.last_uri.has_suffix("/cards/c1/links"));
    assert(transport.last_content_type == "application/json");
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
        "{\"models\":{\"provider_defaults\":{\"openai\":{\"provider\":\"OpenAI\",\"enabled\":true,\"setup_url\":\"https://s\",\"docs_url\":\"https://d\"}}}}"
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
    assert(transport.last_uri.has_suffix("/ai_catalog.json"));
}

private void test_list_git_provider_catalog_parses_providers() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"providers\":[{\"id\":\"github\",\"name\":\"GitHub\",\"kind\":\"hosted\",\"defaults\":{\"preferred_transport\":\"ssh\"},\"git\":{\"transports\":[\"ssh\",\"https\"]}}]}"
    );
    var client = make_client(transport);

    bool done = false;
    Gee.ArrayList<HolderLinux.GitProviderCatalogEntry>? providers = null;
    client.list_git_provider_catalog.begin((obj, res) => {
        try {
            providers = client.list_git_provider_catalog.end(res);
        } catch (Error e) {
            providers = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(providers != null);
    assert(providers.size == 1);
    assert(providers[0].id == "github");
    assert(providers[0].preferred_transport == "ssh");
    assert(providers[0].transports_summary == "ssh, https");
    assert(transport.last_uri.has_suffix("/git_providers.json"));
}

private void test_create_and_update_card_payloads() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"card_id\":\"c42\"}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done_create = false;
    string card_id = "";
    client.create_card.begin("p1", "Title", "Body", null, (obj, res) => {
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

private void test_non_2xx_with_non_json_body_maps_to_http_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(500, "<html>oops</html>");
    var client = make_client(transport);

    bool done = false;
    bool got_http = false;
    client.list_projects.begin((obj, res) => {
        try {
            client.list_projects.end(res);
        } catch (Error e) {
            got_http = (e is HolderLinux.ApiError.HTTP);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_http);
}

private void test_non_2xx_json_without_error_object_maps_to_http_fallback() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(500, "{\"ok\":false,\"data\":{}}");
    var client = make_client(transport);

    bool done = false;
    bool got_http = false;
    bool has_fallback_message = false;
    client.list_projects.begin((obj, res) => {
        try {
            client.list_projects.end(res);
        } catch (Error e) {
            got_http = (e is HolderLinux.ApiError.HTTP);
            has_fallback_message = e.message.contains("HTTP 500 for GET /projects");
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_http);
    assert(has_fallback_message);
}

private void test_list_projects_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
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

private void test_2xx_with_non_object_json_root_maps_to_parse_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "[]");
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

private void test_missing_data_protocol_errors_for_parsers() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    transport.enqueue_read(200, "{\"ok\":true}");
    transport.enqueue_read(200, "{\"ok\":true}");
    transport.enqueue_read(200, "{\"ok\":true}");
    transport.enqueue_read(200, "{\"ok\":true}");
    transport.enqueue_read(200, "{\"ok\":true}");
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    int protocol_count = 0;
    bool done = false;
    client.list_cards.begin("p1", "root", null, (o1, r1) => {
        try { client.list_cards.end(r1); } catch (Error e) { if (e is HolderLinux.ApiError.PROTOCOL) protocol_count++; }
        client.get_card.begin("c1", (o2, r2) => {
            try { client.get_card.end(r2); } catch (Error e) { if (e is HolderLinux.ApiError.PROTOCOL) protocol_count++; }
            client.search_cards.begin("p1", "q", 30, (o3, r3) => {
                try { client.search_cards.end(r3); } catch (Error e) { if (e is HolderLinux.ApiError.PROTOCOL) protocol_count++; }
                client.get_ai_status.begin((o4, r4) => {
                    try { client.get_ai_status.end(r4); } catch (Error e) { if (e is HolderLinux.ApiError.PROTOCOL) protocol_count++; }
                    client.list_ai_threads.begin("p1", (o5, r5) => {
                        try { client.list_ai_threads.end(r5); } catch (Error e) { if (e is HolderLinux.ApiError.PROTOCOL) protocol_count++; }
                        client.list_ai_provider_catalog.begin((o6, r6) => {
                            try { client.list_ai_provider_catalog.end(r6); } catch (Error e) { if (e is HolderLinux.ApiError.PROTOCOL) protocol_count++; }
                            client.get_ai_capabilities.begin("p1", (o7, r7) => {
                                try { client.get_ai_capabilities.end(r7); } catch (Error e) { if (e is HolderLinux.ApiError.PROTOCOL) protocol_count++; }
                                done = true;
                            });
                        });
                    });
                });
            });
        });
    });

    assert(wait_for_condition(() => done));
    assert(protocol_count == 6);
}

private void test_start_runner_pull_missing_data_is_protocol_error_and_missing_job_returns_empty() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done_empty = false;
    string job = "x";
    client.start_ai_runner_pull.begin("phi4", (o1, r1) => {
        try {
            job = client.start_ai_runner_pull.end(r1);
        } catch (Error e) {
            job = "error";
        }
        done_empty = true;
    });
    assert(wait_for_condition(() => done_empty));
    assert(job == "");

    bool done_error = false;
    bool got_protocol = false;
    client.start_ai_runner_pull.begin("phi4", (o2, r2) => {
        try {
            client.start_ai_runner_pull.end(r2);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done_error = true;
    });
    assert(wait_for_condition(() => done_error));
    assert(got_protocol);
}

private void test_create_ai_thread_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.create_ai_thread.begin("p1", "T", (obj, res) => {
        try {
            client.create_ai_thread.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

private void test_ai_capabilities_optional_fields_and_no_project_query() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"runner_available\":false,\"error\":\"runner missing\",\"models\":[{}],\"recommended_install\":[{}],\"caste\":null}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.AiCapabilitiesInfo? info = null;
    client.get_ai_capabilities.begin(null, (obj, res) => {
        try {
            info = client.get_ai_capabilities.end(res);
        } catch (Error e) {
            info = null;
        }
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(info != null);
    assert(!info.runner_available);
    assert(info.runner_error == "runner missing");
    assert(info.caste_name == "");
    assert(info.models.size == 0);
    assert(info.recommended_install.size == 0);
    assert(!transport.last_uri.contains("project_id="));
}

private void test_ai_capabilities_missing_caste_and_null_string_fields() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"runner_available\":true,\"error\":null,\"version\":null,\"models\":[],\"recommended_install\":[]}}"
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
    assert(info.caste_name == "");
    assert(info.runner_error == "");
    assert(info.runner_version == "");
}

private void test_ai_status_missing_pull_fields_uses_defaults() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"pulls\":[{}]}}"
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
    assert(status.pull_jobs.size == 1);
    assert(status.pull_jobs[0].contains("unknown"));
    assert(status.pull_jobs[0].contains("0.0%"));
}

private void test_provider_catalog_missing_providers_returns_empty() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"models\":{}}");
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
    assert(providers.size == 0);
}

private void test_run_ai_stream_eof_without_blank_line_and_with_context_fields() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream(200, "event: chunk\ndata: {\"delta\":\"tail\"}");
    var client = make_client(transport);

    bool done = false;
    bool saw_chunk = false;
    client.run_ai_stream.begin(
        "Prompt",
        "p1",
        "t1",
        "c1",
        "Card title",
        "Body text",
        (event_name, data) => {
            if (event_name == "chunk" && data.has_member("delta")) {
                saw_chunk = true;
            }
        },
        (obj, res) => {
            try { client.run_ai_stream.end(res); } catch (Error e) {}
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(saw_chunk);
    assert(transport.last_content_type == "application/json");
}

private void test_run_ai_stream_multiline_data_joins_with_newline() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream(
        200,
        "event: message\n" +
        "data: first line\n" +
        "data: second line\n\n"
    );
    var client = make_client(transport);

    bool done = false;
    bool saw_joined_raw = false;
    client.run_ai_stream.begin(
        "Prompt",
        null,
        null,
        null,
        null,
        null,
        (event_name, data) => {
            if (data.has_member("raw") && data.get_string_member("raw") == "first line\nsecond line") {
                saw_joined_raw = true;
            }
        },
        (obj, res) => {
            try { client.run_ai_stream.end(res); } catch (Error e) {}
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(saw_joined_raw);
}

private void test_response_wrapper_objects_construct() {
    var bytes = new Bytes((uint8[]) "ok".data);
    var bytes_resp = new HolderLinux.ApiHttpBytesResponse(201, bytes);
    assert(bytes_resp.status == 201);
    assert(((string) bytes_resp.body.get_data()).has_prefix("ok"));

    var stream = new MemoryInputStream.from_bytes(new Bytes((uint8[]) "x".data));
    var stream_resp = new HolderLinux.ApiHttpStreamResponse(202, stream);
    assert(stream_resp.status == 202);
    assert(stream_resp.stream != null);

    var transport = new HolderLinux.SoupApiHttpTransport();
    assert(transport != null);
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
    Test.add_func("/api_client/get_health_info_parses_data", test_get_health_info_parses_data);
    Test.add_func("/api_client/list_projects_parses_data", test_list_projects_parses_data);
    Test.add_func("/api_client/create_project_sends_json_and_returns_id",
                  test_create_project_sends_json_and_returns_id);
    Test.add_func("/api_client/export_and_import_project_recovery_token",
                  test_export_and_import_project_recovery_token);
    Test.add_func("/api_client/import_recovery_token_parses_outcome",
                  test_import_recovery_token_parses_outcome);
    Test.add_func("/api_client/list_cards_parses_data_and_query", test_list_cards_parses_data_and_query);
    Test.add_func("/api_client/list_cards_with_parent_query", test_list_cards_with_parent_query);
    Test.add_func("/api_client/get_card_parses_detail", test_get_card_parses_detail);
    Test.add_func("/api_client/list_card_links_and_backlinks_parse_data",
                  test_list_card_links_and_backlinks_parse_data);
    Test.add_func("/api_client/create_card_link_posts_payload_and_parses_response",
                  test_create_card_link_posts_payload_and_parses_response);
    Test.add_func("/api_client/delete_card_link_sends_delete_payload",
                  test_delete_card_link_sends_delete_payload);
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
    Test.add_func("/api_client/list_git_provider_catalog_parses_providers",
                  test_list_git_provider_catalog_parses_providers);
    Test.add_func("/api_client/create_and_update_card_payloads", test_create_and_update_card_payloads);
    Test.add_func("/api_client/health_check_missing_data_is_protocol_error",
                  test_health_check_missing_data_is_protocol_error);
    Test.add_func("/api_client/non_2xx_with_non_json_body_maps_to_http_error",
                  test_non_2xx_with_non_json_body_maps_to_http_error);
    Test.add_func("/api_client/non_2xx_json_without_error_object_maps_to_http_fallback",
                  test_non_2xx_json_without_error_object_maps_to_http_fallback);
    Test.add_func("/api_client/list_projects_missing_data_is_protocol_error",
                  test_list_projects_missing_data_is_protocol_error);
    Test.add_func("/api_client/2xx_with_non_object_json_root_maps_to_parse_error",
                  test_2xx_with_non_object_json_root_maps_to_parse_error);
    Test.add_func("/api_client/missing_data_protocol_errors_for_parsers",
                  test_missing_data_protocol_errors_for_parsers);
    Test.add_func("/api_client/start_runner_pull_missing_data_is_protocol_error_and_missing_job_returns_empty",
                  test_start_runner_pull_missing_data_is_protocol_error_and_missing_job_returns_empty);
    Test.add_func("/api_client/create_ai_thread_missing_data_is_protocol_error",
                  test_create_ai_thread_missing_data_is_protocol_error);
    Test.add_func("/api_client/ai_capabilities_optional_fields_and_no_project_query",
                  test_ai_capabilities_optional_fields_and_no_project_query);
    Test.add_func("/api_client/ai_capabilities_missing_caste_and_null_string_fields",
                  test_ai_capabilities_missing_caste_and_null_string_fields);
    Test.add_func("/api_client/ai_status_missing_pull_fields_uses_defaults",
                  test_ai_status_missing_pull_fields_uses_defaults);
    Test.add_func("/api_client/provider_catalog_missing_providers_returns_empty",
                  test_provider_catalog_missing_providers_returns_empty);
    Test.add_func("/api_client/run_ai_stream_eof_without_blank_line_and_with_context_fields",
                  test_run_ai_stream_eof_without_blank_line_and_with_context_fields);
    Test.add_func("/api_client/run_ai_stream_multiline_data_joins_with_newline",
                  test_run_ai_stream_multiline_data_joins_with_newline);
    Test.add_func("/api_client/response_wrapper_objects_construct",
                  test_response_wrapper_objects_construct);
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
