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

private void test_format_epoch_outputs_timestamp() {
    var controller = new HolderLinux.ResourcesController();
    var formatted = controller.format_epoch(1710000000);
    assert(formatted.length > 0);
    assert(formatted.contains("-"));
}

private void test_ellipsize_title_caps_length() {
    var controller = new HolderLinux.ResourcesController();
    var in_text = "12345678901234567890123456789012345678901234567890";
    var out_text = controller.ellipsize_title(in_text);
    assert(out_text.length <= 47);
    assert(out_text.has_suffix("..."));
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/resources_controller/filter_resources_matches_query",
                  test_filter_resources_matches_query);
    Test.add_func("/resources_controller/filter_resources_empty_query_returns_all",
                  test_filter_resources_empty_query_returns_all);
    Test.add_func("/resources_controller/format_epoch_outputs_timestamp",
                  test_format_epoch_outputs_timestamp);
    Test.add_func("/resources_controller/ellipsize_title_caps_length",
                  test_ellipsize_title_caps_length);

    return Test.run();
}
