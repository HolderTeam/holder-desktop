using GLib;

namespace HolderLinux {

public class CardSummary : Object {
    public string card_id { get; set; }
    public string project_id { get; set; }

    public CardSummary(string card_id, string project_id) {
        this.card_id = card_id;
        this.project_id = project_id;
    }
}

internal class SelectionController : Object {
}

internal class FlowboardController : Object {
}

internal class MainController : Object {
    public string? prepared_search_card_id = null;

    public async string? prepare_search_result_card_at(uint position) {
        return prepared_search_card_id;
    }
}

internal class SelectionTransitionController : Object {
    public int run_project_selection_calls = 0;
    public string? last_project_selection_project_id = null;

    public int run_project_overview_selection_calls = 0;
    public string? last_project_overview_project_id = null;

    public int run_ai_thread_selection_calls = 0;
    public string? last_ai_thread_project_id = null;
    public string? last_ai_thread_card_id = null;
    public string? last_ai_thread_id = null;

    public int run_card_open_transition_calls = 0;
    public string? last_open_reason = null;
    public string? last_open_requested_project_id = null;
    public string? last_open_requested_card_id = null;
    public string? last_open_selected_project_id = null;
    public string? last_open_selected_card_id = null;

    public async void run_project_selection(string? project_id,
                                            SelectionController selection_controller,
                                            FlowboardController flowboard_controller) {
        run_project_selection_calls++;
        last_project_selection_project_id = project_id;
    }

    public async void run_project_overview_selection(string project_id,
                                                     MainController main_controller,
                                                     FlowboardController flowboard_controller) {
        run_project_overview_selection_calls++;
        last_project_overview_project_id = project_id;
    }

    public void run_ai_thread_selection(string? project_id,
                                        string? card_id,
                                        string? thread_id,
                                        MainController controller) {
        run_ai_thread_selection_calls++;
        last_ai_thread_project_id = project_id;
        last_ai_thread_card_id = card_id;
        last_ai_thread_id = thread_id;
    }

    public async void run_card_open_transition(string reason,
                                               string? project_id,
                                               string? card_id,
                                               string selected_project_id,
                                               string selected_card_id,
                                               SelectionController selection_controller,
                                               FlowboardController flowboard_controller) {
        run_card_open_transition_calls++;
        last_open_reason = reason;
        last_open_requested_project_id = project_id;
        last_open_requested_card_id = card_id;
        last_open_selected_project_id = selected_project_id;
        last_open_selected_card_id = selected_card_id;
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

private void test_project_selection_routes_through_transition() {
    var intents = new HolderLinux.SelectionIntentController();
    var transitions = new HolderLinux.SelectionTransitionController();
    var selection = new HolderLinux.SelectionController();
    var flowboard = new HolderLinux.FlowboardController();

    bool done = false;
    intents.on_project_selection.begin("p1", transitions, selection, flowboard, (obj, res) => {
        intents.on_project_selection.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(transitions.run_project_selection_calls == 1);
    assert(transitions.last_project_selection_project_id == "p1");
}

private void test_card_selection_ignores_missing_project() {
    var intents = new HolderLinux.SelectionIntentController();
    var transitions = new HolderLinux.SelectionTransitionController();
    var selection = new HolderLinux.SelectionController();
    var flowboard = new HolderLinux.FlowboardController();
    var controller = new HolderLinux.MainController();

    bool done = false;
    intents.on_card_selection.begin(
        null, "c1", transitions, selection, controller,
        (card_id) => { return new HolderLinux.CardSummary(card_id, "p1"); },
        flowboard,
        (obj, res) => {
        intents.on_card_selection.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(transitions.run_project_overview_selection_calls == 0);
}

private void test_card_selection_without_card_routes_to_project_overview() {
    var intents = new HolderLinux.SelectionIntentController();
    var transitions = new HolderLinux.SelectionTransitionController();
    var selection = new HolderLinux.SelectionController();
    var flowboard = new HolderLinux.FlowboardController();
    var controller = new HolderLinux.MainController();

    bool done = false;
    intents.on_card_selection.begin(
        "p1", null, transitions, selection, controller,
        (card_id) => { return new HolderLinux.CardSummary(card_id, "p1"); },
        flowboard,
        (obj, res) => {
        intents.on_card_selection.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(transitions.run_project_overview_selection_calls == 1);
    assert(transitions.last_project_overview_project_id == "p1");
}

private void test_card_selection_with_card_routes_to_card_transition() {
    var intents = new HolderLinux.SelectionIntentController();
    var transitions = new HolderLinux.SelectionTransitionController();
    var selection = new HolderLinux.SelectionController();
    var flowboard = new HolderLinux.FlowboardController();
    var controller = new HolderLinux.MainController();

    bool done = false;
    intents.on_card_selection.begin(
        "p1", "c1", transitions, selection, controller,
        (card_id) => { return new HolderLinux.CardSummary(card_id, "p1"); },
        flowboard,
        (obj, res) => {
        intents.on_card_selection.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(transitions.run_card_open_transition_calls == 1);
    assert(transitions.last_open_reason == "sidebar-card-selection");
    assert(transitions.last_open_requested_project_id == "p1");
    assert(transitions.last_open_requested_card_id == "c1");
    assert(transitions.last_open_selected_project_id == "p1");
    assert(transitions.last_open_selected_card_id == "c1");
    assert(transitions.run_project_overview_selection_calls == 0);
}

private void test_ai_thread_selection_routes_through_transition() {
    var intents = new HolderLinux.SelectionIntentController();
    var transitions = new HolderLinux.SelectionTransitionController();
    var controller = new HolderLinux.MainController();

    intents.on_ai_thread_selection("t1", "p1", "c1", transitions, controller);

    assert(transitions.run_ai_thread_selection_calls == 1);
    assert(transitions.last_ai_thread_id == "t1");
    assert(transitions.last_ai_thread_project_id == "p1");
    assert(transitions.last_ai_thread_card_id == "c1");
}

private void test_search_activation_routes_through_card_open_transition() {
    var intents = new HolderLinux.SelectionIntentController();
    var transitions = new HolderLinux.SelectionTransitionController();
    var selection = new HolderLinux.SelectionController();
    var flowboard = new HolderLinux.FlowboardController();
    var controller = new HolderLinux.MainController();
    controller.prepared_search_card_id = "c2";

    bool done = false;
    intents.on_search_result_activation.begin(
        0,
        controller,
        (card_id) => {
            return new HolderLinux.CardSummary("c2", "p2");
        },
        transitions,
        selection,
        flowboard,
        (obj, res) => {
            intents.on_search_result_activation.end(res);
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(transitions.run_card_open_transition_calls == 1);
    assert(transitions.last_open_reason == "search-result-activation");
    assert(transitions.last_open_requested_project_id == "p2");
    assert(transitions.last_open_requested_card_id == "c2");
    assert(transitions.last_open_selected_project_id == "p2");
    assert(transitions.last_open_selected_card_id == "c2");
}

private void test_search_activation_ignores_blank_prepared_card_id() {
    var intents = new HolderLinux.SelectionIntentController();
    var transitions = new HolderLinux.SelectionTransitionController();
    var selection = new HolderLinux.SelectionController();
    var flowboard = new HolderLinux.FlowboardController();
    var controller = new HolderLinux.MainController();
    controller.prepared_search_card_id = "   ";

    bool done = false;
    intents.on_search_result_activation.begin(
        0,
        controller,
        (card_id) => {
            return new HolderLinux.CardSummary(card_id, "p2");
        },
        transitions,
        selection,
        flowboard,
        (obj, res) => {
            intents.on_search_result_activation.end(res);
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(transitions.run_card_open_transition_calls == 0);
}

private void test_open_card_with_transition_routes_through_card_open_transition() {
    var intents = new HolderLinux.SelectionIntentController();
    var transitions = new HolderLinux.SelectionTransitionController();
    var selection = new HolderLinux.SelectionController();
    var flowboard = new HolderLinux.FlowboardController();
    var controller = new HolderLinux.MainController();

    bool done = false;
    intents.open_card_with_transition.begin(
        "c3",
        "test-reason",
        controller,
        (card_id) => {
            return new HolderLinux.CardSummary("c3", "p3");
        },
        transitions,
        selection,
        flowboard,
        (obj, res) => {
            intents.open_card_with_transition.end(res);
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(transitions.run_card_open_transition_calls == 1);
    assert(transitions.last_open_reason == "test-reason");
    assert(transitions.last_open_requested_project_id == "p3");
    assert(transitions.last_open_requested_card_id == "c3");
    assert(transitions.last_open_selected_project_id == "p3");
    assert(transitions.last_open_selected_card_id == "c3");
}

private void test_open_card_with_transition_ignores_unknown_card() {
    var intents = new HolderLinux.SelectionIntentController();
    var transitions = new HolderLinux.SelectionTransitionController();
    var selection = new HolderLinux.SelectionController();
    var flowboard = new HolderLinux.FlowboardController();
    var controller = new HolderLinux.MainController();

    bool done = false;
    intents.open_card_with_transition.begin(
        "missing",
        "test-reason",
        controller,
        (card_id) => {
            return null;
        },
        transitions,
        selection,
        flowboard,
        (obj, res) => {
            intents.open_card_with_transition.end(res);
            done = true;
        }
    );

    assert(wait_for_condition(() => done));
    assert(transitions.run_card_open_transition_calls == 0);
}

public int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/selection_intent/project_selection_routes_through_transition",
                  test_project_selection_routes_through_transition);
    Test.add_func("/selection_intent/card_selection_ignores_missing_project",
                  test_card_selection_ignores_missing_project);
    Test.add_func("/selection_intent/card_selection_without_card_routes_to_project_overview",
                  test_card_selection_without_card_routes_to_project_overview);
    Test.add_func("/selection_intent/card_selection_with_card_routes_to_card_transition",
                  test_card_selection_with_card_routes_to_card_transition);
    Test.add_func("/selection_intent/ai_thread_selection_routes_through_transition",
                  test_ai_thread_selection_routes_through_transition);
    Test.add_func("/selection_intent/search_activation_routes_through_card_open_transition",
                  test_search_activation_routes_through_card_open_transition);
    Test.add_func("/selection_intent/search_activation_ignores_blank_prepared_card_id",
                  test_search_activation_ignores_blank_prepared_card_id);
    Test.add_func("/selection_intent/open_card_with_transition_routes_through_card_open_transition",
                  test_open_card_with_transition_routes_through_card_open_transition);
    Test.add_func("/selection_intent/open_card_with_transition_ignores_unknown_card",
                  test_open_card_with_transition_ignores_unknown_card);

    return Test.run();
}

}
