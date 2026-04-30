namespace HolderLinux {

internal class CardAppendController : Object {
    public signal void toast_requested(string message);

    public string? build_append_suffix(bool has_selected_card, string existing_text, string? extra_text) {
        if (!has_selected_card) {
            toast_requested("Select a card first.");
            return null;
        }
        if (extra_text == null || extra_text.length == 0) {
            toast_requested("Nothing to copy.");
            return null;
        }

        var needs_gap = existing_text.length > 0 && !existing_text.has_suffix("\n");
        var prefix = needs_gap ? "\n\n" : "\n";
        toast_requested("Copied terminal output into card.");
        return "%s%s".printf(prefix, extra_text);
    }
}

}
