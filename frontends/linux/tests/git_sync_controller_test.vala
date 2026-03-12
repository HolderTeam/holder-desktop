using GLib;

private class FakeGitSyncService : HolderLinux.GitSyncService {
    public HolderLinux.GitHubCliState cli_state =
        new HolderLinux.GitHubCliState(true, true, "zeth", "");
    public HolderLinux.GitRepoCheckResult repo_check =
        new HolderLinux.GitRepoCheckResult(true, "");
    public HolderLinux.GitRepoCreateResult repo_create =
        new HolderLinux.GitRepoCreateResult(true, true, "ok");
    public string probe_output = "ok";
    public HolderLinux.GitCommandResult keygen_result =
        new HolderLinux.GitCommandResult(0, "generated");
    public HolderLinux.GitRemoteApplyResult apply_result =
        new HolderLinux.GitRemoteApplyResult(
            new HolderLinux.GitTestRemoteResult("p1", "r", "cards", "reachable", true, "", ""),
            new HolderLinux.GitPushResult("p1", "r", "cards", "pushed", 0, 0, "", "", "")
        );

    public int detect_calls = 0;
    public int check_calls = 0;
    public int create_calls = 0;
    public int probe_calls = 0;
    public int keygen_calls = 0;
    public int apply_calls = 0;
    public string last_username = "";
    public string last_repo_name = "";
    public string last_email = "";
    public string last_key_path = "";
    public string last_project_id = "";
    public string last_remote_url = "";
    public string last_branch = "";
    public bool fail_apply = false;

    public override async HolderLinux.GitHubCliState detect_github_cli_state() {
        detect_calls++;
        return cli_state;
    }

    public override async HolderLinux.GitRepoCheckResult check_repository_exists_via_ssh(string username,
                                                                                          string repo_name) {
        check_calls++;
        last_username = username;
        last_repo_name = repo_name;
        return repo_check;
    }

    public override async HolderLinux.GitRepoCreateResult create_private_repo_and_verify(string username,
                                                                                          string repo_name) {
        create_calls++;
        last_username = username;
        last_repo_name = repo_name;
        return repo_create;
    }

    public override async string probe_github_ssh() {
        probe_calls++;
        return probe_output;
    }

    public override async HolderLinux.GitCommandResult generate_ssh_key(string email, string key_path) {
        keygen_calls++;
        last_email = email;
        last_key_path = key_path;
        return keygen_result;
    }

    public override async HolderLinux.GitRemoteApplyResult configure_remote_and_sync(HolderLinux.IHolderApi api,
                                                                                      string project_id,
                                                                                      string remote_url,
                                                                                      string branch) throws Error {
        if (fail_apply) {
            throw new IOError.FAILED("apply failed");
        }
        apply_calls++;
        last_project_id = project_id;
        last_remote_url = remote_url;
        last_branch = branch;
        return apply_result;
    }
}

private Settings make_test_settings() {
    string exe_path;
    try {
        exe_path = FileUtils.read_link("/proc/self/exe");
    } catch (Error e) {
        assert_not_reached();
    }

    var settings = HolderLinux.AppSettings.open_or_null_for_executable_path(exe_path);
    assert(settings != null);
    return settings;
}

private void test_normalize_repository_name_basic() {
    var controller = new HolderLinux.GitSyncController();
    var normalized = controller.normalize_repository_name("My Project/Name");
    assert(normalized == "My-Project-Name");
}

private void test_normalize_repository_name_strips_unsupported() {
    var controller = new HolderLinux.GitSyncController();
    var normalized = controller.normalize_repository_name("###");
    assert(normalized == "");
}

private void test_fill_remote_template_common_placeholders() {
    var controller = new HolderLinux.GitSyncController();
    var remote = controller.fill_remote_template(
        "git@{host}:{owner}/{repo}.git",
        "zeth",
        "CardApp",
        "github.com"
    );
    assert(remote == "git@github.com:zeth/CardApp.git");
}

private void test_fill_remote_template_region_alias() {
    var controller = new HolderLinux.GitSyncController();
    var remote = controller.fill_remote_template(
        "https://git-codecommit.{region}.amazonaws.com/v1/repos/{repo}",
        "ignored",
        "holder",
        "eu-west-1"
    );
    assert(remote == "https://git-codecommit.eu-west-1.amazonaws.com/v1/repos/holder");
}

private void test_normalize_repository_name_whitespace_returns_empty() {
    var controller = new HolderLinux.GitSyncController();
    assert(controller.normalize_repository_name("   ") == "");
}

private void test_fill_remote_template_more_aliases() {
    var controller = new HolderLinux.GitSyncController();
    var remote = controller.fill_remote_template(
        "ssh://{user}@{host}/{workspace}/{project}/{repo}/{org}",
        "team",
        "cards",
        "git.example.com"
    );
    assert(remote == "ssh://team@git.example.com/team/team/cards/team");
}

private void test_detect_github_cli_state_passthrough() {
    var service = new FakeGitSyncService();
    service.cli_state = new HolderLinux.GitHubCliState(true, false, "", "auth needed");
    var controller = new HolderLinux.GitSyncController(service);
    bool done = false;
    controller.detect_github_cli_state.begin((obj, res) => {
        var state = controller.detect_github_cli_state.end(res);
        assert(service.detect_calls == 1);
        assert(!state.authenticated);
        assert(state.details == "auth needed");
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
}

private void test_check_repository_exists_via_ssh_passthrough() {
    var service = new FakeGitSyncService();
    service.repo_check = new HolderLinux.GitRepoCheckResult(false, "missing");
    var controller = new HolderLinux.GitSyncController(service);
    bool done = false;
    controller.check_repository_exists_via_ssh.begin("zeth", "CardApp", (obj, res) => {
        var result = controller.check_repository_exists_via_ssh.end(res);
        assert(service.check_calls == 1);
        assert(service.last_username == "zeth");
        assert(service.last_repo_name == "CardApp");
        assert(!result.exists);
        assert(result.error_text == "missing");
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
}

private void test_create_private_repo_and_verify_passthrough() {
    var service = new FakeGitSyncService();
    service.repo_create = new HolderLinux.GitRepoCreateResult(false, false, "boom");
    var controller = new HolderLinux.GitSyncController(service);
    bool done = false;
    controller.create_private_repo_and_verify.begin("zeth", "CardApp", (obj, res) => {
        var result = controller.create_private_repo_and_verify.end(res);
        assert(service.create_calls == 1);
        assert(!result.created_ok);
        assert(result.details == "boom");
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
}

private void test_probe_and_keygen_passthrough() {
    var service = new FakeGitSyncService();
    service.probe_output = "ssh-ok";
    service.keygen_result = new HolderLinux.GitCommandResult(0, "generated");
    var controller = new HolderLinux.GitSyncController(service);

    bool probe_done = false;
    controller.probe_github_ssh.begin((obj, res) => {
        var output = controller.probe_github_ssh.end(res);
        assert(service.probe_calls == 1);
        assert(output == "ssh-ok");
        probe_done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => probe_done));

    bool keygen_done = false;
    controller.generate_ssh_key.begin("user@example.com", "/tmp/id", (obj, res) => {
        var result = controller.generate_ssh_key.end(res);
        assert(service.keygen_calls == 1);
        assert(service.last_email == "user@example.com");
        assert(service.last_key_path == "/tmp/id");
        assert(result.exit_code == 0);
        keygen_done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => keygen_done));
}

private void test_configure_remote_and_sync_passthrough() {
    var service = new FakeGitSyncService();
    var controller = new HolderLinux.GitSyncController(service);
    var api = new HolderLinuxTests.MainControllerFakeApi();
    bool done = false;
    controller.configure_remote_and_sync.begin(api, "p42", "git@github.com:zeth/CardApp.git", "cards", (obj, res) => {
        try {
            var result = controller.configure_remote_and_sync.end(res);
            assert(service.apply_calls == 1);
            assert(service.last_project_id == "p42");
            assert(service.last_remote_url == "git@github.com:zeth/CardApp.git");
            assert(service.last_branch == "cards");
            assert(result.test_result != null);
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
}

private void test_get_saved_github_username_without_settings_returns_empty() {
    var controller = new HolderLinux.GitSyncController();
    controller.set_settings(null);
    assert(controller.get_saved_github_username() == "");
}

private void test_set_and_get_saved_github_username_round_trip() {
    var settings = make_test_settings();
    var controller = new HolderLinux.GitSyncController();
    controller.set_settings(settings);

    controller.set_saved_github_username("zeth");
    assert(controller.get_saved_github_username() == "zeth");
}

private void test_get_saved_github_username_strips_whitespace() {
    var settings = make_test_settings();
    var controller = new HolderLinux.GitSyncController();
    controller.set_settings(settings);

    settings.set_string(HolderLinux.AppSettings.KEY_GIT_GITHUB_USERNAME, "  zeth  ");
    assert(controller.get_saved_github_username() == "zeth");
}

private void test_set_saved_github_username_without_settings_is_noop() {
    var controller = new HolderLinux.GitSyncController();
    controller.set_settings(null);
    controller.set_saved_github_username("zeth");
    assert(controller.get_saved_github_username() == "");
}

private void test_configure_remote_and_sync_failure_propagates() {
    var service = new FakeGitSyncService();
    service.fail_apply = true;
    var controller = new HolderLinux.GitSyncController(service);
    var api = new HolderLinuxTests.MainControllerFakeApi();
    bool done = false;
    bool got_error = false;
    controller.configure_remote_and_sync.begin(api, "p42", "git@github.com:zeth/CardApp.git", "cards", (obj, res) => {
        try {
            controller.configure_remote_and_sync.end(res);
        } catch (Error e) {
            got_error = e.message.contains("apply failed");
        }
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
    assert(got_error);
}

private void test_apply_project_git_remote_and_sync_builds_summary_and_toast() {
    var service = new FakeGitSyncService();
    service.apply_result = new HolderLinux.GitRemoteApplyResult(
        new HolderLinux.GitTestRemoteResult(
            "p1",
            "git@github.com:zeth/holder.git",
            "cards",
            "reachable",
            true,
            "",
            "ok"
        ),
        new HolderLinux.GitPushResult(
            "p1",
            "git@github.com:zeth/holder.git",
            "cards",
            "pushed",
            2,
            0,
            "",
            "",
            "none"
        )
    );

    var controller = new HolderLinux.GitSyncController(service);
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var project = new HolderLinux.Project("p1", "Demo Project", "standard", "/tmp/demo", 1, 1);

    bool done = false;
    HolderLinux.GitSyncApplyFlowResult? out_result = null;
    controller.apply_project_git_remote_and_sync.begin(
        api,
        project,
        "git@github.com:zeth/holder.git",
        "cards",
        (obj, res) => {
            try {
                out_result = controller.apply_project_git_remote_and_sync.end(res);
            } catch (Error e) {
                assert_not_reached();
            }
            done = true;
        }
    );
    assert(HolderLinuxTests.wait_for_condition(() => done));
    assert(out_result != null);
    assert(out_result.summary_text.contains("Project: Demo Project"));
    assert(out_result.summary_text.contains("Remote test: reachable (ok)"));
    assert(out_result.summary_text.contains("Push: pushed"));
    assert(out_result.summary_text.contains("Next action: none"));
    assert(out_result.toast_message == "Git remote configured and synced.");
}

private void test_apply_project_git_remote_and_sync_handles_missing_results_without_toast() {
    var service = new FakeGitSyncService();
    service.apply_result = new HolderLinux.GitRemoteApplyResult(null, null);

    var controller = new HolderLinux.GitSyncController(service);
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var project = new HolderLinux.Project("p1", "Demo Project", "standard", "/tmp/demo", 1, 1);

    bool done = false;
    HolderLinux.GitSyncApplyFlowResult? out_result = null;
    controller.apply_project_git_remote_and_sync.begin(
        api,
        project,
        "git@github.com:zeth/holder.git",
        "",
        (obj, res) => {
            try {
                out_result = controller.apply_project_git_remote_and_sync.end(res);
            } catch (Error e) {
                assert_not_reached();
            }
            done = true;
        }
    );
    assert(HolderLinuxTests.wait_for_condition(() => done));
    assert(out_result != null);
    assert(!out_result.summary_text.contains("Branch:"));
    assert(out_result.summary_text.contains("Remote test: not run"));
    assert(out_result.summary_text.contains("Push: not run"));
    assert(out_result.toast_message == "");
}

private void test_run_github_cli_auto_sync_flow_created_repo_with_toast() {
    var service = new FakeGitSyncService();
    service.repo_create = new HolderLinux.GitRepoCreateResult(true, true, "ok");
    service.apply_result = new HolderLinux.GitRemoteApplyResult(
        new HolderLinux.GitTestRemoteResult(
            "p1",
            "git@github.com:zeth/demo.git",
            "",
            "reachable",
            true,
            "",
            ""
        ),
        new HolderLinux.GitPushResult(
            "p1",
            "git@github.com:zeth/demo.git",
            "",
            "up_to_date",
            0,
            0,
            "",
            "",
            ""
        )
    );
    var controller = new HolderLinux.GitSyncController(service);
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var project = new HolderLinux.Project("p1", "Demo", "standard", "/tmp/demo", 1, 1);

    bool done = false;
    HolderLinux.GitHubCliAutoSyncFlowResult? out_result = null;
    controller.run_github_cli_auto_sync_flow.begin(api, project, "zeth", (obj, res) => {
        try {
            out_result = controller.run_github_cli_auto_sync_flow.end(res);
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
    assert(out_result != null);
    assert(out_result.error_title == "");
    assert(out_result.status_text.contains("GitHub CLI: created repo `zeth/Demo`."));
    assert(out_result.status_text.contains("Remote test: reachable"));
    assert(out_result.status_text.contains("Push: up_to_date."));
    assert(out_result.toast_message == "GitHub CLI sync setup completed.");
}

private void test_run_github_cli_auto_sync_flow_uses_existing_repo_without_toast() {
    var service = new FakeGitSyncService();
    service.repo_create = new HolderLinux.GitRepoCreateResult(false, true, "already exists");
    service.apply_result = new HolderLinux.GitRemoteApplyResult(
        new HolderLinux.GitTestRemoteResult(
            "p1",
            "git@github.com:zeth/demo.git",
            "",
            "reachable",
            true,
            "",
            ""
        ),
        new HolderLinux.GitPushResult(
            "p1",
            "git@github.com:zeth/demo.git",
            "",
            "non_fast_forward",
            1,
            1,
            "non_fast_forward",
            "need pull",
            "pull first"
        )
    );
    var controller = new HolderLinux.GitSyncController(service);
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var project = new HolderLinux.Project("p1", "Demo", "standard", "/tmp/demo", 1, 1);

    bool done = false;
    HolderLinux.GitHubCliAutoSyncFlowResult? out_result = null;
    controller.run_github_cli_auto_sync_flow.begin(api, project, "zeth", (obj, res) => {
        try {
            out_result = controller.run_github_cli_auto_sync_flow.end(res);
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
    assert(out_result != null);
    assert(out_result.status_text.contains("GitHub CLI: using existing repo `zeth/Demo`."));
    assert(out_result.status_text.contains("Push: non_fast_forward (need pull)."));
    assert(out_result.toast_message == "");
}

private void test_run_github_cli_auto_sync_flow_create_failure_returns_error_result() {
    var service = new FakeGitSyncService();
    service.repo_create = new HolderLinux.GitRepoCreateResult(false, false, "create failed");
    var controller = new HolderLinux.GitSyncController(service);
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var project = new HolderLinux.Project("p1", "Demo", "standard", "/tmp/demo", 1, 1);

    bool done = false;
    HolderLinux.GitHubCliAutoSyncFlowResult? out_result = null;
    controller.run_github_cli_auto_sync_flow.begin(api, project, "zeth", (obj, res) => {
        try {
            out_result = controller.run_github_cli_auto_sync_flow.end(res);
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
    assert(out_result != null);
    assert(out_result.error_title == "GitHub CLI setup failed");
    assert(out_result.error_details == "create failed");
    assert(out_result.status_text == "GitHub CLI setup failed: create failed");
}

private void test_run_github_cli_auto_sync_flow_invalid_project_name_throws() {
    var controller = new HolderLinux.GitSyncController();
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var project = new HolderLinux.Project("p1", "###", "standard", "/tmp/demo", 1, 1);

    bool done = false;
    bool got_error = false;
    controller.run_github_cli_auto_sync_flow.begin(api, project, "zeth", (obj, res) => {
        try {
            controller.run_github_cli_auto_sync_flow.end(res);
        } catch (Error e) {
            got_error = e.message.contains("valid repository name");
        }
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
    assert(got_error);
}

private void test_run_github_guided_sync_flow_builds_status_and_toast() {
    var service = new FakeGitSyncService();
    service.apply_result = new HolderLinux.GitRemoteApplyResult(
        new HolderLinux.GitTestRemoteResult(
            "p1",
            "git@github.com:zeth/demo.git",
            "",
            "reachable",
            true,
            "",
            "ok"
        ),
        new HolderLinux.GitPushResult(
            "p1",
            "git@github.com:zeth/demo.git",
            "",
            "pushed",
            0,
            0,
            "",
            "",
            ""
        )
    );
    var controller = new HolderLinux.GitSyncController(service);
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var project = new HolderLinux.Project("p1", "Demo", "standard", "/tmp/demo", 1, 1);

    bool done = false;
    HolderLinux.GitHubGuidedSyncFlowResult? out_result = null;
    controller.run_github_guided_sync_flow.begin(api, project, "zeth", "demo", (obj, res) => {
        try {
            out_result = controller.run_github_guided_sync_flow.end(res);
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
    assert(out_result != null);
    assert(out_result.status_text.contains("Remote test: reachable (ok)"));
    assert(out_result.status_text.contains("Push: pushed"));
    assert(out_result.status_text.contains("Sync state: unknown"));
    assert(out_result.status_text.contains("Last push: never"));
    assert(out_result.status_text.contains("Push retry count: 0"));
    assert(out_result.status_text.contains("Pull retry count: 0"));
    assert(out_result.toast_message == "Git sync setup completed.");
}

private void test_run_github_guided_sync_flow_list_projects_failure_propagates() {
    var service = new FakeGitSyncService();
    var controller = new HolderLinux.GitSyncController(service);
    var api = new HolderLinuxTests.MainControllerFakeApi();
    api.fail_list_projects = true;
    var project = new HolderLinux.Project("p1", "Demo", "standard", "/tmp/demo", 1, 1);

    bool done = false;
    bool got_error = false;
    controller.run_github_guided_sync_flow.begin(api, project, "zeth", "demo", (obj, res) => {
        try {
            controller.run_github_guided_sync_flow.end(res);
        } catch (Error e) {
            got_error = e.message.contains("list projects failed");
        }
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
    assert(got_error);
}

private void test_verify_github_repository_exists_flow_success() {
    var service = new FakeGitSyncService();
    service.repo_check = new HolderLinux.GitRepoCheckResult(true, "");
    var controller = new HolderLinux.GitSyncController(service);

    bool done = false;
    HolderLinux.GitHubRepoVerifyFlowResult? out_result = null;
    controller.verify_github_repository_exists_flow.begin("zeth", "demo", (obj, res) => {
        out_result = controller.verify_github_repository_exists_flow.end(res);
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
    assert(out_result != null);
    assert(out_result.exists);
    assert(out_result.status_text == "Repository found on GitHub.");
    assert(out_result.error_title == "");
    assert(out_result.push_intro_text.contains("git@github.com:zeth/demo.git"));
}

private void test_verify_github_repository_exists_flow_failure() {
    var service = new FakeGitSyncService();
    service.repo_check = new HolderLinux.GitRepoCheckResult(false, "not reachable");
    var controller = new HolderLinux.GitSyncController(service);

    bool done = false;
    HolderLinux.GitHubRepoVerifyFlowResult? out_result = null;
    controller.verify_github_repository_exists_flow.begin("zeth", "demo", (obj, res) => {
        out_result = controller.verify_github_repository_exists_flow.end(res);
        done = true;
    });
    assert(HolderLinuxTests.wait_for_condition(() => done));
    assert(out_result != null);
    assert(!out_result.exists);
    assert(out_result.status_text == "not reachable");
    assert(out_result.error_title == "Repository check failed");
    assert(out_result.error_details.contains("https://github.com/zeth/demo"));
}

private void test_validate_remote_setup_inputs_missing_project_returns_toast() {
    var controller = new HolderLinux.GitSyncController();
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var result = controller.validate_remote_setup_inputs(null, api, "git@github.com:zeth/demo.git");
    assert(!result.ok);
    assert(result.is_toast);
    assert(result.message == "Select a project first.");
}

private void test_validate_remote_setup_inputs_missing_api_returns_error() {
    var controller = new HolderLinux.GitSyncController();
    var project = new HolderLinux.Project("p1", "Demo", "standard", "/tmp/demo", 1, 1);
    var result = controller.validate_remote_setup_inputs(project, null, "git@github.com:zeth/demo.git");
    assert(!result.ok);
    assert(!result.is_toast);
    assert(result.error_title == "Git sync failed");
    assert(result.error_details == "Backend API client is not ready.");
}

private void test_validate_remote_setup_inputs_missing_remote_returns_toast() {
    var controller = new HolderLinux.GitSyncController();
    var project = new HolderLinux.Project("p1", "Demo", "standard", "/tmp/demo", 1, 1);
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var result = controller.validate_remote_setup_inputs(project, api, "   ");
    assert(!result.ok);
    assert(result.is_toast);
    assert(result.message == "Remote URL is required.");
}

private void test_validate_remote_setup_inputs_ok() {
    var controller = new HolderLinux.GitSyncController();
    var project = new HolderLinux.Project("p1", "Demo", "standard", "/tmp/demo", 1, 1);
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var result = controller.validate_remote_setup_inputs(project, api, "git@github.com:zeth/demo.git");
    assert(result.ok);
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/git_sync_controller/normalize_repository_name_basic", test_normalize_repository_name_basic);
    Test.add_func("/git_sync_controller/normalize_repository_name_strips_unsupported",
                  test_normalize_repository_name_strips_unsupported);
    Test.add_func("/git_sync_controller/fill_remote_template_common_placeholders",
                  test_fill_remote_template_common_placeholders);
    Test.add_func("/git_sync_controller/fill_remote_template_region_alias",
                  test_fill_remote_template_region_alias);
    Test.add_func("/git_sync_controller/normalize_repository_name_whitespace_returns_empty",
                  test_normalize_repository_name_whitespace_returns_empty);
    Test.add_func("/git_sync_controller/fill_remote_template_more_aliases",
                  test_fill_remote_template_more_aliases);
    Test.add_func("/git_sync_controller/detect_github_cli_state_passthrough",
                  test_detect_github_cli_state_passthrough);
    Test.add_func("/git_sync_controller/check_repository_exists_via_ssh_passthrough",
                  test_check_repository_exists_via_ssh_passthrough);
    Test.add_func("/git_sync_controller/create_private_repo_and_verify_passthrough",
                  test_create_private_repo_and_verify_passthrough);
    Test.add_func("/git_sync_controller/probe_and_keygen_passthrough",
                  test_probe_and_keygen_passthrough);
    Test.add_func("/git_sync_controller/configure_remote_and_sync_passthrough",
                  test_configure_remote_and_sync_passthrough);
    Test.add_func("/git_sync_controller/get_saved_github_username_without_settings_returns_empty",
                  test_get_saved_github_username_without_settings_returns_empty);
    Test.add_func("/git_sync_controller/set_and_get_saved_github_username_round_trip",
                  test_set_and_get_saved_github_username_round_trip);
    Test.add_func("/git_sync_controller/get_saved_github_username_strips_whitespace",
                  test_get_saved_github_username_strips_whitespace);
    Test.add_func("/git_sync_controller/set_saved_github_username_without_settings_is_noop",
                  test_set_saved_github_username_without_settings_is_noop);
    Test.add_func("/git_sync_controller/configure_remote_and_sync_failure_propagates",
                  test_configure_remote_and_sync_failure_propagates);
    Test.add_func("/git_sync_controller/apply_project_git_remote_and_sync_builds_summary_and_toast",
                  test_apply_project_git_remote_and_sync_builds_summary_and_toast);
    Test.add_func("/git_sync_controller/apply_project_git_remote_and_sync_handles_missing_results_without_toast",
                  test_apply_project_git_remote_and_sync_handles_missing_results_without_toast);
    Test.add_func("/git_sync_controller/run_github_cli_auto_sync_flow_created_repo_with_toast",
                  test_run_github_cli_auto_sync_flow_created_repo_with_toast);
    Test.add_func("/git_sync_controller/run_github_cli_auto_sync_flow_uses_existing_repo_without_toast",
                  test_run_github_cli_auto_sync_flow_uses_existing_repo_without_toast);
    Test.add_func("/git_sync_controller/run_github_cli_auto_sync_flow_create_failure_returns_error_result",
                  test_run_github_cli_auto_sync_flow_create_failure_returns_error_result);
    Test.add_func("/git_sync_controller/run_github_cli_auto_sync_flow_invalid_project_name_throws",
                  test_run_github_cli_auto_sync_flow_invalid_project_name_throws);
    Test.add_func("/git_sync_controller/run_github_guided_sync_flow_builds_status_and_toast",
                  test_run_github_guided_sync_flow_builds_status_and_toast);
    Test.add_func("/git_sync_controller/run_github_guided_sync_flow_list_projects_failure_propagates",
                  test_run_github_guided_sync_flow_list_projects_failure_propagates);
    Test.add_func("/git_sync_controller/verify_github_repository_exists_flow_success",
                  test_verify_github_repository_exists_flow_success);
    Test.add_func("/git_sync_controller/verify_github_repository_exists_flow_failure",
                  test_verify_github_repository_exists_flow_failure);
    Test.add_func("/git_sync_controller/validate_remote_setup_inputs_missing_project_returns_toast",
                  test_validate_remote_setup_inputs_missing_project_returns_toast);
    Test.add_func("/git_sync_controller/validate_remote_setup_inputs_missing_api_returns_error",
                  test_validate_remote_setup_inputs_missing_api_returns_error);
    Test.add_func("/git_sync_controller/validate_remote_setup_inputs_missing_remote_returns_toast",
                  test_validate_remote_setup_inputs_missing_remote_returns_toast);
    Test.add_func("/git_sync_controller/validate_remote_setup_inputs_ok",
                  test_validate_remote_setup_inputs_ok);

    return Test.run();
}
