using GLib;

namespace HolderLinux.Tests {

private string buffer_text(Gtk.TextBuffer buffer) {
    Gtk.TextIter start;
    Gtk.TextIter end;
    buffer.get_bounds(out start, out end);
    return buffer.get_text(start, end, false);
}

private void test_apply_deletes_only_canonicalized_line_suffixes() {
    var buffer = new Gtk.TextBuffer(null);
    buffer.set_text("First   \nSecond  \nThird", -1);
    Gtk.TextIter cursor;
    buffer.get_iter_at_line_offset(out cursor, 2, 2);
    buffer.place_cursor(cursor);

    assert(EditorWhitespaceCleaner.apply(buffer, "First\nSecond\nThird"));
    assert(buffer_text(buffer) == "First\nSecond\nThird");
    buffer.get_iter_at_mark(out cursor, buffer.get_insert());
    assert(cursor.get_line() == 2);
    assert(cursor.get_line_offset() == 2);
}

private void test_apply_moves_cursor_with_explicitly_removed_typing_space() {
    var buffer = new Gtk.TextBuffer(null);
    buffer.set_text("hello ", -1);
    Gtk.TextIter cursor;
    buffer.get_end_iter(out cursor);
    buffer.place_cursor(cursor);

    assert(EditorWhitespaceCleaner.apply(buffer, "hello"));
    assert(buffer_text(buffer) == "hello");
    buffer.get_iter_at_mark(out cursor, buffer.get_insert());
    assert(cursor.get_offset() == 5);
}

private void test_apply_preserves_inline_child_anchor() {
    var buffer = new Gtk.TextBuffer(null);
    buffer.set_text("First   \n![Image](holder://resource/abc)  \nTail", -1);
    Gtk.TextIter anchor_position;
    buffer.get_iter_at_line(out anchor_position, 1);
    var anchor = buffer.create_child_anchor(anchor_position);
    Gtk.TextIter cursor;
    buffer.get_iter_at_line_offset(out cursor, 2, 2);
    buffer.place_cursor(cursor);

    assert(EditorWhitespaceCleaner.apply(
        buffer,
        "First\n![Image](holder://resource/abc)\nTail"
    ));
    assert(!anchor.get_deleted());
    assert(buffer_text(buffer) == "First\n![Image](holder://resource/abc)\nTail");
    buffer.get_iter_at_mark(out cursor, buffer.get_insert());
    assert(cursor.get_line() == 2);
    assert(cursor.get_line_offset() == 2);
}

private void test_apply_rejects_non_suffix_replacement() {
    var buffer = new Gtk.TextBuffer(null);
    buffer.set_text("Original", -1);

    assert(!EditorWhitespaceCleaner.apply(buffer, "Changed"));
    assert(buffer_text(buffer) == "Original");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func(
        "/holder/editor-whitespace-cleaner/deletes-only-line-suffixes",
        test_apply_deletes_only_canonicalized_line_suffixes
    );
    Test.add_func(
        "/holder/editor-whitespace-cleaner/moves-cursor-with-explicit-cleanup",
        test_apply_moves_cursor_with_explicitly_removed_typing_space
    );
    Test.add_func(
        "/holder/editor-whitespace-cleaner/preserves-inline-child-anchor",
        test_apply_preserves_inline_child_anchor
    );
    Test.add_func(
        "/holder/editor-whitespace-cleaner/rejects-non-suffix-replacement",
        test_apply_rejects_non_suffix_replacement
    );
    return Test.run();
}

}
