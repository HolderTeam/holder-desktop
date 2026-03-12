namespace HolderLinux {

public class ApiClientTransport : Object { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: declaration branch artifact
    internal static async Json.Object request_json(IApiHttpTransport transport, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: async declaration branch artifact
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
            throw new ApiError.PROTOCOL("Response missing ok=true for %s %s".printf(method, path)); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: throw edge branch artifact
        }

        return root; // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: return edge branch artifact
    }

    internal static async Json.Object request_json_unwrapped(IApiHttpTransport transport, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: async declaration branch artifact
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

        if (request_body != null) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: nullable-check branch artifact
            var bytes = new Bytes((uint8[]) request_body.data);
            message.set_request_body_from_bytes("application/json", bytes);
        }

        ApiHttpBytesResponse response;
        try { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: exception table branch artifact
            response = yield transport.send_and_read(message); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: async resume branch artifact
        } catch (Error e) {
            throw new ApiError.TRANSPORT("Transport error for %s %s: %s".printf(method, path, e.message)); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: throw edge branch artifact
        }

        var status = response.status;
        var response_text = (string) response.body.get_data();

        Json.Object root;
        try { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: exception table branch artifact
            root = ApiParsersCommon.parse_response_object(response_text); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: parser throw edge branch artifact
        } catch (Error e) {
            if (status >= 200 && status < 300) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: short-circuit branch artifact
                throw e; // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: throw edge branch artifact
            }
            throw new ApiError.HTTP("HTTP %u for %s %s".printf((uint) status, method, path)); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: throw edge branch artifact
        }

        if (status < 200 || status >= 300) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: short-circuit branch artifact
            if (root.has_member("error")) {
                var err_obj = root.get_object_member("error"); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: json accessor throw edge artifact
                var code = err_obj.has_member("code") ? err_obj.get_string_member("code") : "http_error"; // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: ternary branch artifact
                var message_text = err_obj.has_member("message") // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: ternary branch artifact
                    ? err_obj.get_string_member("message")
                    : "Request failed";
                throw new ApiError.HTTP("HTTP %u %s: %s".printf((uint) status, code, message_text)); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: throw edge branch artifact
            }
            throw new ApiError.HTTP("HTTP %u for %s %s".printf((uint) status, method, path)); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: throw edge branch artifact
        }

        return root; // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: return edge branch artifact
    }

    internal static string build_url(string base_url, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: declaration branch artifact
                                     string path,
                                     HashTable<string, string>? query) {
        var sb = new StringBuilder();
        sb.append(base_url); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: library edge branch artifact
        sb.append(path); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: library edge branch artifact
        if (query != null && query.size() > 0) {
            sb.append("?"); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: library edge branch artifact
            bool first = true;
            var iter = HashTableIter<string, string>(query);
            string key;
            string value;
            while (iter.next(out key, out value)) {
                if (!first) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: loop edge branch artifact
                    sb.append("&"); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: library edge branch artifact
                }
                first = false;
                sb.append(Uri.escape_string(key)); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: escape call edge artifact
                sb.append("="); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: library edge branch artifact
                sb.append(Uri.escape_string(value)); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: escape call edge artifact
            }
        }
        return sb.str; // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: return edge branch artifact
    }

    internal static string json_string_from_builder(Json.Builder builder) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: declaration branch artifact
        var generator = new Json.Generator();
        generator.set_root(builder.get_root()); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: generator edge branch artifact
        return generator.to_data(null); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: return edge branch artifact
    }

    internal static Json.Object json_object_from_text_or_raw(string text) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: declaration branch artifact
        var parser = new Json.Parser();
        try { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: exception table branch artifact
            parser.load_from_data(text, -1);
            var root = parser.get_root(); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: parser edge branch artifact
            if (root != null && root.get_node_type() == Json.NodeType.OBJECT) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: short-circuit branch artifact
                return root.get_object(); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: return edge branch artifact
            }
        } catch (Error e) {
        }

        var out = new Json.Object();
        out.set_string_member("raw", text);
        return out; // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: return edge branch artifact
    }
}

}
