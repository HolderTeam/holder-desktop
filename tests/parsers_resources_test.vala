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
        "{\"resource_id\":\"r1\",\"project_id\":\"p1\",\"type\":\"website\",\"label\":\"Example\",\"metadata\":{\"identifier\":[\"https://example.com\"],\"description\":[\"Docs\"],\"creator\":[\"One\",\"Two\"]},\"assets\":[{\"asset_id\":\"a1\",\"resource_id\":\"r1\",\"original_filename\":\"page.pdf\",\"media_type\":\"application/pdf\",\"byte_size\":42,\"plaintext_sha256\":\"abc123\",\"placements\":[{\"placement_id\":\"pl1\",\"location_id\":\"l1\",\"encoding\":\"plain\",\"stored_byte_size\":42}]}],\"referenced_by_cards\":[{\"card_id\":\"c1\",\"title\":\"Research notes\",\"updated_at\":333,\"link_kinds\":[\"attachment\",\"reference\"]}],\"created_at\":111,\"updated_at\":222}," +
        "{\"resource_id\":\"r2\",\"project_id\":\"p2\",\"type\":\"document\",\"label\":\"Local\",\"metadata\":{},\"assets\":[]}," +
        "{\"resource_id\":\"r3\"}," +
        "{\"resource_id\":\"r4\",\"assets\":[{\"asset_id\":\"a2\",\"resource_id\":\"r4\",\"original_filename\":\"note.txt\",\"media_type\":\"text/plain\",\"placements\":[{\"placement_id\":\"pl2\",\"location_id\":\"l2\",\"encoding\":\"plain\"}]}]," +
        "\"referenced_by_cards\":[{\"card_id\":\"c2\",\"title\":\"Untimed note\"}]}" +
        "]}"
    );

    Gee.ArrayList<HolderLinux.ProjectResource> resources;
    try {
        resources = HolderLinux.ApiParsersResources.parse_resources(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(resources.size == 4);

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
    assert(r1.assets[0].plaintext_sha256 == "abc123");
    assert(r1.assets[0].placements.size == 1);
    assert(r1.assets[0].placements[0].location_id == "l1");
    assert(r1.referenced_by_cards.size == 1);
    assert(r1.referenced_by_cards[0].card_id == "c1");
    assert(r1.referenced_by_cards[0].title == "Research notes");
    assert(r1.referenced_by_cards[0].updated_at == 333);
    assert(r1.referenced_by_cards[0].link_kinds.size == 2);

    var r2 = resources[1];
    assert(r2.resource_id == "r2");
    assert(r2.project_id == "p2");
    assert(r2.resource_type == "document");
    assert(r2.uri == "");
    assert(r2.label == "Local");
    assert(r2.desc == null);
    assert(r2.created_at == 0);
    assert(r2.updated_at == 0);
    assert(r2.referenced_by_cards.size == 0);

    var r3 = resources[2];
    assert(r3.resource_id == "r3");
    assert(r3.project_id == "");
    assert(r3.kind == "");
    assert(r3.uri == "");
    assert(r3.label == "");
    assert(r3.desc == null);
    assert(r3.created_at == 0);
    assert(r3.updated_at == 0);

    var r4 = resources[3];
    assert(r4.assets.size == 1);
    assert(r4.assets[0].placements.size == 1);
    assert(r4.assets[0].placements[0].stored_byte_size == 0);
    assert(r4.assets[0].byte_size == 0);
    assert(r4.referenced_by_cards.size == 1);
    assert(r4.referenced_by_cards[0].updated_at == 0);
}

private void test_parse_import_job_retains_reuse_and_link_state() {
    var root = parse_json_object(
        "{\"data\":{\"job_id\":\"j1\",\"status\":\"completed\",\"resource_id\":\"r1\"," +
        "\"asset_id\":\"a1\",\"duplicate_reused\":true,\"link_created\":false,\"error\":null}}"
    );
    HolderLinux.AssetImportJob job;
    try {
        job = HolderLinux.ApiParsersResources.parse_import_job(root);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(job.job_id == "j1");
    assert(job.duplicate_reused);
    assert(!job.link_created);
}

private void test_parse_locations_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");

    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersResources.parse_locations(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for locations response");
    }

    assert(got_protocol);
}

private void test_parse_locations_full_and_defaults() {
    var root = parse_json_object(
        "{\"data\":[" +
        "{\"location_id\":\"l1\",\"project_id\":\"p1\",\"name\":\"Drive\",\"provider\":\"google-drive\"," +
        "\"configuration\":{\"folder\":\"root\",\"team\":\"eng\"},\"bound\":true,\"binding_preview\":\"Folder: root\"}," +
        "{\"location_id\":\"l2\",\"project_id\":\"p1\",\"name\":\"Local\",\"provider\":\"filesystem\"}" +
        "],\"preferred_location_id\":\"l1\"}"
    );

    HolderLinux.StorageLocationList list;
    try {
        list = HolderLinux.ApiParsersResources.parse_locations(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(list.locations.size == 2);
    var l1 = list.locations[0];
    assert(l1.location_id == "l1");
    assert(l1.project_id == "p1");
    assert(l1.name == "Drive");
    assert(l1.provider == "google-drive");
    assert(l1.configuration.get("folder") == "root");
    assert(l1.configuration.get("team") == "eng");
    assert(l1.bound);
    assert(l1.binding_preview == "Folder: root");

    var l2 = list.locations[1];
    assert(l2.location_id == "l2");
    assert(l2.configuration.size == 0);
    assert(!l2.bound);
    assert(l2.binding_preview == null);

    assert(list.preferred_location_id == "l1");
}

private void test_parse_locations_null_binding_preview_and_no_preferred_location() {
    var root = parse_json_object(
        "{\"data\":[" +
        "{\"location_id\":\"l1\",\"project_id\":\"p1\",\"name\":\"Drive\",\"provider\":\"google-drive\"," +
        "\"bound\":false,\"binding_preview\":null}" +
        "],\"preferred_location_id\":null}"
    );

    HolderLinux.StorageLocationList list;
    try {
        list = HolderLinux.ApiParsersResources.parse_locations(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(list.locations.size == 1);
    assert(list.locations[0].binding_preview == null);
    assert(list.preferred_location_id == null);
}

private void test_parse_import_job_defaults_when_optional_fields_absent() {
    var root = parse_json_object(
        "{\"data\":{\"job_id\":\"j1\",\"status\":\"pending\"}}"
    );

    HolderLinux.AssetImportJob job;
    try {
        job = HolderLinux.ApiParsersResources.parse_import_job(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(job.job_id == "j1");
    assert(job.status == "pending");
    assert(job.resource_id == null);
    assert(job.asset_id == null);
    assert(!job.duplicate_reused);
    assert(!job.link_created);
    assert(job.error == null);
}

private void test_parse_import_job_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");

    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersResources.parse_import_job(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for import job response");
    }

    assert(got_protocol);
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
    Test.add_func("/parsers/resources/import-job-reuse-state", test_parse_import_job_retains_reuse_and_link_state);
    Test.add_func("/parsers/resources/locations-missing-data-protocol-error",
                  test_parse_locations_missing_data_is_protocol_error);
    Test.add_func("/parsers/resources/locations-full-and-defaults",
                  test_parse_locations_full_and_defaults);
    Test.add_func("/parsers/resources/locations-null-binding-preview-and-no-preferred",
                  test_parse_locations_null_binding_preview_and_no_preferred_location);
    Test.add_func("/parsers/resources/import-job-defaults-when-optional-fields-absent",
                  test_parse_import_job_defaults_when_optional_fields_absent);
    Test.add_func("/parsers/resources/import-job-missing-data-protocol-error",
                  test_parse_import_job_missing_data_is_protocol_error);

    return Test.run();
}

}
