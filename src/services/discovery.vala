namespace HolderLinux {

public errordomain DiscoveryError {
    NOT_FOUND,
    INVALID_FORMAT
}

public class Discovery : Object {
    internal static bool force_windows_path_fallback_for_tests = false;

    private static string server_info_path_for_data_home(string data_home) {
        return Path.build_filename(
            data_home,
            "holder",
            "server",
            "holder.json"
        );
    }

    public static string holder_info_path() {
        return server_info_path_for_data_home(Environment.get_user_data_dir());
    }

    private static bool should_include_windows_path_fallbacks() {
        return force_windows_path_fallback_for_tests || Path.DIR_SEPARATOR_S == "\\";
    }

    private static string[] holder_info_candidate_paths() {
        string[] paths = {};
        paths += holder_info_path();

        if (!should_include_windows_path_fallbacks()) {
            return paths;
        }

        var xdg_data_home = Environment.get_variable("XDG_DATA_HOME");
        if (xdg_data_home != null && xdg_data_home.strip().length > 0) {
            paths += server_info_path_for_data_home(xdg_data_home);
        }

        var home = Environment.get_variable("HOME");
        if (home != null && home.strip().length > 0) {
            paths += server_info_path_for_data_home(Path.build_filename(home, ".local", "share"));
        }

        var user_profile = Environment.get_variable("USERPROFILE");
        if (user_profile != null && user_profile.strip().length > 0) {
            paths += server_info_path_for_data_home(Path.build_filename(user_profile, ".local", "share"));
        }

        return paths;
    }

    public static ServerInfo discover_server() throws Error {
        var info_path = "";
        foreach (var candidate in holder_info_candidate_paths()) {
            if (FileUtils.test(candidate, FileTest.EXISTS)) {
                info_path = candidate;
                break;
            }
        }

        if (info_path == "") {
            info_path = holder_info_path();
        }

        if (!FileUtils.test(info_path, FileTest.EXISTS)) {
            throw new DiscoveryError.NOT_FOUND(
                "Holder is not running. Missing %s".printf(info_path)
            );
        }

        string json_text;
        size_t json_len;
        try {
            FileUtils.get_contents(info_path, out json_text, out json_len);
        } catch (FileError e) {
            throw new DiscoveryError.INVALID_FORMAT(
                "Failed to read %s: %s".printf(info_path, e.message)
            );
        }

        var parser = new Json.Parser();
        try {
            parser.load_from_data(json_text, (ssize_t) json_len);
        } catch (Error e) {
            throw new DiscoveryError.INVALID_FORMAT(
                "Invalid JSON in %s: %s".printf(info_path, e.message)
            );
        }

        var root = parser.get_root();
        if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
            throw new DiscoveryError.INVALID_FORMAT(
                "Invalid holder.json root format"
            );
        }

        var obj = root.get_object();
        if (!obj.has_member("bind") ||
            !obj.has_member("port") ||
            !obj.has_member("auth_token")) {
            throw new DiscoveryError.INVALID_FORMAT(
                "holder.json missing required fields"
            );
        }

        return new ServerInfo(
            (int) obj.get_int_member("pid"),
            obj.get_string_member("bind"),
            (int) obj.get_int_member("port"),
            obj.get_int_member("started_at"),
            obj.get_string_member("api_version"),
            obj.get_string_member("server_version"),
            obj.get_string_member("auth_token")
        );
    }
}

public class FileServerDiscovery : Object, IServerDiscovery {
    public ServerInfo discover_server() throws Error {
        return Discovery.discover_server();
    }

    public string holder_info_path() {
        return Discovery.holder_info_path();
    }
}

}
