using GLib;

namespace HolderLinuxTests {

private bool wait_until(owned SourceFunc predicate, int timeout_ms = 2000) {
    var loop = new MainLoop();
    var deadline = GLib.get_monotonic_time() + (int64) timeout_ms * 1000;
    Timeout.add(5, () => {
        if (predicate() || GLib.get_monotonic_time() >= deadline) {
            loop.quit();
            return Source.REMOVE;
        }
        return Source.CONTINUE;
    });
    loop.run();
    return predicate();
}

private bool contains_label(Gtk.Widget? widget, string text) {
    if (widget == null) {
        return false;
    }
    var label = widget as Gtk.Label;
    if (label != null && label.get_text().contains(text)) {
        return true;
    }
    for (var child = widget.get_first_child(); child != null; child = child.get_next_sibling()) {
        if (contains_label(child, text)) {
            return true;
        }
    }
    return false;
}

private void collect_flow_boxes(Gtk.Widget? widget, Gee.ArrayList<Gtk.FlowBox> boxes) {
    if (widget == null) {
        return;
    }
    var flow_box = widget as Gtk.FlowBox;
    if (flow_box != null) {
        boxes.add(flow_box);
    }
    for (var child = widget.get_first_child(); child != null; child = child.get_next_sibling()) {
        collect_flow_boxes(child, boxes);
    }
}

private void test_cloud_card_tags_and_results() {
    var api = new MainControllerFakeApi();
    api.project_tags.add(new HolderLinux.TagCount("sync", 1));
    api.project_tags.add(new HolderLinux.TagCount("android", 3));
    api.current_card_tags = { "android" };
    api.tagged_cards.add(new HolderLinux.CardSummary(
        "c2", "p1", "Tagged card", "cards/c2.md", 2.0, null, 1, 2
    ));

    var projects = new GLib.ListStore(typeof(HolderLinux.Project));
    projects.append(new HolderLinux.Project("p1", "Project", "plain", "/tmp/p1", 1, 1));
    var project_selection = new Gtk.SingleSelection(projects);
    project_selection.set_selected(0);
    var cards = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    cards.append(new HolderLinux.CardSummary(
        "c1", "p1", "Current card", "cards/c1.md", 1.0, null, 1, 2
    ));
    var card_selection = new Gtk.SingleSelection(cards);
    card_selection.set_selected(0);

    var view = new HolderLinux.TagsToolView();
    view.set_api_client(api);
    view.bind_context(project_selection, card_selection);
    view.set_tool_visible(true);
    assert(wait_until(() => api.list_project_tags_calls > 0 && api.get_card_calls > 0));
    assert(contains_label(view.widget, "On this card"));
    assert(contains_label(view.widget, "#android"));
    assert(contains_label(view.widget, "#sync"));

    var flow_boxes = new Gee.ArrayList<Gtk.FlowBox>();
    collect_flow_boxes(view.widget, flow_boxes);
    assert(flow_boxes.size == 2);
    foreach (var flow_box in flow_boxes) {
        assert(flow_box.get_orientation() == Gtk.Orientation.HORIZONTAL);
        assert(flow_box.get_halign() == Gtk.Align.FILL);
        assert(flow_box.get_hexpand());
    }

    view.show_tag("#Android");
    assert(wait_until(() => api.list_cards_with_tag_calls == 1));
    assert(api.last_requested_tag == "android");
    assert(contains_label(view.widget, "Cards tagged #android"));
    assert(contains_label(view.widget, "Tagged card"));
    assert(view.tool_id == "tags");
    assert(view.tool_label == "Tags");
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping tags tool view tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();
    Test.add_func("/holder/tags-tool/cloud-card-tags-and-results", test_cloud_card_tags_and_results);
    return Test.run();
}

}
