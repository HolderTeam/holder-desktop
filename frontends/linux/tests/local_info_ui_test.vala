using GLib;

namespace HolderLinux {

public interface IHolderApi : Object {
}

internal errordomain TestLocalInfoError {
    FAILED
}

public class LocalInfoController : Object {
    public string markdown_result = "";
    public Error? markdown_error = null;
    public int build_calls = 0;

    public async string build_local_info_markdown(IHolderApi api) throws Error {
        build_calls++;
        if (markdown_error != null) {
            throw markdown_error;
        }
        return markdown_result;
    }
}

public class LocalInfoViewAdapter : Object {
    public int render_not_connected_calls = 0;
    public int render_success_calls = 0;
    public int render_failure_calls = 0;
    public string last_markdown = "";
    public string last_error = "";

    public void render_not_connected() {
        render_not_connected_calls++;
    }

    public void render_success(string markdown) {
        render_success_calls++;
        last_markdown = markdown;
    }

    public void render_failure(string details) {
        render_failure_calls++;
        last_error = details;
    }
}

}

namespace HolderLinux.Tests {

private class BoolFlag : Object {
    public bool value = false;
}

private class FakeHolderApi : Object, HolderLinux.IHolderApi {
}

private class FakeLocalInfoFlowContext : Object, HolderLinux.ILocalInfoFlowContext {
    public HolderLinux.IHolderApi? api;

    public HolderLinux.IHolderApi? get_api_client() {
        return api;
    }
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

private void test_show_page_renders_not_connected() {
    var context = new FakeLocalInfoFlowContext();
    var local_info_controller = new HolderLinux.LocalInfoController();
    var flow = new HolderLinux.LocalInfoFlowController(context, local_info_controller);
    var view = new HolderLinux.LocalInfoViewAdapter();
    var controller = new HolderLinux.LocalInfoUiController(flow, view);
    var done = new BoolFlag();

    controller.show_page.begin((obj, res) => {
        controller.show_page.end(res);
        done.value = true;
    });
    wait_for_bool(done);

    assert(local_info_controller.build_calls == 0);
    assert(view.render_not_connected_calls == 1);
    assert(view.render_success_calls == 0);
    assert(view.render_failure_calls == 0);
}

private void test_show_page_renders_success_and_failure() {
    var context = new FakeLocalInfoFlowContext();
    context.api = new FakeHolderApi();
    var local_info_controller = new HolderLinux.LocalInfoController();
    var flow = new HolderLinux.LocalInfoFlowController(context, local_info_controller);
    var view = new HolderLinux.LocalInfoViewAdapter();
    var controller = new HolderLinux.LocalInfoUiController(flow, view);

    local_info_controller.markdown_result = "markdown";
    var success_done = new BoolFlag();
    controller.show_page.begin((obj, res) => {
        controller.show_page.end(res);
        success_done.value = true;
    });
    wait_for_bool(success_done);
    assert(view.render_success_calls == 1);
    assert(view.last_markdown == "markdown");

    local_info_controller.markdown_error = new HolderLinux.TestLocalInfoError.FAILED("broken");
    var failure_done = new BoolFlag();
    controller.show_page.begin((obj, res) => {
        controller.show_page.end(res);
        failure_done.value = true;
    });
    wait_for_bool(failure_done);
    assert(view.render_failure_calls == 1);
    assert(view.last_error == "broken");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/local-info-ui/show-page-renders-not-connected", test_show_page_renders_not_connected);
    Test.add_func("/holder/local-info-ui/show-page-renders-success-and-failure", test_show_page_renders_success_and_failure);
    return Test.run();
}

}
