namespace HolderLinux {

internal class SearchSelectionController : Object {
    private GLib.ListStore search_store;

    public SearchSelectionController(GLib.ListStore search_store) {
        this.search_store = search_store;
    }

    public uint position_for_request(int position) {
        if (position < 0) {
            return Gtk.INVALID_LIST_POSITION;
        }

        var target = (uint) position;
        if (target >= search_store.get_n_items()) {
            return Gtk.INVALID_LIST_POSITION;
        }

        return target;
    }
}

}
