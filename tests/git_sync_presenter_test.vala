private HolderLinux.GitProviderCatalogEntry make_provider(string id,
                                                          string preferred_transport,
                                                          string transports_summary,
                                                          string ssh_example,
                                                          string https_example) {
    return new HolderLinux.GitProviderCatalogEntry(
        id,
        id,
        "hosted",
        preferred_transport,
        transports_summary,
        ssh_example,
        https_example
    );
}

private HolderLinux.Project configured_project(string remote_url,
                                                HolderLinux.ProjectSyncState sync) {
    return new HolderLinux.Project(
        "p1",
        "Family Notes",
        "encrypted_git",
        "/tmp/p1",
        10,
        20,
        remote_url,
        sync
    );
}

private void test_configured_state_shows_repository_and_last_sync() {
    var sync = new HolderLinux.ProjectSyncState(
        null,
        9880,
        null,
        0,
        0,
        "pushed"
    );
    var presentation = HolderLinux.GitSyncPresenter.configured_state(
        configured_project("git@github.com:HolderTeam/family-notes.git", sync),
        10000
    );

    assert(presentation.repository_text == "github.com/HolderTeam/family-notes");
    assert(presentation.remote_url == "git@github.com:HolderTeam/family-notes.git");
    assert(presentation.web_url == "https://github.com/HolderTeam/family-notes");
    assert(presentation.status_text == "Up to date");
    assert(presentation.status_class == "success");
    assert(presentation.detail_text == "Last successful sync 2m ago");
}

private void test_configured_state_prioritizes_pending_changes() {
    var sync = new HolderLinux.ProjectSyncState(
        null,
        9900,
        null,
        2,
        1,
        "pushed"
    );
    var presentation = HolderLinux.GitSyncPresenter.configured_state(
        configured_project("https://git.example.com/team/cards.git", sync),
        10000
    );

    assert(presentation.status_text == "Changes waiting");
    assert(presentation.status_class == "warning");
    assert(presentation.detail_text.contains("2 uncommitted changes"));
    assert(presentation.detail_text.contains("1 commit waiting to push"));
}

private void test_configured_state_prioritizes_sync_error() {
    var sync = new HolderLinux.ProjectSyncState(
        null,
        null,
        null,
        2,
        3,
        "failed",
        "",
        "Authentication denied"
    );
    var presentation = HolderLinux.GitSyncPresenter.configured_state(
        configured_project("ssh://git@git.example.com/team/cards.git", sync),
        10000
    );

    assert(presentation.status_text == "Needs attention");
    assert(presentation.status_class == "error");
    assert(presentation.detail_text.contains("Authentication denied"));
    assert(presentation.web_url == "https://git.example.com/team/cards");
}

private void test_git_cli_controls_when_cli_missing() {
    var presentation = HolderLinux.GitSyncPresenter.git_cli_controls(false, false, "");

    assert(presentation.repo_mode_text == "Create a private repository for this project.");
    assert(presentation.repo_manual_label == "Create a new repository:");
    assert(presentation.cli_status_text.contains("GitHub CLI not detected"));
    assert(!presentation.cli_buttons_visible);
    assert(!presentation.cli_buttons_sensitive);
}

private void test_git_cli_controls_when_authenticated() {
    var presentation = HolderLinux.GitSyncPresenter.git_cli_controls(true, true, "zeth");

    assert(presentation.repo_mode_text == "Recommended on this device: create the private repository with GitHub CLI.");
    assert(presentation.repo_manual_label == "Browser fallback:");
    assert(presentation.repo_manual_instructions_markup.contains("If you prefer the browser route"));
    assert(presentation.cli_status_text.contains("authenticated as `zeth`"));
    assert(presentation.cli_buttons_visible);
    assert(presentation.cli_buttons_sensitive);
}

private void test_git_cli_controls_requires_login_to_enable_buttons() {
    var presentation = HolderLinux.GitSyncPresenter.git_cli_controls(true, true, "   ");

    assert(presentation.cli_status_text.contains("authenticated as"));
    assert(presentation.cli_buttons_visible);
    assert(!presentation.cli_buttons_sensitive);
}

private void test_provider_remote_preview_uses_default_host_and_template() {
    var provider = make_provider(
        "github",
        "ssh",
        "ssh,https",
        "git@{host}:{owner}/{repo}.git",
        "https://{host}/{owner}/{repo}.git"
    );
    var preview = HolderLinux.GitSyncPresenter.provider_remote_preview(
        provider,
        "ssh",
        "holderteam",
        "holder",
        ""
    );

    assert(preview.remote_url == "git@github.com:holderteam/holder.git");
    assert(preview.template_label.contains("Template: git@{host}:{owner}/{repo}.git"));
    assert(preview.needs_host);
    assert(!preview.clear_host);
}

private void test_provider_remote_preview_falls_back_when_template_missing() {
    var provider = make_provider("custom", "https", "https", "", "");
    var preview = HolderLinux.GitSyncPresenter.provider_remote_preview(
        provider,
        "https",
        "team",
        "cards",
        "git.example.com"
    );

    assert(preview.remote_url == "https://git.example.com/team/cards.git");
    assert(preview.needs_host);
    assert(!preview.clear_host);
}

private void test_provider_remote_preview_uses_region_placeholder() {
    var provider = make_provider("aws", "https", "https", "", "ssh://git-codecommit.{region}.amazonaws.com/v1/repos/{repo}");
    var preview = HolderLinux.GitSyncPresenter.provider_remote_preview(
        provider,
        "https",
        "ignored",
        "holder",
        "eu-west-1"
    );

    assert(preview.remote_url == "ssh://git-codecommit.eu-west-1.amazonaws.com/v1/repos/holder");
    assert(preview.needs_host);
    assert(!preview.clear_host);
}

private void test_provider_remote_preview_clears_host_when_template_does_not_use_host() {
    var provider = make_provider("custom", "ssh", "ssh", "ssh://git.example.com/{owner}/{repo}.git", "");
    var preview = HolderLinux.GitSyncPresenter.provider_remote_preview(
        provider,
        "ssh",
        "team",
        "cards",
        "should-clear"
    );

    assert(preview.remote_url == "ssh://git.example.com/team/cards.git");
    assert(!preview.needs_host);
    assert(preview.clear_host);
}

private void test_provider_remote_preview_without_provider() {
    var preview = HolderLinux.GitSyncPresenter.provider_remote_preview(null, "ssh", "", "", "");

    assert(preview.remote_url == "");
    assert(preview.template_label == "No provider selected.");
    assert(!preview.needs_host);
}

private void test_guided_ssh_key_ui_without_key() {
    var presentation = HolderLinux.GitSyncPresenter.guided_ssh_key_ui(false, false, "");

    assert(presentation.missing_key_visible);
    assert(!presentation.key_ready_visible);
    assert(!presentation.copy_key_sensitive);
    assert(presentation.open_keys_visible);
}

private void test_guided_ssh_key_ui_with_unauthenticated_key() {
    var presentation = HolderLinux.GitSyncPresenter.guided_ssh_key_ui(true, false, "ssh-ed25519 key");

    assert(!presentation.missing_key_visible);
    assert(presentation.key_ready_visible);
    assert(presentation.copy_key_sensitive);
    assert(presentation.open_keys_visible);
}

private void test_guided_ssh_key_ui_with_authenticated_key() {
    var presentation = HolderLinux.GitSyncPresenter.guided_ssh_key_ui(true, true, "ssh-ed25519 key");

    assert(!presentation.missing_key_visible);
    assert(!presentation.key_ready_visible);
    assert(!presentation.copy_key_sensitive);
    assert(!presentation.open_keys_visible);
}

private void test_guided_ssh_probe_status_variants() {
    var success = HolderLinux.GitSyncPresenter.guided_ssh_probe_status("Hi user! You've successfully authenticated");
    var denied = HolderLinux.GitSyncPresenter.guided_ssh_probe_status("Permission denied (publickey)");
    var custom = HolderLinux.GitSyncPresenter.guided_ssh_probe_status("ssh: connect failed");
    var empty = HolderLinux.GitSyncPresenter.guided_ssh_probe_status("");

    assert(success.authenticated);
    assert(success.status_text.contains("authenticated with GitHub"));
    assert(!denied.authenticated);
    assert(denied.status_text.contains("rejected authentication"));
    assert(custom.status_text.contains("ssh: connect failed"));
    assert(empty.status_text.contains("Could not verify"));
}

private void test_fill_remote_template_aliases() {
    var remote = HolderLinux.GitSyncPresenter.fill_remote_template(
        "ssh://{user}@{host}/{workspace}/{project}/{repo}/{org}/{region}",
        "team",
        "cards",
        "git.example.com"
    );

    assert(remote == "ssh://team@git.example.com/team/team/cards/team/git.example.com");
}

public int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/holder/git-sync-presenter/cli-missing", test_git_cli_controls_when_cli_missing);
    Test.add_func("/holder/git-sync-presenter/cli-authenticated", test_git_cli_controls_when_authenticated);
    Test.add_func("/holder/git-sync-presenter/cli-requires-login", test_git_cli_controls_requires_login_to_enable_buttons);
    Test.add_func("/holder/git-sync-presenter/configured-state-last-sync", test_configured_state_shows_repository_and_last_sync);
    Test.add_func("/holder/git-sync-presenter/configured-state-pending", test_configured_state_prioritizes_pending_changes);
    Test.add_func("/holder/git-sync-presenter/configured-state-error", test_configured_state_prioritizes_sync_error);
    Test.add_func("/holder/git-sync-presenter/provider-default-host", test_provider_remote_preview_uses_default_host_and_template);
    Test.add_func("/holder/git-sync-presenter/provider-fallback-template", test_provider_remote_preview_falls_back_when_template_missing);
    Test.add_func("/holder/git-sync-presenter/provider-region-placeholder", test_provider_remote_preview_uses_region_placeholder);
    Test.add_func("/holder/git-sync-presenter/provider-clears-host", test_provider_remote_preview_clears_host_when_template_does_not_use_host);
    Test.add_func("/holder/git-sync-presenter/provider-without-provider", test_provider_remote_preview_without_provider);
    Test.add_func("/holder/git-sync-presenter/guided-ssh-key-ui-without-key", test_guided_ssh_key_ui_without_key);
    Test.add_func("/holder/git-sync-presenter/guided-ssh-key-ui-with-unauthenticated-key", test_guided_ssh_key_ui_with_unauthenticated_key);
    Test.add_func("/holder/git-sync-presenter/guided-ssh-key-ui-with-authenticated-key", test_guided_ssh_key_ui_with_authenticated_key);
    Test.add_func("/holder/git-sync-presenter/guided-ssh-probe-status-variants", test_guided_ssh_probe_status_variants);
    Test.add_func("/holder/git-sync-presenter/fill-remote-template-aliases", test_fill_remote_template_aliases);

    return Test.run();
}
