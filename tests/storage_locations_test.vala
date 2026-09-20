using GLib;

namespace HolderLinuxTests {

private HolderLinux.StorageLocationDraft local_draft(string name, string path) {
    return new HolderLinux.StorageLocationDraft(false, name, path, "", "", "", "", "", "", "");
}

private HolderLinux.StorageLocationDraft s3_draft(string name = "S3",
                                                  string endpoint = "https://s3.example.com",
                                                  string region = "us-east-1",
                                                  string bucket = "bucket",
                                                  string access_key = "AKIA",
                                                  string secret_key = "secret",
                                                  string session_token = "") {
    return new HolderLinux.StorageLocationDraft(
        true, name, "", endpoint, region, bucket, " prefix/ ", access_key, secret_key, session_token
    );
}

private void test_local_draft_validation_and_spec() {
    assert(local_draft("Assets", "/data").can_save());
    assert(local_draft("  ", "/data").validation_error() == "A storage location name is required.");
    assert(local_draft("Assets", "  ").validation_error() == "Choose a storage folder.");
    assert(!local_draft("Assets", "").can_save());

    var draft = local_draft("  Assets ", "  /data/assets  ");
    assert(draft.location_name == "Assets");
    var spec = draft.build_spec();
    assert(spec.provider == "local_directory");
    assert(spec.configuration.size == 0);
    assert(spec.values.get("root_path") == "/data/assets");
    assert(spec.preview == "/data/assets");
}

private void test_s3_draft_validation() {
    assert(s3_draft().can_save());
    assert(s3_draft("").validation_error() == "A storage location name is required.");
    string required = "Endpoint, region, bucket and credentials are required.";
    assert(s3_draft("S3", " ").validation_error() == required);
    assert(s3_draft("S3", "e", " ").validation_error() == required);
    assert(s3_draft("S3", "e", "r", " ").validation_error() == required);
    assert(s3_draft("S3", "e", "r", "b", " ").validation_error() == required);
    assert(s3_draft("S3", "e", "r", "b", "k", "").validation_error() == required);
    assert(s3_draft("S3", "e", "r", "b", "k", "   ").can_save());
}

private void test_s3_draft_spec_strips_fields_but_not_secrets() {
    var spec = s3_draft("S3", " https://s3.example.com ", " us-east-1 ", " bucket ", " AKIA ", " secret ", "token").build_spec();
    assert(spec.provider == "s3_compatible");
    assert(spec.configuration.get("endpoint") == "https://s3.example.com");
    assert(spec.configuration.get("region") == "us-east-1");
    assert(spec.configuration.get("bucket") == "bucket");
    assert(spec.configuration.get("prefix") == "prefix/");
    assert(spec.configuration.get("addressing_style") == "path");
    assert(spec.values.get("access_key_id") == "AKIA");
    assert(spec.values.get("secret_access_key") == " secret ");
    assert(spec.values.get("session_token") == "token");
    assert(spec.preview == "https://s3.example.com / bucket");

    var without_token = s3_draft().build_spec();
    assert(!without_token.values.has_key("session_token"));
}

private void test_presenter_provider_labels() {
    assert(HolderLinux.StorageLocationPresenter.provider_label("local_directory") == "Local folder");
    assert(HolderLinux.StorageLocationPresenter.provider_label("google-drive") == "Google Drive");
    assert(HolderLinux.StorageLocationPresenter.provider_label("s3_compatible") == "S3-compatible storage");
}

private void test_presenter_row_states() {
    var preferred = HolderLinux.StorageLocationPresenter.row(
        make_location("l1", "local_directory", true, "/data", "Assets"), "l1"
    );
    assert(preferred.title == "Assets");
    assert(preferred.summary == "Local folder · /data");
    assert(preferred.is_preferred);
    assert(!preferred.offers_use_by_default);
    assert(preferred.test_enabled);

    var bound = HolderLinux.StorageLocationPresenter.row(make_location("l2", "s3_compatible", true, "e / b"), "l1");
    assert(!bound.is_preferred);
    assert(bound.offers_use_by_default);
    assert(bound.test_enabled);

    var unbound = HolderLinux.StorageLocationPresenter.row(make_location("l3", "google-drive", false), null);
    assert(unbound.summary == "Google Drive · Configuration required");
    assert(!unbound.is_preferred);
    assert(!unbound.offers_use_by_default);
    assert(!unbound.test_enabled);
}

private HolderLinux.StorageLocationsRefreshResult run_refresh(HolderLinux.IResourceStorageApi? api,
                                                              HolderLinux.Project? project) {
    var controller = new HolderLinux.StorageLocationsController();
    HolderLinux.StorageLocationsRefreshResult? result = null;
    controller.refresh_flow.begin(api, project, (obj, res) => {
        result = controller.refresh_flow.end(res);
    });
    assert(wait_for_condition(() => result != null));
    return (!) result;
}

private void test_refresh_flow_states() {
    var project = new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 10, 10);
    var api = new FakeStorageLocationApi();

    var no_project = run_refresh(api, null);
    assert(!no_project.success && !no_project.has_error);
    assert(no_project.empty_visible);
    assert(no_project.empty_text == HolderLinux.StorageLocationsController.EMPTY_TEXT);
    var no_api = run_refresh(null, project);
    assert(!no_api.success && no_api.empty_visible);
    assert(api.list_calls == 0);

    api.list_responses.add(make_location_list({}));
    var empty = run_refresh(api, project);
    assert(empty.success && empty.empty_visible);
    assert(empty.empty_text == HolderLinux.StorageLocationsController.EMPTY_TEXT);

    api.list_calls = 0;
    api.list_responses.clear();
    api.list_responses.add(make_location_list({ make_location("l1", "local_directory", true) }, "l1"));
    var loaded = run_refresh(api, project);
    assert(loaded.success && !loaded.empty_visible);
    assert(loaded.locations.size == 1);
    assert(loaded.preferred_location_id == "l1");

    api.list_error = "offline";
    var failed = run_refresh(api, project);
    assert(!failed.success && failed.has_error && failed.empty_visible);
    assert(failed.empty_text == HolderLinux.StorageLocationsController.LOAD_FAILED_TEXT);
    assert(failed.error_title == "Storage Locations refresh failed");
    assert(failed.error_details == "offline");
}

private void test_create_and_bind_flow() {
    var controller = new HolderLinux.StorageLocationsController();
    var spec = local_draft("Assets", "/data").build_spec();

    var api = new FakeStorageLocationApi();
    HolderLinux.ResourcesMutationResult? added = null;
    controller.create_and_bind_flow.begin(api, "p1", "Assets", spec, () => { return null; }, (obj, res) => {
        added = controller.create_and_bind_flow.end(res);
    });
    assert(wait_for_condition(() => added != null));
    assert(added.success && added.should_refresh);
    assert(added.toast_message == "Storage location added.");
    assert(api.last_created_name == "Assets");
    assert(api.last_created_provider == "local_directory");
    assert(api.last_bound_location == "new-location");
    assert(api.last_bound_values.get("root_path") == "/data");
    assert(api.last_bound_preview == "/data");
    assert(string.joinv(",", api.calls.to_array()) == "create,bind,prefer:new-location");

    var preferred_api = new FakeStorageLocationApi();
    HolderLinux.ResourcesMutationResult? kept = null;
    controller.create_and_bind_flow.begin(preferred_api, "p1", "Assets", spec, () => { return "existing"; }, (obj, res) => {
        kept = controller.create_and_bind_flow.end(res);
    });
    assert(wait_for_condition(() => kept != null));
    assert(kept.success);
    assert(string.joinv(",", preferred_api.calls.to_array()) == "create,bind");
}

private void test_create_and_bind_flow_failures() {
    var controller = new HolderLinux.StorageLocationsController();
    var spec = local_draft("Assets", "/data").build_spec();

    HolderLinux.ResourcesMutationResult? no_api = null;
    controller.create_and_bind_flow.begin(null, "p1", "Assets", spec, () => { return null; }, (obj, res) => {
        no_api = controller.create_and_bind_flow.end(res);
    });
    assert(wait_for_condition(() => no_api != null));
    assert(no_api.ignored);

    var bind_api = new FakeStorageLocationApi();
    bind_api.bind_error = "bind broke";
    HolderLinux.ResourcesMutationResult? failed = null;
    controller.create_and_bind_flow.begin(bind_api, "p1", "Assets", spec, () => { return null; }, (obj, res) => {
        failed = controller.create_and_bind_flow.end(res);
    });
    assert(wait_for_condition(() => failed != null));
    assert(!failed.success && !failed.ignored);
    assert(failed.error_title == "Failed to add storage location");
    assert(failed.error_details == "bind broke");
    assert(string.joinv(",", bind_api.calls.to_array()) == "create,bind");
}

private void test_simple_location_flows() {
    var controller = new HolderLinux.StorageLocationsController();

    var api = new FakeStorageLocationApi();
    HolderLinux.ResourcesMutationResult? preferred = null;
    controller.prefer_flow.begin(api, "p1", "l1", (obj, res) => { preferred = controller.prefer_flow.end(res); });
    assert(wait_for_condition(() => preferred != null));
    assert(preferred.success && preferred.should_refresh);
    assert(preferred.toast_message == "Preferred storage location updated.");

    HolderLinux.ResourcesMutationResult? tested = null;
    controller.test_flow.begin(api, "l1", (obj, res) => { tested = controller.test_flow.end(res); });
    assert(wait_for_condition(() => tested != null));
    assert(tested.success && !tested.should_refresh);
    assert(tested.toast_message == "Storage location is available.");

    HolderLinux.ResourcesMutationResult? deleted = null;
    controller.delete_flow.begin(api, "l1", (obj, res) => { deleted = controller.delete_flow.end(res); });
    assert(wait_for_condition(() => deleted != null));
    assert(deleted.success && deleted.should_refresh);
    assert(deleted.toast_message == "Storage location removed.");
    assert(string.joinv(",", api.calls.to_array()) == "prefer:l1,test:l1,delete:l1");
}

private void test_simple_location_flow_failures_and_missing_api() {
    var controller = new HolderLinux.StorageLocationsController();
    var api = new FakeStorageLocationApi();
    api.prefer_error = "no prefer";
    api.test_error = "no test";
    api.delete_error = "no delete";

    HolderLinux.ResourcesMutationResult? preferred = null;
    controller.prefer_flow.begin(api, "p1", "l1", (obj, res) => { preferred = controller.prefer_flow.end(res); });
    assert(wait_for_condition(() => preferred != null));
    assert(!preferred.success && preferred.error_title == "Failed to update preferred location");
    assert(preferred.error_details == "no prefer");

    HolderLinux.ResourcesMutationResult? tested = null;
    controller.test_flow.begin(api, "l1", (obj, res) => { tested = controller.test_flow.end(res); });
    assert(wait_for_condition(() => tested != null));
    assert(!tested.success && tested.error_title == "Storage location test failed");
    assert(tested.error_details == "no test");

    HolderLinux.ResourcesMutationResult? deleted = null;
    controller.delete_flow.begin(api, "l1", (obj, res) => { deleted = controller.delete_flow.end(res); });
    assert(wait_for_condition(() => deleted != null));
    assert(!deleted.success && deleted.error_title == "Failed to remove storage location");
    assert(deleted.error_details == "no delete");

    HolderLinux.ResourcesMutationResult? ignored_prefer = null;
    HolderLinux.ResourcesMutationResult? ignored_test = null;
    HolderLinux.ResourcesMutationResult? ignored_delete = null;
    controller.prefer_flow.begin(null, "p1", "l1", (obj, res) => { ignored_prefer = controller.prefer_flow.end(res); });
    controller.test_flow.begin(null, "l1", (obj, res) => { ignored_test = controller.test_flow.end(res); });
    controller.delete_flow.begin(null, "l1", (obj, res) => { ignored_delete = controller.delete_flow.end(res); });
    assert(wait_for_condition(() => ignored_prefer != null && ignored_test != null && ignored_delete != null));
    assert(ignored_prefer.ignored && ignored_test.ignored && ignored_delete.ignored);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/storage-locations/local-draft", test_local_draft_validation_and_spec);
    Test.add_func("/holder/storage-locations/s3-draft-validation", test_s3_draft_validation);
    Test.add_func("/holder/storage-locations/s3-draft-spec", test_s3_draft_spec_strips_fields_but_not_secrets);
    Test.add_func("/holder/storage-locations/provider-labels", test_presenter_provider_labels);
    Test.add_func("/holder/storage-locations/row-states", test_presenter_row_states);
    Test.add_func("/holder/storage-locations/refresh-flow", test_refresh_flow_states);
    Test.add_func("/holder/storage-locations/create-and-bind", test_create_and_bind_flow);
    Test.add_func("/holder/storage-locations/create-and-bind-failures", test_create_and_bind_flow_failures);
    Test.add_func("/holder/storage-locations/simple-flows", test_simple_location_flows);
    Test.add_func("/holder/storage-locations/simple-flow-failures", test_simple_location_flow_failures_and_missing_api);
    return Test.run();
}

}
