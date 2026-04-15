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
    assert(text.contains("- `none`"));

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
    assert(text.contains("## Local Models"));
    assert(text.contains("- `none`"));
    assert(logger.lines.size >= 2);
}

private void test_local_info_ai_capabilities_failure_marks_models_unavailable() {
    var api = new MainControllerFakeApi();
    api.fail_ai_capabilities = true;
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
    assert(text.contains("## Local Models"));
    assert(text.contains("- `unavailable`"));
    assert(logger.lines.size >= 1);
    assert(logger.lines[0].contains("failed to load AI capabilities"));
}

private void test_local_info_lists_available_local_models() {
    var api = new MainControllerFakeApi();
    api.ai_capability_models.add("phi4");
    api.ai_capability_models.add("qwen3:4b");
    var local_info = new HolderLinux.LocalInfoController();

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
    assert(text.contains("- `phi4`"));
    assert(text.contains("- `qwen3:4b`"));
    assert(!text.contains("- `none`"));
}

private void test_local_info_includes_sync_status_times_and_errors_for_remote_projects() {
    var api = new MainControllerFakeApi();
    var local_info = new HolderLinux.LocalInfoController();

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
    assert(text.contains("## Sync"));
    assert(text.contains("- Project 1: push `pushed`"));
    assert(text.contains("uncommitted `2`"));
    assert(text.contains("unpushed `3`"));
    assert(text.contains("push_retry `4`"));
    assert(text.contains("pull_retry `5`"));
    assert(text.contains("error: `last sync failed`"));
    assert(!text.contains("no project remote repository set"));
    assert(!text.contains("push `unknown`"));
    assert(!text.contains("next `never`"));
}

private void test_local_info_uses_unknown_push_status_and_never_retry_times_when_sync_fields_are_blank() {
    var api = new MainControllerFakeApi();
    api.blank_project_sync_status = true;
    api.omit_project_sync_retry_times = true;
    var local_info = new HolderLinux.LocalInfoController();

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
    assert(text.contains("- Project 1: push `unknown`"));
    assert(text.contains("push_retry `4` (next `never`)"));
    assert(text.contains("pull_retry `5` (next `never`)"));
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
    Test.add_func("/local_info/ai_capabilities_failure_marks_models_unavailable",
                  test_local_info_ai_capabilities_failure_marks_models_unavailable);
    Test.add_func("/local_info/lists_available_local_models",
                  test_local_info_lists_available_local_models);
    Test.add_func("/local_info/includes_sync_status_times_and_errors_for_remote_projects",
                  test_local_info_includes_sync_status_times_and_errors_for_remote_projects);
    Test.add_func("/local_info/uses_unknown_push_status_and_never_retry_times_when_sync_fields_are_blank",
                  test_local_info_uses_unknown_push_status_and_never_retry_times_when_sync_fields_are_blank);
    Test.add_func("/local_info/propagates_health_error",
                  test_local_info_propagates_health_error);

    return Test.run();
}

}
