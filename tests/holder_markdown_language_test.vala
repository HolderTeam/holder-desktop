using GLib;

namespace HolderLinuxTests {

private GtkSource.LanguageManager? language_manager;

private GtkSource.Language load_holder_markdown() {
    var language_dir = Environment.get_variable("HOLDER_MARKDOWN_LANGUAGE_DIR");
    assert(language_dir != null);
    if (language_manager == null) {
        language_manager = new GtkSource.LanguageManager();
        language_manager.prepend_search_path((!) language_dir);
    }
    var language = ((!) language_manager).get_language("holder-markdown");
    assert(language != null);
    return (!) language;
}

private bool has_class(string text, string needle, string context_class) {
    var buffer = new GtkSource.Buffer(null);
    buffer.set_language(load_holder_markdown());
    buffer.set_highlight_syntax(true);
    buffer.set_text(text, -1);

    Gtk.TextIter start;
    Gtk.TextIter end;
    buffer.get_bounds(out start, out end);
    buffer.ensure_highlight(start, end);

    Gtk.TextIter target;
    buffer.get_iter_at_offset(out target, text.index_of(needle) + 1);
    return buffer.iter_has_context_class(target, context_class);
}

private void test_commonmark_heading_boundary_preserves_tags() {
    assert(has_class("# Heading", "Heading", "holder-heading"));
    assert(has_class("   ## Heading", "Heading", "holder-heading"));
    assert(!has_class("#todo", "todo", "holder-heading"));
    assert(!has_class("#ff8800", "ff8800", "holder-heading"));
}

private void test_gfm_and_holder_contexts_are_available() {
    assert(has_class("Use ~~obsolete~~ wording", "obsolete", "holder-strikethrough"));
    assert(has_class("- [x] shipped", "[x]", "holder-task-marker"));
    assert(has_class("| --- | :---: |", "---", "holder-table-delimiter"));
    assert(has_class("> [!WARNING]", "WARNING", "holder-alert"));
    assert(has_class("Visit https://holder.team", "holder.team", "holder-bare-url"));
    assert(has_class("Open [[Release plan]]", "Release", "holder-wikilink"));
}

public static int main(string[] args) {
    Test.init(ref args);
    GtkSource.init();
    Test.add_func("/holder/markdown-language/commonmark-headings", test_commonmark_heading_boundary_preserves_tags);
    Test.add_func("/holder/markdown-language/extensions", test_gfm_and_holder_contexts_are_available);
    var result = Test.run();
    GtkSource.finalize();
    return result;
}

}
