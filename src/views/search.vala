namespace HolderLinux {

public class SearchEntryTextProvider : Object, ITextProvider {
    private Gtk.SearchEntry entry;

    public SearchEntryTextProvider(Gtk.SearchEntry entry) {
        this.entry = entry;
    }

    public string get_text() {
        return entry.get_text();
    }
}

}
