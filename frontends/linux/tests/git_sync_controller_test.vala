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
        apply_calls++;
        last_project_id = project_id;
        last_remote_url = remote_url;
        last_branch = branch;
        return apply_result;
    }
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

    return Test.run();
}
