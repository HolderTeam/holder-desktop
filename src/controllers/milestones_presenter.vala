namespace HolderLinux {

public class MilestoneRange : Object {
    public int64 from_epoch { get; construct; }
    public int64 to_epoch { get; construct; }

    public MilestoneRange(int64 from_epoch, int64 to_epoch) {
        Object(from_epoch: from_epoch, to_epoch: to_epoch);
    }
}

public class MilestoneDayGroups : Object {
    public Gee.ArrayList<Milestone> milestones { get; construct; }
    public Gee.ArrayList<CalendarCardActivity> created { get; construct; }
    public Gee.ArrayList<CalendarCardActivity> updated { get; construct; }

    public bool is_empty {
        get { return milestones.size == 0 && created.size == 0 && updated.size == 0; }
    }

    public MilestoneDayGroups(Gee.ArrayList<Milestone> milestones,
                              Gee.ArrayList<CalendarCardActivity> created,
                              Gee.ArrayList<CalendarCardActivity> updated) {
        Object(milestones: milestones, created: created, updated: updated);
    }
}

// Calendar/date decisions for the Milestones tool. Every method that turns an epoch into a
// calendar date takes the TimeZone explicitly so tests do not depend on the machine's zone.
public class MilestonesPresenter {
    public const string SELECT_PROJECT_MESSAGE = "Select a project to see its calendar.";
    public const string SERVICE_UNAVAILABLE_MESSAGE = "Calendar service is unavailable.";
    public const string LOADING_UPCOMING_MESSAGE = "Loading upcoming milestones…";
    public const string LOADING_CALENDAR_MESSAGE = "Loading calendar…";
    public const string LOAD_FAILED_MESSAGE = "Failed to load this project’s calendar.";
    public const string NO_CALENDAR_DATA_MESSAGE = "No calendar data loaded.";
    public const string NOTHING_ON_DAY_MESSAGE = "Nothing recorded on this day.";
    public const string NO_UPCOMING_MESSAGE = "No upcoming milestones in the next five years.";
    public const string UPCOMING_TITLE = "Upcoming milestones";

    public static string unavailable_message(bool has_project) {
        return has_project ? SERVICE_UNAVAILABLE_MESSAGE : SELECT_PROJECT_MESSAGE;
    }

    public static bool can_add_milestone(bool has_milestone_api, bool has_project, uint card_count) {
        return has_milestone_api && has_project && card_count > 0;
    }

    public static DateTime date_from_epoch(int64 epoch, TimeZone tz) {
        return new DateTime.from_unix_utc(epoch).to_timezone(tz);
    }

    public static DateTime local_day_start(DateTime value, TimeZone tz) {
        return new DateTime(
            tz, value.get_year(), value.get_month(), value.get_day_of_month(), 0, 0, 0.0
        );
    }

    public static bool same_local_day(int64 epoch, DateTime date, TimeZone tz) {
        var value = date_from_epoch(epoch, tz);
        return value.get_year() == date.get_year() &&
            value.get_month() == date.get_month() &&
            value.get_day_of_month() == date.get_day_of_month();
    }

    public static MilestoneRange upcoming_range(DateTime now, TimeZone tz) {
        var start = local_day_start(now, tz);
        return new MilestoneRange(start.to_unix(), start.add_years(5).to_unix() - 1);
    }

    public static MilestoneRange month_range(DateTime shown, TimeZone tz) {
        var start = new DateTime(tz, shown.get_year(), shown.get_month(), 1, 0, 0, 0.0);
        return new MilestoneRange(start.to_unix(), start.add_months(1).to_unix() - 1);
    }

    public static MilestoneDayGroups group_for_day(ProjectCalendar data, DateTime selected, TimeZone tz) {
        var day_milestones = new Gee.ArrayList<Milestone>();
        var created = new Gee.ArrayList<CalendarCardActivity>();
        var updated = new Gee.ArrayList<CalendarCardActivity>();
        foreach (var item in data.milestones) {
            if (same_local_day(item.start_at, selected, tz)) day_milestones.add(item);
        }
        foreach (var item in data.created_cards) {
            if (same_local_day(item.created_at, selected, tz)) created.add(item);
        }
        foreach (var item in data.updated_cards) {
            if (same_local_day(item.updated_at, selected, tz)) updated.add(item);
        }
        return new MilestoneDayGroups(day_milestones, created, updated);
    }

    public static Gee.ArrayList<Milestone> sorted_upcoming(ProjectCalendar data) {
        var sorted = new Gee.ArrayList<Milestone>();
        foreach (var milestone in data.milestones) {
            sorted.add(milestone);
        }
        sorted.sort((a, b) => {
            if (a.start_at < b.start_at) return -1;
            if (a.start_at > b.start_at) return 1;
            return strcmp(a.card_id, b.card_id);
        });
        return sorted;
    }

    // Days of the visible month that have a milestone or card activity, in first-seen order.
    public static Gee.ArrayList<int> visible_mark_days(ProjectCalendar data,
                                                       DateTime visible,
                                                       TimeZone tz) {
        var days = new Gee.ArrayList<int>();
        foreach (var milestone in data.milestones) {
            add_mark_day(days, milestone.start_at, visible, tz);
        }
        foreach (var item in data.created_cards) {
            add_mark_day(days, item.created_at, visible, tz);
        }
        foreach (var item in data.updated_cards) {
            add_mark_day(days, item.updated_at, visible, tz);
        }
        return days;
    }

    private static void add_mark_day(Gee.ArrayList<int> days,
                                     int64 epoch,
                                     DateTime visible,
                                     TimeZone tz) {
        var date = date_from_epoch(epoch, tz);
        if (date.get_year() == visible.get_year() && date.get_month() == visible.get_month()) {
            var day = date.get_day_of_month();
            if (!days.contains(day)) days.add(day);
        }
    }

    public static string selected_day_title(DateTime selected) {
        return selected.format("%A, %e %B %Y");
    }

    public static string activity_time_text(int64 epoch, TimeZone tz) {
        return date_from_epoch(epoch, tz).format("%R");
    }

    public static string milestone_card_title(Milestone milestone) {
        return milestone.card_title ?? "Open card";
    }

    public static string milestone_summary(Milestone milestone, bool include_date, TimeZone tz) {
        var start = date_from_epoch(milestone.start_at, tz);
        string when = milestone.all_day ? "All day" : start.format("%R");
        if (include_date) when = start.format("%a, %e %b") + " · " + when;
        if (milestone.end_at != null && milestone.all_day) {
            var end = date_from_epoch((!) milestone.end_at, tz);
            if (!same_local_day((!) milestone.end_at, start, tz)) {
                when += " – " + end.format("%e %b");
            }
        } else if (milestone.end_at != null) {
            var end = date_from_epoch((!) milestone.end_at, tz);
            when += " – " + (same_local_day((!) milestone.end_at, start, tz)
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

    public static string remove_dialog_body(Milestone milestone) {
        return "This removes the milestone from \"%s\". The card itself is unchanged.".printf(
            milestone.card_title ?? "this card"
        );
    }
}

}
