using GLib;

namespace HolderLinux {

public delegate CardSummary? CardSummaryResolver(string card_id);

public class Project : Object {
    public string project_id { get; set; }
    public string name { get; set; }

    public Project(string project_id, string name) {
        this.project_id = project_id;
        this.name = name;
    }
}

public class CardSummary : Object {
    public string card_id { get; set; }
    public string project_id { get; set; }

    public CardSummary(string card_id, string project_id) {
        this.card_id = card_id;
        this.project_id = project_id;
    }
}

public class AiThreadSummary : Object {
    public string thread_id { get; set; }

    public AiThreadSummary(string thread_id) {
        this.thread_id = thread_id;
    }
}

internal class SelectionTransitionController : Object {
}

internal class SelectionController : Object {
}

internal class FlowboardController : Object {
}

internal class SearchSelectionController : Object {
    public uint mapped_position = Gtk.INVALID_LIST_POSITION;

    public uint position_for_request(int position) {
        return mapped_position != Gtk.INVALID_LIST_POSITION ? mapped_position : (uint) position;
    }
}

internal class MainController : Object {
    public string? selected_project_id_value = null;
    public string? selected_card_id_value = null;

    public string? selected_project_id() {
        return selected_project_id_value;
    }

    public string? selected_card_id() {
        return selected_card_id_value;
    }
}

internal class SelectionIntentController : Object {
    public int on_project_selection_calls = 0;
    public string? last_project_selection_id = null;

    public int on_card_selection_calls = 0;
    public string? last_card_selection_project_id = null;
    public string? last_card_selection_card_id = null;

    public int on_ai_thread_selection_calls = 0;
    public string? last_ai_thread_id = null;
    public string? last_ai_thread_project_id = null;
    public string? last_ai_thread_card_id = null;

    public int on_search_result_activation_calls = 0;
    public uint last_search_activation_position = 0;
    public CardSummary? resolved_search_card = null;

    public int on_project_selection_requested_calls = 0;
    public string? last_project_selection_requested_id = null;

    public int open_card_with_transition_calls = 0;
    public string? last_open_card_id = null;
    public string? last_open_card_reason = null;

    public async void on_project_selection(string? project_id,
                                           SelectionTransitionController transition,
                                           SelectionController selection,
                                           FlowboardController flowboard) {
        on_project_selection_calls++;
        last_project_selection_id = project_id;
        on_project_selection_requested_calls++;
        last_project_selection_requested_id = project_id;
    }

    public async void on_card_selection(string? project_id,
                                        string? card_id,
                                        SelectionTransitionController transition,
                                        SelectionController selection,
                                        MainController controller,
                                        FlowboardController flowboard) {
        on_card_selection_calls++;
        last_card_selection_project_id = project_id;
        last_card_selection_card_id = card_id;
    }

    public void on_ai_thread_selection(string? thread_id,
                                       string? project_id,
                                       string? card_id,
                                       SelectionTransitionController transition,
                                       MainController controller) {
        on_ai_thread_selection_calls++;
        last_ai_thread_id = thread_id;
        last_ai_thread_project_id = project_id;
        last_ai_thread_card_id = card_id;
    }

    public async void on_search_result_activation(uint position,
                                                  MainController controller,
                                                  owned CardSummaryResolver resolve_card_summary_by_id,
                                                  SelectionTransitionController transition,
                                                  SelectionController selection) {
        on_search_result_activation_calls++;
        last_search_activation_position = position;
        resolved_search_card = resolve_card_summary_by_id("c-search");
    }

    public async void open_card_with_transition(string card_id,
                                                string reason,
                                                MainController controller,
                                                owned CardSummaryResolver resolve_card_summary_by_id,
                                                SelectionTransitionController transition,
                                                SelectionController selection) {
        open_card_with_transition_calls++;
        last_open_card_id = card_id;
        last_open_card_reason = reason;
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

private HolderLinux.SelectionIntentOrchestrator make_orchestrator(
    out HolderLinux.SelectionIntentController intents,
    out HolderLinux.MainController controller,
    out Gtk.SingleSelection project_selection,
    out Gtk.SingleSelection card_selection,
    out Gtk.SingleSelection ai_thread_selection,
    out Gtk.SingleSelection search_selection,
    out GLib.ListStore card_store,
    out HolderLinux.SearchSelectionController search_selection_controller
) {
    intents = new HolderLinux.SelectionIntentController();
    var transition = new HolderLinux.SelectionTransitionController();
    var selection = new HolderLinux.SelectionController();
    controller = new HolderLinux.MainController();
    var flowboard = new HolderLinux.FlowboardController();

    var project_store = new GLib.ListStore(typeof(HolderLinux.Project));
    project_selection = new Gtk.SingleSelection(project_store);

    card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    card_selection = new Gtk.SingleSelection(card_store);

    var ai_thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));
    ai_thread_selection = new Gtk.SingleSelection(ai_thread_store);

    var search_store = new GLib.ListStore(typeof(Object));
    search_selection = new Gtk.SingleSelection(search_store);

    search_selection_controller = new HolderLinux.SearchSelectionController();

    return new HolderLinux.SelectionIntentOrchestrator(
        intents,
        transition,
        selection,
        controller,
        flowboard,
        project_selection,
        card_selection,
        ai_thread_selection,
        search_selection,
        card_store,
        search_selection_controller
    );
}

private GLib.ListStore list_store_from_selection(Gtk.SingleSelection selection) {
    return (!) (selection.get_model() as GLib.ListStore);
}

private void test_project_selection_changed_delegates_selected_id() {
    HolderLinux.SelectionIntentController intents;
    HolderLinux.MainController controller;
    Gtk.SingleSelection project_selection;
    Gtk.SingleSelection card_selection;
    Gtk.SingleSelection ai_thread_selection;
    Gtk.SingleSelection search_selection;
    GLib.ListStore card_store;
    HolderLinux.SearchSelectionController search_selection_controller;
    var orchestrator = make_orchestrator(
        out intents, out controller, out project_selection, out card_selection,
        out ai_thread_selection, out search_selection, out card_store,
        out search_selection_controller
    );

    list_store_from_selection(project_selection).append(new HolderLinux.Project("p1", "Project 1"));
    project_selection.set_selected(0);

    bool done = false;
    orchestrator.on_project_selection_changed.begin((obj, res) => {
        orchestrator.on_project_selection_changed.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(intents.on_project_selection_calls == 1);
    assert(intents.last_project_selection_id == "p1");
}

private void test_card_selection_changed_uses_selected_card_ids() {
    HolderLinux.SelectionIntentController intents;
    HolderLinux.MainController controller;
    Gtk.SingleSelection project_selection;
    Gtk.SingleSelection card_selection;
    Gtk.SingleSelection ai_thread_selection;
    Gtk.SingleSelection search_selection;
    GLib.ListStore card_store;
    HolderLinux.SearchSelectionController search_selection_controller;
    var orchestrator = make_orchestrator(
        out intents, out controller, out project_selection, out card_selection,
        out ai_thread_selection, out search_selection, out card_store,
        out search_selection_controller
    );

    card_store.append(new HolderLinux.CardSummary("c1", "p1"));
    card_selection.set_selected(0);

    bool done = false;
    orchestrator.on_card_selection_changed.begin((obj, res) => {
        orchestrator.on_card_selection_changed.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(intents.on_card_selection_calls == 1);
    assert(intents.last_card_selection_project_id == "p1");
    assert(intents.last_card_selection_card_id == "c1");
}

private void test_card_selection_changed_uses_controller_project_fallback() {
    HolderLinux.SelectionIntentController intents;
    HolderLinux.MainController controller;
    Gtk.SingleSelection project_selection;
    Gtk.SingleSelection card_selection;
    Gtk.SingleSelection ai_thread_selection;
    Gtk.SingleSelection search_selection;
    GLib.ListStore card_store;
    HolderLinux.SearchSelectionController search_selection_controller;
    var orchestrator = make_orchestrator(
        out intents, out controller, out project_selection, out card_selection,
        out ai_thread_selection, out search_selection, out card_store,
        out search_selection_controller
    );

    controller.selected_project_id_value = "fallback-project";
    card_selection.set_selected(Gtk.INVALID_LIST_POSITION);

    bool done = false;
    orchestrator.on_card_selection_changed.begin((obj, res) => {
        orchestrator.on_card_selection_changed.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(intents.on_card_selection_calls == 1);
    assert(intents.last_card_selection_project_id == "fallback-project");
    assert(intents.last_card_selection_card_id == null);
}

private void test_ai_thread_selection_changed_delegates_context() {
    HolderLinux.SelectionIntentController intents;
    HolderLinux.MainController controller;
    Gtk.SingleSelection project_selection;
    Gtk.SingleSelection card_selection;
    Gtk.SingleSelection ai_thread_selection;
    Gtk.SingleSelection search_selection;
    GLib.ListStore card_store;
    HolderLinux.SearchSelectionController search_selection_controller;
    var orchestrator = make_orchestrator(
        out intents, out controller, out project_selection, out card_selection,
        out ai_thread_selection, out search_selection, out card_store,
        out search_selection_controller
    );

    controller.selected_project_id_value = "p-ai";
    controller.selected_card_id_value = "c-ai";
    list_store_from_selection(ai_thread_selection).append(new HolderLinux.AiThreadSummary("t1"));
    ai_thread_selection.set_selected(0);

    orchestrator.on_ai_thread_selection_changed();
    assert(intents.on_ai_thread_selection_calls == 1);
    assert(intents.last_ai_thread_id == "t1");
    assert(intents.last_ai_thread_project_id == "p-ai");
    assert(intents.last_ai_thread_card_id == "c-ai");
}

private void test_search_selection_requested_sets_mapped_position() {
    HolderLinux.SelectionIntentController intents;
    HolderLinux.MainController controller;
    Gtk.SingleSelection project_selection;
    Gtk.SingleSelection card_selection;
    Gtk.SingleSelection ai_thread_selection;
    Gtk.SingleSelection search_selection;
    GLib.ListStore card_store;
    HolderLinux.SearchSelectionController search_selection_controller;
    var orchestrator = make_orchestrator(
        out intents, out controller, out project_selection, out card_selection,
        out ai_thread_selection, out search_selection, out card_store,
        out search_selection_controller
    );

    search_selection_controller.mapped_position = 2;
    list_store_from_selection(search_selection).append(new Object());
    list_store_from_selection(search_selection).append(new Object());
    list_store_from_selection(search_selection).append(new Object());

    orchestrator.on_search_selection_requested(99);
    assert(search_selection.get_selected() == 2);
}

private void test_search_result_activation_uses_card_resolver() {
    HolderLinux.SelectionIntentController intents;
    HolderLinux.MainController controller;
    Gtk.SingleSelection project_selection;
    Gtk.SingleSelection card_selection;
    Gtk.SingleSelection ai_thread_selection;
    Gtk.SingleSelection search_selection;
    GLib.ListStore card_store;
    HolderLinux.SearchSelectionController search_selection_controller;
    var orchestrator = make_orchestrator(
        out intents, out controller, out project_selection, out card_selection,
        out ai_thread_selection, out search_selection, out card_store,
        out search_selection_controller
    );

    card_store.append(new HolderLinux.CardSummary("c-search", "p-search"));

    bool done = false;
    orchestrator.on_search_result_activation.begin(3, (obj, res) => {
        orchestrator.on_search_result_activation.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(intents.on_search_result_activation_calls == 1);
    assert(intents.last_search_activation_position == 3);
    assert(intents.resolved_search_card != null);
    assert(((!) intents.resolved_search_card).card_id == "c-search");
}

private void test_open_card_with_transition_delegates() {
    HolderLinux.SelectionIntentController intents;
    HolderLinux.MainController controller;
    Gtk.SingleSelection project_selection;
    Gtk.SingleSelection card_selection;
    Gtk.SingleSelection ai_thread_selection;
    Gtk.SingleSelection search_selection;
    GLib.ListStore card_store;
    HolderLinux.SearchSelectionController search_selection_controller;
    var orchestrator = make_orchestrator(
        out intents, out controller, out project_selection, out card_selection,
        out ai_thread_selection, out search_selection, out card_store,
        out search_selection_controller
    );

    bool done = false;
    orchestrator.open_card_with_transition.begin("c-open", "toolbox-breadcrumb", (obj, res) => {
        orchestrator.open_card_with_transition.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(intents.open_card_with_transition_calls == 1);
    assert(intents.last_open_card_id == "c-open");
    assert(intents.last_open_card_reason == "toolbox-breadcrumb");
}

private void test_project_selection_requested_delegates() {
    HolderLinux.SelectionIntentController intents;
    HolderLinux.MainController controller;
    Gtk.SingleSelection project_selection;
    Gtk.SingleSelection card_selection;
    Gtk.SingleSelection ai_thread_selection;
    Gtk.SingleSelection search_selection;
    GLib.ListStore card_store;
    HolderLinux.SearchSelectionController search_selection_controller;
    var orchestrator = make_orchestrator(
        out intents, out controller, out project_selection, out card_selection,
        out ai_thread_selection, out search_selection, out card_store,
        out search_selection_controller
    );

    bool done = false;
    orchestrator.on_project_selection_requested.begin("project-requested", (obj, res) => {
        orchestrator.on_project_selection_requested.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(intents.on_project_selection_requested_calls == 1);
    assert(intents.last_project_selection_requested_id == "project-requested");
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/holder/selection-intent-orchestrator/project-selection-changed",
                  test_project_selection_changed_delegates_selected_id);
    Test.add_func("/holder/selection-intent-orchestrator/card-selection-changed-selected",
                  test_card_selection_changed_uses_selected_card_ids);
    Test.add_func("/holder/selection-intent-orchestrator/card-selection-changed-fallback-project",
                  test_card_selection_changed_uses_controller_project_fallback);
    Test.add_func("/holder/selection-intent-orchestrator/ai-thread-selection-changed",
                  test_ai_thread_selection_changed_delegates_context);
    Test.add_func("/holder/selection-intent-orchestrator/search-selection-requested",
                  test_search_selection_requested_sets_mapped_position);
    Test.add_func("/holder/selection-intent-orchestrator/search-result-activation",
                  test_search_result_activation_uses_card_resolver);
    Test.add_func("/holder/selection-intent-orchestrator/open-card-with-transition",
                  test_open_card_with_transition_delegates);
    Test.add_func("/holder/selection-intent-orchestrator/project-selection-requested",
                  test_project_selection_requested_delegates);

    return Test.run();
}

}
