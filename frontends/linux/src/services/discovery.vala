namespace HolderLinux {

public errordomain DiscoveryError {
    NOT_FOUND,
    INVALID_FORMAT
}

public class Discovery : Object {
    public static string holder_info_path() {
        return Path.build_filename(
            Environment.get_user_data_dir(),
            "holder",
            "server",
            "holder.json"
        );
    }

    public static ServerInfo discover_server() throws Error {
        var info_path = holder_info_path();
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
