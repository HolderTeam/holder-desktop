using GLib;

namespace HolderLinux {

internal class SelectionController : Object {
    public async void on_project_selected() {}
    public async void on_card_selected(string card_id) {}
}

public class MainController : Object {
    public async void show_project_overview() {}
    public void on_ai_thread_selected() {}
}

public class FlowboardController : Object {
    public void refresh() {}
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

public int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/selection_transition/begin_navigation_emits_loading_true",
                  test_begin_navigation_emits_loading_true);
    Test.add_func("/selection_transition/finish_navigation_if_current_ignores_stale",
                  test_finish_navigation_if_current_ignores_stale);
    Test.add_func("/selection_transition/commit_selection_ignored_for_stale_sequence",
                  test_commit_selection_ignored_for_stale_sequence);

    return Test.run();
}
