namespace HolderLinux {

public class GitSyncGuided : Object { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public static string github_ssh_remote(string username, string repo_name) {
        return "git@github.com:%s/%s.git".printf(username, repo_name);
    }

    public static string push_intro_text(string username, string repo_name) {
        return "We'll now save this remote and push your cards.\nRemote: %s".printf(
            github_ssh_remote(username, repo_name)
        );
    }

    public static string repo_create_status(bool created_ok) {
        return created_ok
            ? "Repository created with GitHub CLI and verified."
            : "Repository available and verified.";
    }

    public static string create_failure_details(string details) {
        var stripped = details.strip();
        return stripped.length > 0 ? stripped : "Repository could not be created.";
    }

    public static string auto_sync_progress(string username, string repo_name) {
        return "GitHub CLI: creating private repo `%s/%s`...".printf(username, repo_name);
    }

    public static string noreply_email(string username) {
        var stripped = username.strip();
        return stripped.length > 0 ? "%s@users.noreply.github.com".printf(stripped) : "";
    }

    public static string resolve_username(string entry_text, string saved_username) {
        var from_entry = entry_text.strip();
        return from_entry.length > 0 ? from_entry : saved_username;
    }

    public static string prefill_username(string cli_login, string saved_username) {
        return cli_login.strip().length > 0 ? cli_login : saved_username;
    }

    public static string default_repo_name(Project? project) {
        return project != null && project.name != null ? project.name : "";
    }

    public static string? provider_namespace_default(string current_text, string username) {
        if (current_text.strip().length > 0 || username.length == 0) {
            return null;
        }
        return username;
    }
}

}
