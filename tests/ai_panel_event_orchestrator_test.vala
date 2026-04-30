using GLib;

namespace HolderLinux {

public class AiPanel : Object {
    public signal void send_requested();
    public signal void new_thread_requested();
    public signal void status_refresh_requested();
    public signal void pull_model_requested(string model_tag);
    public signal void error_reported(string title, string details);
    public signal void debug_log_requested(string line);

    public string prompt_text = "";
    public string? selected_runner_id = null;
    public string? selected_model_name = null;

    public int render_status_calls = 0;
    public AiCapabilitiesInfo? last_capabilities = null;
    public AiStatusInfo? last_status = null;
    public Gee.ArrayList<AiRunnerInfo>? last_runners = null;

    public int render_status_error_calls = 0;
    public string last_render_status_error = "";

    public int append_output_calls = 0;
    public string last_append_role = "";
    public string last_append_text = "";

    public int append_output_chunk_calls = 0;
    public string last_append_chunk = "";

    public int set_output_text_calls = 0;
    public string last_output_text = "";

    public int clear_prompt_calls = 0;
    public int set_send_enabled_calls = 0;
    public bool last_send_enabled = true;

    public string get_prompt_text() {
        return prompt_text;
    }

    public string? get_selected_runner_id() {
        return selected_runner_id;
    }

    public string? get_selected_model_name() {
        return selected_model_name;
    }

    public void render_status(AiCapabilitiesInfo capabilities,
                              AiStatusInfo status,
                              Gee.ArrayList<AiRunnerInfo> runners) {
        render_status_calls++;
        last_capabilities = capabilities;
        last_status = status;
        last_runners = runners;
    }

    public void render_status_error(string message) {
        render_status_error_calls++;
        last_render_status_error = message;
    }

    public void append_output(string role, string text) {
        append_output_calls++;
        last_append_role = role;
        last_append_text = text;
    }

    public void append_output_chunk(string text) {
        append_output_chunk_calls++;
        last_append_chunk = text;
    }

    public void set_output_text(string text) {
        set_output_text_calls++;
        last_output_text = text;
    }

    public void clear_prompt() {
        clear_prompt_calls++;
    }

    public void set_send_enabled(bool enabled) {
        set_send_enabled_calls++;
        last_send_enabled = enabled;
    }
}

public class AiRunController : Object {
    public signal void status_changed(string text);
    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void activity_requested(string kind,
                                          string message,
                                          string? project_id,
                                          string? card_id,
                                          ActivityDetails? details);
    public signal void render_status_requested(AiCapabilitiesInfo capabilities, AiStatusInfo status);
    public signal void render_status_error_requested(string message);
    public signal void append_output_requested(string role, string text);
    public signal void append_output_chunk_requested(string text);
    public signal void replace_output_requested(string text);
    public signal void clear_prompt_requested();
    public signal void set_send_enabled_requested(bool enabled);

    public int on_send_clicked_calls = 0;
    public string last_prompt = "";
    public string? last_runner_id = null;
    public string? last_model_name = null;

    public int create_thread_from_prompt_calls = 0;
    public int refresh_status_calls = 0;
    public int start_model_pull_calls = 0;
    public string last_pull_model_tag = "";

    private Gee.ArrayList<AiRunnerInfo> last_runners = new Gee.ArrayList<AiRunnerInfo>();

    public void on_send_clicked(string prompt_text,
                                string? selected_runner_id = null,
                                string? selected_model_name = null) {
        on_send_clicked_calls++;
        last_prompt = prompt_text;
        last_runner_id = selected_runner_id;
        last_model_name = selected_model_name;
    }

    public async void create_thread_from_prompt() {
        create_thread_from_prompt_calls++;
    }

    public async void refresh_status() {
        refresh_status_calls++;
    }

    public async void start_model_pull(string model_tag) {
        start_model_pull_calls++;
        last_pull_model_tag = model_tag;
    }

    public Gee.ArrayList<AiRunnerInfo> get_last_rendered_runners() {
        return last_runners;
    }

    public void set_last_rendered_runners(Gee.ArrayList<AiRunnerInfo> runners) {
        last_runners = runners;
    }
}

}

namespace HolderLinux.Tests {

private class RecordingAiPanelSink : Object, HolderLinux.IAiPanelEventSink {
    public int set_status_calls = 0;
    public string last_status = "";

    public int show_error_calls = 0;
    public string last_error_title = "";
    public string last_error_details = "";

    public int add_toast_calls = 0;
    public string last_toast = "";

    public int log_debug_calls = 0;
    public string last_debug = "";

    public int log_activity_calls = 0;
    public string last_activity_kind = "";
    public string last_activity_message = "";
    public string? last_activity_project_id = null;
    public string? last_activity_card_id = null;
    public HolderLinux.ActivityDetails? last_activity_details = null;

    public void set_status(string text) {
        set_status_calls++;
        last_status = text;
    }

    public void show_error(string title_text, string details) {
        show_error_calls++;
        last_error_title = title_text;
        last_error_details = details;
    }

    public void add_toast(string message) {
        add_toast_calls++;
        last_toast = message;
    }

    public void log_debug(string message) {
        log_debug_calls++;
        last_debug = message;
    }

    public void log_activity(string kind,
                             string message,
                             string? project_id,
                             string? card_id,
                             HolderLinux.ActivityDetails? details) {
        log_activity_calls++;
        last_activity_kind = kind;
        last_activity_message = message;
        last_activity_project_id = project_id;
        last_activity_card_id = card_id;
        last_activity_details = details;
    }
}

private delegate bool ConditionFunc();

private bool wait_for_condition(ConditionFunc condition, uint timeout_ms = 1000) {
    var loop = new MainLoop();
    uint timeout_id = 0;
    uint poll_id = 0;
    bool ok = false;

    poll_id = Timeout.add(10, () => {
        if (condition()) {
            ok = true;
            poll_id = 0;
            loop.quit();
            return Source.REMOVE;
        }
        return Source.CONTINUE;
    });

    timeout_id = Timeout.add(timeout_ms, () => {
        timeout_id = 0;
        loop.quit();
        return Source.REMOVE;
    });

    loop.run();
    if (timeout_id != 0) {
        Source.remove(timeout_id);
    }
    if (poll_id != 0) {
        Source.remove(poll_id);
    }
    return ok;
}

private HolderLinux.AiCapabilitiesInfo sample_capabilities() {
    return new HolderLinux.AiCapabilitiesInfo(
        true,
        "",
        100,
        "1.0",
        "User",
        new Gee.ArrayList<string>(),
        new Gee.ArrayList<string>()
    );
}

private HolderLinux.AiStatusInfo sample_status() {
    return new HolderLinux.AiStatusInfo(
        101,
        true,
        "",
        1,
        0,
        0,
        new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>()
    );
}

private Gee.ArrayList<HolderLinux.AiRunnerInfo> sample_runners() {
    var pulls = new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>();
    var models = new Gee.ArrayList<string>();
    models.add("tiny");
    var runtime = new HolderLinux.AiRunnerRuntimeInfo(true, true, true, 100, "1.0", "", models, pulls);
    var runners = new Gee.ArrayList<HolderLinux.AiRunnerInfo>();
    runners.add(new HolderLinux.AiRunnerInfo("runner-1", "Runner 1", "manual", "http://localhost:11434", "user", true, 1, 2, runtime));
    return runners;
}

private void test_ai_panel_signals_forward_to_controller_and_sink() {
    var panel = new HolderLinux.AiPanel();
    panel.prompt_text = "Hello";
    panel.selected_runner_id = "runner-1";
    panel.selected_model_name = "tiny";
    var controller = new HolderLinux.AiRunController();
    var sink = new RecordingAiPanelSink();
    var orchestrator = new HolderLinux.AiPanelEventOrchestrator(panel, controller, sink);
    orchestrator.bind();

    panel.send_requested();
    panel.new_thread_requested();
    panel.status_refresh_requested();
    panel.pull_model_requested("model-a");
    panel.error_reported("Boom", "Details");
    panel.debug_log_requested("debug line");

    assert(controller.on_send_clicked_calls == 1);
    assert(controller.last_prompt == "Hello");
    assert(controller.last_runner_id == "runner-1");
    assert(controller.last_model_name == "tiny");

    assert(wait_for_condition(() => controller.create_thread_from_prompt_calls == 1));
    assert(wait_for_condition(() => controller.refresh_status_calls == 1));
    assert(wait_for_condition(() => controller.start_model_pull_calls == 1));
    assert(controller.last_pull_model_tag == "model-a");

    assert(sink.show_error_calls == 1);
    assert(sink.last_error_title == "Boom");
    assert(sink.last_error_details == "Details");
    assert(sink.log_debug_calls == 1);
    assert(sink.last_debug == "debug line");
}

private void test_controller_signals_forward_to_sink_and_panel() {
    var panel = new HolderLinux.AiPanel();
    var controller = new HolderLinux.AiRunController();
    var sink = new RecordingAiPanelSink();
    var orchestrator = new HolderLinux.AiPanelEventOrchestrator(panel, controller, sink);
    orchestrator.bind();

    var capabilities = sample_capabilities();
    var status = sample_status();
    var runners = sample_runners();
    controller.set_last_rendered_runners(runners);
    var activity_details = new HolderLinux.CardCreatedDetails("Created", "parent-1");

    controller.status_changed("Refreshing");
    controller.error_reported("Failed", "No backend");
    controller.toast_requested("Toast text");
    controller.activity_requested("kind.example", "Activity happened", "proj-1", "card-1", activity_details);
    controller.render_status_requested(capabilities, status);
    controller.render_status_error_requested("status failed");
    controller.append_output_requested("Assistant", "Hello");
    controller.append_output_chunk_requested(" world");
    controller.replace_output_requested("New output");
    controller.clear_prompt_requested();
    controller.set_send_enabled_requested(false);

    assert(sink.set_status_calls == 1);
    assert(sink.last_status == "Refreshing");
    assert(sink.show_error_calls == 1);
    assert(sink.last_error_title == "Failed");
    assert(sink.last_error_details == "No backend");
    assert(sink.add_toast_calls == 1);
    assert(sink.last_toast == "Toast text");
    assert(sink.log_activity_calls == 1);
    assert(sink.last_activity_kind == "kind.example");
    assert(sink.last_activity_message == "Activity happened");
    assert(sink.last_activity_project_id == "proj-1");
    assert(sink.last_activity_card_id == "card-1");
    assert(sink.last_activity_details == activity_details);

    assert(panel.render_status_calls == 1);
    assert(panel.last_capabilities == capabilities);
    assert(panel.last_status == status);
    assert(panel.last_runners == runners);
    assert(panel.render_status_error_calls == 1);
    assert(panel.last_render_status_error == "status failed");
    assert(panel.append_output_calls == 1);
    assert(panel.last_append_role == "Assistant");
    assert(panel.last_append_text == "Hello");
    assert(panel.append_output_chunk_calls == 1);
    assert(panel.last_append_chunk == " world");
    assert(panel.set_output_text_calls == 1);
    assert(panel.last_output_text == "New output");
    assert(panel.clear_prompt_calls == 1);
    assert(panel.set_send_enabled_calls == 1);
    assert(!panel.last_send_enabled);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/ai-panel-event-orchestrator/panel-signals-forward", test_ai_panel_signals_forward_to_controller_and_sink);
    Test.add_func("/holder/ai-panel-event-orchestrator/controller-signals-forward", test_controller_signals_forward_to_sink_and_panel);
    return Test.run();
}

}
