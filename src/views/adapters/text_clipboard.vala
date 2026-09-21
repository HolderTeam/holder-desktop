namespace HolderLinux {

// Lets a view put text on the clipboard without owning the display, so tests can record what was
// copied (or simulate a session with no clipboard).
public interface ITextClipboard : Object {
    // Returns false when no clipboard is available, for example when there is no display.
    public abstract bool set_text(string text);
}

// LCOV_EXCL_START
// GCOVR_EXCL_START
// Thin Gdk clipboard shim: it needs a real display, so it is not unit-testable.
internal class GtkTextClipboard : Object, ITextClipboard {
    public bool set_text(string text) {
        var display = Gdk.Display.get_default();
        if (display == null) {
            return false;
        }
        display.get_clipboard().set_text(text);
        return true;
    }
}
// GCOVR_EXCL_STOP
// LCOV_EXCL_STOP

}
