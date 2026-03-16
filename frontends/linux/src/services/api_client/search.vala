namespace HolderLinux {

public class ApiClientSearchEndpoints : Object { // LCOV_EXCL_BR_LINE: declaration branch artifact
    public static async Gee.ArrayList<SearchCardResult> search_cards(ApiClient client, // LCOV_EXCL_BR_LINE: async declaration branch artifact
                                                                      string project_id,
                                                                      string query_text,
                                                                      int limit = 30) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        query.insert("q", query_text);
        query.insert("limit", limit.to_string());
        var root = yield client.request_json("GET", "/search/cards", null, query); // LCOV_EXCL_BR_LINE: yield/invoke branch artifact
        return ApiParsersSearch.parse_search_cards(root); // LCOV_EXCL_BR_LINE: call/return branch artifact
    }
}

}
