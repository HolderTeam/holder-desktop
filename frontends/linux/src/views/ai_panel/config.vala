namespace HolderLinux {

public class AiConfigPanelView : Object {
    private IHolderApi? api_client = null;

    private Gtk.Label status_label;
    private Gtk.ListBox providers_list;
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

        var providers_heading = new Gtk.Label("Cloud Providers");
        providers_heading.set_halign(Gtk.Align.START);
        providers_heading.add_css_class("heading");
        root.append(providers_heading);

        providers_list = new Gtk.ListBox();
        providers_list.set_selection_mode(Gtk.SelectionMode.NONE);
        providers_list.add_css_class("boxed-list");
        root.append(providers_list);

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
        router_summary_label.set_text("");
        clear_provider_rows();
    }

    private void clear_provider_rows() {
        Gtk.Widget? child = providers_list.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            providers_list.remove(child);
            child = next;
        }
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

        clear_provider_rows();

        foreach (var provider in providers_cache) {
            append_provider_row(provider);
        }
        status_label.set_text("Configure provider credentials and enablement.");
        var effective_model = router.effective_router_model.strip().length > 0
            ? router.effective_router_model : "(none)";
        router_summary_label.set_text(
            "Router: %s (%s)".printf(router.effective_scope, effective_model)
        );
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
}

}
