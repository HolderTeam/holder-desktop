namespace HolderLinux {

public class ApiClientGitEndpoints : Object { // LCOV_EXCL_BR_LINE: declaration branch artifact
    public static async Gee.ArrayList<GitProviderCatalogEntry> list_git_provider_catalog(ApiClient client) // LCOV_EXCL_BR_LINE: async signature branch artifact
        throws Error { // LCOV_EXCL_BR_LINE: throws edge artifact
        var root = yield client.request_json_unwrapped("GET", "/git_providers.json", null, null); // LCOV_EXCL_BR_LINE: async yield branch artifact
        return ApiParsersGit.parse_git_provider_catalog(root); // LCOV_EXCL_BR_LINE: return edge artifact
    }

    public static async void set_project_git_remote(ApiClient client, // LCOV_EXCL_BR_LINE: async signature branch artifact
                                                    string project_id,
                                                    string? git_remote_url,
                                                    int64 updated_at) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("git_remote_url");
        if (git_remote_url == null || git_remote_url.strip().length == 0) {
            body.add_null_value();
        } else {
            body.add_string_value(git_remote_url);
        }
        body.set_member_name("updated_at");
        body.add_int_value(updated_at);
        body.end_object();

        yield client.request_json( // LCOV_EXCL_BR_LINE: async yield branch artifact
            "PATCH",
            "/projects/%s".printf(Uri.escape_string(project_id)),
            client.json_string_from_builder(body),
            null
        );
    }

    public static async GitTestRemoteResult test_project_git_remote(ApiClient client, // LCOV_EXCL_BR_LINE: async signature branch artifact
                                                                    string project_id,
                                                                    string? remote_url = null,
                                                                    string branch = "") throws Error {
        var body = new Json.Builder();
        body.begin_object();
        if (remote_url != null) {
            body.set_member_name("remote_url");
            if (remote_url.strip().length == 0) {
                body.add_null_value();
            } else {
                body.add_string_value(remote_url);
            }
        }
        if (branch.strip().length > 0) {
            body.set_member_name("branch");
            body.add_string_value(branch);
        }
        body.end_object();

        var root = yield client.request_json( // LCOV_EXCL_BR_LINE: async yield branch artifact
            "POST",
            "/projects/%s/git/test-remote".printf(Uri.escape_string(project_id)),
            client.json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for git test-remote response"); // LCOV_EXCL_BR_LINE: throw edge artifact
        }
        return ApiParsersGit.parse_git_test_remote_result(root.get_object_member("data")); // LCOV_EXCL_BR_LINE: return edge artifact
    }

    public static async GitPushResult push_project_git(ApiClient client, // LCOV_EXCL_BR_LINE: async signature branch artifact
                                                       string project_id,
                                                       string branch = "",
                                                       bool set_upstream = true) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        if (branch.strip().length > 0) {
            body.set_member_name("branch");
            body.add_string_value(branch);
        }
        body.set_member_name("set_upstream");
        body.add_boolean_value(set_upstream);
        body.end_object();

        var root = yield client.request_json( // LCOV_EXCL_BR_LINE: async yield branch artifact
            "POST",
            "/projects/%s/git/push".printf(Uri.escape_string(project_id)),
            client.json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for git push response"); // LCOV_EXCL_BR_LINE: throw edge artifact
        }
        return ApiParsersGit.parse_git_push_result(root.get_object_member("data")); // LCOV_EXCL_BR_LINE: return edge artifact
    }
}

}
