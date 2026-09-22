namespace HolderLinux {

internal class EditorWhitespaceCleaner : Object { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public static bool apply(Gtk.TextBuffer buffer, string canonical_text) {
        Gtk.TextIter document_start;
        Gtk.TextIter document_end;
        buffer.get_bounds(out document_start, out document_end);
        var visible_text = buffer.get_text(document_start, document_end, false);
        if (visible_text == canonical_text) {
            return false;
        }

        var visible_lines = visible_text.split("\n");
        var canonical_lines = canonical_text.split("\n");
        if (visible_lines.length != canonical_lines.length) {
            return false;
        }

        for (int line = 0; line < visible_lines.length; line++) {
            if (!visible_lines[line].has_prefix(canonical_lines[line])) {
                return false;
            }
        }

        // Work backwards so deleting one line's suffix cannot affect any line still to visit.
        // GtkTextBuffer marks, child anchors, and tags then adjust in place; unlike set_text(),
        // this preserves the user's logical cursor/selection and does not reset the viewport.
        buffer.begin_user_action();
        for (int line = visible_lines.length - 1; line >= 0; line--) {
            delete_text_after_prefix(buffer, line, canonical_lines[line].char_count());
        }
        buffer.end_user_action();
        return true;
    }

    // Deletes the text on `line` that follows its first `kept_chars` text characters. Embedded
    // objects (inline image anchors) are not text: the visible text the prefix was measured on leaves
    // them out, so they must neither be counted nor deleted, wherever they sit in the suffix.
    private static void delete_text_after_prefix(Gtk.TextBuffer buffer, int line, int kept_chars) {
        Gtk.TextIter position;
        buffer.get_iter_at_line(out position, line);
        int remaining = kept_chars;
        while (remaining > 0) {
            if (!is_embedded_object(position)) {
                remaining--;
            }
            position.forward_char();
        }

        int[] runs = {};
        int run_start = -1;
        while (!position.ends_line()) {
            if (is_embedded_object(position)) {
                if (run_start >= 0) {
                    runs += run_start;
                    runs += position.get_line_offset();
                    run_start = -1;
                }
            } else if (run_start < 0) {
                run_start = position.get_line_offset();
            }
            position.forward_char();
        }
        if (run_start >= 0) {
            runs += run_start;
            runs += position.get_line_offset();
        }

        for (int i = runs.length - 2; i >= 0; i -= 2) {
            Gtk.TextIter from;
            Gtk.TextIter to;
            buffer.get_iter_at_line_offset(out from, line, runs[i]);
            buffer.get_iter_at_line_offset(out to, line, runs[i + 1]);
            buffer.delete(ref from, ref to);
        }
    }

    private static bool is_embedded_object(Gtk.TextIter position) {
        return position.get_child_anchor() != null || position.get_paintable() != null;
    }
}

}
