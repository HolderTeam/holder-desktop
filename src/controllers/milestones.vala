namespace HolderLinux {

public enum MilestonesRefreshOutcome {
    LOADED,
    STALE,
    FAILED
}

public class MilestonesRefreshResult : Object {
    public MilestonesRefreshOutcome outcome { get; construct; }
    public ProjectCalendar? calendar { get; construct; }
    public string? error_message { get; construct; }

    public MilestonesRefreshResult(MilestonesRefreshOutcome outcome,
                                   ProjectCalendar? calendar,
                                   string? error_message) {
        Object(outcome: outcome, calendar: calendar, error_message: error_message);
    }
}

// What the view should do after an add/update/remove: toast, error dialog, and whether to reload.
// A silent failure (no calendar API) carries no messages at all.
public class MilestoneMutationResult : Object {
    public bool succeeded { get; construct; }
    public string? toast_message { get; construct; }
    public string? error_title { get; construct; }
    public string? error_details { get; construct; }
    public bool needs_refresh { get; construct; }

    public MilestoneMutationResult(bool succeeded,
                                   string? toast_message,
                                   string? error_title,
                                   string? error_details,
                                   bool needs_refresh) {
        Object(
            succeeded: succeeded,
            toast_message: toast_message,
            error_title: error_title,
            error_details: error_details,
            needs_refresh: needs_refresh
        );
    }
}

public class MilestonesController : Object {
    private uint refresh_serial = 0;

    public IClock clock { get; construct; }
    public TimeZone time_zone;

    public MilestonesController(IClock clock, TimeZone time_zone) {
        Object(clock: clock);
        this.time_zone = time_zone;
    }

    public DateTime now() {
        return MilestonesPresenter.date_from_epoch(clock.now_epoch_seconds(), time_zone);
    }

    public MilestoneRange refresh_range(bool upcoming, DateTime shown_date) {
        return upcoming
            ? MilestonesPresenter.upcoming_range(now(), time_zone)
            : MilestonesPresenter.month_range(shown_date, time_zone);
    }

    public MilestoneFormDefaults form_defaults(Milestone? editing, DateTime calendar_date) {
        return MilestoneDraft.form_defaults(editing, calendar_date, now(), time_zone);
    }

    public uint next_serial() {
        return ++refresh_serial;
    }

    public bool is_current(uint serial) {
        return serial == refresh_serial;
    }

    public async MilestonesRefreshResult refresh_flow(IMilestoneApi api,
                                                      string project_id,
                                                      MilestoneRange range,
                                                      uint serial) {
        try {
            var calendar = yield api.get_project_calendar(
                project_id, range.from_epoch, range.to_epoch
            );
            if (!is_current(serial)) {
                return new MilestonesRefreshResult(MilestonesRefreshOutcome.STALE, null, null);
            }
            return new MilestonesRefreshResult(MilestonesRefreshOutcome.LOADED, calendar, null);
        } catch (Error e) {
            if (!is_current(serial)) {
                return new MilestonesRefreshResult(MilestonesRefreshOutcome.STALE, null, null);
            }
            return new MilestonesRefreshResult(MilestonesRefreshOutcome.FAILED, null, e.message);
        }
    }

    public async MilestoneMutationResult add_flow(IMilestoneApi? api,
                                                  string card_id,
                                                  int64 start_at,
                                                  int64? end_at,
                                                  bool all_day,
                                                  string? kind,
                                                  string? description) {
        if (api == null) return silent_failure();
        try {
            yield ((!) api).add_card_milestone(card_id, start_at, end_at, all_day, kind, description);
            return new MilestoneMutationResult(true, "Milestone added.", null, null, true);
        } catch (Error e) {
            return new MilestoneMutationResult(false, null, "Failed to add milestone", e.message, false);
        }
    }

    public async MilestoneMutationResult update_flow(IMilestoneApi? api,
                                                     Milestone milestone,
                                                     int64 start_at,
                                                     int64? end_at,
                                                     bool all_day,
                                                     string? kind,
                                                     string? description) {
        if (api == null) return silent_failure();
        try {
            yield ((!) api).update_card_milestone(
                milestone.card_id,
                milestone.milestone_id,
                start_at,
                end_at,
                all_day,
                kind,
                description
            );
            return new MilestoneMutationResult(true, "Milestone updated.", null, null, true);
        } catch (Error e) {
            return new MilestoneMutationResult(
                false, null, "Failed to update milestone", e.message, false
            );
        }
    }

    public async MilestoneMutationResult remove_flow(IMilestoneApi? api, Milestone milestone) {
        if (api == null) return silent_failure();
        try {
            var removed = yield ((!) api).remove_card_milestone(
                milestone.card_id, milestone.milestone_id
            );
            return new MilestoneMutationResult(
                true,
                removed ? "Milestone removed." : "Milestone was already removed.",
                null,
                null,
                true
            );
        } catch (Error e) {
            return new MilestoneMutationResult(
                false, null, "Failed to remove milestone", e.message, false
            );
        }
    }

    private static MilestoneMutationResult silent_failure() {
        return new MilestoneMutationResult(false, null, null, null, false);
    }
}

}
