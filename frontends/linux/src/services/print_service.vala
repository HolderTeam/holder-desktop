namespace HolderLinux {

public class PrintService : Object {
    public async void print_text(Gtk.Window? parent, string text) throws Error {
        if (text == null || text.strip().length == 0) {
            throw new IOError.FAILED("Nothing to print.");
        }

        string tmp_dir;
        try {
            tmp_dir = make_temp_dir();
        } catch (Error e) {
            throw new IOError.FAILED(
                "Could not create temporary print directory: %s".printf(e.message)
            );
        }

        var tmp_path = Path.build_filename(tmp_dir, "card.txt");
        try {
            write_file(tmp_path, text);
        } catch (Error e) {
            cleanup(tmp_path, tmp_dir);
            throw new IOError.FAILED("Could not prepare print file: %s".printf(e.message));
        }

        try {
            yield run_print_dialog(parent, tmp_path);
        } finally {
            cleanup(tmp_path, tmp_dir);
        }
    }

    protected virtual string make_temp_dir() throws Error {
        try {
            return DirUtils.make_tmp("holder-print-XXXXXX");
        } catch (FileError e) {
            throw new IOError.FAILED(e.message);
        }
    }

    protected virtual void write_file(string path, string text) throws Error {
        try {
            FileUtils.set_contents(path, text);
        } catch (FileError e) {
            throw new IOError.FAILED(e.message);
        }
    }

    protected virtual async void run_print_dialog(Gtk.Window? parent, string path) throws Error {
        var dialog = new Gtk.PrintDialog();
        dialog.set_title("Print");
        yield dialog.print_file(parent, null, File.new_for_path(path), null);
    }

    protected virtual void cleanup(string path, string dir) {
        FileUtils.remove(path);
        DirUtils.remove(dir);
    }
}

}
