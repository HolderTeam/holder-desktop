using GLib;

namespace HolderLinuxTests {

private HolderLinux.ApiClient make_client(FakeApiHttpTransport transport) {
    return new HolderLinux.ApiClient("http://127.0.0.1:8080", "token-123", transport);
}

private void test_list_cards_and_context_and_get_card() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"card_id\":\"c1\",\"project_id\":\"p1\",\"title\":\"Card One\",\"rel_path\":\"cards/c1.md\",\"sort_key\":1.0,\"parent_card_id\":null,\"created_at\":1,\"updated_at\":2}]}"
    );
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"project\":{\"project_id\":\"p1\",\"name\":\"Project One\"},\"current_parent_card_id\":null,\"breadcrumbs\":[],\"cards\":[{\"card_id\":\"c1\",\"project_id\":\"p1\",\"title\":\"Card One\",\"rel_path\":\"cards/c1.md\",\"sort_key\":1.0,\"parent_card_id\":null,\"created_at\":1,\"updated_at\":2,\"child_count\":0}]}}"
    );
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"card_id\":\"c1\",\"project_id\":\"p1\",\"title\":\"Card One\",\"content\":\"Hello\",\"updated_at\":10}}"
    );
    var client = make_client(transport);

    bool done_cards = false;
    Gee.ArrayList<HolderLinux.CardSummary>? cards = null;
    client.list_cards.begin("p1", "tree", null, 10, (obj, res) => {
        try { cards = client.list_cards.end(res); } catch (Error e) { cards = null; }
        done_cards = true;
    });
    assert(wait_for_condition(() => done_cards));
    assert(cards != null);
    assert(cards.size == 1);
    assert(cards[0].card_id == "c1");
    assert(transport.last_uri.contains("/cards"));
    assert(transport.last_uri.contains("project_id=p1"));
    assert(transport.last_uri.contains("view=tree"));
    assert(transport.last_uri.contains("limit=10"));

    bool done_ctx = false;
    HolderLinux.CardContextData? ctx = null;
    client.get_card_context.begin("p1", null, (obj, res) => {
        try { ctx = client.get_card_context.end(res); } catch (Error e) { ctx = null; }
        done_ctx = true;
    });
    assert(wait_for_condition(() => done_ctx));
    assert(ctx != null);
    assert(ctx.project.project_id == "p1");
    assert(ctx.cards.size == 1);
    assert(transport.last_uri.contains("/cards/context"));
    assert(transport.last_uri.contains("count=true"));

    bool done_card = false;
    HolderLinux.CardDetail? card = null;
    client.get_card.begin("c1", (obj, res) => {
        try { card = client.get_card.end(res); } catch (Error e) { card = null; }
        done_card = true;
    });
    assert(wait_for_condition(() => done_card));
    assert(card != null);
    assert(card.card_id == "c1");
    assert(card.content == "Hello");
}

private void test_links_create_delete_and_list() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"from_card_id\":\"c1\",\"to_card_id\":\"c2\",\"to_type\":\"card\",\"kind\":\"ref\",\"label\":\"L\",\"created_at\":1}]}"
    );
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"from_card_id\":\"c2\",\"to_card_id\":\"c1\",\"to_type\":\"card\",\"kind\":\"ref\",\"label\":\"B\",\"created_at\":2}]}"
    );
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"from_card_id\":\"c1\",\"to_card_id\":\"r1\",\"to_type\":\"resource\",\"kind\":\"depends_on\",\"label\":\"critical\",\"created_at\":3}}"
    );
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done_links = false;
    Gee.ArrayList<HolderLinux.CardLink>? links = null;
    client.list_card_links.begin("c1", (obj, res) => {
        try { links = client.list_card_links.end(res); } catch (Error e) { links = null; }
        done_links = true;
    });
    assert(wait_for_condition(() => done_links));
    assert(links != null);
    assert(links.size == 1);
    assert(links[0].to_card_id == "c2");

    bool done_back = false;
    Gee.ArrayList<HolderLinux.CardLink>? backlinks = null;
    client.list_card_backlinks.begin("c1", (obj, res) => {
        try { backlinks = client.list_card_backlinks.end(res); } catch (Error e) { backlinks = null; }
        done_back = true;
    });
    assert(wait_for_condition(() => done_back));
    assert(backlinks != null);
    assert(backlinks.size == 1);
    assert(backlinks[0].from_card_id == "c2");

    bool done_create = false;
    HolderLinux.CardLink? created = null;
    client.create_card_link.begin("c1", "r1", "depends_on", " critical ", "resource", (obj, res) => {
        try { created = client.create_card_link.end(res); } catch (Error e) { created = null; }
        done_create = true;
    });
    assert(wait_for_condition(() => done_create));
    assert(created != null);
    assert(created.to_type == "resource");
    assert(created.kind == "depends_on");
    assert(created.label == "critical");
    assert(transport.last_method == "POST");
    assert(transport.last_uri.contains("/cards/c1/links"));

    bool done_delete = false;
    bool ok_delete = false;
    client.delete_card_link.begin("c1", "r1", " depends_on ", "resource", (obj, res) => {
        try { client.delete_card_link.end(res); ok_delete = true; } catch (Error e) { ok_delete = false; }
        done_delete = true;
    });
    assert(wait_for_condition(() => done_delete));
    assert(ok_delete);
    assert(transport.last_method == "DELETE");
}

private void test_create_link_missing_data_and_move_missing_data_are_protocol_errors() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true}");
    transport.enqueue_read(200, "{\"ok\":true}");
    var client = make_client(transport);

    bool done_link = false;
    bool got_link_protocol = false;
    client.create_card_link.begin("c1", "c2", "ref", null, "card", (obj, res) => {
        try { client.create_card_link.end(res); } catch (Error e) { got_link_protocol = (e is HolderLinux.ApiError.PROTOCOL); }
        done_link = true;
    });
    assert(wait_for_condition(() => done_link));
    assert(got_link_protocol);

    bool done_move = false;
    bool got_move_protocol = false;
    client.move_card.begin("c1", "p1", "before", "c2", null, (obj, res) => {
        try { client.move_card.end(res); } catch (Error e) { got_move_protocol = (e is HolderLinux.ApiError.PROTOCOL); }
        done_move = true;
    });
    assert(wait_for_condition(() => done_move));
    assert(got_move_protocol);
}

private void test_create_update_position_and_move_card_success() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{\"card_id\":\"c-new\"}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":{\"card_id\":\"c1\",\"parent_card_id\":null,\"sort_key\":10.5,\"revision\":42,\"moved_into_title\":\"Inbox\"}}"
    );
    var client = make_client(transport);

    bool done_create = false;
    string created = "";
    client.create_card.begin("p1", "Title", "Body", "parent-1", (obj, res) => {
        try { created = client.create_card.end(res); } catch (Error e) { created = ""; }
        done_create = true;
    });
    assert(wait_for_condition(() => done_create));
    assert(created == "c-new");

    bool done_update = false;
    bool ok_update = false;
    client.update_card.begin("c1", "New Title", "New Body", 100, (obj, res) => {
        try { client.update_card.end(res); ok_update = true; } catch (Error e) { ok_update = false; }
        done_update = true;
    });
    assert(wait_for_condition(() => done_update));
    assert(ok_update);
    assert(transport.last_method == "PATCH");

    bool done_pos = false;
    bool ok_pos = false;
    client.update_card_position.begin("c1", null, 1.25, 101, (obj, res) => {
        try { client.update_card_position.end(res); ok_pos = true; } catch (Error e) { ok_pos = false; }
        done_pos = true;
    });
    assert(wait_for_condition(() => done_pos));
    assert(ok_pos);
    assert(transport.last_method == "PATCH");

    bool done_move = false;
    HolderLinux.CardMoveResult? moved = null;
    client.move_card.begin("c1", "p1", "to_start", null, null, (obj, res) => {
        try { moved = client.move_card.end(res); } catch (Error e) { moved = null; }
        done_move = true;
    });
    assert(wait_for_condition(() => done_move));
    assert(moved != null);
    assert(moved.card_id == "c1");
    assert(moved.revision == 42);
}

private void test_delete_card_sends_delete_to_card_path() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200, "{\"ok\":true,\"data\":{}}");
    var client = make_client(transport);

    bool done_delete = false;
    bool ok_delete = false;
    client.delete_card.begin("c 1/2", (obj, res) => {
        try { client.delete_card.end(res); ok_delete = true; } catch (Error e) { ok_delete = false; }
        done_delete = true;
    });

    assert(wait_for_condition(() => done_delete));
    assert(ok_delete);
    assert(transport.last_method == "DELETE");
    assert(transport.last_uri.contains("/cards/c%201%2F2"));
}

private void test_project_tags_and_cards_with_tag() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"tag\":\"android\",\"card_count\":2}]}"
    );
    transport.enqueue_read(
        200,
        "{\"ok\":true,\"data\":[{\"card_id\":\"c1\",\"project_id\":\"p1\",\"title\":\"Tagged\",\"updated_at\":2}]}"
    );
    var client = make_client(transport);

    bool tags_done = false;
    Gee.ArrayList<HolderLinux.TagCount>? tags = null;
    client.list_project_tags.begin("p 1", (obj, res) => {
        try { tags = client.list_project_tags.end(res); } catch (Error e) { tags = null; }
        tags_done = true;
    });
    assert(wait_for_condition(() => tags_done));
    assert(tags != null && tags.size == 1);
    assert(tags[0].tag == "android");
    assert(transport.last_uri.contains("/projects/p%201/tags"));

    bool cards_done = false;
    Gee.ArrayList<HolderLinux.CardSummary>? cards = null;
    client.list_cards_with_tag.begin("p1", "android/mobile", (obj, res) => {
        try { cards = client.list_cards_with_tag.end(res); } catch (Error e) { cards = null; }
        cards_done = true;
    });
    assert(wait_for_condition(() => cards_done));
    assert(cards != null && cards.size == 1);
    assert(cards[0].title == "Tagged");
    assert(transport.last_uri.contains("tag=android%2Fmobile"));
}

private void test_calendar_and_milestone_endpoints() {
    var transport = new FakeApiHttpTransport();
    transport.enqueue_read(200,
        "{\"ok\":true,\"data\":{\"project_id\":\"p1\",\"from\":100,\"to\":500," +
        "\"milestones\":[],\"created_cards\":[],\"updated_cards\":[]}}");
    transport.enqueue_read(200,
        "{\"ok\":true,\"data\":[{\"milestone_id\":\"m1\",\"card_id\":\"c1\"," +
        "\"start_at\":200,\"end_at\":null,\"all_day\":true,\"kind\":null," +
        "\"description\":null,\"created_at\":1,\"updated_at\":1}]}");
    transport.enqueue_read(201,
        "{\"ok\":true,\"data\":{\"milestone_id\":\"m2\",\"card_id\":\"c1\"," +
        "\"start_at\":300,\"end_at\":360,\"all_day\":false,\"kind\":\"Service\"," +
        "\"description\":\"Boiler\",\"created_at\":2,\"updated_at\":2}}");
    transport.enqueue_read(200,
        "{\"ok\":true,\"data\":{\"card_id\":\"c1\",\"milestone_id\":\"m2\",\"removed\":true}}");
    var client = make_client(transport);

    bool calendar_done = false;
    HolderLinux.ProjectCalendar? calendar = null;
    client.get_project_calendar.begin("p1", 100, 500, (obj, res) => {
        try { calendar = client.get_project_calendar.end(res); } catch (Error e) { calendar = null; }
        calendar_done = true;
    });
    assert(wait_for_condition(() => calendar_done));
    assert(calendar != null && calendar.project_id == "p1");
    assert(transport.last_uri.contains("/calendar"));
    assert(transport.last_uri.contains("project_id=p1"));
    assert(transport.last_uri.contains("from=100"));
    assert(transport.last_uri.contains("to=500"));

    bool list_done = false;
    Gee.ArrayList<HolderLinux.Milestone>? milestones = null;
    client.list_card_milestones.begin("c1", (obj, res) => {
        try { milestones = client.list_card_milestones.end(res); } catch (Error e) { milestones = null; }
        list_done = true;
    });
    assert(wait_for_condition(() => list_done));
    assert(milestones != null && milestones.size == 1);

    bool add_done = false;
    HolderLinux.Milestone? added = null;
    client.add_card_milestone.begin("c1", 300, 360, false, " Service ", " Boiler ", (obj, res) => {
        try { added = client.add_card_milestone.end(res); } catch (Error e) { added = null; }
        add_done = true;
    });
    assert(wait_for_condition(() => add_done));
    assert(added != null && added.kind == "Service");
    assert(transport.last_method == "POST");

    bool delete_done = false;
    bool removed = false;
    client.remove_card_milestone.begin("c1", "m2", (obj, res) => {
        try { removed = client.remove_card_milestone.end(res); } catch (Error e) { removed = false; }
        delete_done = true;
    });
    assert(wait_for_condition(() => delete_done));
    assert(removed);
    assert(transport.last_method == "DELETE");
    assert(transport.last_uri.contains("/cards/c1/milestones/m2"));
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/api_client_cards/list_cards_and_context_and_get_card",
                  test_list_cards_and_context_and_get_card);
    Test.add_func("/api_client_cards/links_create_delete_and_list",
                  test_links_create_delete_and_list);
    Test.add_func("/api_client_cards/create_link_missing_data_and_move_missing_data_are_protocol_errors",
                  test_create_link_missing_data_and_move_missing_data_are_protocol_errors);
    Test.add_func("/api_client_cards/create_update_position_and_move_card_success",
                  test_create_update_position_and_move_card_success);
    Test.add_func("/api_client_cards/delete_card_sends_delete_to_card_path",
                  test_delete_card_sends_delete_to_card_path);
    Test.add_func("/api_client_cards/project_tags_and_cards_with_tag",
                  test_project_tags_and_cards_with_tag);
    Test.add_func("/api_client_cards/calendar_and_milestone_endpoints",
                  test_calendar_and_milestone_endpoints);

    return Test.run();
}

}
