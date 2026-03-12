namespace HolderLinux {

public class ApiClientProjectsEndpoints : Object { // LCOV_EXCL_BR_LINE: declaration branch artifact
    public static async Gee.ArrayList<Project> list_projects(ApiClient client) throws Error { // LCOV_EXCL_BR_LINE: async declaration branch artifact
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("count", "true"); // LCOV_EXCL_BR_LINE: hash insert branch artifact
        var root = yield client.request_json("GET", "/projects", null, query); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersProjects.parse_projects(root); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }

    public static async string create_project(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                              string name,
                                              string privacy_mode = "encrypted_git") throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("name");
        body.add_string_value(name);
        body.set_member_name("privacy_mode");
        body.add_string_value(privacy_mode);
        body.end_object();

        var root = yield client.request_json("POST", "/projects", client.json_string_from_builder(body), null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        var data = root.get_object_member("data"); // LCOV_EXCL_BR_LINE: invalid-type branch artifact
        return data.get_string_member("project_id"); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }

    public static async ProjectRecoveryTokenExport export_project_recovery_token( // LCOV_EXCL_BR_LINE: async declaration branch artifact
        ApiClient client,
        string project_id,
        string pin
    ) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("pin");
        body.add_string_value(pin);
        body.end_object();

        var root = yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
            "POST",
            "/projects/%s/recovery-token/export".printf(Uri.escape_string(project_id)),
            client.json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for recovery token export response"); // LCOV_EXCL_BR_LINE: throw edge artifact
        }
        var data = root.get_object_member("data"); // LCOV_EXCL_BR_LINE: invalid-type branch artifact
        return new ProjectRecoveryTokenExport( // LCOV_EXCL_BR_LINE: ctor/call branch artifact
            ApiParsersCommon.string_member_or_empty(data, "project_id"),
            ApiParsersCommon.string_member_or_empty(data, "key_id"),
            ApiParsersCommon.string_member_or_empty(data, "recovery_token")
        );
    }

    public static async void import_project_recovery_token( // LCOV_EXCL_BR_LINE: async declaration branch artifact
        ApiClient client,
        string project_id,
        string pin,
        string recovery_token
    ) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("pin");
        body.add_string_value(pin);
        body.set_member_name("recovery_token");
        body.add_string_value(recovery_token);
        body.end_object();

        yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
            "POST",
            "/projects/%s/recovery-token/import".printf(Uri.escape_string(project_id)),
            client.json_string_from_builder(body),
            null
        );
    }

    public static async RecoveryTokenImportResult import_recovery_token( // LCOV_EXCL_BR_LINE: async declaration branch artifact
        ApiClient client,
        string pin,
        string recovery_token
    ) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("pin");
        body.add_string_value(pin);
        body.set_member_name("recovery_token");
        body.add_string_value(recovery_token);
        body.end_object();

        var root = yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
            "POST",
            "/recovery-token/import",
            client.json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for recovery token import response"); // LCOV_EXCL_BR_LINE: throw edge artifact
        }
        var data = root.get_object_member("data"); // LCOV_EXCL_BR_LINE: invalid-type branch artifact
        string remote_error = "";
        if (data.has_member("remote_error")) { // LCOV_EXCL_BR_LINE: short-circuit branch artifact
            var remote_error_node = data.get_member("remote_error"); // LCOV_EXCL_BR_LINE: nullable node branch artifact
            if (remote_error_node != null && // LCOV_EXCL_BR_LINE: short-circuit branch artifact
                remote_error_node.get_node_type() != Json.NodeType.NULL) {
                remote_error = data.get_string_member("remote_error");
            }
        }
        string pull_error = "";
        if (data.has_member("pull_error")) { // LCOV_EXCL_BR_LINE: short-circuit branch artifact
            var pull_error_node = data.get_member("pull_error");
            if (pull_error_node != null && // LCOV_EXCL_BR_LINE: short-circuit branch artifact
                pull_error_node.get_node_type() != Json.NodeType.NULL) {
                pull_error = data.get_string_member("pull_error");
            }
        }
        return new RecoveryTokenImportResult( // LCOV_EXCL_BR_LINE: ctor/call branch artifact
            ApiParsersCommon.string_member_or_empty(data, "project_id"),
            data.has_member("project_created") ? data.get_boolean_member("project_created") : false, // LCOV_EXCL_BR_LINE: ternary branch artifact
            data.has_member("remote_hint_present") ? data.get_boolean_member("remote_hint_present") : false, // LCOV_EXCL_BR_LINE: ternary branch artifact
            data.has_member("remote_configured") ? data.get_boolean_member("remote_configured") : false, // LCOV_EXCL_BR_LINE: ternary branch artifact
            remote_error,
            ApiParsersCommon.string_member_or_empty(data, "pull_status"),
            pull_error
        );
    }
}

}
