using GLib;

namespace HolderLinuxTests {

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
    assert(wait_for_condition(() => api.list_project_tags_calls > 0 && api.get_card_calls > 0));
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
    assert(wait_for_condition(() => api.list_cards_with_tag_calls == 1));
    assert(api.last_requested_tag == "android");
    assert(contains_label(view.widget, "Cards tagged #android"));
    assert(contains_label(view.widget, "Tagged card"));
    assert(view.tool_id == "tags");
    assert(view.tool_label == "Tags");
}

// ---- harness -------------------------------------------------------------------------------------

private void tg_collect(Gtk.Widget root, Gee.ArrayList<Gtk.Widget> out_widgets) {
    out_widgets.add(root);
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        tg_collect((!) child, out_widgets);
    }
}

private Gee.ArrayList<Gtk.Widget> tg_descendants(Gtk.Widget root) {
    var widgets = new Gee.ArrayList<Gtk.Widget>();
    tg_collect(root, widgets);
    return widgets;
}

private Gee.ArrayList<string> tg_label_texts(Gtk.Widget root) {
    var texts = new Gee.ArrayList<string>();
    foreach (var widget in tg_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label != null) {
            texts.add(((!) label).get_text());
        }
    }
    return texts;
}

private Gtk.Button? tg_button_with_tooltip(Gtk.Widget root, string tooltip) {
    foreach (var widget in tg_descendants(root)) {
        var button = widget as Gtk.Button;
        if (button != null && ((!) button).get_tooltip_text() == tooltip) {
            return (!) button;
        }
    }
    return null;
}

// The button a label (a tag chip or a result row title) sits in.
private Gtk.Button tg_button_around(Gtk.Widget root, string label_text) {
    foreach (var widget in tg_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label != null && ((!) label).get_text() == label_text) {
            var button = ((!) label).get_ancestor(typeof(Gtk.Button)) as Gtk.Button;
            assert(button != null);
            return (!) button;
        }
    }
    assert_not_reached();
}

private bool tg_visible(Gtk.Widget root, string label_text) {
    foreach (var widget in tg_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label != null && ((!) label).get_text() == label_text) {
            return ((!) label).get_visible();
        }
    }
    return false;
}

// list_project_tags / list_cards_with_tag that can fail, differ per tag and be held back so a test
// can act while a tag's cards are still loading.
private class TagsFakeApi : MainControllerFakeApi {
    public bool fail_tags = false;
    public bool fail_cards = false;
    public string? stall_tag = null;
    public Gee.HashMap<string, Gee.ArrayList<HolderLinux.CardSummary>> cards_by_tag =
        new Gee.HashMap<string, Gee.ArrayList<HolderLinux.CardSummary>>();
    private SourceFunc? stalled = null;

    public override async Gee.ArrayList<HolderLinux.TagCount> list_project_tags(string project_id) throws Error {
        if (fail_tags) {
            throw new IOError.FAILED("tags down");
        }
        return yield base.list_project_tags(project_id);
    }

    public override async Gee.ArrayList<HolderLinux.CardSummary> list_cards_with_tag(string project_id,
                                                                                      string tag) throws Error {
        list_cards_with_tag_calls++;
        last_requested_tag = tag;
        if (stall_tag != null && stall_tag == tag) {
            stalled = list_cards_with_tag.callback;
            yield;
        }
        if (fail_cards) {
            throw new IOError.FAILED("cards down");
        }
        var found = cards_by_tag.get(tag);
        return found != null ? found : new Gee.ArrayList<HolderLinux.CardSummary>();
    }

    public bool has_stalled_list() {
        return stalled != null;
    }

    public void release_stalled_list() {
        stall_tag = null;
        var callback = stalled;
        stalled = null;
        if (callback != null) {
            Idle.add((owned) callback);
        }
    }
}

private HolderLinux.CardSummary tg_card(string card_id, string title, int64 updated_at = 1700000000) {
    return new HolderLinux.CardSummary(card_id, "p1", title, card_id + ".md", 1.0, null, 1, updated_at);
}

private class TagsViewHarness : Object {
    public TagsFakeApi api = new TagsFakeApi();
    public HolderLinux.TagsToolView view = new HolderLinux.TagsToolView();
    public GLib.ListStore projects = new GLib.ListStore(typeof(HolderLinux.Project));
    public GLib.ListStore cards = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    public Gtk.SingleSelection project_selection;
    public Gtk.SingleSelection card_selection;
    public Gee.ArrayList<string> opened = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> errors = new Gee.ArrayList<string>();

    public TagsViewHarness(bool bind = true, bool visible = true, bool with_api = true) {
        projects.append(new HolderLinux.Project("p1", "Project 1", "plain", "/tmp/p1", 1, 1));
        projects.append(new HolderLinux.Project("p2", "Project 2", "plain", "/tmp/p2", 1, 1));
        cards.append(tg_card("c1", "Current card"));
        project_selection = new Gtk.SingleSelection(projects);
        card_selection = new Gtk.SingleSelection(cards);
        view.card_open_requested.connect((card_id) => { opened.add(card_id); });
        view.error_reported.connect((title, details) => { errors.add("%s|%s".printf(title, details)); });
        api.project_tags.add(new HolderLinux.TagCount("alpha", 3));
        api.project_tags.add(new HolderLinux.TagCount("beta", 1));
        if (with_api) {
            view.set_api_client(api);
        }
        if (bind) {
            view.bind_context(project_selection, card_selection);
        }
        if (visible) {
            view.set_tool_visible(true);
        }
    }

    public Gtk.Stack stack() {
        var stack = view.widget as Gtk.Stack;
        assert(stack != null);
        return (!) stack;
    }

    public string page() {
        return stack().get_visible_child_name();
    }

    public bool wait_for_tags_loaded() {
        return wait_for_condition(() => tg_label_texts(view.widget).contains("#alpha  3"));
    }

    public Gtk.SearchEntry search_entry() {
        var actions = view.get_actions_widget();
        assert(actions != null);
        foreach (var widget in tg_descendants((!) actions)) {
            if (widget is Gtk.SearchEntry) {
                return (Gtk.SearchEntry) widget;
            }
        }
        assert_not_reached();
    }

    public void type_filter(string text) {
        search_entry().set_text(text);
        // The entry delays its own change signal; emit it so the test does not wait on a timer.
        search_entry().search_changed();
    }

    public int result_rows() {
        int count = 0;
        foreach (var widget in tg_descendants(view.widget)) {
            var button = widget as Gtk.Button;
            if (button != null && ((!) button).has_css_class("flat")) {
                count++;
            }
        }
        return count;
    }

    public void settle() {
        var context = MainContext.default();
        for (int i = 0; i < 20; i++) {
            while (context.iteration(false)) {}
        }
    }
}

// ---- cloud, card tags and filter ------------------------------------------------------------------

private void test_the_cloud_chips_carry_counts_and_singular_or_plural_tooltips() {
    var h = new TagsViewHarness();
    assert(h.wait_for_tags_loaded());

    var alpha = tg_button_around(h.view.widget, "#alpha  3");
    var beta = tg_button_around(h.view.widget, "#beta  1");
    assert(alpha.get_tooltip_text() == "3 cards tagged #alpha");
    assert(beta.get_tooltip_text() == "1 card tagged #beta");
    // Chips are sorted by tag and the bigger tag is weighted heavier.
    assert(h.page() == "overview");
    assert(!tg_visible(h.view.widget, "No tags in this project yet."));
}

private void test_the_current_cards_tags_are_offered_and_an_untagged_card_says_so() {
    var h = new TagsViewHarness();
    h.api.current_card_tags = { "alpha", "gamma" };
    assert(h.wait_for_tags_loaded());
    assert(wait_for_condition(() => tg_label_texts(h.view.widget).contains("#gamma")));
    assert(tg_button_with_tooltip(h.view.widget, "Show cards tagged #gamma") != null);
    assert(!tg_visible(h.view.widget, "This card has no tags."));

    h.api.current_card_tags = {};
    h.card_selection.notify_property("selected-item");
    assert(wait_for_condition(() => tg_visible(h.view.widget, "This card has no tags.")));
}

private void test_typing_in_the_filter_narrows_the_cloud_and_explains_an_empty_result() {
    var h = new TagsViewHarness();
    assert(h.wait_for_tags_loaded());

    h.type_filter("be");
    assert(!tg_label_texts(h.view.widget).contains("#alpha  3"));
    assert(tg_label_texts(h.view.widget).contains("#beta  1"));

    h.type_filter("zzz");
    assert(!tg_label_texts(h.view.widget).contains("#beta  1"));
    assert(tg_visible(h.view.widget, "No tags match this filter."));

    h.type_filter("");
    assert(tg_label_texts(h.view.widget).contains("#alpha  3"));
    assert(!tg_visible(h.view.widget, "No tags match this filter."));
}

private void test_a_project_with_no_tags_says_so_even_while_a_filter_is_typed() {
    var h = new TagsViewHarness(true, false);
    h.api.project_tags.clear();
    h.view.set_tool_visible(true);
    assert(wait_for_condition(() => h.api.list_project_tags_calls >= 1));
    h.settle();
    assert(tg_visible(h.view.widget, "No tags in this project yet."));

    h.type_filter("x");

    // There are no tags for the filter to have ruled out, so "no match" would be the wrong reason.
    assert(tg_visible(h.view.widget, "No tags in this project yet."));
    assert(!tg_visible(h.view.widget, "No tags match this filter."));
}

private void test_the_refresh_button_reloads_the_tags() {
    var h = new TagsViewHarness();
    assert(h.wait_for_tags_loaded());
    var before = h.api.list_project_tags_calls;

    var refresh = tg_button_with_tooltip((!) h.view.get_actions_widget(), "Refresh tags");
    assert(refresh != null);
    ((!) refresh).clicked();

    assert(wait_for_condition(() => h.api.list_project_tags_calls == before + 1));
}

// ---- results --------------------------------------------------------------------------------------

private void test_clicking_a_chip_lists_the_cards_and_a_result_opens_its_card() {
    var h = new TagsViewHarness();
    h.api.cards_by_tag.set("alpha", new Gee.ArrayList<HolderLinux.CardSummary>());
    h.api.cards_by_tag.get("alpha").add(tg_card("c7", "Seventh", 1700000000));
    h.api.cards_by_tag.get("alpha").add(tg_card("c8", "Eighth", 0));
    assert(h.wait_for_tags_loaded());

    tg_button_around(h.view.widget, "#alpha  3").clicked();

    assert(wait_for_condition(() => tg_label_texts(h.view.widget).contains("Seventh")));
    assert(h.page() == "results");
    assert(tg_label_texts(h.view.widget).contains("Cards tagged #alpha"));
    assert(tg_label_texts(h.view.widget).contains("Eighth"));
    assert(tg_label_texts(h.view.widget).contains(HolderLinux.TagsPresenter.format_updated_at(1700000000)));
    assert(h.result_rows() == 2);
    assert(!tg_visible(h.view.widget, "No cards carry this tag."));

    tg_button_around(h.view.widget, "Eighth").clicked();
    assert(h.opened.size == 1 && h.opened[0] == "c8");

    var back = tg_button_with_tooltip(h.view.widget, "Back to tag cloud");
    assert(back != null);
    ((!) back).clicked();
    assert(h.page() == "overview");
}

private void test_a_tag_nobody_carries_says_so() {
    var h = new TagsViewHarness();
    assert(h.wait_for_tags_loaded());

    h.view.show_tag("orphan");

    assert(wait_for_condition(() => tg_visible(h.view.widget, "No cards carry this tag.")));
    assert(h.page() == "results");
    assert(h.result_rows() == 0);
}

private void test_show_tag_normalises_the_tag_and_ignores_an_empty_one() {
    var h = new TagsViewHarness();
    assert(h.wait_for_tags_loaded());

    h.view.show_tag("  #AlPhA ");
    assert(wait_for_condition(() => h.api.list_cards_with_tag_calls == 1));
    assert(h.api.last_requested_tag == "alpha");

    h.view.show_tag("#");
    h.view.show_tag("   ");
    h.settle();
    assert(h.api.list_cards_with_tag_calls == 1);
}

private void test_a_tag_asked_for_before_the_tool_is_shown_waits_for_it() {
    var h = new TagsViewHarness(true, false);

    h.view.show_tag("Alpha");
    h.settle();
    assert(h.api.list_cards_with_tag_calls == 0);

    h.view.set_tool_visible(true);

    assert(wait_for_condition(() => h.api.list_cards_with_tag_calls == 1));
    assert(h.api.last_requested_tag == "alpha");
    assert(h.page() == "results");
}

private void test_a_tag_asked_for_without_an_api_or_project_waits_for_them() {
    var h = new TagsViewHarness(false, true, false);
    h.view.show_tag("alpha");
    h.settle();
    assert(h.api.list_cards_with_tag_calls == 0);

    h.view.set_api_client(h.api);
    h.settle();
    // Still no project selected.
    assert(h.api.list_cards_with_tag_calls == 0);

    h.view.bind_context(h.project_selection, h.card_selection);

    assert(wait_for_condition(() => h.api.list_cards_with_tag_calls == 1));
    assert(h.api.last_requested_tag == "alpha");
    assert(h.page() == "results");
}

private void test_going_back_or_navigating_drops_a_tag_that_was_still_waiting() {
    var h = new TagsViewHarness(true, false);
    h.view.show_tag("alpha");
    bool done = false;
    h.view.navigate_to_projects_root.begin(null, (obj, res) => {
        assert(h.view.navigate_to_projects_root.end(res));
        done = true;
    });
    assert(wait_for_condition(() => done));

    h.view.set_tool_visible(true);
    assert(h.wait_for_tags_loaded());
    h.settle();
    assert(h.api.list_cards_with_tag_calls == 0);
    assert(h.page() == "overview");

    h.view.show_tag("alpha");
    assert(wait_for_condition(() => h.page() == "results"));
    done = false;
    h.view.navigate_to_project_root.begin("p1", (obj, res) => {
        assert(h.view.navigate_to_project_root.end(res));
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(h.page() == "overview");

    h.view.show_tag("alpha");
    assert(wait_for_condition(() => h.page() == "results"));
    done = false;
    h.view.navigate_to_card.begin("c1", (obj, res) => {
        assert(h.view.navigate_to_card.end(res));
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(h.page() == "overview");
}

// ---- failures, missing context and visibility ----------------------------------------------------

private void test_a_failed_tag_load_and_a_failed_cards_load_are_reported() {
    var h = new TagsViewHarness(true, false);
    h.api.fail_tags = true;
    h.view.set_tool_visible(true);
    assert(wait_for_condition(() => h.errors.contains("Could not load tags|tags down")));

    h.api.fail_tags = false;
    h.api.fail_cards = true;
    h.view.show_tag("alpha");
    assert(wait_for_condition(() => h.errors.contains("Could not load tagged cards|cards down")));
    assert(h.page() == "results");
    assert(h.result_rows() == 0);
}

private void test_without_an_api_or_a_project_the_tool_shows_nothing_to_pick() {
    var h = new TagsViewHarness();
    h.api.current_card_tags = { "alpha" };
    assert(h.wait_for_tags_loaded());
    assert(wait_for_condition(() => tg_label_texts(h.view.widget).contains("#alpha")));

    h.view.set_api_client(null);

    assert(wait_for_condition(() => tg_visible(h.view.widget, "No tags in this project yet.")));
    assert(tg_visible(h.view.widget, "This card has no tags."));
    assert(!tg_label_texts(h.view.widget).contains("#alpha  3"));
}

private void test_a_hidden_tool_does_not_reload_until_it_is_shown() {
    var h = new TagsViewHarness(true, false);
    h.settle();
    assert(h.api.list_project_tags_calls == 0);

    h.project_selection.set_selected(1);
    h.card_selection.notify_property("selected-item");
    h.settle();
    assert(h.api.list_project_tags_calls == 0);

    h.view.set_tool_visible(true);
    assert(wait_for_condition(() => h.api.list_project_tags_calls == 1));
    h.view.set_tool_visible(false);
    h.settle();
    assert(h.api.list_project_tags_calls == 1);
}

private void test_the_tool_describes_itself_for_the_shell() {
    var h = new TagsViewHarness();
    assert(h.view.tool_id == "tags" && h.view.tool_label == "Tags");
    assert(h.view.get_content_widget() == h.view.widget);
    assert(h.view.get_actions_widget() != null);
    var scope = h.view.get_scope_snapshot(null, null);
    assert(scope.project_label == "Projects");
    assert(scope.scope_mode == HolderLinux.ToolScopeMode.PROJECTS_ROOT);
}

// ---- regressions ---------------------------------------------------------------------------------

private void test_binding_a_new_context_stops_listening_to_the_old_selections() {
    var h = new TagsViewHarness();
    assert(h.wait_for_tags_loaded());
    var replacement_projects = new Gtk.SingleSelection(h.projects);
    var replacement_cards = new Gtk.SingleSelection(h.cards);
    h.view.bind_context(replacement_projects, replacement_cards);
    assert(wait_for_condition(() => h.api.list_project_tags_calls >= 2));
    h.settle();
    var before = h.api.list_project_tags_calls;

    // The first selections are no longer the view's: moving them must not reload anything.
    h.project_selection.set_selected(1);
    h.card_selection.notify_property("selected-item");
    h.settle();
    assert(h.api.list_project_tags_calls == before);

    replacement_projects.set_selected(1);
    assert(wait_for_condition(() => h.api.list_project_tags_calls == before + 1));
}

private void test_binding_the_same_context_twice_does_not_double_the_reloads() {
    var h = new TagsViewHarness();
    h.view.bind_context(h.project_selection, h.card_selection);
    h.view.bind_context(h.project_selection, h.card_selection);
    h.settle();
    var before = h.api.list_project_tags_calls;

    h.project_selection.set_selected(1);
    h.settle();

    // Each extra bind used to leave another pair of handlers, so one change loaded the tags again
    // and again.
    assert(h.api.list_project_tags_calls == before + 1);
}

private void test_a_slow_tag_cannot_overwrite_the_results_of_the_tag_clicked_after_it() {
    var h = new TagsViewHarness();
    h.api.cards_by_tag.set("alpha", new Gee.ArrayList<HolderLinux.CardSummary>());
    h.api.cards_by_tag.get("alpha").add(tg_card("a1", "Only in alpha"));
    h.api.cards_by_tag.set("beta", new Gee.ArrayList<HolderLinux.CardSummary>());
    h.api.cards_by_tag.get("beta").add(tg_card("b1", "Only in beta"));
    assert(h.wait_for_tags_loaded());

    h.api.stall_tag = "alpha";
    tg_button_around(h.view.widget, "#alpha  3").clicked();
    assert(wait_for_condition(() => h.api.has_stalled_list()));
    tg_button_around(h.view.widget, "#beta  1").clicked();
    assert(wait_for_condition(() => tg_label_texts(h.view.widget).contains("Only in beta")));

    h.api.release_stalled_list();
    assert(wait_for_condition(() => !h.api.has_stalled_list()));
    h.settle();

    // Alpha's cards arrived last but belong to a page the user has already left.
    assert(tg_label_texts(h.view.widget).contains("Cards tagged #beta"));
    assert(!tg_label_texts(h.view.widget).contains("Only in alpha"));
    assert(h.result_rows() == 1);
}

private void test_changing_project_while_reading_results_returns_to_the_cloud() {
    var h = new TagsViewHarness();
    h.api.cards_by_tag.set("alpha", new Gee.ArrayList<HolderLinux.CardSummary>());
    h.api.cards_by_tag.get("alpha").add(tg_card("a1", "Project one card"));
    assert(h.wait_for_tags_loaded());
    h.view.show_tag("alpha");
    assert(wait_for_condition(() => tg_label_texts(h.view.widget).contains("Project one card")));
    assert(h.page() == "results");

    h.project_selection.set_selected(1);

    // The listed cards belong to Project 1, and clicking one would ask for a card the new project
    // does not have.
    assert(h.page() == "overview");
    assert(h.result_rows() == 0);
    assert(!tg_label_texts(h.view.widget).contains("Project one card"));
}

private void test_losing_the_api_while_reading_results_returns_to_the_cloud() {
    var h = new TagsViewHarness();
    h.api.cards_by_tag.set("alpha", new Gee.ArrayList<HolderLinux.CardSummary>());
    h.api.cards_by_tag.get("alpha").add(tg_card("a1", "Project one card"));
    assert(h.wait_for_tags_loaded());
    h.view.show_tag("alpha");
    assert(wait_for_condition(() => h.page() == "results"));

    h.view.set_api_client(null);

    assert(wait_for_condition(() => h.page() == "overview"));
    assert(h.result_rows() == 0);
}

private void test_a_slow_tag_load_finishing_after_a_project_change_is_dropped() {
    var h = new TagsViewHarness();
    h.api.cards_by_tag.set("alpha", new Gee.ArrayList<HolderLinux.CardSummary>());
    h.api.cards_by_tag.get("alpha").add(tg_card("a1", "Late project one card"));
    assert(h.wait_for_tags_loaded());
    h.api.stall_tag = "alpha";
    h.view.show_tag("alpha");
    assert(wait_for_condition(() => h.api.has_stalled_list()));

    h.project_selection.set_selected(1);
    h.api.release_stalled_list();
    assert(wait_for_condition(() => !h.api.has_stalled_list()));
    h.settle();

    assert(h.page() == "overview");
    assert(h.result_rows() == 0);
}

private void test_a_tag_waiting_for_a_project_survives_that_project_being_selected() {
    var h = new TagsViewHarness(false);
    h.api.cards_by_tag.set("alpha", new Gee.ArrayList<HolderLinux.CardSummary>());
    h.api.cards_by_tag.get("alpha").add(tg_card("a1", "Waited-for card"));
    var no_project = new Gtk.SingleSelection(h.projects);
    no_project.set_autoselect(false);
    no_project.set_can_unselect(true);
    no_project.unselect_item(no_project.get_selected());
    h.view.bind_context(no_project, h.card_selection);
    h.settle();
    h.view.show_tag("alpha");
    h.settle();
    assert(h.api.list_cards_with_tag_calls == 0);

    no_project.set_selected(0);

    assert(wait_for_condition(() => tg_label_texts(h.view.widget).contains("Waited-for card")));
    assert(h.page() == "results");
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping tags tool view tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();
    Test.add_func("/holder/tags-tool/cloud-card-tags-and-results", test_cloud_card_tags_and_results);
    Test.add_func("/holder/tags-tool/cloud-chips", test_the_cloud_chips_carry_counts_and_singular_or_plural_tooltips);
    Test.add_func("/holder/tags-tool/card-tags", test_the_current_cards_tags_are_offered_and_an_untagged_card_says_so);
    Test.add_func("/holder/tags-tool/filter", test_typing_in_the_filter_narrows_the_cloud_and_explains_an_empty_result);
    Test.add_func("/holder/tags-tool/filter-no-tags", test_a_project_with_no_tags_says_so_even_while_a_filter_is_typed);
    Test.add_func("/holder/tags-tool/refresh-button", test_the_refresh_button_reloads_the_tags);
    Test.add_func("/holder/tags-tool/results", test_clicking_a_chip_lists_the_cards_and_a_result_opens_its_card);
    Test.add_func("/holder/tags-tool/results-empty", test_a_tag_nobody_carries_says_so);
    Test.add_func("/holder/tags-tool/show-tag-normalises", test_show_tag_normalises_the_tag_and_ignores_an_empty_one);
    Test.add_func("/holder/tags-tool/pending-until-visible", test_a_tag_asked_for_before_the_tool_is_shown_waits_for_it);
    Test.add_func("/holder/tags-tool/pending-until-context", test_a_tag_asked_for_without_an_api_or_project_waits_for_them);
    Test.add_func("/holder/tags-tool/navigation-drops-pending", test_going_back_or_navigating_drops_a_tag_that_was_still_waiting);
    Test.add_func("/holder/tags-tool/failures", test_a_failed_tag_load_and_a_failed_cards_load_are_reported);
    Test.add_func("/holder/tags-tool/no-context", test_without_an_api_or_a_project_the_tool_shows_nothing_to_pick);
    Test.add_func("/holder/tags-tool/hidden-tool", test_a_hidden_tool_does_not_reload_until_it_is_shown);
    Test.add_func("/holder/tags-tool/shell", test_the_tool_describes_itself_for_the_shell);
    Test.add_func("/holder/tags-tool/rebind-old-selections", test_binding_a_new_context_stops_listening_to_the_old_selections);
    Test.add_func("/holder/tags-tool/rebind-same-twice", test_binding_the_same_context_twice_does_not_double_the_reloads);
    Test.add_func("/holder/tags-tool/results-race", test_a_slow_tag_cannot_overwrite_the_results_of_the_tag_clicked_after_it);
    Test.add_func("/holder/tags-tool/project-change-leaves-results", test_changing_project_while_reading_results_returns_to_the_cloud);
    Test.add_func("/holder/tags-tool/api-loss-leaves-results", test_losing_the_api_while_reading_results_returns_to_the_cloud);
    Test.add_func("/holder/tags-tool/slow-tag-after-project-change", test_a_slow_tag_load_finishing_after_a_project_change_is_dropped);
    Test.add_func("/holder/tags-tool/pending-survives-project-select", test_a_tag_waiting_for_a_project_survives_that_project_being_selected);
    return Test.run();
}

}
