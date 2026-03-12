namespace HolderLinux {

public class ApiClientAiEndpoints : Object {
    public static async AiCapabilitiesInfo get_ai_capabilities(ApiClient client,
                                                               string? project_id = null) throws Error {
        HashTable<string, string>? query = null;
        if (project_id != null && project_id.length > 0) {
            query = new HashTable<string, string>(str_hash, str_equal);
            query.insert("project_id", project_id);
        }
        var root = yield client.request_json("GET", "/ai/capabilities", null, query);
        return ApiParsersAi.parse_ai_capabilities(root);
    }

    public static async AiStatusInfo get_ai_status(ApiClient client) throws Error {
        var root = yield client.request_json("GET", "/ai/status", null, null);
        return ApiParsersAi.parse_ai_status(root);
    }

    public static async string start_ai_runner_pull(ApiClient client, string model_tag) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("model");
        body.add_string_value(model_tag);
        body.end_object();

        var root = yield client.request_json("POST", "/ai/runner/pull", client.json_string_from_builder(body), null);
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for runner pull response");
        }
        var data = root.get_object_member("data");
        return data.has_member("job_id") ? data.get_string_member("job_id") : "";
    }

    public static async Gee.ArrayList<AiThreadSummary> list_ai_threads(ApiClient client,
                                                                        string project_id) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        var root = yield client.request_json("GET", "/ai/threads", null, query);
        return ApiParsersAi.parse_ai_threads(root);
    }

    public static async string create_ai_thread(ApiClient client,
                                                string project_id,
                                                string title) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("project_id");
        body.add_string_value(project_id);
        body.set_member_name("title");
        body.add_string_value(title);
        body.end_object();
        var root = yield client.request_json("POST", "/ai/threads", client.json_string_from_builder(body), null);
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai thread create response");
        }
        var data = root.get_object_member("data");
        return ApiParsersCommon.string_member_or_empty(data, "thread_id");
    }

    public static async Gee.ArrayList<AiCatalogProvider> list_ai_provider_catalog(ApiClient client)
        throws Error {
        var root = yield client.request_json_unwrapped("GET", "/ai_catalog.json", null, null);
        return ApiParsersAi.parse_ai_provider_catalog(root);
    }
}

}
