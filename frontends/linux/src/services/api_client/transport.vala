namespace HolderLinux {

public class ApiClientTransport : Object {
    internal static async Json.Object request_json(IApiHttpTransport transport,
                                                   string base_url,
                                                   string auth_token,
                                                   string method,
                                                   string path,
                                                   string? request_body,
                                                   HashTable<string, string>? query) throws Error {
        var root = yield request_json_unwrapped(
            transport,
            base_url,
            auth_token,
            method,
            path,
            request_body,
            query
        );

        if (!root.has_member("ok") || !root.get_boolean_member("ok")) {
            throw new ApiError.PROTOCOL("Response missing ok=true for %s %s".printf(method, path));
        }

        return root;
    }

    internal static async Json.Object request_json_unwrapped(IApiHttpTransport transport,
                                                             string base_url,
                                                             string auth_token,
                                                             string method,
                                                             string path,
                                                             string? request_body,
                                                             HashTable<string, string>? query) throws Error {
        var url = build_url(base_url, path, query);
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
                var message_text = err_obj.has_member("message")
                    ? err_obj.get_string_member("message")
                    : "Request failed";
                throw new ApiError.HTTP("HTTP %u %s: %s".printf((uint) status, code, message_text));
            }
            throw new ApiError.HTTP("HTTP %u for %s %s".printf((uint) status, method, path));
        }

        return root;
    }

    internal static string build_url(string base_url,
                                     string path,
                                     HashTable<string, string>? query) {
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

    internal static string json_string_from_builder(Json.Builder builder) {
        var generator = new Json.Generator();
        generator.set_root(builder.get_root());
        return generator.to_data(null);
    }

    internal static Json.Object json_object_from_text_or_raw(string text) {
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

}
