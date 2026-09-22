namespace HolderLinux {

internal class HistoryLaneGutter : Gtk.DrawingArea {
    private HistoryLaneLayout? layout; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private int lane_count = 1;
    private bool is_merge = false;

    public HistoryLaneGutter() {
        set_content_width(36);
        set_content_height(36);
        set_hexpand(false);
        set_vexpand(true);
        add_css_class("history-lane-gutter");
        set_draw_func((area, cr, width, height) => {
            draw_lane(area, cr, width, height);
        });
    }

    public void set_layout(HistoryLaneLayout layout, int lane_count, bool is_merge) {
        this.layout = layout;
        this.lane_count = lane_count;
        this.is_merge = is_merge;
        set_content_width(HistoryLaneGeometry.gutter_width(lane_count));
        set_tooltip_text(HistoryLaneGeometry.tooltip(layout, lane_count));
        queue_draw();
    }

    private void draw_lane(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        if (layout == null) return;
        var lane_layout = (!) layout;
        var color = area.get_color();
        double x = HistoryLaneGeometry.lane_x(lane_layout.node_lane, width, lane_count);
        double y = HistoryLaneGeometry.node_y(height);
        cr.set_line_width(1.5);
        cr.set_source_rgba(color.red, color.green, color.blue, 0.58);

        foreach (var lane in lane_layout.incoming_lanes) {
            double incoming_x = HistoryLaneGeometry.lane_x(lane, width, lane_count);
            cr.move_to(incoming_x, 0.0);
            cr.line_to(incoming_x, y);
            cr.stroke();
        }

        foreach (var lane in lane_layout.outgoing_lanes) {
            if (HistoryLaneGeometry.contains_lane(lane_layout.parent_lanes, lane)) continue;
            double outgoing_x = HistoryLaneGeometry.lane_x(lane, width, lane_count);
            cr.move_to(outgoing_x, y);
            cr.line_to(outgoing_x, height);
            cr.stroke();
        }
        foreach (var lane in lane_layout.parent_lanes) {
            double parent_x = HistoryLaneGeometry.lane_x(lane, width, lane_count);
            if (lane == lane_layout.node_lane) {
                cr.move_to(x, y);
                cr.line_to(x, height);
            } else {
                double bend_y = HistoryLaneGeometry.bend_y(y, height);
                cr.move_to(x, y);
                cr.line_to(parent_x, bend_y);
                cr.line_to(parent_x, height);
            }
            cr.stroke();
        }

        cr.set_source_rgba(color.red, color.green, color.blue, 0.92);
        if (HistoryLaneGeometry.draws_merge_marker(is_merge, lane_layout)) {
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
    private HistoryLaneGutter lane_gutter; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer

    public HistoryEntryRow(CardHistoryEntry entry) {
        Object(entry: entry);
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 3);
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_end(8);

        var summary = new Gtk.Label(HistoryPresenter.entry_title(entry)) {
            xalign = 0.0f,
            wrap = true
        };
        summary.add_css_class("heading");
        box.append(summary);

        var meta = new Gtk.Label(HistoryPresenter.entry_meta(entry)) { xalign = 0.0f };
        meta.add_css_class("dim-label");
        meta.add_css_class("caption");
        box.append(meta);
        if (entry.saves.length > 1) {
            var saves = new Gtk.Expander(HistoryPresenter.saves_expander_label(entry.saves.length));
            var saves_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            foreach (var save in entry.saves) {
                var button = new Gtk.Button.with_label(HistoryPresenter.save_button_label(save));
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

    public void update_lane(HistoryLaneLayout layout, int lane_count) {
        lane_gutter.set_layout(layout, lane_count, entry.is_merge);
    }
}

private class ProjectHistoryActivityRow : Gtk.ListBoxRow {
    public ProjectHistoryActivity activity { get; construct; }
    private HistoryLaneGutter lane_gutter; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer

    public ProjectHistoryActivityRow(ProjectHistoryActivity activity, Gtk.Widget content) {
        Object(activity: activity);
        lane_gutter = new HistoryLaneGutter();
        var row_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        row_box.append(lane_gutter);
        row_box.append(content);
        set_child(row_box);
    }

    public void update_lane(HistoryLaneLayout layout, int lane_count) {
        lane_gutter.set_layout(layout, lane_count, activity.is_merge);
    }
}

private class HistorySelectionScope : Object, IHistoryScope {
    public Gtk.SingleSelection? project_selection { get; set; }
    public Gtk.SingleSelection? card_selection { get; set; }

    public Project? current_project() {
        return project_selection != null
            ? project_selection.get_selected_item() as Project : null;
    }

    public CardSummary? current_card() {
        return card_selection != null
            ? card_selection.get_selected_item() as CardSummary : null;
    }
}

public class HistoryToolView : Object, IToolShellAdapter {
    private IHolderApi? api; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private HistoryController controller = new HistoryController(); // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private HistorySelectionScope scope = new HistorySelectionScope(); // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Box actions_bar; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Stack content_stack; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.ListBox timeline; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.ListBox project_timeline; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.DropDown project_kind_filter; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.StringList project_kind_options; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Button load_older_project_button; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Button load_older_button; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.ToggleButton since_button; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.ToggleButton change_button; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.ToggleButton version_button; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label detail_title; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label detail_meta; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label git_oid_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label git_parents_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label git_author_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label git_authored_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label git_committed_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label git_message_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Button copy_as_card_button; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Button copy_text_button; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Button copy_commit_button; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Button restore_version_button; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.TextView diff_view; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.TextTag diff_added_tag; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.TextTag diff_removed_tag; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private ITextClipboard clipboard; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.SingleSelection? bound_project_selection; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.SingleSelection? bound_card_selection; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private ulong project_selection_handler_id = 0;
    private ulong card_selection_handler_id = 0;
    // The card the shown comparison belongs to, so a refresh only keeps the user's chosen row for
    // the same card and not for another card that happens to share a commit.
    private string? detail_card_id = null; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private bool tool_visible = false;
    private bool selecting_initial_row = false;
    private bool setting_comparison_mode = false;

    public Gtk.Widget widget { get; private set; }
    public string tool_id { owned get { return "history"; } }
    public string tool_label { owned get { return "History"; } }

    public signal void error_reported(string title, string details);
    public signal void history_text_copied(string text);
    public signal void copy_as_card_requested(string title, string text);
    public signal void restore_succeeded(string project_id, string card_id);
    public signal void project_history_card_open_requested(string card_id);
    public signal void project_history_resource_open_requested(string resource_id);
    public signal void project_history_ai_thread_open_requested(string thread_id);
    public signal void debug_log_requested(string line);

    // The clipboard defaults to the display's; tests pass a fake so they need no display.
    public HistoryToolView(ITextClipboard? clipboard = null) {
        this.clipboard = clipboard ?? new GtkTextClipboard();
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
        if (bound_project_selection != null && project_selection_handler_id != 0) {
            ((!) bound_project_selection).disconnect(project_selection_handler_id);
        }
        if (bound_card_selection != null && card_selection_handler_id != 0) {
            ((!) bound_card_selection).disconnect(card_selection_handler_id);
        }
        bound_project_selection = project_selection;
        bound_card_selection = card_selection;
        scope.project_selection = project_selection;
        scope.card_selection = card_selection;
        project_selection_handler_id = project_selection.notify["selected-item"].connect(() => { queue_refresh(); });
        card_selection_handler_id = card_selection.notify["selected-item"].connect(() => { queue_refresh(); });
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
        content_stack.add_named(build_project_history(), "project");
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
        restore_version_button = new Gtk.Button.with_label("Restore this version");
        restore_version_button.set_sensitive(false);
        restore_version_button.add_css_class("suggested-action");
        restore_version_button.clicked.connect(confirm_restore_selected_version);
        copy_actions.append(restore_version_button);
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

    private Gtk.Widget build_project_history() {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        page.set_margin_top(8);
        page.set_margin_start(8);
        page.set_margin_end(8);
        var filter_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        filter_row.append(new Gtk.Label("Show:") { xalign = 0.0f });
        project_kind_options = new Gtk.StringList(null);
        string[] filter_labels = { "All activity", "Cards", "Resources", "Locations", "AI data",
                                   "Project settings", "Other Git changes" };
        foreach (var label in filter_labels) {
            project_kind_options.append(label);
        }
        project_kind_filter = new Gtk.DropDown(project_kind_options, null);
        project_kind_filter.set_tooltip_text("Filter project history by affected object kind");
        project_kind_filter.notify["selected"].connect(() => {
            var project = selected_project();
            var card = selected_card();
            if (tool_visible && project != null && (card == null || card.project_id != project.project_id)) {
                queue_refresh();
            }
        });
        filter_row.append(project_kind_filter);
        page.append(filter_row);
        project_timeline = new Gtk.ListBox();
        project_timeline.set_selection_mode(Gtk.SelectionMode.NONE);
        project_timeline.add_css_class("boxed-list");
        var scroll = new Gtk.ScrolledWindow();
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.set_vexpand(true);
        scroll.set_child(project_timeline);
        page.append(scroll);
        load_older_project_button = new Gtk.Button.with_label("Load older activity");
        load_older_project_button.set_visible(false);
        load_older_project_button.clicked.connect(() => { load_older_project.begin(); });
        page.append(load_older_project_button);
        return page;
    }

    private string? selected_project_kind() {
        return HistoryPresenter.project_kind_for_index(project_kind_filter.get_selected());
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
        return scope.current_project();
    }

    private CardSummary? selected_card() {
        return scope.current_card();
    }

    private void apply_detail(HistoryDetailText detail) {
        detail_title.set_text(detail.title);
        detail_meta.set_text(detail.meta);
    }

    private void queue_refresh() {
        var serial = controller.begin_refresh();
        if (!tool_visible) return;
        refresh_async.begin(serial);
    }

    private async void refresh_async(uint serial) {
        var history_api = api as IHistoryApi;
        var project_history_api = api as IProjectHistoryApi;
        var project = selected_project();
        var card = selected_card();
        switch (HistoryController.plan_refresh(
            project, card, history_api != null, project_history_api != null
        )) {
            case HistoryRefreshPlan.NO_PROJECT:
            case HistoryRefreshPlan.CARD_UNAVAILABLE:
                clear_timeline();
                content_stack.set_visible_child_name("empty");
                return;
            case HistoryRefreshPlan.PROJECT_UNAVAILABLE:
                clear_project_timeline();
                content_stack.set_visible_child_name("empty");
                return;
            case HistoryRefreshPlan.LOAD_PROJECT:
                yield refresh_project_history((!) project, (!) project_history_api, serial);
                return;
            default:
                yield refresh_card_history((!) project, (!) card, (!) history_api, serial);
                return;
        }
    }

    private async void refresh_project_history(Project project,
                                               IProjectHistoryApi history_api,
                                               uint serial) {
        content_stack.set_visible_child_name("loading");
        var load = yield controller.load_project_page(
            history_api, project.project_id, selected_project_kind(), serial
        );
        if (load.stale) return;
        if (load.error_message != null) {
            content_stack.set_visible_child_name("error");
            error_reported("Failed to load project history", (!) load.error_message);
            return;
        }
        render_project_activities(((!) load.page).activities);
        update_load_older_project_button();
        content_stack.set_visible_child_name("project");
        debug_log_requested((!) load.debug_line);
    }

    private async void refresh_card_history(Project project,
                                            CardSummary card,
                                            IHistoryApi history_api,
                                            uint serial) {
        var selected_oid = detail_card_id == card.card_id ? selected_detail_oid() : null;
        content_stack.set_visible_child_name("loading");
        var load = yield controller.load_card_page(
            history_api, project.project_id, card.card_id, serial
        );
        if (load.stale) return;
        if (load.error_message != null) {
            clear_timeline();
            content_stack.set_visible_child_name("error");
            error_reported("Failed to load card history", (!) load.error_message);
            debug_log_requested((!) load.debug_line);
            return;
        }
        var page = (!) load.page;
        clear_timeline_rows();
        append_entries(page.entries);
        update_load_older_button();
        content_stack.set_visible_child_name("history");
        debug_log_requested((!) load.debug_line);
        if (page.entries.length == 0) {
            clear_detail_state();
            apply_detail(HistoryPresenter.no_history_detail());
            return;
        }
        // Keep the user's explicit choice only when this is the same row restored by a
        // background refresh. New selections use their context-sensitive default.
        var match = HistoryPresenter.find_entry(page.entries, selected_oid);
        selecting_initial_row = true;
        timeline.select_row(timeline.get_row_at_index(match != null ? ((!) match).index : 0));
        selecting_initial_row = false;
        var entry = match != null ? ((!) match).entry : page.entries[0];
        if (match == null) set_default_comparison_mode(entry);
        request_comparison(entry);
    }

    private void request_comparison(CardHistoryEntry entry) {
        var serial = controller.begin_comparison(entry);
        var card = selected_card();
        detail_card_id = card != null ? ((!) card).card_id : null;
        restore_version_button.set_sensitive(
            HistoryPresenter.can_restore(entry, controller.captured_head_oid)
        );
        update_git_details(entry);
        load_comparison.begin(entry, serial);
    }

    private void request_selected_comparison() {
        // A shown row always has a detail entry (selecting it requests its comparison), so there is
        // nothing to compare when there is none.
        if (controller.detail_entry != null) {
            request_comparison((!) controller.detail_entry);
        }
    }

    private void set_default_comparison_mode(CardHistoryEntry entry) {
        setting_comparison_mode = true;
        if (HistoryPresenter.default_mode(entry, controller.captured_head_oid)
            == HistoryComparisonMode.CHANGE) {
            change_button.set_active(true);
        } else {
            since_button.set_active(true);
        }
        setting_comparison_mode = false;
    }

    private async void load_comparison(CardHistoryEntry entry, uint serial) {
        var history_api = api as IHistoryApi;
        var mode = HistoryPresenter.mode_for_toggles(
            version_button.get_active(), change_button.get_active()
        );
        var plan = controller.plan_comparison(scope, history_api != null, entry, mode);
        if (plan.kind == HistoryComparisonKind.SKIP) return;
        if (plan.kind == HistoryComparisonKind.CURRENT_VERSION) {
            apply_detail(HistoryPresenter.current_version_detail());
            diff_view.get_buffer().set_text("");
            return;
        }
        apply_detail(HistoryPresenter.loading_detail(entry));
        var load = yield controller.load_comparison((!) history_api, scope, entry, plan, serial);
        if (load.stale) return;
        apply_detail((!) load.detail);
        if (load.failed) {
            diff_view.get_buffer().set_text("");
        } else if (mode == HistoryComparisonMode.VERSION) {
            render_version(((!) load.comparison).to_version);
        } else {
            render_diff((!) load.comparison);
        }
        debug_log_requested((!) load.debug_line);
    }

    private async void load_older() {
        var history_api = api as IHistoryApi;
        var plan = controller.plan_load_older(scope, history_api != null);
        if (plan == null) return;
        load_older_button.set_sensitive(false);
        load_older_button.set_label(HistoryPresenter.LOADING_OLDER_LABEL);
        var result = yield controller.load_older((!) history_api, scope, (!) plan);
        if (result.outcome == HistoryOlderOutcome.APPENDED) {
            append_entries(((!) result.page).entries);
            debug_log_requested((!) result.debug_line);
        } else if (result.outcome == HistoryOlderOutcome.FAILED) {
            error_reported("Failed to load older card history", (!) result.error_message);
            debug_log_requested((!) result.debug_line);
        }
        if (result.refresh_button) update_load_older_button();
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
        HistoryEntryRow[] rows = {};
        HistoryLaneNode[] nodes = {};
        var index = 0;
        while (true) {
            var row = timeline.get_row_at_index(index++);
            if (row == null) break;
            var history_row = row as HistoryEntryRow;
            if (history_row != null) {
                rows += history_row;
                nodes += new HistoryLaneNode(
                    history_row.entry.last_oid, history_row.entry.visible_parent_oids
                );
            }
        }
        var graph = HistoryLaneAssigner.compute(nodes, HistoryLaneParentRule.AS_GIVEN);
        for (int row_index = 0; row_index < rows.length; row_index++) {
            rows[row_index].update_lane(graph.layouts[row_index], graph.lane_count);
        }
    }

    private void select_save(CardHistoryEntry group, CardHistorySave save) {
        var entry = HistoryPresenter.entry_for_save(group, save);
        set_default_comparison_mode(entry);
        request_comparison(entry);
    }

    private string? selected_detail_oid() {
        var row = timeline.get_selected_row() as HistoryEntryRow;
        return HistoryPresenter.detail_oid(controller.detail_entry, row != null ? row.entry : null);
    }

    private void update_load_older_button() {
        load_older_button.set_label(HistoryPresenter.load_older_label(controller.scan_limited));
        load_older_button.set_sensitive(controller.next_cursor != null);
        load_older_button.set_visible(controller.next_cursor != null);
    }

    private void render_diff(CardHistoryComparison comparison) {
        var buffer = diff_view.get_buffer();
        buffer.set_text("");
        copy_as_card_button.set_sensitive(true);
        copy_text_button.set_sensitive(true);
        if (comparison.lines.length == 0) {
            buffer.set_text(HistoryPresenter.DIFF_EMPTY_TEXT);
            return;
        }
        foreach (var line in comparison.lines) {
            Gtk.TextIter end;
            buffer.get_end_iter(out end);
            var rendered = HistoryPresenter.diff_line_text(line);
            switch (HistoryPresenter.diff_line_kind(line)) {
                case HistoryDiffLineKind.ADDED:
                    buffer.insert_with_tags(ref end, rendered, -1, diff_added_tag);
                    break;
                case HistoryDiffLineKind.REMOVED:
                    buffer.insert_with_tags(ref end, rendered, -1, diff_removed_tag);
                    break;
                default:
                    buffer.insert(ref end, rendered, -1);
                    break;
            }
        }
    }

    private void render_version(CardHistoryVersion version) {
        copy_as_card_button.set_sensitive(true);
        copy_text_button.set_sensitive(true);
        diff_view.get_buffer().set_text(HistoryPresenter.version_text(version));
    }

    private void update_git_details(CardHistoryEntry entry) {
        apply_git_details(HistoryPresenter.git_details(entry));
    }

    private void apply_git_details(HistoryGitDetails details) {
        copy_as_card_button.set_sensitive(false);
        copy_text_button.set_sensitive(false);
        git_oid_label.set_text(details.oid_text);
        git_parents_label.set_text(details.parents_text);
        git_author_label.set_text(details.author_text);
        git_authored_label.set_text(details.authored_text);
        git_committed_label.set_text(details.committed_text);
        git_message_label.set_text(details.message_text);
        copy_commit_button.set_sensitive(details.has_save);
    }

    private void confirm_restore_selected_version() {
        var entry = controller.detail_entry;
        var card = selected_card();
        if (card == null || !HistoryPresenter.can_restore(entry, controller.captured_head_oid)) return;
        var root_window = widget.get_root() as Gtk.Window;
        if (root_window == null) return;
        var dialog = new Adw.AlertDialog(
            "Restore this card version?",
            "Restore \"%s\" to the selected saved version? Your current saved version will remain in History and can be restored again later."
                .printf(card.title)
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("restore", "Restore version");
        dialog.set_response_appearance("restore", Adw.ResponseAppearance.SUGGESTED);
        var oid = ((!) entry).last_oid;
        var project_id = card.project_id;
        var card_id = card.card_id;
        dialog.response.connect((response) => {
            if (response != "restore") return;
            // The commit belongs to the card the dialog was opened for; if the selection has moved
            // on, restoring it would write that version into a different card.
            var current = selected_card();
            if (current == null || ((!) current).card_id != card_id
                || ((!) current).project_id != project_id) return;
            restore_selected_version.begin(oid);
        });
        dialog.present(root_window);
    }

    internal async void restore_selected_version(string oid) {
        var history_api = api as IHistoryApi;
        var plan = controller.plan_restore(scope, history_api != null, oid);
        if (plan == null) return;
        restore_version_button.set_sensitive(false);
        var result = yield controller.restore_version((!) history_api, scope, (!) plan);
        switch (result.outcome) {
            case HistoryRestoreOutcome.RESTORED:
                debug_log_requested((!) result.debug_line);
                apply_detail(HistoryPresenter.restored_detail());
                restore_succeeded(result.project_id, result.card_id);
                queue_refresh();
                break;
            case HistoryRestoreOutcome.SELECTION_CHANGED:
                break;
            default:
                error_reported("Could not restore this version", (!) result.error_message);
                debug_log_requested((!) result.debug_line);
                restore_version_button.set_sensitive(result.restore_enabled);
                break;
        }
    }

    private void copy_detail_text() {
        copy_to_clipboard(detail_text());
    }

    private void copy_detail_as_card() {
        var project = selected_project();
        var card = selected_card();
        var entry = controller.detail_entry;
        if (project == null || card == null || entry == null) return;
        var text = detail_text();
        if (text.length == 0) return;
        var title = HistoryPresenter.copied_card_title(project, card, (!) entry);
        copy_as_card_requested(title, text);
        debug_log_requested(HistoryPresenter.copy_as_card_debug(((!) entry).last_oid, text.length));
    }

    private string detail_text() {
        var buffer = diff_view.get_buffer();
        Gtk.TextIter start;
        Gtk.TextIter end;
        buffer.get_bounds(out start, out end);
        return buffer.get_text(start, end, false);
    }

    private void copy_commit_id() {
        var oid = HistoryPresenter.commit_id_to_copy(controller.detail_entry);
        if (oid == null) return;
        copy_to_clipboard((!) oid);
    }

    private void copy_to_clipboard(string text) {
        if (text.length == 0) return;
        if (!clipboard.set_text(text)) {
            error_reported("Clipboard unavailable", "No display available.");
            return;
        }
        history_text_copied(text);
        debug_log_requested(HistoryPresenter.copied_debug(text.length));
    }

    private async void load_older_project() {
        var history_api = api as IProjectHistoryApi;
        var project = selected_project();
        var cursor = controller.plan_load_older_project(history_api != null, project);
        if (cursor == null) return;
        load_older_project_button.set_sensitive(false);
        var result = yield controller.load_older_project(
            (!) history_api, ((!) project).project_id, (!) cursor, selected_project_kind()
        );
        if (result.error_message != null) {
            error_reported("Failed to load older project activity", (!) result.error_message);
        } else {
            append_project_activities(((!) result.page).activities);
        }
        update_load_older_project_button();
    }

    private void update_load_older_project_button() {
        load_older_project_button.set_visible(controller.project_next_cursor != null);
        load_older_project_button.set_sensitive(controller.project_next_cursor != null);
    }

    private void render_project_activities(ProjectHistoryActivity[] activities) {
        clear_project_rows();
        append_project_activities(activities);
    }

    private Gtk.Button project_history_link(string text) {
        var item = new Gtk.Button.with_label(text);
        item.add_css_class("flat");
        item.add_css_class("caption");
        item.set_halign(Gtk.Align.START);
        return item;
    }

    private void append_project_activities(ProjectHistoryActivity[] activities) {
        foreach (var activity in activities) {
            var presentation = ProjectHistoryPresenter.present(activity);
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 3);
            box.set_margin_top(8);
            box.set_margin_bottom(8);
            box.set_margin_start(10);
            box.set_margin_end(10);
            var title = new Gtk.Label(presentation.title) { xalign = 0.0f, wrap = true };
            title.add_css_class("heading");
            box.append(title);
            var meta = new Gtk.Label(presentation.meta) { xalign = 0.0f, wrap = true };
            meta.add_css_class("dim-label");
            meta.add_css_class("caption");
            box.append(meta);
            if (presentation.unknown_text != null) {
                var unknown = new Gtk.Label((!) presentation.unknown_text) { xalign = 0.0f };
                unknown.add_css_class("dim-label");
                unknown.add_css_class("caption");
                box.append(unknown);
            }
            if (presentation.affected_label != null) {
                var affected = new Gtk.Expander((!) presentation.affected_label);
                var affected_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
                foreach (var project_item in presentation.items) {
                    switch (project_item.item_kind) {
                        case ProjectHistoryItemKind.CARD: {
                            var card_id = (!) project_item.target_id;
                            var item = project_history_link(project_item.text);
                            item.clicked.connect(() => { project_history_card_open_requested(card_id); });
                            affected_box.append(item);
                            break;
                        }
                        case ProjectHistoryItemKind.RESOURCE: {
                            var resource_id = (!) project_item.target_id;
                            var item = project_history_link(project_item.text);
                            item.clicked.connect(() => { project_history_resource_open_requested(resource_id); });
                            affected_box.append(item);
                            break;
                        }
                        case ProjectHistoryItemKind.AI_THREAD: {
                            var thread_id = (!) project_item.target_id;
                            var item = project_history_link(project_item.text);
                            item.clicked.connect(() => { project_history_ai_thread_open_requested(thread_id); });
                            affected_box.append(item);
                            break;
                        }
                        default: {
                            var item = new Gtk.Label(project_item.text) {
                                xalign = 0.0f, selectable = true, wrap = true
                            };
                            item.add_css_class("caption");
                            if (project_item.dimmed) item.add_css_class("dim-label");
                            affected_box.append(item);
                            break;
                        }
                    }
                }
                affected.set_child(affected_box);
                box.append(affected);
            }
            var row = new ProjectHistoryActivityRow(activity, box);
            project_timeline.append(row);
        }
        if (activities.length == 0 && project_timeline.get_first_child() == null) {
            var row = new Gtk.ListBoxRow();
            row.set_child(new Gtk.Label(ProjectHistoryPresenter.EMPTY_TEXT) {
                xalign = 0.0f, margin_top = 12, margin_bottom = 12, margin_start = 12
            });
            project_timeline.append(row);
        }
        update_project_timeline_lanes();
    }

    private void update_project_timeline_lanes() {
        ProjectHistoryActivityRow[] rows = {};
        HistoryLaneNode[] nodes = {};
        var index = 0;
        while (true) {
            var row = project_timeline.get_row_at_index(index++);
            if (row == null) break;
            var activity_row = row as ProjectHistoryActivityRow;
            if (activity_row != null) {
                rows += activity_row;
                nodes += new HistoryLaneNode(activity_row.activity.oid, activity_row.activity.parent_oids);
            }
        }
        var graph = HistoryLaneAssigner.compute(nodes, HistoryLaneParentRule.LISTED_ONLY);
        for (int row_index = 0; row_index < rows.length; row_index++) {
            rows[row_index].update_lane(graph.layouts[row_index], graph.lane_count);
        }
    }

    private void clear_project_rows() {
        Gtk.Widget? child = project_timeline.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            project_timeline.remove(child);
            child = next;
        }
    }

    private void clear_project_timeline() {
        clear_project_rows();
        controller.reset_project_timeline();
        update_load_older_project_button();
    }

    private void clear_timeline_rows() {
        Gtk.Widget? child = timeline.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            timeline.remove(child);
            child = next;
        }
    }

    // Forgets the shown comparison so nothing from the previous card (git details, copy and restore
    // buttons, the diff) is left acting on it.
    private void clear_detail_state() {
        controller.detail_entry = null;
        detail_card_id = null;
        restore_version_button.set_sensitive(false);
        apply_git_details(HistoryPresenter.no_git_details());
        diff_view.get_buffer().set_text("");
    }

    private void clear_timeline() {
        clear_timeline_rows();
        controller.reset_card_timeline();
        clear_detail_state();
        update_load_older_button();
    }
}

}
