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

private void test_parse_trash_items_parses_card_and_ai_message() {
    var root = parse_json_object(
        "{\"data\":[{" +
        "\"type\":\"card\",\"card_id\":\"c1\",\"title\":\"Card One\",\"deleted_at\":100}," +
        "{\"type\":\"ai_message\",\"message_id\":\"abcdef123456\",\"role\":\"assistant\",\"deleted_at\":200}" +
        "]}"
    );

    Gee.ArrayList<HolderLinux.TrashItem> items;
    try {
        items = HolderLinux.ApiParsersTrash.parse_trash_items(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(items.size == 2);
    assert(items[0].item_type == "card");
    assert(items[0].item_id == "c1");
    assert(items[0].title == "Card One");
    assert(items[0].deleted_at == 100);

    assert(items[1].item_type == "ai_message");
    assert(items[1].item_id == "abcdef123456");
    assert(items[1].title == "assistant abcdef12");
    assert(items[1].deleted_at == 200);
}

private void test_parse_trash_items_ai_message_title_without_role_and_short_ids() {
    var root = parse_json_object(
        "{\"data\":[{" +
        "\"type\":\"ai_message\",\"message_id\":\"abcd1234\",\"role\":\"\",\"deleted_at\":1}," +
        "{\"type\":\"ai_message\",\"message_id\":\"abcdef123456\",\"deleted_at\":2}" +
        "]}"
    );

    Gee.ArrayList<HolderLinux.TrashItem> items;
    try {
        items = HolderLinux.ApiParsersTrash.parse_trash_items(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(items.size == 2);
    assert(items[0].title == "ai_message abcd1234");
    assert(items[1].title == "ai_message abcdef12");
}

private void test_parse_trash_items_skips_unknown_or_missing_type() {
    var root = parse_json_object(
        "{\"data\":[{" +
        "\"type\":\"resource\",\"message_id\":\"m1\",\"deleted_at\":1}," +
        "{\"card_id\":\"c1\",\"title\":\"No Type\",\"deleted_at\":2}," +
        "{\"type\":\"card\",\"card_id\":\"c2\",\"title\":\"Card Two\"}" +
        "]}"
    );

    Gee.ArrayList<HolderLinux.TrashItem> items;
    try {
        items = HolderLinux.ApiParsersTrash.parse_trash_items(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(items.size == 1);
    assert(items[0].item_type == "card");
    assert(items[0].item_id == "c2");
    assert(items[0].title == "Card Two");
    assert(items[0].deleted_at == 0);
}

private void test_parse_trash_items_empty_array() {
    var root = parse_json_object("{\"data\":[]}");

    Gee.ArrayList<HolderLinux.TrashItem> items;
    try {
        items = HolderLinux.ApiParsersTrash.parse_trash_items(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(items.size == 0);
}

private void test_parse_trash_items_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");

    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersTrash.parse_trash_items(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for trash response");
    }

    assert(got_protocol);
}


public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/parsers/trash/card-and-ai-message", test_parse_trash_items_parses_card_and_ai_message);
    Test.add_func("/parsers/trash/ai-message-title-without-role-and-short-ids", test_parse_trash_items_ai_message_title_without_role_and_short_ids);
    Test.add_func("/parsers/trash/skips-unknown-or-missing-type", test_parse_trash_items_skips_unknown_or_missing_type);
    Test.add_func("/parsers/trash/empty-array", test_parse_trash_items_empty_array);
    Test.add_func("/parsers/trash/missing-data-protocol-error", test_parse_trash_items_missing_data_is_protocol_error);

    return Test.run();
}

}
