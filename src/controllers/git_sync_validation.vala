namespace HolderLinux {

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

public enum GuidedRetreat {
    NONE,
    USERNAME_PAGE,
    REPOSITORY_PAGE
}

public class GuidedInputCheck : Object {
    public bool ok { get; construct; }
    public string toast_message { get; construct; }
    public GuidedRetreat retreat { get; construct; }

    public GuidedInputCheck(bool ok,
                            string toast_message = "",
                            GuidedRetreat retreat = GuidedRetreat.NONE) {
        Object(ok: ok, toast_message: toast_message, retreat: retreat);
    }
}

public class GitSyncValidation : Object {
    public static GitRemoteSetupValidationResult project_and_api(Project? project, bool api_ready) {
        if (project == null) {
            return new GitRemoteSetupValidationResult(false, true, "Select a project first.");
        }
        if (!api_ready) {
            return new GitRemoteSetupValidationResult(
                false,
                false,
                "",
                "Git sync failed",
                "Backend API client is not ready."
            );
        }
        return new GitRemoteSetupValidationResult(true);
    }

    public static GitRemoteSetupValidationResult auto_sync_inputs(Project? project,
                                                                   bool api_ready,
                                                                   bool cli_authenticated,
                                                                   string cli_login) {
        var base_result = project_and_api(project, api_ready);
        if (!base_result.ok) {
            return base_result;
        }
        if (!cli_authenticated || cli_login.strip().length == 0) {
            return new GitRemoteSetupValidationResult(
                false,
                true,
                "GitHub CLI is not authenticated. Run `gh auth login` first."
            );
        }
        return new GitRemoteSetupValidationResult(true);
    }

    public static GuidedInputCheck cli_repo_inputs(string username, string repo_name) {
        if (username.length == 0 || repo_name.length == 0) {
            return new GuidedInputCheck(false, "GitHub username and repository name are required.");
        }
        return new GuidedInputCheck(true);
    }

    public static GuidedInputCheck verify_repo_inputs(string username, string repo_name) {
        if (username.length == 0) {
            return new GuidedInputCheck(false, "GitHub username is required.", GuidedRetreat.USERNAME_PAGE);
        }
        if (repo_name.length == 0) {
            return new GuidedInputCheck(false, "Repository name is required.");
        }
        return new GuidedInputCheck(true);
    }

    public static GuidedInputCheck push_inputs(string username, string repo_name) {
        if (username.length == 0 || repo_name.length == 0) {
            return new GuidedInputCheck(
                false,
                "GitHub username and repository name are required.",
                GuidedRetreat.REPOSITORY_PAGE
            );
        }
        return new GuidedInputCheck(true);
    }
}

}
