namespace HolderLinux {

public class ApiClientTrashEndpoints : Object {
    public static async Gee.ArrayList<TrashItem> list_trash_items(ApiClient client,
                                                                   string project_id,
                                                                   string type = "all") throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        if (type != null && type.strip().length > 0) {
            query.insert("type", type.strip());
        }
        var root = yield client.request_json("GET", "/trash", null, query);
        return ApiParsersTrash.parse_trash_items(root);
    }

    public static async void empty_trash(ApiClient client,
                                         string project_id,
                                         string type = "all") throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        if (type != null && type.strip().length > 0) {
            query.insert("type", type.strip());
        }
        yield client.request_json("DELETE", "/trash", null, query);
    }

    public static async void restore_trash_item(ApiClient client,
                                                string item_type,
                                                string item_id) throws Error {
        if (item_type == "card") {
            yield client.request_json(
                "POST",
                "/cards/%s/restore".printf(Uri.escape_string(item_id)),
                null,
                null
            );
            return;
        }

        if (item_type == "ai_message") {
            yield client.request_json(
                "POST",
                "/ai/messages/%s/restore".printf(Uri.escape_string(item_id)),
                null,
                null
            );
            return;
        }

        throw new ApiError.PROTOCOL("Unsupported trash item type: %s".printf(item_type));
    }

    public static async void hard_delete_trash_item(ApiClient client,
                                                    string item_type,
                                                    string item_id) throws Error {
        yield client.request_json(
            "DELETE",
            "/trash/%s/%s".printf(Uri.escape_string(item_type), Uri.escape_string(item_id)),
            null,
            null
        );
    }
}

}
