using GLib;

namespace HolderLinuxTests {

private class FakeUriLauncher : Object, HolderLinux.IUriLauncher {
    public int launch_calls = 0;
    public string last_uri = "";
    public bool fail_launch = false;

    public void launch(string uri) throws Error {
        if (fail_launch) {
            throw new IOError.FAILED("launch failed");
        }
        launch_calls++;
        last_uri = uri;
    }
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

private Gtk.Entry? find_entry_with_placeholder(Gtk.Widget root, string placeholder) {
    if (root is Gtk.Entry) {
        var entry = (Gtk.Entry) root;
        if (entry.get_placeholder_text() == placeholder) {
            return entry;
        }
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_entry_with_placeholder(child, placeholder);
        if (match != null) {
            return match;
        }
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.Entry? find_entry_with_text(Gtk.Widget root, string text) {
    if (root is Gtk.Entry) {
        var entry = (Gtk.Entry) root;
        if (entry.get_text() == text) {
            return entry;
        }
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_entry_with_text(child, text);
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
        return;
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        collect_dropdowns(child, dropdowns);
        child = child.get_next_sibling();
    }
}

private void collect_switches(Gtk.Widget root, Gee.ArrayList<Gtk.Switch> switches) {
    if (root is Gtk.Switch) {
        switches.add((Gtk.Switch) root);
        return;
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        collect_switches(child, switches);
        child = child.get_next_sibling();
    }
}

private uint dropdown_item_count(Gtk.DropDown dropdown) {
    var model = dropdown.get_model();
    assert(model != null);
    return ((!) model).get_n_items();
}

private Gee.ArrayList<string> strings(string[] values) {
    var list = new Gee.ArrayList<string>();
    foreach (var value in values) {
        list.add(value);
    }
    return list;
}

private HolderLinux.AiRunnerInfo runner(string id,
                                        string name,
                                        string source,
                                        bool enabled,
                                        string? base_url,
                                        string[] model_names,
                                        string error = "",
                                        Gee.ArrayList<HolderLinux.AiRunnerPullInfo>? pulls = null) {
    return new HolderLinux.AiRunnerInfo(
        id,
        name,
        "ollama",
        base_url,
        source,
        enabled,
        1,
        2,
        new HolderLinux.AiRunnerRuntimeInfo(
            true,
            error.strip().length == 0,
            true,
            3,
            "1.2.3",
            error,
            strings(model_names),
            pulls ?? new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>()
        )
    );
}

private HolderLinux.AiRuntimeProvider provider(string id,
                                               string display_name,
                                               bool enabled = true,
                                               bool configured = false) {
    return new HolderLinux.AiRuntimeProvider(
        id,
        display_name,
        enabled,
        configured,
        "https://setup.example/%s".printf(id),
        "https://docs.example/%s".printf(id)
    );
}

private void refresh_view(HolderLinux.AiConfigPanelView view) {
    bool done = false;
    view.refresh.begin(null, (obj, res) => {
        view.refresh.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));
}

private void test_idle_and_refresh_without_api() {
    var view = new HolderLinux.AiConfigPanelView();
    assert(collect_widget_text(view.widget).contains("Connect to holderd to configure AI."));

    refresh_view(view);
    assert(collect_widget_text(view.widget).contains("Connect to holderd to configure AI."));
}

private void test_set_api_client_null_resets_state() {
    var api = new MainControllerFakeApi();
    api.ai_runners.add(runner("r1", "Local Ollama", "manual", true, "http://localhost:11434", {"llama"}));

    var view = new HolderLinux.AiConfigPanelView();
    view.set_api_client(api);
    refresh_view(view);
    assert(collect_widget_text(view.widget).contains("Local Ollama"));

    view.set_api_client(null);
    var text = collect_widget_text(view.widget);
    assert(text.contains("Connect to holderd to configure AI."));
    assert(!text.contains("Local Ollama"));
}

private void test_render_local_models_and_install_signal() {
    var view = new HolderLinux.AiConfigPanelView();
    var recommended = strings({"llama3.2", "mistral"});
    var pulls = new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>();
    pulls.add(new HolderLinux.AiRunnerPullInfo("job-1", "", "llama3.2", "running", 42.5, "download"));
    var capabilities = new HolderLinux.AiCapabilitiesInfo(
        true,
        "runner warning",
        1,
        "0.7.1",
        "ollama",
        strings({"llama3.2"}),
        recommended
    );
    var status = new HolderLinux.AiStatusInfo(1, true, "", 2, 1, 3, pulls);

    string requested_model = "";
    view.pull_model_requested.connect((model_tag) => {
        requested_model = model_tag;
    });

    view.render_local_models(capabilities, status);

    var text = collect_widget_text(view.widget);
    assert(text.contains("Runtime: available"));
    assert(text.contains("Engine: ollama"));
    assert(text.contains("Version: 0.7.1"));
    assert(text.contains("runner warning"));
    assert(text.contains("Recommended installs: llama3.2, mistral"));
    assert(text.contains("Active runs: 2 | Active pulls: 1 | Cloud providers configured: 3"));
    assert(text.contains("Pull jobs: llama3.2 (running, 42.5%)"));

    var install_button = find_button_with_label(view.widget, "Install llama3.2");
    assert(install_button != null);
    ((!) install_button).clicked();
    assert(requested_model == "llama3.2");

    view.render_local_models_error("offline");
    text = collect_widget_text(view.widget);
    assert(text.contains("Local runtime unavailable"));
    assert(text.contains("offline"));
}

private void test_refresh_renders_runners_providers_and_model_config() {
    var api = new MainControllerFakeApi();
    var pulls = new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>();
    pulls.add(new HolderLinux.AiRunnerPullInfo("job-1", "r1", "llama3.2", "queued", 5.0, "queue"));
    api.ai_runners.add(runner("r1", "Local Ollama", "manual", true, "http://localhost:11434", {"llama3.2", "mistral"}, "", pulls));
    api.ai_runners.add(runner("r2", "Bundled", "detected", false, null, {}, "runtime down"));
    api.ai_runtime_providers.add(provider("openai", "OpenAI"));
    api.ai_provider_credentials.add(new HolderLinux.AiProviderCredentialState("openai", true, "sk-...1234", 4));
    api.ai_provider_settings.add(new HolderLinux.AiProviderSettingState("openai", false, 5));
    api.ai_local_model_config = new HolderLinux.AiLocalModelConfigInfo("r1::llama3.2", null, "missing::ghost", 6);

    var view = new HolderLinux.AiConfigPanelView();
    view.set_api_client(api);
    refresh_view(view);

    assert(api.list_ai_runtime_providers_calls == 1);
    assert(api.list_ai_runners_calls == 1);
    assert(api.list_ai_provider_credentials_calls == 1);
    assert(api.list_ai_provider_settings_calls == 1);
    assert(api.get_ai_local_model_config_calls == 1);

    var text = collect_widget_text(view.widget);
    assert(text.contains("Configure model runners, local model preferences, and cloud providers."));
    assert(text.contains("Local Ollama"));
    assert(text.contains("r1 | ollama | manual | Enabled: yes | http://localhost:11434"));
    assert(text.contains("Runtime: available | Version: 1.2.3 | Models: 2"));
    assert(text.contains("Installed: llama3.2, mistral"));
    assert(text.contains("Pulls: Local Ollama / llama3.2 (queued, 5.0%)"));
    assert(text.contains("Bundled"));
    assert(text.contains("runtime down"));
    assert(text.contains("OpenAI"));
    assert(text.contains("Configured: yes"));

    var dropdowns = new Gee.ArrayList<Gtk.DropDown>();
    collect_dropdowns(view.widget, dropdowns);
    assert(dropdowns.size == 3);
    assert(dropdown_item_count(dropdowns[0]) == 3);
    assert(dropdown_item_count(dropdowns[1]) == 3);
    assert(dropdown_item_count(dropdowns[2]) == 4);
}

private void test_local_model_refresh_cancels_pending_save() {
    var api = new MainControllerFakeApi();
    api.ai_runners.add(runner("r1", "Local Ollama", "manual", true, "http://localhost:11434", {"llama3.2"}));

    var scheduler = new TestScheduler();
    var view = new HolderLinux.AiConfigPanelView(null, scheduler);
    view.set_api_client(api);
    refresh_view(view);

    string debug_line = "";
    view.debug_log_requested.connect((line) => {
        debug_line = line;
    });

    var dropdowns = new Gee.ArrayList<Gtk.DropDown>();
    collect_dropdowns(view.widget, dropdowns);
    assert(dropdowns.size == 3);
    dropdowns[0].set_selected(1);
    assert(debug_line == "Saving local model preferences...");
    assert(scheduler.pending_with_delay(HolderLinux.AiConfigPresenter.LOCAL_MODEL_SAVE_DELAY_MS) == 1);

    refresh_view(view);
    // Rendering fresh settings drops the choice that was waiting to be saved.
    assert(scheduler.pending_one_shots() == 0);
    scheduler.run_due(HolderLinux.AiConfigPresenter.LOCAL_MODEL_SAVE_DELAY_MS);
    assert(api.set_ai_local_model_config_calls == 0);
}

private void test_local_model_save_failure_reports_error() {
    var api = new MainControllerFakeApi();
    api.fail_set_ai_local_model_config = true;
    api.ai_runners.add(runner("r1", "Local Ollama", "manual", true, "http://localhost:11434", {"llama3.2"}));

    var scheduler = new TestScheduler();
    var view = new HolderLinux.AiConfigPanelView(null, scheduler);
    view.set_api_client(api);
    refresh_view(view);

    string error_title = "";
    string error_details = "";
    string debug_line = "";
    view.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });
    view.debug_log_requested.connect((line) => {
        debug_line = line;
    });

    var dropdowns = new Gee.ArrayList<Gtk.DropDown>();
    collect_dropdowns(view.widget, dropdowns);
    assert(dropdowns.size == 3);
    dropdowns[0].set_selected(1);
    assert(scheduler.run_due(HolderLinux.AiConfigPresenter.LOCAL_MODEL_SAVE_DELAY_MS) == 1);

    assert(wait_for_condition(() => debug_line.has_prefix("Save local model config failed:")));
    assert(error_title == "AI Config");
    assert(error_details == "set local model config failed");
}

private void test_refresh_failure_reports_error() {
    var api = new MainControllerFakeApi();
    api.fail_list_ai_runtime_providers = true;
    var view = new HolderLinux.AiConfigPanelView();
    view.set_api_client(api);

    string error_title = "";
    string error_details = "";
    string debug_line = "";
    view.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });
    view.debug_log_requested.connect((line) => {
        debug_line = line;
    });

    refresh_view(view);

    assert(collect_widget_text(view.widget).contains("Failed to load AI config."));
    assert(error_title == "AI Config");
    assert(error_details == "list AI runtime providers failed");
    assert(debug_line == "AI Config load failed: list AI runtime providers failed");
}

private void test_manual_runner_validation_failure_and_switch_update() {
    var api = new MainControllerFakeApi();
    api.ai_runners.add(runner("r1", "Runner One", "manual", true, "http://old:11434", {"llama"}));

    var view = new HolderLinux.AiConfigPanelView();
    view.set_api_client(api);
    refresh_view(view);

    string error_title = "";
    string error_details = "";
    string debug_line = "";
    view.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });
    view.debug_log_requested.connect((line) => {
        debug_line = line;
    });

    ((!) find_button_with_label(view.widget, "Add Runner")).clicked();
    assert(error_title == "AI Config");
    assert(error_details == "Runner name and base URL are required.");

    var add_name_entry = find_entry_with_placeholder(view.widget, "Runner name");
    var add_url_entry = find_entry_with_placeholder(view.widget, "http://host:11434");
    assert(add_name_entry != null);
    assert(add_url_entry != null);
    ((!) add_name_entry).set_text("Runner Fail");
    ((!) add_url_entry).set_text("http://fail:11434");
    api.fail_create_ai_runner = true;
    ((!) find_button_with_label(view.widget, "Add Runner")).clicked();
    assert(wait_for_condition(() => debug_line.has_prefix("Create runner failed:"), 1500));
    assert(error_details == "create AI runner failed");

    var edit_name_entry = find_entry_with_text(view.widget, "Runner One");
    assert(edit_name_entry != null);
    ((!) edit_name_entry).set_text(" ");
    ((!) find_button_with_label(view.widget, "Save")).clicked();
    assert(error_details == "Runner name and base URL are required.");

    ((!) edit_name_entry).set_text("Runner Two");
    api.fail_update_ai_runner = true;
    ((!) find_button_with_label(view.widget, "Save")).clicked();
    assert(wait_for_condition(() => debug_line.has_prefix("Update runner failed (r1):"), 1500));
    assert(error_details == "update AI runner failed");

    api.fail_update_ai_runner = false;
    var switches = new Gee.ArrayList<Gtk.Switch>();
    collect_switches(view.widget, switches);
    assert(switches.size == 1);
    switches[0].set_active(false);
    assert(wait_for_condition(() => api.update_ai_runner_calls == 1));
    assert(api.last_ai_runner_id == "r1");
    assert(!api.last_ai_runner_enabled);

    api.fail_delete_ai_runner = true;
    ((!) find_button_with_label(view.widget, "Delete")).clicked();
    assert(wait_for_condition(() => debug_line.has_prefix("Delete runner failed (r1):"), 1500));
    assert(error_details == "delete AI runner failed");
}

private void test_manual_runner_create_update_delete() {
    var api = new MainControllerFakeApi();
    api.ai_runners.add(runner("r1", "Runner One", "manual", true, "http://old:11434", {"llama"}));
    var view = new HolderLinux.AiConfigPanelView();
    view.set_api_client(api);
    refresh_view(view);

    string debug_line = "";
    view.debug_log_requested.connect((line) => {
        debug_line = line;
    });

    var add_name_entry = find_entry_with_placeholder(view.widget, "Runner name");
    var add_url_entry = find_entry_with_placeholder(view.widget, "http://host:11434");
    assert(add_name_entry != null);
    assert(add_url_entry != null);
    ((!) add_name_entry).set_text(" New Runner ");
    ((!) add_url_entry).set_text(" http://new:11434 ");
    ((!) find_button_with_label(view.widget, "Add Runner")).clicked();

    assert(wait_for_condition(() => api.create_ai_runner_calls == 1));
    assert(api.last_ai_runner_name == "New Runner");
    assert(api.last_ai_runner_base_url == "http://new:11434");
    assert(api.last_ai_runner_enabled);
    assert(debug_line == "Created AI runner: New Runner");

    var edit_name_entry = find_entry_with_text(view.widget, "Runner One");
    var edit_url_entry = find_entry_with_text(view.widget, "http://old:11434");
    assert(edit_name_entry != null);
    assert(edit_url_entry != null);
    ((!) edit_name_entry).set_text("Runner Two");
    ((!) edit_url_entry).set_text("http://updated:11434");
    ((!) find_button_with_label(view.widget, "Save")).clicked();

    assert(wait_for_condition(() => api.update_ai_runner_calls == 1));
    assert(api.last_ai_runner_id == "r1");
    assert(api.last_ai_runner_name == "Runner Two");
    assert(api.last_ai_runner_base_url == "http://updated:11434");
    assert(api.last_ai_runner_enabled);
    assert(debug_line == "Updated AI runner: r1");

    ((!) find_button_with_label(view.widget, "Delete")).clicked();
    assert(wait_for_condition(() => api.delete_ai_runner_calls == 1));
    assert(api.last_ai_runner_id == "r1");
    assert(debug_line == "Deleted AI runner: r1");
}

private void test_provider_fallback_rendering_and_empty_key_validation() {
    var api = new MainControllerFakeApi();
    api.ai_runtime_providers.add(new HolderLinux.AiRuntimeProvider(
        "anthropic",
        "",
        true,
        false,
        "",
        ""
    ));

    var view = new HolderLinux.AiConfigPanelView();
    view.set_api_client(api);
    refresh_view(view);

    var text = collect_widget_text(view.widget);
    assert(text.contains("anthropic"));
    assert(text.contains("Configured: no"));
    assert(find_entry_with_placeholder(view.widget, "Paste API key") != null);

    string error_details = "";
    view.error_reported.connect((title, details) => {
        error_details = details;
    });
    ((!) find_button_with_label(view.widget, "Save Key")).clicked();
    assert(error_details == "API key cannot be empty.");
}

private void test_provider_failure_paths_report_errors() {
    var api = new MainControllerFakeApi();
    api.ai_runtime_providers.add(provider("openai", "OpenAI", true, true));
    api.ai_provider_credentials.add(new HolderLinux.AiProviderCredentialState("openai", true, "sk-...1234", 1));
    api.ai_provider_settings.add(new HolderLinux.AiProviderSettingState("openai", true, 1));

    var view = new HolderLinux.AiConfigPanelView();
    view.set_api_client(api);
    refresh_view(view);

    string error_details = "";
    string debug_line = "";
    view.error_reported.connect((title, details) => {
        error_details = details;
    });
    view.debug_log_requested.connect((line) => {
        debug_line = line;
    });

    var key_entry = find_entry_with_placeholder(view.widget, "Saved: sk-...1234");
    assert(key_entry != null);
    ((!) key_entry).set_text("sk-live");
    api.fail_upsert_ai_provider_credential = true;
    ((!) find_button_with_label(view.widget, "Save Key")).clicked();
    assert(wait_for_condition(() => debug_line.has_prefix("Save key failed (openai):"), 1500));
    assert(error_details == "save provider credential failed");

    api.fail_delete_ai_provider_credential = true;
    ((!) find_button_with_label(view.widget, "Remove Key")).clicked();
    assert(wait_for_condition(() => debug_line.has_prefix("Remove key failed (openai):"), 1500));
    assert(error_details == "delete provider credential failed");

    api.fail_set_ai_provider_enabled = true;
    var switches = new Gee.ArrayList<Gtk.Switch>();
    collect_switches(view.widget, switches);
    assert(switches.size == 1);
    switches[0].set_active(false);
    assert(wait_for_condition(() => debug_line.has_prefix("Set enabled failed (openai):"), 1500));
    assert(error_details == "set provider enabled failed");
}

private void test_provider_setup_and_docs_links_use_uri_launcher() {
    var api = new MainControllerFakeApi();
    api.ai_runtime_providers.add(provider("openai", "OpenAI", true, false));
    var launcher = new FakeUriLauncher();

    var view = new HolderLinux.AiConfigPanelView(launcher);
    view.set_api_client(api);
    refresh_view(view);

    ((!) find_button_with_label(view.widget, "Setup")).clicked();
    assert(launcher.launch_calls == 1);
    assert(launcher.last_uri == "https://setup.example/openai");

    ((!) find_button_with_label(view.widget, "Docs")).clicked();
    assert(launcher.launch_calls == 2);
    assert(launcher.last_uri == "https://docs.example/openai");
}

private void test_provider_link_blank_and_failure_paths() {
    var launcher = new FakeUriLauncher();
    var view = new HolderLinux.AiConfigPanelView(launcher);

    view.open_provider_link("   ");
    assert(launcher.launch_calls == 0);

    string error_title = "";
    string error_details = "";
    view.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });
    launcher.fail_launch = true;
    view.open_provider_link("https://setup.example/openai");
    assert(error_title == "AI Config");
    assert(error_details == "launch failed");
}

private void test_provider_key_and_enabled_actions() {
    var api = new MainControllerFakeApi();
    api.ai_runtime_providers.add(provider("openai", "OpenAI", true, true));
    api.ai_provider_credentials.add(new HolderLinux.AiProviderCredentialState("openai", true, "sk-...1234", 1));
    api.ai_provider_settings.add(new HolderLinux.AiProviderSettingState("openai", true, 1));

    var view = new HolderLinux.AiConfigPanelView();
    view.set_api_client(api);
    refresh_view(view);

    var key_entry = find_entry_with_placeholder(view.widget, "Saved: sk-...1234");
    assert(key_entry != null);
    ((!) key_entry).set_text(" sk-live ");
    ((!) find_button_with_label(view.widget, "Save Key")).clicked();

    assert(wait_for_condition(() => api.upsert_ai_provider_credential_calls == 1));
    assert(api.last_provider_id == "openai");
    assert(api.last_provider_api_key == "sk-live");

    ((!) find_button_with_label(view.widget, "Remove Key")).clicked();
    assert(wait_for_condition(() => api.delete_ai_provider_credential_calls == 1));
    assert(api.last_provider_id == "openai");

    var switches = new Gee.ArrayList<Gtk.Switch>();
    collect_switches(view.widget, switches);
    assert(switches.size == 1);
    switches[0].set_active(false);

    assert(wait_for_condition(() => api.set_ai_provider_enabled_calls == 1));
    assert(api.last_provider_id == "openai");
    assert(!api.last_provider_enabled);
}

private void test_local_model_dropdown_saves_preferences() {
    var api = new MainControllerFakeApi();
    api.ai_runners.add(runner("r1", "Local Ollama", "manual", true, "http://localhost:11434", {"llama3.2", "mistral"}));

    var scheduler = new TestScheduler();
    var view = new HolderLinux.AiConfigPanelView(null, scheduler);
    view.set_api_client(api);
    refresh_view(view);

    string debug_line = "";
    view.debug_log_requested.connect((line) => {
        debug_line = line;
    });

    var dropdowns = new Gee.ArrayList<Gtk.DropDown>();
    collect_dropdowns(view.widget, dropdowns);
    assert(dropdowns.size == 3);
    dropdowns[0].set_selected(1);
    // The choice is held back until the debounce fires, then saved once.
    assert(api.set_ai_local_model_config_calls == 0);
    assert(scheduler.run_due(HolderLinux.AiConfigPresenter.LOCAL_MODEL_SAVE_DELAY_MS) == 1);

    assert(wait_for_condition(() => debug_line == "Saved local model preferences."));
    assert(api.set_ai_local_model_config_calls == 1);
    assert(api.last_fast_model == "r1::llama3.2");
    assert(api.last_strong_model == null);
    assert(api.last_deep_model == null);
}

// Async calls that never suspend finish from idle callbacks, so let the loop drain before asserting
// that nothing further happened.
private void settle() {
    while (MainContext.default().iteration(false)) {}
}

private HolderLinux.AiLocalModelConfigInfo model_config(string? fast, string? strong, string? deep) {
    return new HolderLinux.AiLocalModelConfigInfo(fast, strong, deep, 0);
}

private Gee.ArrayList<Gtk.DropDown> config_dropdowns(HolderLinux.AiConfigPanelView view) {
    var dropdowns = new Gee.ArrayList<Gtk.DropDown>();
    collect_dropdowns(view.widget, dropdowns);
    assert(dropdowns.size == 3);
    return dropdowns;
}

private void test_two_model_choices_in_a_row_are_saved_once_after_the_last() {
    var api = new MainControllerFakeApi();
    api.ai_runners.add(runner("r1", "Local Ollama", "manual", true, "http://localhost:11434", {"llama3.2"}));
    var scheduler = new TestScheduler();
    var view = new HolderLinux.AiConfigPanelView(null, scheduler);
    view.set_api_client(api);
    refresh_view(view);
    var dropdowns = config_dropdowns(view);

    dropdowns[0].set_selected(1);
    assert(scheduler.pending_one_shots() == 1);
    dropdowns[1].set_selected(1);

    // The second choice replaces the first timer instead of queueing another save.
    assert(scheduler.pending_one_shots() == 1);
    assert(scheduler.run_due(HolderLinux.AiConfigPresenter.LOCAL_MODEL_SAVE_DELAY_MS) == 1);
    assert(wait_for_condition(() => api.set_ai_local_model_config_calls == 1));
    assert(api.last_fast_model == "r1::llama3.2");
    assert(api.last_strong_model == "r1::llama3.2");
}

private void test_choosing_the_saved_value_again_does_not_announce_a_save() {
    var api = new MainControllerFakeApi();
    api.ai_runners.add(runner("r1", "Local Ollama", "manual", true, "http://localhost:11434", {"llama3.2"}));
    var view = new HolderLinux.AiConfigPanelView(null, new TestScheduler());
    view.set_api_client(api);
    refresh_view(view);
    int announcements = 0;
    view.debug_log_requested.connect((line) => {
        if (line == "Saving local model preferences...") {
            announcements++;
        }
    });
    var dropdowns = config_dropdowns(view);

    dropdowns[0].set_selected(1);
    assert(announcements == 1);
    // Back to the value that is already saved: there is nothing new to save.
    dropdowns[0].set_selected(0);

    assert(announcements == 1);
}

private void test_a_model_choice_is_saved_when_only_one_dropdown_has_choices() {
    // No runners, so the only choices are the "Missing:" entries for models that were saved earlier.
    var api = new MainControllerFakeApi();
    api.ai_local_model_config = model_config(null, "r1::gone", null);
    var scheduler = new TestScheduler();
    var view = new HolderLinux.AiConfigPanelView(null, scheduler);
    view.set_api_client(api);
    refresh_view(view);
    var dropdowns = config_dropdowns(view);
    assert(!dropdowns[0].get_sensitive() && dropdowns[1].get_sensitive() && !dropdowns[2].get_sensitive());

    dropdowns[1].set_selected(0);

    assert(scheduler.pending_one_shots() == 1);

    // The same when the deep dropdown is the only one with choices.
    var deep_api = new MainControllerFakeApi();
    deep_api.ai_local_model_config = model_config(null, null, "r1::gone");
    var deep_scheduler = new TestScheduler();
    var deep_view = new HolderLinux.AiConfigPanelView(null, deep_scheduler);
    deep_view.set_api_client(deep_api);
    refresh_view(deep_view);
    var deep_dropdowns = config_dropdowns(deep_view);
    assert(!deep_dropdowns[0].get_sensitive() && !deep_dropdowns[1].get_sensitive()
           && deep_dropdowns[2].get_sensitive());

    deep_dropdowns[2].set_selected(0);

    assert(deep_scheduler.pending_one_shots() == 1);
}

private void test_actions_left_over_from_a_removed_api_do_nothing() {
    var api = new MainControllerFakeApi();
    api.ai_runners.add(runner("r1", "Runner One", "manual", true, "http://old:11434", {"llama"}));
    api.ai_runtime_providers.add(provider("openai", "OpenAI", true, true));
    api.ai_provider_credentials.add(new HolderLinux.AiProviderCredentialState("openai", true, "sk-...1234", 1));
    api.ai_provider_settings.add(new HolderLinux.AiProviderSettingState("openai", true, 1));
    var view = new HolderLinux.AiConfigPanelView();
    view.set_api_client(api);
    refresh_view(view);

    var add_name = find_entry_with_placeholder(view.widget, "Runner name");
    var add_url = find_entry_with_placeholder(view.widget, "http://host:11434");
    var key_entry = find_entry_with_placeholder(view.widget, "Saved: sk-...1234");
    var add_runner = find_button_with_label(view.widget, "Add Runner");
    var save_runner = find_button_with_label(view.widget, "Save");
    var delete_runner = find_button_with_label(view.widget, "Delete");
    var save_key = find_button_with_label(view.widget, "Save Key");
    var remove_key = find_button_with_label(view.widget, "Remove Key");
    var switches = new Gee.ArrayList<Gtk.Switch>();
    collect_switches(view.widget, switches);
    assert(add_name != null && add_url != null && key_entry != null);
    assert(add_runner != null && save_runner != null && delete_runner != null);
    // One "Enabled" switch on the runner row and one on the provider row.
    assert(save_key != null && remove_key != null && switches.size == 2);
    ((!) add_name).set_text("Late Runner");
    ((!) add_url).set_text("http://late:11434");
    ((!) key_entry).set_text("sk-late");
    string? reported = null;
    view.error_reported.connect((title, details) => { reported = details; });

    // The API goes away; the rows are gone, but a click that was already on its way still arrives.
    view.set_api_client(null);
    ((!) add_runner).clicked();
    ((!) save_runner).clicked();
    ((!) delete_runner).clicked();
    ((!) save_key).clicked();
    ((!) remove_key).clicked();
    foreach (var toggle in switches) {
        toggle.set_active(!toggle.get_active());
    }
    settle();

    assert(api.create_ai_runner_calls == 0 && api.update_ai_runner_calls == 0
           && api.delete_ai_runner_calls == 0);
    assert(api.upsert_ai_provider_credential_calls == 0 && api.delete_ai_provider_credential_calls == 0);
    assert(api.set_ai_provider_enabled_calls == 0);
    assert(reported == null);
}

private void test_removing_the_api_while_a_refresh_is_loading_does_not_crash_or_render() {
    var api = new MainControllerFakeApi();
    api.ai_runners.add(runner("r1", "Old Runner", "manual", true, "http://old:11434", {"llama"}));
    var view = new HolderLinux.AiConfigPanelView();
    view.set_api_client(api);
    // Fires while the refresh is between its requests (providers answered, runners not yet).
    api.list_ai_runners_hook = () => { view.set_api_client(null); };
    string? reported = null;
    view.error_reported.connect((title, details) => { reported = details; });

    refresh_view(view);

    var text = collect_widget_text(view.widget);
    assert(text.contains(HolderLinux.AiConfigPresenter.CONNECT_MESSAGE));
    assert(!text.contains("Old Runner"));
    assert(reported == null);
}

private void test_a_refresh_for_a_replaced_api_does_not_render_its_answer() {
    var old_api = new MainControllerFakeApi();
    old_api.ai_runners.add(runner("r1", "Old Runner", "manual", true, "http://old:11434", {"llama"}));
    var new_api = new MainControllerFakeApi();
    new_api.ai_runners.add(runner("r2", "New Runner", "manual", true, "http://new:11434", {"mistral"}));
    var view = new HolderLinux.AiConfigPanelView();
    view.set_api_client(old_api);
    old_api.list_ai_runners_hook = () => { view.set_api_client(new_api); };

    refresh_view(view);
    assert(!collect_widget_text(view.widget).contains("Old Runner"));

    refresh_view(view);
    var text = collect_widget_text(view.widget);
    assert(text.contains("New Runner"));
    assert(!text.contains("Old Runner"));
}

private void test_a_model_choice_waiting_to_be_saved_is_dropped_when_the_api_changes() {
    var old_api = new MainControllerFakeApi();
    old_api.ai_runners.add(runner("r1", "Local Ollama", "manual", true, "http://localhost:11434", {"llama3.2"}));
    var new_api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var view = new HolderLinux.AiConfigPanelView(null, scheduler);
    view.set_api_client(old_api);
    refresh_view(view);
    config_dropdowns(view)[0].set_selected(1);
    assert(scheduler.pending_one_shots() == 1);

    view.set_api_client(new_api);

    assert(scheduler.pending_one_shots() == 0);
    scheduler.run_due(HolderLinux.AiConfigPresenter.LOCAL_MODEL_SAVE_DELAY_MS);
    settle();
    assert(old_api.set_ai_local_model_config_calls == 0);
    assert(new_api.set_ai_local_model_config_calls == 0);
}

private void test_a_model_save_that_finishes_after_the_api_changed_does_not_update_the_view() {
    var old_api = new MainControllerFakeApi();
    old_api.ai_runners.add(runner("r1", "Local Ollama", "manual", true, "http://localhost:11434", {"llama3.2"}));
    var new_api = new MainControllerFakeApi();
    var scheduler = new TestScheduler();
    var view = new HolderLinux.AiConfigPanelView(null, scheduler);
    view.set_api_client(old_api);
    refresh_view(view);
    var announced = new Gee.ArrayList<string>();
    view.debug_log_requested.connect((line) => { announced.add(line); });
    config_dropdowns(view)[0].set_selected(1);
    old_api.set_ai_local_model_config_hook = () => { view.set_api_client(new_api); };

    scheduler.run_due(HolderLinux.AiConfigPresenter.LOCAL_MODEL_SAVE_DELAY_MS);
    assert(wait_for_condition(() => old_api.set_ai_local_model_config_calls == 1));
    settle();

    // The answer belongs to models this view no longer shows.
    assert(!announced.contains("Saved local model preferences."));
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping AI config panel view tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/ai_config_panel_view/idle_and_refresh_without_api", test_idle_and_refresh_without_api);
    Test.add_func("/ai_config_panel_view/set_api_client_null_resets_state", test_set_api_client_null_resets_state);
    Test.add_func("/ai_config_panel_view/render_local_models_and_install_signal", test_render_local_models_and_install_signal);
    Test.add_func("/ai_config_panel_view/refresh_renders_runners_providers_and_model_config", test_refresh_renders_runners_providers_and_model_config);
    Test.add_func("/ai_config_panel_view/local_model_refresh_cancels_pending_save", test_local_model_refresh_cancels_pending_save);
    Test.add_func("/ai_config_panel_view/local_model_save_failure_reports_error", test_local_model_save_failure_reports_error);
    Test.add_func("/ai_config_panel_view/refresh_failure_reports_error", test_refresh_failure_reports_error);
    Test.add_func("/ai_config_panel_view/manual_runner_validation_failure_and_switch_update", test_manual_runner_validation_failure_and_switch_update);
    Test.add_func("/ai_config_panel_view/manual_runner_create_update_delete", test_manual_runner_create_update_delete);
    Test.add_func("/ai_config_panel_view/provider_fallback_rendering_and_empty_key_validation", test_provider_fallback_rendering_and_empty_key_validation);
    Test.add_func("/ai_config_panel_view/provider_failure_paths_report_errors", test_provider_failure_paths_report_errors);
    Test.add_func("/ai_config_panel_view/provider_setup_and_docs_links_use_uri_launcher", test_provider_setup_and_docs_links_use_uri_launcher);
    Test.add_func("/ai_config_panel_view/provider_link_blank_and_failure_paths", test_provider_link_blank_and_failure_paths);
    Test.add_func("/ai_config_panel_view/provider_key_and_enabled_actions", test_provider_key_and_enabled_actions);
    Test.add_func("/ai_config_panel_view/local_model_dropdown_saves_preferences", test_local_model_dropdown_saves_preferences);
    Test.add_func("/ai_config_panel_view/two_model_choices_are_saved_once", test_two_model_choices_in_a_row_are_saved_once_after_the_last);
    Test.add_func("/ai_config_panel_view/saved_value_again_is_not_announced", test_choosing_the_saved_value_again_does_not_announce_a_save);
    Test.add_func("/ai_config_panel_view/save_with_a_single_dropdown_of_choices", test_a_model_choice_is_saved_when_only_one_dropdown_has_choices);
    Test.add_func("/ai_config_panel_view/actions_after_api_removed_do_nothing", test_actions_left_over_from_a_removed_api_do_nothing);
    Test.add_func("/ai_config_panel_view/api_removed_mid_refresh", test_removing_the_api_while_a_refresh_is_loading_does_not_crash_or_render);
    Test.add_func("/ai_config_panel_view/api_replaced_mid_refresh", test_a_refresh_for_a_replaced_api_does_not_render_its_answer);
    Test.add_func("/ai_config_panel_view/api_change_drops_pending_save", test_a_model_choice_waiting_to_be_saved_is_dropped_when_the_api_changes);
    Test.add_func("/ai_config_panel_view/api_change_during_save", test_a_model_save_that_finishes_after_the_api_changed_does_not_update_the_view);
    return Test.run();
}

}
