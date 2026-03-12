using GLib;

namespace HolderLinuxTests {

private HolderLinux.ApiClient make_client(FakeApiHttpTransport transport) {
    return new HolderLinux.ApiClient("http://127.0.0.1:8080", "token-123", transport);
}

private void test_list_trash_items_parses_results_and_query() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"type\":\"card\",\"card_id\":\"c1\",\"title\":\"Card 1\",\"deleted_at\":1700000000},{\"type\":\"ai_message\",\"message_id\":\"abcdef123456\",\"role\":\"assistant\",\"deleted_at\":1700000001}]}"
    );
    var client = make_client(transport);

    bool done = false;
    Gee.ArrayList<HolderLinux.TrashItem>? items = null;
    client.list_trash_items.begin("p1", " ai_message ", (obj, res) => {
        try {
            items = client.list_trash_items.end(res);
        } catch (Error e) {
            items = null;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(items != null);
    assert(items.size == 2);
    assert(items[0].item_type == "card");
    assert(items[0].item_id == "c1");
    assert(items[0].title == "Card 1");
    assert(items[1].item_type == "ai_message");
    assert(items[1].item_id == "abcdef123456");
    assert(items[1].title == "assistant abcdef12");
    assert(transport.last_method == "GET");
    assert(transport.last_uri.contains("/trash"));
    assert(transport.last_uri.contains("project_id=p1"));
    assert(transport.last_uri.contains("type=ai_message"));
}

private void test_empty_trash_with_and_without_type_filter() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done_first = false;
    bool ok_first = false;
    client.empty_trash.begin("p1", "all", (obj, res) => {
        try {
            client.empty_trash.end(res);
            ok_first = true;
        } catch (Error e) {
            ok_first = false;
        }
        done_first = true;
    });

    assert(wait_for_condition(() => done_first));
    assert(ok_first);
    assert(transport.last_method == "DELETE");
    assert(transport.last_uri.contains("/trash"));
    assert(transport.last_uri.contains("project_id=p1"));
    assert(transport.last_uri.contains("type=all"));

    bool done_second = false;
    bool ok_second = false;
    client.empty_trash.begin("p1", "   ", (obj, res) => {
        try {
            client.empty_trash.end(res);
            ok_second = true;
        } catch (Error e) {
            ok_second = false;
        }
        done_second = true;
    });

    assert(wait_for_condition(() => done_second));
    assert(ok_second);
    assert(!transport.last_uri.contains("type="));
}

private void test_restore_trash_item_card_and_ai_message_paths() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done_card = false;
    bool ok_card = false;
    client.restore_trash_item.begin("card", "card id/1", (obj, res) => {
        try {
            client.restore_trash_item.end(res);
            ok_card = true;
        } catch (Error e) {
            ok_card = false;
        }
        done_card = true;
    });

    assert(wait_for_condition(() => done_card));
    assert(ok_card);
    assert(transport.last_method == "POST");
    assert(transport.last_uri.contains("/cards/"));
    assert(transport.last_uri.contains("/restore"));
    assert(transport.last_uri.contains("card%20id%2F1"));

    bool done_ai = false;
    bool ok_ai = false;
    client.restore_trash_item.begin("ai_message", "msg id/2", (obj, res) => {
        try {
            client.restore_trash_item.end(res);
            ok_ai = true;
        } catch (Error e) {
            ok_ai = false;
        }
        done_ai = true;
    });

    assert(wait_for_condition(() => done_ai));
    assert(ok_ai);
    assert(transport.last_method == "POST");
    assert(transport.last_uri.contains("/ai/messages/"));
    assert(transport.last_uri.contains("/restore"));
    assert(transport.last_uri.contains("msg%20id%2F2"));
}

private void test_restore_trash_item_unsupported_type_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.restore_trash_item.begin("resource", "r1", (obj, res) => {
        try {
            client.restore_trash_item.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

private void test_hard_delete_trash_item_path() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done = false;
    bool ok = false;
    client.hard_delete_trash_item.begin("card", "card id/3", (obj, res) => {
        try {
            client.hard_delete_trash_item.end(res);
            ok = true;
        } catch (Error e) {
            ok = false;
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(ok);
    assert(transport.last_method == "DELETE");
    assert(transport.last_uri.contains("/trash/card/card%20id%2F3"));
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/api_client_trash/list_trash_items_parses_results_and_query",
                  test_list_trash_items_parses_results_and_query);
    Test.add_func("/api_client_trash/empty_trash_with_and_without_type_filter",
                  test_empty_trash_with_and_without_type_filter);
    Test.add_func("/api_client_trash/restore_trash_item_card_and_ai_message_paths",
                  test_restore_trash_item_card_and_ai_message_paths);
    Test.add_func("/api_client_trash/restore_trash_item_unsupported_type_is_protocol_error",
                  test_restore_trash_item_unsupported_type_is_protocol_error);
    Test.add_func("/api_client_trash/hard_delete_trash_item_path",
                  test_hard_delete_trash_item_path);

    return Test.run();
}

}
