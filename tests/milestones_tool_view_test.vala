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

public static int main(string[] args) {
    Test.init(ref args);
    Gtk.init();
    Test.add_func("/holder/milestones-tool/calendar-and-selected-day",
                  test_calendar_marks_activity_and_renders_selected_day);
    Test.add_func("/holder/milestones-tool/no-project", test_without_project_does_not_call_api);
    return Test.run();
}

}
