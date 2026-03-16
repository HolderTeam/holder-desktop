using GLib;

namespace HolderLinux {

internal class SelectionController : Object {
    public int project_selected_calls = 0;
    public int card_selected_calls = 0;
    public string? last_card_id = null;

    public async void on_project_selected() {
        project_selected_calls++;
    }

    public async void on_card_selected(string card_id) {
        card_selected_calls++;
        last_card_id = card_id;
    }
}

public class MainController : Object {
    public int project_overview_calls = 0;
    public int ai_thread_selected_calls = 0;

    public async void show_project_overview() {
        project_overview_calls++;
    }

    public void on_ai_thread_selected() {
        ai_thread_selected_calls++;
    }
}

public class FlowboardController : Object {
    public int refresh_calls = 0;
    public int focus_card_calls = 0;
    public string? last_focus_card_id = null;

    public void refresh() {
        refresh_calls++;
    }

    public void focus_card(string card_id) {
        focus_card_calls++;
        last_focus_card_id = card_id;
        refresh_calls++;
    }
}

}

private void test_begin_navigation_emits_loading_true() {
    var state = new HolderLinux.AppStateStore();
    var app_transitions = new HolderLinux.AppTransitionController(state);
    var transitions = new HolderLinux.SelectionTransitionController(app_transitions);

    uint loading_true_count = 0;
    transitions.navigation_loading_changed.connect((loading) => {
        if (loading) {
            loading_true_count++;
        }
    });

    var seq = transitions.begin_navigation("test-nav", "p1", "c1", null);

    assert(seq == 1);
    assert(loading_true_count == 1);
    assert(state.transition.in_flight);
    assert(state.transition.reason == "test-nav");
    assert(state.transition.pending_selection.project_id == "p1");
    assert(state.transition.pending_selection.card_id == "c1");
}

private void test_finish_navigation_if_current_ignores_stale() {
    var state = new HolderLinux.AppStateStore();
    var app_transitions = new HolderLinux.AppTransitionController(state);
    var transitions = new HolderLinux.SelectionTransitionController(app_transitions);

    uint loading_false_count = 0;
    transitions.navigation_loading_changed.connect((loading) => {
        if (!loading) {
            loading_false_count++;
        }
    });

    var stale = transitions.begin_navigation("stale", "p1", null, null);
    var current = transitions.begin_navigation("current", "p2", null, null);

    transitions.finish_navigation_if_current(stale);
    assert(state.transition.in_flight);
    assert(state.transition.reason == "current");
    assert(loading_false_count == 0);

    transitions.finish_navigation_if_current(current);
    assert(!state.transition.in_flight);
    assert(state.transition.reason == "");
    assert(loading_false_count == 1);
}

private void test_commit_selection_ignored_for_stale_sequence() {
    var state = new HolderLinux.AppStateStore();
    var app_transitions = new HolderLinux.AppTransitionController(state);
    var transitions = new HolderLinux.SelectionTransitionController(app_transitions);

    var stale = transitions.begin_navigation("stale", "p-stale", "c-stale", null);
    var current = transitions.begin_navigation("current", "p-current", "c-current", null);

    transitions.commit_selection(stale, "p-stale", "c-stale", "t-stale");
    assert(state.selection.project_id == null);
    assert(state.selection.card_id == null);
    assert(state.selection.ai_thread_id == null);

    transitions.commit_selection(current, "p-current", "c-current", "t-current");
    assert(state.selection.project_id == "p-current");
    assert(state.selection.card_id == "c-current");
    assert(state.selection.ai_thread_id == "t-current");
}

private void test_run_methods_cover_transition_paths() {
    var state = new HolderLinux.AppStateStore();
    var app_transitions = new HolderLinux.AppTransitionController(state);
    var transitions = new HolderLinux.SelectionTransitionController(app_transitions);
    var selection_controller = new HolderLinux.SelectionController();
    var main_controller = new HolderLinux.MainController();
    var flowboard_controller = new HolderLinux.FlowboardController();

    {
        var loop = new MainLoop();
        transitions.run_project_selection.begin("p1", selection_controller, flowboard_controller, (obj, res) => {
            transitions.run_project_selection.end(res);
            loop.quit();
        });
        loop.run();
    }
    assert(selection_controller.project_selected_calls == 1);
    assert(flowboard_controller.refresh_calls == 1);
    assert(state.selection.project_id == "p1");
    assert(state.selection.card_id == null);

    {
        var loop = new MainLoop();
        transitions.run_card_selection.begin("p1", "c1", selection_controller, flowboard_controller, (obj, res) => {
            transitions.run_card_selection.end(res);
            loop.quit();
        });
        loop.run();
    }
    assert(selection_controller.card_selected_calls == 1);
    assert(selection_controller.last_card_id == "c1");
    assert(flowboard_controller.focus_card_calls == 1);
    assert(flowboard_controller.last_focus_card_id == "c1");
    assert(state.selection.project_id == "p1");
    assert(state.selection.card_id == "c1");

    {
        var loop = new MainLoop();
        transitions.run_project_overview_selection.begin("p2", main_controller, flowboard_controller, (obj, res) => {
            transitions.run_project_overview_selection.end(res);
            loop.quit();
        });
        loop.run();
    }
    assert(main_controller.project_overview_calls == 1);
    assert(flowboard_controller.refresh_calls == 3);
    assert(state.selection.project_id == "p2");
    assert(state.selection.card_id == null);

    transitions.run_ai_thread_selection("p3", "c3", "t3", main_controller);
    assert(main_controller.ai_thread_selected_calls == 1);
    assert(state.selection.project_id == "p3");
    assert(state.selection.card_id == "c3");
    assert(state.selection.ai_thread_id == "t3");

    {
        var loop = new MainLoop();
        transitions.run_card_open_transition.begin(
            "open-card",
            "p4",
            "c4-pending",
            "p4",
            "c4-selected",
            selection_controller,
            flowboard_controller,
            (obj, res) => {
                transitions.run_card_open_transition.end(res);
                loop.quit();
            }
        );
        loop.run();
    }
    assert(selection_controller.card_selected_calls == 2);
    assert(selection_controller.last_card_id == "c4-selected");
    assert(flowboard_controller.focus_card_calls == 2);
    assert(flowboard_controller.last_focus_card_id == "c4-selected");
    assert(flowboard_controller.refresh_calls == 4);
    assert(state.selection.project_id == "p4");
    assert(state.selection.card_id == "c4-selected");
    assert(state.selection.ai_thread_id == null);
}

private void test_flowboard_open_transition_does_not_reset_flowboard_level() {
    var state = new HolderLinux.AppStateStore();
    var app_transitions = new HolderLinux.AppTransitionController(state);
    var transitions = new HolderLinux.SelectionTransitionController(app_transitions);
    var selection_controller = new HolderLinux.SelectionController();
    var flowboard_controller = new HolderLinux.FlowboardController();

    var loop = new MainLoop();
    transitions.run_card_open_transition.begin(
        "toolbox-flowboard-card-open",
        "p1",
        "c1",
        "p1",
        "c1",
        selection_controller,
        flowboard_controller,
        (obj, res) => {
            transitions.run_card_open_transition.end(res);
            loop.quit();
        }
    );
    loop.run();

    assert(selection_controller.card_selected_calls == 1);
    assert(selection_controller.last_card_id == "c1");
    assert(flowboard_controller.focus_card_calls == 0);
    assert(state.selection.project_id == "p1");
    assert(state.selection.card_id == "c1");
}

public int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/selection_transition/begin_navigation_emits_loading_true",
                  test_begin_navigation_emits_loading_true);
    Test.add_func("/selection_transition/finish_navigation_if_current_ignores_stale",
                  test_finish_navigation_if_current_ignores_stale);
    Test.add_func("/selection_transition/commit_selection_ignored_for_stale_sequence",
                  test_commit_selection_ignored_for_stale_sequence);
    Test.add_func("/selection_transition/run_methods_cover_transition_paths",
                  test_run_methods_cover_transition_paths);
    Test.add_func("/selection_transition/flowboard_open_transition_does_not_reset_flowboard_level",
                  test_flowboard_open_transition_does_not_reset_flowboard_level);

    return Test.run();
}
