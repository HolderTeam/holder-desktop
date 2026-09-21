namespace HolderLinux {

public class MilestonesToolView : Object, IToolShellAdapter {
    private IHolderApi? api;
    private Gtk.SingleSelection? project_selection;
    private GLib.ListStore? card_store;
    private Gtk.SingleSelection? card_selection;
    private Gtk.Calendar calendar;
    private Gtk.Box actions_bar;
    private Gtk.Box details_box;
    private Gtk.Label empty_label;
    private Gtk.ToggleButton upcoming_button;
    private Gtk.Button add_button;
    private ProjectCalendar? calendar_data;
    private MilestonesController controller = new MilestonesController(
        new SystemClock(), new TimeZone.local()
    );
    private bool tool_visible = false;

    public Gtk.Widget widget { get; private set; }
    public string tool_id { owned get { return "milestones"; } }
    public string tool_label { owned get { return "Milestones"; } }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void card_open_requested(string card_id);

    public MilestonesToolView() {
        widget = build_ui();
    }

    public Gtk.Widget get_content_widget() {
        return widget;
    }

    public Gtk.Widget? get_actions_widget() {
        return actions_bar;
    }

    public void set_api_client(IHolderApi? api) {
        this.api = api;
        queue_refresh();
    }

    public void bind_context(Gtk.SingleSelection? project_selection,
                             GLib.ListStore? card_store,
                             Gtk.SingleSelection? card_selection) {
        this.project_selection = project_selection;
        this.card_store = card_store;
        this.card_selection = card_selection;
        if (project_selection != null) {
            project_selection.notify["selected"].connect(() => {
                calendar_data = null;
                queue_refresh();
            });
        }
        if (card_store != null) {
            card_store.items_changed.connect(() => {
                refresh_add_button_state();
                queue_refresh();
            });
        }
        refresh_add_button_state();
        queue_refresh();
    }

    public void set_tool_visible(bool visible) {
        tool_visible = visible;
        if (visible) queue_refresh();
    }

    public void refresh() {
        queue_refresh();
    }

    public ToolScopeSnapshot get_scope_snapshot(Project? selected_project, CardSummary? selected_card) {
        return ToolScopePresenter.snapshot(tool_id, tool_label, selected_project, selected_card);
    }

    public async bool navigate_to_projects_root(string? selected_project_id) {
        queue_refresh();
        return true;
    }

    public async bool navigate_to_project_root(string project_id) {
        queue_refresh();
        return true;
    }

    public async bool navigate_to_card(string card_id) {
        queue_refresh();
        return true;
    }

    private Gtk.Widget build_ui() {
        actions_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        actions_bar.set_hexpand(true);

        var today = new Gtk.Button.with_label("Today");
        today.clicked.connect(() => {
            CalendarCompat.set_date(calendar, controller.now());
            upcoming_button.set_active(false);
            queue_refresh();
        });
        actions_bar.append(today);

        upcoming_button = new Gtk.ToggleButton.with_label("Upcoming");
        upcoming_button.set_tooltip_text("Show upcoming milestones in chronological order");
        upcoming_button.toggled.connect(() => {
            queue_refresh();
        });
        actions_bar.append(upcoming_button);

        var spacer = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        spacer.set_hexpand(true);
        actions_bar.append(spacer);

        add_button = new Gtk.Button.from_icon_name("list-add-symbolic");
        add_button.set_tooltip_text("Add milestone");
        add_button.clicked.connect(() => {
            show_milestone_form();
        });
        actions_bar.append(add_button);

        calendar = new Gtk.Calendar();
        calendar.set_show_day_names(true);
        calendar.set_show_heading(true);
        calendar.set_show_week_numbers(false);
        calendar.set_hexpand(true);
        calendar.set_vexpand(false);
        calendar.day_selected.connect(() => {
            if (!upcoming_button.get_active()) render_selected_day();
        });
        calendar.next_month.connect(() => { if (!upcoming_button.get_active()) queue_refresh(); });
        calendar.prev_month.connect(() => { if (!upcoming_button.get_active()) queue_refresh(); });
        calendar.next_year.connect(() => { if (!upcoming_button.get_active()) queue_refresh(); });
        calendar.prev_year.connect(() => { if (!upcoming_button.get_active()) queue_refresh(); });

        var calendar_frame = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        calendar_frame.set_margin_top(8);
        calendar_frame.set_margin_bottom(8);
        calendar_frame.set_margin_start(8);
        calendar_frame.set_margin_end(8);
        var calendar_title = new Gtk.Label("Project calendar") { xalign = 0.0f };
        calendar_title.add_css_class("heading");
        calendar_frame.append(calendar_title);
        calendar_frame.append(calendar);
        var marker_note = new Gtk.Label("Marked days contain milestones or card activity.") {
            xalign = 0.0f,
            wrap = true
        };
        marker_note.add_css_class("dim-label");
        calendar_frame.append(marker_note);

        details_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        details_box.set_margin_top(8);
        details_box.set_margin_bottom(8);
        details_box.set_margin_start(12);
        details_box.set_margin_end(8);
        empty_label = new Gtk.Label(MilestonesPresenter.SELECT_PROJECT_MESSAGE) {
            xalign = 0.0f,
            wrap = true
        };
        empty_label.add_css_class("dim-label");
        details_box.append(empty_label);

        var details_scroller = new Gtk.ScrolledWindow();
        details_scroller.set_hexpand(true);
        details_scroller.set_vexpand(true);
        details_scroller.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        details_scroller.set_child(details_box);

        var paned = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
        paned.set_resize_start_child(false);
        paned.set_shrink_start_child(false);
        paned.set_shrink_end_child(false);
        paned.set_start_child(calendar_frame);
        paned.set_end_child(details_scroller);
        paned.set_position(330);
        paned.set_wide_handle(true);
        paned.set_hexpand(true);
        paned.set_vexpand(true);
        return paned;
    }

    private void refresh_add_button_state() {
        if (add_button == null) return;
        add_button.set_sensitive(MilestonesPresenter.can_add_milestone(
            api is IMilestoneApi,
            selected_project() != null,
            card_store != null ? ((!) card_store).get_n_items() : 0
        ));
    }

    private Project? selected_project() {
        return project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
    }

    private void queue_refresh() {
        refresh_add_button_state();
        if (!tool_visible) return;
        var serial = controller.next_serial();
        refresh_calendar.begin(serial);
    }

    private async void refresh_calendar(uint serial) {
        var milestone_api = api as IMilestoneApi;
        var project = selected_project();
        if (milestone_api == null || project == null) {
            calendar_data = null;
            calendar.clear_marks();
            render_message(MilestonesPresenter.unavailable_message(project != null));
            return;
        }

        var upcoming = upcoming_button.get_active();
        var range = controller.refresh_range(upcoming, calendar.get_date());
        render_message(upcoming
            ? MilestonesPresenter.LOADING_UPCOMING_MESSAGE
            : MilestonesPresenter.LOADING_CALENDAR_MESSAGE);

        var result = yield controller.refresh_flow(milestone_api, project.project_id, range, serial);
        if (result.outcome == MilestonesRefreshOutcome.STALE) return;
        if (result.outcome == MilestonesRefreshOutcome.FAILED) {
            calendar_data = null;
            calendar.clear_marks();
            render_message(MilestonesPresenter.LOAD_FAILED_MESSAGE);
            error_reported("Calendar refresh failed", (!) result.error_message);
            return;
        }
        calendar_data = result.calendar;
        update_calendar_marks();
        if (upcoming_button.get_active()) render_upcoming();
        else render_selected_day();
    }

    private void update_calendar_marks() {
        calendar.clear_marks();
        var data = calendar_data;
        if (data == null) return;
        foreach (var day in MilestonesPresenter.visible_mark_days(
            data, calendar.get_date(), controller.time_zone
        )) {
            calendar.mark_day((uint) day);
        }
    }

    private void render_selected_day() {
        clear_details();
        var selected = calendar.get_date();
        var title = new Gtk.Label(MilestonesPresenter.selected_day_title(selected)) { xalign = 0.0f };
        title.add_css_class("title-3");
        details_box.append(title);

        var data = calendar_data;
        if (data == null) {
            append_empty(MilestonesPresenter.NO_CALENDAR_DATA_MESSAGE);
            return;
        }

        var groups = MilestonesPresenter.group_for_day(data, selected, controller.time_zone);
        if (groups.is_empty) {
            append_empty(MilestonesPresenter.NOTHING_ON_DAY_MESSAGE);
            return;
        }
        if (groups.milestones.size > 0) append_milestone_section("Milestones", groups.milestones, false);
        if (groups.created.size > 0) append_activity_section("Cards created", groups.created, true);
        if (groups.updated.size > 0) append_activity_section("Cards updated", groups.updated, false);
    }

    private void render_upcoming() {
        clear_details();
        var title = new Gtk.Label(MilestonesPresenter.UPCOMING_TITLE) { xalign = 0.0f };
        title.add_css_class("title-3");
        details_box.append(title);
        var data = calendar_data;
        if (data == null || data.milestones.length == 0) {
            append_empty(MilestonesPresenter.NO_UPCOMING_MESSAGE);
            return;
        }
        append_milestone_section("", MilestonesPresenter.sorted_upcoming(data), true);
    }

    private void append_milestone_section(string heading,
                                          Gee.ArrayList<Milestone> milestones,
                                          bool include_date) {
        if (heading.length > 0) append_section_heading(heading);
        foreach (var milestone in milestones) {
            var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            row.set_margin_top(4);
            row.set_margin_bottom(4);
            row.add_css_class("card");

            var open = new Gtk.Button();
            open.add_css_class("flat");
            open.set_hexpand(true);
            var labels = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            var main = new Gtk.Label(MilestonesPresenter.milestone_card_title(milestone)) {
                xalign = 0.0f
            };
            main.add_css_class("heading");
            labels.append(main);
            var summary = MilestonesPresenter.milestone_summary(
                milestone, include_date, controller.time_zone
            );
            var sub = new Gtk.Label(summary) { xalign = 0.0f, wrap = true };
            sub.add_css_class("dim-label");
            labels.append(sub);
            open.set_child(labels);
            open.clicked.connect(() => { card_open_requested(milestone.card_id); });
            row.append(open);

            var edit = new Gtk.Button.from_icon_name("document-edit-symbolic");
            edit.add_css_class("flat");
            edit.set_tooltip_text("Edit milestone");
            edit.clicked.connect(() => { show_milestone_form(milestone); });
            row.append(edit);

            var remove = new Gtk.Button.from_icon_name("user-trash-symbolic");
            remove.add_css_class("flat");
            remove.set_tooltip_text("Remove milestone");
            remove.clicked.connect(() => { confirm_remove(milestone); });
            row.append(remove);
            details_box.append(row);
        }
    }

    private void append_activity_section(string heading,
                                         Gee.ArrayList<CalendarCardActivity> items,
                                         bool use_created_at) {
        append_section_heading(heading);
        foreach (var item in items) {
            var button = new Gtk.Button();
            button.add_css_class("flat");
            button.set_hexpand(true);
            var labels = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            var title = new Gtk.Label(item.title) { xalign = 0.0f };
            title.add_css_class("heading");
            labels.append(title);
            var epoch = use_created_at ? item.created_at : item.updated_at;
            var sub = new Gtk.Label(
                MilestonesPresenter.activity_time_text(epoch, controller.time_zone)
            ) { xalign = 0.0f };
            sub.add_css_class("dim-label");
            labels.append(sub);
            button.set_child(labels);
            button.clicked.connect(() => { card_open_requested(item.card_id); });
            details_box.append(button);
        }
    }

    private void append_section_heading(string text) {
        var label = new Gtk.Label(text) { xalign = 0.0f };
        label.add_css_class("heading");
        label.set_margin_top(6);
        details_box.append(label);
    }

    private void append_empty(string text) {
        var label = new Gtk.Label(text) { xalign = 0.0f, wrap = true };
        label.add_css_class("dim-label");
        details_box.append(label);
    }

    private void render_message(string text) {
        clear_details();
        empty_label = new Gtk.Label(text) { xalign = 0.0f, wrap = true };
        empty_label.add_css_class("dim-label");
        details_box.append(empty_label);
    }

    private void clear_details() {
        var child = details_box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            details_box.remove(child);
            child = next;
        }
    }

    private void confirm_remove(Milestone milestone) {
        var root = widget.get_root() as Gtk.Window;
        if (root == null) return;
        var dialog = new Adw.AlertDialog(
            "Remove Milestone?",
            MilestonesPresenter.remove_dialog_body(milestone)
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("remove", "Remove");
        dialog.set_response_appearance("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("remove");
        dialog.set_close_response("cancel");
        dialog.response.connect((response) => {
            if (response == "remove") remove_milestone.begin(milestone);
        });
        dialog.present(root);
    }

    private async void remove_milestone(Milestone milestone) {
        apply_mutation(yield controller.remove_flow(api as IMilestoneApi, milestone));
    }

    private bool apply_mutation(MilestoneMutationResult result) {
        if (result.toast_message != null) toast_requested((!) result.toast_message);
        if (result.error_title != null) {
            error_reported((!) result.error_title, (!) result.error_details);
        }
        if (result.needs_refresh) queue_refresh();
        return result.succeeded;
    }

    private void show_milestone_form(Milestone? editing = null) {
        var milestone_api = api as IMilestoneApi;
        var project = selected_project();
        var precondition_error = MilestoneDraft.form_precondition_error(
            milestone_api != null, project != null, card_store != null, editing != null
        );
        if (precondition_error != null) {
            toast_requested((!) precondition_error);
            return;
        }

        var card_ids = new Gee.ArrayList<string>();
        var card_names = new Gtk.StringList(null);
        uint selected_index = 0;
        if (editing == null) {
            var selected_card = card_selection != null
                ? card_selection.get_selected_item() as CardSummary : null;
            var options = MilestoneDraft.card_options(
                snapshot_cards(),
                ((!) project).project_id,
                selected_card != null ? ((!) selected_card).card_id : null
            );
            card_ids = options.card_ids;
            selected_index = options.selected_index;
            foreach (var name in options.card_names) {
                card_names.append(name);
            }
            if (card_ids.size == 0) {
                toast_requested(MilestoneDraft.NO_CARDS_MESSAGE);
                return;
            }
        }

        clear_details();
        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        content.set_hexpand(true);
        content.set_margin_top(8);
        var title = new Gtk.Label(MilestoneDraft.form_title(editing != null)) {
            xalign = 0.0f
        };
        title.add_css_class("title-3");
        content.append(title);
        var subtitle = new Gtk.Label(MilestoneDraft.form_subtitle(editing != null)) {
            xalign = 0.0f,
            wrap = true
        };
        subtitle.add_css_class("dim-label");
        content.append(subtitle);
        content.append(form_label("Card"));
        Gtk.DropDown? card_dropdown = null;
        if (editing == null) {
            card_dropdown = new Gtk.DropDown(card_names, null);
            ((!) card_dropdown).set_selected(selected_index);
            content.append((!) card_dropdown);
        } else {
            var card_label = new Gtk.Label(MilestoneDraft.card_label((!) editing)) {
                xalign = 0.0f
            };
            content.append(card_label);
        }

        var defaults = controller.form_defaults(editing, calendar.get_date());

        var date_columns = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        var start_column = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        start_column.set_hexpand(true);
        start_column.append(form_label("Start"));
        var start_calendar = new Gtk.Calendar();
        CalendarCompat.set_date(start_calendar, defaults.start);
        start_column.append(start_calendar);
        date_columns.append(start_column);

        var end_column = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        end_column.set_hexpand(true);
        var include_end = new Gtk.CheckButton.with_label("Add end");
        include_end.set_active(defaults.include_end);
        end_column.append(include_end);
        var end_calendar = new Gtk.Calendar();
        CalendarCompat.set_date(end_calendar, defaults.end);
        end_calendar.set_sensitive(include_end.get_active());
        end_column.append(end_calendar);
        date_columns.append(end_column);
        content.append(date_columns);

        var all_day = new Gtk.Switch();
        all_day.set_active(defaults.all_day);
        var all_day_row = form_row("All day", all_day);
        content.append(all_day_row);

        var time_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var start_hour = spin(0, 23, defaults.start_hour);
        var start_minute = spin(0, 59, defaults.start_minute);
        var end_hour = spin(0, 23, defaults.end_hour);
        var end_minute = spin(0, 59, defaults.end_minute);
        end_hour.set_sensitive(include_end.get_active());
        end_minute.set_sensitive(include_end.get_active());
        time_box.append(form_label("Start time"));
        time_box.append(start_hour); time_box.append(new Gtk.Label(":")); time_box.append(start_minute);
        time_box.append(new Gtk.Separator(Gtk.Orientation.VERTICAL));
        time_box.append(form_label("End time"));
        time_box.append(end_hour); time_box.append(new Gtk.Label(":")); time_box.append(end_minute);
        time_box.set_sensitive(!all_day.get_active());
        content.append(time_box);
        all_day.notify["active"].connect(() => { time_box.set_sensitive(!all_day.get_active()); });
        include_end.toggled.connect(() => {
            end_calendar.set_sensitive(include_end.get_active());
            end_hour.set_sensitive(include_end.get_active());
            end_minute.set_sensitive(include_end.get_active());
        });

        content.append(form_label("Kind"));
        var kind_box = new Gtk.FlowBox();
        kind_box.set_selection_mode(Gtk.SelectionMode.NONE);
        kind_box.set_max_children_per_line(5);
        kind_box.set_row_spacing(4);
        kind_box.set_column_spacing(4);
        var kind_entry = new Gtk.Entry();
        kind_entry.set_placeholder_text("Kind (optional)");
        kind_entry.set_text(defaults.kind);
        foreach (var kind in MilestoneDraft.kind_presets()) {
            var button = new Gtk.Button.with_label(kind);
            button.add_css_class("pill");
            button.clicked.connect(() => { kind_entry.set_text(kind); });
            kind_box.insert(button, -1);
        }
        content.append(kind_box);
        content.append(kind_entry);

        content.append(form_label("Description"));
        var description = new Gtk.Entry();
        description.set_placeholder_text("Description (optional)");
        description.set_text(defaults.description);
        content.append(description);

        var form_actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        form_actions.set_margin_top(8);
        var form_spacer = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        form_spacer.set_hexpand(true);
        form_actions.append(form_spacer);
        var cancel = new Gtk.Button.with_label("Cancel");
        cancel.clicked.connect(() => {
            if (upcoming_button.get_active()) render_upcoming();
            else render_selected_day();
        });
        form_actions.append(cancel);
        var submit = new Gtk.Button.with_label(MilestoneDraft.submit_label(editing != null));
        submit.add_css_class("suggested-action");
        submit.clicked.connect(() => {
            var card_id = MilestoneDraft.resolve_card_id(
                card_ids,
                card_dropdown != null ? ((!) card_dropdown).get_selected() : 0,
                editing
            );
            if (card_id == null) return;
            var draft = MilestoneDraft.build(
                start_calendar.get_date(),
                start_hour.get_value_as_int(),
                start_minute.get_value_as_int(),
                include_end.get_active(),
                end_calendar.get_date(),
                end_hour.get_value_as_int(),
                end_minute.get_value_as_int(),
                all_day.get_active(),
                kind_entry.get_text(),
                description.get_text(),
                controller.time_zone
            );
            if (draft.error_message != null) {
                toast_requested((!) draft.error_message);
                return;
            }
            submit.set_sensitive(false);
            if (editing == null) {
                add_milestone.begin(
                    (!) card_id, draft.start_at, draft.end_at, draft.all_day,
                    draft.kind, draft.description,
                    (obj, result) => {
                        if (!add_milestone.end(result)) submit.set_sensitive(true);
                    }
                );
            } else {
                update_milestone.begin(
                    (!) editing, draft.start_at, draft.end_at, draft.all_day,
                    draft.kind, draft.description,
                    (obj, result) => {
                        if (!update_milestone.end(result)) submit.set_sensitive(true);
                    }
                );
            }
        });
        form_actions.append(submit);
        content.append(form_actions);
        var form_clamp = new Adw.Clamp();
        form_clamp.set_maximum_size(960);
        form_clamp.set_tightening_threshold(700);
        form_clamp.set_child(content);
        details_box.append(form_clamp);
    }

    private async bool add_milestone(string card_id,
                                     int64 start_at,
                                     int64? end_at,
                                     bool all_day,
                                     string? kind,
                                     string? description) {
        return apply_mutation(yield controller.add_flow(
            api as IMilestoneApi, card_id, start_at, end_at, all_day, kind, description
        ));
    }

    private async bool update_milestone(Milestone milestone,
                                        int64 start_at,
                                        int64? end_at,
                                        bool all_day,
                                        string? kind,
                                        string? description) {
        return apply_mutation(yield controller.update_flow(
            api as IMilestoneApi, milestone, start_at, end_at, all_day, kind, description
        ));
    }

    private Gee.ArrayList<CardSummary> snapshot_cards() {
        var cards = new Gee.ArrayList<CardSummary>();
        if (card_store == null) return cards;
        for (uint i = 0; i < ((!) card_store).get_n_items(); i++) {
            var card = ((!) card_store).get_item(i) as CardSummary;
            if (card != null) cards.add((!) card);
        }
        return cards;
    }

    private Gtk.Label form_label(string text) {
        var label = new Gtk.Label(text) { xalign = 0.0f };
        label.add_css_class("heading");
        return label;
    }

    private Gtk.Box form_row(string title, Gtk.Widget control) {
        var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var label = new Gtk.Label(title) { xalign = 0.0f, hexpand = true };
        row.append(label);
        row.append(control);
        return row;
    }

    private Gtk.SpinButton spin(double min, double max, double value) {
        var result = new Gtk.SpinButton.with_range(min, max, 1);
        result.set_value(value);
        result.set_numeric(true);
        return result;
    }
}

}
