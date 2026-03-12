namespace HolderLinux {

public class ApiParsersTrash { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public static Gee.ArrayList<TrashItem> parse_trash_items(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for trash response");
        }

        var out_list = new Gee.ArrayList<TrashItem>();
        var data = root.get_array_member("data"); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
        for (uint i = 0; i < data.get_length(); i++) { // LCOV_EXCL_BR_LINE: loop overflow branch artifact
            var item = data.get_object_element(i); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
            var item_type = ApiParsersCommon.string_member_or_empty(item, "type");
            var deleted_at = item.has_member("deleted_at") ? item.get_int_member("deleted_at") : 0;

            if (item_type == "card") {
                out_list.add(new TrashItem( // LCOV_EXCL_BR_LINE: allocator failure branch artifact
                    "card",
                    ApiParsersCommon.string_member_or_empty(item, "card_id"),
                    ApiParsersCommon.string_member_or_empty(item, "title"),
                    deleted_at
                ));
                continue; // LCOV_EXCL_BR_LINE: continue fallthrough branch artifact
            }

            if (item_type == "ai_message") {
                var message_id = ApiParsersCommon.string_member_or_empty(item, "message_id");
                var role = ApiParsersCommon.string_member_or_empty(item, "role");
                var title = role.length > 0
                    ? "%s %s".printf(role, short_id(message_id))
                    : "ai_message %s".printf(short_id(message_id));
                out_list.add(new TrashItem( // LCOV_EXCL_BR_LINE: allocator failure branch artifact
                    "ai_message",
                    message_id,
                    title,
                    deleted_at
                ));
                continue; // LCOV_EXCL_BR_LINE: continue fallthrough branch artifact
            }
        }
        return out_list; // LCOV_EXCL_BR_LINE: return edge branch artifact
    }

    private static string short_id(string value) { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (value.length <= 8) {
            return value;
        }
        return value.substring(0, 8);
    }
}

}
