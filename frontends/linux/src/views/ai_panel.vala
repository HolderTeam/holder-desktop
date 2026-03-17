namespace HolderLinux {

public class AiPanel : Object {
    private class AiPanelRenderState : Object {
        public string thread_title = "Thread: none selected";
        public bool send_enabled = true;
        public string summary = "Not loaded";
        public string models = "";
        public string recommended = "";
        public Gee.ArrayList<string> recommended_models = new Gee.ArrayList<string>();
        public string runtime = "";
        public string pulls = "";
    }

    private Gtk.Label ai_summary_label;
    private Gtk.Label ai_models_label;
    private Gtk.Label ai_recommended_label;
    private Gtk.Box ai_recommended_buttons_box;
    private Gtk.Label ai_runtime_label;
    private Gtk.Label ai_pulls_label;
    private Gtk.TextBuffer ai_output_buffer;
    private Gtk.TextView ai_prompt_view;
    private Gtk.Label ai_assistant_thread_label;
    private Gtk.Button send_btn;
    private AiCatalogPanelView ai_catalog_panel;
    private AiConfigPanelView ai_config_panel;
    private AiPanelRenderState render_state;

    public Gtk.Widget widget { get; private set; }

    public signal void send_requested();
    public signal void new_thread_requested();
    public signal void status_refresh_requested();
    public signal void pull_model_requested(string model_tag);
    public signal void error_reported(string title, string details);
    public signal void debug_log_requested(string line);

    public AiPanel() {
        render_state = new AiPanelRenderState();
        ai_catalog_panel = new AiCatalogPanelView();
        ai_config_panel = new AiConfigPanelView();
        ai_catalog_panel.error_reported.connect((title, details) => {
            error_reported(title, details);
        });
        ai_catalog_panel.debug_log_requested.connect((line) => {
            debug_log_requested(line);
        });
        ai_config_panel.error_reported.connect((title, details) => {
            error_reported(title, details);
        });
        ai_config_panel.debug_log_requested.connect((line) => {
            debug_log_requested(line);
        });
        widget = build_ui();
        apply_render_state();
    }

    public void set_api_client(IHolderApi? api) {
        ai_catalog_panel.set_api_client(api);
        ai_config_panel.set_api_client(api);
    }

    public void refresh_catalog() {
        ai_catalog_panel.refresh.begin();
    }

    public void refresh_config(string? project_id = null) {
        ai_config_panel.refresh.begin(project_id);
    }

    public void set_thread_title(string? title) {
        if (title == null || title.strip().length == 0) {
            render_state.thread_title = "Thread: none selected";
            apply_render_state();
            return;
        }
        render_state.thread_title = "Thread: %s".printf(title);
        apply_render_state();
    }

    public string get_prompt_text() {
        var buffer = ai_prompt_view.get_buffer();
        Gtk.TextIter start;
        Gtk.TextIter end;
        buffer.get_bounds(out start, out end);
        return buffer.get_text(start, end, false);
    }

    public void clear_prompt() {
        ai_prompt_view.get_buffer().set_text("", -1);
    }

    public void set_send_enabled(bool enabled) {
        render_state.send_enabled = enabled;
        apply_render_state();
    }

    public void append_output(string role, string text) {
        Gtk.TextIter start;
        Gtk.TextIter end;
        ai_output_buffer.get_bounds(out start, out end);
        var existing = ai_output_buffer.get_text(start, end, false);
        var prefix = existing.length > 0 ? "\n\n" : "";
        ai_output_buffer.insert(ref end, "%s%s:\n%s".printf(prefix, role, text), -1);
    }

    public void append_output_chunk(string text) {
        Gtk.TextIter end;
        ai_output_buffer.get_end_iter(out end);
        ai_output_buffer.insert(ref end, text, -1);
    }

    public void render_status(AiCapabilitiesInfo capabilities, AiStatusInfo status) {
        render_state.summary = "Runner: %s | Caste: %s | Version: %s".printf(
            capabilities.runner_available ? "available" : "unavailable",
            capabilities.caste_name.length > 0 ? capabilities.caste_name : "unknown",
            capabilities.runner_version.length > 0 ? capabilities.runner_version : "unknown"
        );
        if (capabilities.runner_error.length > 0) {
            render_state.summary += "\nError: " + capabilities.runner_error;
        }

        render_state.models = "Installed models (%d): %s".printf(
            capabilities.models.size,
            join_list(capabilities.models)
        );
        render_state.recommended = "Recommended install: %s".printf(join_list(capabilities.recommended_install));
        render_state.recommended_models = new Gee.ArrayList<string>();
        foreach (var model in capabilities.recommended_install) {
            render_state.recommended_models.add(model);
        }
        render_state.runtime = "Active runs: %lld | Active pulls: %lld | Cloud providers configured: %lld".printf(
            status.active_runs,
            status.active_pull_jobs,
            status.cloud_configured_providers
        );
        render_state.pulls = "Pull jobs: %s".printf(join_list(status.pull_jobs));
        apply_render_state();
    }

    public void render_status_error(string message) {
        render_state.summary = "AI status unavailable";
        render_state.models = "";
        render_state.recommended = "";
        render_state.recommended_models = new Gee.ArrayList<string>();
        render_state.runtime = message;
        render_state.pulls = "";
        apply_render_state();
    }

    private Gtk.Widget build_ui() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_start(8);
        box.set_margin_end(8);

        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var title = new Gtk.Label("AI");
        title.add_css_class("title-4");
        title.set_halign(Gtk.Align.START);
        title.set_hexpand(true);
        var refresh = new Gtk.Button.from_icon_name("view-refresh-symbolic");
        refresh.set_tooltip_text("Refresh AI status");
        refresh.clicked.connect(() => {
            status_refresh_requested();
        });
        header.append(title);
        header.append(refresh);
        box.append(header);

        var stack = new Gtk.Stack();
        stack.set_vexpand(true);
        stack.set_hexpand(true);
        var switcher = new Gtk.StackSwitcher();
        switcher.set_stack(stack);
        switcher.set_halign(Gtk.Align.START);
        box.append(switcher);

        var assistant = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        ai_assistant_thread_label = new Gtk.Label("Thread: none selected") { xalign = 0.0f };
        ai_assistant_thread_label.add_css_class("dim-label");
        assistant.append(ai_assistant_thread_label);

        ai_output_buffer = new Gtk.TextBuffer(null);
        var ai_output_view = new Gtk.TextView.with_buffer(ai_output_buffer);
        ai_output_view.set_editable(false);
        ai_output_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        ai_output_view.set_vexpand(true);

        var output_scroll = new Gtk.ScrolledWindow();
        output_scroll.set_vexpand(true);
        output_scroll.set_child(ai_output_view);
        assistant.append(output_scroll);

        ai_prompt_view = new Gtk.TextView();
        ai_prompt_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        ai_prompt_view.set_vexpand(false);
        ai_prompt_view.set_size_request(-1, 96);

        var prompt_scroll = new Gtk.ScrolledWindow();
        prompt_scroll.set_vexpand(false);
        prompt_scroll.set_child(ai_prompt_view);
        assistant.append(prompt_scroll);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        send_btn = new Gtk.Button.with_label("Send");
        send_btn.clicked.connect(() => {
            send_requested();
        });
        var new_thread_btn = new Gtk.Button.with_label("New Thread");
        new_thread_btn.clicked.connect(() => {
            new_thread_requested();
        });
        actions.append(send_btn);
        actions.append(new_thread_btn);
        assistant.append(actions);

        var status_page = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        ai_summary_label = new Gtk.Label("Not loaded") { xalign = 0.0f };
        ai_summary_label.set_wrap(true);
        ai_models_label = new Gtk.Label("") { xalign = 0.0f };
        ai_models_label.set_wrap(true);
        ai_recommended_label = new Gtk.Label("") { xalign = 0.0f };
        ai_recommended_label.set_wrap(true);
        ai_recommended_buttons_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        ai_runtime_label = new Gtk.Label("") { xalign = 0.0f };
        ai_runtime_label.set_wrap(true);
        ai_pulls_label = new Gtk.Label("") { xalign = 0.0f };
        ai_pulls_label.set_wrap(true);

        status_page.append(ai_summary_label);
        status_page.append(ai_models_label);
        status_page.append(ai_recommended_label);
        status_page.append(ai_recommended_buttons_box);
        status_page.append(ai_runtime_label);
        status_page.append(ai_pulls_label);

        stack.add_titled(assistant, "assistant", "Assistant");
        stack.add_titled(status_page, "status", "Status");
        stack.add_titled(ai_catalog_panel.widget, "catalog", "Catalog");
        stack.add_titled(ai_config_panel.widget, "config", "Config");
        stack.set_visible_child_name("assistant");

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_vexpand(true);
        scroll.set_child(stack);
        box.append(scroll);
        return box;
    }

    private void rebuild_recommended_pull_buttons(Gee.ArrayList<string> recommended_models) {
        Gtk.Widget? child = ai_recommended_buttons_box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            ai_recommended_buttons_box.remove(child);
            child = next;
        }

        if (recommended_models.size == 0) {
            var label = new Gtk.Label("No recommended model pulls right now.") { xalign = 0.0f };
            label.add_css_class("dim-label");
            ai_recommended_buttons_box.append(label);
            return;
        }

        for (int i = 0; i < recommended_models.size; i++) {
            var model_tag = recommended_models[i];
            var btn = new Gtk.Button.with_label("Pull %s".printf(model_tag));
            btn.set_halign(Gtk.Align.START);
            btn.clicked.connect(() => {
                pull_model_requested(model_tag);
            });
            ai_recommended_buttons_box.append(btn);
        }
    }

    private void apply_render_state() {
        ai_assistant_thread_label.set_text(render_state.thread_title);
        send_btn.set_sensitive(render_state.send_enabled);
        ai_summary_label.set_text(render_state.summary);
        ai_models_label.set_text(render_state.models);
        ai_recommended_label.set_text(render_state.recommended);
        ai_runtime_label.set_text(render_state.runtime);
        ai_pulls_label.set_text(render_state.pulls);
        rebuild_recommended_pull_buttons(render_state.recommended_models);
    }

    private string join_list(Gee.ArrayList<string> values) {
        if (values.size == 0) {
            return "none";
        }
        var builder = new StringBuilder();
        for (int i = 0; i < values.size; i++) {
            if (i > 0) {
                builder.append(", ");
            }
            builder.append(values[i]);
        }
        return builder.str;
    }
}

}
