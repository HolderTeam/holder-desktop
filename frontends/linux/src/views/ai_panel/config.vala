namespace HolderLinux {

public class AiConfigPanelView : Object {
    private IHolderApi? api_client = null;

    private Gtk.Label status_label;
    private Gtk.ListBox runners_list;
    private Gtk.Entry add_runner_name_entry;
    private Gtk.Entry add_runner_base_url_entry;
    private Gtk.Button add_runner_button;
    private Gtk.Label local_runtime_label;
    private Gtk.Label local_recommended_label;
    private Gtk.Box local_recommended_buttons_box;
    private Gtk.Label local_activity_label;
    private Gtk.Label local_pulls_label;
    private Gtk.DropDown fast_model_dropdown;
    private Gtk.DropDown strong_model_dropdown;
    private Gtk.DropDown deep_model_dropdown;
    private Gtk.StringList fast_model_options;
    private Gtk.StringList strong_model_options;
    private Gtk.StringList deep_model_options;
    private Gtk.ListBox providers_list;

    private Gee.ArrayList<AiRuntimeProvider> providers_cache = new Gee.ArrayList<AiRuntimeProvider>();
    private Gee.ArrayList<AiRunnerInfo> runners_cache = new Gee.ArrayList<AiRunnerInfo>();
    private Gee.ArrayList<string?> local_model_option_values = new Gee.ArrayList<string?>();
    private HashTable<string, AiProviderCredentialState> credential_by_provider =
        new HashTable<string, AiProviderCredentialState>(str_hash, str_equal);
    private HashTable<string, AiProviderSettingState> setting_by_provider =
        new HashTable<string, AiProviderSettingState>(str_hash, str_equal);
    private AiLocalModelConfigInfo local_model_config =
        new AiLocalModelConfigInfo(null, null, null, 0);

    private bool suppress_enable_signal = false;
    private bool suppress_local_model_signal = false;
    private uint local_model_save_timeout_id = 0;
    private bool local_model_save_in_flight = false;
    private string? pending_fast_model = null;
    private string? pending_strong_model = null;
    private string? pending_deep_model = null;

    public Gtk.Widget widget { get; private set; }

    public signal void error_reported(string title, string details);
    public signal void debug_log_requested(string line);
    public signal void pull_model_requested(string model_tag);

    public AiConfigPanelView() {
        widget = build_ui();
        set_idle_state("Connect to holderd to configure AI.");
    }

    public void set_api_client(IHolderApi? api) {
        api_client = api;
        if (api_client == null) {
            set_idle_state("Connect to holderd to configure AI.");
        }
    }

    public async void refresh(string? project_id = null) {
        if (api_client == null) {
            set_idle_state("Connect to holderd to configure AI.");
            return;
        }

        set_idle_state("Loading AI config...");
        try {
            var providers = yield api_client.list_ai_runtime_providers();
            var runners = yield api_client.list_ai_runners();
            var credentials = yield api_client.list_ai_provider_credentials();
            var settings = yield api_client.list_ai_provider_settings();
            var local_models = yield api_client.get_ai_local_model_config();
            render(runners, providers, credentials, settings, local_models);
        } catch (Error e) {
            set_idle_state("Failed to load AI config.");
            error_reported("AI Config", e.message);
            debug_log_requested("AI Config load failed: %s".printf(e.message));
        }
    }

    private Gtk.Widget build_ui() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        root.set_margin_top(8);
        root.set_margin_bottom(8);
        root.set_margin_start(8);
        root.set_margin_end(8);

        status_label = new Gtk.Label("");
        status_label.set_halign(Gtk.Align.START);
        status_label.set_wrap(true);
        root.append(status_label);

        var runners_heading = new Gtk.Label("Model Runners");
        runners_heading.set_halign(Gtk.Align.START);
        runners_heading.add_css_class("heading");
        root.append(runners_heading);

        runners_list = new Gtk.ListBox();
        runners_list.set_selection_mode(Gtk.SelectionMode.NONE);
        runners_list.add_css_class("boxed-list");
        root.append(runners_list);

        var add_runner_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        add_runner_name_entry = new Gtk.Entry();
        add_runner_name_entry.set_hexpand(true);
        add_runner_name_entry.set_placeholder_text("Runner name");
        add_runner_base_url_entry = new Gtk.Entry();
        add_runner_base_url_entry.set_hexpand(true);
        add_runner_base_url_entry.set_placeholder_text("http://host:11434");
        add_runner_button = new Gtk.Button.with_label("Add Runner");
        add_runner_button.clicked.connect(() => {
            create_manual_runner.begin();
        });
        add_runner_box.append(add_runner_name_entry);
        add_runner_box.append(add_runner_base_url_entry);
        add_runner_box.append(add_runner_button);
        root.append(add_runner_box);

        var local_heading = new Gtk.Label("Local Models");
        local_heading.set_halign(Gtk.Align.START);
        local_heading.add_css_class("heading");
        root.append(local_heading);

        local_runtime_label = new Gtk.Label("");
        local_runtime_label.set_halign(Gtk.Align.START);
        local_runtime_label.set_wrap(true);
        root.append(local_runtime_label);

        fast_model_options = new Gtk.StringList(null);
        fast_model_dropdown = new Gtk.DropDown(fast_model_options, null);
        fast_model_dropdown.notify["selected"].connect(() => {
            schedule_local_model_save();
        });
        root.append(build_local_model_row(
            "Fast local model",
            "Used for quick background AI tasks.",
            fast_model_dropdown
        ));

        strong_model_options = new Gtk.StringList(null);
        strong_model_dropdown = new Gtk.DropDown(strong_model_options, null);
        strong_model_dropdown.notify["selected"].connect(() => {
            schedule_local_model_save();
        });
        root.append(build_local_model_row(
            "Strong local model",
            "Used for normal AI replies.",
            strong_model_dropdown
        ));

        deep_model_options = new Gtk.StringList(null);
        deep_model_dropdown = new Gtk.DropDown(deep_model_options, null);
        deep_model_dropdown.notify["selected"].connect(() => {
            schedule_local_model_save();
        });
        root.append(build_local_model_row(
            "Deep local model",
            "Reserved for slower, higher-effort local reasoning.",
            deep_model_dropdown
        ));

        local_recommended_label = new Gtk.Label("");
        local_recommended_label.set_halign(Gtk.Align.START);
        local_recommended_label.set_wrap(true);
        root.append(local_recommended_label);

        local_recommended_buttons_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        root.append(local_recommended_buttons_box);

        local_activity_label = new Gtk.Label("");
        local_activity_label.set_halign(Gtk.Align.START);
        local_activity_label.set_wrap(true);
        root.append(local_activity_label);

        local_pulls_label = new Gtk.Label("");
        local_pulls_label.set_halign(Gtk.Align.START);
        local_pulls_label.set_wrap(true);
        local_pulls_label.add_css_class("dim-label");
        root.append(local_pulls_label);

        var providers_heading = new Gtk.Label("Cloud Providers");
        providers_heading.set_halign(Gtk.Align.START);
        providers_heading.add_css_class("heading");
        root.append(providers_heading);

        providers_list = new Gtk.ListBox();
        providers_list.set_selection_mode(Gtk.SelectionMode.NONE);
        providers_list.add_css_class("boxed-list");
        root.append(providers_list);

        var scroller = new Gtk.ScrolledWindow();
        scroller.set_vexpand(true);
        scroller.set_child(root);
        return scroller;
    }

    private Gtk.Widget build_local_model_row(string title_text,
                                             string subtitle_text,
                                             Gtk.DropDown dropdown) {
        var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        var title = new Gtk.Label(title_text) { xalign = 0.0f };
        var subtitle = new Gtk.Label(subtitle_text) { xalign = 0.0f };
        subtitle.add_css_class("dim-label");
        dropdown.set_hexpand(true);
        row.append(title);
        row.append(subtitle);
        row.append(dropdown);
        return row;
    }

    private void set_idle_state(string message) {
        status_label.set_text(message);
        local_runtime_label.set_text("");
        local_recommended_label.set_text("");
        clear_runner_rows();
        local_activity_label.set_text("");
        local_pulls_label.set_text("");
        local_model_option_values.clear();
        local_model_config = new AiLocalModelConfigInfo(null, null, null, 0);
        clear_recommended_buttons();
        update_local_model_dropdowns();
        clear_provider_rows();
    }

    public void render_local_models(AiCapabilitiesInfo capabilities, AiStatusInfo status) {
        var runtime_parts = new Gee.ArrayList<string>();
        runtime_parts.add("Runtime: %s".printf(capabilities.runner_available ? "available" : "unavailable"));
        if (capabilities.caste_name.strip().length > 0) {
            runtime_parts.add("Engine: %s".printf(capabilities.caste_name));
        }
        if (capabilities.runner_version.strip().length > 0) {
            runtime_parts.add("Version: %s".printf(capabilities.runner_version));
        }
        local_runtime_label.set_text(string.joinv(" | ", runtime_parts.to_array()));

        if (capabilities.runner_error.strip().length > 0) {
            local_runtime_label.set_text("%s\n%s".printf(
                local_runtime_label.get_text(),
                capabilities.runner_error
            ));
        }

        update_local_model_dropdowns();

        if (capabilities.recommended_install.size == 0) {
            local_recommended_label.set_text("Recommended installs: none");
        } else {
            local_recommended_label.set_text(
                "Recommended installs: %s".printf(join_list(capabilities.recommended_install))
            );
        }
        rebuild_recommended_pull_buttons(capabilities.recommended_install);

        local_activity_label.set_text(
            "Active runs: %lld | Active pulls: %lld | Cloud providers configured: %lld".printf(
                status.active_runs,
                status.active_pull_jobs,
                status.cloud_configured_providers
            )
        );
        local_pulls_label.set_text("Pull jobs: %s".printf(join_list(status.pull_jobs)));
    }

    public void render_local_models_error(string message) {
        local_runtime_label.set_text("Local runtime unavailable");
        local_recommended_label.set_text("");
        local_activity_label.set_text(message);
        local_pulls_label.set_text("");
        local_model_option_values.clear();
        update_local_model_dropdowns();
        clear_recommended_buttons();
    }

    private void clear_provider_rows() {
        Gtk.Widget? child = providers_list.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            providers_list.remove(child);
            child = next;
        }
    }

    private void clear_runner_rows() {
        Gtk.Widget? child = runners_list.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            runners_list.remove(child);
            child = next;
        }
    }

    private void clear_recommended_buttons() {
        Gtk.Widget? child = local_recommended_buttons_box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            local_recommended_buttons_box.remove(child);
            child = next;
        }
    }

    private void render(Gee.ArrayList<AiRunnerInfo> runners,
                        Gee.ArrayList<AiRuntimeProvider> providers,
                        Gee.ArrayList<AiProviderCredentialState> credentials,
                        Gee.ArrayList<AiProviderSettingState> settings,
                        AiLocalModelConfigInfo local_models) {
        runners_cache = runners;
        providers_cache = providers;
        local_model_config = local_models;
        credential_by_provider.remove_all();
        setting_by_provider.remove_all();
        foreach (var cred in credentials) {
            credential_by_provider.insert(cred.provider, cred);
        }
        foreach (var setting in settings) {
            setting_by_provider.insert(setting.provider, setting);
        }

        update_local_model_dropdowns();
        clear_runner_rows();
        clear_provider_rows();

        foreach (var runner in runners_cache) {
            append_runner_row(runner);
        }
        foreach (var provider in providers_cache) {
            append_provider_row(provider);
        }
        status_label.set_text("Configure model runners, local model preferences, and cloud providers.");
    }

    private void update_local_model_dropdowns() {
        if (local_model_save_timeout_id != 0) {
            Source.remove(local_model_save_timeout_id);
            local_model_save_timeout_id = 0;
        }

        suppress_local_model_signal = true;
        populate_local_model_dropdown(fast_model_options, fast_model_dropdown, local_model_config.fast_model);
        populate_local_model_dropdown(strong_model_options, strong_model_dropdown, local_model_config.strong_model);
        populate_local_model_dropdown(deep_model_options, deep_model_dropdown, local_model_config.deep_model);
        suppress_local_model_signal = false;
    }

    private void populate_local_model_dropdown(Gtk.StringList options,
                                               Gtk.DropDown dropdown,
                                               string? selected_model) {
        while (options.get_n_items() > 0) {
            options.remove(options.get_n_items() - 1);
        }
        local_model_option_values.clear();

        options.append("(auto)");
        local_model_option_values.add(null);
        uint selected_index = 0;
        foreach (var runner in runners_cache) {
            for (int i = 0; i < runner.runtime.models.size; i++) {
                var model_name = runner.runtime.models[i];
                var model_ref = "%s::%s".printf(runner.runner_id, model_name);
                options.append(display_runner_model_label(runner, model_name));
                local_model_option_values.add(model_ref);
                if (selected_model != null && selected_model == model_ref) {
                    selected_index = local_model_option_values.size - 1;
                }
            }
        }

        if (selected_model != null && selected_index == 0) {
            options.append("Missing: %s".printf(display_model_ref_label(selected_model)));
            local_model_option_values.add(selected_model);
            selected_index = local_model_option_values.size - 1;
        }

        dropdown.set_selected(selected_index);
        dropdown.set_sensitive(local_model_option_values.size > 1);
    }

    private string? selected_model_from_dropdown(Gtk.StringList options, Gtk.DropDown dropdown) {
        var selected = dropdown.get_selected();
        if (selected == 0 || selected >= local_model_option_values.size) {
            return null;
        }
        return local_model_option_values[(int) selected];
    }

    private async void save_local_model_config() {
        if (api_client == null) {
            return;
        }

        var fast_model = selected_model_from_dropdown(fast_model_options, fast_model_dropdown);
        var strong_model = selected_model_from_dropdown(strong_model_options, strong_model_dropdown);
        var deep_model = selected_model_from_dropdown(deep_model_options, deep_model_dropdown);
        try {
            local_model_save_in_flight = true;
            pending_fast_model = fast_model;
            pending_strong_model = strong_model;
            pending_deep_model = deep_model;
            local_model_config = yield api_client.set_ai_local_model_config(
                fast_model,
                strong_model,
                deep_model
            );
            update_local_model_dropdowns();
            debug_log_requested("Saved local model preferences.");
        } catch (Error e) {
            error_reported("AI Config", e.message);
            debug_log_requested("Save local model config failed: %s".printf(e.message));
        } finally {
            local_model_save_in_flight = false;
            pending_fast_model = null;
            pending_strong_model = null;
            pending_deep_model = null;
        }
    }

    private void schedule_local_model_save() {
        if (suppress_local_model_signal || local_model_option_values.size <= 1) {
            return;
        }

        var fast_model = selected_model_from_dropdown(fast_model_options, fast_model_dropdown);
        var strong_model = selected_model_from_dropdown(strong_model_options, strong_model_dropdown);
        var deep_model = selected_model_from_dropdown(deep_model_options, deep_model_dropdown);
        if (models_match(local_model_config.fast_model, fast_model) &&
            models_match(local_model_config.strong_model, strong_model) &&
            models_match(local_model_config.deep_model, deep_model)) {
            return;
        }

        if (local_model_save_in_flight &&
            models_match(pending_fast_model, fast_model) &&
            models_match(pending_strong_model, strong_model) &&
            models_match(pending_deep_model, deep_model)) {
            return;
        }

        if (local_model_save_timeout_id != 0) {
            Source.remove(local_model_save_timeout_id);
            local_model_save_timeout_id = 0;
        }

        debug_log_requested("Saving local model preferences...");
        local_model_save_timeout_id = Timeout.add(500, () => {
            local_model_save_timeout_id = 0;
            save_local_model_config.begin();
            return Source.REMOVE;
        });
    }

    private bool models_match(string? a, string? b) {
        if (a == null && b == null) {
            return true;
        }
        if (a == null || b == null) {
            return false;
        }
        return a == b;
    }

    private string display_runner_model_label(AiRunnerInfo runner, string model_name) {
        var runner_label = runner.name.strip();
        if (runner_label.length == 0) {
            runner_label = runner.runner_id;
        }
        return "%s / %s".printf(runner_label, model_name);
    }

    private string display_model_ref_label(string model_ref) {
        var separator = model_ref.index_of("::");
        if (separator < 0) {
            return model_ref;
        }
        var runner_id = model_ref.substring(0, separator);
        var model_name = model_ref.substring(separator + 2);
        foreach (var runner in runners_cache) {
            if (runner.runner_id == runner_id) {
                return display_runner_model_label(runner, model_name);
            }
        }
        return "%s / %s".printf(runner_id, model_name);
    }

    private void rebuild_recommended_pull_buttons(Gee.ArrayList<string> recommended_models) {
        clear_recommended_buttons();

        if (recommended_models.size == 0) {
            var label = new Gtk.Label("No local model installs recommended right now.") { xalign = 0.0f };
            label.add_css_class("dim-label");
            local_recommended_buttons_box.append(label);
            return;
        }

        for (int i = 0; i < recommended_models.size; i++) {
            var model_tag = recommended_models[i];
            var btn = new Gtk.Button.with_label("Install %s".printf(model_tag));
            btn.set_halign(Gtk.Align.START);
            btn.clicked.connect(() => {
                pull_model_requested(model_tag);
            });
            local_recommended_buttons_box.append(btn);
        }
    }

    private void append_runner_row(AiRunnerInfo runner) {
        var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        row.set_margin_top(8);
        row.set_margin_bottom(8);
        row.set_margin_start(8);
        row.set_margin_end(8);

        var title = new Gtk.Label(runner.name) { xalign = 0.0f };
        title.add_css_class("heading");
        row.append(title);

        var summary_parts = new Gee.ArrayList<string>();
        summary_parts.add("%s".printf(runner.runner_id));
        summary_parts.add("%s".printf(runner.kind));
        summary_parts.add("%s".printf(runner.source));
        summary_parts.add("Enabled: %s".printf(runner.enabled ? "yes" : "no"));
        if (runner.base_url != null && runner.base_url.strip().length > 0) {
            summary_parts.add(runner.base_url);
        }
        var summary = new Gtk.Label(string.joinv(" | ", summary_parts.to_array())) { xalign = 0.0f };
        summary.set_wrap(true);
        summary.add_css_class("dim-label");
        row.append(summary);

        var runtime_parts = new Gee.ArrayList<string>();
        runtime_parts.add("Runtime: %s".printf(runner.runtime.available ? "available" : "unavailable"));
        if (runner.runtime.version.strip().length > 0) {
            runtime_parts.add("Version: %s".printf(runner.runtime.version));
        }
        if (runner.runtime.models.size > 0) {
            runtime_parts.add("Models: %d".printf(runner.runtime.models.size));
        }
        var runtime = new Gtk.Label(string.joinv(" | ", runtime_parts.to_array())) { xalign = 0.0f };
        runtime.set_wrap(true);
        row.append(runtime);

        if (runner.runtime.error.strip().length > 0) {
            var error = new Gtk.Label(runner.runtime.error) { xalign = 0.0f };
            error.set_wrap(true);
            error.add_css_class("error");
            row.append(error);
        }

        if (runner.runtime.models.size > 0) {
            var models = new Gtk.Label("Installed: %s".printf(join_list(runner.runtime.models))) { xalign = 0.0f };
            models.set_wrap(true);
            models.add_css_class("dim-label");
            row.append(models);
        }

        if (runner.runtime.pulls.size > 0) {
            var pull_parts = new Gee.ArrayList<string>();
            foreach (var pull in runner.runtime.pulls) {
                pull_parts.add("%s (%s, %.1f%%)".printf(pull.model, pull.status, pull.percent));
            }
            var pulls = new Gtk.Label("Pulls: %s".printf(join_list(pull_parts))) { xalign = 0.0f };
            pulls.set_wrap(true);
            pulls.add_css_class("dim-label");
            row.append(pulls);
        }

        if (runner.source == "manual") {
            var edit_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            var name_entry = new Gtk.Entry();
            name_entry.set_hexpand(true);
            name_entry.set_text(runner.name);
            var base_url_entry = new Gtk.Entry();
            base_url_entry.set_hexpand(true);
            base_url_entry.set_text(runner.base_url ?? "");
            edit_row.append(name_entry);
            edit_row.append(base_url_entry);
            row.append(edit_row);

            var controls = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var enabled_switch = new Gtk.Switch();
            enabled_switch.set_active(runner.enabled);
            enabled_switch.notify["active"].connect(() => {
                update_manual_runner.begin(runner.runner_id, name_entry.get_text(), base_url_entry.get_text(), enabled_switch.get_active());
            });
            var enabled_label = new Gtk.Label("Enabled");
            var save_btn = new Gtk.Button.with_label("Save");
            save_btn.clicked.connect(() => {
                update_manual_runner.begin(runner.runner_id, name_entry.get_text(), base_url_entry.get_text(), enabled_switch.get_active());
            });
            var delete_btn = new Gtk.Button.with_label("Delete");
            delete_btn.clicked.connect(() => {
                delete_manual_runner.begin(runner.runner_id);
            });
            controls.append(enabled_label);
            controls.append(enabled_switch);
            controls.append(save_btn);
            controls.append(delete_btn);
            row.append(controls);
        }

        runners_list.append(row);
    }

    private async void create_manual_runner() {
        if (api_client == null) {
            return;
        }
        var name = add_runner_name_entry.get_text().strip();
        var base_url = add_runner_base_url_entry.get_text().strip();
        if (name.length == 0 || base_url.length == 0) {
            error_reported("AI Config", "Runner name and base URL are required.");
            return;
        }
        try {
            add_runner_button.set_sensitive(false);
            yield api_client.create_ai_runner(name, base_url, true);
            add_runner_name_entry.set_text("");
            add_runner_base_url_entry.set_text("");
            debug_log_requested("Created AI runner: %s".printf(name));
            yield refresh(null);
        } catch (Error e) {
            error_reported("AI Config", e.message);
            debug_log_requested("Create runner failed: %s".printf(e.message));
        } finally {
            add_runner_button.set_sensitive(true);
        }
    }

    private async void update_manual_runner(string runner_id,
                                            string name,
                                            string base_url,
                                            bool enabled) {
        if (api_client == null) {
            return;
        }
        var trimmed_name = name.strip();
        var trimmed_base_url = base_url.strip();
        if (trimmed_name.length == 0 || trimmed_base_url.length == 0) {
            error_reported("AI Config", "Runner name and base URL are required.");
            return;
        }
        try {
            yield api_client.update_ai_runner(runner_id, trimmed_name, trimmed_base_url, enabled);
            debug_log_requested("Updated AI runner: %s".printf(runner_id));
            yield refresh(null);
        } catch (Error e) {
            error_reported("AI Config", e.message);
            debug_log_requested("Update runner failed (%s): %s".printf(runner_id, e.message));
        }
    }

    private async void delete_manual_runner(string runner_id) {
        if (api_client == null) {
            return;
        }
        try {
            yield api_client.delete_ai_runner(runner_id);
            debug_log_requested("Deleted AI runner: %s".printf(runner_id));
            yield refresh(null);
        } catch (Error e) {
            error_reported("AI Config", e.message);
            debug_log_requested("Delete runner failed (%s): %s".printf(runner_id, e.message));
        }
    }

    private void append_provider_row(AiRuntimeProvider provider) {
        var provider_id = provider.id;
        var cred = credential_by_provider.lookup(provider_id);
        var setting = setting_by_provider.lookup(provider_id);

        var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        row.set_margin_top(8);
        row.set_margin_bottom(8);
        row.set_margin_start(8);
        row.set_margin_end(8);

        var title = new Gtk.Label(provider.display_name.strip().length > 0
            ? provider.display_name
            : provider.id);
        title.set_halign(Gtk.Align.START);
        title.add_css_class("heading");
        row.append(title);

        var info = new Gtk.Label("Configured: %s".printf((cred != null && cred.configured) ? "yes" : "no"));
        info.set_halign(Gtk.Align.START);
        info.add_css_class("dim-label");
        row.append(info);

        var key_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var key_entry = new Gtk.Entry();
        key_entry.set_visibility(false);
        key_entry.set_hexpand(true);
        if (cred != null && cred.api_key_preview.strip().length > 0) {
            key_entry.set_placeholder_text("Saved: %s".printf(cred.api_key_preview));
        } else {
            key_entry.set_placeholder_text("Paste API key");
        }
        var save_btn = new Gtk.Button.with_label("Save Key");
        save_btn.clicked.connect(() => {
            save_provider_key.begin(provider_id, key_entry);
        });
        var remove_btn = new Gtk.Button.with_label("Remove Key");
        remove_btn.set_sensitive(cred != null && cred.configured);
        remove_btn.clicked.connect(() => {
            remove_provider_key.begin(provider_id);
        });
        key_row.append(key_entry);
        key_row.append(save_btn);
        key_row.append(remove_btn);
        row.append(key_row);

        var controls_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var enabled_label = new Gtk.Label("Enabled");
        enabled_label.set_halign(Gtk.Align.START);
        var enabled_switch = new Gtk.Switch();
        enabled_switch.set_active(setting != null ? setting.enabled : provider.enabled);
        enabled_switch.notify["active"].connect(() => {
            if (suppress_enable_signal) {
                return;
            }
            set_provider_enabled.begin(provider_id, enabled_switch.get_active());
        });
        var setup_btn = new Gtk.Button.with_label("Setup");
        setup_btn.set_sensitive(provider.setup_url.strip().length > 0);
        setup_btn.clicked.connect(() => {
            open_provider_link(provider.setup_url);
        });
        var docs_btn = new Gtk.Button.with_label("Docs");
        docs_btn.set_sensitive(provider.docs_url.strip().length > 0);
        docs_btn.clicked.connect(() => {
            open_provider_link(provider.docs_url);
        });
        controls_row.append(enabled_label);
        controls_row.append(enabled_switch);
        controls_row.append(setup_btn);
        controls_row.append(docs_btn);
        row.append(controls_row);

        providers_list.append(row);
    }

    private async void save_provider_key(string provider_id, Gtk.Entry key_entry) {
        if (api_client == null) {
            return;
        }
        var key = key_entry.get_text().strip();
        if (key.length == 0) {
            error_reported("AI Config", "API key cannot be empty.");
            return;
        }
        try {
            yield api_client.upsert_ai_provider_credential(provider_id, key);
            key_entry.set_text("");
            yield refresh(null);
        } catch (Error e) {
            error_reported("AI Config", e.message);
            debug_log_requested("Save key failed (%s): %s".printf(provider_id, e.message));
        }
    }

    private async void remove_provider_key(string provider_id) {
        if (api_client == null) {
            return;
        }
        try {
            yield api_client.delete_ai_provider_credential(provider_id);
            yield refresh(null);
        } catch (Error e) {
            error_reported("AI Config", e.message);
            debug_log_requested("Remove key failed (%s): %s".printf(provider_id, e.message));
        }
    }

    private async void set_provider_enabled(string provider_id, bool enabled) {
        if (api_client == null) {
            return;
        }
        try {
            yield api_client.set_ai_provider_enabled(provider_id, enabled);
            yield refresh(null);
        } catch (Error e) {
            error_reported("AI Config", e.message);
            debug_log_requested("Set enabled failed (%s): %s".printf(provider_id, e.message));
        }
    }

    private void open_provider_link(string link) {
        if (link.strip().length == 0) {
            return;
        }
        try {
            AppInfo.launch_default_for_uri(link, null);
        } catch (Error e) {
            error_reported("AI Config", e.message);
        }
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
