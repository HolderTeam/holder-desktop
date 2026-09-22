using GLib;

namespace HolderLinuxTests {

// A load held open by the fake source until the test releases it, so a test can decide the order in
// which overlapping loads answer.
private class StalledLoad : Object {
    public SourceFunc resume;
    public Gee.ArrayList<HolderLinux.AiCatalogProvider> answer;
    public Error? failure;
}

private class FakeAiCatalogProviderSource : Object, HolderLinux.IAiCatalogProviderSource {
    public Gee.ArrayList<HolderLinux.AiCatalogProvider> providers =
        new Gee.ArrayList<HolderLinux.AiCatalogProvider>();
    public Error? next_error = null;
    public bool stall = false;
    public Gee.ArrayList<StalledLoad> stalled = new Gee.ArrayList<StalledLoad>();

    public async Gee.ArrayList<HolderLinux.AiCatalogProvider> list_ai_provider_catalog() throws Error {
        if (stall) {
            var load = new StalledLoad();
            load.answer = new Gee.ArrayList<HolderLinux.AiCatalogProvider>();
            load.answer.add_all(providers);
            load.failure = next_error;
            next_error = null;
            load.resume = list_ai_provider_catalog.callback;
            stalled.add(load);
            yield;
            if (load.failure != null) {
                throw load.failure;
            }
            return load.answer;
        }
        if (next_error != null) {
            var error = next_error;
            next_error = null;
            throw error;
        }
        return providers;
    }

    public void release(int index) {
        stalled[index].resume();
    }
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

private HolderLinux.AiCatalogProvider openai_provider() {
    return new HolderLinux.AiCatalogProvider("openai", "OpenAI", true, false, "", "");
}

private Gtk.ListBox catalog_list(HolderLinux.AiCatalogPanelView view) {
    var list = find_list_box(view.widget) as Gtk.ListBox;
    assert(list != null);
    return (!) list;
}

private void test_overlapping_refreshes_render_the_rows_once() {
    var view = new HolderLinux.AiCatalogPanelView();
    var source = new FakeAiCatalogProviderSource();
    source.providers.add(openai_provider());
    source.stall = true;
    view.set_catalog_source(source);
    bool first_done = false;
    bool second_done = false;

    // A double-click on "Refresh Catalog": two loads are in flight at once.
    view.refresh.begin((obj, res) => { view.refresh.end(res); first_done = true; });
    view.refresh.begin((obj, res) => { view.refresh.end(res); second_done = true; });
    assert(source.stalled.size == 2);

    source.release(0);
    assert(wait_for_condition(() => first_done));
    source.release(1);
    assert(wait_for_condition(() => second_done));

    assert(list_box_row_count(catalog_list(view)) == 1);
    assert(collect_widget_text(catalog_list(view)).contains("OpenAI (openai)"));
}

private void test_a_load_for_a_replaced_source_is_not_rendered() {
    var view = new HolderLinux.AiCatalogPanelView();
    var old_source = new FakeAiCatalogProviderSource();
    old_source.providers.add(openai_provider());
    old_source.stall = true;
    view.set_catalog_source(old_source);
    string debug_line = "";
    view.debug_log_requested.connect((line) => { debug_line = line; });
    bool done = false;
    view.refresh.begin((obj, res) => { view.refresh.end(res); done = true; });
    assert(old_source.stalled.size == 1);

    view.set_catalog_source(new FakeAiCatalogProviderSource());
    old_source.release(0);
    assert(wait_for_condition(() => done));

    assert(list_box_row_count(catalog_list(view)) == 0);
    assert(debug_line == "");
}

private void test_a_failed_load_for_a_replaced_source_is_not_reported() {
    var view = new HolderLinux.AiCatalogPanelView();
    var old_source = new FakeAiCatalogProviderSource();
    old_source.stall = true;
    old_source.next_error = new IOError.FAILED("old catalog failed");
    view.set_catalog_source(old_source);
    string error_title = "";
    string debug_line = "";
    view.error_reported.connect((title, details) => { error_title = title; });
    view.debug_log_requested.connect((line) => { debug_line = line; });
    bool done = false;
    view.refresh.begin((obj, res) => { view.refresh.end(res); done = true; });
    assert(old_source.stalled.size == 1);

    view.set_api_client(null);
    old_source.release(0);
    assert(wait_for_condition(() => done));

    assert(error_title == "");
    assert(debug_line == "");
}

private void test_refreshing_without_a_source_does_nothing() {
    var view = new HolderLinux.AiCatalogPanelView();
    bool signalled = false;
    view.error_reported.connect((title, details) => { signalled = true; });
    view.debug_log_requested.connect((line) => { signalled = true; });
    bool done = false;

    view.refresh.begin((obj, res) => { view.refresh.end(res); done = true; });

    assert(wait_for_condition(() => done));
    assert(!signalled);
    assert(list_box_row_count(catalog_list(view)) == 0);
}

private void test_the_refresh_button_loads_the_catalog() {
    var view = new HolderLinux.AiCatalogPanelView();
    var source = new FakeAiCatalogProviderSource();
    source.providers.add(openai_provider());
    view.set_catalog_source(source);
    var button = find_button(view.widget, "Refresh Catalog");
    assert(button != null);
    assert(list_box_row_count(catalog_list(view)) == 0);

    ((!) button).clicked();

    assert(wait_for_condition(() => list_box_row_count(catalog_list(view)) == 1));
    assert(collect_widget_text(catalog_list(view)).contains("OpenAI (openai)"));
}

private void test_the_api_client_is_the_catalog_source_until_it_is_removed() {
    var view = new HolderLinux.AiCatalogPanelView();
    view.set_api_client(new MainControllerFakeApi());
    bool done = false;

    view.refresh.begin((obj, res) => { view.refresh.end(res); done = true; });
    assert(wait_for_condition(() => done));
    assert(collect_widget_text(catalog_list(view)).contains("No providers in catalog."));

    view.set_api_client(null);
    string debug_line = "";
    view.debug_log_requested.connect((line) => { debug_line = line; });
    done = false;
    view.refresh.begin((obj, res) => { view.refresh.end(res); done = true; });
    assert(wait_for_condition(() => done));
    // Without a source the last rows stay and nothing new is reported.
    assert(debug_line == "");
}

private Gtk.Button? find_button(Gtk.Widget root, string label) {
    var button = root as Gtk.Button;
    if (button != null && ((!) button).get_label() == label) {
        return button;
    }
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        var found = find_button((!) child, label);
        if (found != null) {
            return found;
        }
    }
    return null;
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
    Test.add_func("/ai_catalog_panel_view/overlapping_refreshes_render_once",
                  test_overlapping_refreshes_render_the_rows_once);
    Test.add_func("/ai_catalog_panel_view/replaced_source_load_not_rendered",
                  test_a_load_for_a_replaced_source_is_not_rendered);
    Test.add_func("/ai_catalog_panel_view/replaced_source_failure_not_reported",
                  test_a_failed_load_for_a_replaced_source_is_not_reported);
    Test.add_func("/ai_catalog_panel_view/refresh_without_source_does_nothing",
                  test_refreshing_without_a_source_does_nothing);
    Test.add_func("/ai_catalog_panel_view/refresh_button_loads_catalog",
                  test_the_refresh_button_loads_the_catalog);
    Test.add_func("/ai_catalog_panel_view/api_client_is_the_source",
                  test_the_api_client_is_the_catalog_source_until_it_is_removed);

    return Test.run();
}

}
