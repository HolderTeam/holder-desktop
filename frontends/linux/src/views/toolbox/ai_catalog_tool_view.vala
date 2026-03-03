namespace HolderLinux {

public class AiCatalogToolView : Object {
    private IHolderApi? api;
    private AiCatalogController controller;
    private Gtk.ListBox ai_catalog_list;

    public Gtk.Widget widget { get; private set; }

    public signal void error_reported(string title, string details);
    public signal void debug_log_requested(string line);

    public AiCatalogToolView() {
        controller = new AiCatalogController();
        widget = build_ui();
    }

    public void set_api_client(IHolderApi? api) {
        this.api = api;
    }

    public async void refresh() {
        if (api == null) {
            return;
        }
        clear_list_box(ai_catalog_list);
        try {
            var providers = yield api.list_ai_provider_catalog();
            if (providers.size == 0) {
                ai_catalog_list.append(new Gtk.Label("No providers in catalog.") { xalign = 0.0f });
                return;
            }
            foreach (var provider in providers) {
                var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
                var title_label = new Gtk.Label(controller.title_for_provider(provider)) { xalign = 0.0f };
                title_label.add_css_class("title-5");
                var detail_label = new Gtk.Label(controller.status_for_provider(provider)) { xalign = 0.0f };
                detail_label.add_css_class("dim-label");
                detail_label.set_wrap(true);
                row.append(title_label);
                row.append(detail_label);
                if (controller.has_urls(provider)) {
                    var urls = new Gtk.Label(controller.urls_for_provider(provider)) { xalign = 0.0f };
                    urls.add_css_class("caption");
                    urls.add_css_class("dim-label");
                    urls.set_wrap(true);
                    row.append(urls);
                }
                ai_catalog_list.append(row);
            }
            debug_log_requested("AI catalog refreshed: %d providers".printf(providers.size));
        } catch (Error e) {
            debug_log_requested("AI catalog refresh failed: %s".printf(e.message));
            error_reported("AI catalog refresh failed", e.message);
        }
    }

    private Gtk.Widget build_ui() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var refresh_btn = new Gtk.Button.with_label("Refresh Catalog");
        refresh_btn.clicked.connect(() => {
            refresh.begin();
        });
        actions.append(refresh_btn);
        box.append(actions);

        ai_catalog_list = new Gtk.ListBox();
        ai_catalog_list.set_selection_mode(Gtk.SelectionMode.NONE);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_vexpand(true);
        scroll.set_child(ai_catalog_list);
        box.append(scroll);
        return box;
    }

    private void clear_list_box(Gtk.ListBox list) {
        Gtk.Widget? child = list.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            list.remove(child);
            child = next;
        }
    }
}

}
