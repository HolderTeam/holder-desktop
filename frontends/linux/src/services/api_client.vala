namespace HolderLinux {

public class ApiClient : Object, IHolderApi {
    private IApiHttpTransport transport;
    private string base_url;
    private string auth_token;

    public ApiClient(string base_url, string auth_token, IApiHttpTransport? transport = null) {
        this.base_url = base_url;
        this.auth_token = auth_token;
        this.transport = transport ?? new SoupApiHttpTransport();
    }

    public async void health_check() throws Error {
        var root = yield request_json("GET", "/health", null, null);
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data in /health response");
        }
    }

    public async HealthInfo get_health_info() throws Error {
        var root = yield request_json("GET", "/health", null, null);
        return ApiParsersHealth.parse_health_info(root);
    }

    public async Gee.ArrayList<Project> list_projects() throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("count", "true");
        var root = yield request_json("GET", "/projects", null, query);
        return ApiParsersProjects.parse_projects(root);
    }

    public async string create_project(string name,
                                       string privacy_mode = "encrypted_git") throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("name");
        body.add_string_value(name);
        body.set_member_name("privacy_mode");
        body.add_string_value(privacy_mode);
        body.end_object();

        var root = yield request_json("POST", "/projects", json_string_from_builder(body), null);
        var data = root.get_object_member("data");
        return data.get_string_member("project_id");
    }

    public async ProjectRecoveryTokenExport export_project_recovery_token(
        string project_id,
        string pin
    ) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("pin");
        body.add_string_value(pin);
        body.end_object();

        var root = yield request_json(
            "POST",
            "/projects/%s/recovery-token/export".printf(Uri.escape_string(project_id)),
            json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for recovery token export response");
        }
        var data = root.get_object_member("data");
        return new ProjectRecoveryTokenExport(
            ApiParsersCommon.string_member_or_empty(data, "project_id"),
            ApiParsersCommon.string_member_or_empty(data, "key_id"),
            ApiParsersCommon.string_member_or_empty(data, "recovery_token")
        );
    }

    public async void import_project_recovery_token(
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

        yield request_json(
            "POST",
            "/projects/%s/recovery-token/import".printf(Uri.escape_string(project_id)),
            json_string_from_builder(body),
            null
        );
    }

    public async RecoveryTokenImportResult import_recovery_token(
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

        var root = yield request_json(
            "POST",
            "/recovery-token/import",
            json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for recovery token import response");
        }
        var data = root.get_object_member("data");
        string remote_error = "";
        if (data.has_member("remote_error")) {
            var remote_error_node = data.get_member("remote_error");
            if (remote_error_node != null &&
                remote_error_node.get_node_type() != Json.NodeType.NULL) {
                remote_error = data.get_string_member("remote_error");
            }
        }
        string pull_error = "";
        if (data.has_member("pull_error")) {
            var pull_error_node = data.get_member("pull_error");
            if (pull_error_node != null &&
                pull_error_node.get_node_type() != Json.NodeType.NULL) {
                pull_error = data.get_string_member("pull_error");
            }
        }
        return new RecoveryTokenImportResult(
            ApiParsersCommon.string_member_or_empty(data, "project_id"),
            data.has_member("project_created") ? data.get_boolean_member("project_created") : false,
            data.has_member("remote_hint_present") ? data.get_boolean_member("remote_hint_present") : false,
            data.has_member("remote_configured") ? data.get_boolean_member("remote_configured") : false,
            remote_error,
            ApiParsersCommon.string_member_or_empty(data, "pull_status"),
            pull_error
        );
    }

    public async Gee.ArrayList<CardSummary> list_cards(string project_id,
                                                       string view = "tree",
                                                       string? parent_card_id = null,
                                                       int limit = 0) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        query.insert("view", view);
        if (parent_card_id != null && parent_card_id.strip().length > 0) {
            query.insert("parent_card_id", parent_card_id);
        }
        if (limit > 0) {
            query.insert("limit", limit.to_string());
        }
        var root = yield request_json("GET", "/cards", null, query);
        return ApiParsersCards.parse_cards(root);
    }

    public async CardContextData get_card_context(string project_id,
                                                  string? parent_card_id = null) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        query.insert("count", "true");
        if (parent_card_id != null && parent_card_id.strip().length > 0) {
            query.insert("parent_card_id", parent_card_id);
        }
        var root = yield request_json("GET", "/cards/context", null, query);
        return ApiParsersCards.parse_card_context(root);
    }

    public async CardDetail get_card(string card_id) throws Error {
        var root = yield request_json("GET", "/cards/%s".printf(Uri.escape_string(card_id)), null, null);
        return ApiParsersCards.parse_card_detail(root);
    }

    public async Gee.ArrayList<CardLink> list_card_links(string card_id) throws Error {
        var root = yield request_json(
            "GET",
            "/cards/%s/links".printf(Uri.escape_string(card_id)),
            null,
            null
        );
        return ApiParsersCards.parse_card_links(root);
    }

    public async Gee.ArrayList<CardLink> list_card_backlinks(string card_id) throws Error {
        var root = yield request_json(
            "GET",
            "/cards/%s/backlinks".printf(Uri.escape_string(card_id)),
            null,
            null
        );
        return ApiParsersCards.parse_card_links(root);
    }

    public async Gee.ArrayList<ProjectResource> list_resources(string project_id) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        var root = yield request_json("GET", "/resources", null, query);
        return ApiParsersResources.parse_resources(root);
    }

    public async Gee.ArrayList<TrashItem> list_trash_items(string project_id,
                                                            string type = "all") throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        if (type != null && type.strip().length > 0) {
            query.insert("type", type.strip());
        }
        var root = yield request_json("GET", "/trash", null, query);
        return ApiParsersTrash.parse_trash_items(root);
    }

    public async void empty_trash(string project_id, string type = "all") throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        if (type != null && type.strip().length > 0) {
            query.insert("type", type.strip());
        }
        yield request_json("DELETE", "/trash", null, query);
    }

    public async void restore_trash_item(string item_type, string item_id) throws Error {
        if (item_type == "card") {
            yield request_json(
                "POST",
                "/cards/%s/restore".printf(Uri.escape_string(item_id)),
                null,
                null
            );
            return;
        }

        if (item_type == "ai_message") {
            yield request_json(
                "POST",
                "/ai/messages/%s/restore".printf(Uri.escape_string(item_id)),
                null,
                null
            );
            return;
        }

        throw new ApiError.PROTOCOL("Unsupported trash item type: %s".printf(item_type));
    }

    public async void hard_delete_trash_item(string item_type, string item_id) throws Error {
        yield request_json(
            "DELETE",
            "/trash/%s/%s".printf(Uri.escape_string(item_type), Uri.escape_string(item_id)),
            null,
            null
        );
    }

    public async string create_resource(string project_id,
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

        var root = yield request_json("POST", "/resources", json_string_from_builder(body), null);
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for resource create response");
        }
        var data = root.get_object_member("data");
        return ApiParsersCommon.string_member_or_empty(data, "resource_id");
    }

    public async void update_resource(string resource_id,
                                      string? kind,
                                      string? uri,
                                      string? label,
                                      string? desc,
                                      int64 updated_at) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        if (kind != null) {
            body.set_member_name("kind");
            body.add_string_value(kind);
        }
        if (uri != null) {
            body.set_member_name("uri");
            body.add_string_value(uri);
        }
        if (label != null) {
            body.set_member_name("label");
            body.add_string_value(label);
        }
        body.set_member_name("desc");
        if (desc == null) {
            body.add_null_value();
        } else {
            body.add_string_value(desc);
        }
        body.set_member_name("updated_at");
        body.add_int_value(updated_at);
        body.end_object();

        yield request_json(
            "PATCH",
            "/resources/%s".printf(Uri.escape_string(resource_id)),
            json_string_from_builder(body),
            null
        );
    }

    public async void delete_resource(string resource_id) throws Error {
        yield request_json(
            "DELETE",
            "/resources/%s".printf(Uri.escape_string(resource_id)),
            null,
            null
        );
    }

    public async CardLink create_card_link(string from_card_id,
                                           string to_card_id,
                                           string kind = "ref",
                                           string? label = null,
                                           string to_type = "card") throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("to_card_id");
        body.add_string_value(to_card_id);
        if (to_type != null && to_type.length > 0 && to_type != "card") {
            body.set_member_name("to_type");
            body.add_string_value(to_type);
        }
        if (kind != null && kind.strip().length > 0) {
            body.set_member_name("kind");
            body.add_string_value(kind.strip());
        }
        if (label != null && label.strip().length > 0) {
            body.set_member_name("label");
            body.add_string_value(label.strip());
        }
        body.end_object();

        var root = yield request_json(
            "POST",
            "/cards/%s/links".printf(Uri.escape_string(from_card_id)),
            json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for card link create response");
        }
        return ApiParsersCards.parse_card_link(root.get_object_member("data"));
    }

    public async void delete_card_link(string from_card_id,
                                       string to_card_id,
                                       string kind,
                                       string to_type = "card") throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("to_card_id");
        body.add_string_value(to_card_id);
        if (to_type != null && to_type.length > 0) {
            body.set_member_name("to_type");
            body.add_string_value(to_type);
        }
        if (kind != null && kind.strip().length > 0) {
            body.set_member_name("kind");
            body.add_string_value(kind.strip());
        }
        body.end_object();

        yield request_json(
            "DELETE",
            "/cards/%s/links".printf(Uri.escape_string(from_card_id)),
            json_string_from_builder(body),
            null
        );
    }

    public async Gee.ArrayList<SearchCardResult> search_cards(string project_id,
                                                              string query_text,
                                                              int limit = 30) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        query.insert("q", query_text);
        query.insert("limit", limit.to_string());
        var root = yield request_json("GET", "/search/cards", null, query);
        return ApiParsersSearch.parse_search_cards(root);
    }

    public async AiCapabilitiesInfo get_ai_capabilities(string? project_id = null) throws Error {
        HashTable<string, string>? query = null;
        if (project_id != null && project_id.length > 0) {
            query = new HashTable<string, string>(str_hash, str_equal);
            query.insert("project_id", project_id);
        }
        var root = yield request_json("GET", "/ai/capabilities", null, query);
        return ApiParsersAi.parse_ai_capabilities(root);
    }

    public async AiStatusInfo get_ai_status() throws Error {
        var root = yield request_json("GET", "/ai/status", null, null);
        return ApiParsersAi.parse_ai_status(root);
    }

    public async string start_ai_runner_pull(string model_tag) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("model");
        body.add_string_value(model_tag);
        body.end_object();

        var root = yield request_json("POST", "/ai/runner/pull", json_string_from_builder(body), null);
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for runner pull response");
        }
        var data = root.get_object_member("data");
        return data.has_member("job_id") ? data.get_string_member("job_id") : "";
    }

    public async Gee.ArrayList<AiThreadSummary> list_ai_threads(string project_id) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        var root = yield request_json("GET", "/ai/threads", null, query);
        return ApiParsersAi.parse_ai_threads(root);
    }

    public async string create_ai_thread(string project_id, string title) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("project_id");
        body.add_string_value(project_id);
        body.set_member_name("title");
        body.add_string_value(title);
        body.end_object();
        var root = yield request_json("POST", "/ai/threads", json_string_from_builder(body), null);
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai thread create response");
        }
        var data = root.get_object_member("data");
        return ApiParsersCommon.string_member_or_empty(data, "thread_id");
    }

    public async Gee.ArrayList<AiCatalogProvider> list_ai_provider_catalog() throws Error {
        var root = yield request_json_unwrapped("GET", "/ai_catalog.json", null, null);
        return ApiParsersAi.parse_ai_provider_catalog(root);
    }

    public async Gee.ArrayList<GitProviderCatalogEntry> list_git_provider_catalog() throws Error {
        var root = yield request_json_unwrapped("GET", "/git_providers.json", null, null);
        return ApiParsersGit.parse_git_provider_catalog(root);
    }

    public async void set_project_git_remote(string project_id,
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

        yield request_json(
            "PATCH",
            "/projects/%s".printf(Uri.escape_string(project_id)),
            json_string_from_builder(body),
            null
        );
    }

    public async GitTestRemoteResult test_project_git_remote(string project_id,
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

        var root = yield request_json(
            "POST",
            "/projects/%s/git/test-remote".printf(Uri.escape_string(project_id)),
            json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for git test-remote response");
        }
        return ApiParsersGit.parse_git_test_remote_result(root.get_object_member("data"));
    }

    public async GitPushResult push_project_git(string project_id,
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

        var root = yield request_json(
            "POST",
            "/projects/%s/git/push".printf(Uri.escape_string(project_id)),
            json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for git push response");
        }
        return ApiParsersGit.parse_git_push_result(root.get_object_member("data"));
    }

    public async void run_ai_stream(string prompt,
                                    string? project_id,
                                    string? thread_id,
                                    string? context_card_id,
                                    string? context_card_title,
                                    string? context_card_body,
                                    AiRunEventHandler on_event) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("prompt");
        body.add_string_value(prompt);
        if (project_id != null && project_id.length > 0) {
            body.set_member_name("project_id");
            body.add_string_value(project_id);
        }
        if (thread_id != null && thread_id.length > 0) {
            body.set_member_name("thread_id");
            body.add_string_value(thread_id);
        }
        if (context_card_id != null || context_card_title != null || context_card_body != null) {
            body.set_member_name("context");
            body.begin_object();
            if (context_card_id != null && context_card_id.length > 0) {
                body.set_member_name("card_id");
                body.add_string_value(context_card_id);
            }
            if (context_card_title != null && context_card_title.length > 0) {
                body.set_member_name("card_title");
                body.add_string_value(context_card_title);
            }
            if (context_card_body != null && context_card_body.length > 0) {
                body.set_member_name("card_body");
                body.add_string_value(context_card_body);
            }
            body.end_object();
        }
        body.end_object();

        var message = new Soup.Message("POST", base_url + "/ai/runs");
        message.request_headers.append("Authorization", "Bearer %s".printf(auth_token));
        message.request_headers.append("Accept", "text/event-stream");
        var body_text = json_string_from_builder(body);
        message.set_request_body_from_bytes("application/json", new Bytes((uint8[]) body_text.data));

        ApiHttpStreamResponse response;
        try {
            response = yield transport.send(message);
        } catch (Error e) {
            throw new ApiError.TRANSPORT("Transport error for POST /ai/runs: %s".printf(e.message));
        }

        var status = response.status;
        if (status < 200 || status >= 300) {
            throw new ApiError.HTTP("HTTP %u for POST /ai/runs".printf((uint) status));
        }

        var stream = response.stream;
        var data_stream = new DataInputStream(stream);
        data_stream.set_newline_type(DataStreamNewlineType.LF);

        string current_event = "message";
        var data_builder = new StringBuilder();
        while (true) {
            size_t line_len = 0;
            string? line;
            try {
                line = yield data_stream.read_line_async(Priority.DEFAULT, null, out line_len);
            } catch (Error e) {
                throw new ApiError.TRANSPORT("SSE read error: %s".printf(e.message));
            }

            if (line == null) {
                if (data_builder.len > 0) {
                    on_event(current_event, json_object_from_text_or_raw(data_builder.str));
                }
                break;
            }

            if (line.length == 0) {
                if (data_builder.len > 0) {
                    on_event(current_event, json_object_from_text_or_raw(data_builder.str));
                }
                current_event = "message";
                data_builder = new StringBuilder();
                continue;
            }

            if (line.has_prefix("event:")) {
                current_event = line.substring("event:".length).strip();
                continue;
            }
            if (line.has_prefix("data:")) {
                if (data_builder.len > 0) {
                    data_builder.append("\n");
                }
                data_builder.append(line.substring("data:".length).strip());
            }
        }
    }

    public async string create_card(string project_id,
                                    string title,
                                    string content,
                                    string? parent_card_id = null) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("project_id");
        body.add_string_value(project_id);
        body.set_member_name("title");
        body.add_string_value(title);
        body.set_member_name("content");
        body.add_string_value(content);
        if (parent_card_id != null && parent_card_id.strip().length > 0) {
            body.set_member_name("parent_card_id");
            body.add_string_value(parent_card_id);
        }
        body.end_object();

        var root = yield request_json("POST", "/cards", json_string_from_builder(body), null);
        var data = root.get_object_member("data");
        return data.get_string_member("card_id");
    }

    public async void update_card(string card_id,
                                  string title,
                                  string content,
                                  int64 updated_at) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("title");
        body.add_string_value(title);
        body.set_member_name("content");
        body.add_string_value(content);
        body.set_member_name("updated_at");
        body.add_int_value(updated_at);
        body.end_object();

        yield request_json(
            "PATCH",
            "/cards/%s".printf(Uri.escape_string(card_id)),
            json_string_from_builder(body),
            null
        );
    }

    public async void update_card_position(string card_id,
                                           string? parent_card_id,
                                           double sort_key,
                                           int64 updated_at) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("parent_card_id");
        if (parent_card_id == null || parent_card_id.length == 0) {
            body.add_null_value();
        } else {
            body.add_string_value(parent_card_id);
        }
        body.set_member_name("sort_key");
        body.add_double_value(sort_key);
        body.set_member_name("updated_at");
        body.add_int_value(updated_at);
        body.end_object();

        yield request_json(
            "PATCH",
            "/cards/%s".printf(Uri.escape_string(card_id)),
            json_string_from_builder(body),
            null
        );
    }

    public async CardMoveResult move_card(string card_id,
                                          string project_id,
                                          string intent,
                                          string? target_card_id = null,
                                          string? parent_card_id = null) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("project_id");
        body.add_string_value(project_id);
        body.set_member_name("intent");
        body.add_string_value(intent);
        if (target_card_id != null && target_card_id.strip().length > 0) {
            body.set_member_name("target_card_id");
            body.add_string_value(target_card_id);
        }
        if (intent == "to_start" || intent == "to_end") {
            body.set_member_name("parent_card_id");
            if (parent_card_id == null || parent_card_id.strip().length == 0) {
                body.add_null_value();
            } else {
                body.add_string_value(parent_card_id);
            }
        }
        body.end_object();

        var root = yield request_json(
            "POST",
            "/cards/%s/move".printf(Uri.escape_string(card_id)),
            json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for move response");
        }
        return ApiParsersCards.parse_card_move_result(root.get_object_member("data"));
    }

    private async Json.Object request_json(string method,
                                           string path,
                                           string? request_body,
                                           HashTable<string, string>? query) throws Error {
        var url = build_url(path, query);
        var message = new Soup.Message(method, url);

        message.request_headers.append("Authorization", "Bearer %s".printf(auth_token));
        message.request_headers.append("Accept", "application/json");

        if (request_body != null) {
            var bytes = new Bytes((uint8[]) request_body.data);
            message.set_request_body_from_bytes("application/json", bytes);
        }

        ApiHttpBytesResponse response;
        try {
            response = yield transport.send_and_read(message);
        } catch (Error e) {
            throw new ApiError.TRANSPORT("Transport error for %s %s: %s".printf(method, path, e.message));
        }

        var status = response.status;
        var response_text = (string) response.body.get_data();

        Json.Object root;
        try {
            root = ApiParsersCommon.parse_response_object(response_text);
        } catch (Error e) {
            if (status >= 200 && status < 300) {
                throw e;
            }
            throw new ApiError.HTTP(
                "HTTP %u for %s %s".printf((uint) status, method, path)
            );
        }

        if (status < 200 || status >= 300) {
            if (root.has_member("error")) {
                var err_obj = root.get_object_member("error");
                var code = err_obj.has_member("code") ? err_obj.get_string_member("code") : "http_error";
                var message_text = err_obj.has_member("message") ? err_obj.get_string_member("message") : "Request failed";
                throw new ApiError.HTTP("HTTP %u %s: %s".printf((uint) status, code, message_text));
            }
            throw new ApiError.HTTP("HTTP %u for %s %s".printf((uint) status, method, path));
        }

        if (!root.has_member("ok") || !root.get_boolean_member("ok")) {
            throw new ApiError.PROTOCOL("Response missing ok=true for %s %s".printf(method, path));
        }

        return root;
    }

    private async Json.Object request_json_unwrapped(string method,
                                                     string path,
                                                     string? request_body,
                                                     HashTable<string, string>? query) throws Error {
        var url = build_url(path, query);
        var message = new Soup.Message(method, url);

        message.request_headers.append("Authorization", "Bearer %s".printf(auth_token));
        message.request_headers.append("Accept", "application/json");

        if (request_body != null) {
            var bytes = new Bytes((uint8[]) request_body.data);
            message.set_request_body_from_bytes("application/json", bytes);
        }

        ApiHttpBytesResponse response;
        try {
            response = yield transport.send_and_read(message);
        } catch (Error e) {
            throw new ApiError.TRANSPORT("Transport error for %s %s: %s".printf(method, path, e.message));
        }

        var status = response.status;
        var response_text = (string) response.body.get_data();

        Json.Object root;
        try {
            root = ApiParsersCommon.parse_response_object(response_text);
        } catch (Error e) {
            if (status >= 200 && status < 300) {
                throw e;
            }
            throw new ApiError.HTTP(
                "HTTP %u for %s %s".printf((uint) status, method, path)
            );
        }

        if (status < 200 || status >= 300) {
            throw new ApiError.HTTP("HTTP %u for %s %s".printf((uint) status, method, path));
        }

        return root;
    }

    public async Json.Object request_json_unwrapped_for_tests(string method,
                                                              string path,
                                                              string? request_body,
                                                              HashTable<string, string>? query = null) throws Error {
        return yield request_json_unwrapped(method, path, request_body, query);
    }

    private string build_url(string path, HashTable<string, string>? query) {
        var sb = new StringBuilder();
        sb.append(base_url);
        sb.append(path);
        if (query != null && query.size() > 0) {
            sb.append("?");
            bool first = true;
            var iter = HashTableIter<string, string>(query);
            string key;
            string value;
            while (iter.next(out key, out value)) {
                if (!first) {
                    sb.append("&");
                }
                first = false;
                sb.append(Uri.escape_string(key));
                sb.append("=");
                sb.append(Uri.escape_string(value));
            }
        }
        return sb.str;
    }

    private string json_string_from_builder(Json.Builder builder) {
        var generator = new Json.Generator();
        generator.set_root(builder.get_root());
        return generator.to_data(null);
    }

    private Json.Object json_object_from_text_or_raw(string text) {
        var parser = new Json.Parser();
        try {
            parser.load_from_data(text, -1);
            var root = parser.get_root();
            if (root != null && root.get_node_type() == Json.NodeType.OBJECT) {
                return root.get_object();
            }
        } catch (Error e) {
        }

        var out = new Json.Object();
        out.set_string_member("raw", text);
        return out;
    }
}

public class DefaultApiFactory : Object, IApiFactory {
    public IHolderApi create(string base_url, string auth_token) {
        return new ApiClient(base_url, auth_token);
    }
}

}
