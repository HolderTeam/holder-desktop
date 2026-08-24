using GLib;

private HolderLinux.ProjectResource make_resource(string id,
                                                  string kind,
                                                  string uri,
                                                  string label,
                                                  string? desc = null,
                                                  int64 updated_at = 0) {
    return new HolderLinux.ProjectResource(id, "p1", kind, uri, label, desc, 1, updated_at);
}

private void test_filter_resources_matches_query() {
    var controller = new HolderLinux.ResourcesController();
    var all = new Gee.ArrayList<HolderLinux.ProjectResource>();
    all.add(make_resource("r1", "url", "https://example.com", "Example", "site"));
    all.add(make_resource("r2", "file", "file:///tmp/a.txt", "Local file", null));

    var filtered = controller.filter_resources(all, "example");
    assert(filtered.size == 1);
    assert(filtered[0].resource_id == "r1");
}

private void test_filter_resources_empty_query_returns_all() {
    var controller = new HolderLinux.ResourcesController();
    var all = new Gee.ArrayList<HolderLinux.ProjectResource>();
    all.add(make_resource("r1", "url", "https://example.com", "Example"));
    all.add(make_resource("r2", "file", "file:///tmp/a.txt", "Local file"));

    var filtered = controller.filter_resources(all, "");
    assert(filtered.size == 2);
}

private void test_filter_resources_matches_kind_uri_and_desc() {
    var controller = new HolderLinux.ResourcesController();
    var all = new Gee.ArrayList<HolderLinux.ProjectResource>();
    all.add(make_resource("r1", "repo", "https://git.example.com/a.git", "Alpha", "primary mirror"));
    all.add(make_resource("r2", "file", "file:///tmp/notes.txt", "Notes", "local file"));

    var by_kind = controller.filter_resources(all, "repo");
    assert(by_kind.size == 1);
    assert(by_kind[0].resource_id == "r1");

    var by_uri = controller.filter_resources(all, "notes.txt");
    assert(by_uri.size == 1);
    assert(by_uri[0].resource_id == "r2");

    var by_desc = controller.filter_resources(all, "PRIMARY");
    assert(by_desc.size == 1);
    assert(by_desc[0].resource_id == "r1");
}

private void test_filter_resources_trims_query() {
    var controller = new HolderLinux.ResourcesController();
    var all = new Gee.ArrayList<HolderLinux.ProjectResource>();
    all.add(make_resource("r1", "url", "https://example.com", "Example"));
    all.add(make_resource("r2", "url", "https://other.com", "Other"));

    var filtered = controller.filter_resources(all, "   example   ");
    assert(filtered.size == 1);
    assert(filtered[0].resource_id == "r1");
}

private void test_async_methods_forward_to_api() {
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var controller = new HolderLinux.ResourcesController();
    bool done = false;

    controller.list_resources.begin(api, "p-1", (obj, res) => {
        try {
            var listed = controller.list_resources.end(res);
            assert(listed != null);
            assert(api.list_resources_calls == 1);
            assert(api.last_resource_project_id == "p-1");

            controller.create_resource.begin(api, "p-1", "url", "https://example.com", "Example", "desc", null,
                                             (obj2, res2) => {
                try {
                    controller.create_resource.end(res2);
                    assert(api.create_resource_calls == 1);
                    assert(api.last_resource_kind == "url");

                    controller.update_resource.begin(api, "r-1", "file", "file:///tmp/a.txt", "A", null, null,
                                                     (obj3, res3) => {
                        try {
                            controller.update_resource.end(res3);
                            assert(api.update_resource_calls == 1);
                            assert(api.last_resource_id == "r-1");

                            controller.delete_resource.begin(api, "r-1", (obj4, res4) => {
                                try {
                                    controller.delete_resource.end(res4);
                                    assert(api.delete_resource_calls == 1);
                                    assert(api.last_resource_id == "r-1");
                                } catch (Error e4) {
                                    assert_not_reached();
                                }
                                done = true;
                            });
                        } catch (Error e3) {
                            assert_not_reached();
                        }
                    });
                } catch (Error e2) {
                    assert_not_reached();
                }
            });
        } catch (Error e) {
            assert_not_reached();
        }
    });

    assert(HolderLinuxTests.wait_for_condition(() => done));
}

private void test_format_epoch_outputs_timestamp() {
    var controller = new HolderLinux.ResourcesController();
    var formatted = controller.format_epoch(1710000000);
    assert(formatted.length > 0);
    assert(formatted.contains("-"));
}

private void test_format_epoch_non_positive_is_empty() {
    var controller = new HolderLinux.ResourcesController();
    assert(controller.format_epoch(0) == "");
    assert(controller.format_epoch(-1) == "");
}

private void test_ellipsize_title_caps_length() {
    var controller = new HolderLinux.ResourcesController();
    var in_text = "12345678901234567890123456789012345678901234567890";
    var out_text = controller.ellipsize_title(in_text);
    assert(out_text.length <= 47);
    assert(out_text.has_suffix("..."));
}

private void test_ellipsize_title_short_and_boundary_values() {
    var controller = new HolderLinux.ResourcesController();
    var short_text = "short title";
    assert(controller.ellipsize_title(short_text) == short_text);

    var exact_47 = "12345678901234567890123456789012345678901234567";
    var out_47 = controller.ellipsize_title(exact_47);
    assert(out_47.length == 47);
    assert(out_47.has_suffix("..."));
}

private void test_ellipsize_title_null_returns_empty() {
    var controller = new HolderLinux.ResourcesController();
    assert(controller.ellipsize_title(null) == "");
}

private void test_ellipsize_title_cutoff_negative_returns_original() {
    var controller = new HolderLinux.ResourcesController();
    controller.ellipsize_cutoff_override_for_tests = 500;
    var in_text = "12345678901234567890123456789012345678901234567890";
    var out_text = controller.ellipsize_title(in_text);
    assert(out_text == in_text);
}

private void test_default_resource_kinds_are_stable() {
    var controller = new HolderLinux.ResourcesController();
    var kinds = controller.default_resource_kinds();
    assert(kinds.length == 7);
    assert(kinds[0] == "thing");
    assert(kinds[1] == "document");
    assert(kinds[2] == "image");
    assert(kinds[3] == "person");
    assert(kinds[4] == "organisation");
    assert(kinds[5] == "book");
    assert(kinds[6] == "website");
}

private void test_refresh_resources_flow_project_and_api_preconditions() {
    var controller = new HolderLinux.ResourcesController();
    bool done1 = false;
    HolderLinux.ResourcesRefreshResult? res1 = null;
    controller.refresh_resources_flow.begin(null, null, (obj, res) => {
        res1 = controller.refresh_resources_flow.end(res);
        done1 = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done1));
    assert(res1 != null);
    assert(!res1.success);
    assert(res1.empty_text == "Select a project to view resources.");

    bool done2 = false;
    HolderLinux.ResourcesRefreshResult? res2 = null;
    var project = new HolderLinux.Project("p1", "Project 1", "plain", "/tmp/p1", 1, 1);
    controller.refresh_resources_flow.begin(null, project, (obj, res) => {
        res2 = controller.refresh_resources_flow.end(res);
        done2 = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done2));
    assert(res2 != null);
    assert(!res2.success);
    assert(res2.empty_text == "API unavailable.");
}

private void test_refresh_resources_flow_success_and_error() {
    var controller = new HolderLinux.ResourcesController();
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var project = new HolderLinux.Project("p1", "Project 1", "plain", "/tmp/p1", 1, 1);

    bool done1 = false;
    HolderLinux.ResourcesRefreshResult? res1 = null;
    controller.refresh_resources_flow.begin(api, project, (obj, res) => {
        res1 = controller.refresh_resources_flow.end(res);
        done1 = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done1));
    assert(res1 != null);
    assert(res1.success);
    assert(res1.resources.size == 0);
    assert(api.list_resources_calls == 1);

    api.fail_list_resources = true;
    bool done2 = false;
    HolderLinux.ResourcesRefreshResult? res2 = null;
    controller.refresh_resources_flow.begin(api, project, (obj, res) => {
        res2 = controller.refresh_resources_flow.end(res);
        done2 = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done2));
    assert(res2 != null);
    assert(!res2.success);
    assert(res2.has_error);
    assert(res2.empty_text == "Failed to load resources.");
    assert(res2.error_title == "Resources refresh failed");
}

private void test_apply_resources_filter_flow_empty_texts() {
    var controller = new HolderLinux.ResourcesController();
    var all = new Gee.ArrayList<HolderLinux.ProjectResource>();
    all.add(make_resource("r1", "url", "https://example.com", "Example"));

    var non_empty = controller.apply_resources_filter_flow(all, "example");
    assert(!non_empty.empty);

    var empty_with_query = controller.apply_resources_filter_flow(all, "missing");
    assert(empty_with_query.empty);
    assert(empty_with_query.empty_text == "No resources match this filter.");

    all.clear();
    var empty_no_query = controller.apply_resources_filter_flow(all, "");
    assert(empty_no_query.empty);
    assert(empty_no_query.empty_text == "No resources in this project.");
}

private void test_create_update_delete_resource_flows() {
    var controller = new HolderLinux.ResourcesController();
    var api = new HolderLinuxTests.MainControllerFakeApi();

    bool cdone = false;
    HolderLinux.ResourcesMutationResult? cresult = null;
    controller.create_resource_flow.begin(api, "p1", "url", "https://example.com", "Example", null, null, (obj, res) => {
        cresult = controller.create_resource_flow.end(res);
        cdone = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => cdone));
    assert(cresult != null && cresult.success && cresult.should_refresh);
    assert(cresult.toast_message == "Resource added.");

    bool udone = false;
    HolderLinux.ResourcesMutationResult? uresult = null;
    controller.update_resource_flow.begin(api, "r1", "file", "file:///tmp/a.txt", "A", null, null, (obj, res) => {
        uresult = controller.update_resource_flow.end(res);
        udone = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => udone));
    assert(uresult != null && uresult.success && uresult.should_refresh);
    assert(uresult.toast_message == "Resource updated.");

    bool ddone = false;
    HolderLinux.ResourcesMutationResult? dresult = null;
    controller.delete_resource_flow.begin(api, "r1", (obj, res) => {
        dresult = controller.delete_resource_flow.end(res);
        ddone = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => ddone));
    assert(dresult != null && dresult.success && dresult.should_refresh);
    assert(dresult.toast_message == "Resource deleted.");
}

private void test_resource_flows_ignore_or_error_paths() {
    var controller = new HolderLinux.ResourcesController();

    bool done_ignore = false;
    HolderLinux.ResourcesMutationResult? ignore_result = null;
    controller.create_resource_flow.begin(null, "p1", "url", "u", "l", null, null, (obj, res) => {
        ignore_result = controller.create_resource_flow.end(res);
        done_ignore = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done_ignore));
    assert(ignore_result != null && ignore_result.ignored);

    var api = new HolderLinuxTests.MainControllerFakeApi();
    api.fail_update_resource = true;
    bool done_error = false;
    HolderLinux.ResourcesMutationResult? error_result = null;
    controller.update_resource_flow.begin(api, "r1", "file", "u", "l", null, null, (obj, res) => {
        error_result = controller.update_resource_flow.end(res);
        done_error = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done_error));
    assert(error_result != null && !error_result.success);
    assert(error_result.error_title == "Failed to update resource");
}

private void test_resource_create_flow_failure_reports_activity_and_error() {
    var controller = new HolderLinux.ResourcesController();
    var api = new HolderLinuxTests.MainControllerFakeApi();
    api.fail_create_resource = true;

    string activity_kind = "";
    string activity_message = "";
    controller.activity_requested.connect((kind, message, project_id, resource_id, details) => {
        activity_kind = kind;
        activity_message = message;
    });

    bool done = false;
    HolderLinux.ResourcesMutationResult? result = null;
    controller.create_resource_flow.begin(api, "p1", "url", "https://example.com", "Example", null, null, (obj, res) => {
        result = controller.create_resource_flow.end(res);
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
    assert(result != null);
    assert(!result.success);
    assert(result.error_title == "Failed to create resource");
    assert(activity_kind == "result.resource.create_failed");
    assert(activity_message.contains("Failed to create resource:"));
}

private void test_resource_update_and_delete_ignore_when_api_missing() {
    var controller = new HolderLinux.ResourcesController();

    bool update_done = false;
    HolderLinux.ResourcesMutationResult? update_result = null;
    controller.update_resource_flow.begin(null, "r1", "file", "u", "l", null, null, (obj, res) => {
        update_result = controller.update_resource_flow.end(res);
        update_done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => update_done));
    assert(update_result != null && update_result.ignored);

    bool delete_done = false;
    HolderLinux.ResourcesMutationResult? delete_result = null;
    controller.delete_resource_flow.begin(null, "r1", (obj, res) => {
        delete_result = controller.delete_resource_flow.end(res);
        delete_done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => delete_done));
    assert(delete_result != null && delete_result.ignored);
}

private void test_resource_delete_flow_failure_reports_activity_and_error() {
    var controller = new HolderLinux.ResourcesController();
    var api = new HolderLinuxTests.MainControllerFakeApi();
    api.fail_delete_resource = true;

    string activity_kind = "";
    string activity_message = "";
    controller.activity_requested.connect((kind, message, project_id, resource_id, details) => {
        activity_kind = kind;
        activity_message = message;
    });

    bool done = false;
    HolderLinux.ResourcesMutationResult? result = null;
    controller.delete_resource_flow.begin(api, "r1", (obj, res) => {
        result = controller.delete_resource_flow.end(res);
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
    assert(result != null);
    assert(!result.success);
    assert(result.error_title == "Failed to delete resource");
    assert(activity_kind == "result.resource.delete_failed");
    assert(activity_message.contains("Failed to delete resource:"));
}

private void test_additional_metadata_parses_repeated_values_and_rejects_bad_lines() {
    var controller = new HolderLinux.ResourcesController();
    try {
        var metadata = controller.parse_additional_metadata(
            "creator: Ada Lovelace\ncreator: Grace Hopper\ncustom: value: with colon\n"
        );
        assert(metadata.get("creator").size == 2);
        assert(metadata.get("custom")[0] == "value: with colon");
    } catch (Error e) {
        assert_not_reached();
    }

    bool rejected = false;
    try {
        controller.parse_additional_metadata("not a property line");
    } catch (Error e) {
        rejected = e is IOError.INVALID_ARGUMENT;
    }
    assert(rejected);
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/resources_controller/filter_resources_matches_query",
                  test_filter_resources_matches_query);
    Test.add_func("/resources_controller/filter_resources_empty_query_returns_all",
                  test_filter_resources_empty_query_returns_all);
    Test.add_func("/resources_controller/filter_resources_matches_kind_uri_and_desc",
                  test_filter_resources_matches_kind_uri_and_desc);
    Test.add_func("/resources_controller/filter_resources_trims_query",
                  test_filter_resources_trims_query);
    Test.add_func("/resources_controller/async_methods_forward_to_api",
                  test_async_methods_forward_to_api);
    Test.add_func("/resources_controller/format_epoch_outputs_timestamp",
                  test_format_epoch_outputs_timestamp);
    Test.add_func("/resources_controller/format_epoch_non_positive_is_empty",
                  test_format_epoch_non_positive_is_empty);
    Test.add_func("/resources_controller/ellipsize_title_caps_length",
                  test_ellipsize_title_caps_length);
    Test.add_func("/resources_controller/ellipsize_title_short_and_boundary_values",
                  test_ellipsize_title_short_and_boundary_values);
    Test.add_func("/resources_controller/ellipsize_title_null_returns_empty",
                  test_ellipsize_title_null_returns_empty);
    Test.add_func("/resources_controller/ellipsize_title_cutoff_negative_returns_original",
                  test_ellipsize_title_cutoff_negative_returns_original);
    Test.add_func("/resources_controller/default_resource_kinds_are_stable",
                  test_default_resource_kinds_are_stable);
    Test.add_func("/resources_controller/refresh_resources_flow_project_and_api_preconditions",
                  test_refresh_resources_flow_project_and_api_preconditions);
    Test.add_func("/resources_controller/refresh_resources_flow_success_and_error",
                  test_refresh_resources_flow_success_and_error);
    Test.add_func("/resources_controller/apply_resources_filter_flow_empty_texts",
                  test_apply_resources_filter_flow_empty_texts);
    Test.add_func("/resources_controller/create_update_delete_resource_flows",
                  test_create_update_delete_resource_flows);
    Test.add_func("/resources_controller/resource_flows_ignore_or_error_paths",
                  test_resource_flows_ignore_or_error_paths);
    Test.add_func("/resources_controller/resource_create_flow_failure_reports_activity_and_error",
                  test_resource_create_flow_failure_reports_activity_and_error);
    Test.add_func("/resources_controller/resource_update_and_delete_ignore_when_api_missing",
                  test_resource_update_and_delete_ignore_when_api_missing);
    Test.add_func("/resources_controller/resource_delete_flow_failure_reports_activity_and_error",
                  test_resource_delete_flow_failure_reports_activity_and_error);
    Test.add_func("/resources_controller/additional_metadata_parse",
                  test_additional_metadata_parses_repeated_values_and_rejects_bad_lines);

    return Test.run();
}
