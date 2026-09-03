namespace HolderLinux {

public class PowerShellTranscriptSnapshot : Object {
    public string raw_text { get; construct; }
    public string useful_text { get; construct; }
    public bool completed { get; construct; }

    public PowerShellTranscriptSnapshot(string raw_text,
                                        string useful_text,
                                        bool completed) {
        Object(
            raw_text: raw_text,
            useful_text: useful_text,
            completed: completed
        );
    }
}

public class PowerShellTranscriptParser : Object {
    private const string DELIMITER = "**********************";
    private const string START_MARKER = "PowerShell transcript start";
    private const string END_MARKER = "PowerShell transcript end";

    public PowerShellTranscriptSnapshot parse(string raw_text) {
        var normalized = normalize_text(raw_text);
        var completed = has_completed_footer(normalized);
        var useful = strip_bookkeeping(normalized);
        useful = strip_terminal_control_sequences(useful);
        return new PowerShellTranscriptSnapshot(normalized, useful, completed);
    }

    internal static string normalize_text(string text) {
        var normalized = text;
        if (normalized.has_prefix("\xEF\xBB\xBF")) {
            normalized = normalized.substring(3);
        }
        return normalized.replace("\r\n", "\n").replace("\r", "\n");
    }

    internal static bool has_completed_footer(string normalized_text) {
        var lines = normalized_text.split("\n");
        for (int i = 0; i + 1 < lines.length; i++) {
            if (lines[i] == DELIMITER && lines[i + 1] == END_MARKER) {
                return true;
            }
        }
        return false;
    }

    internal static string strip_bookkeeping(string normalized_text) {
        var lines = normalized_text.split("\n");
        int start = 0;
        int end = lines.length;

        if (lines.length >= 2 && lines[0] == DELIMITER && lines[1] == START_MARKER) {
            for (int i = 2; i < lines.length; i++) {
                if (lines[i] == DELIMITER) {
                    start = i + 1;
                    break;
                }
            }
        }

        while (start < end && lines[start].strip().length == 0) {
            start++;
        }
        if (start < end && lines[start].has_prefix("Transcript started, output file is ")) {
            start++;
        }

        for (int i = start; i + 1 < lines.length; i++) {
            if (lines[i] == DELIMITER && lines[i + 1] == END_MARKER) {
                end = i;
                break;
            }
        }

        while (end > start && lines[end - 1].strip().length == 0) {
            end--;
        }
        if (end > start && lines[end - 1].has_suffix("> Stop-Transcript")) {
            end--;
        }
        while (end > start && lines[end - 1].strip().length == 0) {
            end--;
        }

        var output = new StringBuilder();
        for (int i = start; i < end; i++) {
            if (i > start) {
                output.append_c('\n');
            }
            output.append(lines[i]);
        }
        return output.str;
    }

    internal static string strip_terminal_control_sequences(string text) {
        try {
            var ansi = new Regex("\x1b\\[[0-?]*[ -/]*[@-~]");
            return ansi.replace(text, -1, 0, "");
        } catch (RegexError e) {
            return text; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: constant regular expression is valid.
        }
    }
}

}
