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
        workspace.set_app_message(is_serious_status(text) ? text : null);
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
        var parts = new Gee.ArrayList<string>();
        if (project_id != null && project_id.strip().length > 0) {
            parts.add("project=%s".printf(project_id));
        }
        if (card_id != null && card_id.strip().length > 0) {
            parts.add("card=%s".printf(card_id));
        }
        append_activity_details(parts, details);
        var scope = parts.size > 0
            ? " [%s]".printf(string.joinv(", ", parts.to_array()))
            : "";
        toolbox.log_debug("ACTIVITY %s %s%s".printf(kind, message, scope));
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

    private bool is_serious_status(string text) {
        var lower = text.down();
        return lower.contains("connecting") ||
               lower.contains("disconnected") ||
               lower.contains("failed") ||
               lower.contains("error") ||
               lower.contains("unavailable") ||
               lower.contains("timeout");
    }

    private void append_activity_details(Gee.ArrayList<string> parts, ActivityDetails? details) {
        var ai_details = details as AiRunDetails;
        if (ai_details == null) {
            return;
        }
        if (ai_details.thread_id.strip().length > 0) {
            parts.add("thread=%s".printf(ai_details.thread_id));
        }
        if (ai_details.run_id.strip().length > 0) {
            parts.add("run=%s".printf(ai_details.run_id));
        }
        if (ai_details.provider.strip().length > 0) {
            parts.add("provider=%s".printf(ai_details.provider));
        }
        if (ai_details.model.strip().length > 0) {
            parts.add("model=%s".printf(ai_details.model));
        }
        if (ai_details.router_model.strip().length > 0) {
            parts.add("router=%s".printf(ai_details.router_model));
        }
        if (ai_details.prompt_chars > 0) {
            parts.add("prompt_chars=%d".printf(ai_details.prompt_chars));
        }
        parts.add("success=%s".printf(ai_details.success ? "true" : "false"));
    }
}

}
