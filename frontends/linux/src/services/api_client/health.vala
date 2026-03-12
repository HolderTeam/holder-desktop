namespace HolderLinux {

public class ApiClientHealthEndpoints : Object { // LCOV_EXCL_BR_LINE: declaration branch artifact
    public static async void health_check(ApiClient client) throws Error { // LCOV_EXCL_BR_LINE: async declaration branch artifact
        var root = yield client.request_json("GET", "/health", null, null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data in /health response"); // LCOV_EXCL_BR_LINE: throw edge artifact
        }
    }

    public static async HealthInfo get_health_info(ApiClient client) throws Error { // LCOV_EXCL_BR_LINE: async declaration branch artifact
        var root = yield client.request_json("GET", "/health", null, null); // LCOV_EXCL_BR_LINE: yield resume edge artifact
        return ApiParsersHealth.parse_health_info(root); // LCOV_EXCL_BR_LINE: return edge artifact
    }
}

}
