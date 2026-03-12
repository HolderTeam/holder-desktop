namespace HolderLinux {

public class ApiParsersHealth {
    public static HealthInfo parse_health_info(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for health response");
        }
        var data = root.get_object_member("data");
        return new HealthInfo(
            data.has_member("db_ok") ? data.get_boolean_member("db_ok") : false,
            data.has_member("uptime_ms") ? data.get_int_member("uptime_ms") : 0,
            ApiParsersCommon.string_member_or_empty(data, "api_version"),
            ApiParsersCommon.string_member_or_empty(data, "server_version"),
            data.has_member("pid") ? (int) data.get_int_member("pid") : 0
        );
    }
}

}
