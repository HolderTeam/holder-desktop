namespace HolderLinux {

public class GtkSingleSelectionState : Object, ISelectionState {
    private Gtk.SingleSelection selection;

    public GtkSingleSelectionState(Gtk.SingleSelection selection) {
        this.selection = selection;
    }

    public Object? get_selected_item() {
        return selection.get_selected_item();
    }

    public uint get_selected_index() {
        return selection.get_selected();
    }

    public void set_selected_index(uint index) {
        selection.set_selected(index);
    }
}

public class SearchEntryTextProvider : Object, ITextProvider {
    private Gtk.SearchEntry entry;

    public SearchEntryTextProvider(Gtk.SearchEntry entry) {
        this.entry = entry;
    }

    public string get_text() {
        return entry.get_text();
    }
}

public class SourceBufferTextProvider : Object, ITextProvider {
    private GtkSource.Buffer buffer;

    public SourceBufferTextProvider(GtkSource.Buffer buffer) {
        this.buffer = buffer;
    }

    public string get_text() {
        Gtk.TextIter start;
        Gtk.TextIter end;
        buffer.get_bounds(out start, out end);
        return buffer.get_text(start, end, false);
    }
}

}
