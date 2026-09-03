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
    private uint refresh_serial = 0;
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
        var project_id = selected_project != null ? selected_project.project_id : null;
        var project_label = selected_project != null ? selected_project.name : "(none)";
        var card_id = selected_card != null ? selected_card.card_id : null;
        var card_label = selected_card != null ? selected_card.title : "Overview";
        var mode = selected_card != null ? ToolScopeMode.CARD_FOCUS : ToolScopeMode.PROJECT_ROOT;
        if (project_id == null) {
            mode = ToolScopeMode.PROJECTS_ROOT;
            project_label = "Projects";
            card_id = null;
            card_label = "Overview";
        }
        return new ToolScopeSnapshot(
            tool_id, tool_label, project_id, project_label, card_id, card_label, mode, false
        );
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
            var now = new DateTime.now_local();
            CalendarCompat.set_date(calendar, now);
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
            show_add_form();
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
        empty_label = new Gtk.Label("Select a project to see its calendar.") {
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
        add_button.set_sensitive(
            api is IMilestoneApi &&
            selected_project() != null &&
            card_store != null &&
            ((!) card_store).get_n_items() > 0
        );
    }

    private Project? selected_project() {
        return project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
    }

    private void queue_refresh() {
        refresh_add_button_state();
        if (!tool_visible) return;
        var serial = ++refresh_serial;
        refresh_calendar.begin(serial);
    }

    private async void refresh_calendar(uint serial) {
        var milestone_api = api as IMilestoneApi;
        var project = selected_project();
        if (milestone_api == null || project == null) {
            calendar_data = null;
            calendar.clear_marks();
            render_message(project == null
                ? "Select a project to see its calendar."
                : "Calendar service is unavailable.");
            return;
        }

        int64 from_epoch;
        int64 to_epoch;
        if (upcoming_button.get_active()) {
            var now = new DateTime.now_local();
            var start = local_day_start(now);
            from_epoch = start.to_unix();
            to_epoch = start.add_years(5).to_unix() - 1;
            render_message("Loading upcoming milestones…");
        } else {
            var shown = calendar.get_date();
            var start = new DateTime.local(shown.get_year(), shown.get_month(), 1, 0, 0, 0.0);
            from_epoch = start.to_unix();
            to_epoch = start.add_months(1).to_unix() - 1;
            render_message("Loading calendar…");
        }

        try {
            var result = yield milestone_api.get_project_calendar(
                project.project_id, from_epoch, to_epoch
            );
            if (serial != refresh_serial) return;
            calendar_data = result;
            update_calendar_marks();
            if (upcoming_button.get_active()) render_upcoming();
            else render_selected_day();
        } catch (Error e) {
            if (serial != refresh_serial) return;
            calendar_data = null;
            calendar.clear_marks();
            render_message("Failed to load this project’s calendar.");
            error_reported("Calendar refresh failed", e.message);
        }
    }

    private void update_calendar_marks() {
        calendar.clear_marks();
        var data = calendar_data;
        if (data == null) return;
        var visible = calendar.get_date();
        foreach (var milestone in data.milestones) {
            mark_epoch_if_visible(milestone.start_at, visible);
        }
        foreach (var item in data.created_cards) {
            mark_epoch_if_visible(item.created_at, visible);
        }
        foreach (var item in data.updated_cards) {
            mark_epoch_if_visible(item.updated_at, visible);
        }
    }

    private void mark_epoch_if_visible(int64 epoch, DateTime visible) {
        var date = new DateTime.from_unix_local(epoch);
        if (date.get_year() == visible.get_year() && date.get_month() == visible.get_month()) {
            calendar.mark_day((uint) date.get_day_of_month());
        }
    }

    private void render_selected_day() {
        clear_details();
        var selected = calendar.get_date();
        var title = new Gtk.Label(selected.format("%A, %e %B %Y")) { xalign = 0.0f };
        title.add_css_class("title-3");
        details_box.append(title);

        var data = calendar_data;
        if (data == null) {
            append_empty("No calendar data loaded.");
            return;
        }

        var day_milestones = new Gee.ArrayList<Milestone>();
        var created = new Gee.ArrayList<CalendarCardActivity>();
        var updated = new Gee.ArrayList<CalendarCardActivity>();
        foreach (var item in data.milestones) {
            if (same_local_day(item.start_at, selected)) day_milestones.add(item);
        }
        foreach (var item in data.created_cards) {
            if (same_local_day(item.created_at, selected)) created.add(item);
        }
        foreach (var item in data.updated_cards) {
            if (same_local_day(item.updated_at, selected)) updated.add(item);
        }

        if (day_milestones.size == 0 && created.size == 0 && updated.size == 0) {
            append_empty("Nothing recorded on this day.");
            return;
        }
        if (day_milestones.size > 0) append_milestone_section("Milestones", day_milestones, false);
        if (created.size > 0) append_activity_section("Cards created", created, true);
        if (updated.size > 0) append_activity_section("Cards updated", updated, false);
    }

    private void render_upcoming() {
        clear_details();
        var title = new Gtk.Label("Upcoming milestones") { xalign = 0.0f };
        title.add_css_class("title-3");
        details_box.append(title);
        var data = calendar_data;
        if (data == null || data.milestones.length == 0) {
            append_empty("No upcoming milestones in the next five years.");
            return;
        }
        var sorted = new Gee.ArrayList<Milestone>.wrap(data.milestones);
        sorted.sort((a, b) => {
            if (a.start_at < b.start_at) return -1;
            if (a.start_at > b.start_at) return 1;
            return strcmp(a.card_id, b.card_id);
        });
        append_milestone_section("", sorted, true);
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
            var card_title = milestone.card_title ?? "Open card";
            var main = new Gtk.Label(card_title) { xalign = 0.0f };
            main.add_css_class("heading");
            labels.append(main);
            var summary = milestone_summary(milestone, include_date);
            var sub = new Gtk.Label(summary) { xalign = 0.0f, wrap = true };
            sub.add_css_class("dim-label");
            labels.append(sub);
            open.set_child(labels);
            open.clicked.connect(() => { card_open_requested(milestone.card_id); });
            row.append(open);

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
            var time = new DateTime.from_unix_local(epoch);
            var sub = new Gtk.Label(time.format("%R")) { xalign = 0.0f };
            sub.add_css_class("dim-label");
            labels.append(sub);
            button.set_child(labels);
            button.clicked.connect(() => { card_open_requested(item.card_id); });
            details_box.append(button);
        }
    }

    private string milestone_summary(Milestone milestone, bool include_date) {
        var start = new DateTime.from_unix_local(milestone.start_at);
        string when = milestone.all_day ? "All day" : start.format("%R");
        if (include_date) when = start.format("%a, %e %b") + " · " + when;
        if (milestone.end_at != null && milestone.all_day) {
            var end = new DateTime.from_unix_local((!) milestone.end_at);
            if (!same_local_day((!) milestone.end_at, start)) {
                when += " – " + end.format("%e %b");
            }
        } else if (milestone.end_at != null) {
            var end = new DateTime.from_unix_local((!) milestone.end_at);
            when += " – " + (same_local_day((!) milestone.end_at, start)
                ? end.format("%R") : end.format("%e %b %R"));
        }
        var kind = milestone.kind != null && ((!) milestone.kind).strip().length > 0
            ? (!) milestone.kind : "Milestone";
        var result = "%s · %s".printf(kind, when);
        if (milestone.description != null && ((!) milestone.description).strip().length > 0) {
            result += "\n" + (!) milestone.description;
        }
        return result;
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

    private bool same_local_day(int64 epoch, DateTime date) {
        var value = new DateTime.from_unix_local(epoch);
        return value.get_year() == date.get_year() &&
            value.get_month() == date.get_month() &&
            value.get_day_of_month() == date.get_day_of_month();
    }

    private DateTime local_day_start(DateTime value) {
        return new DateTime.local(
            value.get_year(), value.get_month(), value.get_day_of_month(), 0, 0, 0.0
        );
    }

    private void confirm_remove(Milestone milestone) {
        var root = widget.get_root() as Gtk.Window;
        if (root == null) return;
        var dialog = new Adw.AlertDialog(
            "Remove Milestone?",
            "This removes the milestone from \"%s\". The card itself is unchanged.".printf(
                milestone.card_title ?? "this card"
            )
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
        var milestone_api = api as IMilestoneApi;
        if (milestone_api == null) return;
        try {
            var removed = yield milestone_api.remove_card_milestone(
                milestone.card_id, milestone.milestone_id
            );
            toast_requested(removed ? "Milestone removed." : "Milestone was already removed.");
            queue_refresh();
        } catch (Error e) {
            error_reported("Failed to remove milestone", e.message);
        }
    }

    private void show_add_form() {
        var milestone_api = api as IMilestoneApi;
        var project = selected_project();
        if (milestone_api == null || project == null || card_store == null) {
            toast_requested("Select a project and connect to Holder first.");
            return;
        }

        var card_ids = new Gee.ArrayList<string>();
        var card_names = new Gtk.StringList(null);
        uint selected_index = 0;
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary : null;
        for (uint i = 0; i < ((!) card_store).get_n_items(); i++) {
            var card = ((!) card_store).get_item(i) as CardSummary;
            if (card == null || card.project_id != project.project_id) continue;
            if (selected_card != null && card.card_id == selected_card.card_id) {
                selected_index = (uint) card_ids.size;
            }
            card_ids.add(card.card_id);
            card_names.append(card.title);
        }
        if (card_ids.size == 0) {
            toast_requested("Create a card before adding a milestone.");
            return;
        }

        clear_details();
        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        content.set_hexpand(true);
        content.set_margin_top(8);
        var title = new Gtk.Label("Add milestone") { xalign = 0.0f };
        title.add_css_class("title-3");
        content.append(title);
        var subtitle = new Gtk.Label("Attach a date to a card in this project.") {
            xalign = 0.0f,
            wrap = true
        };
        subtitle.add_css_class("dim-label");
        content.append(subtitle);
        content.append(form_label("Card"));
        var card_dropdown = new Gtk.DropDown(card_names, null);
        card_dropdown.set_selected(selected_index);
        content.append(card_dropdown);

        var date_columns = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        var start_column = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        start_column.set_hexpand(true);
        start_column.append(form_label("Start"));
        var start_calendar = new Gtk.Calendar();
        CalendarCompat.set_date(start_calendar, calendar.get_date());
        start_column.append(start_calendar);
        date_columns.append(start_column);

        var end_column = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        end_column.set_hexpand(true);
        var include_end = new Gtk.CheckButton.with_label("Add end");
        end_column.append(include_end);
        var end_calendar = new Gtk.Calendar();
        CalendarCompat.set_date(end_calendar, calendar.get_date());
        end_calendar.set_sensitive(false);
        end_column.append(end_calendar);
        date_columns.append(end_column);
        content.append(date_columns);

        var all_day = new Gtk.Switch();
        all_day.set_active(true);
        var all_day_row = form_row("All day", all_day);
        content.append(all_day_row);

        var time_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var now = new DateTime.now_local();
        var start_hour = spin(0, 23, now.get_hour());
        var start_minute = spin(0, 59, now.get_minute());
        var end_hour = spin(0, 23, now.get_hour() + 1 > 23 ? 23 : now.get_hour() + 1);
        var end_minute = spin(0, 59, now.get_minute());
        end_hour.set_sensitive(false);
        end_minute.set_sensitive(false);
        time_box.append(form_label("Start time"));
        time_box.append(start_hour); time_box.append(new Gtk.Label(":")); time_box.append(start_minute);
        time_box.append(new Gtk.Separator(Gtk.Orientation.VERTICAL));
        time_box.append(form_label("End time"));
        time_box.append(end_hour); time_box.append(new Gtk.Label(":")); time_box.append(end_minute);
        time_box.set_sensitive(false);
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
        string[] kinds = { "Deadline", "Appointment", "Event", "Exam", "Birthday",
            "Expiry", "Renewal", "Service", "MOT" };
        foreach (var kind in kinds) {
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
        var submit = new Gtk.Button.with_label("Add milestone");
        submit.add_css_class("suggested-action");
        submit.clicked.connect(() => {
            var index = card_dropdown.get_selected();
            if (index == Gtk.INVALID_LIST_POSITION || index >= card_ids.size) return;
            var start_date = start_calendar.get_date();
            var start_at = date_with_time(
                start_date,
                all_day.get_active() ? 0 : start_hour.get_value_as_int(),
                all_day.get_active() ? 0 : start_minute.get_value_as_int()
            ).to_unix();
            int64? end_at = null;
            if (include_end.get_active()) {
                var end_date = end_calendar.get_date();
                end_at = date_with_time(
                    end_date,
                    all_day.get_active() ? 0 : end_hour.get_value_as_int(),
                    all_day.get_active() ? 0 : end_minute.get_value_as_int()
                ).to_unix();
                if ((!) end_at < start_at) {
                    toast_requested("The end must not be before the start.");
                    return;
                }
            }
            submit.set_sensitive(false);
            add_milestone.begin(
                card_ids[(int) index], start_at, end_at, all_day.get_active(),
                kind_entry.get_text(), description.get_text(),
                (obj, result) => {
                    if (!add_milestone.end(result)) submit.set_sensitive(true);
                }
            );
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
        var milestone_api = api as IMilestoneApi;
        if (milestone_api == null) return false;
        try {
            yield milestone_api.add_card_milestone(
                card_id, start_at, end_at, all_day, kind, description
            );
            toast_requested("Milestone added.");
            queue_refresh();
            return true;
        } catch (Error e) {
            error_reported("Failed to add milestone", e.message);
            return false;
        }
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

    private DateTime date_with_time(DateTime date, int hour, int minute) {
        return new DateTime.local(
            date.get_year(), date.get_month(), date.get_day_of_month(), hour, minute, 0.0
        );
    }
}

}
