namespace HolderLinux {

public class MilestoneCardOptions : Object {
    public Gee.ArrayList<string> card_ids { get; construct; }
    public Gee.ArrayList<string> card_names { get; construct; }
    public uint selected_index { get; construct; }

    public MilestoneCardOptions(Gee.ArrayList<string> card_ids,
                                Gee.ArrayList<string> card_names,
                                uint selected_index) {
        Object(card_ids: card_ids, card_names: card_names, selected_index: selected_index);
    }
}

public class MilestoneFormDefaults : Object {
    public DateTime start { get; construct; }
    public DateTime end { get; construct; }
    public bool include_end { get; construct; }
    public bool all_day { get; construct; }
    public int start_hour { get; construct; }
    public int start_minute { get; construct; }
    public int end_hour { get; construct; }
    public int end_minute { get; construct; }
    public string kind { get; construct; }
    public string description { get; construct; }

    public MilestoneFormDefaults(DateTime start,
                                 DateTime end,
                                 bool include_end,
                                 bool all_day,
                                 int start_hour,
                                 int start_minute,
                                 int end_hour,
                                 int end_minute,
                                 string kind,
                                 string description) {
        Object(
            start: start,
            end: end,
            include_end: include_end,
            all_day: all_day,
            start_hour: start_hour,
            start_minute: start_minute,
            end_hour: end_hour,
            end_minute: end_minute,
            kind: kind,
            description: description
        );
    }
}

public class MilestoneDraftResult : Object {
    public string? error_message { get; construct; }
    public int64 start_at { get; construct; }
    public int64? end_at;
    public bool all_day { get; construct; }
    public string? kind { get; construct; }
    public string? description { get; construct; }

    public MilestoneDraftResult(string? error_message,
                                int64 start_at,
                                int64? end_at,
                                bool all_day,
                                string? kind,
                                string? description) {
        Object(
            error_message: error_message,
            start_at: start_at,
            all_day: all_day,
            kind: kind,
            description: description
        );
        this.end_at = end_at;
    }
}

// Form rules for adding/editing a milestone: which cards can be chosen, what the form starts
// with, and how the chosen dates/times become epochs. The view only reads and writes widgets.
public class MilestoneDraft { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public const string NOT_READY_MESSAGE = "Select a project and connect to Holder first.";
    public const string NO_CARDS_MESSAGE = "Create a card before adding a milestone.";
    public const string END_BEFORE_START_MESSAGE = "The end must not be before the start.";

    public static string[] kind_presets() {
        return { "Deadline", "Appointment", "Event", "Exam", "Birthday",
            "Expiry", "Renewal", "Service", "MOT" };
    }

    public static string form_title(bool editing) {
        return editing ? "Edit milestone" : "Add milestone";
    }

    public static string form_subtitle(bool editing) {
        return editing
            ? "Update this milestone without changing its identity."
            : "Attach a date to a card in this project.";
    }

    public static string submit_label(bool editing) {
        return editing ? "Save changes" : "Add milestone";
    }

    public static string card_label(Milestone editing) {
        return editing.card_title ?? editing.card_id;
    }

    public static string? form_precondition_error(bool has_milestone_api,
                                                  bool has_project,
                                                  bool has_card_store,
                                                  bool editing) {
        if (!has_milestone_api || !has_project || (!editing && !has_card_store)) {
            return NOT_READY_MESSAGE;
        }
        return null;
    }

    public static MilestoneCardOptions card_options(Gee.List<CardSummary> cards,
                                                    string project_id,
                                                    string? selected_card_id) {
        var card_ids = new Gee.ArrayList<string>();
        var card_names = new Gee.ArrayList<string>();
        uint selected_index = 0;
        foreach (var card in cards) {
            if (card.project_id != project_id) continue;
            if (selected_card_id != null && card.card_id == selected_card_id) {
                selected_index = (uint) card_ids.size;
            }
            card_ids.add(card.card_id);
            card_names.add(card.title);
        }
        return new MilestoneCardOptions(card_ids, card_names, selected_index);
    }

    // The card a submitted form targets: the milestone's own card when editing, otherwise the
    // dropdown choice. Null when the dropdown has no valid selection.
    public static string? resolve_card_id(Gee.ArrayList<string> card_ids,
                                          uint selected_index,
                                          Milestone? editing) {
        if (editing != null) {
            return ((!) editing).card_id;
        }
        if ((int64) selected_index >= card_ids.size) {
            return null;
        }
        return card_ids[(int) selected_index];
    }

    public static MilestoneFormDefaults form_defaults(Milestone? editing,
                                                      DateTime calendar_date,
                                                      DateTime now,
                                                      TimeZone tz) {
        int64? editing_end = editing != null ? ((!) editing).end_at : null;
        var initial_start = editing != null
            ? MilestonesPresenter.date_from_epoch(((!) editing).start_at, tz)
            : calendar_date;
        var initial_end = editing_end != null
            ? MilestonesPresenter.date_from_epoch((!) editing_end, tz)
            : initial_start;
        var default_end_hour = now.get_hour() + 1 > 23 ? 23 : now.get_hour() + 1;
        return new MilestoneFormDefaults(
            initial_start,
            initial_end,
            editing_end != null,
            editing == null || ((!) editing).all_day,
            editing != null ? initial_start.get_hour() : now.get_hour(),
            editing != null ? initial_start.get_minute() : now.get_minute(),
            editing != null ? initial_end.get_hour() : default_end_hour,
            editing != null ? initial_end.get_minute() : now.get_minute(),
            editing != null && ((!) editing).kind != null ? (!) ((!) editing).kind : "",
            editing != null && ((!) editing).description != null
                ? (!) ((!) editing).description : ""
        );
    }

    public static DateTime date_with_time(DateTime date, int hour, int minute, TimeZone tz) {
        return new DateTime(
            tz, date.get_year(), date.get_month(), date.get_day_of_month(), hour, minute, 0.0
        );
    }

    public static string? optional_text(string text) {
        var normalized = text.strip();
        return normalized.length > 0 ? normalized : null;
    }

    public static MilestoneDraftResult build(DateTime start_date,
                                             int start_hour,
                                             int start_minute,
                                             bool include_end,
                                             DateTime end_date,
                                             int end_hour,
                                             int end_minute,
                                             bool all_day,
                                             string kind_text,
                                             string description_text,
                                             TimeZone tz) {
        var start_at = date_with_time(
            start_date,
            all_day ? 0 : start_hour,
            all_day ? 0 : start_minute,
            tz
        ).to_unix();
        int64? end_at = null;
        if (include_end) {
            end_at = date_with_time(
                end_date,
                all_day ? 0 : end_hour,
                all_day ? 0 : end_minute,
                tz
            ).to_unix();
            if ((!) end_at < start_at) {
                return new MilestoneDraftResult(
                    END_BEFORE_START_MESSAGE, start_at, end_at, all_day, null, null
                );
            }
        }
        return new MilestoneDraftResult(
            null,
            start_at,
            end_at,
            all_day,
            optional_text(kind_text),
            optional_text(description_text)
        );
    }
}

}
