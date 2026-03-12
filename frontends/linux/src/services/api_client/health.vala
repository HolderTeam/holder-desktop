namespace HolderLinux {

public class ApiClientHealthEndpoints : Object {
    public static async void health_check(ApiClient client) throws Error {
        var root = yield client.request_json("GET", "/health", null, null);
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data in /health response");
        }
    }

    public static async HealthInfo get_health_info(ApiClient client) throws Error {
        var root = yield client.request_json("GET", "/health", null, null);
        return ApiParsersHealth.parse_health_info(root);
    }
}

}
