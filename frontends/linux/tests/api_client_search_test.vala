using GLib;

namespace HolderLinuxTests {

private HolderLinux.ApiClient make_client(FakeApiHttpTransport transport) {
    return new HolderLinux.ApiClient("http://127.0.0.1:8080", "token-123", transport);
}

private void test_search_cards_sends_query_and_parses_results() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"card_id\":\"c1\",\"title\":\"Card One\",\"updated_at\":11,\"created_at\":10,\"snippet\":\"hello\",\"rank\":1.5}]}"
    );
    var client = make_client(transport);

    bool done = false;
    Gee.ArrayList<HolderLinux.SearchCardResult>? results = null;
    client.search_cards.begin("p1", "hello", 25, (obj, res) => {
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
    assert(results[0].card_id == "c1");
    assert(results[0].title == "Card One");
    assert(results[0].snippet == "hello");
    assert(transport.last_method == "GET");
    assert(transport.last_uri.contains("/search/cards"));
    assert(transport.last_uri.contains("project_id=p1"));
    assert(transport.last_uri.contains("q=hello"));
    assert(transport.last_uri.contains("limit=25"));
}

private void test_search_cards_missing_data_is_protocol_error() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done = false;
    bool got_protocol = false;
    client.search_cards.begin("p1", "hello", 30, (obj, res) => {
        try {
            client.search_cards.end(res);
        } catch (Error e) {
            got_protocol = (e is HolderLinux.ApiError.PROTOCOL);
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_protocol);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/api_client_search/search_cards_sends_query_and_parses_results",
                  test_search_cards_sends_query_and_parses_results);
    Test.add_func("/api_client_search/search_cards_missing_data_is_protocol_error",
                  test_search_cards_missing_data_is_protocol_error);

    return Test.run();
}

}
