namespace HolderLinux {

public class TextUtils : Object {
    public static string ellipsize(string? value, int max_len) {
        if (value == null) {
            return "";
        }
        if (value.length <= max_len) {
            return value;
        }
        if (max_len <= 3) {
            return value.substring(0, max_len);
        }
        return value.substring(0, max_len - 3) + "...";
    }

    public static string title_from_content(string? text) {
        if (text == null) {
            return "Untitled";
        }
        var lines = text.split("\n");
        foreach (var raw_line in lines) {
            var line = raw_line.strip();
            if (line.length == 0) {
                continue;
            }
            if (line[0] == '#') {
                line = line.substring(1).strip();
            }
            return ellipsize(line, 80);
        }
        return "Untitled";
    }

    public static string format_relative_time(int64 now, int64 timestamp) {
        if (timestamp <= 0) {
            return "unknown";
        }

        var delta = now - timestamp;
        if (delta < 0) {
            return "just now";
        }
        if (delta < 60) {
            return "%llds ago".printf(delta);
        }
        if (delta < 3600) {
            return "%lldm ago".printf(delta / 60);
        }
        if (delta < 86400) {
            return "%lldh ago".printf(delta / 3600);
        }
        return "%lldd ago".printf(delta / 86400);
    }
}

}
