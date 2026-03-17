namespace HolderLinux {

public class AiConfigPanelView : Object {
    private IHolderApi? api_client = null;

    private Gtk.Label status_label;
    private Gtk.DropDown provider_dropdown;
    private Gtk.StringList provider_names;
    private Gtk.Entry api_key_entry;
    private Gtk.Button save_key_button;
    private Gtk.Button remove_key_button;
    private Gtk.Switch enabled_switch;
    private Gtk.Button setup_button;
    private Gtk.Button docs_button;
    private Gtk.Label provider_state_label;
    private Gtk.Label router_summary_label;

    private Gee.ArrayList<AiRuntimeProvider> providers_cache = new Gee.ArrayList<AiRuntimeProvider>();
    private HashTable<string, AiProviderCredentialState> credential_by_provider =
        new HashTable<string, AiProviderCredentialState>(str_hash, str_equal);
    private HashTable<string, AiProviderSettingState> setting_by_provider =
        new HashTable<string, AiProviderSettingState>(str_hash, str_equal);

    private bool suppress_enable_signal = false;

    public Gtk.Widget widget { get; private set; }

    public signal void error_reported(string title, string details);
    public signal void debug_log_requested(string line);

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
            var credentials = yield api_client.list_ai_provider_credentials();
            var settings = yield api_client.list_ai_provider_settings();
            var router = yield api_client.get_ai_router_config(project_id);
            render(providers, credentials, settings, router);
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

        var provider_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var provider_label = new Gtk.Label("Provider");
        provider_label.set_halign(Gtk.Align.START);
        provider_names = new Gtk.StringList(null);
        provider_dropdown = new Gtk.DropDown(provider_names, null);
        provider_dropdown.set_hexpand(true);
        provider_dropdown.notify["selected"].connect(() => {
            update_provider_controls();
        });
        provider_row.append(provider_label);
        provider_row.append(provider_dropdown);
        root.append(provider_row);

        var key_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var key_label = new Gtk.Label("API key");
        key_label.set_halign(Gtk.Align.START);
        api_key_entry = new Gtk.Entry();
        api_key_entry.set_visibility(false);
        api_key_entry.set_hexpand(true);
        api_key_entry.set_placeholder_text("Paste provider API key");
        save_key_button = new Gtk.Button.with_label("Save Key");
        save_key_button.clicked.connect(() => {
            save_selected_provider_key.begin();
        });
        remove_key_button = new Gtk.Button.with_label("Remove Key");
        remove_key_button.clicked.connect(() => {
            remove_selected_provider_key.begin();
        });
        key_row.append(key_label);
        key_row.append(api_key_entry);
        key_row.append(save_key_button);
        key_row.append(remove_key_button);
        root.append(key_row);

        var enabled_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var enabled_label = new Gtk.Label("Enabled");
        enabled_label.set_halign(Gtk.Align.START);
        enabled_switch = new Gtk.Switch();
        enabled_switch.notify["active"].connect(() => {
            on_enabled_switch_toggled.begin();
        });
        enabled_row.append(enabled_label);
        enabled_row.append(enabled_switch);
        root.append(enabled_row);

        var links_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        setup_button = new Gtk.Button.with_label("Setup");
        setup_button.clicked.connect(() => {
            open_selected_provider_link(true);
        });
        docs_button = new Gtk.Button.with_label("Docs");
        docs_button.clicked.connect(() => {
            open_selected_provider_link(false);
        });
        links_row.append(setup_button);
        links_row.append(docs_button);
        root.append(links_row);

        provider_state_label = new Gtk.Label("");
        provider_state_label.set_halign(Gtk.Align.START);
        provider_state_label.set_wrap(true);
        provider_state_label.add_css_class("dim-label");
        root.append(provider_state_label);

        router_summary_label = new Gtk.Label("");
        router_summary_label.set_halign(Gtk.Align.START);
        router_summary_label.set_wrap(true);
        router_summary_label.add_css_class("dim-label");
        root.append(router_summary_label);

        var scroller = new Gtk.ScrolledWindow();
        scroller.set_vexpand(true);
        scroller.set_child(root);
        return scroller;
    }

    private void set_idle_state(string message) {
        status_label.set_text(message);
        provider_state_label.set_text("");
        router_summary_label.set_text("");
        provider_names.splice(0, provider_names.get_n_items(), null);
        save_key_button.set_sensitive(false);
        remove_key_button.set_sensitive(false);
        enabled_switch.set_sensitive(false);
        setup_button.set_sensitive(false);
        docs_button.set_sensitive(false);
    }

    private string selected_provider_id() {
        uint idx = provider_dropdown.get_selected();
        if (idx >= providers_cache.size) {
            return "";
        }
        return providers_cache[(int) idx].id;
    }

    private AiRuntimeProvider? selected_provider() {
        uint idx = provider_dropdown.get_selected();
        if (idx >= providers_cache.size) {
            return null;
        }
        return providers_cache[(int) idx];
    }

    private void update_provider_controls() {
        var provider = selected_provider();
        if (provider == null) {
            save_key_button.set_sensitive(false);
            remove_key_button.set_sensitive(false);
            enabled_switch.set_sensitive(false);
            setup_button.set_sensitive(false);
            docs_button.set_sensitive(false);
            provider_state_label.set_text("");
            return;
        }

        var provider_id = provider.id;
        var cred = credential_by_provider.lookup(provider_id);
        var setting = setting_by_provider.lookup(provider_id);

        suppress_enable_signal = true;
        enabled_switch.set_active(setting != null ? setting.enabled : provider.enabled);
        suppress_enable_signal = false;
        enabled_switch.set_sensitive(true);

        save_key_button.set_sensitive(true);
        remove_key_button.set_sensitive(cred != null && cred.configured);
        setup_button.set_sensitive(provider.setup_url.strip().length > 0);
        docs_button.set_sensitive(provider.docs_url.strip().length > 0);

        if (cred != null && cred.api_key_preview.strip().length > 0) {
            api_key_entry.set_placeholder_text("Saved: %s".printf(cred.api_key_preview));
        } else {
            api_key_entry.set_placeholder_text("Paste provider API key");
        }

        provider_state_label.set_text(
            "Configured: %s | Enabled: %s".printf(
                (cred != null && cred.configured) ? "yes" : "no",
                enabled_switch.get_active() ? "yes" : "no"
            )
        );
    }

    private void render(Gee.ArrayList<AiRuntimeProvider> providers,
                        Gee.ArrayList<AiProviderCredentialState> credentials,
                        Gee.ArrayList<AiProviderSettingState> settings,
                        AiRouterConfigInfo router) {
        providers_cache = providers;
        credential_by_provider.remove_all();
        setting_by_provider.remove_all();
        foreach (var cred in credentials) {
            credential_by_provider.insert(cred.provider, cred);
        }
        foreach (var setting in settings) {
            setting_by_provider.insert(setting.provider, setting);
        }

        provider_names.splice(0, provider_names.get_n_items(), null);
        foreach (var provider in providers_cache) {
            var label = provider.display_name.strip().length > 0 ? provider.display_name : provider.id;
            provider_names.append(label);
        }
        if (providers_cache.size > 0) {
            provider_dropdown.set_selected(0);
        }
        status_label.set_text("Configure provider credentials and enablement.");
        var effective_model = router.effective_router_model.strip().length > 0
            ? router.effective_router_model : "(none)";
        router_summary_label.set_text(
            "Router: %s (%s)".printf(router.effective_scope, effective_model)
        );
        update_provider_controls();
    }

    private async void save_selected_provider_key() {
        if (api_client == null) {
            return;
        }
        var provider_id = selected_provider_id();
        if (provider_id.length == 0) {
            return;
        }
        var key = api_key_entry.get_text().strip();
        if (key.length == 0) {
            error_reported("AI Config", "API key cannot be empty.");
            return;
        }
        try {
            yield api_client.upsert_ai_provider_credential(provider_id, key);
            api_key_entry.set_text("");
            yield refresh(null);
        } catch (Error e) {
            error_reported("AI Config", e.message);
            debug_log_requested("Save key failed (%s): %s".printf(provider_id, e.message));
        }
    }

    private async void remove_selected_provider_key() {
        if (api_client == null) {
            return;
        }
        var provider_id = selected_provider_id();
        if (provider_id.length == 0) {
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

    private async void on_enabled_switch_toggled() {
        if (api_client == null || suppress_enable_signal) {
            return;
        }
        var provider_id = selected_provider_id();
        if (provider_id.length == 0) {
            return;
        }
        try {
            yield api_client.set_ai_provider_enabled(provider_id, enabled_switch.get_active());
            yield refresh(null);
        } catch (Error e) {
            error_reported("AI Config", e.message);
            debug_log_requested("Set enabled failed (%s): %s".printf(provider_id, e.message));
        }
    }

    private void open_selected_provider_link(bool setup) {
        var provider = selected_provider();
        if (provider == null) {
            return;
        }
        var link = setup ? provider.setup_url : provider.docs_url;
        if (link.strip().length == 0) {
            return;
        }
        try {
            AppInfo.launch_default_for_uri(link, null);
        } catch (Error e) {
            error_reported("AI Config", e.message);
        }
    }
}

}
