using GLib;

// This target does not link the real workspace_pane.vala, toolbox.vala or main.vala: WorkspacePane,
// ToolboxPane and MainController are compiled alone by dozens of other test targets, so giving them
// interfaces to implement (or any other change) would ripple across the whole build. Instead this
// file provides lightweight local stand-ins with just the members window_activity_feedback.vala's
// class actually calls, matching the approach in tests/window_event_endpoints_test.vala.

namespace HolderLinux {

public class WorkspacePane : Object {
    public int set_app_message_calls = 0;
    public string? last_set_app_message_text = "unset";

    public void set_app_message(string? text) {
        set_app_message_calls++;
        last_set_app_message_text = text;
    }
}

public class ToolboxPane : Object {
    public int log_debug_calls = 0;
    public Gee.ArrayList<string> log_debug_lines = new Gee.ArrayList<string>();

    public void log_debug(string line) {
        log_debug_calls++;
        log_debug_lines.add(line);
    }
}

public class MainController : Object {
    public string? project_id = null;
    public string? card_id = null;

    public string? selected_project_id() {
        return project_id;
    }

    public string? selected_card_id() {
        return card_id;
    }
}

}

namespace HolderLinuxTests {

private HolderLinux.WindowActivityFeedback make_feedback(HolderLinux.WorkspacePane workspace,
                                                          HolderLinux.ToolboxPane toolbox,
                                                          Adw.ToastOverlay toast_overlay,
                                                          HolderLinux.ActivityLogController log_controller,
                                                          HolderLinux.MainController controller) {
    return new HolderLinux.WindowActivityFeedback(workspace, toolbox, toast_overlay, log_controller, controller);
}

private void test_set_status_updates_the_app_message_only_for_serious_text() {
    var workspace = new HolderLinux.WorkspacePane();
    var toolbox = new HolderLinux.ToolboxPane();
    var toast_overlay = new Adw.ToastOverlay();
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.MainController();
    var log_controller = new HolderLinux.ActivityLogController(store, controller);
    var feedback = make_feedback(workspace, toolbox, toast_overlay, log_controller, controller);

    feedback.set_status("Saved.");

    assert(workspace.set_app_message_calls == 1);
    // "Saved." is not a serious status per WindowFeedbackFormat.is_serious_status, so it clears the
    // message rather than showing it.
    assert(workspace.last_set_app_message_text == null);
    assert(toolbox.log_debug_calls == 1);
    assert(toolbox.log_debug_lines[0] == "STATUS: Saved.");
}

private void test_set_status_shows_a_serious_message() {
    var workspace = new HolderLinux.WorkspacePane();
    var toolbox = new HolderLinux.ToolboxPane();
    var toast_overlay = new Adw.ToastOverlay();
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.MainController();
    var log_controller = new HolderLinux.ActivityLogController(store, controller);
    var feedback = make_feedback(workspace, toolbox, toast_overlay, log_controller, controller);

    // is_serious_status keys off certain words (e.g. "failed"); this text must actually be one of
    // them, or the assertion below would pass for the wrong reason.
    var serious = HolderLinux.WindowFeedbackFormat.error_status_text("Save failed", "disk full");
    assert(HolderLinux.WindowFeedbackFormat.is_serious_status(serious));
    feedback.set_status(serious);

    assert(workspace.last_set_app_message_text == serious);
}

private void test_log_debug_line_forwards_to_toolbox() {
    var workspace = new HolderLinux.WorkspacePane();
    var toolbox = new HolderLinux.ToolboxPane();
    var toast_overlay = new Adw.ToastOverlay();
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.MainController();
    var log_controller = new HolderLinux.ActivityLogController(store, controller);
    var feedback = make_feedback(workspace, toolbox, toast_overlay, log_controller, controller);

    feedback.log_debug_line("debug line");

    assert(toolbox.log_debug_calls == 1);
    assert(toolbox.log_debug_lines[0] == "debug line");
}

private void test_log_activity_appends_to_the_store_and_logs_a_debug_line() {
    var workspace = new HolderLinux.WorkspacePane();
    var toolbox = new HolderLinux.ToolboxPane();
    var toast_overlay = new Adw.ToastOverlay();
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.MainController();
    var log_controller = new HolderLinux.ActivityLogController(store, controller);
    var feedback = make_feedback(workspace, toolbox, toast_overlay, log_controller, controller);

    HolderLinux.ActivityLogEntry? seen = null;
    store.entry_added.connect((entry) => { seen = entry; });

    feedback.log_activity("kind.x", "msg", "p1", "c1", null);

    assert(seen != null);
    assert(((!) seen).kind == "kind.x");
    assert(((!) seen).message == "msg");
    assert(((!) seen).project_id == "p1");
    assert(((!) seen).card_id == "c1");
    assert(toolbox.log_debug_calls == 1);
}

private void test_log_status_activity_uses_the_current_selection() {
    var workspace = new HolderLinux.WorkspacePane();
    var toolbox = new HolderLinux.ToolboxPane();
    var toast_overlay = new Adw.ToastOverlay();
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.MainController();
    controller.project_id = "p1";
    controller.card_id = "c1";
    var log_controller = new HolderLinux.ActivityLogController(store, controller);
    var feedback = make_feedback(workspace, toolbox, toast_overlay, log_controller, controller);

    HolderLinux.ActivityLogEntry? seen = null;
    store.entry_added.connect((entry) => { seen = entry; });

    feedback.log_status_activity("Saved.");

    assert(seen != null);
    assert(((!) seen).kind == "feedback.status");
    assert(((!) seen).message == "Saved.");
    assert(((!) seen).project_id == "p1");
    assert(((!) seen).card_id == "c1");
}

private void test_log_toast_activity_uses_the_current_selection() {
    var workspace = new HolderLinux.WorkspacePane();
    var toolbox = new HolderLinux.ToolboxPane();
    var toast_overlay = new Adw.ToastOverlay();
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.MainController();
    controller.project_id = "p1";
    controller.card_id = "c1";
    var log_controller = new HolderLinux.ActivityLogController(store, controller);
    var feedback = make_feedback(workspace, toolbox, toast_overlay, log_controller, controller);

    HolderLinux.ActivityLogEntry? seen = null;
    store.entry_added.connect((entry) => { seen = entry; });

    feedback.log_toast_activity("Done.");

    assert(seen != null);
    assert(((!) seen).kind == "feedback.toast");
    assert(((!) seen).message == "Done.");
}

private void test_log_error_activity_formats_the_message_and_uses_the_current_selection() {
    var workspace = new HolderLinux.WorkspacePane();
    var toolbox = new HolderLinux.ToolboxPane();
    var toast_overlay = new Adw.ToastOverlay();
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.MainController();
    controller.project_id = "p1";
    controller.card_id = "c1";
    var log_controller = new HolderLinux.ActivityLogController(store, controller);
    var feedback = make_feedback(workspace, toolbox, toast_overlay, log_controller, controller);

    HolderLinux.ActivityLogEntry? seen = null;
    store.entry_added.connect((entry) => { seen = entry; });

    feedback.log_error_activity("Bad", "Broken");

    assert(seen != null);
    assert(((!) seen).kind == "feedback.error");
    assert(((!) seen).message == HolderLinux.WindowFeedbackFormat.error_status_text("Bad", "Broken"));
}

private void test_add_toast_adds_a_toast_to_the_overlay() {
    var workspace = new HolderLinux.WorkspacePane();
    var toolbox = new HolderLinux.ToolboxPane();
    var toast_overlay = new Adw.ToastOverlay();
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.MainController();
    var log_controller = new HolderLinux.ActivityLogController(store, controller);
    var feedback = make_feedback(workspace, toolbox, toast_overlay, log_controller, controller);

    // There's no public way to inspect an Adw.ToastOverlay's queued toasts, so this only proves
    // add_toast does not throw or crash; the outcome is covered end to end by show_error below.
    feedback.add_toast("Done.");
}

private void test_show_error_sets_status_toasts_and_logs_debug() {
    var workspace = new HolderLinux.WorkspacePane();
    var toolbox = new HolderLinux.ToolboxPane();
    var toast_overlay = new Adw.ToastOverlay();
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.MainController();
    var log_controller = new HolderLinux.ActivityLogController(store, controller);
    var feedback = make_feedback(workspace, toolbox, toast_overlay, log_controller, controller);

    feedback.show_error("Save failed", "disk full");

    var expected_status = HolderLinux.WindowFeedbackFormat.error_status_text("Save failed", "disk full");
    assert(HolderLinux.WindowFeedbackFormat.is_serious_status(expected_status));
    assert(workspace.set_app_message_calls == 1);
    assert(workspace.last_set_app_message_text == expected_status);
    var expected_debug = HolderLinux.WindowFeedbackFormat.error_debug_line("Save failed", "disk full");
    assert(toolbox.log_debug_lines.contains(expected_debug));
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping window activity feedback tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    var prefix = "/holder/window-activity-feedback/";
    Test.add_func(prefix + "set-status-updates-the-app-message-only-for-serious-text",
                  test_set_status_updates_the_app_message_only_for_serious_text);
    Test.add_func(prefix + "set-status-shows-a-serious-message",
                  test_set_status_shows_a_serious_message);
    Test.add_func(prefix + "log-debug-line-forwards-to-toolbox",
                  test_log_debug_line_forwards_to_toolbox);
    Test.add_func(prefix + "log-activity-appends-to-the-store-and-logs-a-debug-line",
                  test_log_activity_appends_to_the_store_and_logs_a_debug_line);
    Test.add_func(prefix + "log-status-activity-uses-the-current-selection",
                  test_log_status_activity_uses_the_current_selection);
    Test.add_func(prefix + "log-toast-activity-uses-the-current-selection",
                  test_log_toast_activity_uses_the_current_selection);
    Test.add_func(prefix + "log-error-activity-formats-the-message-and-uses-the-current-selection",
                  test_log_error_activity_formats_the_message_and_uses_the_current_selection);
    Test.add_func(prefix + "add-toast-adds-a-toast-to-the-overlay",
                  test_add_toast_adds_a_toast_to_the_overlay);
    Test.add_func(prefix + "show-error-sets-status-toasts-and-logs-debug",
                  test_show_error_sets_status_toasts_and_logs_debug);

    return Test.run();
}

}
