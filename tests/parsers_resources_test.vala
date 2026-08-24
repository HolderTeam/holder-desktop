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

private void test_parse_resources_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");

    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersResources.parse_resources(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for resources response");
    }

    assert(got_protocol);
}

private void test_parse_resources_full_and_defaults() {
    var root = parse_json_object(
        "{\"data\":[" +
        "{\"resource_id\":\"r1\",\"project_id\":\"p1\",\"type\":\"website\",\"label\":\"Example\",\"metadata\":{\"identifier\":[\"https://example.com\"],\"description\":[\"Docs\"],\"creator\":[\"One\",\"Two\"]},\"assets\":[{\"asset_id\":\"a1\",\"resource_id\":\"r1\",\"original_filename\":\"page.pdf\",\"media_type\":\"application/pdf\",\"byte_size\":42,\"placements\":[{\"placement_id\":\"pl1\",\"location_id\":\"l1\",\"encoding\":\"plain\",\"stored_byte_size\":42}]}],\"created_at\":111,\"updated_at\":222}," +
        "{\"resource_id\":\"r2\",\"project_id\":\"p2\",\"type\":\"document\",\"label\":\"Local\",\"metadata\":{},\"assets\":[]}," +
        "{\"resource_id\":\"r3\"}" +
        "]}"
    );

    Gee.ArrayList<HolderLinux.ProjectResource> resources;
    try {
        resources = HolderLinux.ApiParsersResources.parse_resources(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(resources.size == 3);

    var r1 = resources[0];
    assert(r1.resource_id == "r1");
    assert(r1.project_id == "p1");
    assert(r1.resource_type == "website");
    assert(r1.uri == "https://example.com");
    assert(r1.label == "Example");
    assert(r1.desc == "Docs");
    assert(r1.created_at == 111);
    assert(r1.updated_at == 222);
    assert(r1.metadata.get("creator").size == 2);
    assert(r1.assets.size == 1);
    assert(r1.assets[0].original_filename == "page.pdf");
    assert(r1.assets[0].placements.size == 1);
    assert(r1.assets[0].placements[0].location_id == "l1");

    var r2 = resources[1];
    assert(r2.resource_id == "r2");
    assert(r2.project_id == "p2");
    assert(r2.resource_type == "document");
    assert(r2.uri == "");
    assert(r2.label == "Local");
    assert(r2.desc == null);
    assert(r2.created_at == 0);
    assert(r2.updated_at == 0);

    var r3 = resources[2];
    assert(r3.resource_id == "r3");
    assert(r3.project_id == "");
    assert(r3.kind == "");
    assert(r3.uri == "");
    assert(r3.label == "");
    assert(r3.desc == null);
    assert(r3.created_at == 0);
    assert(r3.updated_at == 0);
}

private void test_parse_resources_empty_data_returns_empty_list() {
    var root = parse_json_object("{\"data\":[]}");

    Gee.ArrayList<HolderLinux.ProjectResource> resources;
    try {
        resources = HolderLinux.ApiParsersResources.parse_resources(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(resources.size == 0);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/parsers/resources/missing-data-protocol-error", test_parse_resources_missing_data_is_protocol_error);
    Test.add_func("/parsers/resources/full-and-defaults", test_parse_resources_full_and_defaults);
    Test.add_func("/parsers/resources/empty-data-returns-empty-list", test_parse_resources_empty_data_returns_empty_list);

    return Test.run();
}

}
