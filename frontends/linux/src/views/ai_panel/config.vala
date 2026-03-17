namespace HolderLinux {

public class AiConfigPanelView : Object {
    private IHolderApi? api_client = null;
    private Gtk.Label status_label;
    private Gtk.Label effective_label;
    private Gtk.Label global_label;
    private Gtk.Label project_label;
    private Gtk.ListBox providers_list;

    public Gtk.Widget widget { get; private set; }

    public signal void error_reported(string title, string details);
    public signal void debug_log_requested(string line);

    public AiConfigPanelView() {
        widget = build_ui();
        set_idle_state("Connect to holderd to load config.");
    }

    public void set_api_client(IHolderApi? api) {
        api_client = api;
        if (api_client == null) {
            set_idle_state("Connect to holderd to load config.");
        }
    }

    public async void refresh(string? project_id = null) {
        if (api_client == null) {
            set_idle_state("Connect to holderd to load config.");
            return;
        }
        set_idle_state("Loading AI config...");
        try {
            var providers = yield api_client.list_ai_runtime_providers();
            var router = yield api_client.get_ai_router_config(project_id);
            render(providers, router);
        } catch (Error e) {
            set_idle_state("Failed to load AI config.");
            error_reported("AI Config", e.message);
            debug_log_requested("AI Config load failed: %s".printf(e.message));
        }
    }

    private Gtk.Widget build_ui() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        root.set_margin_top(8);
        root.set_margin_bottom(8);
        root.set_margin_start(8);
        root.set_margin_end(8);

        var heading = new Gtk.Label("Runtime Provider Config");
        heading.set_halign(Gtk.Align.START);
        heading.add_css_class("heading");
        root.append(heading);

        status_label = new Gtk.Label("");
        status_label.set_halign(Gtk.Align.START);
        status_label.set_wrap(true);
        root.append(status_label);

        var router_heading = new Gtk.Label("Router");
        router_heading.set_halign(Gtk.Align.START);
        router_heading.add_css_class("heading");
        root.append(router_heading);

        effective_label = new Gtk.Label("");
        effective_label.set_halign(Gtk.Align.START);
        effective_label.set_wrap(true);
        root.append(effective_label);

        global_label = new Gtk.Label("");
        global_label.set_halign(Gtk.Align.START);
        global_label.set_wrap(true);
        root.append(global_label);

        project_label = new Gtk.Label("");
        project_label.set_halign(Gtk.Align.START);
        project_label.set_wrap(true);
        root.append(project_label);

        var providers_heading = new Gtk.Label("Providers");
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

    private void set_idle_state(string message) {
        status_label.set_text(message);
        effective_label.set_text("Effective: n/a");
        global_label.set_text("Global model: n/a");
        project_label.set_text("Project model: n/a");
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

    private void append_provider_row(AiRuntimeProvider provider) {
        var row_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 3);
        row_box.set_margin_top(6);
        row_box.set_margin_bottom(6);
        row_box.set_margin_start(8);
        row_box.set_margin_end(8);

        var name = provider.display_name.strip().length > 0 ? provider.display_name : provider.id;
        var title = new Gtk.Label("%s (%s)".printf(name, provider.id));
        title.set_halign(Gtk.Align.START);
        title.add_css_class("heading");
        row_box.append(title);

        var state_line = "Configured: %s | Enabled: %s".printf(
            provider.configured ? "yes" : "no",
            provider.enabled ? "yes" : "no"
        );
        var status = new Gtk.Label(state_line);
        status.set_halign(Gtk.Align.START);
        status.add_css_class("dim-label");
        row_box.append(status);

        if (provider.setup_url.strip().length > 0) {
            var setup = new Gtk.Label("Setup URL: %s".printf(provider.setup_url));
            setup.set_halign(Gtk.Align.START);
            setup.set_wrap(true);
            row_box.append(setup);
        }
        if (provider.docs_url.strip().length > 0) {
            var docs = new Gtk.Label("Docs URL: %s".printf(provider.docs_url));
            docs.set_halign(Gtk.Align.START);
            docs.set_wrap(true);
            row_box.append(docs);
        }

        providers_list.append(row_box);
    }

    private void render(Gee.ArrayList<AiRuntimeProvider> providers,
                        AiRouterConfigInfo router) {
        status_label.set_text("%d provider(s) in runtime catalog.".printf(providers.size));
        var effective_model = router.effective_router_model.strip().length > 0
            ? router.effective_router_model : "(none)";
        var global_model = router.global_router_model.strip().length > 0
            ? router.global_router_model : "(none)";
        var project_model = router.project_router_model.strip().length > 0
            ? router.project_router_model : "(none)";

        effective_label.set_text("Effective: %s (%s)".printf(router.effective_scope, effective_model));
        global_label.set_text("Global model: %s".printf(global_model));
        if (router.project_id.strip().length > 0) {
            project_label.set_text("Project model (%s): %s".printf(router.project_id, project_model));
        } else {
            project_label.set_text("Project model: n/a");
        }

        clear_provider_rows();
        if (providers.size == 0) {
            var empty = new Gtk.Label("No runtime providers available.");
            empty.set_halign(Gtk.Align.START);
            empty.add_css_class("dim-label");
            providers_list.append(empty);
            return;
        }

        foreach (var provider in providers) {
            append_provider_row(provider);
        }
    }
}

}
