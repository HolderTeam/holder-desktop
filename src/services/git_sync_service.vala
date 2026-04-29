namespace HolderLinux {

public class GitCommandResult : Object {
    public int exit_code { get; construct; }
    public string output { get; construct; }

    public GitCommandResult(int exit_code, string output) {
        Object(exit_code: exit_code, output: output);
    }
}

public class GitHubCliState : Object {
    public bool available { get; construct; }
    public bool authenticated { get; construct; }
    public string login { get; construct; }
    public string details { get; construct; }

    public GitHubCliState(bool available, bool authenticated, string login, string details) {
        Object(available: available, authenticated: authenticated, login: login, details: details);
    }
}

public class GitRepoCheckResult : Object {
    public bool exists { get; construct; }
    public string error_text { get; construct; }

    public GitRepoCheckResult(bool exists, string error_text) {
        Object(exists: exists, error_text: error_text);
    }
}

public class GitRepoCreateResult : Object {
    public bool created_ok { get; construct; }
    public bool exists { get; construct; }
    public string details { get; construct; }

    public GitRepoCreateResult(bool created_ok, bool exists, string details) {
        Object(created_ok: created_ok, exists: exists, details: details);
    }
}

public class GitRemoteApplyResult : Object {
    public GitTestRemoteResult? test_result { get; construct; }
    public GitPushResult? push_result { get; construct; }

    public GitRemoteApplyResult(GitTestRemoteResult? test_result,
                                GitPushResult? push_result) {
        Object(test_result: test_result, push_result: push_result);
    }
}

public class GitSyncService : Object {
    public virtual async GitCommandResult run_command(string[] argv) {
        try {
            var proc = new Subprocess.newv(argv,
                SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            string? stdout_buf = null;
            string? stderr_buf = null;
            yield proc.communicate_utf8_async(null, null, out stdout_buf, out stderr_buf);
            var out_text = (stdout_buf ?? "").strip();
            var err_text = (stderr_buf ?? "").strip();
            var combined = "";
            if (out_text.length > 0 && err_text.length > 0) {
                combined = "%s\n%s".printf(out_text, err_text);
            } else {
                combined = out_text.length > 0 ? out_text : err_text;
            }
            return new GitCommandResult(proc.get_exit_status(), combined);
        } catch (Error e) {
            return new GitCommandResult(-1, e.message);
        }
    }

    public virtual async GitHubCliState detect_github_cli_state() {
        var auth = yield run_command({
            "gh",
            "auth",
            "status",
            "-h",
            "github.com"
        });
        if (auth.exit_code < 0) {
            return new GitHubCliState(false, false, "", auth.output);
        }
        if (auth.exit_code != 0) {
            return new GitHubCliState(true, false, "", auth.output);
        }

        var login = yield run_command({
            "gh",
            "api",
            "user",
            "-q",
            ".login"
        });
        if (login.exit_code != 0) {
            return new GitHubCliState(true, false, "", login.output);
        }
        return new GitHubCliState(true, true, login.output.strip(), "");
    }

    public virtual async GitRepoCheckResult check_repository_exists_via_ssh(string username,
                                                                            string repo_name) {
        var remote = "git@github.com:%s/%s.git".printf(username, repo_name);
        var result = yield run_command({
            "git",
            "ls-remote",
            remote
        });
        if (result.exit_code == 0) {
            return new GitRepoCheckResult(true, "");
        }
        var details = result.output.strip();
        if (details.length == 0) {
            details = "Repository not reachable over SSH.";
        }
        return new GitRepoCheckResult(
            false,
            "Could not verify %s via SSH. %s".printf(remote, details)
        );
    }

    public virtual async GitRepoCreateResult create_private_repo_and_verify(string username,
                                                                             string repo_name) {
        var create = yield run_command({
            "gh",
            "repo",
            "create",
            "%s/%s".printf(username, repo_name),
            "--private",
            "--disable-issues",
            "--disable-wiki",
            "--confirm"
        });
        var check = yield check_repository_exists_via_ssh(username, repo_name);
        var details = create.output.strip();
        if (details.length == 0 && !check.exists) {
            details = check.error_text;
        }
        return new GitRepoCreateResult(create.exit_code == 0, check.exists, details);
    }

    public virtual async string probe_github_ssh() {
        var probe = yield run_command({
            "ssh",
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ConnectTimeout=5",
            "-T",
            "git@github.com"
        });
        return probe.output;
    }

    public virtual async GitCommandResult generate_ssh_key(string email, string key_path) {
        return yield run_command({
            "ssh-keygen",
            "-t", "ed25519",
            "-C", email,
            "-f", key_path,
            "-N", ""
        });
    }

    public virtual async GitRemoteApplyResult configure_remote_and_sync(IHolderApi api,
                                                                         string project_id,
                                                                         string remote_url,
                                                                         string branch) throws Error {
        var updated_at = new DateTime.now_utc().to_unix();
        yield api.set_project_git_remote(project_id, remote_url, updated_at);
        var test_result = yield api.test_project_git_remote(project_id, remote_url, branch);
        GitPushResult? push_result = null;
        if (test_result.status == "reachable") {
            push_result = yield api.push_project_git(project_id, branch, true);
        }
        return new GitRemoteApplyResult(test_result, push_result);
    }
}

}
