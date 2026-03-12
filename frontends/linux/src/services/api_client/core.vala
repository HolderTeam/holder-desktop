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
        yield ApiClientHealthEndpoints.health_check(this);
    }

    public async HealthInfo get_health_info() throws Error {
        return yield ApiClientHealthEndpoints.get_health_info(this);
    }

    public async Gee.ArrayList<Project> list_projects() throws Error {
        return yield ApiClientProjectsEndpoints.list_projects(this);
    }

    public async string create_project(string name,
                                       string privacy_mode = "encrypted_git") throws Error {
        return yield ApiClientProjectsEndpoints.create_project(this, name, privacy_mode);
    }

    public async ProjectRecoveryTokenExport export_project_recovery_token(
        string project_id,
        string pin
    ) throws Error {
        return yield ApiClientProjectsEndpoints.export_project_recovery_token(this, project_id, pin);
    }

    public async void import_project_recovery_token(
        string project_id,
        string pin,
        string recovery_token
    ) throws Error {
        yield ApiClientProjectsEndpoints.import_project_recovery_token(this, project_id, pin, recovery_token);
    }

    public async RecoveryTokenImportResult import_recovery_token(
        string pin,
        string recovery_token
    ) throws Error {
        return yield ApiClientProjectsEndpoints.import_recovery_token(this, pin, recovery_token);
    }

    public async Gee.ArrayList<CardSummary> list_cards(string project_id,
                                                       string view = "tree",
                                                       string? parent_card_id = null,
                                                       int limit = 0) throws Error {
        return yield ApiClientCardsEndpoints.list_cards(this, project_id, view, parent_card_id, limit);
    }

    public async CardContextData get_card_context(string project_id,
                                                  string? parent_card_id = null) throws Error {
        return yield ApiClientCardsEndpoints.get_card_context(this, project_id, parent_card_id);
    }

    public async CardDetail get_card(string card_id) throws Error {
        return yield ApiClientCardsEndpoints.get_card(this, card_id);
    }

    public async Gee.ArrayList<CardLink> list_card_links(string card_id) throws Error {
        return yield ApiClientCardsEndpoints.list_card_links(this, card_id);
    }

    public async Gee.ArrayList<CardLink> list_card_backlinks(string card_id) throws Error {
        return yield ApiClientCardsEndpoints.list_card_backlinks(this, card_id);
    }

    public async Gee.ArrayList<ProjectResource> list_resources(string project_id) throws Error {
        return yield ApiClientResourcesEndpoints.list_resources(this, project_id);
    }

    public async Gee.ArrayList<TrashItem> list_trash_items(string project_id,
                                                            string type = "all") throws Error {
        return yield ApiClientTrashEndpoints.list_trash_items(this, project_id, type);
    }

    public async void empty_trash(string project_id, string type = "all") throws Error {
        yield ApiClientTrashEndpoints.empty_trash(this, project_id, type);
    }

    public async void restore_trash_item(string item_type, string item_id) throws Error {
        yield ApiClientTrashEndpoints.restore_trash_item(this, item_type, item_id);
    }

    public async void hard_delete_trash_item(string item_type, string item_id) throws Error {
        yield ApiClientTrashEndpoints.hard_delete_trash_item(this, item_type, item_id);
    }

    public async string create_resource(string project_id,
                                        string kind,
                                        string uri,
                                        string label,
                                        string? desc = null) throws Error {
        return yield ApiClientResourcesEndpoints.create_resource(this, project_id, kind, uri, label, desc);
    }

    public async void update_resource(string resource_id,
                                      string? kind,
                                      string? uri,
                                      string? label,
                                      string? desc,
                                      int64 updated_at) throws Error {
        yield ApiClientResourcesEndpoints.update_resource(
            this, resource_id, kind, uri, label, desc, updated_at
        );
    }

    public async void delete_resource(string resource_id) throws Error {
        yield ApiClientResourcesEndpoints.delete_resource(this, resource_id);
    }

    public async CardLink create_card_link(string from_card_id,
                                           string to_card_id,
                                           string kind = "ref",
                                           string? label = null,
                                           string to_type = "card") throws Error {
        return yield ApiClientCardsEndpoints.create_card_link(
            this, from_card_id, to_card_id, kind, label, to_type
        );
    }

    public async void delete_card_link(string from_card_id,
                                       string to_card_id,
                                       string kind,
                                       string to_type = "card") throws Error {
        yield ApiClientCardsEndpoints.delete_card_link(this, from_card_id, to_card_id, kind, to_type);
    }

    public async Gee.ArrayList<SearchCardResult> search_cards(string project_id,
                                                              string query_text,
                                                              int limit = 30) throws Error {
        return yield ApiClientSearchEndpoints.search_cards(this, project_id, query_text, limit);
    }

    public async AiCapabilitiesInfo get_ai_capabilities(string? project_id = null) throws Error {
        return yield ApiClientAiEndpoints.get_ai_capabilities(this, project_id);
    }

    public async AiStatusInfo get_ai_status() throws Error {
        return yield ApiClientAiEndpoints.get_ai_status(this);
    }

    public async string start_ai_runner_pull(string model_tag) throws Error {
        return yield ApiClientAiEndpoints.start_ai_runner_pull(this, model_tag);
    }

    public async Gee.ArrayList<AiThreadSummary> list_ai_threads(string project_id) throws Error {
        return yield ApiClientAiEndpoints.list_ai_threads(this, project_id);
    }

    public async string create_ai_thread(string project_id, string title) throws Error {
        return yield ApiClientAiEndpoints.create_ai_thread(this, project_id, title);
    }

    public async Gee.ArrayList<AiCatalogProvider> list_ai_provider_catalog() throws Error {
        return yield ApiClientAiEndpoints.list_ai_provider_catalog(this);
    }

    public async Gee.ArrayList<GitProviderCatalogEntry> list_git_provider_catalog() throws Error {
        return yield ApiClientGitEndpoints.list_git_provider_catalog(this);
    }

    public async void set_project_git_remote(string project_id,
                                             string? git_remote_url,
                                             int64 updated_at) throws Error {
        yield ApiClientGitEndpoints.set_project_git_remote(this, project_id, git_remote_url, updated_at);
    }

    public async GitTestRemoteResult test_project_git_remote(string project_id,
                                                             string? remote_url = null,
                                                             string branch = "") throws Error {
        return yield ApiClientGitEndpoints.test_project_git_remote(this, project_id, remote_url, branch);
    }

    public async GitPushResult push_project_git(string project_id,
                                                string branch = "",
                                                bool set_upstream = true) throws Error {
        return yield ApiClientGitEndpoints.push_project_git(this, project_id, branch, set_upstream);
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
        return yield ApiClientCardsEndpoints.create_card(this, project_id, title, content, parent_card_id);
    }

    public async void update_card(string card_id,
                                  string title,
                                  string content,
                                  int64 updated_at) throws Error {
        yield ApiClientCardsEndpoints.update_card(this, card_id, title, content, updated_at);
    }

    public async void update_card_position(string card_id,
                                           string? parent_card_id,
                                           double sort_key,
                                           int64 updated_at) throws Error {
        yield ApiClientCardsEndpoints.update_card_position(
            this, card_id, parent_card_id, sort_key, updated_at
        );
    }

    public async CardMoveResult move_card(string card_id,
                                          string project_id,
                                          string intent,
                                          string? target_card_id = null,
                                          string? parent_card_id = null) throws Error {
        return yield ApiClientCardsEndpoints.move_card(
            this, card_id, project_id, intent, target_card_id, parent_card_id
        );
    }

    internal async Json.Object request_json(string method,
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
            throw new ApiError.HTTP("HTTP %u for %s %s".printf((uint) status, method, path));
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

    internal async Json.Object request_json_unwrapped(string method,
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
            throw new ApiError.HTTP("HTTP %u for %s %s".printf((uint) status, method, path));
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

    internal string json_string_from_builder(Json.Builder builder) {
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
