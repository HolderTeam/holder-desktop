using GLib;

namespace HolderLinuxTests {

private string join_parts(string separator, Gee.List<string> parts) {
    var joined = new StringBuilder();
    bool first = true;
    foreach (var part in parts) {
        if (!first) {
            joined.append(separator);
        }
        joined.append(part);
        first = false;
    }
    return joined.str;
}

private class RecordingLauncher : Object, HolderLinux.IUriLauncher {
    public Gee.ArrayList<string> launched = new Gee.ArrayList<string>();
    public string? error = null;

    public void launch(string uri) throws Error {
        if (error != null) {
            throw new IOError.FAILED((!) error);
        }
        launched.add(uri);
    }
}

private delegate void WaitHook(int wait_number);

private class CountingScheduler : Object, HolderLinux.IScheduler {
    public int waits = 0;
    public uint last_delay_ms = 0;
    public WaitHook? on_wait = null;

    public uint schedule_once(uint delay_ms, owned SourceFunc callback) {
        waits++;
        last_delay_ms = delay_ms;
        if (on_wait != null) {
            on_wait(waits);
        }
        Idle.add(() => {
            callback();
            return Source.REMOVE;
        });
        return (uint) waits;
    }

    public uint schedule_repeating(uint interval_ms, owned SourceFunc callback) {
        return 0;
    }

    public bool cancel(uint source_id) {
        return true;
    }
}

private class DriveFixture : Object {
    public FakeStorageLocationApi api = new FakeStorageLocationApi();
    public RecordingLauncher launcher = new RecordingLauncher();
    public CountingScheduler scheduler = new CountingScheduler();
    public string? preferred = null;
    public Gee.ArrayList<string> statuses = new Gee.ArrayList<string>();
    public HolderLinux.GoogleDriveConnectFlow flow;

    public DriveFixture() {
        flow = new HolderLinux.GoogleDriveConnectFlow(api, launcher, scheduler, () => { return preferred; });
        flow.status_changed.connect((text) => { statuses.add(text); });
    }

    public HolderLinux.GoogleDriveConnectResult run() {
        HolderLinux.GoogleDriveConnectResult? result = null;
        flow.run.begin("p1", (obj, res) => { result = flow.run.end(res); });
        assert(wait_for_condition(() => result != null, 10000));
        return (!) result;
    }
}

private void test_find_unbound_google_drive_location_id_ignores_other_providers_and_bound_ones() {
    var locations = make_location_list({
        make_location("s3-1", "s3_compatible", false),
        make_location("drive-bound", "google-drive", true),
        make_location("drive-unbound", "google-drive", false),
        make_location("drive-unbound-2", "google-drive", false)
    });
    assert(HolderLinux.GoogleDriveConnectFlow.find_unbound_google_drive_location_id(locations) == "drive-unbound");
}

private void test_find_unbound_google_drive_location_id_returns_null_when_none_match() {
    var locations = make_location_list({
        make_location("s3-1", "s3_compatible", false),
        make_location("drive-bound", "google-drive", true)
    });
    assert(HolderLinux.GoogleDriveConnectFlow.find_unbound_google_drive_location_id(locations) == null);
}

private void test_location_is_bound_matches_by_id() {
    var locations = make_location_list({
        make_location("drive-1", "google-drive", true),
        make_location("drive-2", "google-drive", false)
    });
    assert(HolderLinux.GoogleDriveConnectFlow.location_is_bound(locations, "drive-1"));
    assert(!HolderLinux.GoogleDriveConnectFlow.location_is_bound(locations, "drive-2"));
    assert(!HolderLinux.GoogleDriveConnectFlow.location_is_bound(locations, "no-such-id"));
}

private void test_connects_by_reusing_an_unbound_location_and_polling_until_bound() {
    var fixture = new DriveFixture();
    fixture.api.list_responses.add(make_location_list({ make_location("d1", "google-drive", false) }));
    fixture.api.list_responses.add(make_location_list({ make_location("d1", "google-drive", false) }));
    fixture.api.list_responses.add(make_location_list({ make_location("d1", "google-drive", true) }));

    var result = fixture.run();

    assert(result.outcome == HolderLinux.GoogleDriveConnectOutcome.CONNECTED);
    assert(result.toast_message == "Google Drive connected.");
    assert(fixture.api.last_oauth_location == "d1");
    assert(join_parts(",", fixture.api.calls) == "list,oauth,list,list,prefer:d1");
    assert(fixture.launcher.launched.size == 1);
    assert(fixture.launcher.launched[0] == "https://auth.example/consent");
    assert(fixture.scheduler.waits == 2);
    assert(fixture.scheduler.last_delay_ms == HolderLinux.GoogleDriveConnectFlow.POLL_INTERVAL_MS);
    assert(fixture.statuses.size == 2);
    assert(fixture.statuses[0] == "Opening your browser…");
    assert(fixture.statuses[1] == "Waiting for you to finish in your browser…");
}

private void test_creates_a_location_when_none_is_unbound_and_keeps_existing_preference() {
    var fixture = new DriveFixture();
    fixture.preferred = "already-preferred";
    fixture.api.list_responses.add(make_location_list({ make_location("d0", "google-drive", true) }));
    fixture.api.list_responses.add(make_location_list({
        make_location("new-location", "google-drive", true)
    }));

    var result = fixture.run();

    assert(result.outcome == HolderLinux.GoogleDriveConnectOutcome.CONNECTED);
    assert(fixture.api.last_created_name == "Google Drive");
    assert(fixture.api.last_created_provider == "google-drive");
    assert(fixture.api.last_configuration.size == 0);
    assert(fixture.api.last_oauth_location == "new-location");
    assert(join_parts(",", fixture.api.calls) == "list,create,oauth,list");
}

private void test_times_out_after_the_maximum_number_of_polls() {
    var fixture = new DriveFixture();
    fixture.api.list_responses.add(make_location_list({ make_location("d1", "google-drive", false) }));

    var result = fixture.run();

    assert(result.outcome == HolderLinux.GoogleDriveConnectOutcome.TIMED_OUT);
    assert(result.error_title == "Google Drive connection timed out");
    assert(result.error_details == "Try connecting again from the Resources tool.");
    assert(fixture.scheduler.waits == HolderLinux.GoogleDriveConnectFlow.MAX_POLL_ATTEMPTS);
    assert(fixture.api.list_calls == HolderLinux.GoogleDriveConnectFlow.MAX_POLL_ATTEMPTS + 1);
}

private void test_cancelling_while_preparing_stops_before_the_browser_opens() {
    var fixture = new DriveFixture();
    fixture.api.on_call = (call) => {
        if (call == "list") {
            fixture.flow.cancel();
        }
    };

    var result = fixture.run();

    assert(result.outcome == HolderLinux.GoogleDriveConnectOutcome.CANCELLED);
    assert(fixture.api.calls.contains("create"));
    assert(!fixture.api.calls.contains("oauth"));
    assert(fixture.statuses.size == 0);
}

private void test_cancelling_while_requesting_authorisation_does_not_launch_the_browser() {
    var fixture = new DriveFixture();
    fixture.api.on_call = (call) => {
        if (call == "oauth") {
            fixture.flow.cancel();
        }
    };

    var result = fixture.run();

    assert(result.outcome == HolderLinux.GoogleDriveConnectOutcome.CANCELLED);
    assert(fixture.launcher.launched.size == 0);
}

private void test_cancelling_during_a_poll_wait_stops_polling() {
    var fixture = new DriveFixture();
    fixture.scheduler.on_wait = (wait_number) => {
        if (wait_number == 2) {
            fixture.flow.cancel();
        }
    };

    var result = fixture.run();

    assert(result.outcome == HolderLinux.GoogleDriveConnectOutcome.CANCELLED);
    assert(fixture.scheduler.waits == 2);
    assert(fixture.api.list_calls == 2);
}

private void test_cancelling_during_the_last_poll_request_is_reported_as_cancelled() {
    var fixture = new DriveFixture();
    fixture.api.on_call = (call) => {
        if (call == "list" && fixture.api.list_calls == 2) {
            fixture.flow.cancel();
        }
    };

    var result = fixture.run();

    assert(result.outcome == HolderLinux.GoogleDriveConnectOutcome.CANCELLED);
    assert(fixture.scheduler.waits == 1);
}

private void test_failures_are_reported_unless_the_flow_was_cancelled() {
    var listing = new DriveFixture();
    listing.api.list_error = "offline";
    var listing_result = listing.run();
    assert(listing_result.outcome == HolderLinux.GoogleDriveConnectOutcome.FAILED);
    assert(listing_result.error_title == "Failed to connect Google Drive");
    assert(listing_result.error_details == "offline");

    var launching = new DriveFixture();
    launching.launcher.error = "no browser";
    var launching_result = launching.run();
    assert(launching_result.outcome == HolderLinux.GoogleDriveConnectOutcome.FAILED);
    assert(launching_result.error_details == "no browser");

    var cancelled = new DriveFixture();
    cancelled.api.oauth_error = "oauth broke";
    cancelled.api.on_call = (call) => {
        if (call == "oauth") {
            cancelled.flow.cancel();
        }
    };
    assert(cancelled.run().outcome == HolderLinux.GoogleDriveConnectOutcome.CANCELLED);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/google-drive/find-unbound/ignores-other-providers-and-bound",
                  test_find_unbound_google_drive_location_id_ignores_other_providers_and_bound_ones);
    Test.add_func("/holder/google-drive/find-unbound/returns-null-when-none-match",
                  test_find_unbound_google_drive_location_id_returns_null_when_none_match);
    Test.add_func("/holder/google-drive/location-is-bound", test_location_is_bound_matches_by_id);
    Test.add_func("/holder/google-drive/connects-and-polls", test_connects_by_reusing_an_unbound_location_and_polling_until_bound);
    Test.add_func("/holder/google-drive/creates-location-and-keeps-preference",
                  test_creates_a_location_when_none_is_unbound_and_keeps_existing_preference);
    Test.add_func("/holder/google-drive/times-out", test_times_out_after_the_maximum_number_of_polls);
    Test.add_func("/holder/google-drive/cancel-while-preparing",
                  test_cancelling_while_preparing_stops_before_the_browser_opens);
    Test.add_func("/holder/google-drive/cancel-while-requesting-auth",
                  test_cancelling_while_requesting_authorisation_does_not_launch_the_browser);
    Test.add_func("/holder/google-drive/cancel-during-wait", test_cancelling_during_a_poll_wait_stops_polling);
    Test.add_func("/holder/google-drive/cancel-during-last-poll",
                  test_cancelling_during_the_last_poll_request_is_reported_as_cancelled);
    Test.add_func("/holder/google-drive/failures", test_failures_are_reported_unless_the_flow_was_cancelled);
    return Test.run();
}

}
