namespace HolderLinux {

public class ActivityLogController : Object {
    private ActivityLogStore store;
    private MainController main_controller;

    public ActivityLogController(ActivityLogStore store, MainController main_controller) {
        this.store = store;
        this.main_controller = main_controller;
    }

    public ActivityLogStore get_store() {
        return store;
    }

    public void log(string kind,
                    string message,
                    string? project_id = null,
                    string? card_id = null) {
        store.append(kind, message, project_id, card_id);
    }

    public void log_from_current_selection(string kind, string message) {
        log(
            kind,
            message,
            main_controller.selected_project_id(),
            main_controller.selected_card_id()
        );
    }

    public void clear() {
        store.clear();
    }

    public void log_status(string text) {
        log_from_current_selection("feedback.status", text);
    }

    public void log_toast(string message) {
        log_from_current_selection("feedback.toast", message);
    }

    public void log_error(string title_text, string details) {
        log_from_current_selection(
            "feedback.error",
            "%s: %s".printf(title_text, details)
        );
    }

    public void log_new_project_requested() {
        log_from_current_selection("intent.project.create", "New project requested");
    }

    public void log_new_card_requested() {
        log_from_current_selection("intent.card.create", "New card requested");
    }

    public void log_search_activated(string query_text) {
        log_from_current_selection(
            "intent.search.activate",
            "Search activated: %s".printf(query_text)
        );
    }

    public void log_search_result_open_requested() {
        log_from_current_selection(
            "intent.search.open_result",
            "Search result activated"
        );
    }

    public void log_project_selected(Project project) {
        log(
            "intent.project.select",
            "Project selected: %s".printf(project.name),
            project.project_id,
            null
        );
    }

    public void log_card_selected(CardSummary card) {
        log(
            "intent.card.select",
            "Card selected: %s".printf(card.title),
            card.project_id,
            card.card_id
        );
    }

    public void log_ai_thread_selected(AiThreadSummary thread, string? card_id = null) {
        log(
            "intent.ai_thread.select",
            "AI thread selected: %s".printf(thread.title),
            thread.project_id,
            card_id
        );
    }
}

}
