using GLib;

namespace HolderLinux {

public class SelectionController : Object {
    public async void on_project_selected() {
    }

    public async void on_card_selected(string card_id) {
    }
}

public class MainController : Object {
    public async void show_project_overview() {
    }

    public void on_ai_thread_selected() {
    }
}

private class RecordingWindowSelectionEditorEventSink : Object, IWindowSelectionEditorEventSink {
    public int project_selection_calls = 0;
    public int card_selection_calls = 0;
    public int ai_thread_selection_calls = 0;
    public int editor_buffer_calls = 0;
    public Gtk.GestureClick? last_gesture = null;
    public int last_n_press = 0;
    public double last_x = 0;
    public double last_y = 0;
    public uint last_keyval = 0;
    public uint last_keycode = 0;
    public Gdk.ModifierType last_state = 0;
    public bool key_result = true;

    public void on_project_selection_changed() {
        project_selection_calls++;
    }

    public void on_card_selection_changed() {
        card_selection_calls++;
    }

    public void on_ai_thread_selection_changed() {
        ai_thread_selection_calls++;
    }

    public void on_editor_buffer_changed() {
        editor_buffer_calls++;
    }

    public void on_internal_link_click_pressed(Gtk.GestureClick gesture,
                                               int n_press,
                                               double x,
                                               double y) {
        last_gesture = gesture;
        last_n_press = n_press;
        last_x = x;
        last_y = y;
    }

    public bool on_internal_link_key_pressed(uint keyval,
                                             uint keycode,
                                             Gdk.ModifierType state) {
        last_keyval = keyval;
        last_keycode = keycode;
        last_state = state;
        return key_result;
    }
}

private class FakeInternalLinkClickController : Object, IInternalLinkClickController {
    private InternalLinkClickHandler? pressed_handler = null;
    private uint last_button = 0;
    private Gtk.GestureClick inner = new Gtk.GestureClick();

    public Gtk.GestureClick gesture {
        get {
            return inner;
        }
    }

    public void set_button(uint button) {
        last_button = button;
    }

    public void set_pressed_handler(owned InternalLinkClickHandler handler) {
        pressed_handler = (owned) handler;
    }

    public void attach_to(GtkSource.View editor_view) {
    }

    public void trigger(int n_press, double x, double y) {
        assert(pressed_handler != null);
        ((!) pressed_handler)(inner, n_press, x, y);
    }

    public uint get_last_button() {
        return last_button;
    }
}

private class FakeInternalLinkKeyController : Object, IInternalLinkKeyController {
    private InternalLinkKeyHandler? key_handler = null;

    public void set_key_pressed_handler(owned InternalLinkKeyHandler handler) {
        key_handler = (owned) handler;
    }

    public void attach_to(GtkSource.View editor_view) {
    }

    public bool trigger(uint keyval, uint keycode, Gdk.ModifierType state) {
        assert(key_handler != null);
        return ((!) key_handler)(keyval, keycode, state);
    }
}

private class FakeInternalLinkControllerFactory : Object, IInternalLinkControllerFactory {
    public FakeInternalLinkClickController click = new FakeInternalLinkClickController();
    public FakeInternalLinkKeyController key = new FakeInternalLinkKeyController();

    public IInternalLinkClickController create_click_controller() {
        return click;
    }

    public IInternalLinkKeyController create_key_controller() {
        return key;
    }
}

private class RecordingWindowFlowboardEventSink : Object, IWindowFlowboardEventSink {
    public uint last_position = uint.MAX;
    public uint last_removed = uint.MAX;
    public uint last_added = uint.MAX;
    public string last_project_id = "";
    public string? last_parent_card_id = "unset";

    public void on_card_store_items_changed(uint position, uint removed, uint added) {
        last_position = position;
        last_removed = removed;
        last_added = added;
    }

    public void on_flowboard_project_overview_requested(string project_id) {
        last_project_id = project_id;
    }

    public void on_flowboard_context_load_requested(string project_id, string? parent_card_id) {
        last_project_id = project_id;
        last_parent_card_id = parent_card_id;
    }
}

private class FakeEditorControllerAttachTarget : Object, IEditorControllerAttachTarget {
    public IInternalLinkClickController? click = null;
    public IInternalLinkKeyController? key = null;

    public void attach_click_controller(IInternalLinkClickController controller) {
        click = controller;
    }

    public void attach_key_controller(IInternalLinkKeyController controller) {
        key = controller;
    }
}

private class FakeWindowCloseRequestSource : Object, IWindowCloseRequestSource {
    public bool emit_close_requested() {
        return close_requested();
    }
}

private class FakePanedPositionSource : Object, IPanedPositionSource {
    public void emit_position_changed(int position) {
        position_changed(position);
    }
}

private class RecordingWindowLifecycleEventSink : Object, IWindowLifecycleEventSink {
    public string error_title = "";
    public string error_details = "";
    public int close_calls = 0;
    public bool close_result = true;

    public void on_project_create_error_reported(string title_text, string details) {
        error_title = title_text;
        error_details = details;
    }

    public bool on_window_close_requested() {
        close_calls++;
        return close_result;
    }
}

private class RecordingWindowStateEventSink : Object, IWindowStateEventSink {
    public int last_position = -1;
    public int app_state_calls = 0;
    public Gee.ArrayList<bool> loading_values = new Gee.ArrayList<bool>();

    public void on_root_paned_position_changed(int position) {
        last_position = position;
    }

    public void on_app_state_changed() {
        app_state_calls++;
    }

    public void on_navigation_loading_changed(bool loading) {
        loading_values.add(loading);
    }
}

}

namespace HolderLinux.Tests {

private Project sample_project() {
    return new Project("proj-1", "Project", "plain", "/tmp/project", 1, 2);
}

private CardSummary sample_card() {
    return new CardSummary("card-1", "proj-1", "Card", "cards/card-1.md", 1.0, null, 1, 2);
}

private AiThreadSummary sample_thread() {
    return new AiThreadSummary("thread-1", "proj-1", "Thread", 1, 2);
}

private void test_transitive_controller_methods_are_referenced() {
    var project_create = new ProjectCreateController();
    var submission = project_create.build_submission(" Demo ", false);
    assert(submission != null);
    assert(((!) submission).name == "Demo");

    var project_store = new GLib.ListStore(typeof(Project));
    project_store.append(sample_project());
    var project_selection = new Gtk.SingleSelection(project_store);
    var card_store = new GLib.ListStore(typeof(CardSummary));
    var flowboard = new FlowboardController(project_store, project_selection, card_store);
    var app_state_store = new AppStateStore();
    var transitions = new SelectionTransitionController(
        new AppTransitionController(app_state_store)
    );
    var selection_controller = new HolderLinux.SelectionController();
    var main_controller = new HolderLinux.MainController();

    transitions.run_project_selection.begin("proj-1", selection_controller, flowboard);
    transitions.run_project_overview_selection.begin("proj-1", main_controller, flowboard);
    transitions.run_card_open_transition.begin(
        "open-card",
        "proj-1",
        "card-1",
        "proj-1",
        "card-1",
        selection_controller,
        flowboard
    );
    transitions.run_ai_thread_selection("proj-1", "card-1", "thread-1", main_controller);
}

private void test_selection_editor_binder_forwards_selection_buffer_and_internal_link_events() {
    var project_store = new GLib.ListStore(typeof(Project));
    project_store.append(sample_project());
    project_store.append(new Project("proj-2", "Project 2", "plain", "/tmp/project-2", 1, 2));
    var project_selection = new Gtk.SingleSelection(project_store);
    project_selection.set_autoselect(false);

    var card_store = new GLib.ListStore(typeof(CardSummary));
    card_store.append(sample_card());
    card_store.append(new CardSummary("card-2", "proj-1", "Card 2", "cards/card-2.md", 2.0, null, 1, 2));
    var card_selection = new Gtk.SingleSelection(card_store);
    card_selection.set_autoselect(false);

    var ai_thread_store = new GLib.ListStore(typeof(AiThreadSummary));
    ai_thread_store.append(sample_thread());
    ai_thread_store.append(new AiThreadSummary("thread-2", "proj-1", "Thread 2", 1, 2));
    var ai_thread_selection = new Gtk.SingleSelection(ai_thread_store);
    ai_thread_selection.set_autoselect(false);

    var editor_buffer = new GtkSource.Buffer(null);
    var sink = new HolderLinux.RecordingWindowSelectionEditorEventSink();
    var factory = new HolderLinux.FakeInternalLinkControllerFactory();
    var attach_target = new HolderLinux.FakeEditorControllerAttachTarget();
    var binder = new HolderLinux.WindowSelectionEditorEventBinder(
        project_selection,
        card_selection,
        ai_thread_selection,
        editor_buffer,
        null,
        sink,
        factory,
        attach_target
    );

    binder.bind();

    project_selection.set_selected(1);
    card_selection.set_selected(1);
    ai_thread_selection.set_selected(1);
    editor_buffer.set_text("hello", -1);

    assert(sink.project_selection_calls == 1);
    assert(sink.card_selection_calls == 1);
    assert(sink.ai_thread_selection_calls == 1);
    assert(sink.editor_buffer_calls == 1);

    assert(factory.click.get_last_button() == Gdk.BUTTON_PRIMARY);
    assert(attach_target.click == factory.click);
    assert(attach_target.key == factory.key);

    factory.click.trigger(1, 12.5, 33.0);
    assert(sink.last_gesture == factory.click.gesture);
    assert(sink.last_n_press == 1);
    assert(sink.last_x == 12.5);
    assert(sink.last_y == 33.0);

    sink.key_result = true;
    bool key_result = factory.key.trigger(Gdk.Key.Return, 13, Gdk.ModifierType.CONTROL_MASK);
    assert(key_result);
    assert(sink.last_keyval == Gdk.Key.Return);
    assert(sink.last_keycode == 13);
    assert(sink.last_state == Gdk.ModifierType.CONTROL_MASK);
}

private void test_flowboard_binder_forwards_store_and_controller_signals() {
    var project_store = new GLib.ListStore(typeof(Project));
    project_store.append(sample_project());
    var project_selection = new Gtk.SingleSelection(project_store);
    var card_store = new GLib.ListStore(typeof(CardSummary));
    var controller = new FlowboardController(project_store, project_selection, card_store);
    var sink = new HolderLinux.RecordingWindowFlowboardEventSink();
    var binder = new HolderLinux.WindowFlowboardEventBinder(card_store, controller, sink);

    binder.bind();

    card_store.append(sample_card());
    controller.project_overview_requested("proj-1");
    assert(sink.last_position == 0);
    assert(sink.last_removed == 0);
    assert(sink.last_added == 1);
    assert(sink.last_project_id == "proj-1");

    controller.context_load_requested("proj-1", "parent-1");
    assert(sink.last_project_id == "proj-1");
    assert(sink.last_parent_card_id == "parent-1");
}

private void test_lifecycle_binder_forwards_project_create_and_window_close() {
    var controller = new ProjectCreateController();
    var window = new HolderLinux.FakeWindowCloseRequestSource();
    var sink = new HolderLinux.RecordingWindowLifecycleEventSink();
    var binder = new HolderLinux.WindowLifecycleEventBinder(controller, window, sink);

    binder.bind();

    controller.error_reported("Bad", "Broken");
    assert(sink.error_title == "Bad");
    assert(sink.error_details == "Broken");

    sink.close_result = true;
    bool close_result = window.emit_close_requested();
    assert(close_result);
    assert(sink.close_calls == 1);
}

private void test_state_binder_forwards_paned_app_state_and_navigation_loading() {
    var root_paned = new HolderLinux.FakePanedPositionSource();
    var app_state_store = new AppStateStore();
    var transition_controller = new SelectionTransitionController(
        new AppTransitionController(app_state_store)
    );
    var sink = new HolderLinux.RecordingWindowStateEventSink();
    var binder = new HolderLinux.WindowStateEventBinder(
        root_paned,
        app_state_store,
        transition_controller,
        sink
    );

    binder.bind();

    root_paned.emit_position_changed(240);
    app_state_store.set_selected_project("proj-1");
    uint sequence = transition_controller.begin_navigation("test-nav");
    transition_controller.finish_navigation_if_current(sequence);

    assert(sink.last_position == 240);
    assert(sink.app_state_calls >= 1);
    assert(sink.loading_values.size == 2);
    assert(sink.loading_values[0]);
    assert(!sink.loading_values[1]);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func(
        "/holder/window-event-binders/transitive-controller-methods-are-referenced",
        test_transitive_controller_methods_are_referenced
    );
    Test.add_func(
        "/holder/window-event-binders/selection-editor-binder-forwards-selection-buffer-and-internal-link-events",
        test_selection_editor_binder_forwards_selection_buffer_and_internal_link_events
    );
    Test.add_func(
        "/holder/window-event-binders/flowboard-binder-forwards-store-and-controller-signals",
        test_flowboard_binder_forwards_store_and_controller_signals
    );
    Test.add_func(
        "/holder/window-event-binders/lifecycle-binder-forwards-project-create-and-window-close",
        test_lifecycle_binder_forwards_project_create_and_window_close
    );
    Test.add_func(
        "/holder/window-event-binders/state-binder-forwards-paned-app-state-and-navigation-loading",
        test_state_binder_forwards_paned_app_state_and_navigation_loading
    );
    return Test.run();
}

}
