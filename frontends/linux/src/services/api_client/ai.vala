namespace HolderLinux {

public class ApiClientAiEndpoints : Object { // LCOV_EXCL_BR_LINE: declaration branch artifact
    public static async AiCapabilitiesInfo get_ai_capabilities(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                               string? project_id = null) throws Error {
        HashTable<string, string>? query = null;
        if (project_id != null && project_id.length > 0) {
            query = new HashTable<string, string>(str_hash, str_equal); // LCOV_EXCL_BR_LINE: allocator edge artifact
            query.insert("project_id", project_id);
        }
        var root = yield client.request_json("GET", "/ai/capabilities", null, query); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersAi.parse_ai_capabilities(root); // LCOV_EXCL_BR_LINE: return edge artifact
    }

    public static async AiStatusInfo get_ai_status(ApiClient client) throws Error { // LCOV_EXCL_BR_LINE: async declaration branch artifact
        var root = yield client.request_json("GET", "/ai/status", null, null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersAi.parse_ai_status(root); // LCOV_EXCL_BR_LINE: return edge artifact
    }

    public static async string start_ai_runner_pull(ApiClient client, string model_tag) throws Error { // LCOV_EXCL_BR_LINE: async declaration branch artifact
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("model");
        body.add_string_value(model_tag);
        body.end_object();

        var root = yield client.request_json("POST", "/ai/runner/pull", client.json_string_from_builder(body), null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for runner pull response"); // LCOV_EXCL_BR_LINE: throw edge artifact
        }
        var data = root.get_object_member("data"); // LCOV_EXCL_BR_LINE: invalid-type branch artifact
        return data.has_member("job_id") ? data.get_string_member("job_id") : ""; // LCOV_EXCL_BR_LINE: return edge artifact
    }

    public static async Gee.ArrayList<AiThreadSummary> list_ai_threads(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                                        string project_id) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        var root = yield client.request_json("GET", "/ai/threads", null, query); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersAi.parse_ai_threads(root); // LCOV_EXCL_BR_LINE: return edge artifact
    }

    public static async string create_ai_thread(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                string project_id,
                                                string title) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("project_id");
        body.add_string_value(project_id);
        body.set_member_name("title");
        body.add_string_value(title);
        body.end_object();
        var root = yield client.request_json("POST", "/ai/threads", client.json_string_from_builder(body), null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai thread create response"); // LCOV_EXCL_BR_LINE: throw edge artifact
        }
        var data = root.get_object_member("data"); // LCOV_EXCL_BR_LINE: invalid-type branch artifact
        return ApiParsersCommon.string_member_or_empty(data, "thread_id"); // LCOV_EXCL_BR_LINE: return edge artifact
    }

    public static async Gee.ArrayList<AiCatalogProvider> list_ai_provider_catalog(ApiClient client) // LCOV_EXCL_BR_LINE: async declaration branch artifact
        throws Error { // LCOV_EXCL_BR_LINE: async declaration branch artifact
        var root = yield client.request_json_unwrapped("GET", "/ai_catalog.json", null, null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersAi.parse_ai_provider_catalog(root); // LCOV_EXCL_BR_LINE: return edge artifact
    }
}

}
