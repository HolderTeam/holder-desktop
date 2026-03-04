using GLib;

namespace HolderLinuxTests {

private class ScriptedGitSyncService : HolderLinux.GitSyncService {
    private Gee.HashMap<string, HolderLinux.GitCommandResult> scripted;
    public Gee.ArrayList<string> command_keys;

    public ScriptedGitSyncService() {
        scripted = new Gee.HashMap<string, HolderLinux.GitCommandResult>();
        command_keys = new Gee.ArrayList<string>();
    }

    private string key_for(string[] argv) {
        return string.joinv("\x1f", argv);
    }

    public void script(string[] argv, int exit_code, string output) {
        scripted.set(key_for(argv), new HolderLinux.GitCommandResult(exit_code, output));
    }

    public override async HolderLinux.GitCommandResult run_command(string[] argv) {
        var key = key_for(argv);
        command_keys.add(key);
        var result = scripted.get(key);
        if (result != null) {
            return result;
        }
        return new HolderLinux.GitCommandResult(-1, "unscripted");
    }
}

private void test_run_command_success_captures_stdout() {
    var service = new HolderLinux.GitSyncService();
    bool done = false;

    service.run_command.begin({"/bin/sh", "-lc", "printf 'hello'"}, (obj, res) => {
        var result = service.run_command.end(res);
        assert(result.exit_code == 0);
        assert(result.output == "hello");
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_run_command_combines_stdout_and_stderr() {
    var service = new HolderLinux.GitSyncService();
    bool done = false;

    service.run_command.begin({"/bin/sh", "-lc", "printf 'out'; printf 'err' 1>&2"}, (obj, res) => {
        var result = service.run_command.end(res);
        assert(result.exit_code == 0);
        assert(result.output == "out\nerr");
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_run_command_missing_binary_returns_error_result() {
    var service = new HolderLinux.GitSyncService();
    bool done = false;

    service.run_command.begin({"__holder_missing_command__"}, (obj, res) => {
        var result = service.run_command.end(res);
        assert(result.exit_code == -1);
        assert(result.output.length > 0);
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_configure_remote_and_sync_pushes_when_reachable() {
    var service = new HolderLinux.GitSyncService();
    var api = new MainControllerFakeApi();
    api.test_project_git_remote_status = "reachable";
    bool done = false;

    service.configure_remote_and_sync.begin(api, "p1", "git@github.com:z/u.git", "cards", (obj, res) => {
        try {
            var result = service.configure_remote_and_sync.end(res);
            assert(api.set_project_git_remote_calls == 1);
            assert(api.test_project_git_remote_calls == 1);
            assert(api.push_project_git_calls == 1);
            assert(result.test_result != null);
            assert(result.push_result != null);
            assert(result.test_result.status == "reachable");
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_configure_remote_and_sync_skips_push_when_unreachable() {
    var service = new HolderLinux.GitSyncService();
    var api = new MainControllerFakeApi();
    api.test_project_git_remote_status = "unreachable";
    bool done = false;

    service.configure_remote_and_sync.begin(api, "p1", "git@github.com:z/u.git", "cards", (obj, res) => {
        try {
            var result = service.configure_remote_and_sync.end(res);
            assert(api.set_project_git_remote_calls == 1);
            assert(api.test_project_git_remote_calls == 1);
            assert(api.push_project_git_calls == 0);
            assert(result.test_result != null);
            assert(result.push_result == null);
            assert(result.test_result.status == "unreachable");
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_detect_github_cli_state_unavailable_when_auth_missing() {
    var service = new ScriptedGitSyncService();
    service.script({"gh", "auth", "status", "-h", "github.com"}, -1, "not found");

    bool done = false;
    service.detect_github_cli_state.begin((obj, res) => {
        var state = service.detect_github_cli_state.end(res);
        assert(!state.available);
        assert(!state.authenticated);
        assert(state.details == "not found");
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_detect_github_cli_state_not_authenticated() {
    var service = new ScriptedGitSyncService();
    service.script({"gh", "auth", "status", "-h", "github.com"}, 1, "auth failed");

    bool done = false;
    service.detect_github_cli_state.begin((obj, res) => {
        var state = service.detect_github_cli_state.end(res);
        assert(state.available);
        assert(!state.authenticated);
        assert(state.details == "auth failed");
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_detect_github_cli_state_login_failure() {
    var service = new ScriptedGitSyncService();
    service.script({"gh", "auth", "status", "-h", "github.com"}, 0, "ok");
    service.script({"gh", "api", "user", "-q", ".login"}, 1, "forbidden");

    bool done = false;
    service.detect_github_cli_state.begin((obj, res) => {
        var state = service.detect_github_cli_state.end(res);
        assert(state.available);
        assert(!state.authenticated);
        assert(state.details == "forbidden");
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_detect_github_cli_state_authenticated() {
    var service = new ScriptedGitSyncService();
    service.script({"gh", "auth", "status", "-h", "github.com"}, 0, "ok");
    service.script({"gh", "api", "user", "-q", ".login"}, 0, "zeth\n");

    bool done = false;
    service.detect_github_cli_state.begin((obj, res) => {
        var state = service.detect_github_cli_state.end(res);
        assert(state.available);
        assert(state.authenticated);
        assert(state.login == "zeth");
        assert(state.details == "");
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_check_repository_exists_via_ssh_success() {
    var service = new ScriptedGitSyncService();
    service.script({"git", "ls-remote", "git@github.com:u/r.git"}, 0, "hash");

    bool done = false;
    service.check_repository_exists_via_ssh.begin("u", "r", (obj, res) => {
        var result = service.check_repository_exists_via_ssh.end(res);
        assert(result.exists);
        assert(result.error_text == "");
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_check_repository_exists_via_ssh_default_error_text() {
    var service = new ScriptedGitSyncService();
    service.script({"git", "ls-remote", "git@github.com:u/r.git"}, 2, "");

    bool done = false;
    service.check_repository_exists_via_ssh.begin("u", "r", (obj, res) => {
        var result = service.check_repository_exists_via_ssh.end(res);
        assert(!result.exists);
        assert(result.error_text.contains("Repository not reachable over SSH."));
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_create_private_repo_and_verify_prefers_check_error_when_create_output_empty() {
    var service = new ScriptedGitSyncService();
    service.script(
        {"gh", "repo", "create", "u/r", "--private", "--disable-issues", "--disable-wiki", "--confirm"},
        0,
        ""
    );
    service.script({"git", "ls-remote", "git@github.com:u/r.git"}, 2, "permission denied");

    bool done = false;
    service.create_private_repo_and_verify.begin("u", "r", (obj, res) => {
        var result = service.create_private_repo_and_verify.end(res);
        assert(result.created_ok);
        assert(!result.exists);
        assert(result.details.contains("Could not verify"));
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_create_private_repo_and_verify_keeps_create_output() {
    var service = new ScriptedGitSyncService();
    service.script(
        {"gh", "repo", "create", "u/r", "--private", "--disable-issues", "--disable-wiki", "--confirm"},
        1,
        "create failed"
    );
    service.script({"git", "ls-remote", "git@github.com:u/r.git"}, 2, "permission denied");

    bool done = false;
    service.create_private_repo_and_verify.begin("u", "r", (obj, res) => {
        var result = service.create_private_repo_and_verify.end(res);
        assert(!result.created_ok);
        assert(!result.exists);
        assert(result.details == "create failed");
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_probe_github_ssh_returns_output() {
    var service = new ScriptedGitSyncService();
    service.script(
        {"ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new", "-o", "ConnectTimeout=5", "-T", "git@github.com"},
        1,
        "hi from github"
    );

    bool done = false;
    service.probe_github_ssh.begin((obj, res) => {
        var output = service.probe_github_ssh.end(res);
        assert(output == "hi from github");
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_generate_ssh_key_invokes_expected_command() {
    var service = new ScriptedGitSyncService();
    service.script(
        {"ssh-keygen", "-t", "ed25519", "-C", "user@example.com", "-f", "/tmp/id_ed25519", "-N", ""},
        0,
        "ok"
    );

    bool done = false;
    service.generate_ssh_key.begin("user@example.com", "/tmp/id_ed25519", (obj, res) => {
        var result = service.generate_ssh_key.end(res);
        assert(result.exit_code == 0);
        assert(result.output == "ok");
        assert(service.command_keys.size == 1);
        done = true;
    });

    assert(wait_for_condition(() => done));
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/git_sync_service/run_command_success_captures_stdout",
                  test_run_command_success_captures_stdout);
    Test.add_func("/git_sync_service/run_command_combines_stdout_and_stderr",
                  test_run_command_combines_stdout_and_stderr);
    Test.add_func("/git_sync_service/run_command_missing_binary_returns_error_result",
                  test_run_command_missing_binary_returns_error_result);
    Test.add_func("/git_sync_service/configure_remote_and_sync_pushes_when_reachable",
                  test_configure_remote_and_sync_pushes_when_reachable);
    Test.add_func("/git_sync_service/configure_remote_and_sync_skips_push_when_unreachable",
                  test_configure_remote_and_sync_skips_push_when_unreachable);
    Test.add_func("/git_sync_service/detect_github_cli_state_unavailable_when_auth_missing",
                  test_detect_github_cli_state_unavailable_when_auth_missing);
    Test.add_func("/git_sync_service/detect_github_cli_state_not_authenticated",
                  test_detect_github_cli_state_not_authenticated);
    Test.add_func("/git_sync_service/detect_github_cli_state_login_failure",
                  test_detect_github_cli_state_login_failure);
    Test.add_func("/git_sync_service/detect_github_cli_state_authenticated",
                  test_detect_github_cli_state_authenticated);
    Test.add_func("/git_sync_service/check_repository_exists_via_ssh_success",
                  test_check_repository_exists_via_ssh_success);
    Test.add_func("/git_sync_service/check_repository_exists_via_ssh_default_error_text",
                  test_check_repository_exists_via_ssh_default_error_text);
    Test.add_func("/git_sync_service/create_private_repo_and_verify_prefers_check_error_when_create_output_empty",
                  test_create_private_repo_and_verify_prefers_check_error_when_create_output_empty);
    Test.add_func("/git_sync_service/create_private_repo_and_verify_keeps_create_output",
                  test_create_private_repo_and_verify_keeps_create_output);
    Test.add_func("/git_sync_service/probe_github_ssh_returns_output",
                  test_probe_github_ssh_returns_output);
    Test.add_func("/git_sync_service/generate_ssh_key_invokes_expected_command",
                  test_generate_ssh_key_invokes_expected_command);

    return Test.run();
}

}
