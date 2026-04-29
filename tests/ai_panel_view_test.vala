using GLib;

namespace HolderLinuxTests {

private Gtk.Button? find_button_with_label(Gtk.Widget root, string label) {
    if (root is Gtk.Button) {
        var button = (Gtk.Button) root;
        if (button.get_label() == label) {
            return button;
        }
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_button_with_label(child, label);
        if (match != null) {
            return match;
        }
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.Button? find_button_with_tooltip(Gtk.Widget root, string tooltip) {
    if (root is Gtk.Button && root.get_tooltip_text() == tooltip) {
        return (Gtk.Button) root;
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_button_with_tooltip(child, tooltip);
        if (match != null) {
            return match;
        }
        child = child.get_next_sibling();
    }
    return null;
}

private string collect_widget_text(Gtk.Widget widget) {
    if (widget is Gtk.Label) {
        return ((Gtk.Label) widget).get_text();
    }

    var builder = new StringBuilder();
    Gtk.Widget? child = widget.get_first_child();
    while (child != null) {
        builder.append(collect_widget_text(child));
        builder.append("\n");
        child = child.get_next_sibling();
    }
    return builder.str;
}

private void collect_text_views(Gtk.Widget root, Gee.ArrayList<Gtk.TextView> views) {
    if (root is Gtk.TextView) {
        views.add((Gtk.TextView) root);
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        collect_text_views(child, views);
        child = child.get_next_sibling();
    }
}

private Gtk.TextView panel_prompt_view(HolderLinux.AiPanel panel) {
    var views = new Gee.ArrayList<Gtk.TextView>();
    collect_text_views(panel.widget, views);
    foreach (var view in views) {
        if (view.get_editable()) {
            return view;
        }
    }
    assert_not_reached();
}

private Gtk.TextView panel_output_view(HolderLinux.AiPanel panel) {
    var views = new Gee.ArrayList<Gtk.TextView>();
    collect_text_views(panel.widget, views);
    foreach (var view in views) {
        if (!view.get_editable()) {
            return view;
        }
    }
    assert_not_reached();
}

private string text_buffer_contents(Gtk.TextBuffer buffer) {
    Gtk.TextIter start;
    Gtk.TextIter end;
    buffer.get_bounds(out start, out end);
    return buffer.get_text(start, end, false);
}

private string output_text(HolderLinux.AiPanel panel) {
    return text_buffer_contents(panel_output_view(panel).get_buffer());
}

private Gtk.Label? find_label_with_prefix(Gtk.Widget root, string prefix) {
    if (root is Gtk.Label) {
        var label = (Gtk.Label) root;
        if (label.get_text().has_prefix(prefix)) {
            return label;
        }
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_label_with_prefix(child, prefix);
        if (match != null) {
            return match;
        }
        child = child.get_next_sibling();
    }
    return null;
}

private void collect_dropdowns(Gtk.Widget root, Gee.ArrayList<Gtk.DropDown> dropdowns) {
    if (root is Gtk.DropDown) {
        dropdowns.add((Gtk.DropDown) root);
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        collect_dropdowns(child, dropdowns);
        child = child.get_next_sibling();
    }
}

private Gtk.DropDown panel_dropdown(HolderLinux.AiPanel panel, int index) {
    var dropdowns = new Gee.ArrayList<Gtk.DropDown>();
    collect_dropdowns(panel.widget, dropdowns);
    assert(dropdowns.size > index);
    return dropdowns[index];
}

private uint dropdown_item_count(Gtk.DropDown dropdown) {
    var model = dropdown.get_model();
    assert(model != null);
    return ((!) model).get_n_items();
}

private HolderLinux.AiRunnerInfo runner(string id,
                                        string name,
                                        bool available,
                                        string[] model_names) {
    var models = new Gee.ArrayList<string>();
    foreach (var model in model_names) {
        models.add(model);
    }
    return new HolderLinux.AiRunnerInfo(
        id,
        name,
        "ollama",
        "http://localhost:11434",
        "manual",
        true,
        1,
        1,
        new HolderLinux.AiRunnerRuntimeInfo(
            true,
            available,
            false,
            1,
            "1.0",
            "",
            models,
            new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>()
        )
    );
}

private HolderLinux.AiCapabilitiesInfo capabilities() {
    return new HolderLinux.AiCapabilitiesInfo(
        true,
        "",
        1,
        "1.0",
        "user",
        new Gee.ArrayList<string>(),
        new Gee.ArrayList<string>()
    );
}

private HolderLinux.AiStatusInfo status() {
    return new HolderLinux.AiStatusInfo(
        1,
        true,
        "",
        0,
        0,
        0,
        new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>()
    );
}

private HolderLinux.AiNudge title_nudge() {
    var suggestions = new Gee.ArrayList<string>();
    suggestions.add("Thread Roles in Holder");
    suggestions.add("Socket Mechanics vs App Work");
    return new HolderLinux.AiNudge(
        "n1",
        "card.title_suggestion",
        "p1",
        "c1",
        "Suggest a title",
        "",
        "fp",
        "commit",
        1,
        suggestions
    );
}

private void test_prompt_output_thread_state_and_buttons() {
    var panel = new HolderLinux.AiPanel();
    int send_calls = 0;
    int new_thread_calls = 0;
    int refresh_calls = 0;
    panel.send_requested.connect(() => {
        send_calls++;
    });
    panel.new_thread_requested.connect(() => {
        new_thread_calls++;
    });
    panel.status_refresh_requested.connect(() => {
        refresh_calls++;
    });

    panel_prompt_view(panel).get_buffer().set_text("hello", -1);
    assert(panel.get_prompt_text() == "hello");
    panel.clear_prompt();
    assert(panel.get_prompt_text() == "");

    panel.set_thread_title(null);
    assert(((!) find_label_with_prefix(panel.widget, "Thread:")).get_text() == "Thread: none selected");
    panel.set_thread_title("  ");
    assert(((!) find_label_with_prefix(panel.widget, "Thread:")).get_text() == "Thread: none selected");
    panel.set_thread_title("Planning");
    assert(((!) find_label_with_prefix(panel.widget, "Thread:")).get_text() == "Thread: Planning");

    panel.append_output("user", "First");
    panel.append_output("assistant", "Second");
    assert(output_text(panel).contains("user:\nFirst"));
    assert(output_text(panel).contains("assistant:\nSecond"));
    panel.append_output_chunk(" chunk");
    assert(output_text(panel).has_suffix(" chunk"));
    panel.set_output_text("replacement");
    assert(output_text(panel) == "replacement");

    panel.set_send_enabled(false);
    assert(!((!) find_button_with_label(panel.widget, "Send")).get_sensitive());
    panel.set_send_enabled(true);
    assert(((!) find_button_with_label(panel.widget, "Send")).get_sensitive());

    var send_btn = find_button_with_label(panel.widget, "Send");
    var new_thread_btn = find_button_with_label(panel.widget, "New Thread");
    var refresh_btn = find_button_with_tooltip(panel.widget, "Refresh AI status");
    assert(send_btn != null);
    assert(new_thread_btn != null);
    assert(refresh_btn != null);

    ((!) send_btn).clicked();
    ((!) new_thread_btn).clicked();
    ((!) refresh_btn).clicked();
    assert(send_calls == 1);
    assert(new_thread_calls == 1);
    assert(refresh_calls == 1);
}

private void test_render_status_updates_runner_and_model_selection() {
    var panel = new HolderLinux.AiPanel();
    var runners = new Gee.ArrayList<HolderLinux.AiRunnerInfo>();
    runners.add(runner("r1", "Local", true, {"mistral", "llama"}));
    runners.add(runner("r2", "Remote", false, {"gpt"}));

    panel.render_status(capabilities(), status(), runners);

    var runner_dropdown = panel_dropdown(panel, 0);
    var model_dropdown = panel_dropdown(panel, 1);
    assert(dropdown_item_count(runner_dropdown) == 2);
    assert(dropdown_item_count(model_dropdown) == 3);
    assert(panel.get_selected_runner_id() == "r1");
    assert(panel.get_selected_model_name() == null);

    model_dropdown.set_selected(2);
    assert(panel.get_selected_model_name() == "llama");

    runner_dropdown.set_selected(1);
    assert(panel.get_selected_runner_id() == "r2");
    assert(dropdown_item_count(model_dropdown) == 2);
    model_dropdown.set_selected(1);
    assert(panel.get_selected_model_name() == "gpt");

    panel.render_status_error("offline");
}

private void test_refresh_nudges_without_context_hides_section() {
    var panel = new HolderLinux.AiPanel();
    panel.refresh_nudges(null, null);

    assert(wait_for_condition(() => !collect_widget_text(panel.widget).contains("Suggest a title")));
}

private void test_title_suggestion_nudge_renders_and_applies() {
    var api = new MainControllerFakeApi();
    api.ai_nudges.add(title_nudge());

    var panel = new HolderLinux.AiPanel();
    panel.set_api_client(api);

    string applied_nudge_id = "";
    string applied_card_id = "";
    string applied_title = "";
    panel.title_suggestion_apply_requested.connect((nudge_id, card_id, title) => {
        applied_nudge_id = nudge_id;
        applied_card_id = card_id;
        applied_title = title;
    });

    panel.refresh_nudges("p1", "c1");
    assert(wait_for_condition(() => collect_widget_text(panel.widget).contains("Thread Roles in Holder")));
    assert(api.list_ai_nudges_calls == 1);
    assert(api.last_nudge_project_id == "p1");
    assert(api.last_nudge_card_id == "c1");

    var text = collect_widget_text(panel.widget);
    assert(text.contains("Suggest a title"));
    assert(text.contains("Thread Roles in Holder"));
    assert(text.contains("Socket Mechanics vs App Work"));

    var apply_btn = find_button_with_label(panel.widget, "Apply");
    assert(apply_btn != null);
    ((!) apply_btn).clicked();

    assert(applied_nudge_id == "n1");
    assert(applied_card_id == "c1");
    assert(applied_title == "Thread Roles in Holder");
}

private void test_dismiss_nudge_calls_api_and_refreshes() {
    var api = new MainControllerFakeApi();
    api.ai_nudges.add(title_nudge());

    var panel = new HolderLinux.AiPanel();
    panel.set_api_client(api);
    panel.refresh_nudges("p1", "c1");
    assert(wait_for_condition(() => collect_widget_text(panel.widget).contains("Thread Roles in Holder")));

    var dismiss_btn = find_button_with_label(panel.widget, "Dismiss");
    assert(dismiss_btn != null);
    ((!) dismiss_btn).clicked();

    assert(wait_for_condition(() => api.dismiss_ai_nudge_calls == 1));
    assert(api.last_dismissed_nudge_id == "n1");
    assert(wait_for_condition(() => api.list_ai_nudges_calls >= 2));
}

private void test_refresh_nudges_failure_hides_section_and_logs_debug() {
    var api = new MainControllerFakeApi();
    api.ai_nudges.add(title_nudge());
    api.fail_list_ai_nudges = true;

    var panel = new HolderLinux.AiPanel();
    panel.set_api_client(api);
    string debug_line = "";
    panel.debug_log_requested.connect((line) => {
        debug_line = line;
    });

    panel.refresh_nudges("p1", "c1");

    assert(wait_for_condition(() => debug_line.contains("NUDGE_LIST_ERROR")));
    assert(!collect_widget_text(panel.widget).contains("Suggest a title"));
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping AI panel view tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/holder/ai-panel/prompt-output-thread-buttons", test_prompt_output_thread_state_and_buttons);
    Test.add_func("/holder/ai-panel/render-status-runners-models", test_render_status_updates_runner_and_model_selection);
    Test.add_func("/holder/ai-panel/nudges-no-context", test_refresh_nudges_without_context_hides_section);
    Test.add_func("/holder/ai-panel/title-suggestion-apply", test_title_suggestion_nudge_renders_and_applies);
    Test.add_func("/holder/ai-panel/dismiss-nudge", test_dismiss_nudge_calls_api_and_refreshes);
    Test.add_func("/holder/ai-panel/nudge-refresh-failure", test_refresh_nudges_failure_hides_section_and_logs_debug);
    return Test.run();
}

}
