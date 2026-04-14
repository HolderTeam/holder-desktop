namespace HolderLinux {

internal class PrintUiController : Object {
    private PrintService print_service;

    public signal void toast_requested(string message);
    public signal void error_reported(string title, string details);

    public PrintUiController(PrintService print_service) {
        this.print_service = print_service;
    }

    public async void print_text(Gtk.Window parent, string text) {
        try {
            yield print_service.print_text(parent, text);
        } catch (Error e) {
            if (e.message == "Nothing to print.") {
                toast_requested("Nothing to print.");
                return;
            }
            error_reported("Print failed", e.message);
        }
    }
}

}
