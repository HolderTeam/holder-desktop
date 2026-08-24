namespace HolderLinux {

internal class TagHighlightRange : Object {
    public int char_start { get; construct; }
    public int char_end { get; construct; }

    public TagHighlightRange(int char_start, int char_end) {
        Object(char_start: char_start, char_end: char_end);
    }
}

internal class TagHighlightingController : Object {
    public Gee.ArrayList<TagHighlightRange> ranges_for(string text,
                                                       CardTagOccurrence[] occurrences) {
        var ranges = new Gee.ArrayList<TagHighlightRange>();
        foreach (var occurrence in occurrences) {
            if (occurrence.byte_start < 0 ||
                occurrence.byte_end <= occurrence.byte_start ||
                occurrence.byte_end > text.length) {
                continue;
            }
            var source = text.substring(
                occurrence.byte_start,
                occurrence.byte_end - occurrence.byte_start
            );
            if (source.down() != "#" + occurrence.tag.down()) {
                continue;
            }
            ranges.add(new TagHighlightRange(
                text.substring(0, occurrence.byte_start).char_count(),
                text.substring(0, occurrence.byte_end).char_count()
            ));
        }
        return ranges;
    }
}

}
