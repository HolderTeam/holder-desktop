using GLib;

namespace HolderLinuxTests {

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

    var view = new HolderLinux.AiConfigPanelView();
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

    assert(wait_for_condition(() => api.set_ai_local_model_config_calls == 1, 1500));
    assert(api.last_fast_model == "r1::llama3.2");
    assert(api.last_strong_model == null);
    assert(api.last_deep_model == null);
    assert(debug_line == "Saved local model preferences.");
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping AI config panel view tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/ai_config_panel_view/idle_and_refresh_without_api", test_idle_and_refresh_without_api);
    Test.add_func("/ai_config_panel_view/render_local_models_and_install_signal", test_render_local_models_and_install_signal);
    Test.add_func("/ai_config_panel_view/refresh_renders_runners_providers_and_model_config", test_refresh_renders_runners_providers_and_model_config);
    Test.add_func("/ai_config_panel_view/refresh_failure_reports_error", test_refresh_failure_reports_error);
    Test.add_func("/ai_config_panel_view/manual_runner_create_update_delete", test_manual_runner_create_update_delete);
    Test.add_func("/ai_config_panel_view/provider_key_and_enabled_actions", test_provider_key_and_enabled_actions);
    Test.add_func("/ai_config_panel_view/local_model_dropdown_saves_preferences", test_local_model_dropdown_saves_preferences);
    return Test.run();
}

}
