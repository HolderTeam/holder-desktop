namespace HolderLinux {

public class EditorSpellcheckController : Object {
    private GtkSource.Buffer buffer;
    private GtkSource.View view;
    private Spelling.Checker? checker;

    public Spelling.TextBufferAdapter? adapter { get; private set; }
    public bool requested_enabled { get; private set; default = true; }
    public bool buffer_safe { get; private set; default = true; }
    public bool backend_available {
        get { return checker != null; }
    }

    public EditorSpellcheckController(GtkSource.Buffer buffer, GtkSource.View view) {
        this.buffer = buffer;
        this.view = view;
        Spelling.init();
        checker = Spelling.Checker.get_default();
        restore_adapter_if_safe();
    }

    public void set_enabled_preference(bool enabled) {
        requested_enabled = enabled;
        if (adapter != null) {
            adapter.set_enabled(enabled);
        }
    }

    public void prepare_buffer_mutation() {
        retire_adapter();
    }

    public void finish_buffer_mutation(bool has_inline_images) {
        buffer_safe = !has_inline_images;
        if (buffer_safe) {
            restore_adapter_if_safe();
        } else {
            retire_adapter();
        }
    }

    private void retire_adapter() {
        if (adapter == null) {
            return;
        }
        var retiring = (!) adapter;
        retiring.set_enabled(false);
        view.insert_action_group("spelling", null);
        view.set_extra_menu(null);
        adapter = null;
    }

    private void restore_adapter_if_safe() {
        if (!buffer_safe || checker == null || adapter != null) {
            return;
        }
        var restored = new Spelling.TextBufferAdapter(buffer, (!) checker);
        restored.set_enabled(requested_enabled);
        adapter = restored;
        view.insert_action_group("spelling", restored);
        view.set_extra_menu(restored.get_menu_model());
    }
}

}
