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

private class FakeImportApi : Object, HolderLinux.IResourceStorageApi {
    public string? preferred_location_id = "loc-1";
    public string? list_error = null;
    public string? start_error = null;
    public string? poll_error = null;
    public Gee.ArrayList<HolderLinux.AssetImportJob> polled_jobs = new Gee.ArrayList<HolderLinux.AssetImportJob>();
    public int list_calls { get; set; default = 0; }
    public int start_calls = 0;
    public int poll_calls = 0;
    public string? started_project = null;
    public string? started_card = null;
    public string? started_location = null;
    public string? started_source = null;

    public async HolderLinux.StorageLocationList list_storage_locations(string project_id) throws Error {
        list_calls++;
        if (list_error != null) {
            throw new IOError.FAILED((!) list_error);
        }
        return new HolderLinux.StorageLocationList(
            new Gee.ArrayList<HolderLinux.StorageLocation>(), preferred_location_id
        );
    }

    public async HolderLinux.AssetImportJob start_asset_import(string project_id, string card_id,
                                                               string location_id,
                                                               string source_path) throws Error {
        start_calls++;
        if (start_error != null) {
            throw new IOError.FAILED((!) start_error);
        }
        started_project = project_id;
        started_card = card_id;
        started_location = location_id;
        started_source = source_path;
        return new HolderLinux.AssetImportJob("job-1", "pending");
    }

    public async HolderLinux.AssetImportJob get_asset_import_job(string job_id) throws Error {
        poll_calls++;
        if (poll_error != null) {
            throw new IOError.FAILED((!) poll_error);
        }
        var index = int.min(poll_calls - 1, polled_jobs.size - 1);
        return polled_jobs[index];
    }

    public async string create_storage_location(string project_id, string name, string provider,
                                                Gee.HashMap<string, string> configuration) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void bind_storage_location(string location_id, Gee.HashMap<string, string> values,
                                            string preview) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void prefer_storage_location(string project_id, string location_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void test_storage_location(string location_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void delete_storage_location(string location_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async string start_google_drive_oauth(string location_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void download_asset(string resource_id, string asset_id, string destination_path) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
}

private class ImportFixture : Object {
    public FakeImportApi api = new FakeImportApi();
    public TestScheduler scheduler = new TestScheduler(true);
    public string? selected_project = "p1";
    public string? selected_card = "c1";
    public Gee.ArrayList<string> statuses = new Gee.ArrayList<string>();
    public HolderLinux.AssetImportFlow flow;

    public ImportFixture() {
        flow = new HolderLinux.AssetImportFlow(scheduler, (out project_id, out card_id) => {
            project_id = selected_project;
            card_id = selected_card;
        });
        flow.status_changed.connect((text) => { statuses.add(text); });
    }

    public HolderLinux.AssetImportResult run(string? basename = "photo.png",
                                             string? project_id = "p1",
                                             string? card_id = "c1",
                                             string? source_path = "/tmp/photo.png",
                                             bool with_api = true) {
        HolderLinux.AssetImportResult? result = null;
        flow.run.begin(with_api ? api : null, project_id, card_id, source_path, basename, (obj, res) => {
            result = flow.run.end(res);
        });
        assert(wait_for_condition(() => result != null, 10000));
        return (!) result;
    }

    public void queue_jobs(string[] statuses_to_return) {
        foreach (var status in statuses_to_return) {
            api.polled_jobs.add(new HolderLinux.AssetImportJob(
                "job-1", status, status == "completed" ? "r1" : null, status == "completed" ? "a1" : null,
                false, true, status == "failed" ? "boom" : null
            ));
        }
    }
}

private void test_missing_inputs_are_not_ready_and_make_no_calls() {
    var fixture = new ImportFixture();
    var no_api = fixture.run("photo.png", "p1", "c1", "/tmp/photo.png", false);
    assert(no_api.outcome == HolderLinux.AssetImportOutcome.NOT_READY);
    assert(no_api.toast_message == "Select a Card before dropping local files.");
    assert(fixture.run("photo.png", null, "c1").outcome == HolderLinux.AssetImportOutcome.NOT_READY);
    assert(fixture.run("photo.png", "p1", null).outcome == HolderLinux.AssetImportOutcome.NOT_READY);
    assert(fixture.run("photo.png", "p1", "c1", null).outcome == HolderLinux.AssetImportOutcome.NOT_READY);
    assert(fixture.api.list_calls == 0);
    assert(fixture.statuses.size == 0);
}

private void test_missing_preferred_location_asks_for_one() {
    var fixture = new ImportFixture();
    fixture.api.preferred_location_id = null;
    var result = fixture.run();
    assert(result.outcome == HolderLinux.AssetImportOutcome.NEEDS_LOCATION);
    assert(result.toast_message == "Add and choose a preferred Storage Location first.");
    assert(fixture.api.start_calls == 0);
    assert(fixture.statuses.size == 0);
}

private void test_completed_image_import_reports_status_and_insert_decision() {
    var fixture = new ImportFixture();
    fixture.queue_jobs({"running", "running", "completed"});
    var result = fixture.run();
    assert(result.outcome == HolderLinux.AssetImportOutcome.COMPLETED);
    assert(fixture.api.started_project == "p1");
    assert(fixture.api.started_card == "c1");
    assert(fixture.api.started_location == "loc-1");
    assert(fixture.api.started_source == "/tmp/photo.png");
    assert(fixture.api.poll_calls == 3);
    assert(fixture.scheduler.repeating_scheduled == 0);
    assert(join_parts("|", fixture.statuses)
        == "Importing photo.png…|Importing photo.png · running|Imported photo.png");
    assert(result.toast_message.has_prefix("Asset imported"));
    assert(result.still_selected);
    assert(result.insert_image_markdown);
    assert(result.image_filename == "photo.png");
    assert(((!) result.job).resource_id == "r1");
    assert(((!) result.job).asset_id == "a1");
}

private void test_completed_non_image_import_does_not_insert_markdown() {
    var fixture = new ImportFixture();
    fixture.queue_jobs({"completed"});
    var result = fixture.run("notes.txt", "p1", "c1", "/tmp/notes.txt");
    assert(result.outcome == HolderLinux.AssetImportOutcome.COMPLETED);
    assert(result.still_selected);
    assert(!result.insert_image_markdown);
    assert(result.image_filename == "notes.txt");
}

private void test_completed_import_after_selection_changed_skips_follow_up() {
    var fixture = new ImportFixture();
    fixture.queue_jobs({"completed"});
    fixture.selected_card = "c2";
    var moved_card = fixture.run();
    assert(moved_card.outcome == HolderLinux.AssetImportOutcome.COMPLETED);
    assert(!moved_card.still_selected);
    assert(!moved_card.insert_image_markdown);
    assert(moved_card.toast_message.has_prefix("Asset imported"));

    fixture.selected_project = null;
    fixture.selected_card = null;
    assert(!fixture.run().still_selected);
}

private void test_unnamed_file_falls_back_to_generic_labels() {
    var fixture = new ImportFixture();
    fixture.queue_jobs({"running", "completed"});
    var result = fixture.run(null);
    assert(result.outcome == HolderLinux.AssetImportOutcome.COMPLETED);
    assert(join_parts("|", fixture.statuses)
        == "Importing asset…|Importing asset · running|Imported asset");
    assert(result.image_filename == "image");
    assert(!result.insert_image_markdown);
}

private void test_duplicate_imports_use_the_matching_completion_message() {
    var fixture = new ImportFixture();
    fixture.api.polled_jobs.add(new HolderLinux.AssetImportJob("job-1", "completed", "r1", "a1", true, false));
    assert(fixture.run().toast_message.has_prefix("Already attached"));
    fixture.api.polled_jobs.clear();
    fixture.api.poll_calls = 0;
    fixture.api.polled_jobs.add(new HolderLinux.AssetImportJob("job-1", "completed", "r1", "a1", true, true));
    assert(fixture.run().toast_message.has_prefix("Existing Asset attached"));
}

private void test_completed_job_without_resource_id_is_a_failure() {
    var fixture = new ImportFixture();
    fixture.api.polled_jobs.add(new HolderLinux.AssetImportJob("job-1", "completed"));
    var result = fixture.run();
    assert(result.outcome == HolderLinux.AssetImportOutcome.FAILED);
    assert(result.error_title == "Failed to import Asset");
    assert(result.error_details == "Completed Asset import did not return a Resource ID");
}

private void test_failed_job_reports_its_error_or_a_default() {
    var fixture = new ImportFixture();
    fixture.queue_jobs({"failed"});
    var with_error = fixture.run();
    assert(with_error.outcome == HolderLinux.AssetImportOutcome.FAILED);
    assert(with_error.error_details == "boom");

    fixture.api.polled_jobs.clear();
    fixture.api.poll_calls = 0;
    fixture.api.polled_jobs.add(new HolderLinux.AssetImportJob("job-1", "failed"));
    assert(fixture.run().error_details == "Asset import failed");
}

private void test_api_errors_are_reported_as_failures() {
    var fixture = new ImportFixture();
    fixture.api.list_error = "list broke";
    var listing = fixture.run();
    assert(listing.outcome == HolderLinux.AssetImportOutcome.FAILED);
    assert(listing.error_title == "Failed to import Asset");
    assert(listing.error_details == "list broke");

    fixture.api.list_error = null;
    fixture.api.start_error = "start broke";
    assert(fixture.run().error_details == "start broke");

    fixture.api.start_error = null;
    fixture.api.poll_error = "poll broke";
    assert(fixture.run().error_details == "poll broke");
}

private void test_polling_gives_up_after_600_attempts_without_real_waiting() {
    var fixture = new ImportFixture();
    fixture.queue_jobs({"running"});
    var result = fixture.run();
    assert(result.outcome == HolderLinux.AssetImportOutcome.TIMED_OUT);
    assert(result.error_title == "Failed to import Asset");
    assert(result.error_details == "Asset import timed out");
    assert(fixture.api.poll_calls == HolderLinux.AssetImportFlow.MAX_POLL_ATTEMPTS);
    assert(fixture.api.poll_calls == 600);
    assert(fixture.statuses.size == 2);
}

private void test_is_still_selected_requires_both_ids_to_match() {
    assert(HolderLinux.AssetImportFlow.is_still_selected("p1", "c1", "p1", "c1"));
    assert(!HolderLinux.AssetImportFlow.is_still_selected("p2", "c1", "p1", "c1"));
    assert(!HolderLinux.AssetImportFlow.is_still_selected("p1", "c2", "p1", "c1"));
    assert(!HolderLinux.AssetImportFlow.is_still_selected(null, "c1", "p1", "c1"));
    assert(!HolderLinux.AssetImportFlow.is_still_selected("p1", null, "p1", "c1"));
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/asset-import-flow/missing-inputs", test_missing_inputs_are_not_ready_and_make_no_calls);
    Test.add_func("/asset-import-flow/needs-location", test_missing_preferred_location_asks_for_one);
    Test.add_func("/asset-import-flow/completed-image", test_completed_image_import_reports_status_and_insert_decision);
    Test.add_func("/asset-import-flow/completed-non-image", test_completed_non_image_import_does_not_insert_markdown);
    Test.add_func("/asset-import-flow/selection-changed", test_completed_import_after_selection_changed_skips_follow_up);
    Test.add_func("/asset-import-flow/unnamed-file", test_unnamed_file_falls_back_to_generic_labels);
    Test.add_func("/asset-import-flow/duplicate-messages", test_duplicate_imports_use_the_matching_completion_message);
    Test.add_func("/asset-import-flow/completed-without-resource", test_completed_job_without_resource_id_is_a_failure);
    Test.add_func("/asset-import-flow/failed-job", test_failed_job_reports_its_error_or_a_default);
    Test.add_func("/asset-import-flow/api-errors", test_api_errors_are_reported_as_failures);
    Test.add_func("/asset-import-flow/timeout", test_polling_gives_up_after_600_attempts_without_real_waiting);
    Test.add_func("/asset-import-flow/still-selected", test_is_still_selected_requires_both_ids_to_match);
    return Test.run();
}

}
