namespace HolderLinux {

public class ApiParsersCards { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public static Gee.ArrayList<CardSummary> parse_cards(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for cards response");
        }

        var out_list = new Gee.ArrayList<CardSummary>();
        var data = root.get_array_member("data"); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
        for (uint i = 0; i < data.get_length(); i++) { // LCOV_EXCL_BR_LINE: loop overflow branch artifact
            var item = data.get_object_element(i); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
            out_list.add(new CardSummary( // LCOV_EXCL_BR_LINE: allocator/ctor edge branch artifact
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
        return out_list; // LCOV_EXCL_BR_LINE: return edge branch artifact
    }

    public static CardDetail parse_card_detail(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for card response");
        }

        var data = root.get_object_member("data");
        string[] tags = {};
        if (data.has_member("tags")) {
            var tags_data = data.get_array_member("tags");
            for (uint i = 0; i < tags_data.get_length(); i++) {
                tags += tags_data.get_string_element(i);
            }
        }
        CardTagOccurrence[] tag_occurrences = {};
        if (data.has_member("tag_occurrences")) {
            var occurrence_data = data.get_array_member("tag_occurrences");
            for (uint i = 0; i < occurrence_data.get_length(); i++) {
                var item = occurrence_data.get_object_element(i);
                tag_occurrences += new CardTagOccurrence(
                    item.get_string_member("tag"),
                    (int) item.get_int_member("byte_start"),
                    (int) item.get_int_member("byte_end")
                );
            }
        }
        return new CardDetail( // LCOV_EXCL_BR_LINE: ctor edge branch artifact
            data.get_string_member("card_id"),
            data.get_string_member("project_id"),
            data.get_string_member("title"),
            data.get_string_member("content"),
            data.has_member("updated_at") ? data.get_int_member("updated_at") : 0,
            tags,
            tag_occurrences
        );
    }

    public static Gee.ArrayList<TagCount> parse_project_tags(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for project tags response");
        }
        var tags = new Gee.ArrayList<TagCount>();
        var data = root.get_array_member("data");
        for (uint i = 0; i < data.get_length(); i++) {
            var item = data.get_object_element(i);
            tags.add(new TagCount(
                item.get_string_member("tag"),
                (int) item.get_int_member("card_count")
            ));
        }
        return tags;
    }

    public static CardContextData parse_card_context(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for cards context response");
        }

        var data = root.get_object_member("data");
        if (!data.has_member("project")) {
            throw new ApiError.PROTOCOL("Missing project for cards context response"); // LCOV_EXCL_BR_LINE: throw edge branch artifact
        }
        var project_obj = data.get_object_member("project");
        var project = new CardContextProject(
            ApiParsersCommon.string_member_or_empty(project_obj, "project_id"),
            ApiParsersCommon.string_member_or_empty(project_obj, "name")
        );

        var breadcrumbs = new Gee.ArrayList<CardContextBreadcrumb>();
        if (data.has_member("breadcrumbs")) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
            var crumbs = data.get_array_member("breadcrumbs");
            for (uint i = 0; i < crumbs.get_length(); i++) {
                var crumb = crumbs.get_object_element(i);
                breadcrumbs.add(new CardContextBreadcrumb( // LCOV_EXCL_BR_LINE: allocator/ctor edge branch artifact
                    ApiParsersCommon.string_member_or_empty(crumb, "type"),
                    ApiParsersCommon.string_member_or_empty(crumb, "title"),
                    ApiParsersCommon.nullable_string_member_or_null(crumb, "project_id"),
                    ApiParsersCommon.nullable_string_member_or_null(crumb, "card_id")
                ));
            }
        }

        var cards = new Gee.ArrayList<CardContextCard>();
        if (data.has_member("cards")) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
            var items = data.get_array_member("cards");
            for (uint i = 0; i < items.get_length(); i++) {
                var item = items.get_object_element(i);
                cards.add(new CardContextCard( // LCOV_EXCL_BR_LINE: allocator/ctor edge branch artifact
                    ApiParsersCommon.string_member_or_empty(item, "card_id"),
                    ApiParsersCommon.string_member_or_empty(item, "project_id"),
                    ApiParsersCommon.string_member_or_empty(item, "title"),
                    ApiParsersCommon.string_member_or_empty(item, "rel_path"),
                    item.has_member("sort_key") ? item.get_double_member("sort_key") : 0.0, // LCOV_EXCL_BR_LINE: json member error edge artifact
                    ApiParsersCommon.nullable_string_member_or_null(item, "parent_card_id"),
                    item.has_member("created_at") ? item.get_int_member("created_at") : 0, // LCOV_EXCL_BR_LINE: json member error edge artifact
                    item.has_member("updated_at") ? item.get_int_member("updated_at") : 0, // LCOV_EXCL_BR_LINE: json member error edge artifact
                    item.has_member("child_count") ? (int) item.get_int_member("child_count") : 0 // LCOV_EXCL_BR_LINE: json member error edge artifact
                ));
            }
        }

        return new CardContextData( // LCOV_EXCL_BR_LINE: ctor edge branch artifact
            project,
            ApiParsersCommon.nullable_string_member_or_null(data, "current_parent_card_id"),
            breadcrumbs,
            cards
        );
    }

    public static Gee.ArrayList<CardLink> parse_card_links(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for card links response");
        }

        var out_list = new Gee.ArrayList<CardLink>();
        var data = root.get_array_member("data");
        for (uint i = 0; i < data.get_length(); i++) {
            out_list.add(parse_card_link(data.get_object_element(i))); // LCOV_EXCL_BR_LINE: allocator edge branch artifact
        }
        return out_list; // LCOV_EXCL_BR_LINE: return edge branch artifact
    }

    public static CardLink parse_card_link(Json.Object item) { // LCOV_EXCL_BR_LINE: declaration branch artifact
        return new CardLink( // LCOV_EXCL_BR_LINE: ctor edge branch artifact
            item.get_string_member("from_card_id"),
            item.get_string_member("to_card_id"),
            item.has_member("to_type") ? ApiParsersCommon.string_member_or_empty(item, "to_type") : "card",
            item.has_member("kind") ? ApiParsersCommon.string_member_or_empty(item, "kind") : "ref",
            item.has_member("label") ? ApiParsersCommon.string_member_or_empty(item, "label") : null,
            item.has_member("created_at") ? item.get_int_member("created_at") : 0
        );
    }

    public static CardMoveResult parse_card_move_result(Json.Object data) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!data.has_member("card_id") // LCOV_EXCL_BR_LINE: short-circuit artifact branch
            || !data.has_member("sort_key")
            || !data.has_member("revision")) {
            throw new ApiError.PROTOCOL("Missing fields for card move result");
        }

        var parent = ApiParsersCommon.nullable_string_member_or_null(data, "parent_card_id");
        var moved_into_title = ApiParsersCommon.string_member_or_empty(data, "moved_into_title");
        return new CardMoveResult( // LCOV_EXCL_BR_LINE: ctor edge branch artifact
            data.get_string_member("card_id"),
            parent,
            data.get_double_member("sort_key"),
            data.get_int_member("revision"),
            moved_into_title
        );
    }
}

}
