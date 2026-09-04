namespace HolderLinux {

internal class EditorWhitespaceCleaner : Object {
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

        var removed_char_counts = new int[visible_lines.length];
        for (int line = 0; line < visible_lines.length; line++) {
            if (!visible_lines[line].has_prefix(canonical_lines[line])) {
                return false;
            }
            removed_char_counts[line] = visible_lines[line].char_count()
                - canonical_lines[line].char_count();
        }

        // Work backwards so deleting one line's suffix cannot affect any line still to visit.
        // GtkTextBuffer marks, child anchors, and tags then adjust in place; unlike set_text(),
        // this preserves the user's logical cursor/selection and does not reset the viewport.
        buffer.begin_user_action();
        for (int line = removed_char_counts.length - 1; line >= 0; line--) {
            var remove_count = removed_char_counts[line];
            if (remove_count == 0) {
                continue;
            }
            Gtk.TextIter remove_end;
            buffer.get_iter_at_line(out remove_end, line);
            remove_end.forward_to_line_end();
            Gtk.TextIter remove_start = remove_end;
            if (!remove_start.backward_chars(remove_count)) {
                buffer.end_user_action();
                return false;
            }
            buffer.delete(ref remove_start, ref remove_end);
        }
        buffer.end_user_action();
        return true;
    }
}

}
