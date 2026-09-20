namespace HolderLinux {

public class TagChip : Object {
    public string label { get; construct; }
    public string tooltip { get; construct; }
    public string css_class { get; construct; }
    public string tag { get; construct; }

    public TagChip(string tag, string label, string tooltip, string css_class) {
        Object(tag: tag, label: label, tooltip: tooltip, css_class: css_class);
    }
}

public class TagCloudPresentation : Object {
    public Gee.ArrayList<TagChip> chips { get; construct; }
    public string empty_text { get; construct; }
    public bool empty_visible { get; construct; }

    public TagCloudPresentation(Gee.ArrayList<TagChip> chips, string empty_text, bool empty_visible) {
        Object(chips: chips, empty_text: empty_text, empty_visible: empty_visible);
    }
}

public class TagsPresenter {
    public static void sort_tags(Gee.ArrayList<TagCount> tags) {
        tags.sort((a, b) => { return strcmp(a.tag, b.tag); });
    }

    public static TagChip card_tag_chip(string tag) {
        return new TagChip(tag, "#%s".printf(tag), "Show cards tagged #%s".printf(tag), "");
    }

    public static TagChip cloud_chip(string tag, int count, string css_class) {
        return new TagChip(
            tag,
            "#%s  %d".printf(tag, count),
            "%d %s tagged #%s".printf(count, count == 1 ? "card" : "cards", tag),
            css_class
        );
    }

    public static string weight_class(int card_count, int max_count) {
        if (max_count > 1 && card_count * 3 >= max_count * 2) {
            return "title-4";
        }
        if (max_count > 1 && card_count * 3 >= max_count) {
            return "heading";
        }
        return "";
    }

    public static TagCloudPresentation cloud(Gee.List<TagCount> tags, string raw_filter) {
        var filter = raw_filter.strip().down();
        var max_count = 0;
        foreach (var entry in tags) {
            max_count = int.max(max_count, entry.card_count);
        }
        var chips = new Gee.ArrayList<TagChip>();
        foreach (var entry in tags) {
            if (filter.length > 0 && !entry.tag.down().contains(filter)) {
                continue;
            }
            chips.add(cloud_chip(entry.tag, entry.card_count, weight_class(entry.card_count, max_count)));
        }
        var empty_text = filter.length > 0 && chips.size == 0
            ? "No tags match this filter."
            : "No tags in this project yet.";
        return new TagCloudPresentation(chips, empty_text, chips.size == 0);
    }

    public static string format_updated_at(int64 timestamp) {
        if (timestamp <= 0) {
            return "";
        }
        var updated = new DateTime.from_unix_local(timestamp);
        return "Updated %s".printf(updated.format("%x %R"));
    }
}

}
