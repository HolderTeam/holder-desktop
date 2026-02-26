namespace HolderLinux {

public errordomain ApiError {
    TRANSPORT,
    HTTP,
    PROTOCOL,
    PARSE
}

public interface IApiHttpTransport : Object {
    public abstract async ApiHttpBytesResponse send_and_read(Soup.Message message) throws Error;
    public abstract async ApiHttpStreamResponse send(Soup.Message message) throws Error;
}

public class ApiHttpBytesResponse : Object {
    public uint status { get; construct; }
    public Bytes body { get; construct; }

    public ApiHttpBytesResponse(uint status, Bytes body) {
        Object(status: status, body: body);
    }
}

public class ApiHttpStreamResponse : Object {
    public uint status { get; construct; }
    public InputStream stream { get; construct; }

    public ApiHttpStreamResponse(uint status, InputStream stream) {
        Object(status: status, stream: stream);
    }
}

public class SoupApiHttpTransport : Object, IApiHttpTransport {
    private Soup.Session session;

    public SoupApiHttpTransport(Soup.Session? session = null) {
        this.session = session ?? new Soup.Session();
    }

    public async ApiHttpBytesResponse send_and_read(Soup.Message message) throws Error {
        var body = yield session.send_and_read_async(message, Priority.DEFAULT, null);
        return new ApiHttpBytesResponse(message.get_status(), body);
    }

    public async ApiHttpStreamResponse send(Soup.Message message) throws Error {
        var stream = yield session.send_async(message, Priority.DEFAULT, null);
        return new ApiHttpStreamResponse(message.get_status(), stream);
    }
}

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
        return parse_health_info(root);
    }

    public async Gee.ArrayList<Project> list_projects() throws Error {
        var root = yield request_json("GET", "/projects", null, null);
        return parse_projects(root);
    }

    public async string create_project(string name) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("name");
        body.add_string_value(name);
        body.end_object();

        var root = yield request_json("POST", "/projects", json_string_from_builder(body), null);
        var data = root.get_object_member("data");
        return data.get_string_member("project_id");
    }

    public async Gee.ArrayList<CardSummary> list_cards(string project_id,
                                                       string scope = "root",
                                                       string? parent_card_id = null) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        query.insert("scope", scope);
        if (parent_card_id != null && parent_card_id.strip().length > 0) {
            query.insert("parent_card_id", parent_card_id);
        }
        var root = yield request_json("GET", "/cards", null, query);
        return parse_cards(root);
    }

    public async CardDetail get_card(string card_id) throws Error {
        var root = yield request_json("GET", "/cards/%s".printf(Uri.escape_string(card_id)), null, null);
        return parse_card_detail(root);
    }

    public async Gee.ArrayList<CardLink> list_card_links(string card_id) throws Error {
        var root = yield request_json(
            "GET",
            "/cards/%s/links".printf(Uri.escape_string(card_id)),
            null,
            null
        );
        return parse_card_links(root);
    }

    public async Gee.ArrayList<CardLink> list_card_backlinks(string card_id) throws Error {
        var root = yield request_json(
            "GET",
            "/cards/%s/backlinks".printf(Uri.escape_string(card_id)),
            null,
            null
        );
        return parse_card_links(root);
    }

    public async Gee.ArrayList<ProjectResource> list_resources(string project_id) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        var root = yield request_json("GET", "/resources", null, query);
        return parse_resources(root);
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
        return string_member_or_empty(data, "resource_id");
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
        return parse_card_link(root.get_object_member("data"));
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
        return parse_search_cards(root);
    }

    public async AiCapabilitiesInfo get_ai_capabilities(string? project_id = null) throws Error {
        HashTable<string, string>? query = null;
        if (project_id != null && project_id.length > 0) {
            query = new HashTable<string, string>(str_hash, str_equal);
            query.insert("project_id", project_id);
        }
        var root = yield request_json("GET", "/ai/capabilities", null, query);
        return parse_ai_capabilities(root);
    }

    public async AiStatusInfo get_ai_status() throws Error {
        var root = yield request_json("GET", "/ai/status", null, null);
        return parse_ai_status(root);
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
        return parse_ai_threads(root);
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
        return string_member_or_empty(data, "thread_id");
    }

    public async Gee.ArrayList<AiCatalogProvider> list_ai_provider_catalog() throws Error {
        var root = yield request_json_unwrapped("GET", "/ai_catalog.json", null, null);
        return parse_ai_provider_catalog(root);
    }

    public async Gee.ArrayList<GitProviderCatalogEntry> list_git_provider_catalog() throws Error {
        var root = yield request_json_unwrapped("GET", "/git_providers.json", null, null);
        return parse_git_provider_catalog(root);
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
            root = parse_response_object(response_text);
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
            root = parse_response_object(response_text);
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

    private Json.Object parse_response_object(string payload) throws Error {
        var parser = new Json.Parser();
        try {
            parser.load_from_data(payload, -1);
        } catch (Error e) {
            throw new ApiError.PARSE("Invalid JSON response: %s".printf(e.message));
        }

        var root = parser.get_root();
        if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
            throw new ApiError.PARSE("Response JSON root is not an object");
        }

        return root.get_object();
    }

    private string json_string_from_builder(Json.Builder builder) {
        var generator = new Json.Generator();
        generator.set_root(builder.get_root());
        return generator.to_data(null);
    }

    private Gee.ArrayList<Project> parse_projects(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for projects response");
        }

        var out_list = new Gee.ArrayList<Project>();
        var data = root.get_array_member("data");
        for (uint i = 0; i < data.get_length(); i++) {
            var item = data.get_object_element(i);
            out_list.add(new Project(
                item.get_string_member("project_id"),
                item.get_string_member("name"),
                item.has_member("root_path") ? item.get_string_member("root_path") : "",
                item.has_member("created_at") ? item.get_int_member("created_at") : 0,
                item.has_member("updated_at") ? item.get_int_member("updated_at") : 0
            ));
        }
        return out_list;
    }

    private HealthInfo parse_health_info(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for health response");
        }
        var data = root.get_object_member("data");
        return new HealthInfo(
            data.has_member("db_ok") ? data.get_boolean_member("db_ok") : false,
            data.has_member("uptime_ms") ? data.get_int_member("uptime_ms") : 0,
            string_member_or_empty(data, "api_version"),
            string_member_or_empty(data, "server_version"),
            data.has_member("pid") ? (int) data.get_int_member("pid") : 0
        );
    }

    private Gee.ArrayList<CardSummary> parse_cards(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for cards response");
        }

        var out_list = new Gee.ArrayList<CardSummary>();
        var data = root.get_array_member("data");
        for (uint i = 0; i < data.get_length(); i++) {
            var item = data.get_object_element(i);
            out_list.add(new CardSummary(
                item.get_string_member("card_id"),
                item.get_string_member("project_id"),
                item.get_string_member("title"),
                item.has_member("rel_path") ? item.get_string_member("rel_path") : "",
                item.has_member("sort_key") ? item.get_double_member("sort_key") : 0.0,
                item.has_member("parent_card_id") && item.get_member("parent_card_id").get_node_type() != Json.NodeType.NULL
                    ? item.get_string_member("parent_card_id")
                    : null,
                item.has_member("created_at") ? item.get_int_member("created_at") : 0,
                item.has_member("updated_at") ? item.get_int_member("updated_at") : 0
            ));
        }
        return out_list;
    }

    private CardDetail parse_card_detail(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for card response");
        }

        var data = root.get_object_member("data");
        return new CardDetail(
            data.get_string_member("card_id"),
            data.get_string_member("project_id"),
            data.get_string_member("title"),
            data.get_string_member("content"),
            data.has_member("updated_at") ? data.get_int_member("updated_at") : 0
        );
    }

    private Gee.ArrayList<CardLink> parse_card_links(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for card links response");
        }

        var out_list = new Gee.ArrayList<CardLink>();
        var data = root.get_array_member("data");
        for (uint i = 0; i < data.get_length(); i++) {
            out_list.add(parse_card_link(data.get_object_element(i)));
        }
        return out_list;
    }

    private Gee.ArrayList<ProjectResource> parse_resources(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for resources response");
        }

        var out_list = new Gee.ArrayList<ProjectResource>();
        var data = root.get_array_member("data");
        for (uint i = 0; i < data.get_length(); i++) {
            var item = data.get_object_element(i);
            string? desc = null;
            if (item.has_member("desc")) {
                var desc_node = item.get_member("desc");
                if (desc_node != null && desc_node.get_node_type() != Json.NodeType.NULL) {
                    desc = item.get_string_member("desc");
                }
            }
            out_list.add(new ProjectResource(
                string_member_or_empty(item, "resource_id"),
                string_member_or_empty(item, "project_id"),
                string_member_or_empty(item, "kind"),
                string_member_or_empty(item, "uri"),
                string_member_or_empty(item, "label"),
                desc,
                item.has_member("created_at") ? item.get_int_member("created_at") : 0,
                item.has_member("updated_at") ? item.get_int_member("updated_at") : 0
            ));
        }
        return out_list;
    }

    private CardLink parse_card_link(Json.Object item) {
        return new CardLink(
            item.get_string_member("from_card_id"),
            item.get_string_member("to_card_id"),
            item.has_member("to_type") ? string_member_or_empty(item, "to_type") : "card",
            item.has_member("kind") ? string_member_or_empty(item, "kind") : "ref",
            item.has_member("label") ? string_member_or_empty(item, "label") : null,
            item.has_member("created_at") ? item.get_int_member("created_at") : 0
        );
    }

    private Gee.ArrayList<SearchCardResult> parse_search_cards(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for search cards response");
        }

        var out_list = new Gee.ArrayList<SearchCardResult>();
        var data = root.get_array_member("data");
        for (uint i = 0; i < data.get_length(); i++) {
            var item = data.get_object_element(i);
            out_list.add(new SearchCardResult(
                item.get_string_member("card_id"),
                item.get_string_member("title"),
                item.has_member("updated_at") ? item.get_int_member("updated_at") : 0,
                item.has_member("created_at") ? item.get_int_member("created_at") : 0,
                item.has_member("snippet") ? item.get_string_member("snippet") : "",
                item.has_member("rank") ? item.get_double_member("rank") : 0.0
            ));
        }
        return out_list;
    }

    private AiCapabilitiesInfo parse_ai_capabilities(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai capabilities response");
        }

        var data = root.get_object_member("data");
        var models = new Gee.ArrayList<string>();
        if (data.has_member("models")) {
            var items = data.get_array_member("models");
            for (uint i = 0; i < items.get_length(); i++) {
                var model = items.get_object_element(i);
                if (model.has_member("name")) {
                    models.add(model.get_string_member("name"));
                }
            }
        }

        var recommended_install = new Gee.ArrayList<string>();
        if (data.has_member("recommended_install")) {
            var items = data.get_array_member("recommended_install");
            for (uint i = 0; i < items.get_length(); i++) {
                var rec = items.get_object_element(i);
                if (rec.has_member("tag")) {
                    recommended_install.add(rec.get_string_member("tag"));
                }
            }
        }

        string caste_name = "";
        var caste = object_member_or_null(data, "caste");
        if (caste != null) {
            caste_name = string_member_or_empty(caste, "name");
        }

        return new AiCapabilitiesInfo(
            data.has_member("runner_available") ? data.get_boolean_member("runner_available") : false,
            string_member_or_empty(data, "error"),
            data.has_member("last_checked") ? data.get_int_member("last_checked") : 0,
            string_member_or_empty(data, "version"),
            caste_name,
            models,
            recommended_install
        );
    }

    private AiStatusInfo parse_ai_status(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai status response");
        }

        var data = root.get_object_member("data");
        var pull_jobs = new Gee.ArrayList<string>();
        if (data.has_member("pulls")) {
            var pulls = data.get_array_member("pulls");
            for (uint i = 0; i < pulls.get_length(); i++) {
                var pull = pulls.get_object_element(i);
                var model = pull.has_member("model") ? pull.get_string_member("model") : "unknown";
                var status = pull.has_member("status") ? pull.get_string_member("status") : "unknown";
                double percent = 0.0;
                if (pull.has_member("progress")) {
                    var progress = pull.get_object_member("progress");
                    if (progress != null && progress.has_member("percent")) {
                        percent = progress.get_double_member("percent");
                    }
                }
                pull_jobs.add("%s (%s, %.1f%%)".printf(model, status, percent));
            }
        }

        return new AiStatusInfo(
            data.has_member("checked_at") ? data.get_int_member("checked_at") : 0,
            data.has_member("runner_available") ? data.get_boolean_member("runner_available") : false,
            string_member_or_empty(data, "runner_error"),
            data.has_member("active_runs") ? data.get_int_member("active_runs") : 0,
            data.has_member("active_pull_jobs") ? data.get_int_member("active_pull_jobs") : 0,
            data.has_member("cloud_configured_providers") ? data.get_int_member("cloud_configured_providers") : 0,
            pull_jobs
        );
    }

    private Gee.ArrayList<AiThreadSummary> parse_ai_threads(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai threads response");
        }

        var out_list = new Gee.ArrayList<AiThreadSummary>();
        var data = root.get_array_member("data");
        for (uint i = 0; i < data.get_length(); i++) {
            var item = data.get_object_element(i);
            out_list.add(new AiThreadSummary(
                string_member_or_empty(item, "thread_id"),
                string_member_or_empty(item, "project_id"),
                string_member_or_empty(item, "title"),
                item.has_member("created_at") ? item.get_int_member("created_at") : 0,
                item.has_member("updated_at") ? item.get_int_member("updated_at") : 0
            ));
        }
        return out_list;
    }

    private Gee.ArrayList<AiCatalogProvider> parse_ai_provider_catalog(Json.Object root) throws Error {
        var providers = new Gee.ArrayList<AiCatalogProvider>();
        var models_node = object_member_or_null(root, "models");
        if (models_node == null) {
            return providers;
        }
        var defaults = object_member_or_null(models_node, "provider_defaults");
        if (defaults == null) {
            return providers;
        }
        var names = defaults.get_members();
        if (names == null) {
            return providers;
        }
        for (unowned List<weak string>? cursor = names; cursor != null; cursor = cursor.next) {
            unowned string provider_id = cursor.data;
            var node = defaults.get_member(provider_id);
            if (node != null && node.get_node_type() == Json.NodeType.OBJECT) {
                var provider = defaults.get_object_member(provider_id);
                var display_name = string_member_or_empty(provider, "provider");
                if (display_name.length == 0) {
                    display_name = provider_id;
                }
                providers.add(new AiCatalogProvider(
                    provider_id,
                    display_name,
                    provider.has_member("enabled") ? provider.get_boolean_member("enabled") : false,
                    false,
                    string_member_or_empty(provider, "setup_url"),
                    string_member_or_empty(provider, "docs_url")
                ));
            }
        }
        return providers;
    }

    private Gee.ArrayList<GitProviderCatalogEntry> parse_git_provider_catalog(Json.Object root) throws Error {
        var providers = new Gee.ArrayList<GitProviderCatalogEntry>();
        if (!root.has_member("providers")) {
            return providers;
        }
        var items = root.get_array_member("providers");
        for (uint i = 0; i < items.get_length(); i++) {
            var item = items.get_object_element(i);
            var preferred_transport = "";
            var defaults = object_member_or_null(item, "defaults");
            if (defaults != null) {
                preferred_transport = string_member_or_empty(defaults, "preferred_transport");
            }

            var transports_summary = "";
            var git = object_member_or_null(item, "git");
            if (git != null && git.has_member("transports")) {
                var transports = git.get_array_member("transports");
                var sb = new StringBuilder();
                for (uint idx = 0; idx < transports.get_length(); idx++) {
                    if (idx > 0) {
                        sb.append(", ");
                    }
                    sb.append(transports.get_string_element(idx));
                }
                transports_summary = sb.str;
            }

            providers.add(new GitProviderCatalogEntry(
                string_member_or_empty(item, "id"),
                string_member_or_empty(item, "name"),
                string_member_or_empty(item, "kind"),
                preferred_transport,
                transports_summary
            ));
        }
        return providers;
    }

    private string string_member_or_empty(Json.Object obj, string key) {
        if (!obj.has_member(key)) {
            return "";
        }
        var node = obj.get_member(key);
        if (node == null || node.get_node_type() == Json.NodeType.NULL) {
            return "";
        }
        return obj.get_string_member(key);
    }

    private Json.Object? object_member_or_null(Json.Object obj, string key) {
        if (!obj.has_member(key)) {
            return null;
        }
        var node = obj.get_member(key);
        if (node == null || node.get_node_type() == Json.NodeType.NULL) {
            return null;
        }
        return obj.get_object_member(key);
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
