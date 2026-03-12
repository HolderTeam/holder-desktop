namespace HolderLinux {

public class ApiParsersCommon {
    public static string string_member_or_empty(Json.Object obj, string key) {
        if (!obj.has_member(key)) {
            return "";
        }
        var node = obj.get_member(key);
        if (node == null || node.get_node_type() == Json.NodeType.NULL) {
            return "";
        }
        return obj.get_string_member(key);
    }

    public static string? nullable_string_member_or_null(Json.Object obj, string key) {
        if (!obj.has_member(key)) {
            return null;
        }
        var node = obj.get_member(key);
        if (node == null || node.get_node_type() == Json.NodeType.NULL) {
            return null;
        }
        return obj.get_string_member(key);
    }

    public static int64? nullable_int_member_or_null(Json.Object obj, string key) {
        if (!obj.has_member(key)) {
            return null;
        }
        var node = obj.get_member(key);
        if (node == null || node.get_node_type() == Json.NodeType.NULL) {
            return null;
        }
        return obj.get_int_member(key);
    }

    public static Json.Object? object_member_or_null(Json.Object obj, string key) {
        if (!obj.has_member(key)) {
            return null;
        }
        var node = obj.get_member(key);
        if (node == null || node.get_node_type() == Json.NodeType.NULL) {
            return null;
        }
        return obj.get_object_member(key);
    }

    public static Json.Object parse_response_object(string payload) throws Error {
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
}

}
