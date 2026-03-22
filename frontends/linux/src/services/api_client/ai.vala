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

    public static async Gee.ArrayList<AiMessage> list_ai_messages(ApiClient client,
                                                                  string thread_id) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("thread_id", thread_id);
        var root = yield client.request_json("GET", "/ai/messages", null, query);
        return ApiParsersAi.parse_ai_messages(root);
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

    public static async Gee.ArrayList<AiRuntimeProvider> list_ai_runtime_providers(ApiClient client) // LCOV_EXCL_BR_LINE: async declaration branch artifact
        throws Error { // LCOV_EXCL_BR_LINE: async declaration branch artifact
        var root = yield client.request_json("GET", "/ai/providers/catalog", null, null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersAi.parse_ai_runtime_providers(root); // LCOV_EXCL_BR_LINE: return edge artifact
    }

    public static async AiLocalModelConfigInfo get_ai_local_model_config(ApiClient client) throws Error {
        var root = yield client.request_json("GET", "/ai/local-models/config", null, null);
        return ApiParsersAi.parse_ai_local_model_config(root);
    }

    public static async AiLocalModelConfigInfo set_ai_local_model_config(ApiClient client,
                                                                         string? fast_model,
                                                                         string? strong_model,
                                                                         string? deep_model) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("fast_model");
        if (fast_model != null && fast_model.length > 0) {
            body.add_string_value(fast_model);
        } else {
            body.add_null_value();
        }
        body.set_member_name("strong_model");
        if (strong_model != null && strong_model.length > 0) {
            body.add_string_value(strong_model);
        } else {
            body.add_null_value();
        }
        body.set_member_name("deep_model");
        if (deep_model != null && deep_model.length > 0) {
            body.add_string_value(deep_model);
        } else {
            body.add_null_value();
        }
        body.end_object();

        var root = yield client.request_json("PUT",
                                             "/ai/local-models/config",
                                             client.json_string_from_builder(body),
                                             null);
        return ApiParsersAi.parse_ai_local_model_config(root);
    }

    public static async Gee.ArrayList<AiProviderCredentialState> list_ai_provider_credentials(ApiClient client) // LCOV_EXCL_BR_LINE: async declaration branch artifact
        throws Error { // LCOV_EXCL_BR_LINE: async declaration branch artifact
        var root = yield client.request_json("GET", "/ai/providers/credentials", null, null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersAi.parse_ai_provider_credentials(root); // LCOV_EXCL_BR_LINE: return edge artifact
    }

    public static async Gee.ArrayList<AiProviderSettingState> list_ai_provider_settings(ApiClient client) // LCOV_EXCL_BR_LINE: async declaration branch artifact
        throws Error { // LCOV_EXCL_BR_LINE: async declaration branch artifact
        var root = yield client.request_json("GET", "/ai/providers/settings", null, null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersAi.parse_ai_provider_settings(root); // LCOV_EXCL_BR_LINE: return edge artifact
    }

    public static async void upsert_ai_provider_credential(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                           string provider,
                                                           string api_key) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("provider");
        body.add_string_value(provider);
        body.set_member_name("api_key");
        body.add_string_value(api_key);
        body.end_object();
        yield client.request_json("PUT",
                                  "/ai/providers/credentials",
                                  client.json_string_from_builder(body),
                                  null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
    }

    public static async void delete_ai_provider_credential(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                           string provider) throws Error {
        yield client.request_json("DELETE",
                                  "/ai/providers/credentials/" + provider,
                                  null,
                                  null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
    }

    public static async void set_ai_provider_enabled(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                     string provider,
                                                     bool enabled) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("provider");
        body.add_string_value(provider);
        body.set_member_name("enabled");
        body.add_boolean_value(enabled);
        body.end_object();
        yield client.request_json("PUT",
                                  "/ai/providers/settings",
                                  client.json_string_from_builder(body),
                                  null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
    }

    public static async Gee.ArrayList<AiNudge> list_ai_nudges(ApiClient client,
                                                              string project_id,
                                                              string? card_id = null) throws Error {
        var path = "/ai/nudges?project_id=%s".printf(Uri.escape_string(project_id, null, false));
        if (card_id != null && card_id.length > 0) {
            path += "&card_id=%s".printf(Uri.escape_string(card_id, null, false));
        }
        var root = yield client.request_json("GET", path, null, null);
        return ApiParsersAi.parse_ai_nudge_list(root);
    }

    public static async void dismiss_ai_nudge(ApiClient client, string nudge_id) throws Error {
        yield client.request_json(
            "POST",
            "/ai/nudges/%s/dismiss".printf(Uri.escape_string(nudge_id, null, false)),
            "",
            null
        );
    }

    public static async NudgeEvaluationResult evaluate_nudge_candidate(ApiClient client,
                                                                       string kind,
                                                                       string project_id,
                                                                       string? card_id,
                                                                       int64 created_at,
                                                                       Json.Object facts,
                                                                       string? basis_fingerprint = null,
                                                                       string? basis_commit = null) throws Error {
        var body = new Json.Builder();
        var facts_node = new Json.Node(Json.NodeType.OBJECT);
        facts_node.set_object(facts);
        body.begin_object();
        body.set_member_name("kind");
        body.add_string_value(kind);
        body.set_member_name("project_id");
        body.add_string_value(project_id);
        if (card_id != null && card_id.length > 0) {
            body.set_member_name("card_id");
            body.add_string_value(card_id);
        }
        body.set_member_name("created_at");
        body.add_int_value(created_at);
        if (basis_fingerprint != null && basis_fingerprint.length > 0) {
            body.set_member_name("basis_fingerprint");
            body.add_string_value(basis_fingerprint);
        }
        if (basis_commit != null && basis_commit.length > 0) {
            body.set_member_name("basis_commit");
            body.add_string_value(basis_commit);
        }
        body.set_member_name("facts");
        body.add_value(facts_node);
        body.end_object();

        var root = yield client.request_json("POST",
                                             "/ai/nudges/evaluate",
                                             client.json_string_from_builder(body),
                                             null);
        return ApiParsersAi.parse_nudge_evaluation(root);
    }
}

}
