using GLib;

namespace HolderLinux {

public class ToolboxBreadcrumbController : Object {
    public delegate void OpenCardFunc(string card_id);
    public delegate void ShowToolHelpFunc(string tool_id);

    public string last_tool_id = "";
    public int last_segment_index = -1;
    public string? last_project_id = "unset";
    public string? last_card_id = "unset";
    public string callback_card_id = "callback-card";
    public string callback_tool_id = "callback-tool";
    public bool invoke_open_card = false;
    public bool invoke_show_tool_help = false;

    public async void navigate(string tool_id,
                               int segment_index,
                               string? project_id,
                               string? card_id,
                               owned OpenCardFunc open_card,
                               owned ShowToolHelpFunc show_tool_help) {
        last_tool_id = tool_id;
        last_segment_index = segment_index;
        last_project_id = project_id;
        last_card_id = card_id;
        if (invoke_open_card) {
            open_card(callback_card_id);
        }
        if (invoke_show_tool_help) {
            show_tool_help(callback_tool_id);
        }
    }
}

public class SelectionIntentOrchestrator : Object {
    public string last_open_card_id = "";
    public string last_open_reason = "";

    public async void open_card_with_transition(string card_id, string reason) {
        last_open_card_id = card_id;
        last_open_reason = reason;
    }
}

public class MainController : Object {
    public int create_card_calls = 0;
    public string? first_created_parent_card_id = "unset";
    public string? last_created_parent_card_id = "unset";
    public string last_move_card_id = "";
    public string last_move_intent = "";
    public string? last_move_target_card_id = "unset";
    public string? last_move_parent_card_id = "unset";
    public ProjectResource? shown_resource_references;

    public async void create_card(string? parent_card_id = null) {
        create_card_calls++;
        if (create_card_calls == 1) {
            first_created_parent_card_id = parent_card_id;
        }
        last_created_parent_card_id = parent_card_id;
    }

    public async void move_card_by_intent(string card_id,
                                          string intent,
                                          string? target_card_id,
                                          string? parent_card_id) {
        last_move_card_id = card_id;
        last_move_intent = intent;
        last_move_target_card_id = target_card_id;
        last_move_parent_card_id = parent_card_id;
    }

    public void show_resource_references(ProjectResource resource) {
        shown_resource_references = resource;
    }
}

private class FakeToolboxEventSource : Object, IToolboxEventSource {
    public void emit_error_reported(string title_text, string details) {
        error_reported(title_text, details);
    }

    public void emit_toast_requested(string message) {
        toast_requested(message);
    }

    public void emit_breadcrumb_navigation_requested(string tool_id,
                                                     int segment_index,
                                                     string? project_id,
                                                     string? card_id) {
        breadcrumb_navigation_requested(tool_id, segment_index, project_id, card_id);
    }

    public void emit_flowboard_card_open_requested(string card_id) {
        flowboard_card_open_requested(card_id);
    }

    public void emit_connections_card_open_requested(string card_id) {
        connections_card_open_requested(card_id);
    }

    public void emit_tags_card_open_requested(string card_id) {
        tags_card_open_requested(card_id);
    }

    public void emit_resources_card_open_requested(string card_id) {
        resources_card_open_requested(card_id);
    }

    public void emit_resource_references_requested(ProjectResource resource) {
        resource_references_requested(resource);
    }

    public void emit_connections_card_create_child_requested(string card_id) {
        connections_card_create_child_requested(card_id);
    }

    public void emit_flowboard_card_move_to_trash_requested(string card_id) {
        flowboard_card_move_to_trash_requested(card_id);
    }

    public void emit_flowboard_move_intent_requested(string card_id,
                                                     string project_id,
                                                     string intent,
                                                     string? target_card_id,
                                                     string? parent_card_id) {
        flowboard_move_intent_requested(card_id, project_id, intent, target_card_id, parent_card_id);
    }

    public void emit_flowboard_new_card_requested(string? parent_card_id) {
        flowboard_new_card_requested(parent_card_id);
    }

    public void emit_send_card_as_email_requested() {
        send_card_as_email_requested();
    }

    public void emit_send_recovery_key_as_email_requested() {
        send_recovery_key_as_email_requested();
    }

    public void emit_save_recovery_key_to_usb_requested() {
        save_recovery_key_to_usb_requested();
    }

    public void emit_import_recovery_key_requested() {
        import_recovery_key_requested();
    }

    public void emit_terminal_copy_to_card_requested(string text) {
        terminal_copy_to_card_requested(text);
    }

    public void emit_activity_requested(string kind,
                                        string message,
                                        string? project_id,
                                        string? card_id,
                                        ActivityDetails? details) {
        activity_requested(kind, message, project_id, card_id, details);
    }
}

private class RecordingToolboxEventSink : Object, IToolboxEventSink {
    public string error_title = "";
    public string error_details = "";
    public string toast_message = "";
    public string tool_help_page = "";
    public string move_to_trash_card_id = "";
    public int send_card_as_email_calls = 0;
    public int send_recovery_key_as_email_calls = 0;
    public int save_recovery_key_to_usb_calls = 0;
    public int import_recovery_key_calls = 0;
    public string appended_text = "";
    public string activity_kind = "";
    public string activity_message = "";
    public string? activity_project_id = "unset";
    public string? activity_card_id = "unset";
    public ActivityDetails? activity_details = null;

    public void show_error(string title_text, string details) {
        error_title = title_text;
        error_details = details;
    }

    public void add_toast(string message) {
        toast_message = message;
    }

    public void show_tool_help_page(string tool_id) {
        tool_help_page = tool_id;
    }

    public void confirm_move_card_to_trash(string card_id) {
        move_to_trash_card_id = card_id;
    }

    public void send_current_card_as_email() {
        send_card_as_email_calls++;
    }

    public void request_send_recovery_key_as_email() {
        send_recovery_key_as_email_calls++;
    }

    public void request_save_recovery_key_to_usb() {
        save_recovery_key_to_usb_calls++;
    }

    public void request_import_recovery_key() {
        import_recovery_key_calls++;
    }

    public void append_text_to_current_card(string text) {
        appended_text = text;
    }

    public void log_activity(string kind,
                             string message,
                             string? project_id,
                             string? card_id,
                             ActivityDetails? details) {
        activity_kind = kind;
        activity_message = message;
        activity_project_id = project_id;
        activity_card_id = card_id;
        activity_details = details;
    }
}

}

namespace HolderLinux.Tests {

private void wait_for_idle() {
    var loop = new MainLoop();
    Idle.add(() => {
        loop.quit();
        return Source.REMOVE;
    });
    loop.run();
}

private void test_bind_routes_toolbox_events_to_sink_and_controllers() {
    var source = new HolderLinux.FakeToolboxEventSource();
    var breadcrumbs = new HolderLinux.ToolboxBreadcrumbController();
    var selection = new HolderLinux.SelectionIntentOrchestrator();
    var controller = new HolderLinux.MainController();
    var sink = new HolderLinux.RecordingToolboxEventSink();
    var orchestrator = new HolderLinux.ToolboxEventOrchestrator(
        source,
        breadcrumbs,
        selection,
        controller,
        sink
    );
    var details = new HolderLinux.CardCreatedDetails("Card A", "parent-1");

    orchestrator.bind();

    source.emit_error_reported("Bad", "Broken");
    source.emit_toast_requested("Saved");
    source.emit_connections_card_create_child_requested("card-parent");
    source.emit_flowboard_card_move_to_trash_requested("card-trash");
    source.emit_flowboard_move_intent_requested("card-1", "proj-1", "left", "target-1", "parent-1");
    source.emit_flowboard_new_card_requested("parent-2");
    source.emit_send_card_as_email_requested();
    source.emit_send_recovery_key_as_email_requested();
    source.emit_save_recovery_key_to_usb_requested();
    source.emit_import_recovery_key_requested();
    source.emit_terminal_copy_to_card_requested("copy me");
    source.emit_activity_requested("result.card.create", "Created", "proj-1", "card-1", details);
    wait_for_idle();

    assert(sink.error_title == "Bad");
    assert(sink.error_details == "Broken");
    assert(sink.toast_message == "Saved");
    assert(controller.create_card_calls == 2);
    assert(controller.first_created_parent_card_id == "card-parent");
    assert(controller.last_created_parent_card_id == "parent-2");
    assert(sink.move_to_trash_card_id == "card-trash");
    assert(controller.last_move_card_id == "card-1");
    assert(controller.last_move_intent == "left");
    assert(controller.last_move_target_card_id == "target-1");
    assert(controller.last_move_parent_card_id == "parent-1");
    assert(sink.send_card_as_email_calls == 1);
    assert(sink.send_recovery_key_as_email_calls == 1);
    assert(sink.save_recovery_key_to_usb_calls == 1);
    assert(sink.import_recovery_key_calls == 1);
    assert(sink.appended_text == "copy me");
    assert(sink.activity_kind == "result.card.create");
    assert(sink.activity_message == "Created");
    assert(sink.activity_project_id == "proj-1");
    assert(sink.activity_card_id == "card-1");
    assert(sink.activity_details == details);
}

private void test_bind_routes_open_card_requests_with_expected_reasons() {
    var source = new HolderLinux.FakeToolboxEventSource();
    var breadcrumbs = new HolderLinux.ToolboxBreadcrumbController();
    var selection = new HolderLinux.SelectionIntentOrchestrator();
    var controller = new HolderLinux.MainController();
    var sink = new HolderLinux.RecordingToolboxEventSink();
    var orchestrator = new HolderLinux.ToolboxEventOrchestrator(
        source,
        breadcrumbs,
        selection,
        controller,
        sink
    );

    orchestrator.bind();

    source.emit_flowboard_card_open_requested("card-flow");
    wait_for_idle();
    assert(selection.last_open_card_id == "card-flow");
    assert(selection.last_open_reason == "toolbox-flowboard-card-open");

    source.emit_connections_card_open_requested("card-conn");
    wait_for_idle();
    assert(selection.last_open_card_id == "card-conn");
    assert(selection.last_open_reason == "toolbox-connections-card-open");

    source.emit_tags_card_open_requested("card-tag");
    wait_for_idle();
    assert(selection.last_open_card_id == "card-tag");
    assert(selection.last_open_reason == "toolbox-tags-card-open");

    source.emit_resources_card_open_requested("card-resource");
    wait_for_idle();
    assert(selection.last_open_card_id == "card-resource");
    assert(selection.last_open_reason == "toolbox-resources-card-open");

    var resource = new ProjectResource("r1", "p1", "image", "", "Boiler", null, 1, 2);
    source.emit_resource_references_requested(resource);
    assert(controller.shown_resource_references == resource);
}

private void test_breadcrumb_navigation_passes_callbacks_through_orchestrator() {
    var source = new HolderLinux.FakeToolboxEventSource();
    var breadcrumbs = new HolderLinux.ToolboxBreadcrumbController();
    var selection = new HolderLinux.SelectionIntentOrchestrator();
    var controller = new HolderLinux.MainController();
    var sink = new HolderLinux.RecordingToolboxEventSink();
    var orchestrator = new HolderLinux.ToolboxEventOrchestrator(
        source,
        breadcrumbs,
        selection,
        controller,
        sink
    );

    orchestrator.bind();

    breadcrumbs.invoke_open_card = true;
    breadcrumbs.callback_card_id = "card-breadcrumb";
    source.emit_breadcrumb_navigation_requested("connections", 2, "proj-1", "card-1");
    wait_for_idle();
    assert(breadcrumbs.last_tool_id == "connections");
    assert(breadcrumbs.last_segment_index == 2);
    assert(breadcrumbs.last_project_id == "proj-1");
    assert(breadcrumbs.last_card_id == "card-1");
    assert(selection.last_open_card_id == "card-breadcrumb");
    assert(selection.last_open_reason == "toolbox-breadcrumb-card-open");

    breadcrumbs.invoke_open_card = false;
    breadcrumbs.invoke_show_tool_help = true;
    breadcrumbs.callback_tool_id = "resources";
    source.emit_breadcrumb_navigation_requested("flowboard", 0, null, null);
    wait_for_idle();
    assert(sink.tool_help_page == "resources");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func(
        "/holder/toolbox-event-orchestrator/bind-routes-toolbox-events-to-sink-and-controllers",
        test_bind_routes_toolbox_events_to_sink_and_controllers
    );
    Test.add_func(
        "/holder/toolbox-event-orchestrator/bind-routes-open-card-requests-with-expected-reasons",
        test_bind_routes_open_card_requests_with_expected_reasons
    );
    Test.add_func(
        "/holder/toolbox-event-orchestrator/breadcrumb-navigation-passes-callbacks-through-orchestrator",
        test_breadcrumb_navigation_passes_callbacks_through_orchestrator
    );
    return Test.run();
}

}
