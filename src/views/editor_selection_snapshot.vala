namespace HolderLinux {

internal class EditorSelectionSnapshot : Object {
    private int insert_line;
    private int insert_line_offset;
    private int bound_line;
    private int bound_line_offset;

    private EditorSelectionSnapshot(int insert_line,
                                    int insert_line_offset,
                                    int bound_line,
                                    int bound_line_offset) {
        this.insert_line = insert_line;
        this.insert_line_offset = insert_line_offset;
        this.bound_line = bound_line;
        this.bound_line_offset = bound_line_offset;
    }

    public static EditorSelectionSnapshot capture(Gtk.TextBuffer buffer) {
        Gtk.TextIter insert;
        Gtk.TextIter bound;
        buffer.get_iter_at_mark(out insert, buffer.get_insert());
        buffer.get_iter_at_mark(out bound, buffer.get_selection_bound());
        return new EditorSelectionSnapshot(
            insert.get_line(),
            text_line_offset(buffer, insert),
            bound.get_line(),
            text_line_offset(buffer, bound)
        );
    }

    public void restore(Gtk.TextBuffer buffer) {
        Gtk.TextIter insert;
        Gtk.TextIter bound;
        get_clamped_iter(buffer, insert_line, insert_line_offset, out insert);
        get_clamped_iter(buffer, bound_line, bound_line_offset, out bound);
        buffer.select_range(insert, bound);
    }

    private static void get_clamped_iter(Gtk.TextBuffer buffer,
                                         int line,
                                         int line_offset,
                                         out Gtk.TextIter iter) {
        var safe_line = int.max(0, int.min(line, buffer.get_line_count() - 1));
        buffer.get_iter_at_line(out iter, safe_line);
        Gtk.TextIter line_end = iter;
        line_end.forward_to_line_end();
        iter.forward_chars(int.max(0, int.min(line_offset, line_end.get_line_offset())));
    }

    private static int text_line_offset(Gtk.TextBuffer buffer, Gtk.TextIter position) {
        Gtk.TextIter line_start;
        buffer.get_iter_at_line(out line_start, position.get_line());
        return buffer.get_text(line_start, position, false).char_count();
    }
}

}
