namespace HolderLinux {

private class HistoryEntryRow : Gtk.ListBoxRow {
    public CardHistoryEntry entry { get; construct; }

    public HistoryEntryRow(CardHistoryEntry entry) {
        Object(entry: entry);
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 3);
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_start(8);
        box.set_margin_end(8);

        var summary = new Gtk.Label((entry.is_merge ? "◆  " : "●  ") + entry.summary) {
            xalign = 0.0f,
            wrap = true
        };
        summary.add_css_class("heading");
        box.append(summary);

        var when = new DateTime.from_unix_local(entry.ended_at);
        var details = "%s · %s".printf(when.format("%e %b %Y, %H:%M"), entry.author_name);
        if (entry.commit_count > 1) {
            details += " · %d saves".printf(entry.commit_count);
        }
        var meta = new Gtk.Label(details) { xalign = 0.0f };
        meta.add_css_class("dim-label");
        meta.add_css_class("caption");
        box.append(meta);
        set_child(box);
    }
}

public class HistoryToolView : Object, IToolShellAdapter {
    private IHolderApi? api;
    private Gtk.SingleSelection? project_selection;
    private Gtk.SingleSelection? card_selection;
    private Gtk.Box actions_bar;
    private Gtk.Stack content_stack;
    private Gtk.ListBox timeline;
    private Gtk.Button load_older_button;
    private Gtk.Label detail_title;
    private Gtk.Label detail_meta;
    private Gtk.TextView diff_view;
    private Gtk.TextTag diff_added_tag;
    private Gtk.TextTag diff_removed_tag;
    private string? captured_head_oid;
    private string? next_cursor;
    private uint refresh_serial = 0;
    private uint comparison_serial = 0;
    private bool tool_visible = false;
    private bool selecting_initial_row = false;

    public Gtk.Widget widget { get; private set; }
    public string tool_id { owned get { return "history"; } }
    public string tool_label { owned get { return "History"; } }

    public signal void error_reported(string title, string details);

    public HistoryToolView() {
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
        if (visible) queue_refresh();
    }

    public void refresh() { queue_refresh(); }

    public ToolScopeSnapshot get_scope_snapshot(Project? selected_project,
                                                 CardSummary? selected_card) {
        var project_id = selected_project != null ? selected_project.project_id : null;
        var project_label = selected_project != null ? selected_project.name : "Projects";
        var card_id = selected_card != null ? selected_card.card_id : null;
        var card_label = selected_card != null ? selected_card.title : "Select a card";
        var mode = selected_card != null ? ToolScopeMode.CARD_FOCUS : ToolScopeMode.PROJECT_ROOT;
        if (selected_project == null) mode = ToolScopeMode.PROJECTS_ROOT;
        return new ToolScopeSnapshot(
            tool_id, tool_label, project_id, project_label, card_id, card_label, mode, false
        );
    }

    public async bool navigate_to_projects_root(string? selected_project_id) { return true; }
    public async bool navigate_to_project_root(string project_id) { return true; }
    public async bool navigate_to_card(string card_id) { return true; }

    private Gtk.Widget build_ui() {
        actions_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var refresh_button = new Gtk.Button.from_icon_name("view-refresh-symbolic");
        refresh_button.set_tooltip_text("Refresh history");
        refresh_button.clicked.connect(() => { queue_refresh(); });
        actions_bar.append(refresh_button);

        content_stack = new Gtk.Stack();
        content_stack.set_vexpand(true);
        content_stack.set_hexpand(true);
        content_stack.add_named(message_page(
            "document-open-recent-symbolic",
            "Select a card",
            "History shows how the selected card reached its current saved version."
        ), "empty");
        content_stack.add_named(message_page(
            "content-loading-symbolic", "Loading history…", "Reading saved versions from Git."
        ), "loading");
        content_stack.add_named(message_page(
            "dialog-error-symbolic",
            "History unavailable",
            "Holder could not read this card's saved history. Try refreshing it."
        ), "error");
        content_stack.add_named(build_history(), "history");
        content_stack.set_visible_child_name("empty");
        return content_stack;
    }

    private Gtk.Widget build_history() {
        var paned = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
        paned.set_position(340);
        paned.set_shrink_start_child(false);

        timeline = new Gtk.ListBox();
        timeline.set_selection_mode(Gtk.SelectionMode.SINGLE);
        timeline.add_css_class("boxed-list");
        timeline.row_selected.connect((row) => {
            if (selecting_initial_row) return;
            var history_row = row as HistoryEntryRow;
            if (history_row != null) request_comparison(history_row.entry);
        });
        var timeline_scroll = new Gtk.ScrolledWindow();
        timeline_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        timeline_scroll.set_min_content_width(280);
        timeline_scroll.set_child(timeline);
        var timeline_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        timeline_box.append(timeline_scroll);
        load_older_button = new Gtk.Button.with_label("Load older history");
        load_older_button.set_margin_start(6);
        load_older_button.set_margin_end(6);
        load_older_button.set_margin_bottom(6);
        load_older_button.set_visible(false);
        load_older_button.clicked.connect(() => { load_older.begin(); });
        timeline_box.append(load_older_button);
        paned.set_start_child(timeline_box);

        var detail = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        detail.set_margin_top(12);
        detail.set_margin_bottom(12);
        detail.set_margin_start(12);
        detail.set_margin_end(12);
        detail_title = new Gtk.Label("Select a saved version") { xalign = 0.0f };
        detail_title.add_css_class("title-3");
        detail.append(detail_title);
        detail_meta = new Gtk.Label("Compare it with the current saved version.") {
            xalign = 0.0f,
            wrap = true
        };
        detail_meta.add_css_class("dim-label");
        detail.append(detail_meta);

        diff_view = new Gtk.TextView();
        diff_view.set_editable(false);
        diff_view.set_cursor_visible(false);
        diff_view.set_monospace(true);
        diff_view.set_wrap_mode(Gtk.WrapMode.NONE);
        var diff_buffer = diff_view.get_buffer();
        diff_added_tag = diff_buffer.create_tag(
            "history-added", "foreground", "#33d17a"
        );
        diff_removed_tag = diff_buffer.create_tag(
            "history-removed", "foreground", "#f66151"
        );
        var diff_scroll = new Gtk.ScrolledWindow();
        diff_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        diff_scroll.set_vexpand(true);
        diff_scroll.set_hexpand(true);
        diff_scroll.set_child(diff_view);
        detail.append(diff_scroll);
        paned.set_end_child(detail);
        return paned;
    }

    private Gtk.Widget message_page(string icon_name, string title_text, string body_text) {
        var status = new Adw.StatusPage();
        status.set_icon_name(icon_name);
        status.set_title(title_text);
        status.set_description(body_text);
        return status;
    }

    private Project? selected_project() {
        return project_selection != null
            ? project_selection.get_selected_item() as Project : null;
    }

    private CardSummary? selected_card() {
        return card_selection != null
            ? card_selection.get_selected_item() as CardSummary : null;
    }

    private void queue_refresh() {
        refresh_serial++;
        comparison_serial++;
        if (!tool_visible) return;
        refresh_async.begin(refresh_serial);
    }

    private async void refresh_async(uint serial) {
        var history_api = api as IHistoryApi;
        var project = selected_project();
        var card = selected_card();
        if (history_api == null || project == null || card == null ||
            card.project_id != project.project_id) {
            clear_timeline();
            content_stack.set_visible_child_name("empty");
            return;
        }
        var selected_oid = selected_timeline_oid();
        content_stack.set_visible_child_name("loading");
        try {
            var page = yield history_api.list_card_history(project.project_id, card.card_id);
            if (serial != refresh_serial) return;
            clear_timeline();
            captured_head_oid = page.head_oid;
            next_cursor = page.next_cursor;
            append_entries(page.entries);
            update_load_older_button();
            content_stack.set_visible_child_name("history");
            if (page.entries.length > 0) {
                var row = find_timeline_row(selected_oid) ?? timeline.get_row_at_index(0);
                selecting_initial_row = true;
                timeline.select_row(row);
                selecting_initial_row = false;
                var history_row = row as HistoryEntryRow;
                if (history_row != null) request_comparison(history_row.entry);
            } else {
                detail_title.set_text("No saved history yet");
                detail_meta.set_text("The card has no matching commits in this project repository.");
                diff_view.get_buffer().set_text("");
            }
        } catch (Error e) {
            if (serial != refresh_serial) return;
            clear_timeline();
            content_stack.set_visible_child_name("error");
            error_reported("Failed to load card history", e.message);
        }
    }

    private void request_comparison(CardHistoryEntry entry) {
        comparison_serial++;
        load_comparison.begin(entry, comparison_serial);
    }

    private async void load_comparison(CardHistoryEntry entry, uint serial) {
        var history_api = api as IHistoryApi;
        var project = selected_project();
        var card = selected_card();
        if (history_api == null || project == null || card == null || captured_head_oid == null) return;
        var expected_project = project.project_id;
        var expected_card = card.card_id;
        var expected_head = (!) captured_head_oid;
        var from_oid = entry.last_oid;
        var showing_current_change = entry.last_oid == expected_head;
        if (showing_current_change && entry.parent_oids.length > 0) {
            from_oid = entry.parent_oids[0];
        } else if (showing_current_change) {
            detail_title.set_text("Current saved version");
            detail_meta.set_text("This is the first saved version of the card.");
            diff_view.get_buffer().set_text("");
            return;
        }
        detail_title.set_text("Loading saved version…");
        detail_meta.set_text(entry.summary);
        try {
            var comparison = yield history_api.compare_card_history(
                expected_project, expected_card, from_oid, expected_head
            );
            var current_project = selected_project();
            var current_card = selected_card();
            if (serial != comparison_serial || captured_head_oid != expected_head ||
                current_project == null || current_card == null ||
                current_project.project_id != expected_project || current_card.card_id != expected_card) return;
            detail_title.set_text(entry.summary);
            var when = new DateTime.from_unix_local(entry.ended_at);
            var meta = showing_current_change
                ? "%s by %s · Current saved change".printf(
                    when.format("%e %b %Y, %H:%M"), entry.author_name)
                : "%s by %s  →  Current saved version".printf(
                    when.format("%e %b %Y, %H:%M"), entry.author_name);
            if (comparison.truncated) meta += " · Diff shortened";
            detail_meta.set_text(meta);
            render_diff(comparison);
        } catch (Error e) {
            if (serial != comparison_serial) return;
            detail_title.set_text("Could not compare this version");
            detail_meta.set_text(e.message);
            diff_view.get_buffer().set_text("");
        }
    }

    private async void load_older() {
        var history_api = api as IHistoryApi;
        var project = selected_project();
        var card = selected_card();
        var cursor = next_cursor;
        if (history_api == null || project == null || card == null || cursor == null) return;
        var serial = refresh_serial;
        var expected_project = project.project_id;
        var expected_card = card.card_id;
        load_older_button.set_sensitive(false);
        load_older_button.set_label("Loading older history…");
        try {
            var page = yield history_api.list_card_history(
                expected_project, expected_card, 50, cursor
            );
            var current_project = selected_project();
            var current_card = selected_card();
            if (serial != refresh_serial || current_project == null || current_card == null ||
                current_project.project_id != expected_project || current_card.card_id != expected_card) {
                return;
            }
            append_entries(page.entries);
            next_cursor = page.next_cursor;
        } catch (Error e) {
            if (serial == refresh_serial) {
                error_reported("Failed to load older card history", e.message);
            }
        } finally {
            if (serial == refresh_serial) update_load_older_button();
        }
    }

    private void append_entries(CardHistoryEntry[] entries) {
        foreach (var entry in entries) timeline.append(new HistoryEntryRow(entry));
    }

    private string? selected_timeline_oid() {
        var row = timeline.get_selected_row() as HistoryEntryRow;
        return row != null ? row.entry.last_oid : null;
    }

    private Gtk.ListBoxRow? find_timeline_row(string? oid) {
        if (oid == null) return null;
        var index = 0;
        while (true) {
            var row = timeline.get_row_at_index(index++);
            if (row == null) return null;
            var history_row = row as HistoryEntryRow;
            if (history_row != null && history_row.entry.last_oid == oid) return row;
        }
    }

    private void update_load_older_button() {
        load_older_button.set_label("Load older history");
        load_older_button.set_sensitive(next_cursor != null);
        load_older_button.set_visible(next_cursor != null);
    }

    private void render_diff(CardHistoryComparison comparison) {
        var buffer = diff_view.get_buffer();
        buffer.set_text("");
        foreach (var line in comparison.lines) {
            Gtk.TextIter end;
            buffer.get_end_iter(out end);
            var rendered = "%s %s\n".printf(line.origin, line.text);
            if (line.origin == "+") {
                buffer.insert_with_tags(ref end, rendered, -1, diff_added_tag);
            } else if (line.origin == "-") {
                buffer.insert_with_tags(ref end, rendered, -1, diff_removed_tag);
            }
            else buffer.insert(ref end, rendered, -1);
        }
    }

    private void clear_timeline() {
        Gtk.Widget? child = timeline.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            timeline.remove(child);
            child = next;
        }
        captured_head_oid = null;
        next_cursor = null;
        update_load_older_button();
    }
}

}
