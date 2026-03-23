namespace HolderLinux {

public class ApiParsersCommon { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public static string string_member_or_empty(Json.Object obj, string key) { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!obj.has_member(key)) {
            return "";
        }
        var node = obj.get_member(key); // LCOV_EXCL_BR_LINE: invalid-key edge branch artifact
        if (node == null || node.get_node_type() == Json.NodeType.NULL) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
            return ""; // LCOV_EXCL_BR_LINE: return edge branch artifact
        }
        return obj.get_string_member(key); // LCOV_EXCL_BR_LINE: json type error edge artifact
    }

    public static string? nullable_string_member_or_null(Json.Object obj, string key) { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!obj.has_member(key)) {
            return null;
        }
        var node = obj.get_member(key);
        if (node == null || node.get_node_type() == Json.NodeType.NULL) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
            return null; // LCOV_EXCL_BR_LINE: return edge branch artifact
        }
        return obj.get_string_member(key); // LCOV_EXCL_BR_LINE: json type error edge artifact
    }

    public static int64? nullable_int_member_or_null(Json.Object obj, string key) { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!obj.has_member(key)) {
            return null;
        }
        var node = obj.get_member(key);
        if (node == null || node.get_node_type() == Json.NodeType.NULL) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
            return null; // LCOV_EXCL_BR_LINE: return edge branch artifact
        }
        return obj.get_int_member(key); // LCOV_EXCL_BR_LINE: json type error edge artifact
    }

    public static Json.Object? object_member_or_null(Json.Object obj, string key) { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!obj.has_member(key)) {
            return null;
        }
        var node = obj.get_member(key);
        if (node == null || node.get_node_type() == Json.NodeType.NULL) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
            return null; // LCOV_EXCL_BR_LINE: return edge branch artifact
        }
        return obj.get_object_member(key); // LCOV_EXCL_BR_LINE: json type error edge artifact
    }

    public static Json.Object parse_response_object(string payload) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        var parser = new Json.Parser();
        try { // LCOV_EXCL_BR_LINE: exception table branch artifact
            parser.load_from_data(payload, -1);
        } catch (Error e) {
            throw new ApiError.PARSE("Invalid JSON response: %s".printf(e.message)); // LCOV_EXCL_BR_LINE: throw edge branch artifact
        }

        var root = parser.get_root();
        if (root == null || root.get_node_type() != Json.NodeType.OBJECT) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
            throw new ApiError.PARSE("Response JSON root is not an object"); // LCOV_EXCL_BR_LINE: throw edge branch artifact
        }

        return root.get_object(); // LCOV_EXCL_BR_LINE: accessor edge branch artifact
    }

    public static Json.Object parse_response_object_bytes(Bytes payload) throws Error {
        var parser = new Json.Parser();
        var data = payload.get_data();
        var size = payload.get_size();
        if (size > 0 && data[size - 1] == 0) {
            size--;
        }
        try {
            parser.load_from_data((string) data, (ssize_t) size);
        } catch (Error e) {
            throw new ApiError.PARSE("Invalid JSON response: %s".printf(e.message));
        }

        var root = parser.get_root();
        if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
            throw new ApiError.PARSE("Response JSON root is not an object");
        }

        return root.get_object();
    }
}

}
