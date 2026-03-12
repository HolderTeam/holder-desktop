namespace HolderLinux {

public class ApiClientGitEndpoints : Object {
    public static async Gee.ArrayList<GitProviderCatalogEntry> list_git_provider_catalog(ApiClient client)
        throws Error {
        var root = yield client.request_json_unwrapped("GET", "/git_providers.json", null, null);
        return ApiParsersGit.parse_git_provider_catalog(root);
    }

    public static async void set_project_git_remote(ApiClient client,
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

        yield client.request_json(
            "PATCH",
            "/projects/%s".printf(Uri.escape_string(project_id)),
            client.json_string_from_builder(body),
            null
        );
    }

    public static async GitTestRemoteResult test_project_git_remote(ApiClient client,
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

        var root = yield client.request_json(
            "POST",
            "/projects/%s/git/test-remote".printf(Uri.escape_string(project_id)),
            client.json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for git test-remote response");
        }
        return ApiParsersGit.parse_git_test_remote_result(root.get_object_member("data"));
    }

    public static async GitPushResult push_project_git(ApiClient client,
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

        var root = yield client.request_json(
            "POST",
            "/projects/%s/git/push".printf(Uri.escape_string(project_id)),
            client.json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for git push response");
        }
        return ApiParsersGit.parse_git_push_result(root.get_object_member("data"));
    }
}

}
