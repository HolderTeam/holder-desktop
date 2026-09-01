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

private void test_parse_cards_full_and_defaults() {
    var root = parse_json_object(
        "{\"data\":[" +
        "{\"card_id\":\"c1\",\"project_id\":\"p1\",\"title\":\"One\",\"rel_path\":\"a.md\",\"sort_key\":1.5,\"parent_card_id\":\"p\",\"created_at\":10,\"updated_at\":11}," +
        "{\"card_id\":\"c2\",\"project_id\":\"p1\",\"title\":\"Two\",\"parent_card_id\":null}," +
        "{\"card_id\":\"c3\",\"project_id\":\"p2\",\"title\":\"Three\"}" +
        "]}"
    );

    Gee.ArrayList<HolderLinux.CardSummary> cards;
    try {
        cards = HolderLinux.ApiParsersCards.parse_cards(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(cards.size == 3);
    assert(cards[0].card_id == "c1");
    assert(cards[0].project_id == "p1");
    assert(cards[0].title == "One");
    assert(cards[0].rel_path == "a.md");
    assert(cards[0].sort_key == 1.5);
    assert(cards[0].parent_card_id == "p");
    assert(cards[0].created_at == 10);
    assert(cards[0].updated_at == 11);

    assert(cards[1].parent_card_id == null);
    assert(cards[1].rel_path == "");
    assert(cards[1].sort_key == 0.0);
    assert(cards[1].created_at == 0);
    assert(cards[1].updated_at == 0);

    assert(cards[2].parent_card_id == null);
    assert(cards[2].rel_path == "");
    assert(cards[2].sort_key == 0.0);
}

private void test_parse_cards_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");
    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersCards.parse_cards(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for cards response");
    }
    assert(got_protocol);
}

private void test_parse_card_detail_full_and_default() {
    var root_full = parse_json_object(
        "{\"data\":{\"card_id\":\"c1\",\"project_id\":\"p1\",\"title\":\"T\",\"content\":\"#android Body\",\"updated_at\":99,\"tags\":[\"android\",\"sync\"],\"tag_occurrences\":[{\"tag\":\"android\",\"byte_start\":0,\"byte_end\":8}]}}"
    );

    HolderLinux.CardDetail full;
    try {
        full = HolderLinux.ApiParsersCards.parse_card_detail(root_full);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(full.card_id == "c1");
    assert(full.project_id == "p1");
    assert(full.title == "T");
    assert(full.content == "#android Body");
    assert(full.updated_at == 99);
    assert(full.tags.length == 2);
    assert(full.tags[0] == "android");
    assert(full.tag_occurrences.length == 1);
    assert(full.tag_occurrences[0].byte_end == 8);

    var root_default = parse_json_object(
        "{\"data\":{\"card_id\":\"c2\",\"project_id\":\"p2\",\"title\":\"X\",\"content\":\"Y\"}}"
    );
    HolderLinux.CardDetail defaults;
    try {
        defaults = HolderLinux.ApiParsersCards.parse_card_detail(root_default);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(defaults.updated_at == 0);
    assert(defaults.tags.length == 0);
    assert(defaults.tag_occurrences.length == 0);
}

private void test_parse_project_tags() {
    var root = parse_json_object(
        "{\"data\":[{\"tag\":\"sync\",\"card_count\":4},{\"tag\":\"android\",\"card_count\":2}]}"
    );
    Gee.ArrayList<HolderLinux.TagCount> tags;
    try {
        tags = HolderLinux.ApiParsersCards.parse_project_tags(root);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(tags.size == 2);
    assert(tags[0].tag == "sync");
    assert(tags[0].card_count == 4);

    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersCards.parse_project_tags(parse_json_object("{\"ok\":true}"));
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for project tags response");
    }
    assert(got_protocol);
}

private void test_parse_card_detail_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");
    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersCards.parse_card_detail(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for card response");
    }
    assert(got_protocol);
}

private void test_parse_card_context_full_and_defaults() {
    var root_full = parse_json_object(
        "{\"data\":{" +
        "\"project\":{\"project_id\":\"p1\",\"name\":\"Project One\"}," +
        "\"current_parent_card_id\":\"parent\"," +
        "\"breadcrumbs\":[{\"type\":\"project\",\"title\":\"Project One\",\"project_id\":\"p1\"}]," +
        "\"cards\":[{\"card_id\":\"c1\",\"project_id\":\"p1\",\"title\":\"A\",\"rel_path\":\"a.md\",\"sort_key\":2.5,\"parent_card_id\":\"parent\",\"created_at\":1,\"updated_at\":2,\"child_count\":3}]" +
        "}}"
    );

    HolderLinux.CardContextData full;
    try {
        full = HolderLinux.ApiParsersCards.parse_card_context(root_full);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(full.project.project_id == "p1");
    assert(full.project.name == "Project One");
    assert(full.current_parent_card_id == "parent");
    assert(full.breadcrumbs.size == 1);
    assert(full.breadcrumbs[0].crumb_type == "project");
    assert(full.cards.size == 1);
    assert(full.cards[0].card_id == "c1");
    assert(full.cards[0].sort_key == 2.5);
    assert(full.cards[0].parent_card_id == "parent");
    assert(full.cards[0].child_count == 3);

    var root_default = parse_json_object(
        "{\"data\":{\"project\":{\"project_id\":\"p2\",\"name\":\"P2\"}}}"
    );
    HolderLinux.CardContextData defaults;
    try {
        defaults = HolderLinux.ApiParsersCards.parse_card_context(root_default);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(defaults.current_parent_card_id == null);
    assert(defaults.breadcrumbs.size == 0);
    assert(defaults.cards.size == 0);
}

private void test_parse_card_context_errors() {
    var no_data = parse_json_object("{\"ok\":true}");
    bool no_data_protocol = false;
    try {
        HolderLinux.ApiParsersCards.parse_card_context(no_data);
    } catch (Error e) {
        no_data_protocol = e.message.contains("Missing data for cards context response");
    }
    assert(no_data_protocol);

    var no_project = parse_json_object("{\"data\":{}}");
    bool no_project_protocol = false;
    try {
        HolderLinux.ApiParsersCards.parse_card_context(no_project);
    } catch (Error e) {
        no_project_protocol = e.message.contains("Missing project for cards context response");
    }
    assert(no_project_protocol);
}

private void test_parse_card_links_and_link_defaults() {
    var root = parse_json_object(
        "{\"data\":[" +
        "{\"from_card_id\":\"a\",\"to_card_id\":\"b\",\"to_type\":\"card\",\"kind\":\"ref\",\"label\":\"L\",\"created_at\":9}," +
        "{\"from_card_id\":\"x\",\"to_card_id\":\"y\"}" +
        "]}"
    );

    Gee.ArrayList<HolderLinux.CardLink> links;
    try {
        links = HolderLinux.ApiParsersCards.parse_card_links(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(links.size == 2);
    assert(links[0].from_card_id == "a");
    assert(links[0].to_card_id == "b");
    assert(links[0].to_type == "card");
    assert(links[0].kind == "ref");
    assert(links[0].label == "L");
    assert(links[0].created_at == 9);

    assert(links[1].from_card_id == "x");
    assert(links[1].to_card_id == "y");
    assert(links[1].to_type == "card");
    assert(links[1].kind == "ref");
    assert(links[1].label == null);
    assert(links[1].created_at == 0);
}

private void test_parse_card_links_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");
    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersCards.parse_card_links(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for card links response");
    }
    assert(got_protocol);
}

private void test_parse_card_move_result_full_and_defaults() {
    var full = parse_json_object(
        "{\"card_id\":\"c1\",\"parent_card_id\":\"p\",\"sort_key\":2.0,\"revision\":7,\"moved_into_title\":\"Inbox\"}"
    );

    HolderLinux.CardMoveResult moved;
    try {
        moved = HolderLinux.ApiParsersCards.parse_card_move_result(full);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(moved.card_id == "c1");
    assert(moved.parent_card_id == "p");
    assert(moved.sort_key == 2.0);
    assert(moved.revision == 7);
    assert(moved.moved_into_title == "Inbox");

    var defaults = parse_json_object(
        "{\"card_id\":\"c2\",\"parent_card_id\":null,\"sort_key\":1.0,\"revision\":8}"
    );
    HolderLinux.CardMoveResult moved_default;
    try {
        moved_default = HolderLinux.ApiParsersCards.parse_card_move_result(defaults);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(moved_default.parent_card_id == null);
    assert(moved_default.moved_into_title == "");
}

private void test_parse_card_move_result_missing_fields_is_protocol_error() {
    var bad = parse_json_object("{\"card_id\":\"c1\"}");
    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersCards.parse_card_move_result(bad);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing fields for card move result");
    }
    assert(got_protocol);
}

private void test_parse_project_calendar_and_milestones() {
    var root = parse_json_object(
        "{\"data\":{" +
        "\"project_id\":\"p1\",\"from\":100,\"to\":500," +
        "\"milestones\":[{\"milestone_id\":\"m1\",\"card_id\":\"c1\"," +
        "\"start_at\":200,\"end_at\":220,\"all_day\":false,\"kind\":\"Exam\"," +
        "\"description\":\"Final\",\"created_at\":10,\"updated_at\":11," +
        "\"card_title\":\"Revision\"}]," +
        "\"created_cards\":[{\"card_id\":\"c2\",\"title\":\"Created\",\"created_at\":150,\"updated_at\":150}]," +
        "\"updated_cards\":[{\"card_id\":\"c3\",\"title\":\"Updated\",\"created_at\":120,\"updated_at\":250}]}}"
    );
    HolderLinux.ProjectCalendar parsed;
    try {
        parsed = HolderLinux.ApiParsersCards.parse_project_calendar(root);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(parsed.project_id == "p1");
    assert(parsed.from_epoch == 100);
    assert(parsed.to_epoch == 500);
    assert(parsed.milestones.length == 1);
    assert(parsed.milestones[0].milestone_id == "m1");
    assert(parsed.milestones[0].end_at == 220);
    assert(parsed.milestones[0].kind == "Exam");
    assert(parsed.milestones[0].card_title == "Revision");
    assert(parsed.created_cards.length == 1);
    assert(parsed.created_cards[0].card_id == "c2");
    assert(parsed.updated_cards.length == 1);
    assert(parsed.updated_cards[0].updated_at == 250);

    var list_root = parse_json_object(
        "{\"data\":[{\"milestone_id\":\"m2\",\"card_id\":\"c2\"," +
        "\"start_at\":300,\"end_at\":null,\"all_day\":true,\"kind\":null," +
        "\"description\":null,\"created_at\":1,\"updated_at\":1}]}"
    );
    Gee.ArrayList<HolderLinux.Milestone> listed;
    try {
        listed = HolderLinux.ApiParsersCards.parse_milestones_response(list_root);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(listed.size == 1);
    assert(listed[0].all_day);
    assert(listed[0].end_at == null);
    assert(listed[0].kind == null);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/parsers/cards/parse-cards-full-and-defaults", test_parse_cards_full_and_defaults);
    Test.add_func("/parsers/cards/parse-cards-missing-data-protocol-error", test_parse_cards_missing_data_is_protocol_error);
    Test.add_func("/parsers/cards/card-detail-full-and-default", test_parse_card_detail_full_and_default);
    Test.add_func("/parsers/cards/project-tags", test_parse_project_tags);
    Test.add_func("/parsers/cards/card-detail-missing-data-protocol-error", test_parse_card_detail_missing_data_is_protocol_error);
    Test.add_func("/parsers/cards/card-context-full-and-defaults", test_parse_card_context_full_and_defaults);
    Test.add_func("/parsers/cards/card-context-errors", test_parse_card_context_errors);
    Test.add_func("/parsers/cards/card-links-and-link-defaults", test_parse_card_links_and_link_defaults);
    Test.add_func("/parsers/cards/card-links-missing-data-protocol-error", test_parse_card_links_missing_data_is_protocol_error);
    Test.add_func("/parsers/cards/card-move-result-full-and-defaults", test_parse_card_move_result_full_and_defaults);
    Test.add_func("/parsers/cards/card-move-result-missing-fields-protocol-error", test_parse_card_move_result_missing_fields_is_protocol_error);
    Test.add_func("/parsers/cards/project-calendar-and-milestones", test_parse_project_calendar_and_milestones);

    return Test.run();
}

}
