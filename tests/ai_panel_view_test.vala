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

private void settle() {
    while (MainContext.default().iteration(false)) {}
}

private HolderLinux.AiNudge summary_nudge() {
    return new HolderLinux.AiNudge(
        "n2", "card.summary", "p1", "c1", "Link related cards",
        "Remember to link the related cards.", "fp", "commit", 1
    );
}

private Gee.ArrayList<HolderLinux.AiRunnerInfo> two_runners() {
    var runners = new Gee.ArrayList<HolderLinux.AiRunnerInfo>();
    runners.add(runner("r1", "Local", true, {"mistral", "llama"}));
    runners.add(runner("r2", "Remote", false, {"gpt"}));
    return runners;
}

private void test_refresh_config_loads_the_config_panel_from_the_api() {
    var api = new MainControllerFakeApi();
    api.ai_runners.add(runner("r1", "Config Runner", true, {"llama"}));
    var panel = new HolderLinux.AiPanel();
    panel.set_api_client(api);

    panel.refresh_config("p1");

    assert(wait_for_condition(() => collect_widget_text(panel.widget).contains("Config Runner")));
}

private void test_config_panel_events_are_forwarded() {
    var api = new MainControllerFakeApi();
    api.fail_list_ai_runners = true;
    var panel = new HolderLinux.AiPanel();
    panel.set_api_client(api);
    string? error_title = null;
    string? error_details = null;
    string? pulled = null;
    var debug_lines = new Gee.ArrayList<string>();
    panel.error_reported.connect((title, details) => { error_title = title; error_details = details; });
    panel.debug_log_requested.connect((line) => { debug_lines.add(line); });
    panel.pull_model_requested.connect((tag) => { pulled = tag; });

    panel.refresh_config("p1");
    assert(wait_for_condition(() => error_title != null));
    assert(error_title == "AI Config" && error_details == "list AI runners failed");

    // A recommended install offered by the config panel is passed on as a pull request.
    var caps = new HolderLinux.AiCapabilitiesInfo(
        true, "", 1, "1.0", "user", new Gee.ArrayList<string>(),
        strings({"llama3.2:3b"})
    );
    panel.render_status(caps, status(), new Gee.ArrayList<HolderLinux.AiRunnerInfo>());
    var install = find_button_with_label(panel.widget, "Install llama3.2:3b");
    assert(install != null);
    ((!) install).clicked();
    assert(pulled == "llama3.2:3b");

    // Debug lines the config panel writes (a model choice being saved) reach the panel's log too.
    var api2 = new MainControllerFakeApi();
    api2.ai_runners.add(runner("r1", "Config Runner", true, {"llama"}));
    panel.set_api_client(api2);
    panel.refresh_config("p1");
    assert(wait_for_condition(() => collect_widget_text(panel.widget).contains("Config Runner")));
    var model_dropdowns = new Gee.ArrayList<Gtk.DropDown>();
    collect_dropdowns(panel.widget, model_dropdowns);
    // Dropdowns: run target runner, run target model, then the three saved-model choices.
    assert(model_dropdowns.size == 5);
    model_dropdowns[2].set_selected(1);
    assert(debug_lines.contains("Saving local model preferences..."));
}

private Gee.ArrayList<string> strings(string[] values) {
    var list = new Gee.ArrayList<string>();
    foreach (var value in values) {
        list.add(value);
    }
    return list;
}

private void test_the_run_target_selection_survives_a_status_refresh() {
    var panel = new HolderLinux.AiPanel();
    panel.render_status(capabilities(), status(), two_runners());
    var runner_dropdown = panel_dropdown(panel, 0);
    var model_dropdown = panel_dropdown(panel, 1);
    runner_dropdown.set_selected(1);
    model_dropdown.set_selected(1);
    assert(panel.get_selected_runner_id() == "r2" && panel.get_selected_model_name() == "gpt");

    // The same runners arrive again (the periodic status refresh): the user's choice stays.
    panel.render_status(capabilities(), status(), two_runners());
    assert(panel.get_selected_runner_id() == "r2");
    assert(panel.get_selected_model_name() == "gpt");
    assert(dropdown_item_count(runner_dropdown) == 2);

    // The chosen runner is gone: fall back to the first one, with no model chosen.
    var only_local = new Gee.ArrayList<HolderLinux.AiRunnerInfo>();
    only_local.add(runner("r1", "Local", true, {"mistral", "llama"}));
    panel.render_status(capabilities(), status(), only_local);
    assert(panel.get_selected_runner_id() == "r1");
    assert(panel.get_selected_model_name() == null);
}

private void test_no_runners_means_nothing_to_choose() {
    var panel = new HolderLinux.AiPanel();
    panel.render_status(capabilities(), status(), two_runners());

    panel.render_status(capabilities(), status(), new Gee.ArrayList<HolderLinux.AiRunnerInfo>());

    assert(panel.get_selected_runner_id() == null);
    assert(panel.get_selected_model_name() == null);
    assert(!panel_dropdown(panel, 0).get_sensitive());
    assert(!panel_dropdown(panel, 1).get_sensitive());
    assert(dropdown_item_count(panel_dropdown(panel, 1)) == 1);
}

private void test_a_nudge_that_is_not_a_title_suggestion_shows_its_body() {
    var api = new MainControllerFakeApi();
    api.ai_nudges.add(summary_nudge());
    var panel = new HolderLinux.AiPanel();
    panel.set_api_client(api);

    panel.refresh_nudges("p1", "c1");

    assert(wait_for_condition(() => collect_widget_text(panel.widget).contains("Link related cards")));
    assert(collect_widget_text(panel.widget).contains("Remember to link the related cards."));
    assert(find_button_with_label(panel.widget, "Apply") == null);
    assert(find_button_with_label(panel.widget, "Dismiss") != null);
}

private void test_an_older_nudge_load_does_not_overwrite_a_newer_one() {
    var api = new MainControllerFakeApi();
    api.ai_nudges.add(title_nudge());
    var panel = new HolderLinux.AiPanel();
    panel.set_api_client(api);
    bool fired = false;
    // While the first request is in flight the answer changes and a second refresh starts.
    api.list_ai_nudges_hook = () => {
        if (fired) {
            return;
        }
        fired = true;
        var newer = new Gee.ArrayList<HolderLinux.AiNudge>();
        newer.add(summary_nudge());
        api.ai_nudges = newer;
        panel.refresh_nudges("p1", "c1");
    };

    panel.refresh_nudges("p1", "c1");

    assert(wait_for_condition(() => collect_widget_text(panel.widget).contains("Link related cards")));
    settle();
    assert(!collect_widget_text(panel.widget).contains("Suggest a title"));
}

private void test_an_older_failed_nudge_load_is_ignored() {
    var api = new MainControllerFakeApi();
    api.ai_nudges.add(summary_nudge());
    var panel = new HolderLinux.AiPanel();
    panel.set_api_client(api);
    var debug_lines = new Gee.ArrayList<string>();
    panel.debug_log_requested.connect((line) => { debug_lines.add(line); });
    bool fired = false;
    api.list_ai_nudges_hook = () => {
        if (fired) {
            return;
        }
        fired = true;
        // The first request will fail, but a newer one has already been started and succeeds.
        panel.refresh_nudges("p1", "c1");
        api.fail_list_ai_nudges = true;
    };

    panel.refresh_nudges("p1", "c1");

    assert(wait_for_condition(() => collect_widget_text(panel.widget).contains("Link related cards")));
    settle();
    assert(collect_widget_text(panel.widget).contains("Link related cards"));
    foreach (var line in debug_lines) {
        assert(!line.contains("NUDGE_LIST_ERROR"));
    }
}

private void test_removing_the_api_clears_its_nudges() {
    var api = new MainControllerFakeApi();
    api.ai_nudges.add(title_nudge());
    var panel = new HolderLinux.AiPanel();
    panel.set_api_client(api);
    panel.refresh_nudges("p1", "c1");
    assert(wait_for_condition(() => collect_widget_text(panel.widget).contains("Suggest a title")));
    var dismiss = find_button_with_label(panel.widget, "Dismiss");
    assert(dismiss != null);
    string? reported = null;
    panel.error_reported.connect((title, details) => { reported = details; });

    panel.set_api_client(null);

    assert(!collect_widget_text(panel.widget).contains("Suggest a title"));
    // A click that was already on its way finds nothing to do.
    ((!) dismiss).clicked();
    settle();
    assert(api.dismiss_ai_nudge_calls == 0);
    assert(reported == null);
}

private void test_a_nudge_load_for_a_replaced_api_is_not_rendered() {
    var old_api = new MainControllerFakeApi();
    old_api.ai_nudges.add(title_nudge());
    var new_api = new MainControllerFakeApi();
    var panel = new HolderLinux.AiPanel();
    panel.set_api_client(old_api);
    old_api.list_ai_nudges_hook = () => { panel.set_api_client(new_api); };

    panel.refresh_nudges("p1", "c1");
    assert(wait_for_condition(() => old_api.list_ai_nudges_calls == 1));
    settle();

    assert(!collect_widget_text(panel.widget).contains("Suggest a title"));
}

private void test_a_failed_dismissal_is_reported_and_can_be_retried() {
    var api = new MainControllerFakeApi();
    api.ai_nudges.add(title_nudge());
    api.fail_dismiss_ai_nudge = true;
    var panel = new HolderLinux.AiPanel();
    panel.set_api_client(api);
    panel.refresh_nudges("p1", "c1");
    assert(wait_for_condition(() => find_button_with_label(panel.widget, "Dismiss") != null));
    var errors = new Gee.ArrayList<string>();
    var debug_lines = new Gee.ArrayList<string>();
    panel.error_reported.connect((title, details) => { errors.add("%s|%s".printf(title, details)); });
    panel.debug_log_requested.connect((line) => { debug_lines.add(line); });
    var dismiss = (!) find_button_with_label(panel.widget, "Dismiss");

    dismiss.clicked();
    assert(!dismiss.get_sensitive());
    assert(wait_for_condition(() => errors.size == 1));

    assert(errors[0] == "Dismiss nudge failed|dismiss nudge failed");
    assert(debug_lines.contains("NUDGE_DISMISS_ERROR dismiss nudge failed"));
    // The nudge is still there, and the button is back so the user can try again.
    assert(dismiss.get_sensitive());
    assert(collect_widget_text(panel.widget).contains("Suggest a title"));
}

private void test_dismiss_is_disabled_while_its_request_is_running() {
    var api = new MainControllerFakeApi();
    api.ai_nudges.add(title_nudge());
    var panel = new HolderLinux.AiPanel();
    panel.set_api_client(api);
    panel.refresh_nudges("p1", "c1");
    assert(wait_for_condition(() => find_button_with_label(panel.widget, "Dismiss") != null));
    var dismiss = (!) find_button_with_label(panel.widget, "Dismiss");
    assert(dismiss.get_sensitive());

    dismiss.clicked();

    // GTK delivers no further clicks to an insensitive button, so a double click sends one request.
    assert(!dismiss.get_sensitive());
    assert(wait_for_condition(() => api.dismiss_ai_nudge_calls == 1));
    settle();
    assert(api.dismiss_ai_nudge_calls == 1);
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
    Test.add_func("/holder/ai-panel/refresh-config", test_refresh_config_loads_the_config_panel_from_the_api);
    Test.add_func("/holder/ai-panel/config-events-forwarded", test_config_panel_events_are_forwarded);
    Test.add_func("/holder/ai-panel/run-target-survives-refresh", test_the_run_target_selection_survives_a_status_refresh);
    Test.add_func("/holder/ai-panel/no-runners", test_no_runners_means_nothing_to_choose);
    Test.add_func("/holder/ai-panel/nudge-body", test_a_nudge_that_is_not_a_title_suggestion_shows_its_body);
    Test.add_func("/holder/ai-panel/nudge-stale-load", test_an_older_nudge_load_does_not_overwrite_a_newer_one);
    Test.add_func("/holder/ai-panel/nudge-stale-failure", test_an_older_failed_nudge_load_is_ignored);
    Test.add_func("/holder/ai-panel/api-removed-clears-nudges", test_removing_the_api_clears_its_nudges);
    Test.add_func("/holder/ai-panel/api-replaced-nudge-load", test_a_nudge_load_for_a_replaced_api_is_not_rendered);
    Test.add_func("/holder/ai-panel/dismiss-failure", test_a_failed_dismissal_is_reported_and_can_be_retried);
    Test.add_func("/holder/ai-panel/dismiss-disabled-in-flight", test_dismiss_is_disabled_while_its_request_is_running);
    return Test.run();
}

}
