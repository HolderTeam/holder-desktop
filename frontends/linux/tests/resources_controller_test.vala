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

            controller.create_resource.begin(api, "p-1", "url", "https://example.com", "Example", "desc",
                                             (obj2, res2) => {
                try {
                    controller.create_resource.end(res2);
                    assert(api.create_resource_calls == 1);
                    assert(api.last_resource_kind == "url");

                    controller.update_resource.begin(api, "r-1", "file", "file:///tmp/a.txt", "A", null,
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
    assert(kinds.length == 5);
    assert(kinds[0] == "url");
    assert(kinds[1] == "file");
    assert(kinds[2] == "dir");
    assert(kinds[3] == "repo");
    assert(kinds[4] == "image");
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

    return Test.run();
}
