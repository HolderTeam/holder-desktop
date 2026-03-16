using GLib;

namespace HolderLinux {

internal class SelectionIntentOrchestrator : Object {
    public int project_selection_requested_calls = 0;
    public string? last_project_id = null;
    public string delayed_project_id = "";
    public uint delay_ms = 0;

    public async void on_project_selection_requested(string project_id) {
        project_selection_requested_calls++;
        last_project_id = project_id;
        if (delay_ms > 0 && project_id == delayed_project_id) {
            SourceFunc resume = on_project_selection_requested.callback;
            Timeout.add(delay_ms, () => {
                resume();
                return Source.REMOVE;
            });
            yield;
        }
    }
}

public class ToolboxPane : Object {
    public int show_flowboard_projects_root_calls = 0;
    public int show_flowboard_project_root_calls = 0;
    public int show_connections_projects_root_calls = 0;

    public void show_flowboard_projects_root() {
        show_flowboard_projects_root_calls++;
    }

    public void show_flowboard_project_root() {
        show_flowboard_project_root_calls++;
    }

    public void show_connections_projects_root() {
        show_connections_projects_root_calls++;
    }
}

}

namespace HolderLinuxTests {

private delegate bool ConditionFunc();

private bool wait_for_condition(ConditionFunc condition, uint timeout_ms = 1500) {
    var loop = new MainLoop();
    uint timeout_id = 0;
    uint poll_id = 0;
    bool ok = false;

    poll_id = Timeout.add(10, () => {
        if (condition()) {
            ok = true;
            poll_id = 0;
            loop.quit();
            return Source.REMOVE;
        }
        return Source.CONTINUE;
    });
    timeout_id = Timeout.add(timeout_ms, () => {
        timeout_id = 0;
        loop.quit();
        return Source.REMOVE;
    });

    loop.run();
    if (timeout_id != 0) {
        Source.remove(timeout_id);
    }
    if (poll_id != 0) {
        Source.remove(poll_id);
    }
    return ok;
}

private void run_navigate(HolderLinux.ToolboxBreadcrumbController controller,
                          string tool_id,
                          int segment_index,
                          string? project_id,
                          string? card_id,
                          HolderLinux.ToolboxBreadcrumbController.OpenCardFunc open_card,
                          HolderLinux.ToolboxBreadcrumbController.ShowToolHelpFunc show_tool_help) {
    bool done = false;
    controller.navigate.begin(tool_id, segment_index, project_id, card_id, open_card, show_tool_help,
        (obj, res) => {
            controller.navigate.end(res);
            done = true;
        });
    assert(wait_for_condition(() => done));
}

private void test_segment_zero_flowboard_shows_projects_root_and_help() {
    var intents = new HolderLinux.SelectionIntentOrchestrator();
    var toolbox = new HolderLinux.ToolboxPane();
    var controller = new HolderLinux.ToolboxBreadcrumbController(intents, toolbox);

    int open_calls = 0;
    int help_calls = 0;

    run_navigate(controller, "flowboard", 0, "p1", "c1", (card_id) => {
        open_calls++;
    }, (tool_id) => {
        help_calls++;
    });

    assert(toolbox.show_flowboard_projects_root_calls == 1);
    assert(toolbox.show_flowboard_project_root_calls == 0);
    assert(help_calls == 1);
    assert(open_calls == 0);
}

private void test_segment_zero_non_flowboard_shows_help() {
    var intents = new HolderLinux.SelectionIntentOrchestrator();
    var toolbox = new HolderLinux.ToolboxPane();
    var controller = new HolderLinux.ToolboxBreadcrumbController(intents, toolbox);

    int open_calls = 0;
    int help_calls = 0;
    string? last_help_tool = null;

    run_navigate(controller, "connections", 0, "p1", "c1", (card_id) => {
        open_calls++;
    }, (tool_id) => {
        help_calls++;
        last_help_tool = tool_id;
    });

    assert(toolbox.show_flowboard_projects_root_calls == 0);
    assert(toolbox.show_connections_projects_root_calls == 1);
    assert(help_calls == 1);
    assert(last_help_tool == "connections");
    assert(open_calls == 0);
}

private void test_segment_one_requires_project_id() {
    var intents = new HolderLinux.SelectionIntentOrchestrator();
    var toolbox = new HolderLinux.ToolboxPane();
    var controller = new HolderLinux.ToolboxBreadcrumbController(intents, toolbox);

    int open_calls = 0;
    int help_calls = 0;

    run_navigate(controller, "flowboard", 1, "", null, (card_id) => {
        open_calls++;
    }, (tool_id) => {
        help_calls++;
    });

    assert(intents.project_selection_requested_calls == 0);
    assert(toolbox.show_flowboard_project_root_calls == 0);
    assert(help_calls == 0);
    assert(open_calls == 0);
}

private void test_segment_one_flowboard_selects_project_and_shows_project_root() {
    var intents = new HolderLinux.SelectionIntentOrchestrator();
    var toolbox = new HolderLinux.ToolboxPane();
    var controller = new HolderLinux.ToolboxBreadcrumbController(intents, toolbox);

    int open_calls = 0;
    int help_calls = 0;

    run_navigate(controller, "flowboard", 1, "p1", null, (card_id) => {
        open_calls++;
    }, (tool_id) => {
        help_calls++;
    });

    assert(intents.project_selection_requested_calls == 1);
    assert(intents.last_project_id == "p1");
    assert(toolbox.show_flowboard_project_root_calls == 1);
    assert(help_calls == 0);
    assert(open_calls == 0);
}

private void test_segment_two_opens_card_for_supported_tools() {
    var intents = new HolderLinux.SelectionIntentOrchestrator();
    var toolbox = new HolderLinux.ToolboxPane();
    var controller = new HolderLinux.ToolboxBreadcrumbController(intents, toolbox);

    int open_calls = 0;
    string? last_opened = null;

    run_navigate(controller, "flowboard", 2, null, "c-flow", (card_id) => {
        open_calls++;
        last_opened = card_id;
    }, (tool_id) => {});

    run_navigate(controller, "connections", 2, null, "c-conn", (card_id) => {
        open_calls++;
        last_opened = card_id;
    }, (tool_id) => {});

    assert(open_calls == 2);
    assert(last_opened == "c-conn");
}

private void test_segment_two_ignores_empty_or_unsupported() {
    var intents = new HolderLinux.SelectionIntentOrchestrator();
    var toolbox = new HolderLinux.ToolboxPane();
    var controller = new HolderLinux.ToolboxBreadcrumbController(intents, toolbox);

    int open_calls = 0;

    run_navigate(controller, "flowboard", 2, null, "", (card_id) => {
        open_calls++;
    }, (tool_id) => {});

    run_navigate(controller, "trash", 2, null, "c1", (card_id) => {
        open_calls++;
    }, (tool_id) => {});

    assert(open_calls == 0);
}

private void test_stale_segment_one_response_is_ignored() {
    var intents = new HolderLinux.SelectionIntentOrchestrator();
    intents.delayed_project_id = "slow";
    intents.delay_ms = 50;
    var toolbox = new HolderLinux.ToolboxPane();
    var controller = new HolderLinux.ToolboxBreadcrumbController(intents, toolbox);

    bool slow_done = false;
    controller.navigate.begin("flowboard", 1, "slow", null, (card_id) => {}, (tool_id) => {},
        (obj, res) => {
            controller.navigate.end(res);
            slow_done = true;
        });

    int help_calls = 0;
    run_navigate(controller, "flowboard", 0, "p1", null, (card_id) => {}, (tool_id) => {
        help_calls++;
    });

    assert(wait_for_condition(() => slow_done));
    assert(help_calls == 1);
    assert(toolbox.show_flowboard_projects_root_calls == 1);
    assert(toolbox.show_flowboard_project_root_calls == 0);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/holder/toolbox-breadcrumb/segment-zero-flowboard-projects-root-and-help",
                  test_segment_zero_flowboard_shows_projects_root_and_help);
    Test.add_func("/holder/toolbox-breadcrumb/segment-zero-non-flowboard-help",
                  test_segment_zero_non_flowboard_shows_help);
    Test.add_func("/holder/toolbox-breadcrumb/segment-one-requires-project",
                  test_segment_one_requires_project_id);
    Test.add_func("/holder/toolbox-breadcrumb/segment-one-flowboard-project-root",
                  test_segment_one_flowboard_selects_project_and_shows_project_root);
    Test.add_func("/holder/toolbox-breadcrumb/segment-two-supported-tools",
                  test_segment_two_opens_card_for_supported_tools);
    Test.add_func("/holder/toolbox-breadcrumb/segment-two-empty-or-unsupported",
                  test_segment_two_ignores_empty_or_unsupported);
    Test.add_func("/holder/toolbox-breadcrumb/stale-segment-one-response-ignored",
                  test_stale_segment_one_response_is_ignored);

    return Test.run();
}

}
