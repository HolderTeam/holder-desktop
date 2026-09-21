using GLib;

namespace HolderLinuxTests {

private delegate void CallHook();

private class FixedClock : Object, HolderLinux.IClock {
    public int64 epoch { get; set; default = 0; }

    public int64 now_epoch_seconds() {
        return epoch;
    }
}

private class FakeMilestoneApi : Object, HolderLinux.IMilestoneApi {
    public HolderLinux.ProjectCalendar calendar = new HolderLinux.ProjectCalendar("p1", 0, 1, {}, {}, {});
    public Error? error = null;
    public bool remove_result = true;
    public CallHook? during_call = null;

    public int calendar_calls { get; set; default = 0; }
    public string? last_project_id = null;
    public int64 last_from = 0;
    public int64 last_to = 0;
    public int add_calls = 0;
    public int update_calls = 0;
    public int remove_calls = 0;
    public string? last_card_id = null;
    public string? last_milestone_id = null;
    public int64 last_start_at = 0;
    public int64? last_end_at = null;
    public bool last_all_day = false;
    public string? last_kind = null;
    public string? last_description = null;

    private void record(string card_id, int64 start_at, int64? end_at, bool all_day,
                        string? kind, string? description) {
        last_card_id = card_id;
        last_start_at = start_at;
        last_end_at = end_at;
        last_all_day = all_day;
        last_kind = kind;
        last_description = description;
    }

    public async HolderLinux.ProjectCalendar get_project_calendar(string project_id,
                                                                  int64 from_epoch,
                                                                  int64 to_epoch) throws Error {
        calendar_calls++;
        last_project_id = project_id;
        last_from = from_epoch;
        last_to = to_epoch;
        if (during_call != null) {
            ((!) during_call)();
        }
        if (error != null) {
            throw error;
        }
        return calendar;
    }

    public async Gee.ArrayList<HolderLinux.Milestone> list_card_milestones(string card_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }

    public async HolderLinux.Milestone add_card_milestone(string card_id,
                                                          int64 start_at,
                                                          int64? end_at,
                                                          bool all_day,
                                                          string? kind,
                                                          string? description) throws Error {
        add_calls++;
        record(card_id, start_at, end_at, all_day, kind, description);
        if (error != null) {
            throw error;
        }
        return new HolderLinux.Milestone("m-new", card_id, start_at, end_at, all_day, kind, description, 1, 1);
    }

    public async HolderLinux.Milestone update_card_milestone(string card_id,
                                                             string milestone_id,
                                                             int64 start_at,
                                                             int64? end_at,
                                                             bool all_day,
                                                             string? kind,
                                                             string? description) throws Error {
        update_calls++;
        last_milestone_id = milestone_id;
        record(card_id, start_at, end_at, all_day, kind, description);
        if (error != null) {
            throw error;
        }
        return new HolderLinux.Milestone(milestone_id, card_id, start_at, end_at, all_day, kind, description, 1, 1);
    }

    public async bool remove_card_milestone(string card_id, string milestone_id) throws Error {
        remove_calls++;
        last_card_id = card_id;
        last_milestone_id = milestone_id;
        if (error != null) {
            throw error;
        }
        return remove_result;
    }
}

private HolderLinux.MilestonesController make_controller(FixedClock clock, TimeZone tz) {
    return new HolderLinux.MilestonesController(clock, tz);
}

private HolderLinux.Milestone existing() {
    return new HolderLinux.Milestone("m1", "c1", 100, null, true, null, null, 1, 1);
}

private HolderLinux.MilestonesRefreshResult run_refresh(HolderLinux.MilestonesController controller,
                                                        FakeMilestoneApi api,
                                                        uint serial) {
    HolderLinux.MilestonesRefreshResult? result = null;
    var loop = new MainLoop();
    controller.refresh_flow.begin(
        api, "p1", new HolderLinux.MilestoneRange(10, 20), serial, (obj, res) => {
            result = controller.refresh_flow.end(res);
            loop.quit();
        }
    );
    loop.run();
    return (!) result;
}

private HolderLinux.MilestoneMutationResult run_add(HolderLinux.MilestonesController controller,
                                                    HolderLinux.IMilestoneApi? api) {
    HolderLinux.MilestoneMutationResult? result = null;
    var loop = new MainLoop();
    controller.add_flow.begin(api, "c1", 5, 9, false, "Exam", "Room 4", (obj, res) => {
        result = controller.add_flow.end(res);
        loop.quit();
    });
    loop.run();
    return (!) result;
}

private HolderLinux.MilestoneMutationResult run_update(HolderLinux.MilestonesController controller,
                                                       HolderLinux.IMilestoneApi? api) {
    HolderLinux.MilestoneMutationResult? result = null;
    var loop = new MainLoop();
    controller.update_flow.begin(api, existing(), 5, null, true, null, null, (obj, res) => {
        result = controller.update_flow.end(res);
        loop.quit();
    });
    loop.run();
    return (!) result;
}

private HolderLinux.MilestoneMutationResult run_remove(HolderLinux.MilestonesController controller,
                                                       HolderLinux.IMilestoneApi? api) {
    HolderLinux.MilestoneMutationResult? result = null;
    var loop = new MainLoop();
    controller.remove_flow.begin(api, existing(), (obj, res) => {
        result = controller.remove_flow.end(res);
        loop.quit();
    });
    loop.run();
    return (!) result;
}

private TimeZone? london() {
    try {
        return new TimeZone.identifier("Europe/London");
    } catch (Error e) {
        return null;
    }
}

private void test_clock_drives_now_ranges_and_form_defaults() {
    var zone = london();
    if (zone == null) {
        Test.skip("timezone database unavailable");
        return;
    }
    var z = (!) zone;
    var clock = new FixedClock();
    clock.epoch = new DateTime(z, 2026, 3, 5, 9, 15, 0.0).to_unix();
    var controller = make_controller(clock, z);

    var now = controller.now();
    assert(now.get_year() == 2026 && now.get_hour() == 9 && now.get_minute() == 15);

    var upcoming = controller.refresh_range(true, new DateTime(z, 2030, 1, 1, 0, 0, 0.0));
    assert(upcoming.from_epoch == new DateTime(z, 2026, 3, 5, 0, 0, 0.0).to_unix());
    assert(upcoming.to_epoch == new DateTime(z, 2031, 3, 5, 0, 0, 0.0).to_unix() - 1);

    var month = controller.refresh_range(false, new DateTime(z, 2027, 2, 14, 12, 0, 0.0));
    assert(month.from_epoch == new DateTime(z, 2027, 2, 1, 0, 0, 0.0).to_unix());
    assert(month.to_epoch == new DateTime(z, 2027, 3, 1, 0, 0, 0.0).to_unix() - 1);

    var defaults = controller.form_defaults(null, new DateTime(z, 2026, 3, 12, 0, 0, 0.0));
    assert(defaults.start_hour == 9 && defaults.end_hour == 10 && defaults.end_minute == 15);

    clock.epoch = new DateTime(z, 2026, 3, 5, 23, 59, 0.0).to_unix();
    assert(controller.form_defaults(null, now).end_hour == 23);
}

private void test_serials_track_the_latest_refresh() {
    var controller = make_controller(new FixedClock(), new TimeZone.utc());
    var first = controller.next_serial();
    assert(controller.is_current(first));
    var second = controller.next_serial();
    assert(second == first + 1);
    assert(!controller.is_current(first));
    assert(controller.is_current(second));
}

private void test_refresh_flow_loads_the_calendar() {
    var controller = make_controller(new FixedClock(), new TimeZone.utc());
    var api = new FakeMilestoneApi();
    var result = run_refresh(controller, api, controller.next_serial());

    assert(result.outcome == HolderLinux.MilestonesRefreshOutcome.LOADED);
    assert(result.calendar == api.calendar);
    assert(result.error_message == null);
    assert(api.last_project_id == "p1" && api.last_from == 10 && api.last_to == 20);
}

private void test_refresh_flow_reports_failure() {
    var controller = make_controller(new FixedClock(), new TimeZone.utc());
    var api = new FakeMilestoneApi();
    api.error = new IOError.FAILED("calendar down");
    var result = run_refresh(controller, api, controller.next_serial());

    assert(result.outcome == HolderLinux.MilestonesRefreshOutcome.FAILED);
    assert(result.calendar == null);
    assert(result.error_message == "calendar down");
}

private void test_refresh_flow_drops_results_superseded_while_in_flight() {
    var controller = make_controller(new FixedClock(), new TimeZone.utc());
    var api = new FakeMilestoneApi();
    api.during_call = () => { controller.next_serial(); };
    var stale_success = run_refresh(controller, api, controller.next_serial());
    assert(stale_success.outcome == HolderLinux.MilestonesRefreshOutcome.STALE);
    assert(stale_success.calendar == null);

    api.error = new IOError.FAILED("late failure");
    var stale_failure = run_refresh(controller, api, controller.next_serial());
    assert(stale_failure.outcome == HolderLinux.MilestonesRefreshOutcome.STALE);
    assert(stale_failure.error_message == null);
}

private void test_add_flow() {
    var controller = make_controller(new FixedClock(), new TimeZone.utc());
    var api = new FakeMilestoneApi();
    var ok = run_add(controller, api);
    assert(ok.succeeded && ok.needs_refresh);
    assert(ok.toast_message == "Milestone added.");
    assert(ok.error_title == null && ok.error_details == null);
    assert(api.add_calls == 1);
    assert(api.last_card_id == "c1" && api.last_start_at == 5 && api.last_end_at == 9);
    assert(!api.last_all_day && api.last_kind == "Exam" && api.last_description == "Room 4");

    api.error = new IOError.FAILED("nope");
    var failed = run_add(controller, api);
    assert(!failed.succeeded && !failed.needs_refresh);
    assert(failed.toast_message == null);
    assert(failed.error_title == "Failed to add milestone" && failed.error_details == "nope");

    var silent = run_add(controller, null);
    assert(!silent.succeeded && !silent.needs_refresh);
    assert(silent.toast_message == null && silent.error_title == null && silent.error_details == null);
}

private void test_update_flow() {
    var controller = make_controller(new FixedClock(), new TimeZone.utc());
    var api = new FakeMilestoneApi();
    var ok = run_update(controller, api);
    assert(ok.succeeded && ok.needs_refresh);
    assert(ok.toast_message == "Milestone updated.");
    assert(api.last_card_id == "c1" && api.last_milestone_id == "m1");
    assert(api.last_start_at == 5 && api.last_end_at == null && api.last_all_day);

    api.error = new IOError.FAILED("nope");
    var failed = run_update(controller, api);
    assert(!failed.succeeded && !failed.needs_refresh);
    assert(failed.error_title == "Failed to update milestone" && failed.error_details == "nope");

    var silent = run_update(controller, null);
    assert(!silent.succeeded && silent.toast_message == null && silent.error_title == null);
}

private void test_remove_flow() {
    var controller = make_controller(new FixedClock(), new TimeZone.utc());
    var api = new FakeMilestoneApi();
    var removed = run_remove(controller, api);
    assert(removed.succeeded && removed.needs_refresh);
    assert(removed.toast_message == "Milestone removed.");
    assert(api.last_card_id == "c1" && api.last_milestone_id == "m1");

    api.remove_result = false;
    var already = run_remove(controller, api);
    assert(already.succeeded && already.needs_refresh);
    assert(already.toast_message == "Milestone was already removed.");

    api.error = new IOError.FAILED("nope");
    var failed = run_remove(controller, api);
    assert(!failed.succeeded && !failed.needs_refresh);
    assert(failed.error_title == "Failed to remove milestone" && failed.error_details == "nope");

    var silent = run_remove(controller, null);
    assert(!silent.succeeded && silent.toast_message == null && silent.error_title == null);
    assert(api.remove_calls == 3);
}

public static int main(string[] args) {
    Environment.set_variable("TZ", "Europe/London", true);
    Test.init(ref args);

    Test.add_func("/milestones-controller/clock-ranges-defaults", test_clock_drives_now_ranges_and_form_defaults);
    Test.add_func("/milestones-controller/serials", test_serials_track_the_latest_refresh);
    Test.add_func("/milestones-controller/refresh-loads", test_refresh_flow_loads_the_calendar);
    Test.add_func("/milestones-controller/refresh-fails", test_refresh_flow_reports_failure);
    Test.add_func("/milestones-controller/refresh-stale", test_refresh_flow_drops_results_superseded_while_in_flight);
    Test.add_func("/milestones-controller/add", test_add_flow);
    Test.add_func("/milestones-controller/update", test_update_flow);
    Test.add_func("/milestones-controller/remove", test_remove_flow);

    return Test.run();
}

}
