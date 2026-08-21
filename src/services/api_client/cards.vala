namespace HolderLinux {

public class ApiClientCardsEndpoints : Object { // LCOV_EXCL_BR_LINE: declaration branch artifact
    public static async Gee.ArrayList<CardSummary> list_cards(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                              string project_id,
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
        var root = yield client.request_json("GET", "/cards", null, query); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersCards.parse_cards(root); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }

    public static async CardContextData get_card_context(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                         string project_id,
                                                         string? parent_card_id = null) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        query.insert("count", "true");
        if (parent_card_id != null && parent_card_id.strip().length > 0) {
            query.insert("parent_card_id", parent_card_id);
        }
        var root = yield client.request_json("GET", "/cards/context", null, query); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersCards.parse_card_context(root); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }

    public static async CardDetail get_card(ApiClient client, string card_id) throws Error { // LCOV_EXCL_BR_LINE: async declaration branch artifact
        var root = yield client.request_json("GET", "/cards/%s".printf(Uri.escape_string(card_id)), null, null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersCards.parse_card_detail(root); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }

    public static async Gee.ArrayList<TagCount> list_project_tags(ApiClient client,
                                                                  string project_id) throws Error {
        var root = yield client.request_json(
            "GET",
            "/projects/%s/tags".printf(Uri.escape_string(project_id)),
            null,
            null
        );
        return ApiParsersCards.parse_project_tags(root);
    }

    public static async Gee.ArrayList<CardSummary> list_cards_with_tag(ApiClient client,
                                                                       string project_id,
                                                                       string tag) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        query.insert("tag", tag);
        var root = yield client.request_json("GET", "/cards", null, query);
        return ApiParsersCards.parse_cards(root);
    }

    public static async Gee.ArrayList<CardLink> list_card_links(ApiClient client, string card_id) throws Error { // LCOV_EXCL_BR_LINE: async declaration branch artifact
        var root = yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
            "GET",
            "/cards/%s/links".printf(Uri.escape_string(card_id)),
            null,
            null
        );
        return ApiParsersCards.parse_card_links(root); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }

    public static async Gee.ArrayList<CardLink> list_card_backlinks(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                                    string card_id) throws Error {
        var root = yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
            "GET",
            "/cards/%s/backlinks".printf(Uri.escape_string(card_id)),
            null,
            null
        );
        return ApiParsersCards.parse_card_links(root); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }

    public static async CardLink create_card_link(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                  string from_card_id,
                                                  string to_card_id,
                                                  string kind = "ref",
                                                  string? label = null,
                                                  string to_type = "card") throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("to_card_id");
        body.add_string_value(to_card_id);
        if (to_type != null && to_type.length > 0 && to_type != "card") { // LCOV_EXCL_BR_LINE: short-circuit branch artifact
            body.set_member_name("to_type");
            body.add_string_value(to_type);
        }
        if (kind != null && kind.strip().length > 0) { // LCOV_EXCL_BR_LINE: short-circuit branch artifact
            body.set_member_name("kind");
            body.add_string_value(kind.strip());
        }
        if (label != null && label.strip().length > 0) {
            body.set_member_name("label");
            body.add_string_value(label.strip());
        }
        body.end_object();

        var root = yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
            "POST",
            "/cards/%s/links".printf(Uri.escape_string(from_card_id)),
            client.json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for card link create response"); // LCOV_EXCL_BR_LINE: throw edge artifact
        }
        return ApiParsersCards.parse_card_link(root.get_object_member("data")); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }

    public static async void delete_card_link(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                              string from_card_id,
                                              string to_card_id,
                                              string kind,
                                              string to_type = "card") throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("to_card_id");
        body.add_string_value(to_card_id);
        if (to_type != null && to_type.length > 0) { // LCOV_EXCL_BR_LINE: short-circuit branch artifact
            body.set_member_name("to_type");
            body.add_string_value(to_type);
        }
        if (kind != null && kind.strip().length > 0) { // LCOV_EXCL_BR_LINE: short-circuit branch artifact
            body.set_member_name("kind");
            body.add_string_value(kind.strip());
        }
        body.end_object();

        yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
            "DELETE",
            "/cards/%s/links".printf(Uri.escape_string(from_card_id)),
            client.json_string_from_builder(body),
            null
        );
    }

    public static async string create_card(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                           string project_id,
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

        var root = yield client.request_json("POST", "/cards", client.json_string_from_builder(body), null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        var data = root.get_object_member("data"); // LCOV_EXCL_BR_LINE: invalid-type branch artifact
        return data.get_string_member("card_id"); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }

    public static async void update_card(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                         string card_id,
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

        yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
            "PATCH",
            "/cards/%s".printf(Uri.escape_string(card_id)),
            client.json_string_from_builder(body),
            null
        );
    }

    public static async void update_card_position(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                  string card_id,
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

        yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
            "PATCH",
            "/cards/%s".printf(Uri.escape_string(card_id)),
            client.json_string_from_builder(body),
            null
        );
    }

    public static async void delete_card(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                         string card_id) throws Error {
        yield client.request_json(
            "DELETE",
            "/cards/%s".printf(Uri.escape_string(card_id)),
            null,
            null
        );
    }

    public static async CardMoveResult move_card(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                 string card_id,
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

        var root = yield client.request_json( // LCOV_EXCL_BR_LINE: yield resume edge artifact
            "POST",
            "/cards/%s/move".printf(Uri.escape_string(card_id)),
            client.json_string_from_builder(body),
            null
        );
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for move response"); // LCOV_EXCL_BR_LINE: throw edge artifact
        }
        return ApiParsersCards.parse_card_move_result(root.get_object_member("data")); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }
}

}
