using GLib;

namespace HolderLinuxTests {

// Guided flow tests that never need a working gh/git/ssh: navigation, input validation and the
// no-key SSH page. Anything that reaches ~/.ssh first checks that HOME was redirected.
private GitSyncViewHarness? gsg_start(string? remote = null,
                                      bool with_project = true,
                                      bool with_api = true) {
    if (!GitSyncViewEnv.require_home()) {
        return null;
    }
    GitSyncViewEnv.reset();
    return new GitSyncViewHarness(remote, with_project, with_api);
}

private void gsg_test_the_username_page_gates_next_on_a_username() {
    var h = gsg_start();
    if (h == null) return;
    ((!) h).setup_button("Guided (I'm new to this)").clicked();
    assert(((!) h).page() == "guided-part1");
    var next = gsv_button(((!) h).child_page("guided-part1"), "Next");
    assert(!next.get_sensitive());

    ((!) h).username_entry().set_text("   ");
    assert(!next.get_sensitive());
    ((!) h).username_entry().set_text("  octocat ");
    assert(next.get_sensitive());

    gsv_button(((!) h).child_page("guided-part1"), "Back").clicked();
    assert(((!) h).page() == "start");
}

private void gsg_test_next_opens_the_ssh_page_with_a_noreply_email() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.username_entry().set_text("octocat");
    harness.click("guided-part1", "Next");

    assert(harness.page() == "guided-part2");
    assert(harness.email_entry().get_text() == "octocat@users.noreply.github.com");
    assert(harness.ssh_status().get_text() == "No SSH key found. Enter your email address and generate one.");
    assert(harness.missing_key_box().get_visible());
    assert(!harness.key_ready_box().get_visible());
    assert(harness.open_keys_button().get_visible());
}

private void gsg_test_an_email_the_user_typed_is_kept() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.email_entry().set_text("me@example.org");
    harness.username_entry().set_text("octocat");
    harness.click("guided-part1", "Next");

    assert(harness.page() == "guided-part2");
    assert(harness.email_entry().get_text() == "me@example.org");
}

private void gsg_test_a_blank_username_does_not_invent_an_email() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.click("guided-part1", "Next");

    assert(harness.page() == "guided-part2");
    assert(harness.email_entry().get_text() == "");
}

private void gsg_test_ssh_page_navigation_and_recheck() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.main_stack().set_visible_child_name("guided-part2");

    harness.click("guided-part2", "Re-check");
    assert(harness.ssh_status().get_text() == "No SSH key found. Enter your email address and generate one.");

    harness.click("guided-part2", "Back");
    assert(harness.page() == "guided-part1");

    harness.main_stack().set_visible_child_name("guided-part2");
    harness.click("guided-part2", "Next");
    assert(harness.page() == "guided-part3");
    assert(harness.repo_name_entry().get_text() == "Runbook Project");
}

private void gsg_test_generating_a_key_needs_an_email() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.click("guided-part2", "Generate SSH Key");

    assert(harness.toasts.size == 1 && harness.toasts[0] == "Email address is required.");
    assert(!GitSyncViewEnv.shims_available || !GitSyncViewEnv.ran("ssh-keygen"));
}

private void gsg_test_an_existing_private_key_is_reused_without_running_ssh_keygen() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    GitSyncViewEnv.write_ssh_file("id_ed25519", "existing private key");
    harness.email_entry().set_text("me@example.org");
    harness.click("guided-part2", "Generate SSH Key");

    assert(harness.toasts.contains("Using existing id_ed25519 key."));
    assert(!GitSyncViewEnv.shims_available || !GitSyncViewEnv.ran("ssh-keygen"));
    // The private key has no public half, so the re-check still finds no usable key.
    assert(harness.ssh_status().get_text() == "No SSH key found. Enter your email address and generate one.");
    GitSyncViewEnv.clear_ssh_dir();
}

private void gsg_test_an_unusable_ssh_directory_is_reported() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    try {
        FileUtils.set_contents(GitSyncViewEnv.ssh_dir(), "not a directory");
    } catch (Error e) {
        assert_not_reached();
    }
    harness.email_entry().set_text("me@example.org");
    harness.click("guided-part2", "Generate SSH Key");

    assert(harness.errors.size == 1);
    assert(harness.errors[0].has_prefix("SSH key generation failed|Could not create "));
    assert(harness.toasts.size == 0);
    GitSyncViewEnv.clear_ssh_dir();
}

private void gsg_test_copying_without_a_public_key_says_so() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.click("guided-part2", "Copy Public Key");

    assert(harness.toasts.size == 1 && harness.toasts[0] == "No public key to copy.");
}

private void gsg_test_the_repository_page_starts_without_github_cli() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    assert(harness.repo_mode().get_text() == "Create a private repository for this project.");
    assert(!harness.create_repo_cli_button().get_visible());
    assert(harness.repo_name_entry().get_text() == "Runbook Project");
    // Building the repository page applies the "nothing detected yet" CLI presentation.
    assert(!harness.setup_button("Use GitHub CLI (Automatic)").get_visible());
    assert(!harness.setup_button("Use GitHub CLI (Automatic)").get_sensitive());
    assert(harness.cli_status().get_text() ==
           "GitHub CLI not detected. Install `gh` to enable automatic username and repo creation.");
}

private void gsg_test_typing_a_repository_name_clears_the_status() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.repo_status().set_text("Something went wrong");
    harness.repo_name_entry().set_text("runbook");

    assert(harness.repo_status().get_text() == "");
}

private void gsg_test_verifying_needs_a_username_and_goes_back_to_ask() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.main_stack().set_visible_child_name("guided-part3");
    harness.click("guided-part3", "Next");

    assert(harness.toasts.size == 1 && harness.toasts[0] == "GitHub username is required.");
    assert(harness.page() == "guided-part1");
    assert(!GitSyncViewEnv.shims_available || !GitSyncViewEnv.ran("ls-remote"));
}

private void gsg_test_verifying_needs_a_repository_name_and_stays_put() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.username_entry().set_text("octocat");
    harness.main_stack().set_visible_child_name("guided-part3");
    harness.repo_name_entry().set_text("   ");
    harness.click("guided-part3", "Next");

    assert(harness.toasts.size == 1 && harness.toasts[0] == "Repository name is required.");
    assert(harness.page() == "guided-part3");
    assert(!GitSyncViewEnv.shims_available || !GitSyncViewEnv.ran("ls-remote"));
}

private void gsg_test_creating_a_repository_needs_both_names() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.main_stack().set_visible_child_name("guided-part3");
    harness.create_repo_cli_button().clicked();

    assert(harness.toasts.size == 1);
    assert(harness.toasts[0] == "GitHub username and repository name are required.");
    assert(harness.page() == "guided-part3");
    assert(!GitSyncViewEnv.shims_available || !GitSyncViewEnv.ran("gh repo create"));
}

private void gsg_test_repository_page_back_returns_to_the_ssh_page() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.main_stack().set_visible_child_name("guided-part3");
    harness.click("guided-part3", "Back");

    assert(harness.page() == "guided-part2");
}

private void gsg_test_pushing_before_a_repository_is_verified_sends_you_back() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.main_stack().set_visible_child_name("guided-part4");
    harness.click("guided-part4", "Push Cards");

    assert(harness.toasts.size == 1);
    assert(harness.toasts[0] == "GitHub username and repository name are required.");
    assert(harness.page() == "guided-part3");
    assert(harness.api.set_project_git_remote_calls == 0);

    harness.main_stack().set_visible_child_name("guided-part4");
    harness.click("guided-part4", "Back");
    assert(harness.page() == "guided-part3");
}

private void gsg_test_automatic_setup_validates_its_inputs_in_order() {
    var no_project = gsg_start(null, false);
    if (no_project == null) return;
    ((!) no_project).setup_button("Use GitHub CLI (Automatic)").clicked();
    assert(((!) no_project).toasts.size == 1 && ((!) no_project).toasts[0] == "Select a project first.");

    var no_api = gsg_start(null, true, false);
    if (no_api == null) return;
    ((!) no_api).setup_button("Use GitHub CLI (Automatic)").clicked();
    assert(((!) no_api).errors.size == 1);
    assert(((!) no_api).errors[0] == "Git sync failed|Backend API client is not ready.");

    var unauthenticated = gsg_start();
    if (unauthenticated == null) return;
    ((!) unauthenticated).setup_button("Use GitHub CLI (Automatic)").clicked();
    assert(((!) unauthenticated).toasts.size == 1);
    assert(((!) unauthenticated).toasts[0] == "GitHub CLI is not authenticated. Run `gh auth login` first.");
    assert(((!) unauthenticated).api.set_project_git_remote_calls == 0);
    assert(!GitSyncViewEnv.shims_available || !GitSyncViewEnv.ran("gh repo create"));
}

private void gsg_test_the_guided_cli_shortcut_without_a_login_only_moves_on() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.setup_button("Use GitHub CLI (auto-fill username)").clicked();

    assert(harness.page() == "guided-part2");
    assert(harness.username_entry().get_text() == "");
    assert(harness.email_entry().get_text() == "");
    assert(harness.ssh_status().get_text() == "No SSH key found. Enter your email address and generate one.");
}

private void gsg_test_changing_project_refreshes_the_guided_repository_name() {
    var h = gsg_start();
    if (h == null) return;
    var harness = (!) h;
    harness.store.append(gsv_project("p2", "Second Project", null));
    assert(harness.repo_name_entry().get_text() == "Runbook Project");

    harness.selection.set_selected(1);
    assert(harness.repo_name_entry().get_text() == "Second Project");

    harness.select_none();
    assert(harness.repo_name_entry().get_text() == "");
}

public void register_git_sync_view_guided_tests() {
    var prefix = "/holder/git-sync-view/guided/";
    Test.add_func(prefix + "username-gates-next", gsg_test_the_username_page_gates_next_on_a_username);
    Test.add_func(prefix + "ssh-page-defaults", gsg_test_next_opens_the_ssh_page_with_a_noreply_email);
    Test.add_func(prefix + "typed-email-kept", gsg_test_an_email_the_user_typed_is_kept);
    Test.add_func(prefix + "blank-username-no-email", gsg_test_a_blank_username_does_not_invent_an_email);
    Test.add_func(prefix + "ssh-navigation", gsg_test_ssh_page_navigation_and_recheck);
    Test.add_func(prefix + "keygen/needs-email", gsg_test_generating_a_key_needs_an_email);
    Test.add_func(prefix + "keygen/existing-key", gsg_test_an_existing_private_key_is_reused_without_running_ssh_keygen);
    Test.add_func(prefix + "keygen/bad-directory", gsg_test_an_unusable_ssh_directory_is_reported);
    Test.add_func(prefix + "copy-without-key", gsg_test_copying_without_a_public_key_says_so);
    Test.add_func(prefix + "repository/initial", gsg_test_the_repository_page_starts_without_github_cli);
    Test.add_func(prefix + "repository/typing-clears-status", gsg_test_typing_a_repository_name_clears_the_status);
    Test.add_func(prefix + "repository/needs-username", gsg_test_verifying_needs_a_username_and_goes_back_to_ask);
    Test.add_func(prefix + "repository/needs-name", gsg_test_verifying_needs_a_repository_name_and_stays_put);
    Test.add_func(prefix + "repository/create-needs-names", gsg_test_creating_a_repository_needs_both_names);
    Test.add_func(prefix + "repository/back", gsg_test_repository_page_back_returns_to_the_ssh_page);
    Test.add_func(prefix + "push/unverified", gsg_test_pushing_before_a_repository_is_verified_sends_you_back);
    Test.add_func(prefix + "automatic/validation", gsg_test_automatic_setup_validates_its_inputs_in_order);
    Test.add_func(prefix + "cli-shortcut-no-login", gsg_test_the_guided_cli_shortcut_without_a_login_only_moves_on);
    Test.add_func(prefix + "project-change", gsg_test_changing_project_refreshes_the_guided_repository_name);
}

}
