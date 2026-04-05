namespace HolderLinux {

public class AiPanel : Object {
    private class AiPanelRenderState : Object {
        public string thread_title = "Thread: none selected";
        public bool send_enabled = true;
    }

    private IHolderApi? api_client;
    private Gtk.TextBuffer ai_output_buffer;
    private Gtk.TextView ai_prompt_view;
    private Gtk.Label ai_assistant_thread_label;
    private Gtk.DropDown ai_runner_dropdown;
    private Gtk.DropDown ai_model_dropdown;
    private Gtk.StringList ai_runner_options;
    private Gtk.StringList ai_model_options;
    private Gtk.Box ai_nudges_section;
    private Gtk.Box ai_nudges_box;
    private Gtk.Button send_btn;
    private AiConfigPanelView ai_config_panel;
    private AiPanelRenderState render_state;
    private string? nudges_project_id;
    private string? nudges_card_id;
    private uint nudges_request_serial = 0;
    private Gee.ArrayList<AiRunnerInfo> run_target_runners = new Gee.ArrayList<AiRunnerInfo>();

    public Gtk.Widget widget { get; private set; }

    public signal void send_requested();
    public signal void new_thread_requested();
    public signal void status_refresh_requested();
    public signal void pull_model_requested(string model_tag);
    public signal void error_reported(string title, string details);
    public signal void debug_log_requested(string line);

    public AiPanel() {
        render_state = new AiPanelRenderState();
        ai_config_panel = new AiConfigPanelView();
        ai_config_panel.error_reported.connect((title, details) => {
            error_reported(title, details);
        });
        ai_config_panel.debug_log_requested.connect((line) => {
            debug_log_requested(line);
        });
        ai_config_panel.pull_model_requested.connect((model_tag) => {
            pull_model_requested(model_tag);
        });
        widget = build_ui();
        apply_render_state();
    }

    public void set_api_client(IHolderApi? api) {
        api_client = api;
        ai_config_panel.set_api_client(api);
    }

    public void refresh_config(string? project_id = null) {
        ai_config_panel.refresh.begin(project_id);
    }

    public void refresh_nudges(string? project_id = null, string? card_id = null) {
        nudges_project_id = project_id;
        nudges_card_id = card_id;
        var request_serial = ++nudges_request_serial;
        refresh_nudges_async.begin(request_serial, project_id, card_id);
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

    public string? get_selected_runner_id() {
        if (run_target_runners.size == 0) {
            return null;
        }
        var selected = ai_runner_dropdown.get_selected();
        if (selected == Gtk.INVALID_LIST_POSITION || selected >= run_target_runners.size) {
            return run_target_runners[0].runner_id;
        }
        return run_target_runners[(int) selected].runner_id;
    }

    public string? get_selected_model_name() {
        var selected = ai_model_dropdown.get_selected();
        if (selected == Gtk.INVALID_LIST_POSITION || selected == 0 || selected >= ai_model_options.get_n_items()) {
            return null;
        }
        return ai_model_options.get_string(selected);
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

    public void set_output_text(string text) {
        ai_output_buffer.set_text(text, -1);
    }

    public void render_status(AiCapabilitiesInfo capabilities,
                              AiStatusInfo status,
                              Gee.ArrayList<AiRunnerInfo> runners) {
        ai_config_panel.render_local_models(capabilities, status);
        update_run_target_controls(runners);
    }

    public void render_status_error(string message) {
        ai_config_panel.render_local_models_error(message);
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

        var run_target_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        ai_runner_options = new Gtk.StringList(null);
        ai_runner_dropdown = new Gtk.DropDown(ai_runner_options, null);
        ai_runner_dropdown.set_hexpand(true);
        ai_runner_dropdown.notify["selected"].connect(() => {
            refresh_model_dropdown_for_selected_runner();
        });
        ai_model_options = new Gtk.StringList(null);
        ai_model_dropdown = new Gtk.DropDown(ai_model_options, null);
        ai_model_dropdown.set_hexpand(true);
        run_target_box.append(ai_runner_dropdown);
        run_target_box.append(ai_model_dropdown);
        assistant.append(run_target_box);

        ai_nudges_section = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        ai_nudges_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        ai_nudges_section.append(ai_nudges_box);
        ai_nudges_section.set_visible(false);
        assistant.append(ai_nudges_section);

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

        stack.add_titled(assistant, "assistant", "Assistant");
        stack.add_titled(ai_config_panel.widget, "config", "Config");
        stack.set_visible_child_name("assistant");

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_vexpand(true);
        scroll.set_child(stack);
        box.append(scroll);
        return box;
    }

    private void apply_render_state() {
        ai_assistant_thread_label.set_text(render_state.thread_title);
        send_btn.set_sensitive(render_state.send_enabled);
    }

    private void update_run_target_controls(Gee.ArrayList<AiRunnerInfo> runners) {
        var previous_runner_id = get_selected_runner_id();
        var previous_model_name = get_selected_model_name();

        run_target_runners.clear();
        while (ai_runner_options.get_n_items() > 0) {
            ai_runner_options.remove(ai_runner_options.get_n_items() - 1);
        }

        foreach (var runner in runners) {
            run_target_runners.add(runner);
            var label = runner.name;
            if (runner.runtime.available) {
                label += " (available)";
            }
            ai_runner_options.append(label);
        }

        uint selected_runner_index = 0;
        if (previous_runner_id != null) {
            for (int i = 0; i < run_target_runners.size; i++) {
                if (run_target_runners[i].runner_id == previous_runner_id) {
                    selected_runner_index = (uint) i;
                    break;
                }
            }
        }

        ai_runner_dropdown.set_selected(selected_runner_index);
        ai_runner_dropdown.set_sensitive(run_target_runners.size > 0);
        refresh_model_dropdown_for_selected_runner(previous_model_name);
    }

    private void refresh_model_dropdown_for_selected_runner(string? preferred_model_name = null) {
        while (ai_model_options.get_n_items() > 0) {
            ai_model_options.remove(ai_model_options.get_n_items() - 1);
        }
        ai_model_options.append("(auto)");

        var runner = selected_run_target_runner();
        uint selected_model_index = 0;
        if (runner != null) {
            for (int i = 0; i < runner.runtime.models.size; i++) {
                var model_name = runner.runtime.models[i];
                ai_model_options.append(model_name);
                if (preferred_model_name != null && preferred_model_name == model_name) {
                    selected_model_index = (uint) i + 1;
                }
            }
        }

        ai_model_dropdown.set_selected(selected_model_index);
        ai_model_dropdown.set_sensitive(runner != null && runner.runtime.models.size > 0);
    }

    private AiRunnerInfo? selected_run_target_runner() {
        if (run_target_runners.size == 0) {
            return null;
        }
        var selected = ai_runner_dropdown.get_selected();
        if (selected == Gtk.INVALID_LIST_POSITION || selected >= run_target_runners.size) {
            return run_target_runners[0];
        }
        return run_target_runners[(int) selected];
    }

    private async void refresh_nudges_async(uint request_serial,
                                            string? project_id,
                                            string? card_id) {
        if (api_client == null || project_id == null || project_id.strip().length == 0) {
            if (request_serial == nudges_request_serial) {
                render_nudges(new Gee.ArrayList<AiNudge>());
            }
            return;
        }
        try {
            var nudges = yield api_client.list_ai_nudges(project_id, card_id);
            if (request_serial != nudges_request_serial) {
                return;
            }
            render_nudges(nudges);
        } catch (Error e) {
            if (request_serial != nudges_request_serial) {
                return;
            }
            render_nudges(new Gee.ArrayList<AiNudge>());
            debug_log_requested("NUDGE_LIST_ERROR %s".printf(e.message));
        }
    }

    private void render_nudges(Gee.List<AiNudge> nudges) {
        Gtk.Widget? child = ai_nudges_box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            ai_nudges_box.remove(child);
            child = next;
        }

        if (nudges.size == 0) {
            ai_nudges_section.set_visible(false);
            return;
        }

        ai_nudges_section.set_visible(true);
        foreach (var nudge in nudges) {
            ai_nudges_box.append(build_nudge_widget(nudge));
        }
    }

    private Gtk.Widget build_nudge_widget(AiNudge nudge) {
        var frame = new Gtk.Frame(null);
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_start(8);
        box.set_margin_end(8);

        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var title = new Gtk.Label(nudge.title) { xalign = 0.0f };
        title.add_css_class("heading");
        title.set_hexpand(true);
        var dismiss_btn = new Gtk.Button.with_label("Dismiss");
        dismiss_btn.clicked.connect(() => {
            dismiss_nudge.begin(nudge.nudge_id);
        });
        header.append(title);
        header.append(dismiss_btn);

        var body = new Gtk.Label(nudge.body) { xalign = 0.0f };
        body.set_wrap(true);

        box.append(header);
        box.append(body);
        frame.set_child(box);
        return frame;
    }

    private async void dismiss_nudge(string nudge_id) {
        if (api_client == null) {
            return;
        }
        try {
            yield api_client.dismiss_ai_nudge(nudge_id);
            refresh_nudges(nudges_project_id, nudges_card_id);
        } catch (Error e) {
            debug_log_requested("NUDGE_DISMISS_ERROR %s".printf(e.message));
        }
    }
}

}
