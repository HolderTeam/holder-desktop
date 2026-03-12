namespace HolderLinux {

public class ApiParsersSearch {
    public static Gee.ArrayList<SearchCardResult> parse_search_cards(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for search cards response");
        }

        var out_list = new Gee.ArrayList<SearchCardResult>();
        var data = root.get_array_member("data");
        for (uint i = 0; i < data.get_length(); i++) {
            var item = data.get_object_element(i);
            out_list.add(new SearchCardResult(
                item.get_string_member("card_id"),
                item.get_string_member("title"),
                item.has_member("updated_at") ? item.get_int_member("updated_at") : 0,
                item.has_member("created_at") ? item.get_int_member("created_at") : 0,
                item.has_member("snippet") ? item.get_string_member("snippet") : "",
                item.has_member("rank") ? item.get_double_member("rank") : 0.0
            ));
        }
        return out_list;
    }
}

}
