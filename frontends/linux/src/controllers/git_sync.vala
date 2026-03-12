namespace HolderLinux {

public class GitSyncController : Object {
    private GitSyncService service;
    private Settings? settings;

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
}

}
