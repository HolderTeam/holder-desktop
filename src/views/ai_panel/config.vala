namespace HolderLinux {

public class AiConfigPanelView : Object {
    private IHolderApi? api_client = null;
    private IUriLauncher uri_launcher;

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
    private AiModelOptions fast_model_choices = new AiModelOptions();
    private AiModelOptions strong_model_choices = new AiModelOptions();
    private AiModelOptions deep_model_choices = new AiModelOptions();
    private HashTable<string, AiProviderCredentialState> credential_by_provider =
        new HashTable<string, AiProviderCredentialState>(str_hash, str_equal);
    private HashTable<string, AiProviderSettingState> setting_by_provider =
        new HashTable<string, AiProviderSettingState>(str_hash, str_equal);
    private AiLocalModelConfigInfo local_model_config =
        new AiLocalModelConfigInfo(null, null, null, 0);

    private bool suppress_local_model_signal = false;
    private uint local_model_save_timeout_id = 0;
    private uint refresh_serial = 0;
    private IScheduler scheduler;
    private bool local_model_save_in_flight = false;
    private string? pending_fast_model = null;
    private string? pending_strong_model = null;
    private string? pending_deep_model = null;

    public Gtk.Widget widget { get; private set; }

    public signal void error_reported(string title, string details);
    public signal void debug_log_requested(string line);
    public signal void pull_model_requested(string model_tag);

    public AiConfigPanelView(IUriLauncher? uri_launcher = null, IScheduler? scheduler = null) {
        this.uri_launcher = uri_launcher ?? new AppInfoUriLauncher();
        this.scheduler = scheduler ?? new MainLoopScheduler();
        widget = build_ui();
        set_idle_state(AiConfigPresenter.CONNECT_MESSAGE);
    }

    public void set_api_client(IHolderApi? api) {
        api_client = api;
        // A load still running for the previous API must not render into this one, and a model choice
        // waiting to be saved was made against the previous API's models.
        refresh_serial++;
        cancel_pending_local_model_save();
        if (api_client == null) {
            set_idle_state(AiConfigPresenter.CONNECT_MESSAGE);
        }
    }

    public async void refresh(string? project_id = null) {
        if (api_client == null) {
            set_idle_state(AiConfigPresenter.CONNECT_MESSAGE);
            return;
        }

        // The API can be swapped out or removed between the awaits below, so keep the one this load
        // started with and let only the newest load render.
        var api = api_client;
        var serial = ++refresh_serial;
        set_idle_state(AiConfigPresenter.LOADING_MESSAGE);
        try {
            var providers = yield api.list_ai_runtime_providers();
            var runners = yield api.list_ai_runners();
            var credentials = yield api.list_ai_provider_credentials();
            var settings = yield api.list_ai_provider_settings();
            var local_models = yield api.get_ai_local_model_config();
            if (serial != refresh_serial) {
                return;
            }
            render(runners, providers, credentials, settings, local_models);
        } catch (Error e) {
            if (serial != refresh_serial) {
                return;
            }
            set_idle_state(AiConfigPresenter.LOAD_FAILED_MESSAGE);
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
        local_model_config = new AiLocalModelConfigInfo(null, null, null, 0);
        clear_recommended_buttons();
        update_local_model_dropdowns();
        clear_provider_rows();
    }

    public void render_local_models(AiCapabilitiesInfo capabilities, AiStatusInfo status) {
        local_runtime_label.set_text(AiConfigPresenter.runtime_summary(capabilities));

        update_local_model_dropdowns();

        local_recommended_label.set_text(
            AiConfigPresenter.recommended_installs_text(capabilities.recommended_install)
        );
        rebuild_recommended_pull_buttons(capabilities.recommended_install);

        local_activity_label.set_text(AiConfigPresenter.activity_summary(status));
        local_pulls_label.set_text(AiConfigPresenter.pull_jobs_summary(status.pulls, runners_cache));
    }

    public void render_local_models_error(string message) {
        local_runtime_label.set_text(AiConfigPresenter.LOCAL_RUNTIME_UNAVAILABLE);
        local_recommended_label.set_text("");
        local_activity_label.set_text(message);
        local_pulls_label.set_text("");
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
        status_label.set_text(AiConfigPresenter.READY_MESSAGE);
    }

    private void cancel_pending_local_model_save() {
        if (local_model_save_timeout_id != 0) {
            scheduler.cancel(local_model_save_timeout_id);
            local_model_save_timeout_id = 0;
        }
    }

    private void update_local_model_dropdowns() {
        cancel_pending_local_model_save();

        suppress_local_model_signal = true;
        fast_model_choices = populate_local_model_dropdown(
            fast_model_options, fast_model_dropdown, local_model_config.fast_model
        );
        strong_model_choices = populate_local_model_dropdown(
            strong_model_options, strong_model_dropdown, local_model_config.strong_model
        );
        deep_model_choices = populate_local_model_dropdown(
            deep_model_options, deep_model_dropdown, local_model_config.deep_model
        );
        suppress_local_model_signal = false;
    }

    private AiModelOptions populate_local_model_dropdown(Gtk.StringList options,
                                                         Gtk.DropDown dropdown,
                                                         string? selected_model) {
        var choices = AiConfigPresenter.build_model_options(runners_cache, selected_model);
        while (options.get_n_items() > 0) {
            options.remove(options.get_n_items() - 1);
        }
        foreach (var label in choices.labels) {
            options.append(label);
        }
        dropdown.set_selected(choices.selected_index);
        dropdown.set_sensitive(choices.has_choices);
        return choices;
    }

    private async void save_local_model_config() {
        var api = api_client;
        if (api == null) {
            return;
        }

        var fast_model = fast_model_choices.value_at(fast_model_dropdown.get_selected());
        var strong_model = strong_model_choices.value_at(strong_model_dropdown.get_selected());
        var deep_model = deep_model_choices.value_at(deep_model_dropdown.get_selected());
        try {
            local_model_save_in_flight = true;
            pending_fast_model = fast_model;
            pending_strong_model = strong_model;
            pending_deep_model = deep_model;
            var saved = yield api.set_ai_local_model_config(
                fast_model,
                strong_model,
                deep_model
            );
            // The API was swapped out while saving: the answer belongs to models this view no longer shows.
            if (api != api_client) {
                return;
            }
            local_model_config = saved;
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
        if (suppress_local_model_signal
            || !(fast_model_choices.has_choices
                 || strong_model_choices.has_choices
                 || deep_model_choices.has_choices)) {
            return;
        }

        var fast_model = fast_model_choices.value_at(fast_model_dropdown.get_selected());
        var strong_model = strong_model_choices.value_at(strong_model_dropdown.get_selected());
        var deep_model = deep_model_choices.value_at(deep_model_dropdown.get_selected());
        if (!AiConfigPresenter.local_model_save_needed(
                local_model_config, fast_model, strong_model, deep_model,
                local_model_save_in_flight, pending_fast_model, pending_strong_model, pending_deep_model)) {
            return;
        }

        cancel_pending_local_model_save();

        debug_log_requested("Saving local model preferences...");
        local_model_save_timeout_id = scheduler.schedule_once(AiConfigPresenter.LOCAL_MODEL_SAVE_DELAY_MS, () => {
            local_model_save_timeout_id = 0;
            save_local_model_config.begin();
            return Source.REMOVE;
        });
    }

    private void rebuild_recommended_pull_buttons(Gee.ArrayList<string> recommended_models) {
        clear_recommended_buttons();

        if (recommended_models.size == 0) {
            var label = new Gtk.Label(AiConfigPresenter.NO_RECOMMENDED_INSTALLS_HINT) { xalign = 0.0f };
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
        var presentation = AiConfigPresenter.runner_row(runner, runners_cache);
        var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        row.set_margin_top(8);
        row.set_margin_bottom(8);
        row.set_margin_start(8);
        row.set_margin_end(8);

        var title = new Gtk.Label(presentation.title) { xalign = 0.0f };
        title.add_css_class("heading");
        row.append(title);

        var summary = new Gtk.Label(presentation.summary) { xalign = 0.0f };
        summary.set_wrap(true);
        summary.add_css_class("dim-label");
        row.append(summary);

        var runtime = new Gtk.Label(presentation.runtime) { xalign = 0.0f };
        runtime.set_wrap(true);
        row.append(runtime);

        if (presentation.error != null) {
            var error = new Gtk.Label(presentation.error) { xalign = 0.0f };
            error.set_wrap(true);
            error.add_css_class("error");
            row.append(error);
        }

        if (presentation.installed != null) {
            var models = new Gtk.Label(presentation.installed) { xalign = 0.0f };
            models.set_wrap(true);
            models.add_css_class("dim-label");
            row.append(models);
        }

        if (presentation.pulls != null) {
            var pulls = new Gtk.Label(presentation.pulls) { xalign = 0.0f };
            pulls.set_wrap(true);
            pulls.add_css_class("dim-label");
            row.append(pulls);
        }

        if (presentation.is_manual) {
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
        var draft = new AiRunnerDraft(add_runner_name_entry.get_text(), add_runner_base_url_entry.get_text());
        if (!draft.valid) {
            error_reported("AI Config", (!) draft.error_message);
            return;
        }
        var name = draft.name;
        try {
            add_runner_button.set_sensitive(false);
            yield api_client.create_ai_runner(draft.name, draft.base_url, true);
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
        var draft = new AiRunnerDraft(name, base_url);
        if (!draft.valid) {
            error_reported("AI Config", (!) draft.error_message);
            return;
        }
        try {
            yield api_client.update_ai_runner(runner_id, draft.name, draft.base_url, enabled);
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
        var presentation = AiConfigPresenter.provider_row(
            provider,
            credential_by_provider.lookup(provider_id),
            setting_by_provider.lookup(provider_id)
        );

        var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        row.set_margin_top(8);
        row.set_margin_bottom(8);
        row.set_margin_start(8);
        row.set_margin_end(8);

        var title = new Gtk.Label(presentation.title);
        title.set_halign(Gtk.Align.START);
        title.add_css_class("heading");
        row.append(title);

        var info = new Gtk.Label(presentation.configured_text);
        info.set_halign(Gtk.Align.START);
        info.add_css_class("dim-label");
        row.append(info);

        var key_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var key_entry = new Gtk.Entry();
        key_entry.set_visibility(false);
        key_entry.set_hexpand(true);
        key_entry.set_placeholder_text(presentation.key_placeholder);
        var save_btn = new Gtk.Button.with_label("Save Key");
        save_btn.clicked.connect(() => {
            save_provider_key.begin(provider_id, key_entry);
        });
        var remove_btn = new Gtk.Button.with_label("Remove Key");
        remove_btn.set_sensitive(presentation.can_remove_key);
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
        enabled_switch.set_active(presentation.enabled);
        enabled_switch.notify["active"].connect(() => {
            set_provider_enabled.begin(provider_id, enabled_switch.get_active());
        });
        var setup_btn = new Gtk.Button.with_label("Setup");
        setup_btn.set_sensitive(presentation.setup_available);
        setup_btn.clicked.connect(() => {
            open_provider_link(provider.setup_url);
        });
        var docs_btn = new Gtk.Button.with_label("Docs");
        docs_btn.set_sensitive(presentation.docs_available);
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
        var draft = new AiProviderKeyDraft(key_entry.get_text());
        if (!draft.valid) {
            error_reported("AI Config", (!) draft.error_message);
            return;
        }
        try {
            yield api_client.upsert_ai_provider_credential(provider_id, draft.key);
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

    internal void open_provider_link(string link) {
        if (link.strip().length == 0) {
            return;
        }
        try {
            uri_launcher.launch(link);
        } catch (Error e) {
            error_reported("AI Config", e.message);
        }
    }
}

}
