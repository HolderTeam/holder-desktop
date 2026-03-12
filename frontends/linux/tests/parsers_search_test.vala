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

private void test_parse_search_cards_parses_full_fields() {
    var root = parse_json_object(
        "{\"data\":[{" +
        "\"card_id\":\"c1\",\"title\":\"Card One\",\"updated_at\":123,\"created_at\":45,\"snippet\":\"match\",\"rank\":0.75" +
        "}]}"
    );

    Gee.ArrayList<HolderLinux.SearchCardResult> items;
    try {
        items = HolderLinux.ApiParsersSearch.parse_search_cards(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(items.size == 1);
    assert(items[0].card_id == "c1");
    assert(items[0].title == "Card One");
    assert(items[0].updated_at == 123);
    assert(items[0].created_at == 45);
    assert(items[0].snippet == "match");
    assert(Math.fabs(items[0].rank - 0.75) < 0.000001);
}

private void test_parse_search_cards_optional_defaults() {
    var root = parse_json_object(
        "{\"data\":[{" +
        "\"card_id\":\"c2\",\"title\":\"Card Two\"" +
        "}]}"
    );

    Gee.ArrayList<HolderLinux.SearchCardResult> items;
    try {
        items = HolderLinux.ApiParsersSearch.parse_search_cards(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(items.size == 1);
    assert(items[0].card_id == "c2");
    assert(items[0].title == "Card Two");
    assert(items[0].updated_at == 0);
    assert(items[0].created_at == 0);
    assert(items[0].snippet == "");
    assert(Math.fabs(items[0].rank - 0.0) < 0.000001);
}

private void test_parse_search_cards_empty_array() {
    var root = parse_json_object("{\"data\":[]}");

    Gee.ArrayList<HolderLinux.SearchCardResult> items;
    try {
        items = HolderLinux.ApiParsersSearch.parse_search_cards(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(items.size == 0);
}

private void test_parse_search_cards_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");

    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersSearch.parse_search_cards(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for search cards response");
    }

    assert(got_protocol);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/parsers/search/full-fields", test_parse_search_cards_parses_full_fields);
    Test.add_func("/parsers/search/optional-defaults", test_parse_search_cards_optional_defaults);
    Test.add_func("/parsers/search/empty-array", test_parse_search_cards_empty_array);
    Test.add_func("/parsers/search/missing-data-protocol-error", test_parse_search_cards_missing_data_is_protocol_error);

    return Test.run();
}

}
