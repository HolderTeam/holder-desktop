namespace HolderLinux {

internal interface IFindReplaceOps : Object {
    public abstract bool find_next(string find_text);
    public abstract bool replace_next(string find_text, string replace_text) throws Error;
    public abstract uint replace_all(string find_text, string replace_text) throws Error;
}

internal class FindReplaceController : Object {
    private IFindReplaceOps ops;

    public signal void toast_requested(string message);
    public signal void error_reported(string title, string details);

    public FindReplaceController(IFindReplaceOps ops) {
        this.ops = ops;
    }

    public void on_find_next_requested(string find_text) {
        var needle = find_text.strip();
        if (needle.length == 0) {
            toast_requested("Enter text to find.");
            return;
        }
        if (!ops.find_next(needle)) {
            toast_requested("No match found.");
        }
    }

    public void on_replace_requested(string find_text, string replace_text) {
        var needle = find_text.strip();
        if (needle.length == 0) {
            toast_requested("Enter text to find.");
            return;
        }
        try {
            if (!ops.replace_next(needle, replace_text)) {
                toast_requested("No match found.");
                return;
            }
            toast_requested("Replaced one match.");
            ops.find_next(needle);
        } catch (Error e) {
            error_reported("Replace failed", e.message);
        }
    }

    public void on_replace_all_requested(string find_text, string replace_text) {
        var needle = find_text.strip();
        if (needle.length == 0) {
            toast_requested("Enter text to find.");
            return;
        }
        try {
            var replaced = ops.replace_all(needle, replace_text);
            toast_requested("Replaced %u matches.".printf(replaced));
        } catch (Error e) {
            error_reported("Replace all failed", e.message);
        }
    }
}

}
