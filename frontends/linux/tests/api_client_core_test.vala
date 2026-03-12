using GLib;

namespace HolderLinuxTests {

private HolderLinux.ApiClient make_client(FakeApiHttpTransport transport) {
    return new HolderLinux.ApiClient("http://127.0.0.1:8080", "token-123", transport);
}

private void test_core_request_json_unwrapped_for_tests_and_json_builder() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"x\":1}}");
    var client = make_client(transport);

    bool done = false;
    Json.Object? root = null;
    client.request_json_unwrapped_for_tests.begin("GET", "/health", null, null, (obj, res) => {
        try {
            root = client.request_json_unwrapped_for_tests.end(res);
        } catch (Error e) {
            root = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(root != null);
    assert(root.get_boolean_member("ok"));

    var builder = new Json.Builder();
    builder.begin_object();
    builder.set_member_name("k");
    builder.add_string_value("v");
    builder.end_object();

    var text = client.json_string_from_builder(builder);
    var parser = new Json.Parser();
    try {
        parser.load_from_data(text, -1);
    } catch (Error e) {
        assert_not_reached();
    }
    var parsed_root = parser.get_root();
    assert(parsed_root != null);
    assert(parsed_root.get_object().get_string_member("k") == "v");
}

private void test_core_run_ai_stream_delegates_to_ai_stream_runner() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_stream(200, "event: token\ndata: {\"piece\":\"Hello\"}\n\n");
    var client = make_client(transport);

    bool done = false;
    bool ok = true;
    string event_name = "";
    string piece = "";

    client.run_ai_stream.begin(
        "hello",
        "p1",
        "t1",
        "c1",
        "Card",
        "Body",
        (name, payload) => {
            event_name = name;
            piece = payload.get_string_member("piece");
        },
        (obj, res) => {
            try {
                client.run_ai_stream.end(res);
            } catch (Error e) {
                ok = false;
            }
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(ok);
    assert(event_name == "token");
    assert(piece == "Hello");
    assert(transport.last_method == "POST");
    assert(transport.last_uri == "http://127.0.0.1:8080/ai/runs");
}

private void test_core_domain_methods_smoke_delegation() {
    var transport = new FakeApiHttpTransport();
    var client = make_client(transport);

    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":[{\"project_id\":\"p1\",\"name\":\"P\",\"privacy_mode\":\"encrypted_git\"}]}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":[{\"card_id\":\"c1\",\"project_id\":\"p1\",\"title\":\"T\"}]}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":[]}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":[]}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":[]}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"providers\":[]}");

    bool done_health = false;
    bool health_ok = false;
    client.health_check.begin((obj, res) => {
        try {
            client.health_check.end(res);
            health_ok = true;
        } catch (Error e) {
            health_ok = false;
        }
        done_health = true;
    });
    assert(wait_for_condition(() => done_health));
    assert(health_ok);

    bool done_projects = false;
    Gee.ArrayList<HolderLinux.Project>? projects = null;
    client.list_projects.begin((obj, res) => {
        try {
            projects = client.list_projects.end(res);
        } catch (Error e) {
            projects = null;
        }
        done_projects = true;
    });
    assert(wait_for_condition(() => done_projects));
    assert(projects != null);
    assert(projects.size == 1);

    bool done_cards = false;
    Gee.ArrayList<HolderLinux.CardSummary>? cards = null;
    client.list_cards.begin("p1", "tree", null, 0, (obj, res) => {
        try {
            cards = client.list_cards.end(res);
        } catch (Error e) {
            cards = null;
        }
        done_cards = true;
    });
    assert(wait_for_condition(() => done_cards));
    assert(cards != null);
    assert(cards.size == 1);

    bool done_resources = false;
    Gee.ArrayList<HolderLinux.ProjectResource>? resources = null;
    client.list_resources.begin("p1", (obj, res) => {
        try {
            resources = client.list_resources.end(res);
        } catch (Error e) {
            resources = null;
        }
        done_resources = true;
    });
    assert(wait_for_condition(() => done_resources));
    assert(resources != null);

    bool done_trash = false;
    Gee.ArrayList<HolderLinux.TrashItem>? trash = null;
    client.list_trash_items.begin("p1", "all", (obj, res) => {
        try {
            trash = client.list_trash_items.end(res);
        } catch (Error e) {
            trash = null;
        }
        done_trash = true;
    });
    assert(wait_for_condition(() => done_trash));
    assert(trash != null);

    bool done_search = false;
    Gee.ArrayList<HolderLinux.SearchCardResult>? search = null;
    client.search_cards.begin("p1", "hello", 30, (obj, res) => {
        try {
            search = client.search_cards.end(res);
        } catch (Error e) {
            search = null;
        }
        done_search = true;
    });
    assert(wait_for_condition(() => done_search));
    assert(search != null);

    bool done_ai = false;
    HolderLinux.AiStatusInfo? ai_status = null;
    client.get_ai_status.begin((obj, res) => {
        try {
            ai_status = client.get_ai_status.end(res);
        } catch (Error e) {
            ai_status = null;
        }
        done_ai = true;
    });
    assert(wait_for_condition(() => done_ai));
    assert(ai_status != null);

    bool done_git = false;
    Gee.ArrayList<HolderLinux.GitProviderCatalogEntry>? git_providers = null;
    client.list_git_provider_catalog.begin((obj, res) => {
        try {
            git_providers = client.list_git_provider_catalog.end(res);
        } catch (Error e) {
            git_providers = null;
        }
        done_git = true;
    });
    assert(wait_for_condition(() => done_git));
    assert(git_providers != null);
}

private void test_core_git_mutation_methods_delegate() {
    var transport = new FakeApiHttpTransport();
    var client = make_client(transport);

    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"remote_url\":\"u\",\"branch\":\"main\",\"status\":\"ok\"}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"remote_url\":\"u\",\"branch\":\"main\",\"status\":\"ok\"}}");

    bool done_set = false;
    bool set_ok = false;
    client.set_project_git_remote.begin("p1", "https://example/repo.git", 10, (obj, res) => {
        try {
            client.set_project_git_remote.end(res);
            set_ok = true;
        } catch (Error e) {
            set_ok = false;
        }
        done_set = true;
    });
    assert(wait_for_condition(() => done_set));
    assert(set_ok);

    bool done_test = false;
    HolderLinux.GitTestRemoteResult? test_result = null;
    client.test_project_git_remote.begin("p1", "https://example/repo.git", "main", (obj, res) => {
        try {
            test_result = client.test_project_git_remote.end(res);
        } catch (Error e) {
            test_result = null;
        }
        done_test = true;
    });
    assert(wait_for_condition(() => done_test));
    assert(test_result != null);
    assert(test_result.status == "ok");

    bool done_push = false;
    HolderLinux.GitPushResult? push_result = null;
    client.push_project_git.begin("p1", "main", true, (obj, res) => {
        try {
            push_result = client.push_project_git.end(res);
        } catch (Error e) {
            push_result = null;
        }
        done_push = true;
    });
    assert(wait_for_condition(() => done_push));
    assert(push_result != null);
    assert(push_result.status == "ok");
}

private void test_core_trash_mutation_methods_delegate() {
    var transport = new FakeApiHttpTransport();
    var client = make_client(transport);

    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");

    bool done_empty = false;
    bool empty_ok = false;
    client.empty_trash.begin("p1", "all", (obj, res) => {
        try {
            client.empty_trash.end(res);
            empty_ok = true;
        } catch (Error e) {
            empty_ok = false;
        }
        done_empty = true;
    });
    assert(wait_for_condition(() => done_empty));
    assert(empty_ok);

    bool done_restore = false;
    bool restore_ok = false;
    client.restore_trash_item.begin("card", "c1", (obj, res) => {
        try {
            client.restore_trash_item.end(res);
            restore_ok = true;
        } catch (Error e) {
            restore_ok = false;
        }
        done_restore = true;
    });
    assert(wait_for_condition(() => done_restore));
    assert(restore_ok);

    bool done_delete = false;
    bool delete_ok = false;
    client.hard_delete_trash_item.begin("card", "c1", (obj, res) => {
        try {
            client.hard_delete_trash_item.end(res);
            delete_ok = true;
        } catch (Error e) {
            delete_ok = false;
        }
        done_delete = true;
    });
    assert(wait_for_condition(() => done_delete));
    assert(delete_ok);
}

private void test_default_api_factory_create_returns_api_client() {
    var factory = new HolderLinux.DefaultApiFactory();
    var api = factory.create("http://127.0.0.1:8080", "token-123");
    assert(api is HolderLinux.ApiClient);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/api_client_core/request_json_unwrapped_for_tests_and_json_builder",
                  test_core_request_json_unwrapped_for_tests_and_json_builder);
    Test.add_func("/api_client_core/run_ai_stream_delegates_to_ai_stream_runner",
                  test_core_run_ai_stream_delegates_to_ai_stream_runner);
    Test.add_func("/api_client_core/domain_methods_smoke_delegation",
                  test_core_domain_methods_smoke_delegation);
    Test.add_func("/api_client_core/git_mutation_methods_delegate",
                  test_core_git_mutation_methods_delegate);
    Test.add_func("/api_client_core/trash_mutation_methods_delegate",
                  test_core_trash_mutation_methods_delegate);
    Test.add_func("/api_client_core/default_api_factory_create_returns_api_client",
                  test_default_api_factory_create_returns_api_client);

    return Test.run();
}

}
