using GLib;

namespace HolderLinux {

public interface IHolderApi : Object {
    public abstract async CardContextData get_card_context(string project_id, string? parent_card_id = null) throws Error;
}

public class CardContextData : Object {
}

public class FlowboardController : Object {
    public int apply_calls = 0;
    public string last_project_id = "";
    public string? last_parent_card_id = null;
    public CardContextData? last_context = null;

    public void apply_card_context(string project_id,
                                   string? parent_card_id,
                                   CardContextData context) {
        apply_calls++;
        last_project_id = project_id;
        last_parent_card_id = parent_card_id;
        last_context = context;
    }
}

internal errordomain TestFlowboardContextError {
    FAILED
}

internal class FakeHolderApi : Object, IHolderApi {
    public CardContextData context = new CardContextData();
    public Error? next_error = null;
    public int get_calls = 0;
    public string last_project_id = "";
    public string? last_parent_card_id = null;

    public async CardContextData get_card_context(string project_id, string? parent_card_id = null) throws Error {
        get_calls++;
        last_project_id = project_id;
        last_parent_card_id = parent_card_id;
        if (next_error != null) {
            throw next_error;
        }
        return context;
    }
}

}

namespace HolderLinux.Tests {

private class BoolFlag : Object {
    public bool value = false;
}

private void wait_for_bool(BoolFlag done) {
    var loop = new MainLoop();
    Timeout.add(10, () => {
        if (done.value) {
            loop.quit();
            return Source.REMOVE;
        }
        return Source.CONTINUE;
    });
    Timeout.add(2000, () => {
        assert_not_reached();
    });
    loop.run();
}

private void test_begin_request_increments_serial() {
    var controller = new HolderLinux.FlowboardContextController();
    assert(controller.begin_request() == 1);
    assert(controller.begin_request() == 2);
}

private void test_load_context_applies_only_latest_successful_request() {
    var api = new HolderLinux.FakeHolderApi();
    var flowboard = new HolderLinux.FlowboardController();
    var controller = new HolderLinux.FlowboardContextController();

    uint stale = controller.begin_request();
    uint latest = controller.begin_request();

    var stale_done = new BoolFlag();
    controller.load_context.begin(stale, "proj-1", "parent-1", api, flowboard, (obj, res) => {
        controller.load_context.end(res);
        stale_done.value = true;
    });
    wait_for_bool(stale_done);
    assert(flowboard.apply_calls == 0);

    var latest_done = new BoolFlag();
    controller.load_context.begin(latest, "proj-1", "parent-2", api, flowboard, (obj, res) => {
        controller.load_context.end(res);
        latest_done.value = true;
    });
    wait_for_bool(latest_done);
    assert(flowboard.apply_calls == 1);
    assert(flowboard.last_project_id == "proj-1");
    assert(flowboard.last_parent_card_id == "parent-2");
    assert(flowboard.last_context == api.context);
}

private void test_load_context_ignores_null_api_and_errors() {
    var flowboard = new HolderLinux.FlowboardController();
    var controller = new HolderLinux.FlowboardContextController();
    uint serial = controller.begin_request();

    var null_done = new BoolFlag();
    controller.load_context.begin(serial, "proj-1", null, null, flowboard, (obj, res) => {
        controller.load_context.end(res);
        null_done.value = true;
    });
    wait_for_bool(null_done);
    assert(flowboard.apply_calls == 0);

    var api = new HolderLinux.FakeHolderApi();
    api.next_error = new HolderLinux.TestFlowboardContextError.FAILED("boom");
    Test.expect_message(null, LogLevelFlags.LEVEL_WARNING, "*Flowboard context load failed for proj-1: boom*");
    var err_done = new BoolFlag();
    controller.load_context.begin(serial, "proj-1", null, api, flowboard, (obj, res) => {
        controller.load_context.end(res);
        err_done.value = true;
    });
    wait_for_bool(err_done);
    Test.assert_expected_messages();
    assert(flowboard.apply_calls == 0);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/flowboard-context/begin-request-increments-serial", test_begin_request_increments_serial);
    Test.add_func("/holder/flowboard-context/load-context-applies-only-latest-successful-request", test_load_context_applies_only_latest_successful_request);
    Test.add_func("/holder/flowboard-context/load-context-ignores-null-api-and-errors", test_load_context_ignores_null_api_and_errors);
    return Test.run();
}

}
