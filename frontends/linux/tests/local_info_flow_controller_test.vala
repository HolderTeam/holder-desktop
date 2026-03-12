using GLib;

namespace HolderLinuxTests {

private class FakeLocalInfoFlowContext : Object, HolderLinux.ILocalInfoFlowContext {
    public HolderLinux.IHolderApi? api;

    public HolderLinux.IHolderApi? get_api_client() {
        return api;
    }
}

private void test_local_info_flow_not_connected() {
    var context = new FakeLocalInfoFlowContext();
    var local_info = new HolderLinux.LocalInfoController();
    var flow = new HolderLinux.LocalInfoFlowController(context, local_info);

    bool done = false;
    HolderLinux.LocalInfoLoadResult? result = null;
    flow.load.begin((obj, res) => {
        result = flow.load.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(result != null);
    assert(result.state == HolderLinux.LocalInfoLoadState.NOT_CONNECTED);
}

private void test_local_info_flow_success() {
    var context = new FakeLocalInfoFlowContext();
    context.api = new MainControllerFakeApi();
    var local_info = new HolderLinux.LocalInfoController();
    var flow = new HolderLinux.LocalInfoFlowController(context, local_info);

    bool done = false;
    HolderLinux.LocalInfoLoadResult? result = null;
    flow.load.begin((obj, res) => {
        result = flow.load.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(result != null);
    assert(result.state == HolderLinux.LocalInfoLoadState.SUCCESS);
    assert(result.markdown.contains("# Local info"));
}

private void test_local_info_flow_failure() {
    var context = new FakeLocalInfoFlowContext();
    var api = new MainControllerFakeApi();
    api.fail_health = true;
    context.api = api;
    var local_info = new HolderLinux.LocalInfoController();
    var flow = new HolderLinux.LocalInfoFlowController(context, local_info);

    bool done = false;
    HolderLinux.LocalInfoLoadResult? result = null;
    flow.load.begin((obj, res) => {
        result = flow.load.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(result != null);
    assert(result.state == HolderLinux.LocalInfoLoadState.FAILURE);
    assert(result.error_details.contains("health failed"));
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/local_info_flow/not_connected", test_local_info_flow_not_connected);
    Test.add_func("/local_info_flow/success", test_local_info_flow_success);
    Test.add_func("/local_info_flow/failure", test_local_info_flow_failure);

    return Test.run();
}

}
