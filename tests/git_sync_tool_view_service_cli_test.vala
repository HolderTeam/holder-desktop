using GLib;

namespace HolderLinuxTests {

// These tests run the view against a GitSyncViewFakeService, so no gh/git/ssh process is started and
// nothing depends on POSIX shell scripts or a redirected HOME: they run on every platform. (The shim
// based tests in git_sync_tool_view_cli_test.vala cover the real service's subprocess handling.)
private const string GFC_AUTHENTICATED =
    "GitHub CLI authenticated as `octocat`. Use the automatic button above to create repo, set remote, and push.";
private const string GFC_UNAUTHENTICATED =
    "GitHub CLI detected, but not authenticated. Run `gh auth login` in a terminal to enable automation.";
private const string GFC_NOT_DETECTED = "GitHub CLI not detected";
private const string GFC_KEY_SETTING = "git-github-username";

private GitSyncViewHarness gfc_harness(string? remote = null, bool with_project = true, bool with_api = true) {
    return new GitSyncViewHarness(remote, with_project, with_api, true, false, null, true);
}

// A harness whose GitHub CLI check has finished.
private GitSyncViewHarness gfc_detected(bool with_project = true, bool with_api = true, Settings? settings = null) {
    var h = gfc_harness(null, with_project, with_api);
    h.view.set_settings(settings);
    h.settle();
    assert(h.fake().count("detect") == 1);
    return h;
}

private bool gfc_settings(out Settings? settings) {
    settings = null;
    var source = SettingsSchemaSource.get_default();
    if (source == null || ((!) source).lookup(HolderLinux.AppSettings.SCHEMA_ID, true) == null) {
        Test.skip("settings schema is not available");
        return false;
    }
    var created = new Settings(HolderLinux.AppSettings.SCHEMA_ID);
    created.reset(HolderLinux.AppSettings.KEY_GIT_GITHUB_USERNAME);
    settings = created;
    return true;
}

private Gtk.Button gfc_automatic(GitSyncViewHarness h) {
    return h.setup_button("Use GitHub CLI (Automatic)");
}

private Gtk.Button gfc_shortcut(GitSyncViewHarness h) {
    return h.setup_button("Use GitHub CLI (auto-fill username)");
}

// ---- detecting the GitHub CLI ----

private void gfc_test_an_authenticated_cli_unlocks_the_automatic_controls() {
    var h = gfc_detected();

    assert(h.cli_status().get_text() == GFC_AUTHENTICATED);
    assert(gfc_automatic(h).get_visible() && gfc_automatic(h).get_sensitive());
    assert(gfc_shortcut(h).get_visible() && gfc_shortcut(h).get_sensitive());
    assert(h.create_repo_cli_button().get_visible() && h.create_repo_cli_button().get_sensitive());
    assert(h.repo_mode().get_text() ==
           "Recommended on this device: create the private repository with GitHub CLI.");
    // The login becomes the guided username.
    assert(h.username_entry().get_text() == "octocat");
    assert(gsv_button(h.child_page("guided-part1"), "Next").get_sensitive());
}

private void gfc_test_the_detected_login_is_remembered() {
    Settings? maybe_settings;
    if (!gfc_settings(out maybe_settings)) return;
    var settings = (!) maybe_settings;
    gfc_detected(true, true, settings);

    assert(settings.get_string(GFC_KEY_SETTING) == "octocat");
}

private void gfc_test_an_unauthenticated_cli_is_reported_and_locked() {
    var h = gfc_harness();
    h.fake().cli_state = new HolderLinux.GitHubCliState(true, false, "", "You are not logged in.");
    h.view.set_settings(null);
    h.settle();

    assert(h.cli_status().get_text() == GFC_UNAUTHENTICATED);
    assert(gfc_automatic(h).get_visible());
    assert(!gfc_automatic(h).get_sensitive());
    assert(!gfc_shortcut(h).get_sensitive());
    assert(!h.create_repo_cli_button().get_sensitive());
    assert(h.username_entry().get_text() == "");
}

private void gfc_test_a_missing_cli_hides_the_automatic_controls() {
    var h = gfc_harness();
    h.fake().cli_state = new HolderLinux.GitHubCliState(false, false, "", "gh: not found");
    h.view.set_settings(null);
    h.settle();

    assert(h.cli_status().get_text().has_prefix(GFC_NOT_DETECTED));
    assert(!gfc_automatic(h).get_visible());
    assert(!gfc_shortcut(h).get_visible());
    assert(!h.create_repo_cli_button().get_visible());
}

private void gfc_test_a_slow_older_check_cannot_overwrite_a_newer_one() {
    var h = gfc_harness();
    var service = h.fake();
    // The first check answers "not authenticated" but is slow; a second one starts and answers
    // "authenticated" straight away, as at startup when the view checks once itself and again when
    // its settings arrive.
    service.stall_next_detect = true;
    service.cli_state = new HolderLinux.GitHubCliState(true, false, "", "");
    h.view.set_settings(null);
    assert(service.has_stalled_detect());
    service.cli_state = new HolderLinux.GitHubCliState(true, true, "octocat", "");
    h.view.set_settings(null);
    h.settle();
    assert(h.cli_status().get_text() == GFC_AUTHENTICATED);
    assert(gfc_automatic(h).get_sensitive());

    service.release_stalled_detect();
    h.settle();

    assert(h.cli_status().get_text() == GFC_AUTHENTICATED);
    assert(gfc_automatic(h).get_sensitive());
    assert(service.count("detect") == 2);
}

// ---- the automatic setup ----

private void gfc_test_automatic_setup_creates_the_repo_saves_the_remote_and_pushes() {
    var h = gfc_detected();
    h.api.stall_next_push = true;
    gfc_automatic(h).clicked();

    // The repository was created; the flow now waits on the backend push.
    assert(wait_for_condition(() => h.api.has_stalled_push(), 5000));
    assert(!gfc_automatic(h).get_sensitive());
    assert(!gfc_shortcut(h).get_sensitive());
    assert(h.cli_status().get_text() == "GitHub CLI: creating private repo `octocat/Runbook-Project`...");
    assert(h.fake().count("create octocat/Runbook-Project") == 1);

    h.api.release_stalled_push();
    assert(h.wait_for_toast("GitHub CLI sync setup completed."));
    h.settle();
    // The setup page is hidden now but returns after a disconnect, so it is back to its normal state
    // rather than showing the in-flight status with the buttons still disabled.
    assert(h.cli_status().get_text() == GFC_AUTHENTICATED);
    assert(gfc_automatic(h).get_sensitive() && gfc_shortcut(h).get_sensitive());
    assert(h.histories.size == 1 && h.histories[0] == "p1");
    assert(h.errors.size == 0);
    assert(h.api.last_git_remote_url == "git@github.com:octocat/Runbook-Project.git");
    assert(h.api.push_project_git_calls == 1);
    assert(h.page() == "start");
    assert(h.state_page() == "configured");
    assert(h.named_label("git-configured-remote").get_text() == "git@github.com:octocat/Runbook-Project.git");
}

private void gfc_test_the_setup_page_is_usable_again_after_a_successful_setup_is_disconnected() {
    var h = gfc_detected();
    gfc_automatic(h).clicked();
    assert(h.wait_for_toast("GitHub CLI sync setup completed."));
    h.settle();
    assert(h.state_page() == "configured");

    gsv_button(h.view.widget, "Disconnect…").clicked();
    assert(h.wait_for_dialog());
    ((!) h.dialog()).response("disconnect");
    assert(h.wait_for_toast("Git sync disconnected."));
    h.settle();

    assert(h.state_page() == "setup");
    assert(gfc_automatic(h).get_sensitive());
    assert(gfc_shortcut(h).get_sensitive());
    assert(h.cli_status().get_text() == GFC_AUTHENTICATED);
}

private void gfc_test_automatic_setup_reuses_a_repo_that_already_exists() {
    var h = gfc_detected();
    h.fake().repo_create = new HolderLinux.GitRepoCreateResult(false, true, "");
    gfc_automatic(h).clicked();

    assert(h.wait_for_toast("GitHub CLI sync setup completed."));
    assert(h.api.set_project_git_remote_calls == 1);
    assert(h.errors.size == 0);
}

private void gfc_test_automatic_setup_reports_a_repo_that_cannot_be_created() {
    var h = gfc_detected();
    h.fake().repo_create = new HolderLinux.GitRepoCreateResult(false, false, "permission denied");
    gfc_automatic(h).clicked();

    assert(h.wait_for_error("GitHub CLI setup failed|permission denied"));
    h.settle();
    // The failure text has to survive the controls refresh so it stays visible under the buttons.
    assert(h.cli_status().get_text() == "GitHub CLI setup failed: permission denied");
    assert(h.api.set_project_git_remote_calls == 0);
    assert(h.histories.size == 0);
    assert(h.page() == "start");
    assert(h.state_page() == "setup");
    // The controls come back so the user can retry.
    assert(gfc_automatic(h).get_sensitive());
    assert(gfc_shortcut(h).get_sensitive());
}

private void gfc_test_automatic_setup_explains_a_failure_gh_says_nothing_about() {
    var h = gfc_detected();
    h.fake().repo_create = new HolderLinux.GitRepoCreateResult(false, false, "");
    gfc_automatic(h).clicked();

    assert(h.wait_for_error("GitHub CLI setup failed|Repository could not be created."));
    h.settle();
    assert(h.cli_status().get_text() == "GitHub CLI setup failed: Repository could not be created.");
}

private void gfc_test_automatic_setup_reports_a_backend_failure() {
    var h = gfc_detected();
    h.api.fail_push_project_git = true;
    gfc_automatic(h).clicked();

    assert(h.wait_for_error("Git sync failed|push project git failed"));
    h.settle();
    assert(h.cli_status().get_text() == "GitHub CLI setup failed: push project git failed");
    assert(h.histories.size == 0);
    assert(h.page() == "start");
    assert(gfc_automatic(h).get_sensitive());
}

private void gfc_test_automatic_setup_rejects_a_project_name_that_is_not_a_repo_name() {
    var h = gfc_harness(null, false);
    h.store.append(gsv_project("p1", "***", null));
    h.selection.set_selected(0);
    h.view.set_settings(null);
    h.settle();
    assert(gfc_automatic(h).get_sensitive());

    gfc_automatic(h).clicked();

    var reason = "Project name does not produce a valid repository name. Rename project or use manual setup.";
    assert(h.wait_for_error("Git sync failed|" + reason));
    h.settle();
    assert(h.cli_status().get_text() == "GitHub CLI setup failed: " + reason);
    // The name is rejected before anything is created.
    assert(h.fake().count("create") == 0);
    assert(gfc_automatic(h).get_sensitive());
}

private void gfc_test_automatic_setup_needs_a_project() {
    var h = gfc_detected(false);

    gfc_automatic(h).clicked();

    assert(h.toasts.contains("Select a project first."));
    assert(h.fake().count("create") == 0);
}

private void gfc_test_automatic_setup_needs_the_backend() {
    var h = gfc_detected(true, false);

    gfc_automatic(h).clicked();

    assert(h.wait_for_error("Git sync failed|Backend API client is not ready."));
    assert(h.fake().count("create") == 0);
}

private void gfc_test_automatic_setup_needs_an_authenticated_cli() {
    var h = gfc_harness();
    h.fake().cli_state = new HolderLinux.GitHubCliState(true, false, "", "");
    h.view.set_settings(null);
    h.settle();
    assert(!gfc_automatic(h).get_sensitive());

    gfc_automatic(h).clicked();

    assert(h.toasts.contains("GitHub CLI is not authenticated. Run `gh auth login` first."));
    assert(h.fake().count("create") == 0);
}

// ---- the auto-fill shortcut ----

private void gfc_test_the_shortcut_opens_the_ssh_page_with_the_cli_login() {
    var h = gfc_detected();

    gfc_shortcut(h).clicked();
    h.settle();

    assert(h.page() == "guided-part2");
    assert(h.username_entry().get_text() == "octocat");
    assert(h.email_entry().get_text() == "octocat@users.noreply.github.com");
    assert(h.ssh_status().get_text() == "No SSH key found. Enter your email address and generate one.");
}

public void register_git_sync_view_service_cli_tests() {
    var prefix = "/holder/git-sync-view/fake-service/cli/";
    Test.add_func(prefix + "detect/authenticated", gfc_test_an_authenticated_cli_unlocks_the_automatic_controls);
    Test.add_func(prefix + "detect/remembers-login", gfc_test_the_detected_login_is_remembered);
    Test.add_func(prefix + "detect/unauthenticated", gfc_test_an_unauthenticated_cli_is_reported_and_locked);
    Test.add_func(prefix + "detect/missing", gfc_test_a_missing_cli_hides_the_automatic_controls);
    Test.add_func(prefix + "detect/newer-check-wins", gfc_test_a_slow_older_check_cannot_overwrite_a_newer_one);
    Test.add_func(prefix + "automatic/success", gfc_test_automatic_setup_creates_the_repo_saves_the_remote_and_pushes);
    Test.add_func(prefix + "automatic/disconnect-restores-setup",
                  gfc_test_the_setup_page_is_usable_again_after_a_successful_setup_is_disconnected);
    Test.add_func(prefix + "automatic/existing-repo", gfc_test_automatic_setup_reuses_a_repo_that_already_exists);
    Test.add_func(prefix + "automatic/create-failure", gfc_test_automatic_setup_reports_a_repo_that_cannot_be_created);
    Test.add_func(prefix + "automatic/silent-failure", gfc_test_automatic_setup_explains_a_failure_gh_says_nothing_about);
    Test.add_func(prefix + "automatic/backend-failure", gfc_test_automatic_setup_reports_a_backend_failure);
    Test.add_func(prefix + "automatic/bad-repo-name", gfc_test_automatic_setup_rejects_a_project_name_that_is_not_a_repo_name);
    Test.add_func(prefix + "automatic/needs-project", gfc_test_automatic_setup_needs_a_project);
    Test.add_func(prefix + "automatic/needs-api", gfc_test_automatic_setup_needs_the_backend);
    Test.add_func(prefix + "automatic/needs-auth", gfc_test_automatic_setup_needs_an_authenticated_cli);
    Test.add_func(prefix + "shortcut/opens-ssh-page", gfc_test_the_shortcut_opens_the_ssh_page_with_the_cli_login);
}

}
