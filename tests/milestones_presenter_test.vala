using GLib;

namespace HolderLinuxTests {

private TimeZone? london() {
    // GLib on Windows resolves named zones through the registry, not IANA zoneinfo files, so the
    // UK zone is "GMT Standard Time" there (same UK DST rules).
    var name = Path.DIR_SEPARATOR == '\\' ? "GMT Standard Time" : "Europe/London";
    try {
        return new TimeZone.identifier(name);
    } catch (Error e) {
        return null;
    }
}

private int64 at(TimeZone tz, int year, int month, int day, int hour = 0, int minute = 0) {
    return new DateTime(tz, year, month, day, hour, minute, 0.0).to_unix();
}

private HolderLinux.Milestone milestone(string card_id,
                                        int64 start_at,
                                        int64? end_at,
                                        bool all_day,
                                        string? kind = null,
                                        string? description = null,
                                        string? card_title = null) {
    return new HolderLinux.Milestone(
        "m-" + card_id, card_id, start_at, end_at, all_day, kind, description, 1, 1, card_title
    );
}

// The pre-hoist implementations that lived in MilestonesToolView, kept verbatim (they use
// the machine's local zone) so the presenter can be checked against the old behaviour.
private bool reference_same_local_day(int64 epoch, DateTime date) {
    var value = new DateTime.from_unix_local(epoch);
    return value.get_year() == date.get_year() &&
        value.get_month() == date.get_month() &&
        value.get_day_of_month() == date.get_day_of_month();
}

private string reference_summary(HolderLinux.Milestone milestone, bool include_date) {
    var start = new DateTime.from_unix_local(milestone.start_at);
    string when = milestone.all_day ? "All day" : start.format("%R");
    if (include_date) when = start.format("%a, %e %b") + " · " + when;
    if (milestone.end_at != null && milestone.all_day) {
        var end = new DateTime.from_unix_local((!) milestone.end_at);
        if (!reference_same_local_day((!) milestone.end_at, start)) {
            when += " – " + end.format("%e %b");
        }
    } else if (milestone.end_at != null) {
        var end = new DateTime.from_unix_local((!) milestone.end_at);
        when += " – " + (reference_same_local_day((!) milestone.end_at, start)
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

private DateTime reference_local_day_start(DateTime value) {
    return new DateTime.local(
        value.get_year(), value.get_month(), value.get_day_of_month(), 0, 0, 0.0
    );
}

private void test_summary_matches_the_old_view_implementation() {
    var tz = new TimeZone.local();
    var zone = london();
    if (zone == null) {
        Test.skip("timezone database unavailable");
        return;
    }
    var z = (!) zone;
    int64[] starts = {
        at(z, 2026, 3, 5, 9, 30), at(z, 2026, 3, 28, 23, 45), at(z, 2026, 3, 29, 0, 30),
        at(z, 2026, 10, 24, 22, 0), at(z, 2026, 10, 25, 0, 30), at(z, 2026, 12, 31, 23, 59)
    };
    int64[] offsets = { 0, 1800, 3 * 3600, 26 * 3600, 49 * 3600 };
    string?[] kinds = { null, "", "  ", "Deadline" };
    string?[] descriptions = { null, "   ", "Bring ID" };
    foreach (var start in starts) {
        foreach (var offset in offsets) {
            foreach (var all_day in new bool[] { false, true }) {
                foreach (var include_date in new bool[] { false, true }) {
                    foreach (var kind in kinds) {
                        foreach (var description in descriptions) {
                            int64? end = null;
                            if (offset != 0) end = start + offset;
                            var item = milestone("c1", start, end, all_day, kind, description);
                            assert(HolderLinux.MilestonesPresenter.milestone_summary(item, include_date, tz)
                                   == reference_summary(item, include_date));
                        }
                    }
                }
            }
        }
    }
}

private void test_day_helpers_match_the_old_view_implementation() {
    var tz = new TimeZone.local();
    var zone = london();
    if (zone == null) {
        Test.skip("timezone database unavailable");
        return;
    }
    var z = (!) zone;
    var reference_day = new DateTime(z, 2026, 3, 29, 12, 0, 0.0);
    int64[] epochs = {
        at(z, 2026, 3, 28, 23, 59), at(z, 2026, 3, 29, 0, 0), at(z, 2026, 3, 29, 23, 59),
        at(z, 2026, 3, 30, 0, 0), at(z, 2026, 10, 25, 0, 30)
    };
    foreach (var epoch in epochs) {
        assert(HolderLinux.MilestonesPresenter.same_local_day(epoch, reference_day, tz)
               == reference_same_local_day(epoch, reference_day));
    }
    foreach (var value in new DateTime[] { reference_day, new DateTime(z, 2026, 10, 25, 1, 30, 0.0) }) {
        assert(HolderLinux.MilestonesPresenter.local_day_start(value, tz).to_unix()
               == reference_local_day_start(value).to_unix());
    }
}

private void test_summary_formats_timed_all_day_and_multi_day_milestones() {
    var zone = london();
    if (zone == null) {
        Test.skip("timezone database unavailable");
        return;
    }
    var z = (!) zone;
    var start = at(z, 2026, 3, 5, 9, 30);

    assert(HolderLinux.MilestonesPresenter.milestone_summary(
        milestone("c", start, null, false), false, z) == "Milestone · 09:30");
    assert(HolderLinux.MilestonesPresenter.milestone_summary(
        milestone("c", start, null, false), true, z) == "Milestone · Thu, \u20075 Mar · 09:30");
    assert(HolderLinux.MilestonesPresenter.milestone_summary(
        milestone("c", at(z, 2026, 3, 5), null, true, "Deadline"), false, z)
        == "Deadline · All day");
    // All-day range on one day gets no end suffix, across days it shows the end date.
    assert(HolderLinux.MilestonesPresenter.milestone_summary(
        milestone("c", at(z, 2026, 3, 5), at(z, 2026, 3, 5, 12), true), false, z)
        == "Milestone · All day");
    assert(HolderLinux.MilestonesPresenter.milestone_summary(
        milestone("c", at(z, 2026, 3, 5), at(z, 2026, 3, 7), true), false, z)
        == "Milestone · All day – \u20077 Mar");
    // Timed range: same day shows the end time, another day includes the date.
    assert(HolderLinux.MilestonesPresenter.milestone_summary(
        milestone("c", start, at(z, 2026, 3, 5, 11, 0), false, "Event"), false, z)
        == "Event · 09:30 – 11:00");
    assert(HolderLinux.MilestonesPresenter.milestone_summary(
        milestone("c", start, at(z, 2026, 3, 6, 11, 0), false, "Event"), false, z)
        == "Event · 09:30 – \u20076 Mar 11:00");
    // Blank kind falls back, blank description is dropped, real description is appended.
    assert(HolderLinux.MilestonesPresenter.milestone_summary(
        milestone("c", start, null, false, "   ", "  "), false, z) == "Milestone · 09:30");
    assert(HolderLinux.MilestonesPresenter.milestone_summary(
        milestone("c", start, null, false, null, "Bring ID"), false, z)
        == "Milestone · 09:30\nBring ID");
}

private void test_summary_uses_the_supplied_zone_across_daylight_saving_changes() {
    var zone = london();
    if (zone == null) {
        Test.skip("timezone database unavailable");
        return;
    }
    var z = (!) zone;
    // 2026-03-29 clocks go forward at 01:00 UTC: 00:30 GMT is 00:30, 02:30 UTC is 03:30 BST.
    var spring_start = at(new TimeZone.utc(), 2026, 3, 29, 0, 30);
    var spring = milestone("c", spring_start, spring_start + 2 * 3600, false);
    assert(HolderLinux.MilestonesPresenter.date_from_epoch(spring_start, z).get_hour() == 0);
    assert(HolderLinux.MilestonesPresenter.milestone_summary(spring, false, z)
           == "Milestone · 00:30 – 03:30");
    // The same instant in UTC is a different wall-clock time.
    assert(HolderLinux.MilestonesPresenter.milestone_summary(spring, false, new TimeZone.utc())
           == "Milestone · 00:30 – 02:30");
    // 2026-10-25 clocks go back: an all-day range ending on the 26th still spans two days.
    assert(HolderLinux.MilestonesPresenter.milestone_summary(
        milestone("c", at(z, 2026, 10, 25), at(z, 2026, 10, 26), true), false, z)
        == "Milestone · All day – 26 Oct");
    // 23:30 UTC in summer is already the next day in London.
    var late = at(new TimeZone.utc(), 2026, 6, 30, 23, 30);
    assert(HolderLinux.MilestonesPresenter.milestone_summary(
        milestone("c", late, null, false), true, z) == "Milestone · Wed, \u20071 Jul · 00:30");
}

private void test_ranges_cover_month_and_five_year_windows() {
    var zone = london();
    if (zone == null) {
        Test.skip("timezone database unavailable");
        return;
    }
    var z = (!) zone;

    var january = HolderLinux.MilestonesPresenter.month_range(new DateTime(z, 2026, 1, 17, 8, 0, 0.0), z);
    assert(january.from_epoch == at(z, 2026, 1, 1));
    assert(january.to_epoch == at(z, 2026, 2, 1) - 1);

    var december = HolderLinux.MilestonesPresenter.month_range(new DateTime(z, 2026, 12, 31, 23, 0, 0.0), z);
    assert(december.from_epoch == at(z, 2026, 12, 1));
    assert(december.to_epoch == at(z, 2027, 1, 1) - 1);

    // March 2026 contains the spring-forward change, so it is one hour short.
    var march = HolderLinux.MilestonesPresenter.month_range(new DateTime(z, 2026, 3, 29, 12, 0, 0.0), z);
    assert(march.to_epoch - march.from_epoch + 1 == 31 * 24 * 3600 - 3600);

    var upcoming = HolderLinux.MilestonesPresenter.upcoming_range(new DateTime(z, 2026, 3, 5, 15, 20, 0.0), z);
    assert(upcoming.from_epoch == at(z, 2026, 3, 5));
    assert(upcoming.to_epoch == at(z, 2031, 3, 5) - 1);
}

private void test_group_for_day_and_sorted_upcoming() {
    var zone = london();
    if (zone == null) {
        Test.skip("timezone database unavailable");
        return;
    }
    var z = (!) zone;
    var day = new DateTime(z, 2026, 3, 5, 12, 0, 0.0);
    var first = milestone("b", at(z, 2026, 3, 5, 9), null, false);
    var second = milestone("a", at(z, 2026, 3, 5, 9), null, false);
    var other_day = milestone("c", at(z, 2026, 3, 6, 9), null, false);
    var earlier = milestone("d", at(z, 2026, 3, 4, 23), null, false);
    HolderLinux.Milestone[] milestones = { first, other_day, second, earlier };
    HolderLinux.CalendarCardActivity[] created = {
        new HolderLinux.CalendarCardActivity("k1", "Made today", at(z, 2026, 3, 5, 8), at(z, 2026, 3, 9)),
        new HolderLinux.CalendarCardActivity("k2", "Made tomorrow", at(z, 2026, 3, 6, 8), at(z, 2026, 3, 5, 18))
    };
    HolderLinux.CalendarCardActivity[] updated = {
        new HolderLinux.CalendarCardActivity("k1", "Made today", at(z, 2026, 3, 5, 8), at(z, 2026, 3, 5, 20))
    };
    var data = new HolderLinux.ProjectCalendar("p1", 0, 1, milestones, created, updated);

    var groups = HolderLinux.MilestonesPresenter.group_for_day(data, day, z);
    assert(!groups.is_empty);
    assert(groups.milestones.size == 2);
    assert(groups.milestones[0] == first);
    assert(groups.milestones[1] == second);
    assert(groups.created.size == 1 && groups.created[0].card_id == "k1");
    assert(groups.updated.size == 1);

    var empty_day = HolderLinux.MilestonesPresenter.group_for_day(data, new DateTime(z, 2026, 3, 20, 0, 0, 0.0), z);
    assert(empty_day.is_empty);

    // Sorted by start, ties broken by card id; the input array order is not changed.
    var sorted = HolderLinux.MilestonesPresenter.sorted_upcoming(data);
    assert(sorted.size == 4);
    assert(sorted[0] == earlier);
    assert(sorted[1] == second);
    assert(sorted[2] == first);
    assert(sorted[3] == other_day);
    assert(data.milestones[0] == first);
}

private void test_visible_mark_days_are_unique_and_limited_to_the_visible_month() {
    var zone = london();
    if (zone == null) {
        Test.skip("timezone database unavailable");
        return;
    }
    var z = (!) zone;
    var visible = new DateTime(z, 2026, 4, 10, 0, 0, 0.0);
    // 23:30 UTC on 31 March is 00:30 BST on 1 April, so it belongs to April in London.
    var utc_late_march = at(new TimeZone.utc(), 2026, 3, 31, 23, 30);
    HolderLinux.Milestone[] milestones = {
        milestone("a", at(z, 2026, 4, 3, 9), null, false),
        milestone("b", at(z, 2026, 4, 3, 17), null, false),
        milestone("c", at(z, 2026, 5, 1, 0), null, false),
        milestone("d", utc_late_march, null, false)
    };
    HolderLinux.CalendarCardActivity[] created = {
        new HolderLinux.CalendarCardActivity("k", "K", at(z, 2026, 4, 20, 1), at(z, 2026, 3, 30))
    };
    HolderLinux.CalendarCardActivity[] updated = {
        new HolderLinux.CalendarCardActivity("k", "K", at(z, 2026, 4, 20, 1), at(z, 2026, 4, 3, 22)),
        new HolderLinux.CalendarCardActivity("k", "K", at(z, 2026, 4, 20, 1), at(z, 2026, 4, 30, 23, 59))
    };
    var data = new HolderLinux.ProjectCalendar("p1", 0, 1, milestones, created, updated);

    var days = HolderLinux.MilestonesPresenter.visible_mark_days(data, visible, z);
    assert(days.size == 4);
    assert(days[0] == 3);
    assert(days[1] == 1);
    assert(days[2] == 20);
    assert(days[3] == 30);

    var empty = new HolderLinux.ProjectCalendar("p1", 0, 1, {}, {}, {});
    assert(HolderLinux.MilestonesPresenter.visible_mark_days(empty, visible, z).size == 0);
}

private void test_titles_messages_and_small_predicates() {
    var zone = london();
    if (zone == null) {
        Test.skip("timezone database unavailable");
        return;
    }
    var z = (!) zone;
    assert(HolderLinux.MilestonesPresenter.selected_day_title(new DateTime(z, 2026, 3, 5, 0, 0, 0.0))
           == "Thursday, \u20075 March 2026");
    assert(HolderLinux.MilestonesPresenter.activity_time_text(at(z, 2026, 7, 1, 7, 5), z) == "07:05");

    assert(HolderLinux.MilestonesPresenter.unavailable_message(false)
           == "Select a project to see its calendar.");
    assert(HolderLinux.MilestonesPresenter.unavailable_message(true)
           == "Calendar service is unavailable.");

    assert(HolderLinux.MilestonesPresenter.can_add_milestone(true, true, 1));
    assert(!HolderLinux.MilestonesPresenter.can_add_milestone(false, true, 1));
    assert(!HolderLinux.MilestonesPresenter.can_add_milestone(true, false, 1));
    assert(!HolderLinux.MilestonesPresenter.can_add_milestone(true, true, 0));

    var titled = milestone("c", 1, null, true, null, null, "Renew passport");
    var untitled = milestone("c", 1, null, true);
    assert(HolderLinux.MilestonesPresenter.milestone_card_title(titled) == "Renew passport");
    assert(HolderLinux.MilestonesPresenter.milestone_card_title(untitled) == "Open card");
    assert(HolderLinux.MilestonesPresenter.remove_dialog_body(titled)
           == "This removes the milestone from \"Renew passport\". The card itself is unchanged.");
    assert(HolderLinux.MilestonesPresenter.remove_dialog_body(untitled)
           == "This removes the milestone from \"this card\". The card itself is unchanged.");
}

public static int main(string[] args) {
    // GLib pads single-digit %e days with a figure space (U+2007), written \u2007 below.
    Environment.set_variable("TZ", "Europe/London", true);
    Intl.setlocale(LocaleCategory.ALL, "C");
    Test.init(ref args);

    Test.add_func("/milestones-presenter/summary-matches-old-view",
                  test_summary_matches_the_old_view_implementation);
    Test.add_func("/milestones-presenter/day-helpers-match-old-view",
                  test_day_helpers_match_the_old_view_implementation);
    Test.add_func("/milestones-presenter/summary-formats",
                  test_summary_formats_timed_all_day_and_multi_day_milestones);
    Test.add_func("/milestones-presenter/summary-across-dst",
                  test_summary_uses_the_supplied_zone_across_daylight_saving_changes);
    Test.add_func("/milestones-presenter/ranges", test_ranges_cover_month_and_five_year_windows);
    Test.add_func("/milestones-presenter/group-and-sort", test_group_for_day_and_sorted_upcoming);
    Test.add_func("/milestones-presenter/mark-days",
                  test_visible_mark_days_are_unique_and_limited_to_the_visible_month);
    Test.add_func("/milestones-presenter/titles-and-predicates",
                  test_titles_messages_and_small_predicates);

    return Test.run();
}

}
