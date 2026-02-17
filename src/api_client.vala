namespace HolderLinux {

public errordomain ApiError {
    TRANSPORT,
    HTTP,
    PROTOCOL,
    PARSE
}

public class ApiClient : Object {
    private Soup.Session session;
    private string base_url;
    private string auth_token;

    public ApiClient(string base_url, string auth_token) {
        this.base_url = base_url;
        this.auth_token = auth_token;
        this.session = new Soup.Session();
    }

    public async void health_check() throws Error {
        var root = yield request_json("GET", "/health", null, null);
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data in /health response");
        }
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

    public async Gee.ArrayList<CardSummary> list_cards(string project_id) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        var root = yield request_json("GET", "/cards", null, query);
        return parse_cards(root);
    }

    public async CardDetail get_card(string card_id) throws Error {
        var root = yield request_json("GET", "/cards/%s".printf(Uri.escape_string(card_id)), null, null);
        return parse_card_detail(root);
    }

    public async string create_card(string project_id,
                                    string title,
                                    string content) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("project_id");
        body.add_string_value(project_id);
        body.set_member_name("title");
        body.add_string_value(title);
        body.set_member_name("content");
        body.add_string_value(content);
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

        Bytes response_bytes;
        try {
            response_bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
        } catch (Error e) {
            throw new ApiError.TRANSPORT("Transport error for %s %s: %s".printf(method, path, e.message));
        }

        var status = message.get_status();
        var response_text = (string) response_bytes.get_data();

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
}

}
