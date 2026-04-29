using GLib;

namespace HolderLinuxTests {

private Gtk.SingleSelection project_selection_with_one() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    store.append(new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 10, 10));
    var selection = new Gtk.SingleSelection(store);
    selection.set_selected(0);
    return selection;
}

private HolderLinux.ProjectResource resource(string id,
                                             string kind,
                                             string uri,
                                             string label,
                                             string? desc = null) {
    return new HolderLinux.ProjectResource(id, "p1", kind, uri, label, desc, 1700000000, 1700000100);
}

private void test_refresh_without_project_shows_select_message() {
    var api = new MainControllerFakeApi();
    var view = new HolderLinux.ResourcesToolView();
    view.set_api_client(api);

    assert(wait_for_condition(() => view.empty_visible_for_tests()));
    assert(view.empty_text_for_tests() == "Select a project to view resources.");
    assert(view.item_count_for_tests() == 0);
    assert(!view.open_sensitive_for_tests());
    assert(api.list_resources_calls == 0);
}

private void test_refresh_with_resources_updates_list_and_selection_actions() {
    var api = new MainControllerFakeApi();
    api.resources.add(resource("r1", "url", "https://example.test", "Example", "Docs"));
    api.resources.add(resource("r2", "repo", "git@example.test:holder.git", "Holder repo"));

    var view = new HolderLinux.ResourcesToolView();
    view.set_api_client(api);
    view.set_project_selection(project_selection_with_one());

    assert(wait_for_condition(() => view.item_count_for_tests() == 2));
    assert(!view.empty_visible_for_tests());
    assert(api.last_resource_project_id == "p1");
    assert(!view.open_sensitive_for_tests());

    view.select_index_for_tests(0);
    assert(wait_for_condition(() => view.open_sensitive_for_tests()));
    assert(view.edit_sensitive_for_tests());
    assert(view.delete_sensitive_for_tests());
}

private void test_filter_updates_visible_resources_and_empty_message() {
    var api = new MainControllerFakeApi();
    api.resources.add(resource("r1", "url", "https://example.test", "Example", "Docs"));
    api.resources.add(resource("r2", "repo", "git@example.test:holder.git", "Holder repo"));

    var view = new HolderLinux.ResourcesToolView();
    view.set_api_client(api);
    view.set_project_selection(project_selection_with_one());
    assert(wait_for_condition(() => view.item_count_for_tests() == 2));

    view.set_filter_text_for_tests("repo");
    assert(wait_for_condition(() => view.item_count_for_tests() == 1));
    assert(!view.empty_visible_for_tests());

    view.set_filter_text_for_tests("missing");
    assert(wait_for_condition(() => view.empty_visible_for_tests()));
    assert(view.item_count_for_tests() == 0);
    assert(view.empty_text_for_tests() == "No resources match this filter.");
}

private void test_refresh_failure_reports_error_and_empty_state() {
    var api = new MainControllerFakeApi();
    api.fail_list_resources = true;
    api.list_resources_failure_message = "boom";

    var view = new HolderLinux.ResourcesToolView();
    string error_title = "";
    string error_details = "";
    view.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });
    view.set_api_client(api);
    view.set_project_selection(project_selection_with_one());

    assert(wait_for_condition(() => error_title == "Resources refresh failed"));
    assert(error_details == "boom");
    assert(view.empty_visible_for_tests());
    assert(view.empty_text_for_tests() == "Failed to load resources.");
    assert(view.item_count_for_tests() == 0);
}

private void test_refresh_failure_after_committed_resources_preserves_visible_list() {
    var api = new MainControllerFakeApi();
    api.resources.add(resource("r1", "url", "https://example.test", "Example"));

    var view = new HolderLinux.ResourcesToolView();
    view.set_api_client(api);
    view.set_project_selection(project_selection_with_one());
    assert(wait_for_condition(() => view.item_count_for_tests() == 1));

    string error_title = "";
    view.error_reported.connect((title, details) => {
        error_title = title;
    });
    api.fail_list_resources = true;

    bool done = false;
    view.navigate_to_project_root.begin("p1", (obj, res) => {
        view.navigate_to_project_root.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done && error_title == "Resources refresh failed"));
    assert(view.item_count_for_tests() == 1);
    assert(!view.empty_visible_for_tests());
}

private void test_mutations_call_api_emit_feedback_and_refresh() {
    var api = new MainControllerFakeApi();
    api.resources.add(resource("r1", "url", "https://example.test", "Example"));

    var view = new HolderLinux.ResourcesToolView();
    string last_toast = "";
    string last_activity = "";
    view.toast_requested.connect((message) => {
        last_toast = message;
    });
    view.activity_requested.connect((kind, message, project_id, resource_id, details) => {
        last_activity = kind;
    });
    view.set_api_client(api);
    view.set_project_selection(project_selection_with_one());
    assert(wait_for_condition(() => api.list_resources_calls > 0));

    bool create_done = false;
    view.create_resource_for_tests.begin("p1", "url", "https://new.test", "New", "desc", (obj, res) => {
        view.create_resource_for_tests.end(res);
        create_done = true;
    });
    assert(wait_for_condition(() => create_done));
    assert(api.create_resource_calls == 1);
    assert(api.last_resource_project_id == "p1");
    assert(api.last_resource_kind == "url");
    assert(api.last_resource_uri == "https://new.test");
    assert(api.last_resource_label == "New");
    assert(api.last_resource_desc == "desc");
    assert(last_toast == "Resource added.");
    assert(last_activity == "result.resource.create");

    bool update_done = false;
    view.update_resource_for_tests.begin("r1", "repo", "git@example.test:new.git", "Repo", null, (obj, res) => {
        view.update_resource_for_tests.end(res);
        update_done = true;
    });
    assert(wait_for_condition(() => update_done));
    assert(api.update_resource_calls == 1);
    assert(api.last_resource_id == "r1");
    assert(api.last_resource_kind == "repo");
    assert(api.last_resource_label == "Repo");
    assert(last_toast == "Resource updated.");
    assert(last_activity == "result.resource.update");

    view.select_index_for_tests(0);
    bool delete_done = false;
    view.delete_resource_for_tests.begin("r1", (obj, res) => {
        view.delete_resource_for_tests.end(res);
        delete_done = true;
    });
    assert(wait_for_condition(() => delete_done));
    assert(api.delete_resource_calls == 1);
    assert(api.last_resource_id == "r1");
    assert(last_toast == "Resource deleted.");
    assert(last_activity == "result.resource.delete");
}

private void test_mutation_failure_reports_error() {
    var api = new MainControllerFakeApi();
    api.fail_update_resource = true;

    var view = new HolderLinux.ResourcesToolView();
    string error_title = "";
    string error_details = "";
    view.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });
    view.set_api_client(api);
    view.set_project_selection(project_selection_with_one());
    assert(wait_for_condition(() => api.list_resources_calls > 0));

    bool done = false;
    view.update_resource_for_tests.begin("r1", "url", "https://bad.test", "Bad", null, (obj, res) => {
        view.update_resource_for_tests.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(error_title == "Failed to update resource");
    assert(error_details == "update resource failed");
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping resources tool view tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/holder/resources-view/no-project", test_refresh_without_project_shows_select_message);
    Test.add_func("/holder/resources-view/refresh-with-resources", test_refresh_with_resources_updates_list_and_selection_actions);
    Test.add_func("/holder/resources-view/filter", test_filter_updates_visible_resources_and_empty_message);
    Test.add_func("/holder/resources-view/refresh-failure", test_refresh_failure_reports_error_and_empty_state);
    Test.add_func("/holder/resources-view/refresh-failure-preserves-list",
                  test_refresh_failure_after_committed_resources_preserves_visible_list);
    Test.add_func("/holder/resources-view/mutations", test_mutations_call_api_emit_feedback_and_refresh);
    Test.add_func("/holder/resources-view/mutation-failure", test_mutation_failure_reports_error);
    return Test.run();
}

}
