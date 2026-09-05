namespace HolderLinux {

private class HistoryLaneGutter : Gtk.DrawingArea {
    private bool has_visible_child = false;
    private int visible_parent_count = 0;
    private bool is_merge = false;

    public HistoryLaneGutter() {
        set_content_width(34);
        set_content_height(36);
        set_hexpand(false);
        set_vexpand(true);
        add_css_class("history-lane-gutter");
        set_draw_func((area, cr, width, height) => {
            draw_lane(area, cr, width, height);
        });
    }

    public void set_topology(bool has_visible_child,
                             int visible_parent_count,
                             bool is_merge) {
        this.has_visible_child = has_visible_child;
        this.visible_parent_count = visible_parent_count;
        this.is_merge = is_merge;
        if (has_visible_child || visible_parent_count > 0) {
            set_tooltip_text("Known history connection");
        } else {
            set_tooltip_text("No visible history connection on this page");
        }
        queue_draw();
    }

    private void draw_lane(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        var color = area.get_style_context().get_color();
        double x = width / 2.0;
        double y = double.min(18.0, height / 2.0);
        cr.set_line_width(1.5);
        cr.set_source_rgba(color.red, color.green, color.blue, 0.58);

        if (has_visible_child) {
            cr.move_to(x, 0.0);
            cr.line_to(x, y);
            cr.stroke();
        }
        if (visible_parent_count == 1) {
            cr.move_to(x, y);
            cr.line_to(x, height);
            cr.stroke();
        } else if (visible_parent_count > 1) {
            double spread = width * 0.24;
            double bend_y = double.min(y + 9.0, height - 4.0);
            cr.move_to(x, y);
            cr.line_to(x - spread, bend_y);
            cr.line_to(x - spread, height);
            cr.move_to(x, y);
            cr.line_to(x + spread, bend_y);
            cr.line_to(x + spread, height);
            cr.stroke();
        }

        cr.set_source_rgba(color.red, color.green, color.blue, 0.92);
        if (is_merge || visible_parent_count > 1) {
            cr.move_to(x, y - 5.0);
            cr.line_to(x + 5.0, y);
            cr.line_to(x, y + 5.0);
            cr.line_to(x - 5.0, y);
            cr.close_path();
            cr.fill();
        } else {
            cr.arc(x, y, 4.0, 0.0, 2.0 * Math.PI);
            cr.fill();
        }
    }
}

private class HistoryEntryRow : Gtk.ListBoxRow {
    public CardHistoryEntry entry { get; construct; }
    public signal void save_activated(CardHistorySave save);
    private HistoryLaneGutter lane_gutter;

    public HistoryEntryRow(CardHistoryEntry entry) {
        Object(entry: entry);
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 3);
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_end(8);

        var summary = new Gtk.Label(entry.is_merge ? "Merged: " + entry.summary : entry.summary) {
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
        if (entry.saves.length > 1) {
            var saves = new Gtk.Expander("Show %d exact saves".printf(entry.saves.length));
            var saves_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            foreach (var save in entry.saves) {
                var saved_at = new DateTime.from_unix_local(save.committed_at);
                var button = new Gtk.Button.with_label(
                    "Saved %s".printf(saved_at.format("%e %b %Y, %H:%M"))
                );
                button.add_css_class("flat");
                button.set_halign(Gtk.Align.START);
                button.clicked.connect(() => { save_activated(save); });
                saves_box.append(button);
            }
            saves.set_child(saves_box);
            box.append(saves);
        }
        lane_gutter = new HistoryLaneGutter();
        var row_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        row_box.append(lane_gutter);
        row_box.append(box);
        set_child(row_box);
    }

    public void update_lane(bool has_visible_child) {
        lane_gutter.set_topology(
            has_visible_child, entry.visible_parent_oids.length, entry.is_merge
        );
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
    private Gtk.ToggleButton since_button;
    private Gtk.ToggleButton change_button;
    private Gtk.ToggleButton version_button;
    private Gtk.Label detail_title;
    private Gtk.Label detail_meta;
    private Gtk.Label git_oid_label;
    private Gtk.Label git_parents_label;
    private Gtk.Label git_author_label;
    private Gtk.Label git_authored_label;
    private Gtk.Label git_committed_label;
    private Gtk.Label git_message_label;
    private Gtk.Button copy_as_card_button;
    private Gtk.Button copy_text_button;
    private Gtk.Button copy_commit_button;
    private Gtk.TextView diff_view;
    private Gtk.TextTag diff_added_tag;
    private Gtk.TextTag diff_removed_tag;
    private string? captured_head_oid;
    private string? next_cursor;
    private uint refresh_serial = 0;
    private uint comparison_serial = 0;
    private bool tool_visible = false;
    private bool selecting_initial_row = false;
    private bool setting_comparison_mode = false;
    private CardHistoryEntry? detail_entry;

    public Gtk.Widget widget { get; private set; }
    public string tool_id { owned get { return "history"; } }
    public string tool_label { owned get { return "History"; } }

    public signal void error_reported(string title, string details);
    public signal void history_text_copied(string text);
    public signal void copy_as_card_requested(string title, string text);
    public signal void debug_log_requested(string line);

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
            if (history_row != null) {
                set_default_comparison_mode(history_row.entry);
                request_comparison(history_row.entry);
            }
        });
        var timeline_scroll = new Gtk.ScrolledWindow();
        timeline_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        timeline_scroll.set_min_content_width(280);
        timeline_scroll.set_vexpand(true);
        timeline_scroll.set_child(timeline);
        var timeline_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        timeline_box.set_vexpand(true);
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

        var comparison_modes = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        comparison_modes.add_css_class("linked");
        since_button = new Gtk.ToggleButton.with_label("Since this version");
        since_button.set_active(true);
        since_button.toggled.connect(() => {
            if (!setting_comparison_mode && since_button.get_active()) {
                request_selected_comparison();
            }
        });
        comparison_modes.append(since_button);
        change_button = new Gtk.ToggleButton.with_label("This change");
        change_button.set_group(since_button);
        change_button.toggled.connect(() => {
            if (!setting_comparison_mode && change_button.get_active()) {
                request_selected_comparison();
            }
        });
        comparison_modes.append(change_button);
        version_button = new Gtk.ToggleButton.with_label("View version");
        version_button.set_group(since_button);
        version_button.toggled.connect(() => {
            if (!setting_comparison_mode && version_button.get_active()) {
                request_selected_comparison();
            }
        });
        comparison_modes.append(version_button);
        detail.append(comparison_modes);

        detail_title = new Gtk.Label("Select a saved version") { xalign = 0.0f };
        detail_title.add_css_class("title-3");
        detail.append(detail_title);
        detail_meta = new Gtk.Label("Compare it with the current saved version.") {
            xalign = 0.0f,
            wrap = true
        };
        detail_meta.add_css_class("dim-label");
        detail.append(detail_meta);

        var copy_actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        copy_as_card_button = new Gtk.Button.with_label("Copy as card");
        copy_as_card_button.set_sensitive(false);
        copy_as_card_button.clicked.connect(copy_detail_as_card);
        copy_actions.append(copy_as_card_button);
        copy_text_button = new Gtk.Button.with_label("Copy text");
        copy_text_button.set_sensitive(false);
        copy_text_button.clicked.connect(copy_detail_text);
        copy_actions.append(copy_text_button);
        copy_commit_button = new Gtk.Button.with_label("Copy commit ID");
        copy_commit_button.set_sensitive(false);
        copy_commit_button.clicked.connect(copy_commit_id);
        copy_actions.append(copy_commit_button);
        detail.append(copy_actions);

        var git_details = new Gtk.Expander("Git details");
        var git_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        git_oid_label = git_detail_label();
        git_parents_label = git_detail_label();
        git_author_label = git_detail_label();
        git_authored_label = git_detail_label();
        git_committed_label = git_detail_label();
        git_message_label = git_detail_label();
        git_box.append(git_oid_label);
        git_box.append(git_parents_label);
        git_box.append(git_author_label);
        git_box.append(git_authored_label);
        git_box.append(git_committed_label);
        git_box.append(git_message_label);
        git_details.set_child(git_box);
        detail.append(git_details);

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

    private Gtk.Label git_detail_label() {
        return new Gtk.Label("") { xalign = 0.0f, selectable = true, wrap = true };
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
        var selected_oid = selected_detail_oid();
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
            debug_log_requested(
                "History loaded: %d entries at %s%s".printf(
                    page.entries.length,
                    short_oid(page.head_oid),
                    page.next_cursor != null ? "; older history available" : ""
                )
            );
            if (page.entries.length > 0) {
                var restored_row = find_timeline_row(selected_oid);
                var row = restored_row ?? timeline.get_row_at_index(0);
                selecting_initial_row = true;
                timeline.select_row(row);
                selecting_initial_row = false;
                var history_row = row as HistoryEntryRow;
                if (history_row != null) {
                    // Keep the user's explicit choice only when this is the same row
                    // restored by a background refresh. New selections use their
                    // context-sensitive default.
                    var restored_entry = find_timeline_entry(selected_oid);
                    var entry = restored_entry ?? history_row.entry;
                    if (restored_entry == null) set_default_comparison_mode(entry);
                    request_comparison(entry);
                }
            } else {
                detail_entry = null;
                detail_title.set_text("No saved history yet");
                detail_meta.set_text("The card has no matching commits in this project repository.");
                diff_view.get_buffer().set_text("");
            }
        } catch (Error e) {
            if (serial != refresh_serial) return;
            clear_timeline();
            content_stack.set_visible_child_name("error");
            error_reported("Failed to load card history", e.message);
            debug_log_requested("History load failed: %s".printf(e.message));
        }
    }

    private void request_comparison(CardHistoryEntry entry) {
        detail_entry = entry;
        update_git_details(entry);
        comparison_serial++;
        load_comparison.begin(entry, comparison_serial);
    }

    private void request_selected_comparison() {
        if (detail_entry != null) {
            request_comparison((!) detail_entry);
            return;
        }
        var row = timeline.get_selected_row() as HistoryEntryRow;
        if (row != null) request_comparison(row.entry);
    }

    private void set_default_comparison_mode(CardHistoryEntry entry) {
        setting_comparison_mode = true;
        if (entry.last_oid == captured_head_oid) {
            change_button.set_active(true);
        } else {
            since_button.set_active(true);
        }
        setting_comparison_mode = false;
    }

    private async void load_comparison(CardHistoryEntry entry, uint serial) {
        var history_api = api as IHistoryApi;
        var project = selected_project();
        var card = selected_card();
        if (history_api == null || project == null || card == null || captured_head_oid == null) return;
        var expected_project = project.project_id;
        var expected_card = card.card_id;
        var expected_head = (!) captured_head_oid;
        var mode = version_button.get_active()
            ? "version"
            : (change_button.get_active() ? "change" : "since");
        string? from_oid;
        string to_oid;
        if (mode == "change") {
            from_oid = entry.parent_oids.length > 0 ? entry.parent_oids[0] : null;
            to_oid = entry.last_oid;
        } else if (mode == "version") {
            // The comparison endpoint also returns its stable `to` snapshot. Using
            // the selected OID for both endpoints avoids a moving HEAD and needs no
            // separate historical-card route.
            from_oid = entry.last_oid;
            to_oid = entry.last_oid;
        } else {
            from_oid = entry.last_oid;
            to_oid = expected_head;
        }
        if (mode == "since" && entry.last_oid == expected_head) {
            detail_title.set_text("Current saved version");
            detail_meta.set_text(
                "This is the current saved version. Choose This change to see how it was made."
            );
            diff_view.get_buffer().set_text("");
            return;
        }
        detail_title.set_text("Loading saved version…");
        detail_meta.set_text(entry.summary);
        try {
            var comparison = yield history_api.compare_card_history(
                expected_project, expected_card, from_oid, to_oid,
                mode == "version" ? "since" : mode
            );
            var current_project = selected_project();
            var current_card = selected_card();
            if (serial != comparison_serial || captured_head_oid != expected_head ||
                current_project == null || current_card == null ||
                current_project.project_id != expected_project || current_card.card_id != expected_card) return;
            var when = new DateTime.from_unix_local(entry.ended_at);
            string meta;
            if (mode == "version") {
                detail_title.set_text(
                    comparison.to_version.exists ? comparison.to_version.title : "No saved card"
                );
                meta = "%s by %s · Saved version".printf(
                    when.format("%e %b %Y, %H:%M"), entry.author_name
                );
            } else {
                detail_title.set_text(entry.summary);
                meta = mode == "change"
                    ? "%s by %s · This change".printf(
                    when.format("%e %b %Y, %H:%M"), entry.author_name)
                    : "%s by %s  →  Current saved version".printf(
                    when.format("%e %b %Y, %H:%M"), entry.author_name);
            }
            if (comparison.truncated && mode != "version") meta += " · Diff shortened";
            detail_meta.set_text(meta);
            if (mode == "version") {
                render_version(comparison.to_version);
            } else {
                render_diff(comparison);
            }
            debug_log_requested(
                "History compared %s to %s (%s; %d lines%s)".printf(
                    short_oid(from_oid),
                    short_oid(to_oid),
                    mode,
                    comparison.lines.length,
                    comparison.truncated ? "; shortened" : ""
                )
            );
        } catch (Error e) {
            if (serial != comparison_serial) return;
            detail_title.set_text("Could not compare this version");
            detail_meta.set_text(e.message);
            diff_view.get_buffer().set_text("");
            debug_log_requested("History comparison failed: %s".printf(e.message));
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
            debug_log_requested(
                "History loaded %d older entries%s".printf(
                    page.entries.length,
                    page.next_cursor != null ? "; more available" : ""
                )
            );
        } catch (Error e) {
            if (serial == refresh_serial) {
                error_reported("Failed to load older card history", e.message);
                debug_log_requested("History older-page load failed: %s".printf(e.message));
            }
        } finally {
            if (serial == refresh_serial) update_load_older_button();
        }
    }

    private void append_entries(CardHistoryEntry[] entries) {
        foreach (var entry in entries) {
            var row = new HistoryEntryRow(entry);
            row.save_activated.connect((save) => { select_save(entry, save); });
            timeline.append(row);
        }
        update_timeline_lanes();
    }

    private void update_timeline_lanes() {
        var index = 0;
        while (true) {
            var row = timeline.get_row_at_index(index++);
            if (row == null) return;
            var history_row = row as HistoryEntryRow;
            if (history_row == null) continue;
            bool has_visible_child = false;
            var child_index = 0;
            while (true) {
                var child = timeline.get_row_at_index(child_index++);
                if (child == null) break;
                var child_history_row = child as HistoryEntryRow;
                if (child_history_row == null) continue;
                foreach (var parent_oid in child_history_row.entry.visible_parent_oids) {
                    if (parent_oid == history_row.entry.last_oid) {
                        has_visible_child = true;
                        break;
                    }
                }
                if (has_visible_child) break;
            }
            history_row.update_lane(has_visible_child);
        }
    }

    private void select_save(CardHistoryEntry group, CardHistorySave save) {
        var entry = entry_for_save(group, save);
        set_default_comparison_mode(entry);
        request_comparison(entry);
    }

    private CardHistoryEntry entry_for_save(CardHistoryEntry group, CardHistorySave save) {
        return new CardHistoryEntry(
            save.oid, save.oid, save.parent_oids,
            group.author_name, group.author_email,
            save.committed_at, save.committed_at,
            "updated", "Saved version", 1, false,
            { save }
        );
    }

    private string? selected_detail_oid() {
        if (detail_entry != null) return ((!) detail_entry).last_oid;
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
            if (history_row == null) continue;
            if (history_row.entry.last_oid == oid) return row;
            foreach (var save in history_row.entry.saves) {
                if (save.oid == oid) return row;
            }
        }
    }

    private CardHistoryEntry? find_timeline_entry(string? oid) {
        if (oid == null) return null;
        var index = 0;
        while (true) {
            var row = timeline.get_row_at_index(index++);
            if (row == null) return null;
            var history_row = row as HistoryEntryRow;
            if (history_row == null) continue;
            if (history_row.entry.last_oid == oid) return history_row.entry;
            foreach (var save in history_row.entry.saves) {
                if (save.oid == oid) return entry_for_save(history_row.entry, save);
            }
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
        copy_as_card_button.set_sensitive(true);
        copy_text_button.set_sensitive(true);
        if (comparison.lines.length == 0) {
            buffer.set_text("No text changes were recorded between these saved versions.");
            return;
        }
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

    private void render_version(CardHistoryVersion version) {
        var buffer = diff_view.get_buffer();
        copy_as_card_button.set_sensitive(true);
        copy_text_button.set_sensitive(true);
        if (!version.exists) {
            buffer.set_text("This event does not contain a saved card version to view.");
            return;
        }
        if (version.body.length == 0) {
            buffer.set_text("This saved version has no card text.");
            return;
        }
        buffer.set_text(version.body);
    }

    private void update_git_details(CardHistoryEntry entry) {
        copy_as_card_button.set_sensitive(false);
        copy_text_button.set_sensitive(false);
        var save = entry.saves.length > 0 ? entry.saves[entry.saves.length - 1] : null;
        if (save == null) {
            git_oid_label.set_text("");
            git_parents_label.set_text("");
            git_author_label.set_text("");
            git_authored_label.set_text("");
            git_committed_label.set_text("");
            git_message_label.set_text("");
            copy_commit_button.set_sensitive(false);
            return;
        }
        var authored = new DateTime.from_unix_local(((!) save).authored_at);
        var committed = new DateTime.from_unix_local(((!) save).committed_at);
        git_oid_label.set_text("Commit: " + ((!) save).oid);
        git_parents_label.set_text(
            "Parents: " + (((!) save).parent_oids.length > 0
                ? string.joinv(", ", ((!) save).parent_oids)
                : "None (card created)")
        );
        git_author_label.set_text(
            "Author: %s <%s>".printf(entry.author_name, entry.author_email)
        );
        git_authored_label.set_text(
            "Authored: " + authored.format("%e %b %Y, %H:%M:%S %z")
        );
        git_committed_label.set_text(
            "Committed: " + committed.format("%e %b %Y, %H:%M:%S %z")
        );
        git_message_label.set_text(
            "Message: " + (((!) save).message.length > 0 ? ((!) save).message : "(none)")
        );
        copy_commit_button.set_sensitive(true);
    }

    private void copy_detail_text() {
        var buffer = diff_view.get_buffer();
        Gtk.TextIter start;
        Gtk.TextIter end;
        buffer.get_bounds(out start, out end);
        copy_to_clipboard(buffer.get_text(start, end, false));
    }

    private void copy_detail_as_card() {
        var project = selected_project();
        var card = selected_card();
        var entry = detail_entry;
        if (project == null || card == null || entry == null) return;
        var text = detail_text();
        if (text.length == 0) return;
        var title = copied_card_title(project, card, (!) entry);
        copy_as_card_requested(title, text);
        debug_log_requested(
            "History copy as card requested from %s (%d characters)".printf(
                short_oid(((!) entry).last_oid), text.length
            )
        );
    }

    private string detail_text() {
        var buffer = diff_view.get_buffer();
        Gtk.TextIter start;
        Gtk.TextIter end;
        buffer.get_bounds(out start, out end);
        return buffer.get_text(start, end, false);
    }

    private string copied_card_title(Project project, CardSummary card, CardHistoryEntry entry) {
        var saved_at = entry.ended_at;
        var version = "unsaved";
        if (entry.saves.length > 0) {
            var save = entry.saves[entry.saves.length - 1];
            saved_at = save.committed_at;
            version = save.oid.length > 8 ? save.oid.substring(0, 8) : save.oid;
        }
        var when = new DateTime.from_unix_local(saved_at);
        return "Copy of %s from %s · %s · %s".printf(
            card.title, project.name, version, when.format("%e %b %Y, %H:%M")
        );
    }

    private void copy_commit_id() {
        if (detail_entry == null || ((!) detail_entry).saves.length == 0) return;
        copy_to_clipboard(((!) detail_entry).saves[((!) detail_entry).saves.length - 1].oid);
    }

    private void copy_to_clipboard(string text) {
        if (text.length == 0) return;
        var display = Gdk.Display.get_default();
        if (display == null) {
            error_reported("Clipboard unavailable", "No display available.");
            return;
        }
        display.get_clipboard().set_text(text);
        history_text_copied(text);
        debug_log_requested("History copied %d characters to clipboard".printf(text.length));
    }

    private string short_oid(string? oid) {
        if (oid == null || ((!) oid).length == 0) return "no parent";
        return ((!) oid).length > 8 ? ((!) oid).substring(0, 8) : (!) oid;
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
