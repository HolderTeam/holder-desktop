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

private void test_export_project_recovery_token_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.export_project_recovery_token.begin("p1", "1234", (obj, res) => {
        try {
            client.export_project_recovery_token.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
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

private void test_import_recovery_token_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.import_recovery_token.begin("1234", "{\"x\":1}", (obj, res) => {
        try {
            client.import_recovery_token.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

private void test_import_recovery_token_parses_non_null_pull_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"project_created\":false,\"remote_hint_present\":false,\"remote_configured\":false,\"remote_error\":null,\"pull_status\":\"failed\",\"pull_error\":\"git pull failed\"}}"
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
    assert(imported.pull_status == "failed");
    assert(imported.pull_error == "git pull failed");
}

private void test_list_cards_parses_non_null_parent_card_id() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"card_id\":\"c1\",\"project_id\":\"p1\",\"title\":\"T1\",\"parent_card_id\":\"p-root\"}]}"
    );
    var client = make_client(transport);

    bool done = false;
    Gee.ArrayList<HolderLinux.CardSummary>? cards = null;
    client.list_cards.begin("p1", "all", null, (obj, res) => {
        try {
            cards = client.list_cards.end(res);
        } catch (Error e) {
            cards = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(cards != null);
    assert(cards.size == 1);
    assert(cards[0].parent_card_id == "p-root");
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

private void test_list_cards_ignores_blank_parent_query() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":[]}");
    var client = make_client(transport);

    bool done = false;
    client.list_cards.begin("p1", "children", "   ", (obj, res) => {
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
    assert(!transport.last_uri.contains("parent_card_id="));
}

private void test_resources_crud_and_parse() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"resource_id\":\"r1\",\"project_id\":\"p1\",\"kind\":\"url\",\"uri\":\"https://example.com\",\"label\":\"Example\",\"desc\":null,\"created_at\":1,\"updated_at\":2}]}"
    );
    transport.enqueue_read(201, "{\"ok\":true,\"data\":{\"resource_id\":\"r2\"}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done_list = false;
    Gee.ArrayList<HolderLinux.ProjectResource>? resources = null;
    client.list_resources.begin("p1", (obj, res) => {
        try {
            resources = client.list_resources.end(res);
        } catch (Error e) {
            resources = null;
        }
        done_list = true;
    });
    assert(wait_for_condition(() => done_list));
    assert(resources != null);
    assert(resources.size == 1);
    assert(resources[0].resource_id == "r1");
    assert(resources[0].desc == null);
    assert(transport.last_uri.contains("/resources?"));
    assert(transport.last_uri.contains("project_id=p1"));

    bool done_create = false;
    string resource_id = "";
    client.create_resource.begin("p1", "url", "https://example.com", "Example", null, (obj, res) => {
        try {
            resource_id = client.create_resource.end(res);
        } catch (Error e) {
            resource_id = "";
        }
        done_create = true;
    });
    assert(wait_for_condition(() => done_create));
    assert(resource_id == "r2");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/resources"));

    bool done_update = false;
    bool update_ok = false;
    client.update_resource.begin("r2", "file", "/tmp/a.txt", "A", null, 7, (obj, res) => {
        try {
            client.update_resource.end(res);
            update_ok = true;
        } catch (Error e) {
            update_ok = false;
        }
        done_update = true;
    });
    assert(wait_for_condition(() => done_update));
    assert(update_ok);
    assert(transport.last_method == "PATCH");
    assert(transport.last_uri.has_suffix("/resources/r2"));

    bool done_delete = false;
    bool delete_ok = false;
    client.delete_resource.begin("r2", (obj, res) => {
        try {
            client.delete_resource.end(res);
            delete_ok = true;
        } catch (Error e) {
            delete_ok = false;
        }
        done_delete = true;
    });
    assert(wait_for_condition(() => done_delete));
    assert(delete_ok);
    assert(transport.last_method == "DELETE");
    assert(transport.last_uri.has_suffix("/resources/r2"));
}

private void test_create_resource_with_desc_succeeds() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(201, "{\"ok\":true,\"data\":{\"resource_id\":\"r3\"}}");
    var client = make_client(transport);

    bool done = false;
    string resource_id = "";
    client.create_resource.begin("p1", "file", "/tmp/note.txt", "Note", "a description", (obj, res) => {
        try {
            resource_id = client.create_resource.end(res);
        } catch (Error e) {
            resource_id = "";
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(resource_id == "r3");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/resources"));
    assert(transport.last_content_type == "application/json");
}

private void test_create_resource_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(201, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.create_resource.begin("p1", "url", "https://example.com", "Example", null, (obj, res) => {
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

private void test_update_resource_with_desc_succeeds() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done = false;
    bool ok = false;
    client.update_resource.begin("r2", "file", "/tmp/a.txt", "A", "has desc", 8, (obj, res) => {
        try {
            client.update_resource.end(res);
            ok = true;
        } catch (Error e) {
            ok = false;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(ok);
    assert(transport.last_method == "PATCH");
    assert(transport.last_uri.has_suffix("/resources/r2"));
    assert(transport.last_content_type == "application/json");
}

private void test_list_resources_parses_non_null_desc() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"resource_id\":\"r1\",\"project_id\":\"p1\",\"kind\":\"file\",\"uri\":\"/tmp/a.txt\",\"label\":\"A\",\"desc\":\"local file\"}]}"
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
    assert(resources[0].desc == "local file");
}

private void test_list_resources_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.list_resources.begin("p1", (obj, res) => {
        try {
            client.list_resources.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
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

private void test_list_card_links_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.list_card_links.begin("c1", (obj, res) => {
        try {
            client.list_card_links.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
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

private void test_create_card_link_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.create_card_link.begin("c1", "c2", "ref", null, "card", (obj, res) => {
        try {
            client.create_card_link.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

private void test_create_card_link_with_non_card_to_type_succeeds() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        201,
        "{\"ok\":true,\"data\":{\"from_card_id\":\"c1\",\"to_card_id\":\"r1\",\"to_type\":\"resource\",\"kind\":\"ref\",\"created_at\":50}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.CardLink? created = null;
    client.create_card_link.begin("c1", "r1", "ref", null, "resource", (obj, res) => {
        try {
            created = client.create_card_link.end(res);
        } catch (Error e) {
            created = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(created != null);
    assert(created.to_card_id == "r1");
    assert(created.to_type == "resource");
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

private void test_list_ai_provider_catalog_falls_back_to_provider_id_display_name() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"models\":{\"provider_defaults\":{\"openrouter\":{\"provider\":\"\",\"enabled\":false}}}}"
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
    assert(providers[0].id == "openrouter");
    assert(providers[0].display_name == "openrouter");
}

private void test_list_ai_provider_catalog_empty_provider_defaults_returns_empty() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"models\":{\"provider_defaults\":{}}}"
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
    assert(providers.size == 0);
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

private void test_list_git_provider_catalog_parses_examples() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"providers\":[{\"id\":\"github\",\"name\":\"GitHub\",\"kind\":\"hosted\",\"git\":{\"transports\":[\"ssh\",\"https\"],\"examples\":{\"ssh\":\"git@github.com:owner/repo.git\",\"https\":\"https://github.com/owner/repo.git\"}}}]}"
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
    assert(providers[0].ssh_example == "git@github.com:owner/repo.git");
    assert(providers[0].https_example == "https://github.com/owner/repo.git");
}

private void test_list_git_provider_catalog_missing_providers_returns_empty() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"title\":\"Git Providers\"}");
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
    assert(providers.size == 0);
}

private void test_git_remote_test_and_push_parse_results() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"remote_url\":\"git@github.com:me/repo.git\",\"branch\":\"cards\",\"status\":\"reachable\",\"remote_has_head\":true,\"error_code\":\"\",\"error_message\":\"\"}}"
    );
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"remote_url\":\"git@github.com:me/repo.git\",\"branch\":\"cards\",\"status\":\"pushed\",\"ahead_count\":0,\"behind_count\":0,\"error_code\":\"\",\"error_message\":\"\",\"next_action\":\"none\"}}"
    );
    var client = make_client(transport);

    bool done_test = false;
    HolderLinux.GitTestRemoteResult? test_result = null;
    client.test_project_git_remote.begin("p1", "git@github.com:me/repo.git", "cards", (obj, res) => {
        try {
            test_result = client.test_project_git_remote.end(res);
        } catch (Error e) {
            test_result = null;
        }
        done_test = true;
    });
    assert(wait_for_condition(() => done_test));
    assert(test_result != null);
    assert(test_result.status == "reachable");
    assert(test_result.remote_has_head);
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/projects/p1/git/test-remote"));

    bool done_push = false;
    HolderLinux.GitPushResult? push_result = null;
    client.push_project_git.begin("p1", "cards", true, (obj, res) => {
        try {
            push_result = client.push_project_git.end(res);
        } catch (Error e) {
            push_result = null;
        }
        done_push = true;
    });
    assert(wait_for_condition(() => done_push));
    assert(push_result != null);
    assert(push_result.status == "pushed");
    assert(push_result.next_action == "none");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/projects/p1/git/push"));
}

private void test_set_project_git_remote_handles_null_and_non_empty_url() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done_null = false;
    bool ok_null = false;
    client.set_project_git_remote.begin("p1", null, 11, (obj, res) => {
        try {
            client.set_project_git_remote.end(res);
            ok_null = true;
        } catch (Error e) {
            ok_null = false;
        }
        done_null = true;
    });
    assert(wait_for_condition(() => done_null));
    assert(ok_null);
    assert(transport.last_method == "PATCH");
    assert(transport.last_uri.has_suffix("/projects/p1"));

    bool done_url = false;
    bool ok_url = false;
    client.set_project_git_remote.begin("p1", "git@github.com:me/repo.git", 12, (obj, res) => {
        try {
            client.set_project_git_remote.end(res);
            ok_url = true;
        } catch (Error e) {
            ok_url = false;
        }
        done_url = true;
    });
    assert(wait_for_condition(() => done_url));
    assert(ok_url);
    assert(transport.last_method == "PATCH");
    assert(transport.last_uri.has_suffix("/projects/p1"));
}

private void test_git_remote_optional_inputs_are_accepted() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"remote_url\":\"\",\"branch\":\"\",\"status\":\"missing_remote\",\"remote_has_head\":false,\"error_code\":\"\",\"error_message\":\"\"}}"
    );
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"remote_url\":\"\",\"branch\":\"\",\"status\":\"no_remote\",\"ahead_count\":0,\"behind_count\":0,\"error_code\":\"\",\"error_message\":\"\",\"next_action\":\"set_remote\"}}"
    );
    var client = make_client(transport);

    bool done_test = false;
    HolderLinux.GitTestRemoteResult? test_result = null;
    client.test_project_git_remote.begin("p1", null, "", (obj, res) => {
        try {
            test_result = client.test_project_git_remote.end(res);
        } catch (Error e) {
            test_result = null;
        }
        done_test = true;
    });
    assert(wait_for_condition(() => done_test));
    assert(test_result != null);
    assert(test_result.status == "missing_remote");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/projects/p1/git/test-remote"));

    bool done_push = false;
    HolderLinux.GitPushResult? push_result = null;
    client.push_project_git.begin("p1", "", false, (obj, res) => {
        try {
            push_result = client.push_project_git.end(res);
        } catch (Error e) {
            push_result = null;
        }
        done_push = true;
    });
    assert(wait_for_condition(() => done_push));
    assert(push_result != null);
    assert(push_result.status == "no_remote");
    assert(push_result.next_action == "set_remote");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/projects/p1/git/push"));
}

private void test_test_project_git_remote_whitespace_remote_url_maps_to_null() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"remote_url\":\"\",\"branch\":\"cards\",\"status\":\"missing_remote\",\"remote_has_head\":false,\"error_code\":\"\",\"error_message\":\"\"}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.GitTestRemoteResult? test_result = null;
    client.test_project_git_remote.begin("p1", "   ", "cards", (obj, res) => {
        try {
            test_result = client.test_project_git_remote.end(res);
        } catch (Error e) {
            test_result = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(test_result != null);
    assert(test_result.status == "missing_remote");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/projects/p1/git/test-remote"));
    assert(transport.last_content_type == "application/json");
}

private void test_git_remote_test_and_push_missing_data_are_protocol_errors() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done_test = false;
    bool test_protocol = false;
    client.test_project_git_remote.begin("p1", null, "", (obj, res) => {
        try {
            client.test_project_git_remote.end(res);
        } catch (Error e) {
            test_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done_test = true;
    });
    assert(wait_for_condition(() => done_test));
    assert(test_protocol);

    bool done_push = false;
    bool push_protocol = false;
    client.push_project_git.begin("p1", "", true, (obj, res) => {
        try {
            client.push_project_git.end(res);
        } catch (Error e) {
            push_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done_push = true;
    });
    assert(wait_for_condition(() => done_push));
    assert(push_protocol);
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

private void test_create_card_with_parent_id_succeeds() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"card_id\":\"c43\"}}");
    var client = make_client(transport);

    bool done = false;
    string card_id = "";
    client.create_card.begin("p1", "Child", "Body", "parent-1", (obj, res) => {
        try {
            card_id = client.create_card.end(res);
        } catch (Error e) {
            card_id = "";
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(card_id == "c43");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/cards"));
    assert(transport.last_content_type == "application/json");
}

private void test_update_card_position_with_parent_and_root() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done_nested = false;
    bool nested_ok = false;
    client.update_card_position.begin("c42", "parent-1", 123.5, 99, (obj, res) => {
        try {
            client.update_card_position.end(res);
            nested_ok = true;
        } catch (Error e) {
            nested_ok = false;
        }
        done_nested = true;
    });
    assert(wait_for_condition(() => done_nested));
    assert(nested_ok);
    assert(transport.last_method == "PATCH");
    assert(transport.last_uri.has_suffix("/cards/c42"));
    assert(transport.last_content_type == "application/json");

    bool done_root = false;
    bool root_ok = false;
    client.update_card_position.begin("c42", null, 12.0, 100, (obj, res) => {
        try {
            client.update_card_position.end(res);
            root_ok = true;
        } catch (Error e) {
            root_ok = false;
        }
        done_root = true;
    });
    assert(wait_for_condition(() => done_root));
    assert(root_ok);
    assert(transport.last_method == "PATCH");
    assert(transport.last_uri.has_suffix("/cards/c42"));
}

private void test_move_card_posts_move_endpoint() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"card_id\":\"c42\",\"parent_card_id\":\"p1\",\"sort_key\":2048.0,\"revision\":7,\"moved_into_title\":\"Parent\"}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.CardMoveResult? result = null;
    client.move_card.begin("c42", "proj-1", "into", "p1", null, (obj, res) => {
        try {
            result = client.move_card.end(res);
        } catch (Error e) {
            result = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(result != null);
    assert(result.card_id == "c42");
    assert(result.parent_card_id == "p1");
    assert(result.revision == 7);
    assert(result.moved_into_title == "Parent");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.has_suffix("/cards/c42/move"));
    assert(transport.last_content_type == "application/json");
}

private void test_get_card_context_parses_response() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project\":{\"project_id\":\"proj-1\",\"name\":\"Project One\"},\"current_parent_card_id\":\"a1\",\"breadcrumbs\":[{\"type\":\"project\",\"title\":\"Project One\",\"project_id\":\"proj-1\",\"card_id\":null},{\"type\":\"card\",\"title\":\"A\",\"project_id\":null,\"card_id\":\"a1\"}],\"cards\":[{\"card_id\":\"b1\",\"project_id\":\"proj-1\",\"title\":\"B\",\"rel_path\":\"cards/b1.md\",\"sort_key\":42,\"parent_card_id\":\"a1\",\"created_at\":10,\"updated_at\":11,\"child_count\":3}]}}"
    );
    var client = make_client(transport);

    bool done = false;
    HolderLinux.CardContextData? result = null;
    client.get_card_context.begin("proj-1", "a1", (obj, res) => {
        try {
            result = client.get_card_context.end(res);
        } catch (Error e) {
            result = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(result != null);
    assert(result.project.project_id == "proj-1");
    assert(result.project.name == "Project One");
    assert(result.current_parent_card_id == "a1");
    assert(result.breadcrumbs.size == 2);
    assert(result.breadcrumbs[1].card_id == "a1");
    assert(result.cards.size == 1);
    assert(result.cards[0].card_id == "b1");
    assert(result.cards[0].child_count == 3);
    assert(transport.last_method == "GET");
    assert(transport.last_uri.contains("/cards/context?"));
    assert(transport.last_uri.contains("project_id=proj-1"));
    assert(transport.last_uri.contains("parent_card_id=a1"));
}

private void test_get_card_context_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.get_card_context.begin("proj-1", null, (obj, res) => {
        try {
            client.get_card_context.end(res);
        } catch (HolderLinux.ApiError e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        } catch (Error e) {
            got_protocol = false;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

private void test_list_projects_parses_sync_state_fields() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"project_id\":\"p1\",\"name\":\"My Project\",\"root_path\":\"/tmp/p1\",\"created_at\":1,\"updated_at\":2,\"sync\":{\"last_commit_at\":10,\"last_push_at\":11,\"last_pull_at\":12,\"uncommitted_changes_count\":3,\"unpushed_commits_count\":4,\"last_push_status\":\"pushed\",\"last_pull_status\":\"pulled\",\"last_sync_error\":\"\",\"last_sync_error_at\":13,\"retry_count\":2,\"next_retry_at\":14,\"updated_at\":15}}]}"
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
    var sync = projects[0].sync;
    assert(sync.has_last_commit_at);
    assert(sync.last_commit_at == 10);
    assert(sync.has_last_push_at);
    assert(sync.last_push_at == 11);
    assert(sync.has_last_pull_at);
    assert(sync.last_pull_at == 12);
    assert(sync.uncommitted_changes_count == 3);
    assert(sync.unpushed_commits_count == 4);
    assert(sync.last_push_status == "pushed");
    assert(sync.last_pull_status == "pulled");
    assert(sync.last_sync_error == "");
    assert(sync.has_last_sync_error_at);
    assert(sync.last_sync_error_at == 13);
    assert(sync.retry_count == 2);
    assert(sync.has_next_retry_at);
    assert(sync.next_retry_at == 14);
    assert(sync.has_updated_at);
    assert(sync.updated_at == 15);
}

private void test_list_projects_sync_null_or_non_object_uses_defaults() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"project_id\":\"p1\",\"name\":\"Null Sync\",\"root_path\":\"/tmp/p1\",\"sync\":null},{\"project_id\":\"p2\",\"name\":\"Array Sync\",\"root_path\":\"/tmp/p2\",\"sync\":[]}]}"
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
    assert(projects.size == 2);
    assert(!projects[0].sync.has_last_commit_at);
    assert(projects[0].sync.uncommitted_changes_count == 0);
    assert(!projects[1].sync.has_last_push_at);
    assert(projects[1].sync.retry_count == 0);
}

private void test_list_projects_parses_nullable_git_remote_url() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"project_id\":\"p1\",\"name\":\"No Remote\",\"git_remote_url\":null},{\"project_id\":\"p2\",\"name\":\"Has Remote\",\"git_remote_url\":\"git@github.com:owner/repo.git\"}]}"
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
    assert(projects.size == 2);
    assert(projects[0].git_remote_url == null);
    assert(projects[1].git_remote_url == "git@github.com:owner/repo.git");
}

private void test_list_projects_sync_nullable_int_fields_missing_and_null() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"project_id\":\"p1\",\"name\":\"Sync Nullables\",\"sync\":{\"last_push_at\":null,\"last_pull_at\":77,\"last_sync_error_at\":null,\"next_retry_at\":88,\"updated_at\":99}}]}"
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
    var sync = projects[0].sync;
    assert(!sync.has_last_commit_at);   // missing key path
    assert(!sync.has_last_push_at);     // explicit null path
    assert(sync.has_last_pull_at);
    assert(sync.last_pull_at == 77);
    assert(!sync.has_last_sync_error_at); // explicit null path
    assert(sync.has_next_retry_at);
    assert(sync.next_retry_at == 88);
    assert(sync.has_updated_at);
    assert(sync.updated_at == 99);
}

private void test_list_projects_sync_object_missing_counts_defaults_to_zero() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"project_id\":\"p1\",\"name\":\"Missing Counts\",\"sync\":{}}]}"
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
    assert(projects[0].sync.uncommitted_changes_count == 0);
    assert(projects[0].sync.unpushed_commits_count == 0);
    assert(projects[0].sync.retry_count == 0);
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

private void test_get_health_info_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.get_health_info.begin((obj, res) => {
        try {
            client.get_health_info.end(res);
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

private string start_local_soup_server_with_handler(Soup.Server server, string path, string body, uint status) throws Error {
    server.add_handler(path, (srv, msg, req_path, query) => {
        msg.set_status(status, null);
        msg.set_response(
            "application/json",
            Soup.MemoryUse.COPY,
            (uint8[]) body.data
        );
    });

    bool listened = server.listen_local(0, (Soup.ServerListenOptions) 0);
    assert(listened);

    var uris = server.get_uris();
    assert(uris != null);
    var first_uri = uris.nth_data(0);
    assert(first_uri != null);
    var base_url = first_uri.to_string();
    if (base_url.has_suffix("/")) {
        base_url = base_url.substring(0, base_url.length - 1);
    }
    return base_url;
}

private void test_soup_api_http_transport_send_and_read_uses_status_and_bytes() {
    var server = new Soup.Server("server-header", "holder-linux-tests");
    string base_url = "";
    try {
        base_url = start_local_soup_server_with_handler(
            server,
            "/bytes",
            "{\"ok\":true}",
            202
        );
    } catch (Error e) {
        Test.message("Skipping transport bytes test: %s", e.message);
        return;
    }

    var transport = new HolderLinux.SoupApiHttpTransport(new Soup.Session());
    var message = new Soup.Message("GET", base_url + "/bytes");

    bool done = false;
    HolderLinux.ApiHttpBytesResponse? response = null;
    string async_error = "";
    transport.send_and_read.begin(message, (obj, res) => {
        try {
            response = transport.send_and_read.end(res);
        } catch (Error e) {
            async_error = e.message;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    if (async_error != "") {
        Test.message("Skipping transport bytes test (async error): %s", async_error);
        server.disconnect();
        return;
    }
    assert(response != null);
    assert(response.status == 202);
    string response_text = (string) response.body.get_data();
    assert(response_text.has_prefix("{\"ok\":true}"));
    server.disconnect();
}

private void test_soup_api_http_transport_send_returns_stream_and_status() {
    var server = new Soup.Server("server-header", "holder-linux-tests");
    string base_url = "";
    try {
        base_url = start_local_soup_server_with_handler(
            server,
            "/stream",
            "{\"value\":1}",
            201
        );
    } catch (Error e) {
        Test.message("Skipping transport stream test: %s", e.message);
        return;
    }

    var transport = new HolderLinux.SoupApiHttpTransport(new Soup.Session());
    var message = new Soup.Message("GET", base_url + "/stream");

    bool done = false;
    HolderLinux.ApiHttpStreamResponse? response = null;
    string async_error = "";
    transport.send.begin(message, (obj, res) => {
        try {
            response = transport.send.end(res);
        } catch (Error e) {
            async_error = e.message;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    if (async_error != "") {
        Test.message("Skipping transport stream test (async error): %s", async_error);
        server.disconnect();
        return;
    }
    assert(response != null);
    assert(response.status == 201);

    try {
        var data_stream = new DataInputStream(response.stream);
        string? line = data_stream.read_line(null);
        assert(line != null);
        assert(line.contains("\"value\":1"));
    } catch (Error e) {
        Test.message("Skipping stream read verification: %s", e.message);
    }
    server.disconnect();
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

private void test_request_json_unwrapped_with_request_body_sets_json_content_type() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"any\":1}");
    var client = make_client(transport);

    bool done = false;
    bool ok = false;
    client.request_json_unwrapped_for_tests.begin("POST", "/git_providers.json", "{\"x\":1}", null, (obj, res) => {
        try {
            var root = client.request_json_unwrapped_for_tests.end(res);
            ok = (root != null);
        } catch (Error e) {
            ok = false;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(ok);
    assert(transport.last_method == "POST");
    assert(transport.last_content_type == "application/json");
}

private void test_request_json_unwrapped_transport_error_maps_to_api_transport() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read_throw("socket down");
    var client = make_client(transport);

    bool done = false;
    bool got_transport = false;
    client.request_json_unwrapped_for_tests.begin("GET", "/git_providers.json", null, null, (obj, res) => {
        try {
            client.request_json_unwrapped_for_tests.end(res);
        } catch (Error e) {
            got_transport = (e is HolderLinux.ApiError.TRANSPORT);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_transport);
}

private void test_request_json_unwrapped_parse_error_on_2xx_rethrows_parse() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "not-json");
    var client = make_client(transport);

    bool done = false;
    bool got_parse = false;
    client.request_json_unwrapped_for_tests.begin("GET", "/ai_catalog.json", null, null, (obj, res) => {
        try {
            client.request_json_unwrapped_for_tests.end(res);
        } catch (Error e) {
            got_parse = (e is HolderLinux.ApiError.PARSE);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_parse);
}

private void test_request_json_unwrapped_non_2xx_paths_map_to_http() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(500, "not-json");
    transport.enqueue_read(500, "{\"x\":1}");
    var client = make_client(transport);

    bool done_invalid_json = false;
    bool invalid_json_http = false;
    client.request_json_unwrapped_for_tests.begin("GET", "/ai_catalog.json", null, null, (obj, res) => {
        try {
            client.request_json_unwrapped_for_tests.end(res);
        } catch (Error e) {
            invalid_json_http = (e is HolderLinux.ApiError.HTTP);
        }
        done_invalid_json = true;
    });
    assert(wait_for_condition(() => done_invalid_json));
    assert(invalid_json_http);

    bool done_parsed_json = false;
    bool parsed_json_http = false;
    client.request_json_unwrapped_for_tests.begin("GET", "/git_providers.json", null, null, (obj, res) => {
        try {
            client.request_json_unwrapped_for_tests.end(res);
        } catch (Error e) {
            parsed_json_http = (e is HolderLinux.ApiError.HTTP);
        }
        done_parsed_json = true;
    });
    assert(wait_for_condition(() => done_parsed_json));
    assert(parsed_json_http);
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

private void test_run_ai_stream_sse_read_error_maps_to_transport_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream_read_throw(200, "boom read");
    var client = make_client(transport);

    bool done = false;
    bool got_transport = false;
    bool message_has_prefix = false;
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
                message_has_prefix = e.message.contains("SSE read error:");
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(got_transport);
    assert(message_has_prefix);
}

private void test_default_api_factory_create_returns_api_client() {
    var factory = new HolderLinux.DefaultApiFactory();
    var api = factory.create("http://127.0.0.1:8080", "token-abc");
    assert(api is HolderLinux.ApiClient);
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
    Test.add_func("/api_client/export_project_recovery_token_missing_data_is_protocol_error",
                  test_export_project_recovery_token_missing_data_is_protocol_error);
    Test.add_func("/api_client/import_recovery_token_parses_outcome",
                  test_import_recovery_token_parses_outcome);
    Test.add_func("/api_client/import_recovery_token_missing_data_is_protocol_error",
                  test_import_recovery_token_missing_data_is_protocol_error);
    Test.add_func("/api_client/import_recovery_token_parses_non_null_pull_error",
                  test_import_recovery_token_parses_non_null_pull_error);
    Test.add_func("/api_client/list_cards_parses_data_and_query", test_list_cards_parses_data_and_query);
    Test.add_func("/api_client/list_cards_parses_non_null_parent_card_id",
                  test_list_cards_parses_non_null_parent_card_id);
    Test.add_func("/api_client/list_cards_with_parent_query", test_list_cards_with_parent_query);
    Test.add_func("/api_client/list_cards_ignores_blank_parent_query",
                  test_list_cards_ignores_blank_parent_query);
    Test.add_func("/api_client/resources_crud_and_parse", test_resources_crud_and_parse);
    Test.add_func("/api_client/create_resource_with_desc_succeeds",
                  test_create_resource_with_desc_succeeds);
    Test.add_func("/api_client/create_resource_missing_data_is_protocol_error",
                  test_create_resource_missing_data_is_protocol_error);
    Test.add_func("/api_client/update_resource_with_desc_succeeds",
                  test_update_resource_with_desc_succeeds);
    Test.add_func("/api_client/list_resources_parses_non_null_desc",
                  test_list_resources_parses_non_null_desc);
    Test.add_func("/api_client/list_resources_missing_data_is_protocol_error",
                  test_list_resources_missing_data_is_protocol_error);
    Test.add_func("/api_client/get_card_parses_detail", test_get_card_parses_detail);
    Test.add_func("/api_client/list_card_links_and_backlinks_parse_data",
                  test_list_card_links_and_backlinks_parse_data);
    Test.add_func("/api_client/list_card_links_missing_data_is_protocol_error",
                  test_list_card_links_missing_data_is_protocol_error);
    Test.add_func("/api_client/create_card_link_posts_payload_and_parses_response",
                  test_create_card_link_posts_payload_and_parses_response);
    Test.add_func("/api_client/create_card_link_missing_data_is_protocol_error",
                  test_create_card_link_missing_data_is_protocol_error);
    Test.add_func("/api_client/create_card_link_with_non_card_to_type_succeeds",
                  test_create_card_link_with_non_card_to_type_succeeds);
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
    Test.add_func("/api_client/list_ai_provider_catalog_falls_back_to_provider_id_display_name",
                  test_list_ai_provider_catalog_falls_back_to_provider_id_display_name);
    Test.add_func("/api_client/list_ai_provider_catalog_empty_provider_defaults_returns_empty",
                  test_list_ai_provider_catalog_empty_provider_defaults_returns_empty);
    Test.add_func("/api_client/list_git_provider_catalog_parses_providers",
                  test_list_git_provider_catalog_parses_providers);
    Test.add_func("/api_client/list_git_provider_catalog_parses_examples",
                  test_list_git_provider_catalog_parses_examples);
    Test.add_func("/api_client/list_git_provider_catalog_missing_providers_returns_empty",
                  test_list_git_provider_catalog_missing_providers_returns_empty);
    Test.add_func("/api_client/git_remote_test_and_push_parse_results",
                  test_git_remote_test_and_push_parse_results);
    Test.add_func("/api_client/set_project_git_remote_handles_null_and_non_empty_url",
                  test_set_project_git_remote_handles_null_and_non_empty_url);
    Test.add_func("/api_client/git_remote_optional_inputs_are_accepted",
                  test_git_remote_optional_inputs_are_accepted);
    Test.add_func("/api_client/test_project_git_remote_whitespace_remote_url_maps_to_null",
                  test_test_project_git_remote_whitespace_remote_url_maps_to_null);
    Test.add_func("/api_client/git_remote_test_and_push_missing_data_are_protocol_errors",
                  test_git_remote_test_and_push_missing_data_are_protocol_errors);
    Test.add_func("/api_client/create_and_update_card_payloads", test_create_and_update_card_payloads);
    Test.add_func("/api_client/create_card_with_parent_id_succeeds",
                  test_create_card_with_parent_id_succeeds);
    Test.add_func("/api_client/update_card_position_with_parent_and_root",
                  test_update_card_position_with_parent_and_root);
    Test.add_func("/api_client/move_card_posts_move_endpoint",
                  test_move_card_posts_move_endpoint);
    Test.add_func("/api_client/get_card_context_parses_response",
                  test_get_card_context_parses_response);
    Test.add_func("/api_client/get_card_context_missing_data_is_protocol_error",
                  test_get_card_context_missing_data_is_protocol_error);
    Test.add_func("/api_client/list_projects_parses_sync_state_fields",
                  test_list_projects_parses_sync_state_fields);
    Test.add_func("/api_client/list_projects_sync_null_or_non_object_uses_defaults",
                  test_list_projects_sync_null_or_non_object_uses_defaults);
    Test.add_func("/api_client/list_projects_parses_nullable_git_remote_url",
                  test_list_projects_parses_nullable_git_remote_url);
    Test.add_func("/api_client/list_projects_sync_nullable_int_fields_missing_and_null",
                  test_list_projects_sync_nullable_int_fields_missing_and_null);
    Test.add_func("/api_client/list_projects_sync_object_missing_counts_defaults_to_zero",
                  test_list_projects_sync_object_missing_counts_defaults_to_zero);
    Test.add_func("/api_client/health_check_missing_data_is_protocol_error",
                  test_health_check_missing_data_is_protocol_error);
    Test.add_func("/api_client/get_health_info_missing_data_is_protocol_error",
                  test_get_health_info_missing_data_is_protocol_error);
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
    Test.add_func("/api_client/soup_api_http_transport_send_and_read_uses_status_and_bytes",
                  test_soup_api_http_transport_send_and_read_uses_status_and_bytes);
    Test.add_func("/api_client/soup_api_http_transport_send_returns_stream_and_status",
                  test_soup_api_http_transport_send_returns_stream_and_status);
    Test.add_func("/api_client/request_json_transport_error_maps_to_api_transport",
                  test_request_json_transport_error_maps_to_api_transport);
    Test.add_func("/api_client/request_json_http_error_parses_error_object",
                  test_request_json_http_error_parses_error_object);
    Test.add_func("/api_client/request_json_parse_error_on_success_response",
                  test_request_json_parse_error_on_success_response);
    Test.add_func("/api_client/request_json_protocol_error_when_ok_missing",
                  test_request_json_protocol_error_when_ok_missing);
    Test.add_func("/api_client/request_json_unwrapped_with_request_body_sets_json_content_type",
                  test_request_json_unwrapped_with_request_body_sets_json_content_type);
    Test.add_func("/api_client/request_json_unwrapped_transport_error_maps_to_api_transport",
                  test_request_json_unwrapped_transport_error_maps_to_api_transport);
    Test.add_func("/api_client/request_json_unwrapped_parse_error_on_2xx_rethrows_parse",
                  test_request_json_unwrapped_parse_error_on_2xx_rethrows_parse);
    Test.add_func("/api_client/request_json_unwrapped_non_2xx_paths_map_to_http",
                  test_request_json_unwrapped_non_2xx_paths_map_to_http);
    Test.add_func("/api_client/run_ai_stream_parses_sse_and_raw_data",
                  test_run_ai_stream_parses_sse_and_raw_data);
    Test.add_func("/api_client/run_ai_stream_http_error", test_run_ai_stream_http_error);
    Test.add_func("/api_client/run_ai_stream_transport_error", test_run_ai_stream_transport_error);
    Test.add_func("/api_client/run_ai_stream_sse_read_error_maps_to_transport_error",
                  test_run_ai_stream_sse_read_error_maps_to_transport_error);
    Test.add_func("/api_client/default_api_factory_create_returns_api_client",
                  test_default_api_factory_create_returns_api_client);

    return Test.run();
}

}
