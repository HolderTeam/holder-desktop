namespace HolderLinux {

internal class WindowFeedbackFormat : Object {
    public static bool is_serious_status(string text) {
        var lower = text.down();
        return lower.contains("connecting") ||
               lower.contains("disconnected") ||
               lower.contains("failed") ||
               lower.contains("error") ||
               lower.contains("unavailable") ||
               lower.contains("timeout");
    }

    public static string activity_debug_line(string kind,
                                             string message,
                                             string? project_id = null,
                                             string? card_id = null,
                                             ActivityDetails? details = null) {
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
        return "ACTIVITY %s %s%s".printf(kind, message, scope);
    }

    private static void append_activity_details(Gee.ArrayList<string> parts, ActivityDetails? details) {
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
