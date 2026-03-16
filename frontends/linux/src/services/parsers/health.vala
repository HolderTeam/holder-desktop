namespace HolderLinux {

public class ApiParsersHealth { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public static HealthInfo parse_health_info(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: valac/gcov branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for health response");
        }
        var data = root.get_object_member("data"); // LCOV_EXCL_BR_LINE: non-object/null path is GLib-critical (not unit-testable)
        return new HealthInfo( // LCOV_EXCL_BR_LINE: constructor exception branch artifact
            data.has_member("db_ok") ? data.get_boolean_member("db_ok") : false,
            data.has_member("uptime_ms") ? data.get_int_member("uptime_ms") : 0,
            ApiParsersCommon.string_member_or_empty(data, "api_version"),
            ApiParsersCommon.string_member_or_empty(data, "server_version"),
            data.has_member("pid") ? (int) data.get_int_member("pid") : 0
        );
    }
}

}
