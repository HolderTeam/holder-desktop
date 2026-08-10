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
        if (index == Gtk.INVALID_LIST_POSITION) {
            selection.set_autoselect(false);
            selection.set_can_unselect(true);
            selection.unselect_item(selection.get_selected());
            return;
        }
        selection.set_selected(index);
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
