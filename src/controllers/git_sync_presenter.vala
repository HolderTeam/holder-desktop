namespace HolderLinux {

internal class GitCliControlsPresentation : Object {
    public string repo_mode_text { get; construct; }
    public string repo_manual_label { get; construct; }
    public string repo_manual_instructions_markup { get; construct; }
    public string cli_status_text { get; construct; }
    public bool cli_buttons_visible { get; construct; }
    public bool cli_buttons_sensitive { get; construct; }

    public GitCliControlsPresentation(string repo_mode_text,
                                      string repo_manual_label,
                                      string repo_manual_instructions_markup,
                                      string cli_status_text,
                                      bool cli_buttons_visible,
                                      bool cli_buttons_sensitive) {
        Object(
            repo_mode_text: repo_mode_text,
            repo_manual_label: repo_manual_label,
            repo_manual_instructions_markup: repo_manual_instructions_markup,
            cli_status_text: cli_status_text,
            cli_buttons_visible: cli_buttons_visible,
            cli_buttons_sensitive: cli_buttons_sensitive
        );
    }
}

internal class GitConfiguredStatePresentation : Object {
    public string repository_text { get; construct; }
    public string remote_url { get; construct; }
    public string status_text { get; construct; }
    public string detail_text { get; construct; }
    public string web_url { get; construct; }
    public string status_class { get; construct; }

    public GitConfiguredStatePresentation(string repository_text,
                                           string remote_url,
                                           string status_text,
                                           string detail_text,
                                           string web_url,
                                           string status_class) {
        Object(
            repository_text: repository_text,
            remote_url: remote_url,
            status_text: status_text,
            detail_text: detail_text,
            web_url: web_url,
            status_class: status_class
        );
    }
}

internal class GitProviderRemotePreview : Object {
    public string remote_url { get; construct; }
    public string template_label { get; construct; }
    public bool needs_host { get; construct; }
    public bool clear_host { get; construct; }

    public GitProviderRemotePreview(string remote_url,
                                    string template_label,
                                    bool needs_host,
                                    bool clear_host) {
        Object(
            remote_url: remote_url,
            template_label: template_label,
            needs_host: needs_host,
            clear_host: clear_host
        );
    }
}

internal class GitGuidedSshKeyUiPresentation : Object {
    public bool missing_key_visible { get; construct; }
    public bool key_ready_visible { get; construct; }
    public bool copy_key_sensitive { get; construct; }
    public bool open_keys_visible { get; construct; }

    public GitGuidedSshKeyUiPresentation(bool missing_key_visible,
                                         bool key_ready_visible,
                                         bool copy_key_sensitive,
                                         bool open_keys_visible) {
        Object(
            missing_key_visible: missing_key_visible,
            key_ready_visible: key_ready_visible,
            copy_key_sensitive: copy_key_sensitive,
            open_keys_visible: open_keys_visible
        );
    }
}

internal class GitGuidedSshProbePresentation : Object {
    public bool authenticated { get; construct; }
    public string status_text { get; construct; }

    public GitGuidedSshProbePresentation(bool authenticated, string status_text) {
        Object(authenticated: authenticated, status_text: status_text);
    }
}

internal class GitSyncPresenter : Object {
    private const string BROWSER_MANUAL_INSTRUCTIONS =
        "Fill in the repository name, and you need to tell us the same name below.\n\n" +
        "You can leave the description blank.\n\n" +
        "<b>Under 2. Configuration\n" +
        "there is \"Choose visibility *\"\n" +
        "Change the drop down to 🔒Private</b>\n\n" +
        "We want the external repository to be empty, so leave the next three options alone.\n\n" +
        "So under \"Add README\", leave it \"Off\"\n" +
        "Under \"Add .gitignore\", leave it at \"No .gitignore\"\n" +
        "Under \"Add license\", leave it at \"No licence\"\n\n" +
        "Click the green button called \"Create repository\"";

    private const string CLI_BROWSER_FALLBACK_INSTRUCTIONS =
        "If you prefer the browser route, create it manually at GitHub:\n\n" +
        "<b>Under 2. Configuration\n" +
        "there is \"Choose visibility *\"\n" +
        "Change the drop down to 🔒Private</b>\n\n" +
        "Leave README/.gitignore/license unset so the remote starts empty.";

    public static GitCliControlsPresentation git_cli_controls(bool cli_available,
                                                              bool cli_authenticated,
                                                              string cli_login) {
        var has_login = cli_login.strip().length > 0;
        var can_use_cli = cli_authenticated && has_login;
        string cli_status;
        if (!cli_available) {
            cli_status = "GitHub CLI not detected. Install `gh` to enable automatic username and repo creation.";
        } else if (!cli_authenticated) {
            cli_status = "GitHub CLI detected, but not authenticated. Run `gh auth login` in a terminal to enable automation.";
        } else {
            cli_status = "GitHub CLI authenticated as `%s`. Use the automatic button above to create repo, set remote, and push."
                .printf(cli_login);
        }

        return new GitCliControlsPresentation(
            can_use_cli
                ? "Recommended on this device: create the private repository with GitHub CLI."
                : "Create a private repository for this project.",
            can_use_cli ? "Browser fallback:" : "Create a new repository:",
            can_use_cli ? CLI_BROWSER_FALLBACK_INSTRUCTIONS : BROWSER_MANUAL_INSTRUCTIONS,
            cli_status,
            cli_available,
            can_use_cli
        );
    }

    public static GitConfiguredStatePresentation configured_state(Project project, int64 now) {
        var remote_url = project.git_remote_url != null ? project.git_remote_url.strip() : "";
        var repository_text = repository_name_from_remote(remote_url);
        var status_text = "Ready to sync";
        var status_class = "accent";
        var sync = project.sync;
        var last_error = sync.last_sync_error.strip();
        var push_status = sync.last_push_status.strip().down();
        var pull_status = sync.last_pull_status.strip().down();

        if (last_error.length > 0 || is_failed_status(push_status) || is_failed_status(pull_status)) {
            status_text = "Needs attention";
            status_class = "error";
        } else if (sync.uncommitted_changes_count > 0 || sync.unpushed_commits_count > 0) {
            status_text = "Changes waiting";
            status_class = "warning";
        } else if (sync.has_last_push_at || sync.has_last_pull_at ||
                   push_status == "pushed" || push_status == "up_to_date") {
            status_text = "Up to date";
            status_class = "success";
        }

        var details = new StringBuilder();
        var latest_push = sync.has_last_push_at ? sync.last_push_at : 0;
        var latest_pull = sync.has_last_pull_at ? sync.last_pull_at : 0;
        var latest_success = latest_push > latest_pull ? latest_push : latest_pull;
        if (latest_success > 0) {
            details.append("Last successful sync %s".printf(format_relative_time(now, latest_success)));
        } else {
            details.append("No successful sync recorded yet");
        }
        if (sync.uncommitted_changes_count > 0) {
            details.append(" · %d uncommitted change%s".printf(
                sync.uncommitted_changes_count,
                sync.uncommitted_changes_count == 1 ? "" : "s"
            ));
        }
        if (sync.unpushed_commits_count > 0) {
            details.append(" · %d commit%s waiting to push".printf(
                sync.unpushed_commits_count,
                sync.unpushed_commits_count == 1 ? "" : "s"
            ));
        }
        if (last_error.length > 0) {
            details.append("\n%s".printf(last_error));
        }

        return new GitConfiguredStatePresentation(
            repository_text,
            remote_url,
            status_text,
            details.str,
            web_url_from_remote(remote_url),
            status_class
        );
    }

    public static string web_url_from_remote(string remote_url) {
        var remote = remote_url.strip();
        if (remote.has_prefix("http://") || remote.has_prefix("https://")) {
            return strip_git_suffix(remote);
        }
        if (remote.has_prefix("git@")) {
            var separator = remote.index_of(":");
            if (separator > 4 && separator + 1 < remote.length) {
                var host = remote.substring(4, separator - 4);
                var path = remote.substring(separator + 1);
                return "https://%s/%s".printf(host, strip_git_suffix(path));
            }
        }
        if (remote.has_prefix("ssh://")) {
            var remainder = remote.substring("ssh://".length);
            var slash = remainder.index_of("/");
            if (slash > 0 && slash + 1 < remainder.length) {
                var authority = remainder.substring(0, slash);
                var at = authority.last_index_of("@");
                var host = at >= 0 ? authority.substring(at + 1) : authority;
                var path = remainder.substring(slash + 1);
                return "https://%s/%s".printf(host, strip_git_suffix(path));
            }
        }
        return "";
    }

    private static string repository_name_from_remote(string remote_url) {
        var web_url = web_url_from_remote(remote_url);
        if (web_url.length == 0) {
            return remote_url;
        }
        var scheme = web_url.index_of("://");
        return scheme >= 0 ? web_url.substring(scheme + 3) : web_url;
    }

    private static string strip_git_suffix(string value) {
        return value.has_suffix(".git") ? value.substring(0, value.length - 4) : value;
    }

    private static bool is_failed_status(string status) {
        return status.contains("fail") || status.contains("error") ||
               status.contains("denied") || status.contains("conflict");
    }

    private static string format_relative_time(int64 now, int64 timestamp) {
        var delta = now - timestamp;
        if (delta < 60) {
            return "just now";
        }
        if (delta < 3600) {
            return "%lldm ago".printf(delta / 60);
        }
        if (delta < 86400) {
            return "%lldh ago".printf(delta / 3600);
        }
        return "%lldd ago".printf(delta / 86400);
    }

    public static GitProviderRemotePreview provider_remote_preview(GitProviderCatalogEntry? provider,
                                                                   string transport,
                                                                   string namespace_value,
                                                                   string repo_value,
                                                                   string host_value) {
        if (provider == null) {
            return new GitProviderRemotePreview("", "No provider selected.", false, false);
        }

        var template_text = transport == "https" ? provider.https_example : provider.ssh_example;
        if (template_text.strip().length == 0) {
            template_text = transport == "https"
                ? "https://{host}/{owner}/{repo}.git"
                : "git@{host}:{owner}/{repo}.git";
        }

        var resolved_host = host_value.strip();
        if (resolved_host.length == 0) {
            resolved_host = default_host_for_provider(provider.id);
        }

        var remote_url = fill_remote_template(
            template_text,
            namespace_value.strip(),
            repo_value.strip(),
            resolved_host
        );
        var needs_host = template_text.contains("{host}") || template_text.contains("{region}");
        return new GitProviderRemotePreview(
            remote_url,
            "Template: %s\nYou can edit Remote URL directly before saving.".printf(template_text),
            needs_host,
            !needs_host
        );
    }

    public static string fill_remote_template(string template_text,
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

    public static GitGuidedSshKeyUiPresentation guided_ssh_key_ui(bool has_key,
                                                                  bool github_authenticated,
                                                                  string public_key) {
        return new GitGuidedSshKeyUiPresentation(
            !has_key,
            has_key && !github_authenticated,
            has_key && !github_authenticated && public_key.strip().length > 0,
            !github_authenticated
        );
    }

    public static GitGuidedSshProbePresentation guided_ssh_probe_status(string probe_output) {
        var probe_plain = probe_output.strip();
        var probe = probe_plain.down();
        if (probe.contains("successfully authenticated")) {
            return new GitGuidedSshProbePresentation(
                true,
                "SSH key found and authenticated with GitHub. You're all set."
            );
        }
        if (probe.contains("permission denied")) {
            return new GitGuidedSshProbePresentation(
                false,
                "SSH key found locally, but GitHub rejected authentication. Copy this key and add it at GitHub SSH settings."
            );
        }
        if (probe_plain.length > 0) {
            return new GitGuidedSshProbePresentation(
                false,
                "SSH key found locally. GitHub verification result: %s".printf(probe_plain)
            );
        }
        return new GitGuidedSshProbePresentation(
            false,
            "SSH key found locally. Could not verify with GitHub."
        );
    }

    private static string default_host_for_provider(string provider_id) {
        switch (provider_id) {
        case "github":
            return "github.com";
        case "gitlab":
            return "gitlab.com";
        case "bitbucket":
            return "bitbucket.org";
        case "codeberg":
            return "codeberg.org";
        case "sourcehut":
            return "git.sr.ht";
        default:
            return "";
        }
    }
}

}
