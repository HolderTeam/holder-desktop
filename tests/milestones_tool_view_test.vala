using GLib;

namespace HolderLinuxTests {

private Gtk.Widget? find_widget(Gtk.Widget root, Type type) {
    if (root.get_type().is_a(type)) return root;
    var child = root.get_first_child();
    while (child != null) {
        var found = find_widget(child, type);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.Label? find_label(Gtk.Widget root, string text) {
    if (root is Gtk.Label && ((Gtk.Label) root).get_text() == text) return (Gtk.Label) root;
    var child = root.get_first_child();
    while (child != null) {
        var found = find_label(child, text);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.ToggleButton? find_toggle(Gtk.Widget root, string label) {
    if (root is Gtk.ToggleButton && ((Gtk.ToggleButton) root).get_label() == label) {
        return (Gtk.ToggleButton) root;
    }
    var child = root.get_first_child();
    while (child != null) {
        var found = find_toggle(child, label);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.Button? find_button_with_tooltip(Gtk.Widget root, string tooltip) {
    if (root is Gtk.Button && root.get_tooltip_text() == tooltip) {
        return (Gtk.Button) root;
    }
    var child = root.get_first_child();
    while (child != null) {
        var found = find_button_with_tooltip(child, tooltip);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.Button? find_button_with_label(Gtk.Widget root, string label) {
    if (root is Gtk.Button && ((Gtk.Button) root).get_label() == label) {
        return (Gtk.Button) root;
    }
    var child = root.get_first_child();
    while (child != null) {
        var found = find_button_with_label(child, label);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.Entry? find_entry_with_placeholder(Gtk.Widget root, string placeholder) {
    if (root is Gtk.Entry && ((Gtk.Entry) root).get_placeholder_text() == placeholder) {
        return (Gtk.Entry) root;
    }
    var child = root.get_first_child();
    while (child != null) {
        var found = find_entry_with_placeholder(child, placeholder);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private Gtk.CheckButton? find_check_with_label(Gtk.Widget root, string label) {
    if (root is Gtk.CheckButton && ((Gtk.CheckButton) root).get_label() == label) {
        return (Gtk.CheckButton) root;
    }
    var child = root.get_first_child();
    while (child != null) {
        var found = find_check_with_label(child, label);
        if (found != null) return found;
        child = child.get_next_sibling();
    }
    return null;
}

private void test_calendar_marks_activity_and_renders_selected_day() {
    var api = new MainControllerFakeApi();
    var now = new DateTime.now_local();
    var day = new DateTime.local(
        now.get_year(), now.get_month(), now.get_day_of_month(), 12, 0, 0.0
    ).to_unix();
    var milestone_end = day + 3600;
    api.milestones.add(new HolderLinux.Milestone(
        "m1", "c1", day, milestone_end, false, "Deadline", "Submit it", 1, 1, "Homework"
    ));
    api.calendar_created_cards.add(new HolderLinux.CalendarCardActivity(
        "c2", "New note", day, day
    ));

    var projects = new GLib.ListStore(typeof(HolderLinux.Project));
    projects.append(new HolderLinux.Project("p1", "School", "plain_git", "/tmp/p1", 1, 1));
    var project_selection = new Gtk.SingleSelection(projects);
    project_selection.set_selected(0);
    var cards = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    cards.append(new HolderLinux.CardSummary("c1", "p1", "Homework", "", 0, null, 1, 1));
    var card_selection = new Gtk.SingleSelection(cards);
    card_selection.set_selected(0);

    var view = new HolderLinux.MilestonesToolView();
    string? toast_message = null;
    view.toast_requested.connect((message) => { toast_message = message; });
    view.set_api_client(api);
    view.bind_context(project_selection, cards, card_selection);
    view.set_tool_visible(true);

    assert(wait_for_condition(() => api.get_project_calendar_calls > 0));
    assert(api.last_calendar_project_id == "p1");
    var calendar = find_widget(view.widget, typeof(Gtk.Calendar)) as Gtk.Calendar;
    assert(calendar != null);
    assert(wait_for_condition(() => ((!) calendar).get_day_is_marked((uint) now.get_day_of_month())));
    assert(find_label(view.widget, "Homework") != null);
    assert(find_label(view.widget, "Cards created") != null);
    assert(find_label(view.widget, "New note") != null);

    var edit = find_button_with_tooltip(view.widget, "Edit milestone");
    assert(edit != null);
    ((!) edit).clicked();
    assert(find_label(view.widget, "Edit milestone") != null);
    var kind = find_entry_with_placeholder(view.widget, "Kind (optional)");
    var description = find_entry_with_placeholder(view.widget, "Description (optional)");
    assert(kind != null && ((!) kind).get_text() == "Deadline");
    assert(description != null && ((!) description).get_text() == "Submit it");
    var include_end = find_check_with_label(view.widget, "Add end");
    var all_day = find_widget(view.widget, typeof(Gtk.Switch)) as Gtk.Switch;
    assert(include_end != null && ((!) include_end).get_active());
    assert(all_day != null && !((!) all_day).get_active());
    ((!) include_end).set_active(false);
    ((!) kind).set_text("");
    ((!) description).set_text("");
    var save = find_button_with_label(view.widget, "Save changes");
    assert(save != null);
    ((!) save).clicked();
    assert(wait_for_condition(() => api.update_card_milestone_calls == 1));
    assert(api.last_milestone_card_id == "c1");
    assert(api.last_milestone_id == "m1");
    assert(api.last_milestone_kind == null);
    assert(api.last_milestone_description == null);
    assert(api.last_milestone_end_at == null);
    assert(api.last_milestone_start_at == day);
    assert(!api.last_milestone_all_day);
    assert(toast_message == "Milestone updated.");
    assert(wait_for_condition(() => find_label(view.widget, "Homework") != null));

    var actions = view.get_actions_widget();
    assert(actions != null);
    var add = find_button_with_tooltip((!) actions, "Add milestone");
    assert(add != null);
    ((!) add).clicked();
    assert(find_label(view.widget, "Add milestone") != null);
    assert(find_label(view.widget, "Card") != null);
    var cancel = find_button_with_label(view.widget, "Cancel");
    assert(cancel != null);
    ((!) cancel).clicked();
    assert(find_label(view.widget, "Homework") != null);

    ((!) add).clicked();
    var submit = find_button_with_label(view.widget, "Add milestone");
    assert(submit != null);
    ((!) submit).clicked();
    assert(wait_for_condition(() => api.add_card_milestone_calls == 1));

    var upcoming = find_toggle((!) actions, "Upcoming");
    assert(upcoming != null);
    var previous_calls = api.get_project_calendar_calls;
    ((!) upcoming).set_active(true);
    assert(wait_for_condition(() => api.get_project_calendar_calls > previous_calls));
    assert(find_label(view.widget, "Upcoming milestones") != null);
}

private void test_without_project_does_not_call_api() {
    var api = new MainControllerFakeApi();
    var view = new HolderLinux.MilestonesToolView();
    view.set_api_client(api);
    view.set_tool_visible(true);
    while (MainContext.default().iteration(false)) {}
    assert(api.get_project_calendar_calls == 0);
    assert(find_label(view.widget, "Select a project to see its calendar.") != null);
}

// ---- release-quality pass: shell surface, states, remove flow and bug regressions ----

private class MvsClock : Object, HolderLinux.IClock {
    public int64 epoch { get; set; default = 0; }

    public int64 now_epoch_seconds() {
        return epoch;
    }
}

// Every date below is noon UTC on 15 March 2026, in a UTC controller, so nothing depends on the
// machine's own time zone.
private DateTime mvs_noon(int day) {
    return new DateTime.utc(2026, 3, day, 12, 0, 0.0);
}

private class MvsHarness : Object {
    public MainControllerFakeApi api = new MainControllerFakeApi();
    public HolderLinux.MilestonesToolView view;
    public GLib.ListStore projects = new GLib.ListStore(typeof(HolderLinux.Project));
    public Gtk.SingleSelection project_selection;
    public GLib.ListStore cards = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    public Gtk.SingleSelection card_selection;
    public Adw.Window window = new Adw.Window();
    public Gtk.Calendar calendar;
    public Gee.ArrayList<string> toasts = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> errors = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> opened = new Gee.ArrayList<string>();

    public MvsHarness(bool with_milestone = true, bool attach_window = true) {
        var clock = new MvsClock() { epoch = mvs_noon(15).to_unix() };
        view = new HolderLinux.MilestonesToolView(clock, new TimeZone.utc());
        view.toast_requested.connect((message) => { toasts.add(message); });
        view.error_reported.connect((title, details) => { errors.add("%s|%s".printf(title, details)); });
        view.card_open_requested.connect((card_id) => { opened.add(card_id); });
        if (attach_window) window.set_content(view.widget);
        calendar = (Gtk.Calendar) find_widget(view.widget, typeof(Gtk.Calendar));
        HolderLinux.CalendarCompat.set_date(calendar, mvs_noon(15));
        projects.append(new HolderLinux.Project("p1", "School", "plain_git", "/tmp/p1", 1, 1));
        projects.append(new HolderLinux.Project("p2", "Home", "plain_git", "/tmp/p2", 1, 1));
        project_selection = new Gtk.SingleSelection(projects);
        project_selection.set_selected(0);
        cards.append(new HolderLinux.CardSummary("c1", "p1", "Homework", "", 0, null, 1, 1));
        card_selection = new Gtk.SingleSelection(cards);
        card_selection.set_selected(0);
        if (with_milestone) {
            api.milestones.add(new HolderLinux.Milestone(
                "m1", "c1", mvs_noon(15).to_unix(), mvs_noon(15).to_unix() + 3600, false,
                "Deadline", "Submit it", 1, 1, "Homework"
            ));
        }
        view.set_api_client(api);
        view.bind_context(project_selection, cards, card_selection);
        view.set_tool_visible(true);
    }

    public bool wait_for_calls(int calls) {
        return wait_for_condition(() => api.get_project_calendar_calls >= calls);
    }

    public bool has_label(string text) {
        return find_label(view.widget, text) != null;
    }

    public bool wait_for_label(string text) {
        return wait_for_condition(() => has_label(text));
    }

    // Icon buttons live either in the page or in the actions bar next to it.
    public Gtk.Button tooltip_button(string tooltip) {
        var found = find_button_with_tooltip(view.widget, tooltip);
        if (found == null) found = find_button_with_tooltip((!) view.get_actions_widget(), tooltip);
        assert(found != null);
        return (!) found;
    }

    public Adw.AlertDialog? dialog() {
        return window.get_visible_dialog() as Adw.AlertDialog;
    }
}

private void mvs_settle() {
    while (MainContext.default().iteration(false)) {}
}

private void test_mvs_shell_adapter_reports_identity_scope_and_navigation() {
    var h = new MvsHarness();
    assert(h.wait_for_calls(1));
    assert(h.view.tool_id == "milestones");
    assert(h.view.tool_label == "Milestones");
    assert(h.view.get_content_widget() == h.view.widget);
    assert(h.view.get_actions_widget() != null);

    var project = new HolderLinux.Project("p1", "School", "plain_git", "/tmp/p1", 1, 1);
    var card = new HolderLinux.CardSummary("c1", "p1", "Homework", "", 0, null, 1, 1);
    assert(h.view.get_scope_snapshot(null, null).scope_mode == HolderLinux.ToolScopeMode.PROJECTS_ROOT);
    assert(h.view.get_scope_snapshot(project, null).scope_mode == HolderLinux.ToolScopeMode.PROJECT_ROOT);
    var focused = h.view.get_scope_snapshot(project, card);
    assert(focused.scope_mode == HolderLinux.ToolScopeMode.CARD_FOCUS);
    assert(focused.tool_id == "milestones" && focused.card_id == "c1");

    // refresh() and each navigation reload the calendar once.
    mvs_settle();
    var calls = h.api.get_project_calendar_calls;
    h.view.refresh();
    assert(h.wait_for_calls(calls + 1));
    bool root_ok = false;
    bool project_ok = false;
    bool card_ok = false;
    h.view.navigate_to_projects_root.begin(null, (obj, res) => { root_ok = h.view.navigate_to_projects_root.end(res); });
    h.view.navigate_to_project_root.begin("p1", (obj, res) => { project_ok = h.view.navigate_to_project_root.end(res); });
    h.view.navigate_to_card.begin("c1", (obj, res) => { card_ok = h.view.navigate_to_card.end(res); });
    assert(wait_for_condition(() => root_ok && project_ok && card_ok));
    assert(h.wait_for_calls(calls + 4));
}

private void test_mvs_rebinding_stops_listening_to_the_old_context() {
    var h = new MvsHarness();
    assert(h.wait_for_calls(1));
    mvs_settle();

    var second_projects = new GLib.ListStore(typeof(HolderLinux.Project));
    second_projects.append(new HolderLinux.Project("p1", "School", "plain_git", "/tmp/p1", 1, 1));
    second_projects.append(new HolderLinux.Project("p2", "Home", "plain_git", "/tmp/p2", 1, 1));
    var second_selection = new Gtk.SingleSelection(second_projects);
    second_selection.set_selected(0);
    var second_cards = new GLib.ListStore(typeof(HolderLinux.CardSummary));
    second_cards.append(new HolderLinux.CardSummary("c1", "p1", "Homework", "", 0, null, 1, 1));
    var before_rebind = h.api.get_project_calendar_calls;
    h.view.bind_context(second_selection, second_cards, null);
    assert(h.wait_for_calls(before_rebind + 1));
    mvs_settle();
    var settled = h.api.get_project_calendar_calls;

    // The first context is no longer bound: neither its project selection nor its card store refresh.
    h.project_selection.set_selected(1);
    h.cards.append(new HolderLinux.CardSummary("c9", "p1", "Extra", "", 0, null, 1, 1));
    mvs_settle();
    assert(h.api.get_project_calendar_calls == settled);

    // Precondition for the assertion above: the newly bound context does refresh.
    second_selection.set_selected(1);
    assert(h.wait_for_calls(settled + 1));
    second_cards.append(new HolderLinux.CardSummary("c8", "p1", "More", "", 0, null, 1, 1));
    assert(h.wait_for_calls(settled + 2));
}

private void test_mvs_switching_project_clears_the_old_marks_and_the_day_while_loading() {
    var h = new MvsHarness();
    assert(h.wait_for_calls(1));
    assert(wait_for_condition(() => h.calendar.get_day_is_marked(15)));
    assert(h.has_label("Homework"));

    h.api.stall_next_project_calendar = true;
    h.project_selection.set_selected(1);
    assert(wait_for_condition(() => h.api.has_stalled_project_calendar()));

    // Nothing is known about the second project yet: its calendar shows no marks from the first.
    assert(!h.calendar.get_day_is_marked(15));
    assert(h.has_label(HolderLinux.MilestonesPresenter.LOADING_CALENDAR_MESSAGE));
    // Choosing a day now has no data to show either.
    HolderLinux.CalendarCompat.set_date(h.calendar, mvs_noon(16));
    assert(h.has_label(HolderLinux.MilestonesPresenter.NO_CALENDAR_DATA_MESSAGE));

    h.api.release_stalled_project_calendar();
    assert(wait_for_condition(() => h.has_label(HolderLinux.MilestonesPresenter.NOTHING_ON_DAY_MESSAGE)));
}

private void test_mvs_the_today_button_jumps_to_the_clock_date_and_leaves_upcoming() {
    var h = new MvsHarness();
    assert(h.wait_for_calls(1));
    var upcoming = find_toggle((!) h.view.get_actions_widget(), "Upcoming");
    assert(upcoming != null);
    HolderLinux.CalendarCompat.set_date(h.calendar, new DateTime.utc(2026, 1, 2, 12, 0, 0.0));
    ((!) upcoming).set_active(true);
    assert(wait_for_condition(() => h.has_label("Upcoming milestones")));
    mvs_settle();
    var calls = h.api.get_project_calendar_calls;

    var today = find_button_with_label((!) h.view.get_actions_widget(), "Today");
    assert(today != null);
    ((!) today).clicked();

    assert(h.calendar.get_date().get_year() == 2026);
    assert(h.calendar.get_date().get_month() == 3);
    assert(h.calendar.get_date().get_day_of_month() == 15);
    assert(!((!) upcoming).get_active());
    assert(h.wait_for_calls(calls + 1));
}

private void test_mvs_calendar_navigation_reloads_the_month_and_selecting_a_day_rerenders() {
    var h = new MvsHarness();
    assert(h.wait_for_calls(1));
    mvs_settle();
    var calls = h.api.get_project_calendar_calls;

    h.calendar.next_month();
    assert(h.wait_for_calls(calls + 1));
    h.calendar.prev_month();
    assert(h.wait_for_calls(calls + 2));
    h.calendar.next_year();
    assert(h.wait_for_calls(calls + 3));
    h.calendar.prev_year();
    assert(h.wait_for_calls(calls + 4));

    // Choosing a day renders that day without another load.
    mvs_settle();
    calls = h.api.get_project_calendar_calls;
    var other = mvs_noon(20);
    HolderLinux.CalendarCompat.set_date(h.calendar, other);
    assert(h.has_label(HolderLinux.MilestonesPresenter.selected_day_title(h.calendar.get_date())));
    assert(h.has_label(HolderLinux.MilestonesPresenter.NOTHING_ON_DAY_MESSAGE));
    mvs_settle();
    assert(h.api.get_project_calendar_calls == calls);

    // While "Upcoming" is showing, month navigation and day selection leave the list alone.
    var upcoming = find_toggle((!) h.view.get_actions_widget(), "Upcoming");
    assert(upcoming != null);
    ((!) upcoming).set_active(true);
    assert(wait_for_condition(() => h.has_label("Upcoming milestones")));
    mvs_settle();
    calls = h.api.get_project_calendar_calls;
    h.calendar.next_month();
    HolderLinux.CalendarCompat.set_date(h.calendar, mvs_noon(21));
    mvs_settle();
    assert(h.api.get_project_calendar_calls == calls);
    assert(h.has_label("Upcoming milestones"));
}

private void test_mvs_a_failed_refresh_clears_the_marks_and_reports_the_error() {
    var h = new MvsHarness();
    assert(h.wait_for_calls(1));
    assert(wait_for_condition(() => h.calendar.get_day_is_marked(15)));

    h.api.fail_get_project_calendar = true;
    h.view.refresh();

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Calendar refresh failed|calendar down");
    assert(h.has_label(HolderLinux.MilestonesPresenter.LOAD_FAILED_MESSAGE));
    assert(!h.calendar.get_day_is_marked(15));
}

private void test_mvs_a_day_and_an_upcoming_list_without_milestones_explain_themselves() {
    var h = new MvsHarness(false);
    assert(h.wait_for_calls(1));
    assert(h.wait_for_label(HolderLinux.MilestonesPresenter.NOTHING_ON_DAY_MESSAGE));

    var upcoming = find_toggle((!) h.view.get_actions_widget(), "Upcoming");
    assert(upcoming != null);
    ((!) upcoming).set_active(true);
    assert(h.wait_for_label(HolderLinux.MilestonesPresenter.NO_UPCOMING_MESSAGE));
}

private Adw.AlertDialog mvs_open_remove_dialog(MvsHarness h) {
    assert(wait_for_condition(() => find_button_with_tooltip(h.view.widget, "Remove milestone") != null));
    h.tooltip_button("Remove milestone").clicked();
    assert(wait_for_condition(() => h.dialog() != null));
    var dialog = h.dialog();
    assert(dialog != null && ((!) dialog).get_heading() == "Remove Milestone?");
    return (!) dialog;
}

private void test_mvs_cancelling_the_remove_dialog_keeps_the_milestone() {
    var h = new MvsHarness();
    var dialog = mvs_open_remove_dialog(h);

    dialog.response("cancel");
    mvs_settle();

    assert(h.api.remove_card_milestone_calls == 0);
    assert(h.toasts.size == 0 && h.errors.size == 0);
}

private void test_mvs_confirming_the_remove_dialog_removes_the_milestone_and_reloads() {
    var h = new MvsHarness();
    var dialog = mvs_open_remove_dialog(h);
    assert(h.wait_for_calls(1));
    mvs_settle();
    var calls = h.api.get_project_calendar_calls;

    dialog.response("remove");

    assert(wait_for_condition(() => h.api.remove_card_milestone_calls == 1));
    assert(wait_for_condition(() => h.toasts.size == 1));
    assert(h.toasts[0] == "Milestone removed.");
    assert(h.wait_for_calls(calls + 1));
    assert(wait_for_condition(() => h.has_label(HolderLinux.MilestonesPresenter.NOTHING_ON_DAY_MESSAGE)));
}

private void test_mvs_a_failed_remove_is_reported_and_does_not_reload() {
    var h = new MvsHarness();
    var dialog = mvs_open_remove_dialog(h);
    assert(h.wait_for_calls(1));
    mvs_settle();
    var calls = h.api.get_project_calendar_calls;
    h.api.fail_remove_card_milestone = true;

    dialog.response("remove");

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Failed to remove milestone|remove down");
    mvs_settle();
    assert(h.api.get_project_calendar_calls == calls);
    assert(h.has_label("Homework"));
}

private void test_mvs_removing_without_a_window_does_nothing() {
    var h = new MvsHarness(true, false);
    assert(wait_for_condition(() => find_button_with_tooltip(h.view.widget, "Remove milestone") != null));

    h.tooltip_button("Remove milestone").clicked();
    mvs_settle();

    assert(h.dialog() == null);
    assert(h.api.remove_card_milestone_calls == 0);
}

private void mvs_collect_calendars(Gtk.Widget root, Gee.ArrayList<Gtk.Calendar> found) {
    if (root is Gtk.Calendar) found.add((Gtk.Calendar) root);
    var child = root.get_first_child();
    while (child != null) {
        mvs_collect_calendars(child, found);
        child = child.get_next_sibling();
    }
}

private void test_mvs_adding_without_an_api_asks_for_one() {
    var h = new MvsHarness();
    assert(h.wait_for_calls(1));
    h.view.set_api_client(null);
    mvs_settle();

    h.tooltip_button("Add milestone").clicked();

    var expected = HolderLinux.MilestoneDraft.form_precondition_error(false, true, true, false);
    assert(expected != null);
    assert(h.toasts.size == 1 && h.toasts[0] == (!) expected);
}

private void test_mvs_adding_without_any_card_explains_why() {
    var h = new MvsHarness();
    assert(h.wait_for_calls(1));
    h.cards.remove_all();
    mvs_settle();
    assert(!h.tooltip_button("Add milestone").get_sensitive());

    // The button is disabled, but whatever activates the handler still gets an explanation.
    h.tooltip_button("Add milestone").clicked();

    assert(h.toasts.size == 1 && h.toasts[0] == HolderLinux.MilestoneDraft.NO_CARDS_MESSAGE);
    assert(find_button_with_label(h.view.widget, "Add milestone") == null);
}

private void test_mvs_an_end_before_the_start_is_rejected_with_a_toast() {
    var h = new MvsHarness();
    assert(h.wait_for_calls(1));
    h.tooltip_button("Add milestone").clicked();
    var include_end = find_check_with_label(h.view.widget, "Add end");
    assert(include_end != null);
    ((!) include_end).set_active(true);
    var calendars = new Gee.ArrayList<Gtk.Calendar>();
    mvs_collect_calendars(h.view.widget, calendars);
    // The page's own calendar comes first; the form adds a start and an end calendar after it.
    assert(calendars.size == 3);
    HolderLinux.CalendarCompat.set_date(calendars[1], mvs_noon(20));
    HolderLinux.CalendarCompat.set_date(calendars[2], mvs_noon(10));

    var submit = find_button_with_label(h.view.widget, "Add milestone");
    assert(submit != null);
    ((!) submit).clicked();
    mvs_settle();

    assert(h.toasts.size == 1);
    assert(h.api.add_card_milestone_calls == 0);
    // The form stays open so the dates can be corrected.
    assert(find_button_with_label(h.view.widget, "Add milestone") != null);
}

public static int main(string[] args) {
    Test.init(ref args);
    Gtk.init();
    Test.add_func("/holder/milestones-tool/calendar-and-selected-day",
                  test_calendar_marks_activity_and_renders_selected_day);
    Test.add_func("/holder/milestones-tool/no-project", test_without_project_does_not_call_api);
    var prefix = "/holder/milestones-tool/";
    Test.add_func(prefix + "shell-adapter", test_mvs_shell_adapter_reports_identity_scope_and_navigation);
    Test.add_func(prefix + "rebinding", test_mvs_rebinding_stops_listening_to_the_old_context);
    Test.add_func(prefix + "project-switch-clears-marks", test_mvs_switching_project_clears_the_old_marks_and_the_day_while_loading);
    Test.add_func(prefix + "today-button", test_mvs_the_today_button_jumps_to_the_clock_date_and_leaves_upcoming);
    Test.add_func(prefix + "calendar-navigation", test_mvs_calendar_navigation_reloads_the_month_and_selecting_a_day_rerenders);
    Test.add_func(prefix + "refresh-failure", test_mvs_a_failed_refresh_clears_the_marks_and_reports_the_error);
    Test.add_func(prefix + "empty-states", test_mvs_a_day_and_an_upcoming_list_without_milestones_explain_themselves);
    Test.add_func(prefix + "remove-cancel", test_mvs_cancelling_the_remove_dialog_keeps_the_milestone);
    Test.add_func(prefix + "remove-confirm", test_mvs_confirming_the_remove_dialog_removes_the_milestone_and_reloads);
    Test.add_func(prefix + "remove-failure", test_mvs_a_failed_remove_is_reported_and_does_not_reload);
    Test.add_func(prefix + "remove-without-window", test_mvs_removing_without_a_window_does_nothing);
    Test.add_func(prefix + "add-without-api", test_mvs_adding_without_an_api_asks_for_one);
    Test.add_func(prefix + "add-without-cards", test_mvs_adding_without_any_card_explains_why);
    Test.add_func(prefix + "add-end-before-start", test_mvs_an_end_before_the_start_is_rejected_with_a_toast);
    return Test.run();
}

}
