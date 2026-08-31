namespace HolderLinux {

public class MarkdownResourceImageReference : Object {
    public string alt_text { get; construct; }
    public string resource_id { get; construct; }
    public int char_offset { get; construct; }
    public int byte_start { get; construct; }
    public int byte_end { get; construct; }

    public MarkdownResourceImageReference(string alt_text,
                                          string resource_id,
                                          int char_offset,
                                          int byte_start,
                                          int byte_end) {
        Object(
            alt_text: alt_text,
            resource_id: resource_id,
            char_offset: char_offset,
            byte_start: byte_start,
            byte_end: byte_end
        );
    }
}

public class InlineResourceImageItem : Object {
    public MarkdownResourceImageReference reference { get; construct; }
    public ProjectResource resource { get; construct; }
    public ResourceAsset asset { get; construct; }

    public InlineResourceImageItem(MarkdownResourceImageReference reference,
                                   ProjectResource resource,
                                   ResourceAsset asset) {
        Object(reference: reference, resource: resource, asset: asset);
    }

    public string key() {
        return "%d:%s".printf(reference.char_offset, resource.resource_id);
    }
}

public class MarkdownResourceImageController : Object {
    private const string RESOURCE_IMAGE_PATTERN =
        "^[ ]{0,3}!\\[((?:\\\\.|[^\\]])*)\\]\\([ ]*<?holder://resource/" +
        "([A-Za-z0-9][A-Za-z0-9._-]*)>?[ ]*\\)[ ]*$";

    public Gee.ArrayList<MarkdownResourceImageReference> extract(string markdown) {
        var references = new Gee.ArrayList<MarkdownResourceImageReference>();
        Regex image_regex;
        try {
            image_regex = new Regex(RESOURCE_IMAGE_PATTERN);
        } catch (RegexError e) {
            return references;
        }

        bool in_fence = false;
        char fence_character = '\0';
        int fence_length = 0;
        int byte_offset = 0;
        int char_offset = 0;
        foreach (var line in markdown.split("\n")) {
            char marker;
            int marker_length;
            bool closes_fence;
            if (fence_marker(line, in_fence, fence_character, fence_length,
                             out marker, out marker_length, out closes_fence)) {
                if (!in_fence) {
                    in_fence = true;
                    fence_character = marker;
                    fence_length = marker_length;
                } else if (closes_fence) {
                    in_fence = false;
                    fence_character = '\0';
                    fence_length = 0;
                }
            } else if (!in_fence && !line.has_prefix("    ") && !line.has_prefix("\t")) {
                MatchInfo match;
                if (image_regex.match(line, 0, out match)) {
                    references.add(new MarkdownResourceImageReference(
                        unescape_alt_text(match.fetch(1)),
                        match.fetch(2),
                        char_offset,
                        byte_offset,
                        byte_offset + line.length
                    ));
                }
            }
            byte_offset += line.length + 1;
            char_offset += line.char_count() + 1;
        }
        return references;
    }

    public string? resource_id_at_byte_offset(string markdown, int byte_offset) {
        if (byte_offset < 0 || byte_offset > markdown.length) {
            return null;
        }
        foreach (var reference in extract(markdown)) {
            if (byte_offset >= reference.byte_start && byte_offset <= reference.byte_end) {
                return reference.resource_id;
            }
        }
        return null;
    }

    public Gee.ArrayList<InlineResourceImageItem> resolve(
        string markdown,
        Gee.ArrayList<ProjectResource> resources
    ) {
        var resources_by_id = new Gee.HashMap<string, ProjectResource>();
        foreach (var resource in resources) {
            resources_by_id.set(resource.resource_id, resource);
        }
        var items = new Gee.ArrayList<InlineResourceImageItem>();
        foreach (var reference in extract(markdown)) {
            var resource = resources_by_id.get(reference.resource_id);
            if (resource == null) {
                continue;
            }
            ResourceAsset? image_asset = null;
            foreach (var asset in resource.assets) {
                if (asset.media_type.has_prefix("image/")) {
                    image_asset = asset;
                    break;
                }
            }
            if (image_asset != null) {
                items.add(new InlineResourceImageItem(reference, resource, (!) image_asset));
            }
        }
        return items;
    }

    public static string markdown_for_file(string filename, string resource_id) {
        var basename = Path.get_basename(filename.strip());
        var dot = basename.last_index_of(".");
        if (dot > 0) {
            basename = basename.substring(0, dot);
        }
        var readable = basename.replace("_", " ").replace("-", " ").strip();
        try {
            readable = new Regex("[ ]+").replace(readable, -1, 0, " ");
        } catch (RegexError e) {
        }
        if (readable.length == 0) {
            readable = "Image";
        }
        var alt = readable.replace("\\", "\\\\").replace("]", "\\]");
        return "![%s](holder://resource/%s)".printf(alt, resource_id);
    }

    public static string block_insertion(string markdown,
                                         bool at_line_start,
                                         bool at_line_end) {
        var prefix = at_line_start ? "" : "\n";
        var suffix = at_line_end ? "" : "\n";
        return prefix + markdown + suffix;
    }

    public static bool filename_is_image(string filename) {
        var lower = filename.down();
        return lower.has_suffix(".png") || lower.has_suffix(".jpg") ||
            lower.has_suffix(".jpeg") || lower.has_suffix(".gif") ||
            lower.has_suffix(".webp") || lower.has_suffix(".svg") ||
            lower.has_suffix(".bmp") || lower.has_suffix(".avif") ||
            lower.has_suffix(".heic") || lower.has_suffix(".heif");
    }

    private static string unescape_alt_text(string value) {
        var result = new StringBuilder();
        bool escaped = false;
        int offset = 0;
        unichar ch;
        while (value.get_next_char(ref offset, out ch)) {
            if (escaped) {
                result.append_unichar(ch);
                escaped = false;
            } else if (ch == '\\') {
                escaped = true;
            } else {
                result.append_unichar(ch);
            }
        }
        if (escaped) {
            result.append_c('\\');
        }
        return result.str;
    }

    private static bool fence_marker(string line,
                                     bool in_fence,
                                     char expected_character,
                                     int expected_length,
                                     out char marker,
                                     out int marker_length,
                                     out bool closes_fence) {
        marker = '\0';
        marker_length = 0;
        closes_fence = false;
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
        if (marker_length < 3) {
            return false;
        }
        if (in_fence) {
            closes_fence = marker == expected_character && marker_length >= expected_length &&
                line.substring(position).strip().length == 0;
        }
        return true;
    }
}

}
