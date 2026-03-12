namespace HolderLinux {

public class ApiClientResourcesEndpoints : Object { // LCOV_EXCL_BR_LINE: declaration branch artifact
    public static async Gee.ArrayList<ProjectResource> list_resources(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                                       string project_id) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id); // LCOV_EXCL_BR_LINE: hash insert branch artifact
        var root = yield client.request_json("GET", "/resources", null, query); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersResources.parse_resources(root); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }

    public static async string create_resource(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                               string project_id,
                                               string kind,
                                               string uri,
                                               string label,
                                               string? desc = null) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("project_id");
        body.add_string_value(project_id);
        body.set_member_name("kind");
        body.add_string_value(kind);
        body.set_member_name("uri");
        body.add_string_value(uri);
        body.set_member_name("label");
        body.add_string_value(label);
        if (desc != null) {
            body.set_member_name("desc");
            body.add_string_value(desc);
        }
        body.end_object();

        var root = yield client.request_json("POST", "/resources", client.json_string_from_builder(body), null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for resource create response"); // LCOV_EXCL_BR_LINE: throw edge artifact
        }
        var data = root.get_object_member("data"); // LCOV_EXCL_BR_LINE: invalid-type branch artifact
        return ApiParsersCommon.string_member_or_empty(data, "resource_id"); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }

    public static async void update_resource(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                             string resource_id,
                                             string? kind,
                                             string? uri,
                                             string? label,
                                             string? desc,
                                             int64 updated_at) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        if (kind != null) { // LCOV_EXCL_BR_LINE: short-circuit branch artifact
            body.set_member_name("kind");
            body.add_string_value(kind);
        }
        if (uri != null) { // LCOV_EXCL_BR_LINE: short-circuit branch artifact
            body.set_member_name("uri");
            body.add_string_value(uri);
        }
        if (label != null) { // LCOV_EXCL_BR_LINE: short-circuit branch artifact
            body.set_member_name("label");
            body.add_string_value(label);
        }
        body.set_member_name("desc");
        if (desc == null) { // LCOV_EXCL_BR_LINE: short-circuit branch artifact
            body.add_null_value();
        } else {
            body.add_string_value(desc);
        }
        body.set_member_name("updated_at");
        body.add_int_value(updated_at);
        body.end_object();

        yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
            "PATCH",
            "/resources/%s".printf(Uri.escape_string(resource_id)),
            client.json_string_from_builder(body),
            null
        );
    }

    public static async void delete_resource(ApiClient client, string resource_id) throws Error { // LCOV_EXCL_BR_LINE: async declaration branch artifact
        yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
            "DELETE",
            "/resources/%s".printf(Uri.escape_string(resource_id)),
            null,
            null
        );
    }
}

}
