using GLib;

namespace HolderLinuxTests {

private HolderLinux.Project make_project(string id, string? remote_url, string name = "Family Notes") {
    return new HolderLinux.Project(id, name, "encrypted_git", "/tmp/" + id, 10, 20, remote_url, null, 3, 2);
}

private Gee.ArrayList<HolderLinux.Project> project_list(HolderLinux.Project first, HolderLinux.Project? second = null) {
    var list = new Gee.ArrayList<HolderLinux.Project>();
    list.add(first);
    if (second != null) {
        list.add(second);
    }
    return list;
}

private HolderLinux.GitProviderCatalogEntry make_entry(string id, string name, string preferred, string transports) {
    return new HolderLinux.GitProviderCatalogEntry(id, name, "hosted", preferred, transports, "", "");
}

private HolderLinux.GitPushResult make_push(string status, string error_message = "") {
    return new HolderLinux.GitPushResult("p1", "git@x:y/z.git", "main", status, 0, 0, "abc", "", error_message, "");
}

// --- GitSyncProjectState -------------------------------------------------

private void test_project_state_refresh_generation_goes_stale() {
    var state = new HolderLinux.GitSyncProjectState();
    var first = state.begin_refresh();
    assert(state.is_current(first));
    var second = state.begin_refresh();
    assert(!state.is_current(first));
    assert(state.is_current(second));
}

private void test_project_state_resolve_refreshed_project() {
    var state = new HolderLinux.GitSyncProjectState();
    var p1 = make_project("p1", null);
    var p2 = make_project("p2", "git@github.com:a/b.git");
    var list = project_list(p1, p2);

    assert(state.resolve_refreshed_project(list, "p2") == p2);
    assert(state.resolve_refreshed_project(list, "missing") == null);

    // The local "disconnected" flag survives while the backend still reports a remote...
    state.locally_disconnected_project_id = "p2";
    assert(state.resolve_refreshed_project(list, "p2") == p2);
    assert(state.locally_disconnected_project_id == "p2");

    // ...and clears once the backend reports no (or a blank) remote.
    state.locally_disconnected_project_id = "p1";
    assert(state.resolve_refreshed_project(list, "p1") == p1);
    assert(state.locally_disconnected_project_id == "");

    state.locally_disconnected_project_id = "p3";
    var blank = make_project("p3", "   ");
    assert(state.resolve_refreshed_project(project_list(blank), "p3") == blank);
    assert(state.locally_disconnected_project_id == "");

    // A different project's flag is left alone.
    state.locally_disconnected_project_id = "other";
    state.resolve_refreshed_project(list, "p1");
    assert(state.locally_disconnected_project_id == "other");
}

private void test_project_state_select_page() {
    var state = new HolderLinux.GitSyncProjectState();

    var page = state.select_page(null);
    assert(page.show_setup);
    assert(!page.cancel_visible);

    page = state.select_page(make_project("p1", null));
    assert(page.show_setup);
    assert(state.configured_project == null);

    page = state.select_page(make_project("p1", "  "));
    assert(page.show_setup);

    var configured = make_project("p1", "git@github.com:a/b.git");
    page = state.select_page(configured);
    assert(!page.show_setup);
    assert(!page.cancel_visible);
    assert(state.configured_project == configured);

    // Editing forces the setup page, and Cancel is offered because a configured project exists.
    state.editing_remote = true;
    page = state.select_page(configured);
    assert(page.show_setup);
    assert(page.cancel_visible);

    // A locally disconnected project shows setup even though the snapshot still has a remote.
    state.editing_remote = false;
    state.locally_disconnected_project_id = "p1";
    page = state.select_page(configured);
    assert(page.show_setup);
    assert(!page.cancel_visible);
}

private void test_project_state_editing_without_configured_project_hides_cancel() {
    var state = new HolderLinux.GitSyncProjectState();
    state.editing_remote = true;
    var page = state.select_page(make_project("p1", null));
    assert(page.show_setup);
    assert(!page.cancel_visible);
}

private void test_project_state_connect_and_disconnect_transitions() {
    var state = new HolderLinux.GitSyncProjectState();
    var configured = make_project("p1", "git@github.com:a/b.git");
    state.select_page(configured);
    var generation = state.begin_refresh();
    state.editing_remote = true;

    state.mark_disconnected("p1");
    assert(!state.is_current(generation));
    assert(state.locally_disconnected_project_id == "p1");
    assert(state.configured_project == null);
    assert(!state.editing_remote);

    state.editing_remote = true;
    state.mark_connected();
    assert(state.locally_disconnected_project_id == "");
    assert(!state.editing_remote);
}

private void test_project_snapshot_with_remote_copies_everything_but_the_remote() {
    var source = make_project("p1", null, "Notes");
    var copy = HolderLinux.GitSyncProjectState.project_snapshot_with_remote(source, "git@github.com:a/b.git");
    assert(copy.project_id == "p1");
    assert(copy.name == "Notes");
    assert(copy.privacy_mode == "encrypted_git");
    assert(copy.root_path == "/tmp/p1");
    assert(copy.created_at == 10);
    assert(copy.updated_at == 20);
    assert(copy.git_remote_url == "git@github.com:a/b.git");
    assert(copy.sync == source.sync);
    assert(copy.card_count == 3);
    assert(copy.root_card_count == 2);
}

// --- GitSyncValidation ---------------------------------------------------

private void test_validation_project_and_api() {
    var missing_project = HolderLinux.GitSyncValidation.project_and_api(null, true);
    assert(!missing_project.ok && missing_project.is_toast);
    assert(missing_project.message == "Select a project first.");

    var missing_api = HolderLinux.GitSyncValidation.project_and_api(make_project("p1", null), false);
    assert(!missing_api.ok && !missing_api.is_toast);
    assert(missing_api.error_title == "Git sync failed");
    assert(missing_api.error_details == "Backend API client is not ready.");

    assert(HolderLinux.GitSyncValidation.project_and_api(make_project("p1", null), true).ok);
}

private void test_validation_auto_sync_inputs() {
    var project = make_project("p1", null);
    assert(HolderLinux.GitSyncValidation.auto_sync_inputs(null, true, true, "me").message == "Select a project first.");
    assert(HolderLinux.GitSyncValidation.auto_sync_inputs(project, false, true, "me").error_title == "Git sync failed");

    var unauthenticated = HolderLinux.GitSyncValidation.auto_sync_inputs(project, true, false, "me");
    assert(!unauthenticated.ok && unauthenticated.is_toast);
    assert(unauthenticated.message == "GitHub CLI is not authenticated. Run `gh auth login` first.");

    var blank_login = HolderLinux.GitSyncValidation.auto_sync_inputs(project, true, true, "   ");
    assert(!blank_login.ok && blank_login.is_toast);

    assert(HolderLinux.GitSyncValidation.auto_sync_inputs(project, true, true, "me").ok);
}

private void test_validation_guided_repo_inputs() {
    assert(HolderLinux.GitSyncValidation.cli_repo_inputs("me", "repo").ok);
    var cli_missing = HolderLinux.GitSyncValidation.cli_repo_inputs("", "repo");
    assert(!cli_missing.ok);
    assert(cli_missing.toast_message == "GitHub username and repository name are required.");
    assert(cli_missing.retreat == HolderLinux.GuidedRetreat.NONE);
    assert(!HolderLinux.GitSyncValidation.cli_repo_inputs("me", "").ok);

    assert(HolderLinux.GitSyncValidation.verify_repo_inputs("me", "repo").ok);
    var verify_no_user = HolderLinux.GitSyncValidation.verify_repo_inputs("", "repo");
    assert(!verify_no_user.ok);
    assert(verify_no_user.toast_message == "GitHub username is required.");
    assert(verify_no_user.retreat == HolderLinux.GuidedRetreat.USERNAME_PAGE);
    var verify_no_repo = HolderLinux.GitSyncValidation.verify_repo_inputs("me", "");
    assert(!verify_no_repo.ok);
    assert(verify_no_repo.toast_message == "Repository name is required.");
    assert(verify_no_repo.retreat == HolderLinux.GuidedRetreat.NONE);

    assert(HolderLinux.GitSyncValidation.push_inputs("me", "repo").ok);
    var push_no_user = HolderLinux.GitSyncValidation.push_inputs("", "repo");
    assert(!push_no_user.ok);
    assert(push_no_user.retreat == HolderLinux.GuidedRetreat.REPOSITORY_PAGE);
    assert(push_no_user.toast_message == "GitHub username and repository name are required.");
    assert(!HolderLinux.GitSyncValidation.push_inputs("me", "").ok);
}

// --- GitSyncGuided -------------------------------------------------------

private void test_guided_remote_and_messages() {
    assert(HolderLinux.GitSyncGuided.github_ssh_remote("me", "repo") == "git@github.com:me/repo.git");
    assert(HolderLinux.GitSyncGuided.push_intro_text("me", "repo")
           == "We'll now save this remote and push your cards.\nRemote: git@github.com:me/repo.git");
    assert(HolderLinux.GitSyncGuided.repo_create_status(true) == "Repository created with GitHub CLI and verified.");
    assert(HolderLinux.GitSyncGuided.repo_create_status(false) == "Repository available and verified.");
    assert(HolderLinux.GitSyncGuided.create_failure_details("  boom  ") == "boom");
    assert(HolderLinux.GitSyncGuided.create_failure_details("  ") == "Repository could not be created.");
    assert(HolderLinux.GitSyncGuided.auto_sync_progress("me", "repo")
           == "GitHub CLI: creating private repo `me/repo`...");
}

private void test_guided_defaults() {
    assert(HolderLinux.GitSyncGuided.noreply_email("  me  ") == "me@users.noreply.github.com");
    assert(HolderLinux.GitSyncGuided.noreply_email("   ") == "");

    assert(HolderLinux.GitSyncGuided.resolve_username("  typed ", "saved") == "typed");
    assert(HolderLinux.GitSyncGuided.resolve_username("  ", "saved") == "saved");

    assert(HolderLinux.GitSyncGuided.prefill_username("cli-user", "saved") == "cli-user");
    assert(HolderLinux.GitSyncGuided.prefill_username("  ", "saved") == "saved");

    assert(HolderLinux.GitSyncGuided.default_repo_name(make_project("p1", null, "My Notes")) == "My Notes");
    assert(HolderLinux.GitSyncGuided.default_repo_name(null) == "");

    assert(HolderLinux.GitSyncGuided.provider_namespace_default("", "me") == "me");
    assert(HolderLinux.GitSyncGuided.provider_namespace_default("  ", "me") == "me");
    assert(HolderLinux.GitSyncGuided.provider_namespace_default("existing", "me") == null);
    assert(HolderLinux.GitSyncGuided.provider_namespace_default("", "") == null);
}

// --- GitProviderOptions --------------------------------------------------

private void test_provider_transport_options_parse_and_prefer() {
    var options = HolderLinux.GitProviderOptions.transport_options(
        make_entry("gitlab", "GitLab", "https", " ssh , https ,, ")
    );
    assert(options.options.size == 2);
    assert(options.options[0] == "ssh");
    assert(options.options[1] == "https");
    assert(options.selected_index == 1);

    var unknown_preferred = HolderLinux.GitProviderOptions.transport_options(
        make_entry("x", "X", "carrier-pigeon", "ssh,https")
    );
    assert(unknown_preferred.selected_index == 0);

    var no_preferred = HolderLinux.GitProviderOptions.transport_options(
        make_entry("x", "X", "  ", "https,ssh")
    );
    assert(no_preferred.selected_index == 0);
}

private void test_provider_transport_options_defaults() {
    var no_provider = HolderLinux.GitProviderOptions.transport_options(null);
    assert(no_provider.options.size == 2);
    assert(no_provider.options[0] == "ssh");
    assert(no_provider.options[1] == "https");
    assert(no_provider.selected_index == 0);

    var blank_summary = HolderLinux.GitProviderOptions.transport_options(make_entry("x", "X", "https", "  "));
    assert(blank_summary.options.size == 2);
    assert(blank_summary.selected_index == 1);

    var only_separators = HolderLinux.GitProviderOptions.transport_options(make_entry("x", "X", "", " , ,"));
    assert(only_separators.options.size == 2);
}

private void test_provider_label_entry_at_and_resolve_transport() {
    var github = make_entry("github", "GitHub", "ssh", "ssh,https");
    assert(HolderLinux.GitProviderOptions.provider_label(github) == "GitHub (github)");

    var entries = new Gee.ArrayList<HolderLinux.GitProviderCatalogEntry>();
    entries.add(github);
    assert(HolderLinux.GitProviderOptions.entry_at(entries, 0) == github);
    assert(HolderLinux.GitProviderOptions.entry_at(entries, 1) == null);
    assert(HolderLinux.GitProviderOptions.entry_at(entries, uint.MAX) == null);

    var transports = new Gee.ArrayList<string>();
    assert(HolderLinux.GitProviderOptions.resolve_transport(transports, 0) == "ssh");
    transports.add("https");
    transports.add("ssh");
    assert(HolderLinux.GitProviderOptions.resolve_transport(transports, 1) == "ssh");
    assert(HolderLinux.GitProviderOptions.resolve_transport(transports, 7) == "https");
    assert(HolderLinux.GitProviderOptions.resolve_transport(transports, uint.MAX) == "https");
}

// --- GitSyncOutcomes -----------------------------------------------------

private void test_outcomes_for_push_result() {
    var pushed = HolderLinux.GitSyncOutcomes.for_push_result(make_push("pushed"));
    assert(pushed.toast_message == "Project synced.");
    assert(pushed.error_title == "");
    assert(pushed.history_changed);

    var up_to_date = HolderLinux.GitSyncOutcomes.for_push_result(make_push("up_to_date"));
    assert(up_to_date.toast_message == "Project is already up to date.");
    assert(up_to_date.history_changed);

    var failed = HolderLinux.GitSyncOutcomes.for_push_result(make_push("failed", "  auth rejected  "));
    assert(failed.error_title == "Git sync failed");
    assert(failed.error_details == "auth rejected");
    assert(failed.toast_message == "");
    assert(!failed.history_changed);

    var unknown = HolderLinux.GitSyncOutcomes.for_push_result(make_push("weird"));
    assert(unknown.error_details == "Git sync returned: weird");
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/git-sync-rules/project-state/generation", test_project_state_refresh_generation_goes_stale);
    Test.add_func("/git-sync-rules/project-state/resolve-refreshed", test_project_state_resolve_refreshed_project);
    Test.add_func("/git-sync-rules/project-state/select-page", test_project_state_select_page);
    Test.add_func("/git-sync-rules/project-state/editing-without-configured",
                  test_project_state_editing_without_configured_project_hides_cancel);
    Test.add_func("/git-sync-rules/project-state/transitions", test_project_state_connect_and_disconnect_transitions);
    Test.add_func("/git-sync-rules/project-state/snapshot-with-remote",
                  test_project_snapshot_with_remote_copies_everything_but_the_remote);
    Test.add_func("/git-sync-rules/validation/project-and-api", test_validation_project_and_api);
    Test.add_func("/git-sync-rules/validation/auto-sync", test_validation_auto_sync_inputs);
    Test.add_func("/git-sync-rules/validation/guided-repo", test_validation_guided_repo_inputs);
    Test.add_func("/git-sync-rules/guided/remote-and-messages", test_guided_remote_and_messages);
    Test.add_func("/git-sync-rules/guided/defaults", test_guided_defaults);
    Test.add_func("/git-sync-rules/provider/transport-parse", test_provider_transport_options_parse_and_prefer);
    Test.add_func("/git-sync-rules/provider/transport-defaults", test_provider_transport_options_defaults);
    Test.add_func("/git-sync-rules/provider/label-entry-resolve", test_provider_label_entry_at_and_resolve_transport);
    Test.add_func("/git-sync-rules/outcomes/push-result", test_outcomes_for_push_result);

    return Test.run();
}

}
