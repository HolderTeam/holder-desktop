using GLib;

namespace HolderLinuxTests {

// These tests run the real service code against fake gh/git/ssh/ssh-keygen shell scripts placed first
// on PATH (see GitSyncViewEnv), so subprocess handling, argument lists and output parsing are all
// exercised without a real GitHub. POSIX only: they skip on Windows.
private const string GSC_KEY_SETTING = "git-github-username";
private const string GSC_NOT_DETECTED = "GitHub CLI not detected";
private const string GSC_AUTHENTICATED =
    "GitHub CLI authenticated as `octocat`. Use the automatic button above to create repo, set remote, and push.";
private const string GSC_REMOTE = "git@github.com:octocat/runbook.git";
private const string GSC_PUSH_INTRO =
    "We'll now save this remote and push your cards.\nRemote: git@github.com:octocat/runbook.git";

private bool gsc_prepare(out Settings? settings) {
    settings = null;
    if (!GitSyncViewEnv.require_shims()) {
        return false;
    }
    var source = SettingsSchemaSource.get_default();
    if (source == null || ((!) source).lookup(HolderLinux.AppSettings.SCHEMA_ID, true) == null) {
        Test.skip("settings schema is not available");
        return false;
    }
    GitSyncViewEnv.reset();
    var created = new Settings(HolderLinux.AppSettings.SCHEMA_ID);
    created.reset(HolderLinux.AppSettings.KEY_GIT_GITHUB_USERNAME);
    settings = created;
    return true;
}

private bool gsc_wait_for_detection(GitSyncViewHarness h) {
    return wait_for_condition(() => !h.cli_status().get_text().has_prefix(GSC_NOT_DETECTED), 8000);
}

// A harness whose GitHub CLI check has finished, with a real (memory backed) Settings object.
private GitSyncViewHarness gsc_detected(Settings settings,
                                        string? remote = null,
                                        bool with_project = true,
                                        bool with_api = true) {
    var h = new GitSyncViewHarness(remote, with_project, with_api);
    h.view.set_settings(settings);
    assert(gsc_wait_for_detection(h));
    return h;
}

private string gsc_pubkey_text(GitSyncViewHarness h) {
    foreach (var widget in gsv_descendants(h.key_ready_box())) {
        var view = widget as Gtk.TextView;
        if (view != null) {
            return gsv_text_view_text((!) view);
        }
    }
    assert_not_reached();
}

private void gsc_test_an_authenticated_cli_unlocks_the_automatic_controls() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var settings = (!) maybe_settings;
    var h = gsc_detected(settings);

    assert(h.cli_status().get_text() == GSC_AUTHENTICATED);
    var automatic = h.setup_button("Use GitHub CLI (Automatic)");
    var shortcut = h.setup_button("Use GitHub CLI (auto-fill username)");
    assert(automatic.get_visible() && automatic.get_sensitive());
    assert(shortcut.get_visible() && shortcut.get_sensitive());
    assert(h.create_repo_cli_button().get_visible() && h.create_repo_cli_button().get_sensitive());
    assert(h.repo_mode().get_text() ==
           "Recommended on this device: create the private repository with GitHub CLI.");

    // The login becomes the guided username and is remembered.
    assert(h.username_entry().get_text() == "octocat");
    assert(settings.get_string(GSC_KEY_SETTING) == "octocat");
    assert(gsv_button(h.child_page("guided-part1"), "Next").get_sensitive());
    assert(GitSyncViewEnv.ran("gh auth status -h github.com"));
    assert(GitSyncViewEnv.ran("gh api user -q .login"));
}

private void gsc_test_an_unauthenticated_cli_is_reported_and_locked() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    GitSyncViewEnv.set_env("HOLDER_FAKE_GH_AUTH", "no");
    var h = gsc_detected((!) maybe_settings);

    assert(h.cli_status().get_text() ==
           "GitHub CLI detected, but not authenticated. Run `gh auth login` in a terminal to enable automation.");
    var automatic = h.setup_button("Use GitHub CLI (Automatic)");
    assert(automatic.get_visible());
    assert(!automatic.get_sensitive());
    assert(!h.setup_button("Use GitHub CLI (auto-fill username)").get_sensitive());
    assert(!h.create_repo_cli_button().get_sensitive());
    assert(h.username_entry().get_text() == "");
    assert(!GitSyncViewEnv.ran("gh api user"));
}

private void gsc_test_an_authenticated_cli_without_a_login_keeps_the_saved_username() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var settings = (!) maybe_settings;
    GitSyncViewEnv.set_env("HOLDER_FAKE_GH_LOGIN", "");
    settings.set_string(GSC_KEY_SETTING, "kept");
    var h = gsc_detected(settings);

    assert(!h.setup_button("Use GitHub CLI (Automatic)").get_sensitive());
    assert(h.username_entry().get_text() == "kept");
    assert(settings.get_string(GSC_KEY_SETTING) == "kept");
}

private void gsc_test_the_constructor_can_check_the_cli_on_its_own() {
    if (!GitSyncViewEnv.require_shims()) return;
    GitSyncViewEnv.reset();
    var h = new GitSyncViewHarness(null, true, true, true, true);

    assert(gsc_wait_for_detection(h));
    assert(h.cli_status().get_text() == GSC_AUTHENTICATED);
    assert(h.username_entry().get_text() == "octocat");
}

private void gsc_test_the_saved_username_is_prefilled_and_used_when_the_entry_is_blank() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var settings = (!) maybe_settings;
    GitSyncViewEnv.set_env("HOLDER_FAKE_GH_AUTH", "no");
    settings.set_string(GSC_KEY_SETTING, "saved-user");
    var h = gsc_detected(settings);
    assert(h.username_entry().get_text() == "saved-user");

    h.username_entry().set_text("");
    h.main_stack().set_visible_child_name("guided-part3");
    h.repo_name_entry().set_text("runbook");
    h.click("guided-part3", "Next");

    assert(wait_for_condition(() => h.page() == "guided-part4", 8000));
    assert(GitSyncViewEnv.ran("git ls-remote git@github.com:saved-user/runbook.git"));
}

private void gsc_test_the_username_shortcut_fills_saves_and_moves_on() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var settings = (!) maybe_settings;
    var h = gsc_detected(settings);
    h.username_entry().set_text("");
    settings.set_string(GSC_KEY_SETTING, "");

    h.setup_button("Use GitHub CLI (auto-fill username)").clicked();

    assert(h.username_entry().get_text() == "octocat");
    assert(settings.get_string(GSC_KEY_SETTING) == "octocat");
    assert(h.page() == "guided-part2");
    assert(h.email_entry().get_text() == "octocat@users.noreply.github.com");
    assert(h.ssh_status().get_text() == "No SSH key found. Enter your email address and generate one.");
}

private void gsc_test_automatic_setup_creates_the_repo_saves_the_remote_and_pushes() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = gsc_detected((!) maybe_settings);
    var automatic = h.setup_button("Use GitHub CLI (Automatic)");
    var shortcut = h.setup_button("Use GitHub CLI (auto-fill username)");
    h.api.stall_next_push = true;
    automatic.clicked();

    // gh and git ran; the flow is now waiting on the backend push.
    assert(wait_for_condition(() => h.api.has_stalled_push(), 8000));
    assert(!automatic.get_sensitive());
    assert(!shortcut.get_sensitive());
    assert(h.cli_status().get_text() == "GitHub CLI: creating private repo `octocat/Runbook-Project`...");

    h.api.release_stalled_push();
    assert(h.wait_for_toast("GitHub CLI sync setup completed."));
    h.settle();
    // The setup page is hidden now but returns after a disconnect, so it is back to its normal state
    // rather than showing the in-flight status with the buttons still disabled.
    assert(h.cli_status().get_text() == GSC_AUTHENTICATED);
    assert(automatic.get_sensitive() && shortcut.get_sensitive());
    assert(h.histories.size == 1 && h.histories[0] == "p1");
    assert(h.errors.size == 0);
    assert(h.api.last_git_remote_url == "git@github.com:octocat/Runbook-Project.git");
    assert(h.api.push_project_git_calls == 1);
    assert(h.page() == "start");
    assert(h.state_page() == "configured");
    assert(h.named_label("git-configured-remote").get_text() == "git@github.com:octocat/Runbook-Project.git");
    assert(GitSyncViewEnv.ran("gh repo create octocat/Runbook-Project --private"));
    assert(GitSyncViewEnv.ran("git ls-remote git@github.com:octocat/Runbook-Project.git"));
}

private void gsc_test_automatic_setup_reuses_a_repo_that_already_exists() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    GitSyncViewEnv.set_env("HOLDER_FAKE_GH_CREATE", "exists");
    var h = gsc_detected((!) maybe_settings);
    h.setup_button("Use GitHub CLI (Automatic)").clicked();

    assert(wait_for_condition(() => h.toasts.contains("GitHub CLI sync setup completed."), 8000));
    h.settle();
    assert(h.cli_status().get_text() == GSC_AUTHENTICATED);
    assert(h.api.set_project_git_remote_calls == 1);
}

private void gsc_test_automatic_setup_reports_a_repo_that_cannot_be_created() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    GitSyncViewEnv.set_env("HOLDER_FAKE_GH_CREATE", "fail");
    GitSyncViewEnv.set_env("HOLDER_FAKE_GH_CREATE_OUTPUT", "permission denied");
    GitSyncViewEnv.set_env("HOLDER_FAKE_GIT_LSREMOTE", "fail");
    var h = gsc_detected((!) maybe_settings);
    var automatic = h.setup_button("Use GitHub CLI (Automatic)");
    automatic.clicked();

    assert(h.wait_for_error("GitHub CLI setup failed|permission denied"));
    // The failure text has to survive the controls refresh so it stays visible under the buttons.
    assert(h.cli_status().get_text() == "GitHub CLI setup failed: permission denied");
    assert(h.api.set_project_git_remote_calls == 0);
    assert(h.histories.size == 0);
    assert(h.page() == "start");
    assert(h.state_page() == "setup");
    // The controls come back so the user can retry.
    assert(automatic.get_sensitive());
    assert(h.setup_button("Use GitHub CLI (auto-fill username)").get_sensitive());
}

private void gsc_test_automatic_setup_explains_an_unreachable_repo_when_gh_says_nothing() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    GitSyncViewEnv.set_env("HOLDER_FAKE_GH_CREATE", "fail");
    GitSyncViewEnv.set_env("HOLDER_FAKE_GIT_LSREMOTE", "fail");
    var h = gsc_detected((!) maybe_settings);
    h.setup_button("Use GitHub CLI (Automatic)").clicked();

    var details = "Could not verify git@github.com:octocat/Runbook-Project.git via SSH. " +
                  "Repository not reachable over SSH.";
    assert(h.wait_for_error("GitHub CLI setup failed|" + details));
    assert(h.cli_status().get_text() == "GitHub CLI setup failed: " + details);
}

private void gsc_test_automatic_setup_reports_a_backend_failure() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = gsc_detected((!) maybe_settings);
    h.api.fail_push_project_git = true;
    var automatic = h.setup_button("Use GitHub CLI (Automatic)");
    automatic.clicked();

    assert(h.wait_for_error("Git sync failed|push project git failed"));
    assert(h.cli_status().get_text() == "GitHub CLI setup failed: push project git failed");
    assert(h.histories.size == 0);
    assert(h.page() == "start");
    assert(automatic.get_sensitive());
}

private void gsc_test_automatic_setup_rejects_a_project_name_that_is_not_a_repo_name() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = gsc_detected((!) maybe_settings);
    h.store.remove_all();
    h.store.append(gsv_project("p1", "!!!", null));
    h.setup_button("Use GitHub CLI (Automatic)").clicked();

    var message = "Project name does not produce a valid repository name. Rename project or use manual setup.";
    assert(h.wait_for_error("Git sync failed|" + message));
    assert(!GitSyncViewEnv.ran("gh repo create"));
    assert(h.api.set_project_git_remote_calls == 0);
}

// Verifies the repo through the fake `git ls-remote` and lands on the push page.
private GitSyncViewHarness gsc_verified_repository(Settings settings,
                                                   bool with_api = true) {
    var h = gsc_detected(settings, null, true, with_api);
    h.main_stack().set_visible_child_name("guided-part3");
    h.repo_name_entry().set_text("runbook");
    h.click("guided-part3", "Next");
    assert(wait_for_condition(() => h.page() == "guided-part4", 8000));
    return h;
}

private void gsc_test_a_found_repository_leads_to_the_push_page_and_a_finished_setup() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = gsc_verified_repository((!) maybe_settings);

    assert(h.repo_status().get_text() == "Repository found on GitHub.");
    assert(h.push_intro().get_text() == GSC_PUSH_INTRO);
    assert(h.push_status().get_text() == "");
    assert(gsv_button(h.child_page("guided-part3"), "Next").get_sensitive());
    assert(GitSyncViewEnv.ran("git ls-remote " + GSC_REMOTE));

    h.click("guided-part4", "Push Cards");
    assert(h.wait_for_toast("Git sync setup completed."));
    h.settle();
    assert(h.api.last_git_remote_url == GSC_REMOTE);
    assert(h.api.push_project_git_calls == 1);
    assert(h.push_status().get_text().contains("Push: pushed"));
    assert(h.toasts.contains("Git sync setup completed."));
    assert(h.histories.size == 1 && h.histories[0] == "p1");
    assert(h.page() == "start");
    assert(h.state_page() == "configured");
    assert(h.named_label("git-configured-remote").get_text() == GSC_REMOTE);
    assert(gsv_button(h.child_page("guided-part4"), "Push Cards").get_sensitive());
}

private void gsc_test_a_missing_repository_is_reported_and_next_is_usable_again() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    GitSyncViewEnv.set_env("HOLDER_FAKE_GIT_LSREMOTE", "fail");
    GitSyncViewEnv.set_env("HOLDER_FAKE_GIT_OUTPUT", "denied");
    var h = gsc_detected((!) maybe_settings);
    h.main_stack().set_visible_child_name("guided-part3");
    h.repo_name_entry().set_text("runbook");
    h.click("guided-part3", "Next");

    var title = "Repository check failed";
    var details = "Could not find https://github.com/octocat/runbook . Create it first, then click Next again.";
    assert(h.wait_for_error(title + "|" + details));
    assert(h.repo_status().get_text() == "Could not verify " + GSC_REMOTE + " via SSH. denied");
    assert(h.page() == "guided-part3");
    assert(gsv_button(h.child_page("guided-part3"), "Next").get_sensitive());
}

private void gsc_test_creating_the_repository_with_the_cli_moves_to_the_push_page() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = gsc_detected((!) maybe_settings);
    h.main_stack().set_visible_child_name("guided-part3");
    h.repo_name_entry().set_text("runbook");
    h.create_repo_cli_button().clicked();

    assert(wait_for_condition(() => h.page() == "guided-part4", 8000));
    assert(h.repo_status().get_text() == "Repository created with GitHub CLI and verified.");
    assert(h.push_intro().get_text() == GSC_PUSH_INTRO);
    assert(GitSyncViewEnv.ran("gh repo create octocat/runbook --private"));
    assert(h.create_repo_cli_button().get_sensitive());
    assert(h.errors.size == 0);
}

private void gsc_test_an_existing_repository_is_accepted_when_creation_fails() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    GitSyncViewEnv.set_env("HOLDER_FAKE_GH_CREATE", "exists");
    var h = gsc_detected((!) maybe_settings);
    h.main_stack().set_visible_child_name("guided-part3");
    h.repo_name_entry().set_text("runbook");
    h.create_repo_cli_button().clicked();

    assert(wait_for_condition(() => h.page() == "guided-part4", 8000));
    assert(h.repo_status().get_text() == "Repository available and verified.");
}

private void gsc_test_a_failed_repository_creation_is_reported() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    GitSyncViewEnv.set_env("HOLDER_FAKE_GH_CREATE", "fail");
    GitSyncViewEnv.set_env("HOLDER_FAKE_GH_CREATE_OUTPUT", "no permission");
    GitSyncViewEnv.set_env("HOLDER_FAKE_GIT_LSREMOTE", "fail");
    var h = gsc_detected((!) maybe_settings);
    h.main_stack().set_visible_child_name("guided-part3");
    h.repo_name_entry().set_text("runbook");
    h.create_repo_cli_button().clicked();

    assert(h.wait_for_error("GitHub CLI repository creation failed|no permission"));
    assert(h.repo_status().get_text() == "no permission");
    assert(h.page() == "guided-part3");
    assert(h.create_repo_cli_button().get_sensitive());
    assert(gsv_button(h.child_page("guided-part3"), "Next").get_sensitive());
}

private void gsc_test_the_push_step_reports_a_backend_failure() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = gsc_verified_repository((!) maybe_settings);
    h.api.fail_set_project_git_remote = true;
    var push = gsv_button(h.child_page("guided-part4"), "Push Cards");
    push.clicked();

    assert(h.wait_for_error("Git sync failed|set project git remote failed"));
    h.settle();
    assert(h.errors.size == 1);
    assert(h.page() == "guided-part4");
    assert(h.histories.size == 0);
    assert(push.get_sensitive());
}

private void gsc_test_the_push_step_needs_a_project() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = gsc_verified_repository((!) maybe_settings);
    h.select_none();
    h.click("guided-part4", "Push Cards");

    assert(h.toasts.size == 1 && h.toasts[0] == "Select a project first.");
    assert(h.api.set_project_git_remote_calls == 0);
    assert(h.page() == "guided-part4");
}

private void gsc_test_the_push_step_needs_an_api_client() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = gsc_verified_repository((!) maybe_settings, false);
    h.click("guided-part4", "Push Cards");

    assert(h.errors.size == 1 && h.errors[0] == "Git sync failed|Backend API client is not ready.");
    assert(h.page() == "guided-part4");
}

private void gsc_test_an_authenticated_ssh_key_finishes_the_ssh_step() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = new GitSyncViewHarness(null);
    GitSyncViewEnv.write_ssh_file("id_ed25519.pub", "ssh-ed25519 AAAAKEY me@example.com\n");
    h.click("guided-part2", "Re-check");

    var done = "SSH key found and authenticated with GitHub. You're all set.";
    assert(wait_for_condition(() => h.ssh_status().get_text() == done, 8000));
    assert(gsc_pubkey_text(h) == "ssh-ed25519 AAAAKEY me@example.com");
    assert(!h.missing_key_box().get_visible());
    assert(!h.key_ready_box().get_visible());
    assert(!h.open_keys_button().get_visible());
    assert(GitSyncViewEnv.ran("ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -T git@github.com"));
}

private void gsc_test_a_rejected_ssh_key_offers_to_copy_it() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = new GitSyncViewHarness(null);
    GitSyncViewEnv.set_env("HOLDER_FAKE_SSH_PROBE", "denied");
    GitSyncViewEnv.write_ssh_file("id_ed25519.pub", "ssh-ed25519 AAAAKEY me@example.com\n");
    h.click("guided-part2", "Re-check");

    var message = "SSH key found locally, but GitHub rejected authentication. " +
                  "Copy this key and add it at GitHub SSH settings.";
    assert(wait_for_condition(() => h.ssh_status().get_text() == message, 8000));
    assert(!h.missing_key_box().get_visible());
    assert(h.key_ready_box().get_visible());
    assert(h.open_keys_button().get_visible());
    assert(gsv_button(h.child_page("guided-part2"), "Copy Public Key").get_sensitive());
}

private void gsc_test_other_ssh_probe_results_are_shown_as_they_are() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = new GitSyncViewHarness(null);
    GitSyncViewEnv.set_env("HOLDER_FAKE_SSH_PROBE", "other");
    GitSyncViewEnv.write_ssh_file("id_ed25519.pub", "ssh-ed25519 AAAAKEY me@example.com\n");
    h.click("guided-part2", "Re-check");

    var other = "SSH key found locally. GitHub verification result: Connection timed out";
    assert(wait_for_condition(() => h.ssh_status().get_text() == other, 8000));

    GitSyncViewEnv.set_env("HOLDER_FAKE_SSH_PROBE", "silent");
    h.click("guided-part2", "Re-check");
    var silent = "SSH key found locally. Could not verify with GitHub.";
    assert(wait_for_condition(() => h.ssh_status().get_text() == silent, 8000));
}

private void gsc_test_an_rsa_public_key_is_found_when_there_is_no_ed25519_one() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = new GitSyncViewHarness(null);
    GitSyncViewEnv.set_env("HOLDER_FAKE_SSH_PROBE", "denied");
    GitSyncViewEnv.write_ssh_file("id_rsa.pub", "ssh-rsa AAAARSA me@example.com\n");
    h.click("guided-part2", "Re-check");

    assert(wait_for_condition(() => h.ssh_status().get_text().has_prefix("SSH key found locally, but GitHub rejected"), 8000));
    assert(gsc_pubkey_text(h) == "ssh-rsa AAAARSA me@example.com");
}

private void gsc_test_generating_a_key_runs_ssh_keygen_and_rechecks() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = new GitSyncViewHarness(null);
    h.email_entry().set_text("me@example.com");
    var generate = gsv_button(h.child_page("guided-part2"), "Generate SSH Key");
    generate.clicked();

    assert(h.wait_for_toast("SSH key generated."));
    var key_path = Path.build_filename(GitSyncViewEnv.ssh_dir(), "id_ed25519");
    assert(FileUtils.test(key_path + ".pub", FileTest.EXISTS));
    assert(GitSyncViewEnv.ran("ssh-keygen -t ed25519 -C me@example.com -f " + key_path + " -N"));
    assert(generate.get_sensitive());

    var done = "SSH key found and authenticated with GitHub. You're all set.";
    assert(wait_for_condition(() => h.ssh_status().get_text() == done, 8000));
    assert(gsc_pubkey_text(h) == "ssh-ed25519 AAAAFAKEKEY fake@example.com");
}

private void gsc_test_a_failing_ssh_keygen_shows_its_output() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    GitSyncViewEnv.set_env("HOLDER_FAKE_KEYGEN", "fail");
    GitSyncViewEnv.set_env("HOLDER_FAKE_KEYGEN_OUTPUT", "keygen boom");
    var h = new GitSyncViewHarness(null);
    h.email_entry().set_text("me@example.com");
    var generate = gsv_button(h.child_page("guided-part2"), "Generate SSH Key");
    generate.clicked();

    assert(h.wait_for_error("SSH key generation failed|keygen boom"));
    assert(h.toasts.size == 0);
    assert(generate.get_sensitive());
}

private void gsc_test_a_silent_ssh_keygen_failure_still_explains_itself() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    GitSyncViewEnv.set_env("HOLDER_FAKE_KEYGEN", "fail");
    var h = new GitSyncViewHarness(null);
    h.email_entry().set_text("me@example.com");
    gsv_button(h.child_page("guided-part2"), "Generate SSH Key").clicked();

    assert(h.wait_for_error("SSH key generation failed|ssh-keygen did not create a public key."));
}

private void gsc_test_a_second_recheck_while_one_is_running_is_ignored() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = new GitSyncViewHarness(null);
    GitSyncViewEnv.write_ssh_file("id_ed25519.pub", "ssh-ed25519 AAAAKEY me@example.com\n");
    h.click("guided-part2", "Re-check");
    // The first check is now waiting on the (fake) ssh process, so this one must return at once.
    h.click("guided-part2", "Re-check");
    assert(h.ssh_status().get_text() == "Checking SSH setup...");

    var done = "SSH key found and authenticated with GitHub. You're all set.";
    assert(wait_for_condition(() => h.ssh_status().get_text() == done, 8000));
    h.settle();
    var probes = GitSyncViewEnv.commands().split("-T git@github.com");
    assert(probes.length == 2);
}

private void gsc_test_an_unreadable_public_key_is_treated_as_empty() {
    Settings? maybe_settings;
    if (!gsc_prepare(out maybe_settings)) return;
    var h = new GitSyncViewHarness(null);
    // A directory where the key file should be: it exists, but reading it fails.
    DirUtils.create_with_parents(Path.build_filename(GitSyncViewEnv.ssh_dir(), "id_ed25519.pub"), 0700);
    h.click("guided-part2", "Re-check");

    // An unreadable key file is no key: the generate controls stay available and nothing is probed
    // (it used to claim GitHub had authenticated an empty key).
    var done = "No SSH key found. Enter your email address and generate one.";
    assert(wait_for_condition(() => h.ssh_status().get_text() == done, 8000));
    assert(h.missing_key_box().get_visible());
    assert(!h.key_ready_box().get_visible());
    assert(!GitSyncViewEnv.ran("ssh -o"));
}

public void register_git_sync_view_cli_tests() {
    var prefix = "/holder/git-sync-view/cli/";
    Test.add_func(prefix + "detect/authenticated", gsc_test_an_authenticated_cli_unlocks_the_automatic_controls);
    Test.add_func(prefix + "detect/unauthenticated", gsc_test_an_unauthenticated_cli_is_reported_and_locked);
    Test.add_func(prefix + "detect/no-login", gsc_test_an_authenticated_cli_without_a_login_keeps_the_saved_username);
    Test.add_func(prefix + "detect/constructor", gsc_test_the_constructor_can_check_the_cli_on_its_own);
    Test.add_func(prefix + "username/saved-fallback", gsc_test_the_saved_username_is_prefilled_and_used_when_the_entry_is_blank);
    Test.add_func(prefix + "username/shortcut", gsc_test_the_username_shortcut_fills_saves_and_moves_on);
    Test.add_func(prefix + "automatic/success", gsc_test_automatic_setup_creates_the_repo_saves_the_remote_and_pushes);
    Test.add_func(prefix + "automatic/existing-repo", gsc_test_automatic_setup_reuses_a_repo_that_already_exists);
    Test.add_func(prefix + "automatic/create-failure", gsc_test_automatic_setup_reports_a_repo_that_cannot_be_created);
    Test.add_func(prefix + "automatic/silent-failure", gsc_test_automatic_setup_explains_an_unreachable_repo_when_gh_says_nothing);
    Test.add_func(prefix + "automatic/backend-failure", gsc_test_automatic_setup_reports_a_backend_failure);
    Test.add_func(prefix + "automatic/bad-repo-name", gsc_test_automatic_setup_rejects_a_project_name_that_is_not_a_repo_name);
    Test.add_func(prefix + "verify/found-then-push", gsc_test_a_found_repository_leads_to_the_push_page_and_a_finished_setup);
    Test.add_func(prefix + "verify/missing", gsc_test_a_missing_repository_is_reported_and_next_is_usable_again);
    Test.add_func(prefix + "create/success", gsc_test_creating_the_repository_with_the_cli_moves_to_the_push_page);
    Test.add_func(prefix + "create/existing", gsc_test_an_existing_repository_is_accepted_when_creation_fails);
    Test.add_func(prefix + "create/failure", gsc_test_a_failed_repository_creation_is_reported);
    Test.add_func(prefix + "push/backend-failure", gsc_test_the_push_step_reports_a_backend_failure);
    Test.add_func(prefix + "push/no-project", gsc_test_the_push_step_needs_a_project);
    Test.add_func(prefix + "push/no-api", gsc_test_the_push_step_needs_an_api_client);
    Test.add_func(prefix + "ssh/authenticated", gsc_test_an_authenticated_ssh_key_finishes_the_ssh_step);
    Test.add_func(prefix + "ssh/rejected", gsc_test_a_rejected_ssh_key_offers_to_copy_it);
    Test.add_func(prefix + "ssh/other-results", gsc_test_other_ssh_probe_results_are_shown_as_they_are);
    Test.add_func(prefix + "ssh/rsa-fallback", gsc_test_an_rsa_public_key_is_found_when_there_is_no_ed25519_one);
    Test.add_func(prefix + "ssh/overlapping-checks", gsc_test_a_second_recheck_while_one_is_running_is_ignored);
    Test.add_func(prefix + "ssh/unreadable-key", gsc_test_an_unreadable_public_key_is_treated_as_empty);
    Test.add_func(prefix + "keygen/success", gsc_test_generating_a_key_runs_ssh_keygen_and_rechecks);
    Test.add_func(prefix + "keygen/failure", gsc_test_a_failing_ssh_keygen_shows_its_output);
    Test.add_func(prefix + "keygen/silent-failure", gsc_test_a_silent_ssh_keygen_failure_still_explains_itself);
}

}
