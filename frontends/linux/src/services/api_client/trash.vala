namespace HolderLinux {

public class ApiClientTrashEndpoints : Object { // LCOV_EXCL_BR_LINE: declaration branch artifact
    public static async Gee.ArrayList<TrashItem> list_trash_items(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                                   string project_id,
                                                                   string type = "all") throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        if (type != null && type.strip().length > 0) { // LCOV_EXCL_BR_LINE: short-circuit artifact branches
            query.insert("type", type.strip());
        }
        var root = yield client.request_json("GET", "/trash", null, query); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersTrash.parse_trash_items(root); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }

    public static async void empty_trash(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                         string project_id,
                                         string type = "all") throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        if (type != null && type.strip().length > 0) { // LCOV_EXCL_BR_LINE: short-circuit artifact branches
            query.insert("type", type.strip());
        }
        yield client.request_json("DELETE", "/trash", null, query); // LCOV_EXCL_BR_LINE: yield resume edge artifact
    }

    public static async void restore_trash_item(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                string item_type,
                                                string item_id) throws Error {
        if (item_type == "card") {
            yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
                "POST",
                "/cards/%s/restore".printf(Uri.escape_string(item_id)),
                null,
                null
            );
            return; // LCOV_EXCL_BR_LINE: return edge artifact
        }

        if (item_type == "ai_message") {
            yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
                "POST",
                "/ai/messages/%s/restore".printf(Uri.escape_string(item_id)),
                null,
                null
            );
            return; // LCOV_EXCL_BR_LINE: return edge artifact
        }

        throw new ApiError.PROTOCOL("Unsupported trash item type: %s".printf(item_type));
    }

    public static async void hard_delete_trash_item(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                    string item_type,
                                                    string item_id) throws Error {
        yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
            "DELETE",
            "/trash/%s/%s".printf(Uri.escape_string(item_type), Uri.escape_string(item_id)),
            null,
            null
        );
    }
}

}
