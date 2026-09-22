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

private void test_apply_leaves_a_buffer_that_already_matches_untouched() {
    var buffer = new Gtk.TextBuffer(null);
    buffer.set_text("Already clean\nText", -1);

    assert(!EditorWhitespaceCleaner.apply(buffer, "Already clean\nText"));
    assert(buffer_text(buffer) == "Already clean\nText");
}

private void test_apply_rejects_a_canonical_text_with_a_different_line_count() {
    var buffer = new Gtk.TextBuffer(null);
    buffer.set_text("One  \nTwo", -1);

    assert(!EditorWhitespaceCleaner.apply(buffer, "One Two"));
    assert(!EditorWhitespaceCleaner.apply(buffer, "One\nTwo\nThree"));
    assert(buffer_text(buffer) == "One  \nTwo");
}

private void test_apply_keeps_a_child_anchor_that_sits_after_the_trailing_whitespace() {
    var buffer = new Gtk.TextBuffer(null);
    buffer.set_text("![Image](holder://resource/abc)  ", -1);
    // Typing at the end of the markdown while the cursor is left of the inline image puts the spaces
    // before the anchor, so the line ends with the anchor rather than with the spaces.
    Gtk.TextIter end;
    buffer.get_end_iter(out end);
    var anchor = buffer.create_child_anchor(end);
    var before = buffer.get_char_count();

    assert(EditorWhitespaceCleaner.apply(buffer, "![Image](holder://resource/abc)"));

    assert(!anchor.get_deleted());
    assert(buffer_text(buffer) == "![Image](holder://resource/abc)");
    // Two spaces removed, and nothing else: the anchor still occupies its one character.
    assert(buffer.get_char_count() == before - 2);
}

private void test_apply_removes_whitespace_on_both_sides_of_an_anchor_inside_the_suffix() {
    var buffer = new Gtk.TextBuffer(null);
    buffer.set_text("a    ", -1);
    Gtk.TextIter middle;
    buffer.get_iter_at_offset(out middle, 3);
    var anchor = buffer.create_child_anchor(middle);

    assert(EditorWhitespaceCleaner.apply(buffer, "a"));

    assert(!anchor.get_deleted());
    assert(buffer_text(buffer) == "a");
    Gtk.TextIter after;
    buffer.get_iter_at_child_anchor(out after, anchor);
    // Both runs of spaces are gone; the anchor is all that follows the text.
    assert(after.get_offset() == 1);
    assert(buffer.get_char_count() == 2);
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
    Test.add_func(
        "/holder/editor-whitespace-cleaner/leaves-a-matching-buffer-untouched",
        test_apply_leaves_a_buffer_that_already_matches_untouched
    );
    Test.add_func(
        "/holder/editor-whitespace-cleaner/rejects-a-different-line-count",
        test_apply_rejects_a_canonical_text_with_a_different_line_count
    );
    Test.add_func(
        "/holder/editor-whitespace-cleaner/keeps-an-anchor-after-trailing-whitespace",
        test_apply_keeps_a_child_anchor_that_sits_after_the_trailing_whitespace
    );
    Test.add_func(
        "/holder/editor-whitespace-cleaner/removes-whitespace-around-an-anchor",
        test_apply_removes_whitespace_on_both_sides_of_an_anchor_inside_the_suffix
    );
    return Test.run();
}

}
