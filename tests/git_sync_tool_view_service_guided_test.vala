using GLib;

namespace HolderLinuxTests {

// Guided setup, SSH key and clipboard/launcher tests against a GitSyncViewFakeService and an empty
// home directory of their own (see GitSyncViewHarness), so they run on every platform.
private const string GFG_NO_KEY = "No SSH key found. Enter your email address and generate one.";
private const string GFG_UNVERIFIED = "SSH key found locally. Could not verify with GitHub.";
private const string GFG_AUTHENTICATED_PROBE =
    "Hi octocat! You've successfully authenticated, but GitHub does not provide shell access.";
private const string GFG_KEY = "ssh-ed25519 AAAAFAKEKEY me@example.org";
private const string GFG_KEYS_URL = "https://github.com/settings/ssh/new";
private const string GFG_PUSH_INTRO =
    "We'll now save this remote and push your cards.\nRemote: git@github.com:octocat/runbook.git";

private GitSyncViewHarness gfg_harness(bool with_project = true,
                                       bool with_api = true,
                                       string? home_override = null) {
    return new GitSyncViewHarness(null, with_project, with_api, true, false, null, true, home_override);
}

private void gfg_write_ssh_file(string home, string name, string contents) {
    var dir = Path.build_filename(home, ".ssh");
    DirUtils.create_with_parents(dir, 0700);
    try {
        FileUtils.set_contents(Path.build_filename(dir, name), contents);
    } catch (Error e) {
        assert_not_reached();
    }
}

private void gfg_recheck(GitSyncViewHarness h) {
    h.main_stack().set_visible_child_name("guided-part2");
    h.click("guided-part2", "Re-check");
    h.settle();
}

private string gfg_pubkey_text(GitSyncViewHarness h) {
    foreach (var widget in gsv_descendants(h.key_ready_box())) {
        var view = widget as Gtk.TextView;
        if (view != null) {
            return gsv_text_view_text((!) view);
        }
    }
    assert_not_reached();
}

// A harness with a key on disk that GitHub rejects, so the key is shown and can be copied.
private GitSyncViewHarness gfg_with_a_rejected_key() {
    var h = gfg_harness();
    gfg_write_ssh_file(h.home, "id_ed25519.pub", GFG_KEY + "\n");
    h.fake().ssh_probe_output = "git@github.com: Permission denied (publickey).";
    gfg_recheck(h);
    return h;
}

// Sets the guided username and repository name and opens the repository page.
private void gfg_open_the_repository_page(GitSyncViewHarness h, string username, string repo) {
    h.username_entry().set_text(username);
    h.main_stack().set_visible_child_name("guided-part3");
    h.repo_name_entry().set_text(repo);
}

// ---- the SSH page ----

private void gfg_test_no_key_offers_to_generate_one() {
    var h = gfg_harness();

    gfg_recheck(h);

    assert(h.ssh_status().get_text() == GFG_NO_KEY);
    assert(h.missing_key_box().get_visible());
    assert(!h.key_ready_box().get_visible());
    assert(h.open_keys_button().get_visible());
    // Nothing to probe without a key.
    assert(h.fake().count("probe") == 0);
}

private void gfg_test_a_key_github_accepts_is_reported_as_ready() {
    var h = gfg_harness();
    gfg_write_ssh_file(h.home, "id_ed25519.pub", GFG_KEY + "\n");
    h.fake().ssh_probe_output = GFG_AUTHENTICATED_PROBE;

    gfg_recheck(h);

    assert(h.ssh_status().get_text() == "SSH key found and authenticated with GitHub. You're all set.");
    assert(!h.missing_key_box().get_visible());
    assert(!h.key_ready_box().get_visible());
    assert(!h.open_keys_button().get_visible());
    assert(h.fake().count("probe") == 1);
}

private void gfg_test_a_key_github_rejects_is_shown_for_copying() {
    var h = gfg_with_a_rejected_key();

    assert(h.ssh_status().get_text() ==
           "SSH key found locally, but GitHub rejected authentication. Copy this key and add it at GitHub SSH settings.");
    assert(!h.missing_key_box().get_visible());
    assert(h.key_ready_box().get_visible());
    assert(h.open_keys_button().get_visible());
    assert(gfg_pubkey_text(h) == GFG_KEY);
    assert(gsv_button(h.child_page("guided-part2"), "Copy Public Key").get_sensitive());
}

private void gfg_test_an_unclear_probe_result_is_shown_as_it_came() {
    var h = gfg_harness();
    gfg_write_ssh_file(h.home, "id_ed25519.pub", GFG_KEY);
    h.fake().ssh_probe_output = "Connection timed out";

    gfg_recheck(h);

    assert(h.ssh_status().get_text() == "SSH key found locally. GitHub verification result: Connection timed out");
    assert(h.key_ready_box().get_visible());
}

private void gfg_test_a_probe_with_no_output_says_it_could_not_verify() {
    var h = gfg_harness();
    gfg_write_ssh_file(h.home, "id_ed25519.pub", GFG_KEY);

    gfg_recheck(h);

    assert(h.ssh_status().get_text() == GFG_UNVERIFIED);
}

private void gfg_test_an_rsa_key_is_used_when_there_is_no_ed25519_key() {
    var h = gfg_harness();
    gfg_write_ssh_file(h.home, "id_rsa.pub", "ssh-rsa AAAARSA me@example.org");

    gfg_recheck(h);

    assert(h.ssh_status().get_text() == GFG_UNVERIFIED);
    assert(gfg_pubkey_text(h) == "ssh-rsa AAAARSA me@example.org");
}

private void gfg_test_the_ed25519_key_wins_over_an_rsa_key() {
    var h = gfg_harness();
    gfg_write_ssh_file(h.home, "id_rsa.pub", "ssh-rsa AAAARSA me@example.org");
    gfg_write_ssh_file(h.home, "id_ed25519.pub", GFG_KEY);

    gfg_recheck(h);

    assert(gfg_pubkey_text(h) == GFG_KEY);
}

private void gfg_test_an_empty_key_file_is_treated_as_no_key() {
    var h = gfg_harness();
    gfg_write_ssh_file(h.home, "id_ed25519.pub", "  \n");

    gfg_recheck(h);

    // An empty key file used to show an empty "key ready" box and hide the generate controls.
    assert(h.ssh_status().get_text() == GFG_NO_KEY);
    assert(h.missing_key_box().get_visible());
    assert(!h.key_ready_box().get_visible());
    assert(h.fake().count("probe") == 0);
}

private void gfg_test_without_a_home_directory_there_is_no_key() {
    var h = gfg_harness(true, true, "");

    gfg_recheck(h);

    assert(h.ssh_status().get_text() == GFG_NO_KEY);
    assert(h.fake().count("probe") == 0);
}

private void gfg_test_only_one_ssh_check_runs_at_a_time() {
    var h = gfg_harness();
    gfg_write_ssh_file(h.home, "id_ed25519.pub", GFG_KEY);
    var service = h.fake();
    service.stall_next_probe = true;

    gfg_recheck(h);
    assert(service.has_stalled_probe());
    assert(h.ssh_status().get_text() == "Checking SSH setup...");
    h.click("guided-part2", "Re-check");
    h.settle();
    assert(service.count("probe") == 1);

    service.release_stalled_probe();
    h.settle();
    assert(h.ssh_status().get_text() == GFG_UNVERIFIED);
    // The guard is released again once the check finished.
    h.click("guided-part2", "Re-check");
    h.settle();
    assert(service.count("probe") == 2);
}

// ---- generating a key ----

private void gfg_test_generating_a_key_needs_an_email() {
    var h = gfg_harness();
    h.main_stack().set_visible_child_name("guided-part2");

    h.click("guided-part2", "Generate SSH Key");
    h.settle();

    assert(h.toasts.contains("Email address is required."));
    assert(h.fake().count("keygen") == 0);
}

private void gfg_test_a_generated_key_is_shown_and_checked() {
    var h = gfg_harness();
    h.main_stack().set_visible_child_name("guided-part2");
    h.email_entry().set_text("  me@example.org ");
    var generate = gsv_button(h.child_page("guided-part2"), "Generate SSH Key");

    generate.clicked();
    assert(h.wait_for_toast("SSH key generated."));
    h.settle();

    assert(h.fake().count("keygen me@example.org") == 1);
    assert(generate.get_sensitive());
    assert(FileUtils.test(Path.build_filename(h.home, ".ssh", "id_ed25519.pub"), FileTest.EXISTS));
    // The new key is checked straight away.
    assert(h.fake().count("probe") == 1);
    assert(h.ssh_status().get_text() == GFG_UNVERIFIED);
    assert(h.key_ready_box().get_visible());
    assert(gfg_pubkey_text(h) == "ssh-ed25519 AAAAFAKEKEY me@example.org");
}

private void gfg_test_an_existing_private_key_is_never_overwritten() {
    var h = gfg_harness();
    h.main_stack().set_visible_child_name("guided-part2");
    gfg_write_ssh_file(h.home, "id_ed25519", "existing private key");
    h.email_entry().set_text("me@example.org");

    h.click("guided-part2", "Generate SSH Key");
    h.settle();

    assert(h.toasts.contains("Using existing id_ed25519 key."));
    assert(h.fake().count("keygen") == 0);
}

private void gfg_test_a_key_generation_failure_is_reported_with_the_tools_output() {
    var h = gfg_harness();
    h.main_stack().set_visible_child_name("guided-part2");
    h.fake().keygen_writes_key = false;
    h.fake().keygen_result = new HolderLinux.GitCommandResult(1, "  Saving key failed: no space left  ");
    h.email_entry().set_text("me@example.org");
    var generate = gsv_button(h.child_page("guided-part2"), "Generate SSH Key");

    generate.clicked();

    assert(h.wait_for_error("SSH key generation failed|Saving key failed: no space left"));
    assert(generate.get_sensitive());
    assert(!h.toasts.contains("SSH key generated."));
}

private void gfg_test_a_key_generation_failure_without_output_still_explains_itself() {
    var h = gfg_harness();
    h.main_stack().set_visible_child_name("guided-part2");
    h.fake().keygen_writes_key = false;
    h.fake().keygen_result = new HolderLinux.GitCommandResult(1, "");
    h.email_entry().set_text("me@example.org");

    h.click("guided-part2", "Generate SSH Key");

    assert(h.wait_for_error("SSH key generation failed|ssh-keygen did not create a public key."));
}

private void gfg_test_generating_a_key_without_a_home_directory_is_reported() {
    var h = gfg_harness(true, true, "");
    h.main_stack().set_visible_child_name("guided-part2");
    h.email_entry().set_text("me@example.org");

    h.click("guided-part2", "Generate SSH Key");

    assert(h.wait_for_error("SSH key generation failed|Home directory not available."));
    assert(h.fake().count("keygen") == 0);
}

private void gfg_test_an_ssh_directory_that_cannot_be_created_is_reported() {
    // A regular file where the home directory should be, so ~/.ssh cannot be created under it.
    var base_dir = GitSyncViewEnv.make_home();
    var not_a_directory = Path.build_filename(base_dir, "not-a-directory");
    try {
        FileUtils.set_contents(not_a_directory, "x");
    } catch (Error e) {
        assert_not_reached();
    }
    var h = gfg_harness(true, true, not_a_directory);
    h.main_stack().set_visible_child_name("guided-part2");
    h.email_entry().set_text("me@example.org");

    h.click("guided-part2", "Generate SSH Key");

    assert(wait_for_condition(() => h.errors.size == 1, 5000));
    assert(h.errors[0].has_prefix("SSH key generation failed|Could not create "));
    assert(h.fake().count("keygen") == 0);
}

// ---- copying the key and opening GitHub ----

private void gfg_test_the_public_key_is_copied() {
    var h = gfg_with_a_rejected_key();

    gsv_button(h.child_page("guided-part2"), "Copy Public Key").clicked();

    assert(h.clipboard.texts.size == 1 && h.clipboard.texts[0] == GFG_KEY);
    assert(h.toasts.contains("Public key copied."));
    assert(h.errors.size == 0);
}

private void gfg_test_copying_with_no_key_says_so() {
    var h = gfg_harness();
    gfg_recheck(h);

    gsv_button(h.child_page("guided-part2"), "Copy Public Key").clicked();

    assert(h.toasts.contains("No public key to copy."));
    assert(h.clipboard.texts.size == 0);
}

private void gfg_test_copying_the_key_without_a_clipboard_is_reported() {
    var h = gfg_with_a_rejected_key();
    h.clipboard.available = false;

    gsv_button(h.child_page("guided-part2"), "Copy Public Key").clicked();

    assert(h.errors.contains("Clipboard unavailable|No display available."));
    assert(!h.toasts.contains("Public key copied."));
}

private void gfg_test_the_github_keys_page_is_opened() {
    var h = gfg_harness();
    h.main_stack().set_visible_child_name("guided-part2");

    h.open_keys_button().clicked();

    assert(h.launcher.uris.size == 1 && h.launcher.uris[0] == GFG_KEYS_URL);
    assert(h.errors.size == 0);
}

private void gfg_test_a_browser_that_cannot_be_opened_is_reported() {
    var h = gfg_harness();
    h.main_stack().set_visible_child_name("guided-part2");
    h.launcher.failure = new IOError.FAILED("no browser");

    h.open_keys_button().clicked();

    assert(h.errors.contains("Failed to open browser|no browser"));
}

// ---- the repository page ----

private void gfg_test_an_existing_repository_moves_on_to_the_push_page() {
    var h = gfg_harness();
    gfg_open_the_repository_page(h, "octocat", "runbook");

    h.click("guided-part3", "Next");
    h.settle();

    assert(h.fake().count("check octocat/runbook") == 1);
    assert(h.repo_status().get_text() == "Repository found on GitHub.");
    assert(h.push_intro().get_text() == GFG_PUSH_INTRO);
    assert(h.push_status().get_text() == "");
    assert(h.page() == "guided-part4");
    assert(gsv_button(h.child_page("guided-part3"), "Next").get_sensitive());
}

private void gfg_test_a_missing_repository_is_explained_and_stays_on_the_page() {
    var h = gfg_harness();
    gfg_open_the_repository_page(h, "octocat", "runbook");
    h.fake().repo_check = new HolderLinux.GitRepoCheckResult(false, "Repository not reachable over SSH.");

    h.click("guided-part3", "Next");
    h.settle();

    assert(h.repo_status().get_text() == "Repository not reachable over SSH.");
    assert(h.errors.contains(
        "Repository check failed|Could not find https://github.com/octocat/runbook . Create it first, then click Next again."
    ));
    assert(h.page() == "guided-part3");
    assert(gsv_button(h.child_page("guided-part3"), "Next").get_sensitive());
}

private void gfg_test_a_slow_repository_check_does_not_pull_the_user_forward() {
    var h = gfg_harness();
    gfg_open_the_repository_page(h, "octocat", "runbook");
    h.fake().stall_next_repo_check = true;
    h.click("guided-part3", "Next");
    assert(h.fake().has_stalled_repo_check());
    assert(!gsv_button(h.child_page("guided-part3"), "Next").get_sensitive());
    h.click("guided-part3", "Back");
    assert(h.page() == "guided-part2");

    h.fake().release_stalled_repo_check();
    h.settle();

    // The user went back while the check ran, so they stay where they are; the answer is kept.
    assert(h.page() == "guided-part2");
    assert(h.push_intro().get_text() == GFG_PUSH_INTRO);
    assert(gsv_button(h.child_page("guided-part3"), "Next").get_sensitive());
}

private void gfg_test_a_repository_is_created_with_the_cli() {
    var h = gfg_harness();
    gfg_open_the_repository_page(h, "octocat", "runbook");

    h.create_repo_cli_button().clicked();
    h.settle();

    assert(h.fake().count("create octocat/runbook") == 1);
    assert(h.repo_status().get_text() == "Repository created with GitHub CLI and verified.");
    assert(h.push_intro().get_text() == GFG_PUSH_INTRO);
    assert(h.page() == "guided-part4");
    assert(h.create_repo_cli_button().get_sensitive());
}

private void gfg_test_an_existing_repository_is_reused_when_creating() {
    var h = gfg_harness();
    gfg_open_the_repository_page(h, "octocat", "runbook");
    h.fake().repo_create = new HolderLinux.GitRepoCreateResult(false, true, "");

    h.create_repo_cli_button().clicked();
    h.settle();

    assert(h.repo_status().get_text() == "Repository available and verified.");
    assert(h.page() == "guided-part4");
}

private void gfg_test_a_repository_that_cannot_be_created_is_reported() {
    var h = gfg_harness();
    gfg_open_the_repository_page(h, "octocat", "runbook");
    h.fake().repo_create = new HolderLinux.GitRepoCreateResult(false, false, "  permission denied ");

    h.create_repo_cli_button().clicked();
    h.settle();

    assert(h.repo_status().get_text() == "permission denied");
    assert(h.errors.contains("GitHub CLI repository creation failed|permission denied"));
    assert(h.page() == "guided-part3");
    assert(h.create_repo_cli_button().get_sensitive());
    assert(gsv_button(h.child_page("guided-part3"), "Next").get_sensitive());
}

private void gfg_test_creating_a_repository_needs_a_username_and_a_name() {
    var h = gfg_harness();
    gfg_open_the_repository_page(h, "", "runbook");

    h.create_repo_cli_button().clicked();
    h.settle();

    assert(h.toasts.contains("GitHub username and repository name are required."));
    assert(h.fake().count("create") == 0);
}

private void gfg_test_a_slow_repository_creation_does_not_pull_the_user_forward() {
    var h = gfg_harness();
    gfg_open_the_repository_page(h, "octocat", "runbook");
    h.fake().stall_next_repo_create = true;
    h.create_repo_cli_button().clicked();
    assert(h.fake().has_stalled_repo_create());
    assert(!h.create_repo_cli_button().get_sensitive());
    h.click("guided-part3", "Back");
    assert(h.page() == "guided-part2");

    h.fake().release_stalled_repo_create();
    h.settle();

    assert(h.page() == "guided-part2");
    assert(h.repo_status().get_text() == "Repository created with GitHub CLI and verified.");
    assert(h.create_repo_cli_button().get_sensitive());
}

// ---- the push page ----

private GitSyncViewHarness gfg_ready_to_push() {
    var h = gfg_harness();
    gfg_open_the_repository_page(h, "octocat", "runbook");
    h.click("guided-part3", "Next");
    h.settle();
    assert(h.page() == "guided-part4");
    return h;
}

private void gfg_test_pushing_saves_the_remote_and_shows_the_configured_state() {
    var h = gfg_ready_to_push();
    h.api.stall_next_push = true;
    var push = gsv_button(h.child_page("guided-part4"), "Push Cards");

    push.clicked();

    assert(wait_for_condition(() => h.api.has_stalled_push(), 5000));
    assert(!push.get_sensitive());
    assert(h.push_status().get_text() == "Saving remote and testing connectivity...");

    h.api.release_stalled_push();
    assert(h.wait_for_toast("Git sync setup completed."));
    h.settle();
    assert(push.get_sensitive());
    assert(h.errors.size == 0);
    assert(h.histories.size == 1 && h.histories[0] == "p1");
    assert(h.api.last_git_remote_url == "git@github.com:octocat/runbook.git");
    assert(h.page() == "start");
    assert(h.state_page() == "configured");
    assert(h.named_label("git-configured-remote").get_text() == "git@github.com:octocat/runbook.git");
}

private void gfg_test_a_backend_failure_while_pushing_is_reported_and_can_be_retried() {
    var h = gfg_ready_to_push();
    h.api.fail_push_project_git = true;
    var push = gsv_button(h.child_page("guided-part4"), "Push Cards");

    push.clicked();

    assert(h.wait_for_error("Git sync failed|push project git failed"));
    h.settle();
    assert(push.get_sensitive());
    assert(h.histories.size == 0);
    assert(h.page() == "guided-part4");
}

private void gfg_test_pushing_needs_a_project() {
    var h = gfg_harness(false);
    gfg_open_the_repository_page(h, "octocat", "runbook");
    h.click("guided-part3", "Next");
    h.settle();
    assert(h.page() == "guided-part4");

    h.click("guided-part4", "Push Cards");
    h.settle();

    assert(h.toasts.contains("Select a project first."));
    assert(h.api.set_project_git_remote_calls == 0);
}

private void gfg_test_pushing_needs_the_backend() {
    var h = gfg_harness(true, false);
    gfg_open_the_repository_page(h, "octocat", "runbook");
    h.click("guided-part3", "Next");
    h.settle();

    h.click("guided-part4", "Push Cards");
    h.settle();

    assert(h.errors.contains("Git sync failed|Backend API client is not ready."));
}

private void gfg_test_pushing_without_a_repository_goes_back_to_the_repository_page() {
    var h = gfg_harness();
    h.main_stack().set_visible_child_name("guided-part4");

    h.click("guided-part4", "Push Cards");
    h.settle();

    assert(h.toasts.contains("GitHub username and repository name are required."));
    assert(h.page() == "guided-part3");
    assert(h.api.set_project_git_remote_calls == 0);
}

private void gfg_test_a_repository_set_up_for_one_project_is_not_pushed_to_another() {
    var h = gfg_ready_to_push();
    // The user picks a different project while the push page is open.
    h.store.append(gsv_project("p2", "Other Project", null));
    h.selection.set_selected(1);
    h.settle();
    assert(h.page() == "guided-part4");

    h.click("guided-part4", "Push Cards");
    h.settle();

    assert(h.toasts.contains("The selected project changed. Set up the repository again for this project."));
    assert(h.page() == "guided-part3");
    assert(h.api.set_project_git_remote_calls == 0);
    assert(h.api.push_project_git_calls == 0);
}

private void gfg_test_a_repository_checked_before_any_project_was_selected_can_be_pushed() {
    var h = gfg_harness(false);
    gfg_open_the_repository_page(h, "octocat", "runbook");
    h.click("guided-part3", "Next");
    h.settle();
    assert(h.page() == "guided-part4");
    h.store.append(gsv_project("p1", "Runbook Project", null));
    h.selection.set_selected(0);
    h.settle();

    h.click("guided-part4", "Push Cards");

    assert(h.wait_for_toast("Git sync setup completed."));
    assert(h.api.last_git_project_id == "p1");
    assert(h.api.last_git_remote_url == "git@github.com:octocat/runbook.git");
}

public void register_git_sync_view_service_guided_tests() {
    var prefix = "/holder/git-sync-view/fake-service/guided/";
    Test.add_func(prefix + "ssh/no-key", gfg_test_no_key_offers_to_generate_one);
    Test.add_func(prefix + "ssh/key-accepted", gfg_test_a_key_github_accepts_is_reported_as_ready);
    Test.add_func(prefix + "ssh/key-rejected", gfg_test_a_key_github_rejects_is_shown_for_copying);
    Test.add_func(prefix + "ssh/unclear-probe", gfg_test_an_unclear_probe_result_is_shown_as_it_came);
    Test.add_func(prefix + "ssh/silent-probe", gfg_test_a_probe_with_no_output_says_it_could_not_verify);
    Test.add_func(prefix + "ssh/rsa-fallback", gfg_test_an_rsa_key_is_used_when_there_is_no_ed25519_key);
    Test.add_func(prefix + "ssh/ed25519-preferred", gfg_test_the_ed25519_key_wins_over_an_rsa_key);
    Test.add_func(prefix + "ssh/empty-key-file", gfg_test_an_empty_key_file_is_treated_as_no_key);
    Test.add_func(prefix + "ssh/no-home", gfg_test_without_a_home_directory_there_is_no_key);
    Test.add_func(prefix + "ssh/one-check-at-a-time", gfg_test_only_one_ssh_check_runs_at_a_time);
    Test.add_func(prefix + "keygen/needs-email", gfg_test_generating_a_key_needs_an_email);
    Test.add_func(prefix + "keygen/success", gfg_test_a_generated_key_is_shown_and_checked);
    Test.add_func(prefix + "keygen/existing-key", gfg_test_an_existing_private_key_is_never_overwritten);
    Test.add_func(prefix + "keygen/failure-output", gfg_test_a_key_generation_failure_is_reported_with_the_tools_output);
    Test.add_func(prefix + "keygen/silent-failure", gfg_test_a_key_generation_failure_without_output_still_explains_itself);
    Test.add_func(prefix + "keygen/no-home", gfg_test_generating_a_key_without_a_home_directory_is_reported);
    Test.add_func(prefix + "keygen/ssh-dir-blocked", gfg_test_an_ssh_directory_that_cannot_be_created_is_reported);
    Test.add_func(prefix + "copy-key/copies", gfg_test_the_public_key_is_copied);
    Test.add_func(prefix + "copy-key/no-key", gfg_test_copying_with_no_key_says_so);
    Test.add_func(prefix + "copy-key/no-clipboard", gfg_test_copying_the_key_without_a_clipboard_is_reported);
    Test.add_func(prefix + "open-keys/launches", gfg_test_the_github_keys_page_is_opened);
    Test.add_func(prefix + "open-keys/failure", gfg_test_a_browser_that_cannot_be_opened_is_reported);
    Test.add_func(prefix + "repo/verify-found", gfg_test_an_existing_repository_moves_on_to_the_push_page);
    Test.add_func(prefix + "repo/verify-missing", gfg_test_a_missing_repository_is_explained_and_stays_on_the_page);
    Test.add_func(prefix + "repo/verify-after-going-back", gfg_test_a_slow_repository_check_does_not_pull_the_user_forward);
    Test.add_func(prefix + "repo/create", gfg_test_a_repository_is_created_with_the_cli);
    Test.add_func(prefix + "repo/create-existing", gfg_test_an_existing_repository_is_reused_when_creating);
    Test.add_func(prefix + "repo/create-failure", gfg_test_a_repository_that_cannot_be_created_is_reported);
    Test.add_func(prefix + "repo/create-needs-input", gfg_test_creating_a_repository_needs_a_username_and_a_name);
    Test.add_func(prefix + "repo/create-after-going-back", gfg_test_a_slow_repository_creation_does_not_pull_the_user_forward);
    Test.add_func(prefix + "push/success", gfg_test_pushing_saves_the_remote_and_shows_the_configured_state);
    Test.add_func(prefix + "push/backend-failure", gfg_test_a_backend_failure_while_pushing_is_reported_and_can_be_retried);
    Test.add_func(prefix + "push/needs-project", gfg_test_pushing_needs_a_project);
    Test.add_func(prefix + "push/needs-api", gfg_test_pushing_needs_the_backend);
    Test.add_func(prefix + "push/needs-repository", gfg_test_pushing_without_a_repository_goes_back_to_the_repository_page);
    Test.add_func(prefix + "push/wrong-project", gfg_test_a_repository_set_up_for_one_project_is_not_pushed_to_another);
    Test.add_func(prefix + "push/project-chosen-later", gfg_test_a_repository_checked_before_any_project_was_selected_can_be_pushed);
}

}
