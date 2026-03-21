namespace HolderLinux {

internal interface IAiPanelEventSink : Object {
    public abstract void set_status(string text);
    public abstract void show_error(string title_text, string details);
    public abstract void add_toast(string message);
    public abstract void log_debug(string message);
    public abstract void log_activity(string kind,
                                      string message,
                                      string? project_id,
                                      string? card_id,
                                      ActivityDetails? details);
}

internal class AiPanelEventOrchestrator : Object {
    private AiPanel ai_panel; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private AiRunController ai_run_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IAiPanelEventSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public AiPanelEventOrchestrator(AiPanel ai_panel,
                                    AiRunController ai_run_controller,
                                    IAiPanelEventSink sink) {
        this.ai_panel = ai_panel;
        this.ai_run_controller = ai_run_controller;
        this.sink = sink;
    }

    public void bind() {
        ai_panel.send_requested.connect(() => {
            ai_run_controller.on_send_clicked(ai_panel.get_prompt_text());
        });
        ai_panel.new_thread_requested.connect(() => {
            ai_run_controller.create_thread_from_prompt.begin();
        });
        ai_panel.status_refresh_requested.connect(() => {
            ai_run_controller.refresh_status.begin();
        });
        ai_panel.error_reported.connect((title_text, details) => {
            sink.show_error(title_text, details);
        });
        ai_panel.debug_log_requested.connect((line) => {
            sink.log_debug(line);
        });
        ai_panel.pull_model_requested.connect((model_tag) => {
            ai_run_controller.start_model_pull.begin(model_tag);
        });

        ai_run_controller.status_changed.connect((text) => {
            sink.set_status(text);
        });
        ai_run_controller.error_reported.connect((title_text, details) => {
            sink.show_error(title_text, details);
        });
        ai_run_controller.toast_requested.connect((message) => {
            sink.add_toast(message);
        });
        ai_run_controller.activity_requested.connect((kind, message, project_id, card_id, details) => {
            sink.log_activity(kind, message, project_id, card_id, details);
        });
        ai_run_controller.render_status_requested.connect((capabilities, status) => {
            ai_panel.render_status(capabilities, status);
        });
        ai_run_controller.render_status_error_requested.connect((message) => {
            ai_panel.render_status_error(message);
        });
        ai_run_controller.append_output_requested.connect((role, text) => {
            ai_panel.append_output(role, text);
        });
        ai_run_controller.append_output_chunk_requested.connect((text) => {
            ai_panel.append_output_chunk(text);
        });
        ai_run_controller.replace_output_requested.connect((text) => {
            ai_panel.set_output_text(text);
        });
        ai_run_controller.clear_prompt_requested.connect(() => {
            ai_panel.clear_prompt();
        });
        ai_run_controller.set_send_enabled_requested.connect((enabled) => {
            ai_panel.set_send_enabled(enabled);
        });
    }
}

}
