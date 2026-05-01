namespace HolderLinux {

internal class WindowActivityFeedback : Object {
    private WorkspacePane workspace;
    private ToolboxPane toolbox;
    private Adw.ToastOverlay toast_overlay;
    private ActivityLogController activity_log_controller;
    private MainController controller;

    public WindowActivityFeedback(WorkspacePane workspace,
                                  ToolboxPane toolbox,
                                  Adw.ToastOverlay toast_overlay,
                                  ActivityLogController activity_log_controller,
                                  MainController controller) {
        this.workspace = workspace;
        this.toolbox = toolbox;
        this.toast_overlay = toast_overlay;
        this.activity_log_controller = activity_log_controller;
        this.controller = controller;
    }

    public void set_status(string text) {
        workspace.set_app_message(WindowFeedbackFormat.is_serious_status(text) ? text : null);
        toolbox.log_debug("STATUS: %s".printf(text));
    }

    public void log_debug_line(string message) {
        toolbox.log_debug(message);
    }

    public void log_activity(string kind,
                             string message,
                             string? project_id = null,
                             string? card_id = null,
                             ActivityDetails? details = null) {
        activity_log_controller.log(kind, message, project_id, card_id, details);
        toolbox.log_debug(WindowFeedbackFormat.activity_debug_line(
            kind,
            message,
            project_id,
            card_id,
            details
        ));
    }

    public void log_status_activity(string text) {
        log_activity(
            "feedback.status",
            text,
            controller.selected_project_id(),
            controller.selected_card_id()
        );
    }

    public void log_toast_activity(string message) {
        log_activity(
            "feedback.toast",
            message,
            controller.selected_project_id(),
            controller.selected_card_id()
        );
    }

    public void log_error_activity(string title_text, string details) {
        log_activity(
            "feedback.error",
            "%s: %s".printf(title_text, details),
            controller.selected_project_id(),
            controller.selected_card_id()
        );
    }

    public void add_toast(string msg) {
        toast_overlay.add_toast(new Adw.Toast(msg));
    }

    public void show_error(string title_text, string details) {
        set_status("%s: %s".printf(title_text, details));
        add_toast("%s".printf(title_text));
        toolbox.log_debug("ERROR: %s | %s".printf(title_text, details));
    }

}

}
