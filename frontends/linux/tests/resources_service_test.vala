using GLib;

namespace HolderLinuxTests {

private void test_list_resources_forwards_project_id() {
    var api = new MainControllerFakeApi();
    var service = new HolderLinux.ResourcesService();
    bool done = false;

    service.list_resources.begin(api, "p-123", (obj, res) => {
        try {
            var list = service.list_resources.end(res);
            assert(list != null);
            assert(api.list_resources_calls == 1);
            assert(api.last_resource_project_id == "p-123");
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_create_resource_forwards_all_fields() {
    var api = new MainControllerFakeApi();
    var service = new HolderLinux.ResourcesService();
    bool done = false;

    service.create_resource.begin(api, "p-1", "url", "https://example.com", "Example", "desc", (obj, res) => {
        try {
            service.create_resource.end(res);
            assert(api.create_resource_calls == 1);
            assert(api.last_resource_project_id == "p-1");
            assert(api.last_resource_kind == "url");
            assert(api.last_resource_uri == "https://example.com");
            assert(api.last_resource_label == "Example");
            assert(api.last_resource_desc == "desc");
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_update_resource_sets_updated_at() {
    var api = new MainControllerFakeApi();
    var service = new HolderLinux.ResourcesService();
    bool done = false;

    service.update_resource.begin(api, "r-1", "file", "file:///tmp/a.txt", "A", null, (obj, res) => {
        try {
            service.update_resource.end(res);
            assert(api.update_resource_calls == 1);
            assert(api.last_resource_id == "r-1");
            assert(api.last_resource_kind == "file");
            assert(api.last_resource_uri == "file:///tmp/a.txt");
            assert(api.last_resource_label == "A");
            assert(api.last_resource_updated_at > 0);
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_delete_resource_forwards_id() {
    var api = new MainControllerFakeApi();
    var service = new HolderLinux.ResourcesService();
    bool done = false;

    service.delete_resource.begin(api, "r-9", (obj, res) => {
        try {
            service.delete_resource.end(res);
            assert(api.delete_resource_calls == 1);
            assert(api.last_resource_id == "r-9");
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/resources_service/list_resources_forwards_project_id",
                  test_list_resources_forwards_project_id);
    Test.add_func("/resources_service/create_resource_forwards_all_fields",
                  test_create_resource_forwards_all_fields);
    Test.add_func("/resources_service/update_resource_sets_updated_at",
                  test_update_resource_sets_updated_at);
    Test.add_func("/resources_service/delete_resource_forwards_id",
                  test_delete_resource_forwards_id);

    return Test.run();
}

}
