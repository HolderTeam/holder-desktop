namespace HolderLinux {

public class TagsToolView : Object, IToolShellAdapter {
    private IHolderApi? api;
    private Gtk.SingleSelection? project_selection;
    private Gtk.SingleSelection? card_selection;
    private Gtk.Box actions_bar;
    private Gtk.SearchEntry search_entry;
    private Gtk.Stack content_stack;
    private Gtk.FlowBox card_tags_box;
    private Gtk.FlowBox cloud_box;
    private Gtk.Label card_tags_empty;
    private Gtk.Label cloud_empty;
    private Gtk.Label results_title;
    private Gtk.ListBox results_list;
    private Gtk.Label results_empty;
    private Gee.ArrayList<TagCount> all_tags = new Gee.ArrayList<TagCount>();
    private uint refresh_serial = 0;
    private bool tool_visible = false;
    private string? pending_tag;

    public Gtk.Widget widget { get; private set; }
    public string tool_id { owned get { return "tags"; } }
    public string tool_label { owned get { return "Tags"; } }

    public signal void card_open_requested(string card_id);
    public signal void error_reported(string title, string details);

    public TagsToolView() {
        widget = build_ui();
    }

    public Gtk.Widget get_content_widget() { return widget; }
    public Gtk.Widget? get_actions_widget() { return actions_bar; }

    public void set_api_client(IHolderApi? api) {
        this.api = api;
        queue_refresh();
    }

    public void bind_context(Gtk.SingleSelection project_selection,
                             Gtk.SingleSelection card_selection) {
        this.project_selection = project_selection;
        this.card_selection = card_selection;
        project_selection.notify["selected-item"].connect(() => { queue_refresh(); });
        card_selection.notify["selected-item"].connect(() => { queue_refresh(); });
        queue_refresh();
    }

    public void set_tool_visible(bool visible) {
        tool_visible = visible;
        if (visible) {
            queue_refresh();
        }
    }

    public void show_tag(string tag) {
        var normalized = tag.down().strip();
        if (normalized.has_prefix("#")) {
            normalized = normalized.substring(1);
        }
        if (normalized.length == 0) {
            return;
        }
        if (!tool_visible || api == null || selected_project() == null) {
            pending_tag = normalized;
            return;
        }
        pending_tag = null;
        show_tag_results.begin(normalized);
    }

    public ToolScopeSnapshot get_scope_snapshot(Project? selected_project,
                                                 CardSummary? selected_card) {
        var project_id = selected_project != null ? selected_project.project_id : null;
        var project_label = selected_project != null ? selected_project.name : "Projects";
        var card_id = selected_card != null ? selected_card.card_id : null;
        var card_label = selected_card != null ? selected_card.title : "Overview";
        var scope = selected_card != null ? ToolScopeMode.CARD_FOCUS : ToolScopeMode.PROJECT_ROOT;
        if (project_id == null) {
            scope = ToolScopeMode.PROJECTS_ROOT;
            card_id = null;
            card_label = "Overview";
        }
        return new ToolScopeSnapshot(
            tool_id, tool_label, project_id, project_label, card_id, card_label, scope, false
        );
    }

    public async bool navigate_to_projects_root(string? selected_project_id) {
        show_overview();
        return true;
    }

    public async bool navigate_to_project_root(string project_id) {
        show_overview();
        return true;
    }

    public async bool navigate_to_card(string card_id) {
        show_overview();
        return true;
    }

    private Gtk.Widget build_ui() {
        actions_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        search_entry = new Gtk.SearchEntry();
        search_entry.set_placeholder_text("Filter tags…");
        search_entry.set_hexpand(true);
        search_entry.search_changed.connect(() => { rebuild_cloud(); });
        actions_bar.append(search_entry);

        var refresh_button = new Gtk.Button.from_icon_name("view-refresh-symbolic");
        refresh_button.set_tooltip_text("Refresh tags");
        refresh_button.clicked.connect(() => { queue_refresh(); });
        actions_bar.append(refresh_button);

        content_stack = new Gtk.Stack();
        content_stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        content_stack.set_vexpand(true);
        content_stack.add_named(build_overview(), "overview");
        content_stack.add_named(build_results(), "results");
        content_stack.set_visible_child_name("overview");
        return content_stack;
    }

    private Gtk.Widget build_overview() {
        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
        content.set_margin_top(12);
        content.set_margin_bottom(12);
        content.set_margin_start(12);
        content.set_margin_end(12);

        var card_heading = new Gtk.Label("On this card") { xalign = 0.0f };
        card_heading.add_css_class("heading");
        content.append(card_heading);
        card_tags_box = new_flow_box();
        content.append(card_tags_box);
        card_tags_empty = new Gtk.Label("This card has no tags.") { xalign = 0.0f };
        card_tags_empty.add_css_class("dim-label");
        content.append(card_tags_empty);

        var separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        content.append(separator);
        var cloud_heading = new Gtk.Label("All project tags") { xalign = 0.0f };
        cloud_heading.add_css_class("heading");
        content.append(cloud_heading);
        cloud_box = new_flow_box();
        content.append(cloud_box);
        cloud_empty = new Gtk.Label("No tags in this project yet.") { xalign = 0.0f };
        cloud_empty.add_css_class("dim-label");
        content.append(cloud_empty);

        var scroller = new Gtk.ScrolledWindow();
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroller.set_vexpand(true);
        scroller.set_child(content);
        return scroller;
    }

    private Gtk.Widget build_results() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        root.set_margin_top(8);
        root.set_margin_bottom(8);
        root.set_margin_start(8);
        root.set_margin_end(8);

        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var back = new Gtk.Button.from_icon_name("go-previous-symbolic");
        back.set_tooltip_text("Back to tag cloud");
        back.clicked.connect(() => { show_overview(); });
        header.append(back);
        results_title = new Gtk.Label("") { xalign = 0.0f, hexpand = true };
        results_title.add_css_class("heading");
        header.append(results_title);
        root.append(header);

        results_list = new Gtk.ListBox();
        results_list.set_selection_mode(Gtk.SelectionMode.NONE);
        results_list.add_css_class("boxed-list");
        var scroller = new Gtk.ScrolledWindow();
        scroller.set_vexpand(true);
        scroller.set_child(results_list);
        root.append(scroller);
        results_empty = new Gtk.Label("No cards carry this tag.") { xalign = 0.0f };
        results_empty.add_css_class("dim-label");
        results_empty.set_visible(false);
        root.append(results_empty);
        return root;
    }

    private Gtk.FlowBox new_flow_box() {
        var box = new Gtk.FlowBox();
        box.set_orientation(Gtk.Orientation.HORIZONTAL);
        box.set_selection_mode(Gtk.SelectionMode.NONE);
        box.set_column_spacing(6);
        box.set_row_spacing(6);
        box.set_max_children_per_line(12);
        box.set_min_children_per_line(1);
        box.set_homogeneous(false);
        box.set_halign(Gtk.Align.FILL);
        box.set_valign(Gtk.Align.START);
        box.set_hexpand(true);
        return box;
    }

    private void queue_refresh() {
        refresh_serial++;
        if (tool_visible) {
            refresh.begin(refresh_serial);
        }
    }

    private async void refresh(uint serial) {
        var current_api = api;
        var project = selected_project();
        if (current_api == null || project == null) {
            all_tags.clear();
            rebuild_cloud();
            rebuild_card_tags(null);
            return;
        }
        try {
            var loaded_tags = yield current_api.list_project_tags(project.project_id);
            CardDetail? detail = null;
            var card = selected_card();
            if (card != null) {
                detail = yield current_api.get_card(card.card_id);
            }
            if (serial != refresh_serial) {
                return;
            }
            all_tags = loaded_tags;
            all_tags.sort((a, b) => { return strcmp(a.tag, b.tag); });
            rebuild_cloud();
            rebuild_card_tags(detail);
            if (pending_tag != null) {
                var selected = (!) pending_tag;
                pending_tag = null;
                yield show_tag_results(selected);
            }
        } catch (Error e) {
            if (serial == refresh_serial) {
                error_reported("Could not load tags", e.message);
            }
        }
    }

    private void rebuild_card_tags(CardDetail? detail) {
        clear_flow_box(card_tags_box);
        var has_tags = detail != null && detail.tags.length > 0;
        card_tags_empty.set_visible(!has_tags);
        if (!has_tags) {
            return;
        }
        foreach (var tag in detail.tags) {
            card_tags_box.append(build_tag_button(tag, -1, ""));
        }
    }

    private void rebuild_cloud() {
        if (cloud_box == null) {
            return;
        }
        clear_flow_box(cloud_box);
        var filter = search_entry != null ? search_entry.get_text().strip().down() : "";
        var max_count = 0;
        foreach (var entry in all_tags) {
            max_count = int.max(max_count, entry.card_count);
        }
        var shown = 0;
        foreach (var entry in all_tags) {
            if (filter.length > 0 && !entry.tag.down().contains(filter)) {
                continue;
            }
            var css_class = "";
            if (max_count > 1 && entry.card_count * 3 >= max_count * 2) {
                css_class = "title-4";
            } else if (max_count > 1 && entry.card_count * 3 >= max_count) {
                css_class = "heading";
            }
            cloud_box.append(build_tag_button(entry.tag, entry.card_count, css_class));
            shown++;
        }
        cloud_empty.set_text(filter.length > 0 && shown == 0
            ? "No tags match this filter."
            : "No tags in this project yet.");
        cloud_empty.set_visible(shown == 0);
    }

    private Gtk.Widget build_tag_button(string tag, int count, string css_class) {
        var label_text = count >= 0 ? "#%s  %d".printf(tag, count) : "#%s".printf(tag);
        var label = new Gtk.Label(label_text);
        if (css_class.length > 0) {
            label.add_css_class(css_class);
        }
        var button = new Gtk.Button();
        button.set_child(label);
        button.add_css_class("pill");
        button.set_tooltip_text(count >= 0
            ? "%d %s tagged #%s".printf(count, count == 1 ? "card" : "cards", tag)
            : "Show cards tagged #%s".printf(tag));
        var selected_tag = tag;
        button.clicked.connect(() => { show_tag(selected_tag); });
        return button;
    }

    private async void show_tag_results(string tag) {
        var current_api = api;
        var project = selected_project();
        if (current_api == null || project == null) {
            pending_tag = tag;
            return;
        }
        content_stack.set_visible_child_name("results");
        results_title.set_text("Cards tagged #%s".printf(tag));
        clear_list_box(results_list);
        results_empty.set_visible(false);
        try {
            var cards = yield current_api.list_cards_with_tag(project.project_id, tag);
            foreach (var card in cards) {
                var row_button = new Gtk.Button();
                row_button.add_css_class("flat");
                var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
                var title = new Gtk.Label(card.title) { xalign = 0.0f };
                title.set_ellipsize(Pango.EllipsizeMode.END);
                row.append(title);
                var updated = new Gtk.Label(format_updated_at(card.updated_at)) { xalign = 0.0f };
                updated.add_css_class("caption");
                updated.add_css_class("dim-label");
                row.append(updated);
                row_button.set_child(row);
                var card_id = card.card_id;
                row_button.clicked.connect(() => { card_open_requested(card_id); });
                results_list.append(row_button);
            }
            results_empty.set_visible(cards.size == 0);
        } catch (Error e) {
            error_reported("Could not load tagged cards", e.message);
        }
    }

    private void show_overview() {
        pending_tag = null;
        content_stack.set_visible_child_name("overview");
    }

    private Project? selected_project() {
        return project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
    }

    private CardSummary? selected_card() {
        return card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
    }

    private static void clear_flow_box(Gtk.FlowBox box) {
        Gtk.Widget? child = box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            box.remove(child);
            child = next;
        }
    }

    private static void clear_list_box(Gtk.ListBox box) {
        Gtk.Widget? child = box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            box.remove(child);
            child = next;
        }
    }

    private static string format_updated_at(int64 timestamp) {
        if (timestamp <= 0) {
            return "";
        }
        var updated = new DateTime.from_unix_local(timestamp);
        return "Updated %s".printf(updated.format("%x %R"));
    }
}

}
