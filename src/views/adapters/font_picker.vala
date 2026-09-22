namespace HolderLinux {

// Lets the preferences dialog ask the user for a font without owning the GTK dialog, so tests can
// answer (or cancel) without a real font chooser. A cancelled choice throws IOError.CANCELLED, as
// Gtk.FontDialog does.
public interface IFontPicker : Object {
    public abstract async Pango.FontDescription? pick_font(Gtk.Window? parent,
                                                           Pango.FontDescription initial) throws Error;
}

// LCOV_EXCL_START
// GCOVR_EXCL_START
// Thin Gtk.FontDialog shim: it needs a real, presented font chooser, so it is not unit-testable.
internal class GtkFontPicker : Object, IFontPicker {
    public async Pango.FontDescription? pick_font(Gtk.Window? parent,
                                                  Pango.FontDescription initial) throws Error {
        var font_dialog = new Gtk.FontDialog();
        font_dialog.set_title("Pick a Font");
        return yield font_dialog.choose_font(parent, initial, null);
    }
}
// GCOVR_EXCL_STOP
// LCOV_EXCL_STOP

}
