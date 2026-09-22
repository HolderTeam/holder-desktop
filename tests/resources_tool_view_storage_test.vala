using GLib;

namespace HolderLinuxTests {

private const string RVS_EMPTY_TEXT = "No storage location configured for this project.";

private Gtk.Label? rvs_find_label(Gtk.Widget root, string text) {
    foreach (var widget in rv_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label != null && ((!) label).get_text() == text) {
            return label;
        }
    }
    return null;
}

private int rvs_count_labels(Gtk.Widget root, string text) {
    int count = 0;
    foreach (var widget in rv_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label != null && ((!) label).get_text() == text) {
            count++;
        }
    }
    return count;
}

private int rvs_count_buttons(Gtk.Widget root, string label) {
    int count = 0;
    foreach (var widget in rv_descendants(root)) {
        var button = widget as Gtk.Button;
        if (button != null && ((!) button).get_label() == label) {
            count++;
        }
    }
    return count;
}

// Storage rows are built when a refresh completes; the location list is refreshed after the
// responses are queued on the fake, so a follow-up request_refresh() picks them up.
private ResourcesViewHarness rvs_harness_with_locations(HolderLinux.StorageLocationList list,
                                                        string? wait_for_text = null) {
    var h = new ResourcesViewHarness();
    h.api.storage.list_responses.add(list);
    h.view.request_refresh();
    assert(wait_for_condition(() => rvs_find_label(h.view.widget, wait_for_text ?? "Local") != null));
    return h;
}

private HolderLinux.StorageLocationList rvs_three_locations() {
    return make_location_list({
        make_location("l1", "local_directory", true, "/data", "Local"),
        make_location("l2", "google-drive", false, null, "Drive"),
        make_location("l3", "s3_compatible", true, "s3.example / bucket", "Bucket")
    }, "l1");
}

private void rvs_clear_calls(ResourcesViewHarness h) {
    h.api.storage.calls.clear();
}

private string rvs_mutating_calls(ResourcesViewHarness h) {
    var kept = new StringBuilder();
    foreach (var call in h.api.storage.calls) {
        if (call == "list") {
            continue;
        }
        if (kept.len > 0) {
            kept.append_c(',');
        }
        kept.append(call);
    }
    return kept.str;
}

private Adw.AlertDialog rvs_open_dialog(ResourcesViewHarness h, string button_label) {
    rv_button(h.view.widget, button_label).clicked();
    assert(h.wait_for_dialog());
    return (!) h.dialog();
}

private Gtk.Widget rvs_content(Adw.AlertDialog dialog) {
    var content = dialog.get_extra_child();
    assert(content != null);
    return (!) content;
}

private void rvs_press(Adw.AlertDialog dialog, string button_label) {
    rv_button(dialog, button_label).clicked();
}

// ---- storage location list --------------------------------------------------------------------

private void test_locations_show_the_empty_state_when_none_are_configured() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());

    var label = rvs_find_label(h.view.widget, RVS_EMPTY_TEXT);
    assert(label != null);
    assert(((!) label).get_visible());
}

private void test_locations_without_a_project_skip_the_api() {
    var h = new ResourcesViewHarness(false);

    var label = rvs_find_label(h.view.widget, RVS_EMPTY_TEXT);
    assert(label != null);
    assert(((!) label).get_visible());
    assert(h.api.storage.list_calls == 0);
}

private void test_locations_load_failure_shows_the_failed_text_and_reports_it() {
    var h = new ResourcesViewHarness();
    h.api.storage.list_error = "nope";
    h.view.request_refresh();

    assert(wait_for_condition(() => h.errors.contains("Storage Locations refresh failed|nope")));
    var label = rvs_find_label(h.view.widget, "Failed to load storage locations.");
    assert(label != null);
    assert(((!) label).get_visible());
}

private void test_location_rows_show_summaries_the_preferred_badge_and_actions() {
    var h = rvs_harness_with_locations(rvs_three_locations());
    var root = h.view.widget;

    assert(rvs_find_label(root, "Local folder · /data") != null);
    assert(rvs_find_label(root, "Drive") != null);
    assert(rvs_find_label(root, "Google Drive · Configuration required") != null);
    assert(rvs_find_label(root, "Bucket") != null);
    assert(rvs_find_label(root, "S3-compatible storage · s3.example / bucket") != null);
    assert(rvs_count_labels(root, "Preferred") == 1);
    // Only a bound, non-preferred location can be made the default.
    assert(rvs_count_buttons(root, "Use by default") == 1);
    var tests = rv_buttons_with_tooltip(root, "Test storage location");
    assert(tests.size == 3);
    assert(tests[0].get_sensitive());
    assert(!tests[1].get_sensitive());
    assert(tests[2].get_sensitive());
    assert(rv_buttons_with_tooltip(root, "Delete storage location").size == 3);
    var empty = rvs_find_label(root, RVS_EMPTY_TEXT);
    assert(empty != null);
    assert(!((!) empty).get_visible());
}

private void test_use_by_default_prefers_the_location_and_refreshes() {
    var h = rvs_harness_with_locations(rvs_three_locations());
    rvs_clear_calls(h);
    var before = h.api.storage.list_calls;

    rv_button(h.view.widget, "Use by default").clicked();

    assert(wait_for_condition(() => h.api.storage.calls.contains("prefer:l3")));
    assert(h.wait_for_toast("Preferred storage location updated."));
    assert(wait_for_condition(() => h.api.storage.list_calls > before));
}

private void test_use_by_default_failure_is_reported() {
    var h = rvs_harness_with_locations(rvs_three_locations());
    h.api.storage.prefer_error = "read only";

    rv_button(h.view.widget, "Use by default").clicked();

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Failed to update preferred location|read only");
    assert(h.toasts.size == 0);
}

private void test_testing_a_location_reports_availability() {
    var h = rvs_harness_with_locations(rvs_three_locations());

    rv_tooltip_button(h.view.widget, "Test storage location", 0).clicked();

    assert(wait_for_condition(() => h.api.storage.calls.contains("test:l1")));
    assert(h.wait_for_toast("Storage location is available."));
}

private void test_testing_a_location_failure_is_reported() {
    var h = rvs_harness_with_locations(rvs_three_locations());
    h.api.storage.test_error = "unreachable";

    rv_tooltip_button(h.view.widget, "Test storage location", 2).clicked();

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.api.storage.calls.contains("test:l3"));
    assert(h.errors[0] == "Storage location test failed|unreachable");
}

private void test_deleting_a_location_removes_it_and_refreshes() {
    var h = rvs_harness_with_locations(rvs_three_locations());
    var before = h.api.storage.list_calls;

    rv_tooltip_button(h.view.widget, "Delete storage location", 2).clicked();

    assert(wait_for_condition(() => h.api.storage.calls.contains("delete:l3")));
    assert(h.wait_for_toast("Storage location removed."));
    assert(wait_for_condition(() => h.api.storage.list_calls > before));
}

private void test_deleting_a_location_failure_is_reported() {
    var h = rvs_harness_with_locations(rvs_three_locations());
    h.api.storage.delete_error = "in use";

    rv_tooltip_button(h.view.widget, "Delete storage location", 0).clicked();

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Failed to remove storage location|in use");
}

// ---- add location dialogs ---------------------------------------------------------------------

private void test_add_buttons_without_a_project_or_window_ask_to_connect_first() {
    var no_project = new ResourcesViewHarness(false);
    rv_button(no_project.view.widget, "Add Folder").clicked();
    rv_button(no_project.view.widget, "Add S3-compatible").clicked();
    rv_button(no_project.view.widget, "Add Google Drive").clicked();
    assert(no_project.toasts.size == 3);
    foreach (var toast in no_project.toasts) {
        assert(toast == "Select a project and connect to Holder first.");
    }
    assert(no_project.dialog() == null);

    var no_window = new ResourcesViewHarness(true, false);
    rv_button(no_window.view.widget, "Add Folder").clicked();
    assert(no_window.toasts.size == 1);
    assert(no_window.toasts[0] == "Select a project and connect to Holder first.");
}

private void test_folder_dialog_enables_add_only_with_a_name_and_a_path() {
    var h = new ResourcesViewHarness();
    var dialog = rvs_open_dialog(h, "Add Folder");
    var content = rvs_content(dialog);

    assert(dialog.get_heading() == "Add Storage Folder");
    assert(dialog.get_body() == "The folder path stays private to this device.");
    assert(!dialog.get_response_enabled("save"));
    var name = rv_entry(content, "Assets on this computer");
    var path = rv_entry(content, "/path/to/assets");
    assert(rv_button_labeled(content, "Choose…") != null);

    name.set_text("Photos");
    assert(!dialog.get_response_enabled("save"));
    path.set_text("/srv/photos");
    assert(dialog.get_response_enabled("save"));
    name.set_text("   ");
    assert(!dialog.get_response_enabled("save"));
}

private void test_saving_the_folder_dialog_creates_binds_and_prefers_the_first_location() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());
    var dialog = rvs_open_dialog(h, "Add Folder");
    var content = rvs_content(dialog);
    rv_entry(content, "Assets on this computer").set_text("  Photos ");
    rv_entry(content, "/path/to/assets").set_text(" /srv/photos ");
    rvs_clear_calls(h);
    var before = h.api.storage.list_calls;

    rvs_press(dialog, "Add");

    assert(wait_for_condition(() => rvs_mutating_calls(h) == "create,bind,prefer:new-location"));
    assert(h.api.storage.last_created_name == "Photos");
    assert(h.api.storage.last_created_provider == "local_directory");
    assert(h.api.storage.last_configuration.size == 0);
    assert(h.api.storage.last_bound_location == "new-location");
    assert(h.api.storage.last_bound_values.get("root_path") == "/srv/photos");
    assert(h.api.storage.last_bound_preview == "/srv/photos");
    assert(h.wait_for_toast("Storage location added."));
    assert(wait_for_condition(() => h.api.storage.list_calls > before));
}

private void test_saving_the_folder_dialog_keeps_an_existing_preferred_location() {
    var existing = make_location_list({
        make_location("l0", "local_directory", true, "/existing", "Existing")
    }, "l0");
    var h = rvs_harness_with_locations(existing, "Existing");
    var dialog = rvs_open_dialog(h, "Add Folder");
    var content = rvs_content(dialog);
    rv_entry(content, "Assets on this computer").set_text("Second");
    rv_entry(content, "/path/to/assets").set_text("/srv/second");
    rvs_clear_calls(h);

    rvs_press(dialog, "Add");

    assert(wait_for_condition(() => rvs_mutating_calls(h) == "create,bind"));
    assert(h.wait_for_toast("Storage location added."));
}

private void test_saving_an_invalid_folder_dialog_reports_what_is_missing() {
    var h = new ResourcesViewHarness();
    var dialog = rvs_open_dialog(h, "Add Folder");
    rvs_clear_calls(h);

    dialog.response("save");
    assert(h.toasts.size == 1);
    assert(h.toasts[0] == "A storage location name is required.");

    rv_entry(rvs_content(dialog), "Assets on this computer").set_text("Named");
    dialog.response("save");
    assert(h.toasts.size == 2);
    assert(h.toasts[1] == "Choose a storage folder.");
    assert(rvs_mutating_calls(h) == "");
}

private void test_cancelling_the_folder_dialog_makes_no_api_call() {
    var h = new ResourcesViewHarness();
    var dialog = rvs_open_dialog(h, "Add Folder");
    rv_entry(rvs_content(dialog), "Assets on this computer").set_text("Photos");
    rvs_clear_calls(h);

    rvs_press(dialog, "Cancel");

    h.settle();
    assert(rvs_mutating_calls(h) == "");
    assert(h.toasts.size == 0);
}

private void test_adding_a_location_failure_is_reported() {
    var h = new ResourcesViewHarness();
    h.api.storage.create_error = "denied";
    var dialog = rvs_open_dialog(h, "Add Folder");
    var content = rvs_content(dialog);
    rv_entry(content, "Assets on this computer").set_text("Photos");
    rv_entry(content, "/path/to/assets").set_text("/srv/photos");

    rvs_press(dialog, "Add");

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Failed to add storage location|denied");
    assert(h.toasts.size == 0);
}

private void test_s3_dialog_requires_endpoint_region_bucket_and_credentials() {
    var h = new ResourcesViewHarness();
    var dialog = rvs_open_dialog(h, "Add S3-compatible");
    var content = rvs_content(dialog);

    assert(dialog.get_heading() == "Add S3-compatible Storage");
    assert(!dialog.get_response_enabled("save"));
    rv_entry(content, "Family Assets").set_text("Family");
    rv_entry(content, "https://s3.example.com").set_text("https://s3.example.com");
    rv_entry(content, "us-east-1").set_text("us-east-1");
    rv_entry(content, "holder-family-assets").set_text("family");
    rv_entry(content, "Access key ID").set_text("AKIA");
    assert(!dialog.get_response_enabled("save"));
    rv_entry(content, "Secret access key").set_text("shh");
    assert(dialog.get_response_enabled("save"));

    dialog.response("save");
    rv_entry(content, "https://s3.example.com").set_text("");
    dialog.response("save");
    assert(h.toasts.contains("Endpoint, region, bucket and credentials are required."));
}

private void test_saving_the_s3_dialog_sends_configuration_and_credentials() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());
    var dialog = rvs_open_dialog(h, "Add S3-compatible");
    var content = rvs_content(dialog);
    rv_entry(content, "Family Assets").set_text("Family");
    rv_entry(content, "https://s3.example.com").set_text(" https://s3.example.com ");
    rv_entry(content, "us-east-1").set_text("us-east-1");
    rv_entry(content, "holder-family-assets").set_text("family");
    rv_entry(content, "optional/prefix").set_text("photos/");
    rv_entry(content, "Access key ID").set_text("AKIA");
    rv_entry(content, "Secret access key").set_text("shh");
    rv_entry(content, "Session token (optional)").set_text("tok");
    rvs_clear_calls(h);

    rvs_press(dialog, "Add");

    assert(wait_for_condition(() => rvs_mutating_calls(h) == "create,bind,prefer:new-location"));
    assert(h.api.storage.last_created_provider == "s3_compatible");
    var configuration = h.api.storage.last_configuration;
    assert(configuration.get("endpoint") == "https://s3.example.com");
    assert(configuration.get("region") == "us-east-1");
    assert(configuration.get("bucket") == "family");
    assert(configuration.get("prefix") == "photos/");
    assert(configuration.get("addressing_style") == "path");
    var values = h.api.storage.last_bound_values;
    assert(values.get("access_key_id") == "AKIA");
    assert(values.get("secret_access_key") == "shh");
    assert(values.get("session_token") == "tok");
    assert(h.api.storage.last_bound_preview == "https://s3.example.com / family");
    assert(h.wait_for_toast("Storage location added."));
}

private void test_s3_session_token_is_optional() {
    var h = new ResourcesViewHarness();
    var dialog = rvs_open_dialog(h, "Add S3-compatible");
    var content = rvs_content(dialog);
    rv_entry(content, "Family Assets").set_text("Family");
    rv_entry(content, "https://s3.example.com").set_text("https://s3.example.com");
    rv_entry(content, "us-east-1").set_text("us-east-1");
    rv_entry(content, "holder-family-assets").set_text("family");
    rv_entry(content, "Access key ID").set_text("AKIA");
    rv_entry(content, "Secret access key").set_text("shh");

    rvs_press(dialog, "Add");

    assert(wait_for_condition(() => h.api.storage.last_bound_values != null));
    assert(!h.api.storage.last_bound_values.has_key("session_token"));
}

// ---- Google Drive dialog ----------------------------------------------------------------------

private void test_drive_connect_failure_closes_the_dialog_and_reports_it() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());
    h.api.storage.oauth_error = "oauth down";
    rvs_clear_calls(h);

    rv_button(h.view.widget, "Add Google Drive").clicked();

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Failed to connect Google Drive|oauth down");
    assert(rvs_mutating_calls(h) == "create,oauth");
    h.settle();
    assert(h.toasts.size == 0);
}

private void test_drive_connect_reuses_an_unbound_google_drive_location() {
    var pending = make_location_list({
        make_location("gd1", "google-drive", false, null, "Drive")
    });
    var h = rvs_harness_with_locations(pending, "Drive");
    h.api.storage.oauth_error = "oauth down";
    rvs_clear_calls(h);

    rv_button(h.view.widget, "Add Google Drive").clicked();

    assert(wait_for_condition(() => h.errors.size == 1));
    // No "create" call: the existing unbound Drive location was reused for the OAuth attempt.
    assert(rvs_mutating_calls(h) == "oauth");
}

private void test_cancelling_the_drive_dialog_stops_the_flow_before_the_browser_opens() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());
    rvs_clear_calls(h);
    h.api.stall_next_list = true;

    rv_button(h.view.widget, "Add Google Drive").clicked();
    assert(h.wait_for_dialog());
    assert(h.api.has_stalled_list());
    var dialog = (!) h.dialog();
    assert(dialog.get_heading() == "Connect Google Drive");
    assert(rvs_find_label(rvs_content(dialog), "Preparing…") != null);

    rvs_press(dialog, "Cancel");
    h.settle();
    h.api.release_stalled_list();
    // A coroutine resumed from outside completes its caller from an idle callback, so pump the
    // main loop until the flow has continued and the view has handled the cancelled result.
    assert(wait_for_condition(() => h.api.storage.calls.contains("create")));
    wait_for_condition(() => false, 100);

    // The flow resumed (it got as far as creating the Location) and stopped at the cancel
    // checkpoint before asking for the OAuth URL: no OAuth call, nothing reported.
    assert(h.api.storage.calls.contains("create"));
    assert(!h.api.storage.calls.contains("oauth"));
    assert(h.errors.size == 0);
    assert(h.toasts.size == 0);
}

private void test_location_actions_are_ignored_once_the_api_has_no_storage_support() {
    var h = rvs_harness_with_locations(rvs_three_locations());
    // Keep a row's button alive across the refresh that removes the rows.
    var test_button = rv_tooltip_button(h.view.widget, "Test storage location", 0);
    var delete_button = rv_tooltip_button(h.view.widget, "Delete storage location", 0);
    var prefer_button = rv_button(h.view.widget, "Use by default");
    h.view.set_api_client(new MainControllerFakeApi());
    rvs_clear_calls(h);

    test_button.clicked();
    delete_button.clicked();
    prefer_button.clicked();
    assert(wait_for_condition(() => false, 100) == false);

    assert(rvs_mutating_calls(h) == "");
    assert(h.toasts.size == 0);
    assert(h.errors.size == 0);
}

// ---- Google Drive outcomes (fake browser launcher and scheduler) -------------------------------

private Gtk.Spinner? rvs_find_spinner(Gtk.Widget root) {
    foreach (var widget in rv_descendants(root)) {
        if (widget is Gtk.Spinner) {
            return (Gtk.Spinner) widget;
        }
    }
    return null;
}

// Queues what the Drive flow will see: first a list with nothing to reuse (so it creates a
// Location), then, for every poll after that, `polled`.
private void rvs_script_drive_lists(ResourcesViewHarness h, HolderLinux.StorageLocationList first,
                                    HolderLinux.StorageLocationList polled) {
    h.api.storage.list_calls = 0;
    h.api.storage.list_responses.clear();
    h.api.storage.list_responses.add(first);
    h.api.storage.list_responses.add(polled);
    rvs_clear_calls(h);
}

private bool rvs_wait_for_drive_poll(ResourcesViewHarness h) {
    return wait_for_condition(
        () => h.scheduler.pending_with_delay(HolderLinux.GoogleDriveConnectFlow.POLL_INTERVAL_MS) == 1
    );
}

private void test_drive_connect_opens_the_browser_then_reports_success_once_bound() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());
    rvs_script_drive_lists(h, make_location_list({}), make_location_list({
        make_location("new-location", "google-drive", true, null, "Drive")
    }));

    rv_button(h.view.widget, "Add Google Drive").clicked();
    assert(h.wait_for_dialog());
    var dialog = (!) h.dialog();
    assert(rvs_wait_for_drive_poll(h));

    // The flow got as far as the first poll: the browser was opened at the consent URL and the
    // dialog says it is waiting, with its spinner running.
    assert(h.launcher.launched.size == 1);
    assert(h.launcher.launched[0] == h.api.storage.oauth_url);
    assert(rvs_find_label(rvs_content(dialog), "Waiting for you to finish in your browser…") != null);
    var spinner = rvs_find_spinner(rvs_content(dialog));
    assert(spinner != null && ((!) spinner).spinning);
    assert(rvs_mutating_calls(h) == "create,oauth");
    assert(h.toasts.size == 0 && h.errors.size == 0);

    h.scheduler.run_due(HolderLinux.GoogleDriveConnectFlow.POLL_INTERVAL_MS);

    assert(h.wait_for_toast("Google Drive connected."));
    // Nothing was preferred yet, so the new Location becomes the project's default.
    assert(rvs_mutating_calls(h) == "create,oauth,prefer:new-location");
    assert(h.errors.size == 0);
    // The Locations list is reloaded so the new row shows up.
    assert(wait_for_condition(() => h.api.storage.list_calls >= 3));
}

private void test_drive_connect_keeps_an_existing_preferred_location() {
    var local = make_location("l1", "local_directory", true, "/data", "Local");
    var h = rvs_harness_with_locations(make_location_list({ local }, "l1"));
    rvs_script_drive_lists(h, make_location_list({ local }, "l1"), make_location_list({
        local, make_location("new-location", "google-drive", true, null, "Drive")
    }, "l1"));

    rv_button(h.view.widget, "Add Google Drive").clicked();
    assert(rvs_wait_for_drive_poll(h));
    h.scheduler.run_due(HolderLinux.GoogleDriveConnectFlow.POLL_INTERVAL_MS);

    assert(h.wait_for_toast("Google Drive connected."));
    assert(rvs_mutating_calls(h) == "create,oauth");
}

private void test_drive_connect_gives_up_after_the_polling_limit() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());
    rvs_script_drive_lists(h, make_location_list({}), make_location_list({
        make_location("new-location", "google-drive", false, null, "Drive")
    }));

    rv_button(h.view.widget, "Add Google Drive").clicked();
    assert(rvs_wait_for_drive_poll(h));
    assert(h.launcher.launched.size == 1);

    // One poll per interval; the flow stops exactly at the limit, no fake sleeping involved. A
    // coroutine resumed from a timer completes its caller from an idle callback, so let the main
    // loop run between ticks before the next poll is scheduled.
    for (int poll = 0; poll < HolderLinux.GoogleDriveConnectFlow.MAX_POLL_ATTEMPTS; poll++) {
        assert(h.errors.size == 0);
        assert(h.scheduler.run_due(HolderLinux.GoogleDriveConnectFlow.POLL_INTERVAL_MS) == 1);
        h.settle();
    }

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Google Drive connection timed out|Try connecting again from the Resources tool.");
    assert(h.toasts.size == 0);
    assert(h.scheduler.pending_one_shots() == 0);
    // The initial list plus one per poll, and never a "prefer": the Location never became bound.
    assert(h.api.storage.list_calls == 1 + HolderLinux.GoogleDriveConnectFlow.MAX_POLL_ATTEMPTS);
    assert(rvs_mutating_calls(h) == "create,oauth");
}

private void test_cancelling_the_drive_dialog_while_waiting_for_the_browser_stops_polling() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());
    rvs_script_drive_lists(h, make_location_list({}), make_location_list({
        make_location("new-location", "google-drive", true, null, "Drive")
    }));

    rv_button(h.view.widget, "Add Google Drive").clicked();
    assert(h.wait_for_dialog());
    var dialog = (!) h.dialog();
    assert(rvs_wait_for_drive_poll(h));
    assert(h.launcher.launched.size == 1);
    var lists_before = h.api.storage.list_calls;

    rvs_press(dialog, "Cancel");
    h.scheduler.run_due(HolderLinux.GoogleDriveConnectFlow.POLL_INTERVAL_MS);
    h.settle();

    // The flow woke up, saw the cancel and stopped: no further list, nothing bound or reported.
    assert(h.scheduler.pending_one_shots() == 0);
    assert(h.api.storage.list_calls == lists_before);
    assert(rvs_mutating_calls(h) == "create,oauth");
    assert(h.errors.size == 0);
    assert(h.toasts.size == 0);
}

private void test_drive_connect_reports_a_browser_that_cannot_be_opened() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());
    h.launcher.error = "no default browser";
    rvs_clear_calls(h);

    rv_button(h.view.widget, "Add Google Drive").clicked();

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Failed to connect Google Drive|no default browser");
    assert(rvs_mutating_calls(h) == "create,oauth");
    assert(h.launcher.launched.size == 0);
    assert(h.scheduler.pending_one_shots() == 0);
    assert(h.toasts.size == 0);
}

// ---- folder chooser (fake file picker) ---------------------------------------------------------

private Gtk.Entry rvs_open_folder_dialog_path(ResourcesViewHarness h) {
    var dialog = rvs_open_dialog(h, "Add Folder");
    var path = rv_entry(rvs_content(dialog), "/path/to/assets");
    assert(path.get_text() == "");
    return path;
}

private void test_choosing_a_folder_fills_the_path_entry() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());
    var path = rvs_open_folder_dialog_path(h);
    var folder = File.new_for_path(Path.build_filename(Environment.get_tmp_dir(), "holder-photos"));
    h.picker.choice = folder;

    rv_button(rvs_content((!) h.dialog()), "Choose…").clicked();

    assert(wait_for_condition(() => path.get_text() != ""));
    assert(path.get_text() == (!) folder.get_path());
    assert(h.picker.requests.size == 1);
    assert(h.picker.requests[0] == "folder|Choose Storage Folder");
    assert(h.errors.size == 0);
}

private void test_dismissing_the_folder_chooser_changes_nothing_and_says_nothing() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());
    var path = rvs_open_folder_dialog_path(h);
    path.set_text("/typed/by/hand");
    h.picker.cancel = true;

    rv_button(rvs_content((!) h.dialog()), "Choose…").clicked();
    h.settle();

    // The chooser was asked, and dismissing it (IOError.CANCELLED) is not an error.
    assert(h.picker.requests.size == 1);
    assert(path.get_text() == "/typed/by/hand");
    assert(h.errors.size == 0);
}

private void test_a_failing_folder_chooser_is_reported() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());
    var path = rvs_open_folder_dialog_path(h);
    h.picker.error = "portal unavailable";

    rv_button(rvs_content((!) h.dialog()), "Choose…").clicked();

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Failed to choose folder|portal unavailable");
    assert(path.get_text() == "");
}

private void test_a_folder_without_a_local_path_leaves_the_entry_alone() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());
    var path = rvs_open_folder_dialog_path(h);

    // Nothing chosen at all, then a location that has no local path (e.g. a remote share).
    rv_button(rvs_content((!) h.dialog()), "Choose…").clicked();
    h.settle();
    h.picker.choice = File.new_for_uri("https://files.example.test/folder");
    rv_button(rvs_content((!) h.dialog()), "Choose…").clicked();
    h.settle();

    assert(h.picker.requests.size == 2);
    assert(path.get_text() == "");
    assert(h.errors.size == 0);
}

// ---- stale storage location refreshes -----------------------------------------------------------

private void test_a_stale_locations_failure_does_not_clobber_the_newer_list() {
    var h = rvs_harness_with_locations(rvs_three_locations());
    // A slow refresh starts and stalls in the API, then a newer refresh completes first.
    h.api.stall_next_list = true;
    h.view.request_refresh();
    assert(h.api.has_stalled_list());
    h.view.request_refresh();
    assert(wait_for_condition(() => rvs_find_label(h.view.widget, "Local") != null));
    assert(rvs_find_label(h.view.widget, "Failed to load storage locations.") == null);
    var calls = h.api.storage.list_calls;
    var errors_before = h.errors.size;

    // The old request now fails. Nobody is waiting for it any more.
    h.api.storage.list_error = "old request failed";
    h.api.release_stalled_list();
    assert(wait_for_condition(() => h.api.storage.list_calls == calls + 1));
    wait_for_condition(() => false, 100);

    assert(h.errors.size == errors_before);
    assert(rvs_find_label(h.view.widget, "Failed to load storage locations.") == null);
    assert(rvs_find_label(h.view.widget, "Local") != null);
}

public void register_resources_view_storage_tests() {
    var prefix = "/holder/resources-view/storage/";
    Test.add_func(prefix + "list/empty", test_locations_show_the_empty_state_when_none_are_configured);
    Test.add_func(prefix + "list/no-project", test_locations_without_a_project_skip_the_api);
    Test.add_func(prefix + "list/failure", test_locations_load_failure_shows_the_failed_text_and_reports_it);
    Test.add_func(prefix + "list/rows", test_location_rows_show_summaries_the_preferred_badge_and_actions);
    Test.add_func(prefix + "list/stale-failure", test_a_stale_locations_failure_does_not_clobber_the_newer_list);
    Test.add_func(prefix + "actions/prefer", test_use_by_default_prefers_the_location_and_refreshes);
    Test.add_func(prefix + "actions/prefer-failure", test_use_by_default_failure_is_reported);
    Test.add_func(prefix + "actions/test", test_testing_a_location_reports_availability);
    Test.add_func(prefix + "actions/test-failure", test_testing_a_location_failure_is_reported);
    Test.add_func(prefix + "actions/delete", test_deleting_a_location_removes_it_and_refreshes);
    Test.add_func(prefix + "actions/delete-failure", test_deleting_a_location_failure_is_reported);
    Test.add_func(prefix + "actions/ignored-without-storage-api", test_location_actions_are_ignored_once_the_api_has_no_storage_support);
    Test.add_func(prefix + "add/no-project-or-window", test_add_buttons_without_a_project_or_window_ask_to_connect_first);
    Test.add_func(prefix + "folder/enablement", test_folder_dialog_enables_add_only_with_a_name_and_a_path);
    Test.add_func(prefix + "folder/save", test_saving_the_folder_dialog_creates_binds_and_prefers_the_first_location);
    Test.add_func(prefix + "folder/keeps-preferred", test_saving_the_folder_dialog_keeps_an_existing_preferred_location);
    Test.add_func(prefix + "folder/validation", test_saving_an_invalid_folder_dialog_reports_what_is_missing);
    Test.add_func(prefix + "folder/cancel", test_cancelling_the_folder_dialog_makes_no_api_call);
    Test.add_func(prefix + "folder/failure", test_adding_a_location_failure_is_reported);
    Test.add_func(prefix + "s3/enablement", test_s3_dialog_requires_endpoint_region_bucket_and_credentials);
    Test.add_func(prefix + "s3/save", test_saving_the_s3_dialog_sends_configuration_and_credentials);
    Test.add_func(prefix + "s3/optional-token", test_s3_session_token_is_optional);
    Test.add_func(prefix + "drive/failure", test_drive_connect_failure_closes_the_dialog_and_reports_it);
    Test.add_func(prefix + "drive/reuse", test_drive_connect_reuses_an_unbound_google_drive_location);
    Test.add_func(prefix + "drive/cancel", test_cancelling_the_drive_dialog_stops_the_flow_before_the_browser_opens);
    Test.add_func(prefix + "drive/connected", test_drive_connect_opens_the_browser_then_reports_success_once_bound);
    Test.add_func(prefix + "drive/keeps-preferred", test_drive_connect_keeps_an_existing_preferred_location);
    Test.add_func(prefix + "drive/timed-out", test_drive_connect_gives_up_after_the_polling_limit);
    Test.add_func(prefix + "drive/cancel-while-polling", test_cancelling_the_drive_dialog_while_waiting_for_the_browser_stops_polling);
    Test.add_func(prefix + "drive/browser-failure", test_drive_connect_reports_a_browser_that_cannot_be_opened);
    Test.add_func(prefix + "folder/choose", test_choosing_a_folder_fills_the_path_entry);
    Test.add_func(prefix + "folder/choose-dismissed", test_dismissing_the_folder_chooser_changes_nothing_and_says_nothing);
    Test.add_func(prefix + "folder/choose-failure", test_a_failing_folder_chooser_is_reported);
    Test.add_func(prefix + "folder/choose-no-path", test_a_folder_without_a_local_path_leaves_the_entry_alone);
}

}
