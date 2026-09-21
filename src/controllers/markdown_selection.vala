namespace HolderLinux {

// Offset/string decisions the editor view makes around a markdown selection.
internal class MarkdownSelectionRules {
    public static string? inline_marker_for(MarkdownInlineCommand command) {
        switch (command) {
            case MarkdownInlineCommand.BOLD:
                return "**";
            case MarkdownInlineCommand.ITALIC:
                return "*";
            case MarkdownInlineCommand.STRIKETHROUGH:
                return "~~";
            case MarkdownInlineCommand.CODE:
                return "`";
            default:
                return null;
        }
    }

    // A selection that ends at column 0 of a later line does not include that last line.
    public static int last_line_index(int first_line,
                                      int last_line,
                                      bool has_selection,
                                      int end_line_offset) {
        if (has_selection && end_line_offset == 0 && last_line > first_line) {
            return last_line - 1;
        }
        return last_line;
    }

    // `before` and `after` are up to two characters of text immediately outside the selection
    // (shorter, or empty, at the ends of the document). When the selection is already wrapped in
    // `marker`, the wrapper is included so the toggle removes it instead of wrapping again.
    public static bool should_expand_to_marker(string marker, string before, string after) {
        if (!before.has_suffix(marker) || !after.has_prefix(marker)) {
            return false;
        }
        // A single '*' adjacent to a bold marker is not an italic wrapper.
        if (marker == "*" && (before.has_suffix("**") || after.has_prefix("**"))) {
            return false;
        }
        return true;
    }
}

}
