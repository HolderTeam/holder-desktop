namespace HolderLinux {

internal class MarkdownLinkController : Object {
    public string? uri_at_byte_offset(string text, int byte_offset) {
        if (text.length == 0 || byte_offset < 0 || byte_offset > text.length) {
            return null;
        }
        if (is_code_at_byte_offset(text, byte_offset)) {
            return null;
        }

        var uri = uri_from_match(
            text,
            byte_offset,
            "\\[[^\\]\\n]+\\]\\(<?((?:https?://|mailto:)[^\\s<>\\)]+)>?\\)",
            1,
            false
        );
        if (uri != null) {
            return uri;
        }

        uri = uri_from_match(
            text,
            byte_offset,
            "<((?:https?://|mailto:)[^\\s<>]+)>",
            1,
            false
        );
        if (uri != null) {
            return uri;
        }

        var email = uri_from_match(
            text,
            byte_offset,
            "<([A-Za-z0-9.!#$%&'*+/=?^_{}~-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,})>",
            1,
            false,
            "mailto:"
        );
        if (email != null) {
            return email;
        }

        return uri_from_match(
            text,
            byte_offset,
            "((?:https?://|mailto:)[^\\s<>\\\"']+)",
            1,
            true
        );
    }

    private string? uri_from_match(string text,
                                   int byte_offset,
                                   string pattern,
                                   int uri_group,
                                   bool trim_bare_punctuation,
                                   string uri_prefix = "") {
        try {
            var regex = new Regex(pattern, RegexCompileFlags.CASELESS);
            MatchInfo match_info;
            if (!regex.match(text, 0, out match_info)) {
                return null;
            }
            do {
                int match_start;
                int match_end;
                if (!match_info.fetch_pos(0, out match_start, out match_end) ||
                    byte_offset < match_start || byte_offset > match_end) {
                    continue;
                }
                var candidate = match_info.fetch(uri_group);
                if (trim_bare_punctuation) {
                    candidate = trim_trailing_punctuation(candidate);
                    int uri_start;
                    int uri_end;
                    if (!match_info.fetch_pos(uri_group, out uri_start, out uri_end) ||
                        byte_offset > uri_start + candidate.length) {
                        return null;
                    }
                }
                return safe_uri(uri_prefix + candidate);
            } while (match_info.next());
        } catch (RegexError e) {
            // Malformed built-in expressions must not disrupt editor navigation.
        }
        return null;
    }

    private string? safe_uri(string candidate) {
        var scheme = GLib.Uri.parse_scheme(candidate);
        if (scheme == null) {
            return null;
        }
        var normalized = scheme.down();
        if (normalized != "http" && normalized != "https" && normalized != "mailto") {
            return null;
        }
        return candidate;
    }

    private string trim_trailing_punctuation(string candidate) {
        var result = candidate;
        while (result.length > 0) {
            var last = result[result.length - 1];
            if (last == '.' || last == ',' || last == ';' || last == ':' ||
                last == '!' || last == '?') {
                result = result.substring(0, result.length - 1);
                continue;
            }
            if (last == ')' && count_byte(result, '(') < count_byte(result, ')')) {
                result = result.substring(0, result.length - 1);
                continue;
            }
            if (last == ']' && count_byte(result, '[') < count_byte(result, ']')) {
                result = result.substring(0, result.length - 1);
                continue;
            }
            break;
        }
        return result;
    }

    private int count_byte(string text, char needle) {
        int count = 0;
        for (int i = 0; i < text.length; i++) {
            if (text[i] == needle) {
                count++;
            }
        }
        return count;
    }

    private bool is_code_at_byte_offset(string text, int byte_offset) {
        var prefix = text.substring(0, byte_offset);
        var line_start = prefix.last_index_of("\n") + 1;
        var line_end = text.index_of("\n", line_start);
        if (line_end < 0) {
            line_end = text.length;
        }
        var line = text.substring(line_start, line_end - line_start);
        var line_offset = byte_offset - line_start;

        if (line.has_prefix("\t") || line.has_prefix("    ")) {
            return true;
        }
        if (inside_fenced_code(text, line_start, line)) {
            return true;
        }
        return inside_inline_code(line, line_offset);
    }

    private bool inside_fenced_code(string text, int current_line_start, string current_line) {
        bool in_fence = false;
        char fence_character = '\0';
        int fence_length = 0;
        var preceding = text.substring(0, current_line_start);
        foreach (var line in preceding.split("\n")) {
            char marker;
            int marker_length;
            int marker_end;
            if (!fence_marker(line, out marker, out marker_length, out marker_end)) {
                continue;
            }
            if (!in_fence) {
                in_fence = true;
                fence_character = marker;
                fence_length = marker_length;
            } else if (marker == fence_character && marker_length >= fence_length &&
                       line.substring(marker_end).strip().length == 0) {
                in_fence = false;
            }
        }
        if (in_fence) {
            return true;
        }

        char current_marker;
        int current_length;
        int current_end;
        return fence_marker(
            current_line,
            out current_marker,
            out current_length,
            out current_end
        );
    }

    private bool fence_marker(string line,
                              out char marker,
                              out int marker_length,
                              out int marker_end) {
        marker = '\0';
        marker_length = 0;
        marker_end = 0;
        int position = 0;
        while (position < line.length && position < 3 && line[position] == ' ') {
            position++;
        }
        if (position >= line.length || (line[position] != '`' && line[position] != '~')) {
            return false;
        }
        marker = line[position];
        while (position < line.length && line[position] == marker) {
            marker_length++;
            position++;
        }
        marker_end = position;
        return marker_length >= 3;
    }

    private bool inside_inline_code(string line, int line_offset) {
        try {
            var regex = new Regex("(`+)[^\\n]*?\\1");
            MatchInfo match_info;
            if (!regex.match(line, 0, out match_info)) {
                return false;
            }
            do {
                int start;
                int end;
                if (match_info.fetch_pos(0, out start, out end) &&
                    line_offset >= start && line_offset <= end) {
                    return true;
                }
            } while (match_info.next());
        } catch (RegexError e) {
            return false;
        }
        return false;
    }
}

}
