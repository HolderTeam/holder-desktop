using GLib;

namespace HolderLinuxTests {

private const string GSU_URL = "https://github.com/HolderTeam/runbook.git";

private GitSyncViewHarness gsu_unconfigured() {
    return new GitSyncViewHarness(null);
}

private void gsu_test_manual_setup_requires_a_remote_url() {
    var h = gsu_unconfigured();
    assert(h.remote_entry().get_text() == "");
    h.setup_button("Save").clicked();

    assert(h.toasts.size == 1 && h.toasts[0] == "Remote URL is required.");
    assert(h.api.set_project_git_remote_calls == 0);
    assert(h.state_page() == "setup");

    // Whitespace only counts as empty.
    h.remote_entry().set_text("   ");
    h.setup_button("Save").clicked();
    assert(h.toasts.size == 2);
    assert(h.api.set_project_git_remote_calls == 0);
}

private void gsu_test_manual_setup_needs_a_selected_project() {
    var h = new GitSyncViewHarness(null, false);
    h.remote_entry().set_text(GSU_URL);
    h.setup_button("Save").clicked();

    assert(h.toasts.size == 1 && h.toasts[0] == "Select a project first.");
    assert(h.api.set_project_git_remote_calls == 0);
}

private void gsu_test_manual_setup_needs_an_api_client() {
    var h = new GitSyncViewHarness(null, true, false);
    h.remote_entry().set_text(GSU_URL);
    h.setup_button("Save").clicked();

    assert(h.errors.size == 1 && h.errors[0] == "Git sync failed|Backend API client is not ready.");
    assert(h.toasts.size == 0);
    assert(h.setup_button("Save").get_sensitive());
}

private void gsu_test_manual_setup_saves_tests_and_pushes_with_the_branch() {
    var h = gsu_unconfigured();
    h.api.push_commit = "abc123";
    h.remote_entry().set_text("  " + GSU_URL + "  ");
    h.branch_entry().set_text(" main ");
    var save = h.setup_button("Save");
    save.clicked();

    assert(h.wait_for_toast("Git remote configured and synced."));
    h.settle();
    assert(h.api.set_project_git_remote_calls == 1);
    assert(h.api.test_project_git_remote_calls == 1);
    assert(h.api.push_project_git_calls == 1);
    assert(h.api.last_git_project_id == "p1");
    assert(h.api.last_git_remote_url == GSU_URL);
    assert(h.api.last_git_branch == "main");
    assert(h.api.last_git_set_upstream);

    var summary = h.manual_status().get_text();
    assert(summary.contains("Project: Runbook Project"));
    assert(summary.contains("Remote: " + GSU_URL));
    assert(summary.contains("Branch: main"));
    assert(summary.contains("Remote test: reachable"));
    assert(summary.contains("Push: pushed"));
    assert(h.toasts.contains("Git remote configured and synced."));
    assert(h.activities.contains("result.git.push|Git push result: pushed [local_head_commit=abc123]"));
    assert(h.page() == "start");
    assert(h.state_page() == "configured");
    assert(h.named_label("git-configured-remote").get_text() == GSU_URL);
    assert(save.get_sensitive());
}

private void gsu_test_manual_setup_without_a_branch_omits_it() {
    var h = gsu_unconfigured();
    h.remote_entry().set_text(GSU_URL);
    h.setup_button("Save").clicked();

    assert(h.wait_for_toast("Git remote configured and synced."));
    assert(h.api.last_git_branch == "");
    assert(!h.manual_status().get_text().contains("Branch:"));
}

private void gsu_test_an_unreachable_remote_skips_the_push_but_keeps_the_remote() {
    var h = gsu_unconfigured();
    h.api.test_project_git_remote_status = "unreachable";
    h.remote_entry().set_text(GSU_URL);
    h.setup_button("Save").clicked();

    assert(wait_for_condition(() => h.manual_status().get_text().contains("Push: not run")));
    h.settle();
    assert(h.api.set_project_git_remote_calls == 1);
    assert(h.api.test_project_git_remote_calls == 1);
    assert(h.api.push_project_git_calls == 0);
    var summary = h.manual_status().get_text();
    assert(summary.contains("Remote test: unreachable"));
    assert(summary.contains("Push: not run"));
    assert(h.toasts.size == 0);
    // The remote was saved, so the durable state is the configured card.
    assert(h.state_page() == "configured");
}

private void gsu_test_a_failed_push_is_described_without_a_success_toast() {
    var h = gsu_unconfigured();
    h.api.push_status = "failed";
    h.api.push_error_message = "remote rejected";
    h.api.push_next_action = "pull first";
    h.remote_entry().set_text(GSU_URL);
    h.setup_button("Save").clicked();

    assert(wait_for_condition(() => h.manual_status().get_text().contains("Push: failed")));
    h.settle();
    assert(h.api.push_project_git_calls == 1);
    var summary = h.manual_status().get_text();
    assert(summary.contains("Push: failed (remote rejected)"));
    assert(summary.contains("Next action: pull first"));
    assert(h.toasts.size == 0);
    assert(h.activities.contains("result.git.push|Git push result: failed"));
}

private void gsu_test_manual_setup_reports_each_failing_api_call() {
    string[] failing = { "set", "test", "push" };
    foreach (var stage in failing) {
        var h = gsu_unconfigured();
        h.api.fail_set_project_git_remote = stage == "set";
        h.api.fail_test_project_git_remote = stage == "test";
        h.api.fail_push_project_git = stage == "push";
        h.remote_entry().set_text(GSU_URL);
        var save = h.setup_button("Save");
        save.clicked();

        assert(wait_for_condition(() => h.errors.size == 1));
        h.settle();
        assert(h.errors.size == 1);
        assert(h.errors[0].has_prefix("Git sync failed|"));
        assert(h.manual_status().get_text().has_prefix("Git sync failed: "));
        assert(h.manual_status().get_text().has_suffix(" failed"));
        assert(h.state_page() == "setup");
        assert(h.page() == "start");
        assert(h.toasts.size == 0);
        assert(save.get_sensitive());
    }
}

private void gsu_test_manual_setup_shows_progress_while_saving() {
    var h = gsu_unconfigured();
    h.remote_entry().set_text(GSU_URL);
    var save = h.setup_button("Save");
    h.api.stall_next_push = true;
    save.clicked();

    // Saving and testing go through the (fake) backend first; the push is what stalls.
    assert(wait_for_condition(() => h.api.has_stalled_push()));
    assert(!save.get_sensitive());
    assert(h.manual_status().get_text() == "Saving remote and testing connectivity...");
    assert(h.api.set_project_git_remote_calls == 1);
    assert(h.state_page() == "setup");

    h.api.release_stalled_push();
    assert(h.wait_for_toast("Git remote configured and synced."));
    h.settle();
    assert(save.get_sensitive());
    assert(h.state_page() == "configured");
}

private HolderLinux.GitProviderCatalogEntry gsu_github() {
    return gsv_provider(
        "github", "GitHub", "ssh", "ssh,https",
        "git@github.com:{owner}/{repo}.git", "https://github.com/{owner}/{repo}.git"
    );
}

private HolderLinux.GitProviderCatalogEntry gsu_self_hosted() {
    return gsv_provider(
        "selfhosted", "Self Hosted", "https", " https , ssh ,, ",
        "git@{host}:{owner}/{repo}.git", "https://{host}/{owner}/{repo}.git"
    );
}

private GitSyncViewHarness gsu_provider_harness(bool with_catalog = true) {
    var h = gsu_unconfigured();
    if (with_catalog) {
        h.api.provider_catalog.add(gsu_github());
        h.api.provider_catalog.add(gsu_self_hosted());
    }
    return h;
}

private GitSyncProviderUi gsu_open_provider_page(GitSyncViewHarness h) {
    h.setup_button("Provider setup (I know git)").clicked();
    h.settle();
    assert(h.page() == "provider");
    return new GitSyncProviderUi(h);
}

private void gsu_test_provider_page_loads_the_catalog_and_previews_the_remote() {
    var h = gsu_provider_harness();
    var ui = gsu_open_provider_page(h);

    assert(h.api.provider_catalog_calls == 1);
    string[] providers = ui.provider_choices();
    assert(providers.length == 2);
    assert(providers[0] == "GitHub (github)");
    assert(providers[1] == "Self Hosted (selfhosted)");
    assert(ui.provider.get_selected() == 0);
    string[] transports = ui.transport_choices();
    assert(transports.length == 2 && transports[0] == "ssh" && transports[1] == "https");
    assert(ui.transport.get_selected() == 0);

    // The repository defaults from the project name; the namespace is left for the user.
    assert(ui.repo.get_text() == "Runbook-Project");
    assert(ui.namespace_entry.get_text() == "");
    assert(!ui.host_row.get_visible());
    assert(ui.template_label.get_text() ==
           "Template: git@github.com:{owner}/{repo}.git\nYou can edit Remote URL directly before saving.");

    ui.namespace_entry.set_text("octo");
    assert(ui.remote.get_text() == "git@github.com:octo/Runbook-Project.git");
}

private void gsu_test_changing_transport_and_fields_rebuilds_the_preview() {
    var h = gsu_provider_harness();
    var ui = gsu_open_provider_page(h);
    ui.namespace_entry.set_text("octo");

    ui.transport.set_selected(1);
    assert(ui.remote.get_text() == "https://github.com/octo/Runbook-Project.git");

    ui.repo.set_text("  other  ");
    assert(ui.remote.get_text() == "https://github.com/octo/other.git");

    ui.transport.set_selected(0);
    assert(ui.remote.get_text() == "git@github.com:octo/other.git");
}

private void gsu_test_a_provider_with_a_host_template_shows_the_host_row() {
    var h = gsu_provider_harness();
    var ui = gsu_open_provider_page(h);
    ui.namespace_entry.set_text("octo");

    ui.provider.set_selected(1);
    // Choices are trimmed, blanks dropped, and the provider's preferred transport is selected.
    string[] transports = ui.transport_choices();
    assert(transports.length == 2 && transports[0] == "https" && transports[1] == "ssh");
    assert(ui.transport.get_selected() == 0);
    assert(ui.host_row.get_visible());

    ui.host.set_text(" git.example.com ");
    assert(ui.remote.get_text() == "https://git.example.com/octo/Runbook-Project.git");

    // Going back to a provider without a host placeholder hides and clears the host.
    ui.provider.set_selected(0);
    assert(!ui.host_row.get_visible());
    assert(ui.host.get_text() == "");
    assert(ui.remote.get_text() == "git@github.com:octo/Runbook-Project.git");
}

private void gsu_test_a_provider_without_templates_falls_back_to_generic_ones() {
    var h = gsu_unconfigured();
    h.api.provider_catalog.add(gsv_provider("custom", "Custom", "", ""));
    var ui = gsu_open_provider_page(h);
    ui.namespace_entry.set_text("octo");
    ui.host.set_text("git.example.com");

    string[] transports = ui.transport_choices();
    assert(transports.length == 2 && transports[0] == "ssh" && transports[1] == "https");
    assert(ui.host_row.get_visible());
    assert(ui.remote.get_text() == "git@git.example.com:octo/Runbook-Project.git");
    ui.transport.set_selected(1);
    assert(ui.remote.get_text() == "https://git.example.com/octo/Runbook-Project.git");
}

private void gsu_test_an_empty_catalog_leaves_no_provider_selected() {
    var h = gsu_provider_harness(false);
    var ui = gsu_open_provider_page(h);

    assert(h.api.provider_catalog_calls == 1);
    assert(ui.provider_choices().length == 0);
    assert(ui.remote.get_text() == "");
    assert(ui.template_label.get_text() == "No provider selected.");
    string[] transports = ui.transport_choices();
    assert(transports.length == 2 && transports[0] == "ssh");
}

private void gsu_test_a_failed_catalog_load_is_reported() {
    var h = gsu_provider_harness();
    h.api.fail_provider_catalog = true;
    var ui = gsu_open_provider_page(h);

    assert(ui.status.get_text() == "Provider catalog load failed: provider catalog failed");
    assert(h.errors.size == 1);
    assert(h.errors[0] == "Git provider catalog refresh failed|provider catalog failed");
    assert(ui.provider_choices().length == 0);
}

private void gsu_test_the_catalog_is_not_loaded_without_an_api_client() {
    var h = new GitSyncViewHarness(null, true, false);
    var ui = gsu_open_provider_page(h);

    assert(h.api.provider_catalog_calls == 0);
    assert(ui.provider_choices().length == 0);
    assert(h.errors.size == 0);
}

private void gsu_test_reopening_the_provider_page_replaces_the_catalog() {
    var h = gsu_provider_harness();
    var ui = gsu_open_provider_page(h);
    assert(ui.provider_choices().length == 2);

    ui.back.clicked();
    assert(h.page() == "start");

    h.api.provider_catalog.remove_at(1);
    h.setup_button("Provider setup (I know git)").clicked();
    h.settle();
    assert(h.api.provider_catalog_calls == 2);
    assert(ui.provider_choices().length == 1);
    assert(ui.provider.get_selected() == 0);
}

private void gsu_test_provider_setup_saves_the_previewed_remote_and_branch() {
    var h = gsu_provider_harness();
    var ui = gsu_open_provider_page(h);
    ui.namespace_entry.set_text("octo");
    ui.branch.set_text(" trunk ");
    ui.apply.clicked();

    assert(h.wait_for_toast("Git remote configured and synced."));
    h.settle();
    assert(h.api.set_project_git_remote_calls == 1);
    assert(h.api.last_git_remote_url == "git@github.com:octo/Runbook-Project.git");
    assert(h.api.last_git_branch == "trunk");
    assert(h.api.push_project_git_calls == 1);
    assert(ui.status.get_text().contains("Push: pushed"));
    assert(h.toasts.contains("Git remote configured and synced."));
    assert(h.page() == "start");
    assert(h.state_page() == "configured");
    assert(ui.apply.get_sensitive());
}

private void gsu_test_an_edited_remote_url_wins_over_the_preview() {
    var h = gsu_provider_harness();
    var ui = gsu_open_provider_page(h);
    ui.remote.set_text("  git@example.org:me/mine.git  ");
    ui.apply.clicked();

    assert(h.wait_for_toast("Git remote configured and synced."));
    assert(h.api.last_git_remote_url == "git@example.org:me/mine.git");
}

private void gsu_test_provider_setup_needs_a_remote_url() {
    var h = gsu_provider_harness(false);
    var ui = gsu_open_provider_page(h);
    ui.apply.clicked();

    assert(h.toasts.size == 1 && h.toasts[0] == "Remote URL is required.");
    assert(h.api.set_project_git_remote_calls == 0);
}

private void gsu_test_provider_setup_needs_a_project_and_an_api_client() {
    var no_project = new GitSyncViewHarness(null, false);
    no_project.api.provider_catalog.add(gsu_github());
    var no_project_ui = gsu_open_provider_page(no_project);
    no_project_ui.remote.set_text(GSU_URL);
    no_project_ui.apply.clicked();
    assert(no_project.toasts.size == 1 && no_project.toasts[0] == "Select a project first.");

    var no_api = new GitSyncViewHarness(null, true, false);
    var no_api_ui = gsu_open_provider_page(no_api);
    no_api_ui.remote.set_text(GSU_URL);
    no_api_ui.apply.clicked();
    assert(no_api.errors.size == 1);
    assert(no_api.errors[0] == "Git sync failed|Backend API client is not ready.");
}

private void gsu_test_provider_setup_reports_an_api_failure_on_its_own_status_line() {
    var h = gsu_provider_harness();
    var ui = gsu_open_provider_page(h);
    ui.namespace_entry.set_text("octo");
    h.api.fail_test_project_git_remote = true;
    ui.apply.clicked();

    assert(wait_for_condition(() => h.errors.size == 1));
    h.settle();
    assert(ui.status.get_text() == "Git sync failed: test project git remote failed");
    assert(h.errors.size == 1);
    assert(ui.apply.get_sensitive());
    assert(h.page() == "provider");
}

private void gsu_test_project_changes_refresh_the_provider_defaults() {
    var h = gsu_provider_harness();
    h.store.append(gsv_project("p2", "Second Project!", null));
    var ui = gsu_open_provider_page(h);
    assert(ui.repo.get_text() == "Runbook-Project");

    h.selection.set_selected(1);
    assert(ui.repo.get_text() == "Second-Project");
    assert(ui.remote.get_text() == "git@github.com:/Second-Project.git");
}

private void gsu_test_start_page_buttons_open_the_guided_and_provider_pages() {
    var h = gsu_unconfigured();
    h.setup_button("Guided (I'm new to this)").clicked();
    assert(h.page() == "guided-part1");
    gsv_button(h.child_page("guided-part1"), "Back").clicked();
    assert(h.page() == "start");

    h.setup_button("Provider setup (I know git)").clicked();
    assert(h.page() == "provider");
    gsv_button(h.child_page("provider"), "Back").clicked();
    assert(h.page() == "start");
}

public void register_git_sync_view_setup_tests() {
    var prefix = "/holder/git-sync-view/setup/";
    Test.add_func(prefix + "manual/requires-url", gsu_test_manual_setup_requires_a_remote_url);
    Test.add_func(prefix + "manual/needs-project", gsu_test_manual_setup_needs_a_selected_project);
    Test.add_func(prefix + "manual/needs-api", gsu_test_manual_setup_needs_an_api_client);
    Test.add_func(prefix + "manual/success", gsu_test_manual_setup_saves_tests_and_pushes_with_the_branch);
    Test.add_func(prefix + "manual/no-branch", gsu_test_manual_setup_without_a_branch_omits_it);
    Test.add_func(prefix + "manual/unreachable", gsu_test_an_unreachable_remote_skips_the_push_but_keeps_the_remote);
    Test.add_func(prefix + "manual/failed-push", gsu_test_a_failed_push_is_described_without_a_success_toast);
    Test.add_func(prefix + "manual/api-failures", gsu_test_manual_setup_reports_each_failing_api_call);
    Test.add_func(prefix + "manual/in-flight", gsu_test_manual_setup_shows_progress_while_saving);
    Test.add_func(prefix + "provider/catalog-and-preview", gsu_test_provider_page_loads_the_catalog_and_previews_the_remote);
    Test.add_func(prefix + "provider/transport-and-fields", gsu_test_changing_transport_and_fields_rebuilds_the_preview);
    Test.add_func(prefix + "provider/host-row", gsu_test_a_provider_with_a_host_template_shows_the_host_row);
    Test.add_func(prefix + "provider/generic-templates", gsu_test_a_provider_without_templates_falls_back_to_generic_ones);
    Test.add_func(prefix + "provider/empty-catalog", gsu_test_an_empty_catalog_leaves_no_provider_selected);
    Test.add_func(prefix + "provider/catalog-failure", gsu_test_a_failed_catalog_load_is_reported);
    Test.add_func(prefix + "provider/no-api", gsu_test_the_catalog_is_not_loaded_without_an_api_client);
    Test.add_func(prefix + "provider/reload", gsu_test_reopening_the_provider_page_replaces_the_catalog);
    Test.add_func(prefix + "provider/save", gsu_test_provider_setup_saves_the_previewed_remote_and_branch);
    Test.add_func(prefix + "provider/edited-url", gsu_test_an_edited_remote_url_wins_over_the_preview);
    Test.add_func(prefix + "provider/needs-url", gsu_test_provider_setup_needs_a_remote_url);
    Test.add_func(prefix + "provider/needs-project-and-api", gsu_test_provider_setup_needs_a_project_and_an_api_client);
    Test.add_func(prefix + "provider/api-failure", gsu_test_provider_setup_reports_an_api_failure_on_its_own_status_line);
    Test.add_func(prefix + "provider/project-change", gsu_test_project_changes_refresh_the_provider_defaults);
    Test.add_func(prefix + "navigation", gsu_test_start_page_buttons_open_the_guided_and_provider_pages);
}

}
