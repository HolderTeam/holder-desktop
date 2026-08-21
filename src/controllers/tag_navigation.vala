namespace HolderLinux {

internal class TagNavigationController : Object {
    public string? tag_at_byte_offset(string text,
                                     int byte_offset,
                                     CardTagOccurrence[] occurrences) {
        if (text.length == 0 || occurrences.length == 0 || byte_offset < 0) {
            return null;
        }
        foreach (var occurrence in occurrences) {
            if (byte_offset < occurrence.byte_start || byte_offset > occurrence.byte_end) {
                continue;
            }
            if (occurrence.byte_start < 0 || occurrence.byte_end > text.length ||
                occurrence.byte_end <= occurrence.byte_start) {
                continue;
            }
            var source = text.substring(
                occurrence.byte_start,
                occurrence.byte_end - occurrence.byte_start
            );
            if (source.down() == "#" + occurrence.tag) {
                return occurrence.tag;
            }
        }
        return null;
    }
}

}
