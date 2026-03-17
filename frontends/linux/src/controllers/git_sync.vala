namespace HolderLinux {

public class GitSyncApplyFlowResult : Object {
    public string summary_text { get; construct; }
    public string toast_message { get; construct; }

    public GitSyncApplyFlowResult(string summary_text, string toast_message) {
        Object(summary_text: summary_text, toast_message: toast_message);
    }
}

public class GitHubCliAutoSyncFlowResult : Object {
    public string status_text { get; construct; }
    public string toast_message { get; construct; }
    public string error_title { get; construct; }
    public string error_details { get; construct; }

    public GitHubCliAutoSyncFlowResult(string status_text,
                                       string toast_message = "",
                                       string error_title = "",
                                       string error_details = "") {
        Object(
            status_text: status_text,
            toast_message: toast_message,
            error_title: error_title,
            error_details: error_details
        );
    }
}

public class GitHubGuidedSyncFlowResult : Object {
    public string status_text { get; construct; }
    public string toast_message { get; construct; }

    public GitHubGuidedSyncFlowResult(string status_text, string toast_message = "") {
        Object(status_text: status_text, toast_message: toast_message);
    }
}

public class GitHubRepoVerifyFlowResult : Object {
    public bool exists { get; construct; }
    public string status_text { get; construct; }
    public string error_title { get; construct; }
    public string error_details { get; construct; }
    public string push_intro_text { get; construct; }

    public GitHubRepoVerifyFlowResult(bool exists,
                                      string status_text,
                                      string error_title = "",
                                      string error_details = "",
                                      string push_intro_text = "") {
        Object(
            exists: exists,
            status_text: status_text,
            error_title: error_title,
            error_details: error_details,
            push_intro_text: push_intro_text
        );
    }
}

public class GitRemoteSetupValidationResult : Object {
    public bool ok { get; construct; }
    public bool is_toast { get; construct; }
    public string message { get; construct; }
    public string error_title { get; construct; }
    public string error_details { get; construct; }

    public GitRemoteSetupValidationResult(bool ok,
                                          bool is_toast = false,
                                          string message = "",
                                          string error_title = "",
                                          string error_details = "") {
        Object(
            ok: ok,
            is_toast: is_toast,
            message: message,
            error_title: error_title,
            error_details: error_details
        );
    }
}

public class GitSyncController : Object {
    private GitSyncService service;
    private Settings? settings;

    public signal void activity_requested(string kind,
                                          string message,
                                          string? project_id,
                                          string? card_id);

    public GitSyncController(GitSyncService? service = null) {
        this.service = service ?? new GitSyncService();
    }

    public void set_settings(Settings? settings) {
        this.settings = settings;
    }

    public string get_saved_github_username() {
        if (settings == null) {
            return "";
        }
        return settings.get_string(AppSettings.KEY_GIT_GITHUB_USERNAME).strip();
    }

    public void set_saved_github_username(string username) {
        if (settings == null) {
            return;
        }
        settings.set_string(AppSettings.KEY_GIT_GITHUB_USERNAME, username);
    }

    public string normalize_repository_name(string project_name) {
        var name = project_name.strip();
        if (name.length == 0) {
            return "";
        }

        var out_name = new StringBuilder();
        for (int i = 0; i < name.length; i++) {
            var c = name.get_char(i);
            if ((c >= 'a' && c <= 'z') ||
                (c >= 'A' && c <= 'Z') ||
                (c >= '0' && c <= '9') ||
                c == '-' || c == '_' || c == '.') {
                out_name.append_unichar(c);
                continue;
            }
            if (c == ' ' || c == '/' || c == '\\') {
                out_name.append_c('-');
            }
        }

        return out_name.str.strip();
    }

    public string fill_remote_template(string template_text,
                                       string namespace_value,
                                       string repo_value,
                                       string host_value) {
        var output = template_text;
        output = output.replace("{owner}", namespace_value);
        output = output.replace("{workspace}", namespace_value);
        output = output.replace("{user}", namespace_value);
        output = output.replace("{org}", namespace_value);
        output = output.replace("{project}", namespace_value);
        output = output.replace("{repo}", repo_value);
        output = output.replace("{host}", host_value);
        output = output.replace("{region}", host_value);
        return output;
    }

    public async GitHubCliState detect_github_cli_state() {
        return yield service.detect_github_cli_state();
    }

    public async GitRepoCheckResult check_repository_exists_via_ssh(string username,
                                                                    string repo_name) {
        return yield service.check_repository_exists_via_ssh(username, repo_name);
    }

    public async GitRepoCreateResult create_private_repo_and_verify(string username,
                                                                    string repo_name) {
        return yield service.create_private_repo_and_verify(username, repo_name);
    }

    public async string probe_github_ssh() {
        return yield service.probe_github_ssh();
    }

    public async GitCommandResult generate_ssh_key(string email, string key_path) {
        return yield service.generate_ssh_key(email, key_path);
    }

    public async GitRemoteApplyResult configure_remote_and_sync(IHolderApi api,
                                                                 string project_id,
                                                                 string remote_url,
                                                                 string branch) throws Error {
        return yield service.configure_remote_and_sync(api, project_id, remote_url, branch);
    }

    private static string format_push_commit_suffix(GitPushResult push_result) {
        var commit = push_result.local_head_commit.strip();
        if (commit.length == 0) {
            return "";
        }
        return " [local_head_commit=%s]".printf(commit);
    }

    public async GitSyncApplyFlowResult apply_project_git_remote_and_sync(IHolderApi api,
                                                                           Project selected_project,
                                                                           string remote_url,
                                                                           string branch) throws Error {
        var apply_result = yield configure_remote_and_sync(
            api,
            selected_project.project_id,
            remote_url,
            branch
        );

        var test_result = apply_result.test_result;
        var push_result = apply_result.push_result;

        var lines = new StringBuilder();
        lines.append("Project: %s\n".printf(selected_project.name));
        lines.append("Remote: %s\n".printf(remote_url));
        if (branch.length > 0) {
            lines.append("Branch: %s\n".printf(branch));
        }
        if (test_result != null) {
            lines.append("\nRemote test: %s".printf(test_result.status));
            if (test_result.error_message.strip().length > 0) {
                lines.append(" (%s)".printf(test_result.error_message.strip()));
            }
            lines.append("\n");
        } else {
            lines.append("\nRemote test: not run\n");
        }

        var toast_message = "";
        if (push_result != null) {
            lines.append("Push: %s".printf(push_result.status));
            if (push_result.error_message.strip().length > 0) {
                lines.append(" (%s)".printf(push_result.error_message.strip()));
            }
            if (push_result.next_action.strip().length > 0) {
                lines.append("\nNext action: %s".printf(push_result.next_action));
            }
            if (push_result.status == "pushed" || push_result.status == "up_to_date") {
                toast_message = "Git remote configured and synced.";
            }
            activity_requested(
                "result.git.push",
                "Git push result: %s%s".printf(
                    push_result.status,
                    format_push_commit_suffix(push_result)
                ),
                selected_project.project_id,
                null
            );
        } else {
            lines.append("Push: not run");
        }

        return new GitSyncApplyFlowResult(lines.str.strip(), toast_message);
    }

    public async GitHubCliAutoSyncFlowResult run_github_cli_auto_sync_flow(IHolderApi api,
                                                                            Project selected_project,
                                                                            string username) throws Error {
        var repo_name = normalize_repository_name(selected_project.name ?? "");
        if (repo_name.length == 0) {
            throw new IOError.FAILED(
                "Project name does not produce a valid repository name. Rename project or use manual setup."
            );
        }

        var create_result = yield create_private_repo_and_verify(username, repo_name);
        if (!create_result.exists) {
            var details = create_result.details.strip();
            if (details.length == 0) {
                details = "Repository could not be created.";
            }
            return new GitHubCliAutoSyncFlowResult(
                "GitHub CLI setup failed: %s".printf(details),
                "",
                "GitHub CLI setup failed",
                details
            );
        }

        var remote_url = "git@github.com:%s/%s.git".printf(username, repo_name);
        var apply_result = yield configure_remote_and_sync(
            api,
            selected_project.project_id,
            remote_url,
            ""
        );
        var test_result = apply_result.test_result;
        var push_result = apply_result.push_result;

        var status = new StringBuilder();
        status.append("GitHub CLI: %s repo `%s/%s`. ".printf(
            create_result.created_ok ? "created" : "using existing",
            username,
            repo_name
        ));
        if (test_result != null) {
            status.append("Remote test: %s".printf(test_result.status));
            if (test_result.error_message.strip().length > 0) {
                status.append(" (%s)".printf(test_result.error_message.strip()));
            }
            status.append(". ");
        }

        var toast_message = "";
        if (push_result != null) {
            status.append("Push: %s".printf(push_result.status));
            if (push_result.error_message.strip().length > 0) {
                status.append(" (%s)".printf(push_result.error_message.strip()));
            }
            status.append(".");
            if (push_result.status == "pushed" || push_result.status == "up_to_date") {
                toast_message = "GitHub CLI sync setup completed.";
            }
            activity_requested(
                "result.git.push",
                "Git push result: %s%s".printf(
                    push_result.status,
                    format_push_commit_suffix(push_result)
                ),
                selected_project.project_id,
                null
            );
        } else {
            status.append("Push not run.");
        }

        return new GitHubCliAutoSyncFlowResult(status.str, toast_message);
    }

    public async GitHubGuidedSyncFlowResult run_github_guided_sync_flow(IHolderApi api,
                                                                         Project selected_project,
                                                                         string username,
                                                                         string repo_name) throws Error {
        var remote_url = "git@github.com:%s/%s.git".printf(username, repo_name);
        var apply_result = yield configure_remote_and_sync(
            api,
            selected_project.project_id,
            remote_url,
            ""
        );
        var test_result = apply_result.test_result;
        var push_result = apply_result.push_result;

        Project? refreshed_project = null;
        var projects = yield api.list_projects();
        foreach (var project in projects) {
            if (project.project_id == selected_project.project_id) {
                refreshed_project = project;
                break;
            }
        }

        var lines = new StringBuilder();
        if (test_result != null) {
            lines.append("Remote test: %s".printf(test_result.status));
            if (test_result.error_message.strip().length > 0) {
                lines.append(" (%s)".printf(test_result.error_message.strip()));
            }
            lines.append("\n");
        } else {
            lines.append("Remote test: not run\n");
        }

        var toast_message = "";
        if (push_result != null) {
            lines.append("Push: %s".printf(push_result.status));
            if (push_result.error_message.strip().length > 0) {
                lines.append(" (%s)".printf(push_result.error_message.strip()));
            }
            lines.append("\n");
            if (push_result.next_action.strip().length > 0) {
                lines.append("Next action: %s\n".printf(push_result.next_action));
            }
            if (push_result.status == "pushed" || push_result.status == "up_to_date") {
                toast_message = "Git sync setup completed.";
            }
            activity_requested(
                "result.git.push",
                "Git push result: %s%s".printf(
                    push_result.status,
                    format_push_commit_suffix(push_result)
                ),
                selected_project.project_id,
                null
            );
        } else {
            lines.append("Push: not run\n");
        }

        if (refreshed_project != null) {
            lines.append("\n");
            lines.append("Sync state: ");
            var status = refreshed_project.sync.last_push_status.strip();
            lines.append(status.length > 0 ? status : "unknown");
            lines.append("\n");
            lines.append("Last push: ");
            lines.append(format_sync_time(
                refreshed_project.sync.has_last_push_at,
                refreshed_project.sync.last_push_at
            ));
            lines.append("\n");
            lines.append("Push retry count: %d\n".printf(refreshed_project.sync.retry_count));
            lines.append("Pull retry count: %d".printf(refreshed_project.sync.pull_retry_count));
            if (refreshed_project.sync.last_sync_error.strip().length > 0) {
                lines.append("\n");
                lines.append("Error: %s".printf(refreshed_project.sync.last_sync_error));
            }
        }

        return new GitHubGuidedSyncFlowResult(lines.str.strip(), toast_message);
    }

    public async GitHubRepoVerifyFlowResult verify_github_repository_exists_flow(string username,
                                                                                  string repo_name) {
        var repo_check = yield check_repository_exists_via_ssh(username, repo_name);
        if (repo_check.exists) {
            var remote_url = "git@github.com:%s/%s.git".printf(username, repo_name);
            return new GitHubRepoVerifyFlowResult(
                true,
                "Repository found on GitHub.",
                "",
                "",
                "We'll now save this remote and push your cards.\nRemote: %s".printf(remote_url)
            );
        }

        var details = repo_check.error_text.length > 0 ? repo_check.error_text : "Repository not found.";
        return new GitHubRepoVerifyFlowResult(
            false,
            details,
            "Repository check failed",
            "Could not find https://github.com/%s/%s . Create it first, then click Next again."
                .printf(username, repo_name)
        );
    }

    public GitRemoteSetupValidationResult validate_remote_setup_inputs(Project? selected_project,
                                                                       IHolderApi? api,
                                                                       string remote_url) {
        if (selected_project == null) {
            return new GitRemoteSetupValidationResult(false, true, "Select a project first.");
        }
        if (api == null) {
            return new GitRemoteSetupValidationResult(
                false,
                false,
                "",
                "Git sync failed",
                "Backend API client is not ready."
            );
        }
        if (remote_url.strip().length == 0) {
            return new GitRemoteSetupValidationResult(false, true, "Remote URL is required.");
        }
        return new GitRemoteSetupValidationResult(true);
    }

    private string format_sync_time(bool has_timestamp, int64 timestamp) {
        if (!has_timestamp || timestamp <= 0) {
            return "never";
        }
        return "%lld".printf(timestamp);
    }
}

}
