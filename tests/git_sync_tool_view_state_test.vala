using GLib;

namespace HolderLinuxTests {

private const string GSS_REMOTE = "git@github.com:HolderTeam/runbook.git";

private HolderLinux.ProjectSyncState gss_sync(int uncommitted = 0,
                                              int unpushed = 0,
                                              string push_status = "pushed",
                                              string error = "") {
    return new HolderLinux.ProjectSyncState(
        null, 100, 110, uncommitted, unpushed, push_status, "pulled", error
    );
}

// A configured project rendered from the selection alone (no API, so the backend cannot replace it).
private GitSyncViewHarness gss_offline(string remote, HolderLinux.ProjectSyncState? sync = null) {
    return new GitSyncViewHarness(remote, true, false, true, false, sync);
}

private void gss_test_no_project_shows_setup_and_guards_actions() {
    var h = new GitSyncViewHarness(null, false);
    assert(h.state_page() == "setup");
    assert(!h.setup_button("Cancel changes").get_visible());

    gsv_button(h.view.widget, "Sync now").clicked();
    assert(h.toasts.contains("Select a configured project first."));

    // Nothing is configured, so these are ignored without side effects.
    gsv_button(h.view.widget, "Change remote").clicked();
    gsv_button(h.view.widget, "Copy URL").clicked();
    gsv_button(h.view.widget, "Open repository").clicked();
    gsv_button(h.view.widget, "Disconnect…").clicked();
    assert(h.state_page() == "setup");
    assert(h.remote_entry().get_text() == "");
    assert(h.toasts.size == 1);
    assert(h.errors.size == 0);
    assert(h.dialog() == null);

    h.view.set_project_selection(null);
    assert(h.state_page() == "setup");
}

private void gss_test_configured_project_renders_the_presenter_output() {
    var h = gss_offline(GSS_REMOTE, gss_sync());
    assert(h.state_page() == "configured");
    assert(h.named_label("git-configured-project").get_text() == "Project: Runbook Project");
    assert(h.named_label("git-configured-repository").get_text() == "github.com/HolderTeam/runbook");
    assert(h.named_label("git-configured-remote").get_text() == GSS_REMOTE);
    var status = h.named_label("git-configured-status");
    assert(status.get_text() == "Up to date");
    assert(status.has_css_class("success"));
    assert(h.named_label("git-configured-detail").get_text().has_prefix("Last successful sync "));
    assert(gsv_button(h.view.widget, "Open repository").get_sensitive());
    assert(!h.setup_button("Cancel changes").get_visible());
}

private void gss_test_status_class_follows_the_sync_state() {
    var waiting = gss_offline(GSS_REMOTE, gss_sync(1, 2));
    var waiting_status = waiting.named_label("git-configured-status");
    assert(waiting_status.get_text() == "Changes waiting");
    assert(waiting_status.has_css_class("warning"));
    assert(!waiting_status.has_css_class("success"));
    var detail = waiting.named_label("git-configured-detail").get_text();
    assert(detail.contains("1 uncommitted change"));
    assert(detail.contains("2 commits waiting to push"));

    var failed = gss_offline(GSS_REMOTE, gss_sync(0, 0, "pushed", "remote rejected"));
    var failed_status = failed.named_label("git-configured-status");
    assert(failed_status.get_text() == "Needs attention");
    assert(failed_status.has_css_class("error"));
    assert(failed.named_label("git-configured-detail").get_text().has_suffix("\nremote rejected"));

    var fresh = gss_offline(GSS_REMOTE);
    var fresh_status = fresh.named_label("git-configured-status");
    assert(fresh_status.get_text() == "Ready to sync");
    assert(fresh_status.has_css_class("accent"));
    assert(fresh.named_label("git-configured-detail").get_text() == "No successful sync recorded yet");
}

private void gss_test_remote_without_a_web_address_cannot_be_opened() {
    var h = gss_offline("file:///srv/runbook.git", gss_sync());
    assert(h.state_page() == "configured");
    assert(h.named_label("git-configured-repository").get_text() == "file:///srv/runbook.git");
    var open = gsv_button(h.view.widget, "Open repository");
    assert(!open.get_sensitive());
    open.clicked();
    assert(h.errors.size == 0);
}

private void gss_test_backend_snapshot_replaces_the_selection_snapshot() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    assert(h.api.list_projects_calls > 0);
    // The fake backend reports two uncommitted changes, three unpushed commits and a sync error.
    assert(h.named_label("git-configured-status").get_text() == "Needs attention");
    var detail = h.named_label("git-configured-detail").get_text();
    assert(detail.contains("2 uncommitted changes"));
    assert(detail.contains("3 commits waiting to push"));
    assert(detail.contains("last sync failed"));
}

private void gss_test_failed_refresh_keeps_the_last_known_state() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    h.api.fail_list_projects_once = true;
    h.view.set_api_client(h.api);
    h.settle();
    // The one-shot failure was consumed, so the refresh really ran and hit the catch block.
    assert(!h.api.fail_list_projects_once);
    assert(h.state_page() == "configured");
    assert(h.named_label("git-configured-remote").get_text() == "https://example.com/p1.git");
    assert(h.errors.size == 0);
}

private void gss_test_backend_without_the_project_keeps_the_optimistic_state() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    var calls = h.api.list_projects_calls;
    h.api.list_projects_empty = true;
    h.view.set_api_client(h.api);
    h.settle();
    assert(h.api.list_projects_calls == calls + 1);
    assert(h.state_page() == "configured");
    assert(h.named_label("git-configured-remote").get_text() == "https://example.com/p1.git");
}

private void gss_test_a_stale_refresh_never_overwrites_a_newer_one() {
    var h = new GitSyncViewHarness("https://example.com/A.git");
    var remote = h.named_label("git-configured-remote");
    assert(remote.get_text() == "https://example.com/A.git");

    h.api.stall_next_list_projects = true;
    h.view.set_api_client(h.api);
    h.settle();
    assert(h.api.has_stalled_list());

    h.api.project_git_remote_url = "https://example.com/B.git";
    h.view.set_api_client(h.api);
    h.settle();
    assert(remote.get_text() == "https://example.com/B.git");

    // The stalled refresh resumes with the backend state it captured (remote A) and must be dropped.
    h.api.release_stalled_list();
    h.settle();
    assert(!h.api.has_stalled_list());
    assert(remote.get_text() == "https://example.com/B.git");
}

private void gss_test_switching_project_mid_refresh_drops_the_old_result() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    h.api.include_home_project = true;
    h.store.append(gsv_project("p-home", "Home", null));
    assert(h.state_page() == "configured");

    h.api.stall_next_list_projects = true;
    h.view.set_api_client(h.api);
    h.settle();
    assert(h.api.has_stalled_list());

    h.selection.set_selected(1);
    h.settle();
    assert(h.state_page() == "setup");

    h.api.release_stalled_list();
    h.settle();
    assert(!h.api.has_stalled_list());
    assert(h.state_page() == "setup");
}

private void gss_test_a_replaced_selection_model_drops_the_old_result() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    h.api.stall_next_list_projects = true;
    h.view.set_api_client(h.api);
    h.settle();
    assert(h.api.has_stalled_list());

    // Swapping the model keeps the selected position, so there is no selection change (and no new
    // refresh) unless GTK reports one: the "is it still the same project" check must reject the
    // old result either way.
    var other_store = new GLib.ListStore(typeof(HolderLinux.Project));
    other_store.append(gsv_project("other", "Other", null));
    h.selection.set_model(other_store);
    assert(((HolderLinux.Project) h.selection.get_selected_item()).project_id == "other");
    h.settle();
    var before = h.state_page();

    h.api.release_stalled_list();
    h.settle();
    assert(!h.api.has_stalled_list());
    assert(h.state_page() == before);
    assert(h.named_label("git-configured-project").get_text() == "Project: Runbook Project");
}

private void gss_test_change_remote_edits_in_place_and_cancel_restores() {
    var h = gss_offline(GSS_REMOTE, gss_sync());
    gsv_button(h.view.widget, "Change remote").clicked();

    assert(h.state_page() == "setup");
    assert(h.remote_entry().get_text() == GSS_REMOTE);
    assert(h.branch_entry().get_text() == "");
    assert(h.manual_status().get_text().has_prefix("Changing this updates Holder's remote"));
    assert(h.setup_button("Cancel changes").get_visible());

    // A backend refresh while editing must not yank the user back to the configured card.
    h.view.set_api_client(h.api);
    h.settle();
    assert(h.state_page() == "setup");

    h.setup_button("Cancel changes").clicked();
    assert(h.state_page() == "configured");
    assert(!h.setup_button("Cancel changes").get_visible());
}

private void gss_test_changing_project_leaves_edit_mode() {
    var h = gss_offline(GSS_REMOTE, gss_sync());
    h.store.append(gsv_project("p2", "Second", "git@github.com:HolderTeam/second.git", gss_sync()));
    gsv_button(h.view.widget, "Change remote").clicked();
    assert(h.state_page() == "setup");

    h.selection.set_selected(1);
    assert(h.state_page() == "configured");
    assert(h.named_label("git-configured-project").get_text() == "Project: Second");
    assert(h.named_label("git-configured-repository").get_text() == "github.com/HolderTeam/second");
}

private void gss_test_navigation_returns_to_the_start_page_and_leaves_edit_mode() {
    var h = gss_offline(GSS_REMOTE, gss_sync());
    h.main_stack().set_visible_child_name("provider");
    gsv_button(h.view.widget, "Change remote").clicked();
    assert(h.state_page() == "setup");

    h.view.navigate_to_project_root.begin("p1");
    assert(h.page() == "start");
    assert(h.state_page() == "configured");

    h.main_stack().set_visible_child_name("guided-part2");
    h.view.navigate_to_card.begin("c1");
    assert(h.page() == "start");

    h.main_stack().set_visible_child_name("guided-part3");
    h.view.navigate_to_projects_root.begin(null);
    assert(h.page() == "start");
}

private void gss_test_sync_now_reports_a_pushed_project() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    var sync = gsv_button(h.view.widget, "Sync now");
    sync.clicked();

    assert(h.wait_for_toast("Project synced."));
    h.settle();
    assert(h.api.push_project_git_calls == 1);
    assert(h.api.last_git_project_id == "p1");
    assert(h.api.last_git_branch == "");
    assert(h.histories.size == 1 && h.histories[0] == "p1");
    assert(h.errors.size == 0);
    assert(sync.get_sensitive());
}

private void gss_test_sync_now_reports_an_up_to_date_project() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    h.api.push_status = "up_to_date";
    gsv_button(h.view.widget, "Sync now").clicked();

    assert(h.wait_for_toast("Project is already up to date."));
    assert(h.api.push_project_git_calls == 1);
    assert(h.histories.size == 1);
    assert(h.errors.size == 0);
}

private void gss_test_sync_now_reports_a_rejected_push() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    h.api.push_status = "failed";
    h.api.push_error_message = "remote rejected";
    gsv_button(h.view.widget, "Sync now").clicked();

    assert(h.wait_for_error("Git sync failed|remote rejected"));
    h.settle();
    assert(h.api.push_project_git_calls == 1);
    assert(h.errors.size == 1);
    assert(h.toasts.size == 0);
    assert(h.histories.size == 0);
}

private void gss_test_sync_now_names_an_unknown_push_status() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    h.api.push_status = "conflict";
    gsv_button(h.view.widget, "Sync now").clicked();

    assert(h.wait_for_error("Git sync failed|Git sync returned: conflict"));
    assert(h.api.push_project_git_calls == 1);
    assert(h.errors.size == 1);
}

private void gss_test_sync_now_reports_an_api_failure_and_re_enables_the_button() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    h.api.fail_push_project_git = true;
    var sync = gsv_button(h.view.widget, "Sync now");
    sync.clicked();

    assert(h.wait_for_error("Git sync failed|push project git failed"));
    h.settle();
    assert(h.errors.size == 1);
    assert(h.named_label("git-configured-status").get_text() == "Needs attention");
    assert(h.histories.size == 0);
    assert(sync.get_sensitive());
}

private void gss_test_sync_now_shows_progress_while_the_push_is_in_flight() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    var sync = gsv_button(h.view.widget, "Sync now");
    h.api.stall_next_push = true;
    sync.clicked();

    assert(h.api.has_stalled_push());
    assert(!sync.get_sensitive());
    assert(h.named_label("git-configured-status").get_text() == "Syncing…");
    assert(h.toasts.size == 0);

    h.api.release_stalled_push();
    assert(h.wait_for_toast("Project synced."));
    h.settle();
    assert(sync.get_sensitive());
}

private void gss_test_sync_now_needs_an_api_client() {
    var h = gss_offline(GSS_REMOTE, gss_sync());
    var sync = gsv_button(h.view.widget, "Sync now");
    sync.clicked();

    assert(h.toasts.contains("Select a configured project first."));
    assert(h.api.push_project_git_calls == 0);
    assert(sync.get_sensitive());
}

private void gss_test_disconnect_asks_first_and_cancel_changes_nothing() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    gsv_button(h.view.widget, "Disconnect…").clicked();

    assert(h.wait_for_dialog());
    var dialog = (!) h.dialog();
    assert(dialog.get_heading() == "Disconnect Git sync?");
    // The dialog names the backend's current snapshot of the project (the fake calls it "Project 1").
    assert(dialog.get_body().contains("“Project 1”"));
    dialog.response("cancel");

    assert(h.api.set_project_git_remote_calls == 0);
    assert(h.state_page() == "configured");
    assert(h.toasts.size == 0);
}

private void gss_test_confirming_the_disconnect_clears_the_remote() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    var disconnect = gsv_button(h.view.widget, "Disconnect…");
    disconnect.clicked();
    assert(h.wait_for_dialog());
    ((!) h.dialog()).response("disconnect");

    assert(h.wait_for_toast("Git sync disconnected."));
    h.settle();
    assert(h.api.set_project_git_remote_calls == 1);
    assert(h.api.last_git_project_id == "p1");
    assert(h.api.last_git_remote_url == null);
    assert(h.state_page() == "setup");
    assert(h.remote_entry().get_text() == "");
    assert(h.branch_entry().get_text() == "");
    assert(h.manual_status().get_text() == "Git sync disconnected. The remote repository was not deleted.");
    assert(disconnect.get_sensitive());

    // Nothing is configured any more.
    gsv_button(h.view.widget, "Sync now").clicked();
    assert(h.toasts.contains("Select a configured project first."));
}

private void gss_test_a_failed_disconnect_is_reported_and_stays_configured() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    h.api.fail_set_project_git_remote = true;
    var disconnect = gsv_button(h.view.widget, "Disconnect…");
    disconnect.clicked();
    assert(h.wait_for_dialog());
    ((!) h.dialog()).response("disconnect");

    assert(h.wait_for_error("Could not disconnect Git sync|set project git remote failed"));
    h.settle();
    assert(h.errors.size == 1);
    assert(h.state_page() == "configured");
    assert(h.toasts.size == 0);
    assert(disconnect.get_sensitive());
}

private void gss_test_disconnect_without_an_api_client_does_nothing() {
    var h = gss_offline(GSS_REMOTE, gss_sync());
    gsv_button(h.view.widget, "Disconnect…").clicked();
    assert(h.wait_for_dialog());
    ((!) h.dialog()).response("disconnect");

    assert(h.api.set_project_git_remote_calls == 0);
    assert(h.state_page() == "configured");
    assert(h.toasts.size == 0);
    assert(h.errors.size == 0);
}

private void gss_test_disconnect_needs_the_view_inside_a_window() {
    var h = new GitSyncViewHarness("https://example.com/p1.git", true, true, false);
    assert(h.view.widget.get_root() == null);
    gsv_button(h.view.widget, "Disconnect…").clicked();

    assert(h.dialog() == null);
    assert(h.api.set_project_git_remote_calls == 0);
    assert(h.state_page() == "configured");
}

private void gss_test_a_local_disconnect_outlives_a_lagging_backend() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    gsv_button(h.view.widget, "Disconnect…").clicked();
    assert(h.wait_for_dialog());
    ((!) h.dialog()).response("disconnect");
    assert(h.wait_for_toast("Git sync disconnected."));
    h.settle();
    assert(h.state_page() == "setup");

    // The backend still reports the old remote: the local disconnect must win.
    h.api.project_git_remote_url = "https://example.com/p1.git";
    h.view.set_api_client(h.api);
    h.settle();
    assert(h.state_page() == "setup");

    // Once the backend agrees the project has no remote, the local flag is forgotten...
    h.api.project_git_remote_url = null;
    h.view.set_api_client(h.api);
    h.settle();
    assert(h.state_page() == "setup");

    // ...so a remote that appears later is shown again.
    h.api.project_git_remote_url = "https://example.com/new.git";
    h.view.set_api_client(h.api);
    h.settle();
    assert(h.state_page() == "configured");
    assert(h.named_label("git-configured-remote").get_text() == "https://example.com/new.git");
}

private void gss_test_view_shell_identity() {
    var h = new GitSyncViewHarness(null, false);
    assert(h.view.tool_id == "git");
    assert(h.view.tool_label == "Git Sync");
    assert(h.view.get_content_widget() == h.view.widget);
    assert(h.view.get_actions_widget() == null);
}

public void register_git_sync_view_state_tests() {
    var prefix = "/holder/git-sync-view/state/";
    Test.add_func(prefix + "no-project", gss_test_no_project_shows_setup_and_guards_actions);
    Test.add_func(prefix + "configured-presenter", gss_test_configured_project_renders_the_presenter_output);
    Test.add_func(prefix + "status-class", gss_test_status_class_follows_the_sync_state);
    Test.add_func(prefix + "non-web-remote", gss_test_remote_without_a_web_address_cannot_be_opened);
    Test.add_func(prefix + "backend-snapshot", gss_test_backend_snapshot_replaces_the_selection_snapshot);
    Test.add_func(prefix + "refresh-failure", gss_test_failed_refresh_keeps_the_last_known_state);
    Test.add_func(prefix + "project-missing-from-backend",
                  gss_test_backend_without_the_project_keeps_the_optimistic_state);
    Test.add_func(prefix + "stale-refresh", gss_test_a_stale_refresh_never_overwrites_a_newer_one);
    Test.add_func(prefix + "switch-project-mid-refresh", gss_test_switching_project_mid_refresh_drops_the_old_result);
    Test.add_func(prefix + "replaced-model-mid-refresh", gss_test_a_replaced_selection_model_drops_the_old_result);
    Test.add_func(prefix + "change-remote", gss_test_change_remote_edits_in_place_and_cancel_restores);
    Test.add_func(prefix + "change-project-leaves-edit", gss_test_changing_project_leaves_edit_mode);
    Test.add_func(prefix + "navigation", gss_test_navigation_returns_to_the_start_page_and_leaves_edit_mode);
    Test.add_func(prefix + "sync/pushed", gss_test_sync_now_reports_a_pushed_project);
    Test.add_func(prefix + "sync/up-to-date", gss_test_sync_now_reports_an_up_to_date_project);
    Test.add_func(prefix + "sync/rejected", gss_test_sync_now_reports_a_rejected_push);
    Test.add_func(prefix + "sync/unknown-status", gss_test_sync_now_names_an_unknown_push_status);
    Test.add_func(prefix + "sync/api-failure", gss_test_sync_now_reports_an_api_failure_and_re_enables_the_button);
    Test.add_func(prefix + "sync/in-flight", gss_test_sync_now_shows_progress_while_the_push_is_in_flight);
    Test.add_func(prefix + "sync/no-api", gss_test_sync_now_needs_an_api_client);
    Test.add_func(prefix + "disconnect/cancel", gss_test_disconnect_asks_first_and_cancel_changes_nothing);
    Test.add_func(prefix + "disconnect/confirm", gss_test_confirming_the_disconnect_clears_the_remote);
    Test.add_func(prefix + "disconnect/failure", gss_test_a_failed_disconnect_is_reported_and_stays_configured);
    Test.add_func(prefix + "disconnect/no-api", gss_test_disconnect_without_an_api_client_does_nothing);
    Test.add_func(prefix + "disconnect/no-window", gss_test_disconnect_needs_the_view_inside_a_window);
    Test.add_func(prefix + "disconnect/backend-lag", gss_test_a_local_disconnect_outlives_a_lagging_backend);
    Test.add_func(prefix + "shell-identity", gss_test_view_shell_identity);
}

}
