using GLib;

// Real, GTK-backed tests for src/views/adapters/window_find_replace_ops.vala. The controller-level
// find/replace behaviour is already tested against a fake IFindReplaceOps in
// tests/find_replace_test.vala; this file drives a real GtkSource.Buffer/View instead, since this
// class is where the actual search-and-replace logic lives.

namespace HolderLinuxTests {

private HolderLinux.WindowFindReplaceOps make_ops(string text, out GtkSource.Buffer buffer) {
    buffer = new GtkSource.Buffer(null);
    buffer.set_text(text, -1);
    var view = new GtkSource.View.with_buffer(buffer);
    return new HolderLinux.WindowFindReplaceOps(buffer, view);
}

private string selected_text(GtkSource.Buffer buffer) {
    Gtk.TextIter start;
    Gtk.TextIter end;
    if (!buffer.get_selection_bounds(out start, out end)) {
        return "";
    }
    return buffer.get_text(start, end, false);
}

private void place_cursor_at_start(GtkSource.Buffer buffer) {
    Gtk.TextIter start;
    buffer.get_start_iter(out start);
    buffer.place_cursor(start);
}

private void test_find_next_selects_the_match_after_the_cursor() {
    GtkSource.Buffer buffer;
    var ops = make_ops("alpha beta gamma", out buffer);
    place_cursor_at_start(buffer);

    var found = ops.find_next("beta");

    assert(found);
    assert(selected_text(buffer) == "beta");
}

private void test_find_next_is_case_insensitive() {
    GtkSource.Buffer buffer;
    var ops = make_ops("Alpha Beta Gamma", out buffer);
    place_cursor_at_start(buffer);

    var found = ops.find_next("beta");

    assert(found);
    assert(selected_text(buffer) == "Beta");
}

private void test_find_next_wraps_around_to_the_start() {
    GtkSource.Buffer buffer;
    var ops = make_ops("alpha beta alpha", out buffer);
    // Select the second "alpha" so the search starts after it, past every match, and must wrap.
    Gtk.TextIter start;
    Gtk.TextIter end;
    buffer.get_iter_at_offset(out start, 11);
    buffer.get_iter_at_offset(out end, 16);
    buffer.select_range(start, end);

    var found = ops.find_next("alpha");

    assert(found);
    // Wrapped back to the first occurrence.
    Gtk.TextIter sel_start;
    Gtk.TextIter sel_end;
    assert(buffer.get_selection_bounds(out sel_start, out sel_end));
    assert(sel_start.get_offset() == 0);
}

private void test_find_next_returns_false_when_nothing_matches() {
    GtkSource.Buffer buffer;
    var ops = make_ops("alpha beta gamma", out buffer);
    place_cursor_at_start(buffer);

    var found = ops.find_next("nonexistent");

    assert(!found);
}

private void test_find_next_searches_from_the_selection_end_not_the_start() {
    GtkSource.Buffer buffer;
    var ops = make_ops("cat cat cat", out buffer);
    // Select the first "cat" (offsets 0-3): the next search must start at offset 3, finding the
    // second "cat", not re-matching the one already selected.
    Gtk.TextIter start;
    Gtk.TextIter end;
    buffer.get_iter_at_offset(out start, 0);
    buffer.get_iter_at_offset(out end, 3);
    buffer.select_range(start, end);

    var found = ops.find_next("cat");

    assert(found);
    Gtk.TextIter sel_start;
    Gtk.TextIter sel_end;
    assert(buffer.get_selection_bounds(out sel_start, out sel_end));
    assert(sel_start.get_offset() == 4);
}

private void test_replace_next_replaces_the_match_and_reports_success() {
    GtkSource.Buffer buffer;
    var ops = make_ops("alpha beta gamma", out buffer);
    place_cursor_at_start(buffer);

    bool replaced;
    try {
        replaced = ops.replace_next("beta", "BETA");
    } catch (Error e) {
        assert_not_reached();
    }

    assert(replaced);
    Gtk.TextIter start;
    Gtk.TextIter end;
    buffer.get_bounds(out start, out end);
    assert(buffer.get_text(start, end, false) == "alpha BETA gamma");
}

private void test_replace_next_returns_false_when_nothing_matches() {
    GtkSource.Buffer buffer;
    var ops = make_ops("alpha beta gamma", out buffer);
    place_cursor_at_start(buffer);

    bool replaced;
    try {
        replaced = ops.replace_next("nonexistent", "X");
    } catch (Error e) {
        assert_not_reached();
    }

    assert(!replaced);
    Gtk.TextIter start;
    Gtk.TextIter end;
    buffer.get_bounds(out start, out end);
    assert(buffer.get_text(start, end, false) == "alpha beta gamma");
}

private void test_replace_all_replaces_every_match_and_returns_the_count() {
    GtkSource.Buffer buffer;
    var ops = make_ops("cat cat cat", out buffer);

    uint count;
    try {
        count = ops.replace_all("cat", "dog");
    } catch (Error e) {
        assert_not_reached();
    }

    assert(count == 3);
    Gtk.TextIter start;
    Gtk.TextIter end;
    buffer.get_bounds(out start, out end);
    assert(buffer.get_text(start, end, false) == "dog dog dog");
}

private void test_replace_all_returns_zero_when_nothing_matches() {
    GtkSource.Buffer buffer;
    var ops = make_ops("alpha beta gamma", out buffer);

    uint count;
    try {
        count = ops.replace_all("nonexistent", "X");
    } catch (Error e) {
        assert_not_reached();
    }

    assert(count == 0);
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping window find/replace ops tests: GTK display is unavailable.\n");
        return 0;
    }

    var prefix = "/holder/window-find-replace-ops/";
    Test.add_func(prefix + "find-next-selects-the-match-after-the-cursor",
                  test_find_next_selects_the_match_after_the_cursor);
    Test.add_func(prefix + "find-next-is-case-insensitive",
                  test_find_next_is_case_insensitive);
    Test.add_func(prefix + "find-next-wraps-around-to-the-start",
                  test_find_next_wraps_around_to_the_start);
    Test.add_func(prefix + "find-next-returns-false-when-nothing-matches",
                  test_find_next_returns_false_when_nothing_matches);
    Test.add_func(prefix + "find-next-searches-from-the-selection-end-not-the-start",
                  test_find_next_searches_from_the_selection_end_not_the_start);
    Test.add_func(prefix + "replace-next-replaces-the-match-and-reports-success",
                  test_replace_next_replaces_the_match_and_reports_success);
    Test.add_func(prefix + "replace-next-returns-false-when-nothing-matches",
                  test_replace_next_returns_false_when_nothing_matches);
    Test.add_func(prefix + "replace-all-replaces-every-match-and-returns-the-count",
                  test_replace_all_replaces_every_match_and_returns_the_count);
    Test.add_func(prefix + "replace-all-returns-zero-when-nothing-matches",
                  test_replace_all_returns_zero_when_nothing_matches);

    return Test.run();
}

}
