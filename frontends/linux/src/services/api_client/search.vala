namespace HolderLinux {

public class ApiClientSearchEndpoints : Object {
    public static async Gee.ArrayList<SearchCardResult> search_cards(ApiClient client,
                                                                      string project_id,
                                                                      string query_text,
                                                                      int limit = 30) throws Error {
        var query = new HashTable<string, string>(str_hash, str_equal);
        query.insert("project_id", project_id);
        query.insert("q", query_text);
        query.insert("limit", limit.to_string());
        var root = yield client.request_json("GET", "/search/cards", null, query);
        return ApiParsersSearch.parse_search_cards(root);
    }
}

}
