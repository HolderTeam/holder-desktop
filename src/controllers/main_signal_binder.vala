namespace HolderLinux {

internal interface IMainControllerSignalSource : Object {
    public abstract signal void status_changed(string text);
    public abstract signal void editor_state_changed(string text, bool editable);
    public abstract signal void validated_tag_occurrences_changed(CardTagOccurrence[] occurrences);
    public abstract signal void editor_save_state_changed(string text);
    public abstract signal void card_durable_save_completed(string project_id,
                                                            string card_id,
                                                            int64 updated_at);
    public abstract signal void window_title_changed(string title_text);
    public abstract signal void toast_requested(string message);
    public abstract signal void error_reported(string title_text, string details);
    public abstract signal void show_editor_requested();
    public abstract signal void show_search_requested();
    public abstract signal void search_summary_changed(string text);
    public abstract signal void ai_status_refresh_requested();
    public abstract signal void project_selection_requested(string? project_id);
    public abstract signal void card_selection_requested(string? card_id);
    public abstract signal void search_selection_requested(int position);
    public abstract signal void ai_thread_title_changed(string? title_text);
    public abstract signal void ai_thread_selection_requested(string? thread_id);
    public abstract signal void api_client_ready(IHolderApi api_client);
    public abstract signal void card_trashed(string card_id);
    public abstract signal void activity_requested(string kind,
                                                  string message,
                                                  string? project_id,
                                                  string? card_id,
                                                  ActivityDetails? details);
}

internal interface IMainControllerSignalSink : Object {
    public abstract void on_status_changed(string text);
    public abstract void on_editor_state_changed(string text, bool editable);
    public abstract void on_validated_tag_occurrences_changed(CardTagOccurrence[] occurrences);
    public abstract void on_editor_save_state_changed(string text);
    public abstract void on_card_durable_save_completed(string project_id,
                                                        string card_id,
                                                        int64 updated_at);
    public abstract void on_window_title_changed(string title_text);
    public abstract void on_toast_requested(string message);
    public abstract void on_error_reported(string title_text, string details);
    public abstract void on_show_editor_requested();
    public abstract void on_show_search_requested();
    public abstract void on_search_summary_changed(string text);
    public abstract void on_ai_status_refresh_requested();
    public abstract void on_project_selection_requested(string? project_id);
    public abstract void on_card_selection_requested(string? card_id);
    public abstract void on_search_selection_requested(int position);
    public abstract void on_ai_thread_title_changed(string? title_text);
    public abstract void on_ai_thread_selection_requested(string? thread_id);
    public abstract void on_api_client_ready(IHolderApi api_client);
    public abstract void on_card_trashed(string card_id);
    public abstract void on_activity_requested(string kind,
                                              string message,
                                              string? project_id,
                                              string? card_id,
                                              ActivityDetails? details);
}

internal class MainControllerSignalBinder : Object {
    private IMainControllerSignalSource controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IMainControllerSignalSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public MainControllerSignalBinder(IMainControllerSignalSource controller,
                                      IMainControllerSignalSink sink) {
        this.controller = controller;
        this.sink = sink;
    }

    public void bind() {
        controller.status_changed.connect((text) => {
            sink.on_status_changed(text);
        });
        controller.editor_state_changed.connect((text, editable) => {
            sink.on_editor_state_changed(text, editable);
        });
        controller.validated_tag_occurrences_changed.connect((occurrences) => {
            sink.on_validated_tag_occurrences_changed(occurrences);
        });
        controller.editor_save_state_changed.connect((text) => {
            sink.on_editor_save_state_changed(text);
        });
        controller.card_durable_save_completed.connect((project_id, card_id, updated_at) => {
            sink.on_card_durable_save_completed(project_id, card_id, updated_at);
        });
        controller.window_title_changed.connect((title_text) => {
            sink.on_window_title_changed(title_text);
        });
        controller.toast_requested.connect((message) => {
            sink.on_toast_requested(message);
        });
        controller.error_reported.connect((title_text, details) => {
            sink.on_error_reported(title_text, details);
        });
        controller.show_editor_requested.connect(() => {
            sink.on_show_editor_requested();
        });
        controller.show_search_requested.connect(() => {
            sink.on_show_search_requested();
        });
        controller.search_summary_changed.connect((text) => {
            sink.on_search_summary_changed(text);
        });
        controller.ai_status_refresh_requested.connect(() => {
            sink.on_ai_status_refresh_requested();
        });
        controller.project_selection_requested.connect((project_id) => {
            sink.on_project_selection_requested(project_id);
        });
        controller.card_selection_requested.connect((card_id) => {
            sink.on_card_selection_requested(card_id);
        });
        controller.search_selection_requested.connect((position) => {
            sink.on_search_selection_requested(position);
        });
        controller.ai_thread_title_changed.connect((title_text) => {
            sink.on_ai_thread_title_changed(title_text);
        });
        controller.ai_thread_selection_requested.connect((thread_id) => {
            sink.on_ai_thread_selection_requested(thread_id);
        });
        controller.api_client_ready.connect((api_client) => {
            sink.on_api_client_ready(api_client);
        });
        controller.card_trashed.connect((card_id) => {
            sink.on_card_trashed(card_id);
        });
        controller.activity_requested.connect((kind, message, project_id, card_id, details) => {
            sink.on_activity_requested(kind, message, project_id, card_id, details);
        });
    }
}

}
