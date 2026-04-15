using GLib;

namespace HolderLinuxTests {

private class FakeAiCatalogProviderSource : Object, HolderLinux.IAiCatalogProviderSource {
    public Gee.ArrayList<HolderLinux.AiCatalogProvider> providers =
        new Gee.ArrayList<HolderLinux.AiCatalogProvider>();
    public Error? next_error = null;

    public async Gee.ArrayList<HolderLinux.AiCatalogProvider> list_ai_provider_catalog() throws Error {
        if (next_error != null) {
            var error = next_error;
            next_error = null;
            throw error;
        }
        return providers;
    }
}

private delegate bool ConditionFunc();

private bool wait_for_condition(owned ConditionFunc condition, uint timeout_ms = 1000) {
    var loop = new MainLoop(null, false);
    var deadline = get_monotonic_time() + (int64) timeout_ms * 1000;

    Timeout.add(10, () => {
        if (condition()) {
            loop.quit();
            return Source.REMOVE;
        }
        if (get_monotonic_time() >= deadline) {
            loop.quit();
            return Source.REMOVE;
        }
        return Source.CONTINUE;
    });

    loop.run();
    return condition();
}

private Gtk.Widget? find_list_box(Gtk.Widget root) {
    if (root is Gtk.ListBox) {
        return root;
    }

    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        var match = find_list_box(child);
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

private int list_box_row_count(Gtk.ListBox list) {
    int count = 0;
    Gtk.Widget? child = list.get_first_child();
    while (child != null) {
        count++;
        child = child.get_next_sibling();
    }
    return count;
}

private void test_refresh_with_empty_catalog_shows_empty_message() {
    var view = new HolderLinux.AiCatalogPanelView();
    var source = new FakeAiCatalogProviderSource();
    view.set_catalog_source(source);

    bool done = false;
    view.refresh.begin((obj, res) => {
        view.refresh.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));

    var list = find_list_box(view.widget) as Gtk.ListBox;
    assert(list != null);
    assert(list_box_row_count((!) list) == 1);
    assert(collect_widget_text((!) list).contains("No providers in catalog."));
}

private void test_refresh_with_providers_renders_rows_and_debug_log() {
    var view = new HolderLinux.AiCatalogPanelView();
    var source = new FakeAiCatalogProviderSource();
    source.providers.add(new HolderLinux.AiCatalogProvider(
        "openai", "OpenAI", true, false, "https://setup", "https://docs"
    ));
    source.providers.add(new HolderLinux.AiCatalogProvider(
        "local", "Local", false, true, "", ""
    ));
    view.set_catalog_source(source);

    string debug_line = "";
    view.debug_log_requested.connect((line) => {
        debug_line = line;
    });

    bool done = false;
    view.refresh.begin((obj, res) => {
        view.refresh.end(res);
        done = true;
    });

    assert(wait_for_condition(() => done));

    var list = find_list_box(view.widget) as Gtk.ListBox;
    assert(list != null);
    assert(list_box_row_count((!) list) == 2);
    var text = collect_widget_text((!) list);
    assert(text.contains("OpenAI (openai)"));
    assert(text.contains("enabled=yes configured=no"));
    assert(text.contains("setup: https://setup"));
    assert(text.contains("docs: https://docs"));
    assert(text.contains("Local (local)"));
    assert(text.contains("enabled=no configured=yes"));
    assert(debug_line == "AI catalog refreshed: 2 providers");
}

private void test_refresh_failure_reports_error_and_clears_previous_rows() {
    var view = new HolderLinux.AiCatalogPanelView();
    var source = new FakeAiCatalogProviderSource();
    source.providers.add(new HolderLinux.AiCatalogProvider(
        "openai", "OpenAI", true, true, "", ""
    ));
    view.set_catalog_source(source);

    bool first_done = false;
    view.refresh.begin((obj, res) => {
        view.refresh.end(res);
        first_done = true;
    });
    assert(wait_for_condition(() => first_done));

    string debug_line = "";
    string error_title = "";
    string error_details = "";
    view.debug_log_requested.connect((line) => {
        debug_line = line;
    });
    view.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });

    source.next_error = new IOError.FAILED("catalog failed");
    bool second_done = false;
    view.refresh.begin((obj, res) => {
        view.refresh.end(res);
        second_done = true;
    });

    assert(wait_for_condition(() => second_done));

    var list = find_list_box(view.widget) as Gtk.ListBox;
    assert(list != null);
    assert(list_box_row_count((!) list) == 0);
    assert(debug_line == "AI catalog refresh failed: catalog failed");
    assert(error_title == "AI catalog refresh failed");
    assert(error_details == "catalog failed");
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping AI catalog panel view tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    Test.add_func("/ai_catalog_panel_view/refresh_with_empty_catalog_shows_empty_message",
                  test_refresh_with_empty_catalog_shows_empty_message);
    Test.add_func("/ai_catalog_panel_view/refresh_with_providers_renders_rows_and_debug_log",
                  test_refresh_with_providers_renders_rows_and_debug_log);
    Test.add_func("/ai_catalog_panel_view/refresh_failure_reports_error_and_clears_previous_rows",
                  test_refresh_failure_reports_error_and_clears_previous_rows);

    return Test.run();
}

}
