namespace HolderLinux {

public class AiRunController : Object {
    private MainController main_controller;
    private bool ai_run_in_flight = false;
    private bool panel_visible = false;
    private uint ai_poll_id = 0;
    private const uint AI_POLL_INTERVAL_MS = 2000;

    public signal void status_changed(string text);
    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void render_status_requested(AiCapabilitiesInfo capabilities, AiStatusInfo status);
    public signal void render_status_error_requested(string message);
    public signal void append_output_requested(string role, string text);
    public signal void append_output_chunk_requested(string text);
    public signal void clear_prompt_requested();
    public signal void set_send_enabled_requested(bool enabled);

    public AiRunController(MainController main_controller) {
        this.main_controller = main_controller;
    }

    public void set_panel_visible(bool visible) {
        panel_visible = visible;
        if (visible) {
            refresh_status.begin();
            return;
        }
        stop_ai_polling();
    }

    public async void refresh_status() {
        var api = main_controller.get_api_client();
        if (api == null) {
            return;
        }

        var project_id = main_controller.selected_project_id();
        try {
            var capabilities = yield api.get_ai_capabilities(project_id);
            var status = yield api.get_ai_status();
            render_status_requested(capabilities, status);
            update_ai_polling(status.active_pull_jobs > 0);
        } catch (Error e) {
            render_status_error_requested(e.message);
            stop_ai_polling();
        }
    }

    public void on_send_clicked(string prompt_text) {
        if (ai_run_in_flight) {
            status_changed("AI run already in progress...");
            return;
        }

        var prompt = prompt_text.strip();
        if (prompt.length == 0) {
            error_reported("Prompt required", "Type a prompt before sending.");
            return;
        }
        if (main_controller.get_current_project() == null) {
            error_reported("No project selected", "Select a project before using the assistant.");
            return;
        }

        var current_thread = main_controller.get_current_ai_thread();
        if (current_thread == null) {
            create_ai_thread_named.begin(
                "Thread %s".printf(main_controller.now_epoch_seconds().to_string()),
                prompt
            );
            return;
        }

        send_prompt_to_ai.begin(prompt, current_thread.thread_id);
    }

    public async void create_thread_from_prompt() {
        yield create_ai_thread_named("Thread %s".printf(main_controller.now_epoch_seconds().to_string()), null);
    }

    public async void start_model_pull(string model_tag) {
        var api = main_controller.get_api_client();
        if (api == null) {
            return;
        }

        status_changed("Starting pull for %s...".printf(model_tag));
        try {
            var job_id = yield api.start_ai_runner_pull(model_tag);
            toast_requested("Started pull: %s".printf(model_tag));
            if (job_id.length > 0) {
                status_changed("Pull job started: %s".printf(job_id));
            } else {
                status_changed("Pull started: %s".printf(model_tag));
            }
            refresh_status.begin();
        } catch (Error e) {
            error_reported("Failed to start model pull", e.message);
        }
    }

    public void stop() {
        stop_ai_polling();
    }

    private async void create_ai_thread_named(string title, string? continue_prompt) {
        var current_project = main_controller.get_current_project();
        if (current_project == null) {
            error_reported("Cannot create thread", "No project/API context.");
            return;
        }
        try {
            var thread_id = yield main_controller.create_ai_thread(title);
            yield main_controller.reload_ai_threads_for_project(current_project.project_id);
            if (thread_id.length > 0) {
                main_controller.select_ai_thread_by_id(thread_id);
            }
            toast_requested("Created AI thread");
            if (continue_prompt != null && continue_prompt.strip().length > 0) {
                send_prompt_to_ai.begin(continue_prompt, thread_id);
            }
        } catch (Error e) {
            error_reported("Failed to create AI thread", e.message);
        }
    }

    private async void send_prompt_to_ai(string prompt, string? preferred_thread_id = null) {
        var api = main_controller.get_api_client();
        var current_project = main_controller.get_current_project();
        var current_ai_thread = main_controller.get_current_ai_thread();
        var current_card = main_controller.get_current_card();
        var thread_id = preferred_thread_id;
        if (thread_id == null || thread_id.length == 0) {
            thread_id = current_ai_thread != null ? current_ai_thread.thread_id : null;
        }
        if (api == null || current_project == null || thread_id == null || thread_id.length == 0) {
            error_reported("Cannot run AI", "Missing API, project, or thread context.");
            return;
        }

        append_output_requested("You", prompt);
        clear_prompt_requested();
        append_output_requested("Assistant", "");

        ai_run_in_flight = true;
        set_send_enabled_requested(false);
        status_changed("Running AI...");
        try {
            var context_card_id = current_card != null ? current_card.card_id : null;
            var context_card_title = current_card != null ? current_card.title : null;
            var context_card_body = current_card != null ? current_card.content : null;
            yield api.run_ai_stream(
                prompt,
                current_project.project_id,
                thread_id,
                context_card_id,
                context_card_title,
                context_card_body,
                (event_name, data) => {
                    handle_ai_run_event(event_name, data);
                }
            );
            append_output_chunk_requested("\n");
            status_changed("AI run complete");
        } catch (Error e) {
            append_output_requested("System", "AI run failed: %s".printf(e.message));
            error_reported("AI run failed", e.message);
        } finally {
            ai_run_in_flight = false;
            set_send_enabled_requested(true);
            refresh_status.begin();
        }
    }

    private void update_ai_polling(bool should_poll) {
        if (!panel_visible) {
            stop_ai_polling();
            return;
        }
        if (should_poll) {
            start_ai_polling();
            return;
        }
        stop_ai_polling();
    }

    private void start_ai_polling() {
        if (ai_poll_id != 0) {
            return;
        }
        ai_poll_id = Timeout.add(AI_POLL_INTERVAL_MS, () => {
            if (!panel_visible) {
                ai_poll_id = 0;
                return Source.REMOVE;
            }
            refresh_status.begin();
            return Source.CONTINUE;
        });
    }

    private void stop_ai_polling() {
        if (ai_poll_id == 0) {
            return;
        }
        Source.remove(ai_poll_id);
        ai_poll_id = 0;
    }

    private void handle_ai_run_event(string event_name, Json.Object data) {
        switch (event_name) {
            case "chunk":
                append_output_chunk_requested(json_string_member_or_empty(data, "delta"));
                break;
            case "progress":
                var message = json_string_member_or_empty(data, "message");
                if (message.length > 0) {
                    append_output_requested("System", message);
                }
                break;
            case "fallback":
                var model = json_string_member_or_empty(data, "model");
                var error = json_string_member_or_empty(data, "error");
                var detail = model.length > 0 ? "Fallback from %s".printf(model) : "Fallback";
                if (error.length > 0) {
                    detail += ": " + error;
                }
                append_output_requested("System", detail);
                break;
            case "failed":
                var failed = json_string_member_or_empty(data, "error");
                append_output_requested("System", failed.length > 0 ? failed : "Run failed.");
                break;
            case "done":
                var model_done = json_string_member_or_empty(data, "model");
                if (model_done.length > 0) {
                    append_output_requested("System", "Completed with %s".printf(model_done));
                }
                break;
            default:
                break;
        }
    }

    private string json_string_member_or_empty(Json.Object obj, string key) {
        if (!obj.has_member(key)) {
            return "";
        }
        var node = obj.get_member(key);
        if (node == null || node.get_node_type() == Json.NodeType.NULL) {
            return "";
        }
        return obj.get_string_member(key);
    }
}

}
