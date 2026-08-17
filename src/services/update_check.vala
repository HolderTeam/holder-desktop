namespace HolderLinux {

public errordomain UpdateCheckError {
    INVALID_METADATA
}

public interface IUpdateMetadataTransport : Object {
    public abstract async string fetch_text(string url) throws Error;
}

public class SoupUpdateMetadataTransport : Object, IUpdateMetadataTransport {
    private Soup.Session session;

    public SoupUpdateMetadataTransport(Soup.Session? session = null) {
        this.session = session ?? new Soup.Session();
        if (session == null) {
            this.session.timeout = 10;
        }
    }

    public async string fetch_text(string url) throws Error {
        var message = new Soup.Message("GET", url);
        message.request_headers.append("Accept", "application/json");
        var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);

        var status = message.get_status();
        if (status < 200 || status >= 300) {
            throw new UpdateCheckError.INVALID_METADATA("HTTP %u while fetching update metadata".printf((uint) status));
        }

        return string_from_bytes(bytes);
    }

    private static string string_from_bytes(Bytes bytes) {
        var data = bytes.get_data();
        var size = bytes.get_size();
        if (size > 0 && data[size - 1] == 0) {
            size--;
        }

        uint8[] copy = new uint8[(int) size + 1];
        for (int i = 0; i < size; i++) {
            copy[i] = data[i];
        }
        copy[(int) size] = 0;
        return ((string) copy).dup();
    }
}

public class UpdateCandidate : Object {
    public string version { get; construct; }
    public string message { get; construct; }
    public string download_url { get; construct; }

    public UpdateCandidate(string version, string message, string download_url) {
        Object(version: version, message: message, download_url: download_url);
    }
}

public class UpdateCheckService : Object {
    public const string DEFAULT_VERSION_URL = "https://holder.team/version.json";
    public const int64 CHECK_INTERVAL_SECONDS = 24 * 60 * 60;
    public const int64 PROMPT_INTERVAL_SECONDS = 7 * 24 * 60 * 60;

    private IUpdateMetadataTransport transport;
    private IClock clock;
    private string version_url;
    private string platform_key;
    private bool debug_enabled;

    public UpdateCheckService(IUpdateMetadataTransport? transport = null,
                              IClock? clock = null,
                              string? version_url = null,
                              string? platform_key = null) {
        this.transport = transport ?? new SoupUpdateMetadataTransport();
        this.clock = clock ?? new SystemClock();
        var env_url = Environment.get_variable("HOLDER_UPDATE_CHECK_URL");
        this.version_url = version_url ?? ((env_url != null && env_url.strip() != "") ? env_url : DEFAULT_VERSION_URL);
        this.platform_key = platform_key ?? resolve_platform_key();
        this.debug_enabled = Environment.get_variable("HOLDER_UPDATE_CHECK_DEBUG") == "1";
    }

    public async UpdateCandidate? check_if_due(Settings? settings, string current_version) {
        if (settings == null) {
            return null;
        }

        var now = clock.now_epoch_seconds();
        var last_check = settings.get_int64(AppSettings.KEY_UPDATE_LAST_CHECK_AT);
        if (!should_check(settings, now)) {
            debug(("skipped; checked recently; last_check=%" + int64.FORMAT + " now=%" + int64.FORMAT + " age=%" + int64.FORMAT).printf(
                last_check,
                now,
                now - last_check
            ));
            return null;
        }
        settings.set_int64(AppSettings.KEY_UPDATE_LAST_CHECK_AT, now);

        UpdateCandidate? candidate = null;
        try {
            debug("fetching %s for platform %s".printf(version_url, platform_key));
            candidate = yield fetch_update_candidate(current_version);
        } catch (Error e) {
            debug("failed: %s".printf(e.message));
            return null;
        }

        if (candidate == null) {
            debug("no newer update candidate for current version %s".printf(current_version));
            return null;
        }

        if (!should_prompt(settings, candidate.version, now)) {
            debug("candidate %s suppressed by prompt throttle".printf(candidate.version));
            return null;
        }
        debug("candidate %s available at %s".printf(candidate.version, candidate.download_url));
        return candidate;
    }

    public async UpdateCandidate? fetch_update_candidate(string current_version) throws Error {
        var text = yield transport.fetch_text(version_url);
        var candidate = parse_metadata(text);
        if (candidate == null) {
            return null;
        }
        if (compare_versions(candidate.version, current_version) <= 0) {
            return null;
        }
        return candidate;
    }

    public void record_prompt(Settings? settings, string version) {
        if (settings == null) {
            return;
        }
        settings.set_string(AppSettings.KEY_UPDATE_LAST_PROMPT_VERSION, version);
        settings.set_int64(AppSettings.KEY_UPDATE_LAST_PROMPT_AT, clock.now_epoch_seconds());
    }

    public bool should_check(Settings settings, int64 now) {
        var last_check = settings.get_int64(AppSettings.KEY_UPDATE_LAST_CHECK_AT);
        return last_check <= 0 || now - last_check >= CHECK_INTERVAL_SECONDS;
    }

    public bool should_prompt(Settings settings, string version, int64 now) {
        var last_version = settings.get_string(AppSettings.KEY_UPDATE_LAST_PROMPT_VERSION);
        var last_prompt = settings.get_int64(AppSettings.KEY_UPDATE_LAST_PROMPT_AT);
        return last_version != version || last_prompt <= 0 || now - last_prompt >= PROMPT_INTERVAL_SECONDS;
    }

    public UpdateCandidate? parse_metadata(string text) {
        var parser = new Json.Parser();
        try {
            parser.load_from_data(text, -1);
            var root = parser.get_root();
            if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
                return null;
            }
            return parse_metadata_object(root.get_object());
        } catch (Error e) {
            return null;
        }
    }

    private UpdateCandidate? parse_metadata_object(Json.Object root) throws Error {
        if (!root.has_member("schema") || root.get_int_member("schema") != 1) {
            return null;
        }
        if (string_member_or_empty(root, "product") != "Holder") {
            return null;
        }
        if (string_member_or_empty(root, "channel") != "stable") {
            return null;
        }

        var version = string_member_or_empty(root, "version");
        if (!is_dotted_numeric_version(version)) {
            return null;
        }

        var download_url = platform_download_url(root);
        if (download_url == "") {
            download_url = string_member_or_empty(root, "release_url");
        }
        if (download_url == "") {
            return null;
        }

        var message = string_member_or_empty(root, "message");
        if (message == "") {
            message = "A new Holder release is available.";
        }

        return new UpdateCandidate(version, message, download_url);
    }

    private string platform_download_url(Json.Object root) {
        if (!root.has_member("downloads")) {
            return "";
        }
        var node = root.get_member("downloads");
        if (node == null || node.get_node_type() != Json.NodeType.OBJECT) {
            return "";
        }
        return string_member_or_empty(node.get_object(), platform_key);
    }

    private static string string_member_or_empty(Json.Object obj, string member) {
        if (!obj.has_member(member)) {
            return "";
        }
        var node = obj.get_member(member);
        if (node == null || node.get_node_type() != Json.NodeType.VALUE) {
            return "";
        }
        return obj.get_string_member(member);
    }

    public static int compare_versions(string lhs, string rhs) {
        int[] left;
        int[] right;
        var left_valid = parse_dotted_numeric_version(lhs, out left);
        var right_valid = parse_dotted_numeric_version(rhs, out right);
        if (!left_valid || !right_valid) {
            return 0;
        }

        var max_len = int.max(left.length, right.length);
        for (int i = 0; i < max_len; i++) {
            var left_value = i < left.length ? left[i] : 0;
            var right_value = i < right.length ? right[i] : 0;
            if (left_value > right_value) {
                return 1;
            }
            if (left_value < right_value) {
                return -1;
            }
        }
        return 0;
    }

    public static bool is_dotted_numeric_version(string version) {
        int[] parts;
        return parse_dotted_numeric_version(version, out parts);
    }

    private static bool parse_dotted_numeric_version(string version, out int[] parts) {
        parts = {};
        var clean = version.strip();
        if (clean == "") {
            return false;
        }

        var raw_parts = clean.split(".");
        parts = new int[raw_parts.length];
        var index = 0;
        foreach (var raw_part in raw_parts) {
            if (raw_part == "") {
                return false;
            }
            int parsed = 0;
            if (!int.try_parse(raw_part, out parsed) || parsed < 0) {
                return false;
            }
            parts[index++] = parsed;
        }
        return parts.length > 0;
    }

    private static string resolve_platform_key() {
        var test_platform = Environment.get_variable("HOLDER_DESKTOP_TEST_PLATFORM");
        var platform = test_platform != null ? test_platform : HolderLinux.PLATFORM;

        switch (platform.down()) {
        case "darwin":
        case "macos":
            return "macos";
        case "windows":
        case "mingw":
            return "windows";
        default:
            return "linux";
        }
    }

    private void debug(string line) {
        if (!debug_enabled) {
            return;
        }
        message("Update check: %s", line);
    }
}

}
