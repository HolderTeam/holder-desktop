namespace HolderLinux {

// Lets a view ask the user for a file or folder without owning the GTK dialog, so tests can answer
// (or cancel) without a real file chooser. A cancelled choice throws IOError.CANCELLED, as
// Gtk.FileDialog does.
public interface IFilePicker : Object {
    public abstract async File? pick_folder(Gtk.Window parent, string title) throws Error;
    public abstract async File? pick_file(Gtk.Window parent, string title, bool images_only) throws Error;
}

// LCOV_EXCL_START
// GCOVR_EXCL_START
// Thin Gtk.FileDialog shim: it needs a real, presented file chooser, so it is not unit-testable.
internal class GtkFilePicker : Object, IFilePicker {
    public async File? pick_folder(Gtk.Window parent, string title) throws Error {
        var dialog = new Gtk.FileDialog();
        dialog.set_title(title);
        return yield dialog.select_folder(parent, null);
    }

    public async File? pick_file(Gtk.Window parent, string title, bool images_only) throws Error {
        var dialog = new Gtk.FileDialog();
        dialog.set_title(title);
        if (images_only) {
            var image_filter = new Gtk.FileFilter();
            image_filter.add_mime_type("image/*");
            var filters = new GLib.ListStore(typeof(Gtk.FileFilter));
            filters.append(image_filter);
            dialog.set_filters(filters);
            dialog.set_default_filter(image_filter);
        }
        return yield dialog.open(parent, null);
    }
}
// GCOVR_EXCL_STOP
// LCOV_EXCL_STOP

}
