namespace HolderLinux {

internal class WindowFindReplaceOps : Object, IFindReplaceOps {
    private GtkSource.Buffer editor_buffer;
    private GtkSource.View editor_view;

    public WindowFindReplaceOps(GtkSource.Buffer editor_buffer, GtkSource.View editor_view) {
        this.editor_buffer = editor_buffer;
        this.editor_view = editor_view;
    }

    public bool find_next(string find_text) {
        var context = create_search_context(find_text);
        Gtk.TextIter match_start;
        Gtk.TextIter match_end;
        if (!find_match(context, out match_start, out match_end)) {
            return false;
        }
        editor_buffer.select_range(match_start, match_end);
        editor_view.scroll_to_iter(match_start, 0.1, false, 0, 0);
        return true;
    }

    public bool replace_next(string find_text, string replace_text) throws Error {
        var context = create_search_context(find_text);
        Gtk.TextIter match_start;
        Gtk.TextIter match_end;
        if (!find_match(context, out match_start, out match_end)) {
            return false;
        }
        context.replace(match_start, match_end, replace_text, -1);
        return true;
    }

    public uint replace_all(string find_text, string replace_text) throws Error {
        var context = create_search_context(find_text);
        return context.replace_all(replace_text, -1);
    }

    private GtkSource.SearchContext create_search_context(string find_text) {
        var search_settings = new GtkSource.SearchSettings();
        search_settings.set_case_sensitive(false);
        search_settings.set_regex_enabled(false);
        search_settings.set_wrap_around(true);
        search_settings.set_search_text(find_text);
        return new GtkSource.SearchContext(editor_buffer, search_settings);
    }

    private bool find_match(GtkSource.SearchContext context,
                            out Gtk.TextIter match_start,
                            out Gtk.TextIter match_end) {
        bool has_wrapped = false;
        Gtk.TextIter start_from;
        if (editor_buffer.get_has_selection()) {
            Gtk.TextIter sel_start;
            Gtk.TextIter sel_end;
            editor_buffer.get_selection_bounds(out sel_start, out sel_end);
            start_from = sel_end;
        } else {
            editor_buffer.get_iter_at_mark(out start_from, editor_buffer.get_insert());
        }
        return context.forward(start_from, out match_start, out match_end, out has_wrapped);
    }
}

}
