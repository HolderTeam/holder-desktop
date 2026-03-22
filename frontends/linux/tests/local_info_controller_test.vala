using GLib;

namespace HolderLinuxTests {

private class FakeLocalInfoLogger : Object, HolderLinux.ILocalInfoLogger {
    public Gee.ArrayList<string> lines = new Gee.ArrayList<string>();

    public void log_debug(string message) {
        lines.add(message);
    }
}

private void test_local_info_builds_markdown_and_orders_home_first() {
    var api = new MainControllerFakeApi();
    api.include_home_project = true;
    var logger = new FakeLocalInfoLogger();
    var local_info = new HolderLinux.LocalInfoController(logger);

    bool done = false;
    string text = "";
    local_info.build_local_info_markdown.begin(api, (obj, res) => {
        try {
            text = local_info.build_local_info_markdown.end(res);
        } catch (Error e) {
            text = "";
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(text.contains("# Local info"));
    assert(text.contains("## Health"));
    assert(text.contains("## Content"));
    assert(text.contains("## Local Models"));
    assert(text.contains("## Sync"));
    assert(text.contains("- Projects: `2`"));
    assert(text.contains("- Cards: `2`"));
    assert(text.contains("- AI Threads: `2`"));
    assert(text.contains("- Installed models: `none`"));

    var home_idx = text.index_of("- Home:");
    var p1_idx = text.index_of("- Project 1:");
    assert(home_idx >= 0);
    assert(p1_idx >= 0);
    assert(home_idx < p1_idx);
}

private void test_local_info_logs_count_failures_and_continues() {
    var api = new MainControllerFakeApi();
    api.fail_list_cards = true;
    api.fail_list_threads = true;
    var logger = new FakeLocalInfoLogger();
    var local_info = new HolderLinux.LocalInfoController(logger);

    bool done = false;
    string text = "";
    local_info.build_local_info_markdown.begin(api, (obj, res) => {
        try {
            text = local_info.build_local_info_markdown.end(res);
        } catch (Error e) {
            text = "";
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(text.contains("- Cards: `0`"));
    assert(text.contains("- AI Threads: `0`"));
    assert(text.contains("- Installed models: `none`"));
    assert(text.contains("## Local Models"));
    assert(logger.lines.size >= 2);
}

private void test_local_info_propagates_health_error() {
    var api = new MainControllerFakeApi();
    api.fail_health = true;
    var local_info = new HolderLinux.LocalInfoController();

    bool done = false;
    bool got_error = false;
    local_info.build_local_info_markdown.begin(api, (obj, res) => {
        try {
            local_info.build_local_info_markdown.end(res);
        } catch (Error e) {
            got_error = e.message.contains("health failed");
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_error);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/local_info/builds_markdown_and_orders_home_first",
                  test_local_info_builds_markdown_and_orders_home_first);
    Test.add_func("/local_info/logs_count_failures_and_continues",
                  test_local_info_logs_count_failures_and_continues);
    Test.add_func("/local_info/propagates_health_error",
                  test_local_info_propagates_health_error);

    return Test.run();
}

}
