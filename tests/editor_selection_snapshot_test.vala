using GLib;

namespace HolderLinux.Tests {

private void test_restore_keeps_cursor_and_selection_away_from_document_end() {
    var buffer = new Gtk.TextBuffer(null);
    buffer.set_text("# Title   \n\nMiddle text\nTail", -1);
    Gtk.TextIter insert;
    Gtk.TextIter bound;
    buffer.get_iter_at_line(out insert, 2);
    buffer.create_child_anchor(insert);
    buffer.get_iter_at_line_offset(out insert, 2, 7);
    buffer.get_iter_at_line_offset(out bound, 0, 3);
    buffer.select_range(insert, bound);

    var snapshot = EditorSelectionSnapshot.capture(buffer);
    buffer.set_text("# Title\n\nMiddle text\nTail", -1);
    snapshot.restore(buffer);

    buffer.get_iter_at_mark(out insert, buffer.get_insert());
    buffer.get_iter_at_mark(out bound, buffer.get_selection_bound());
    assert(insert.get_line() == 2);
    assert(insert.get_line_offset() == 6);
    assert(bound.get_line() == 0);
    assert(bound.get_line_offset() == 3);
}

private void test_restore_clamps_position_when_trailing_text_was_removed() {
    var buffer = new Gtk.TextBuffer(null);
    buffer.set_text("Title\nBody   \nTail", -1);
    Gtk.TextIter cursor;
    buffer.get_iter_at_line_offset(out cursor, 1, 7);
    buffer.place_cursor(cursor);

    var snapshot = EditorSelectionSnapshot.capture(buffer);
    buffer.set_text("Title\nBody\nTail", -1);
    snapshot.restore(buffer);

    buffer.get_iter_at_mark(out cursor, buffer.get_insert());
    assert(cursor.get_line() == 1);
    assert(cursor.get_line_offset() == 4);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func(
        "/holder/editor-selection/restore-keeps-cursor-and-selection",
        test_restore_keeps_cursor_and_selection_away_from_document_end
    );
    Test.add_func(
        "/holder/editor-selection/restore-clamps-removed-trailing-text",
        test_restore_clamps_position_when_trailing_text_was_removed
    );
    return Test.run();
}

}
