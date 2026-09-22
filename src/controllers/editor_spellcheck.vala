namespace HolderLinux {

// What the preferences dialog needs from spell checking, so it can be tested without a spelling
// backend on the machine.
public interface IEditorSpellcheckPreference : Object {
    public abstract bool requested_enabled { get; }
    public abstract bool buffer_safe { get; }
    public abstract bool backend_available { get; }
    public abstract void set_enabled_preference(bool enabled);
}

public class EditorSpellcheckController : Object, IEditorSpellcheckPreference {
    private GtkSource.Buffer buffer;
    private GtkSource.View view;
    private Spelling.Checker? checker;

    public Spelling.TextBufferAdapter? adapter { get; private set; }
    private bool requested_enabled_value = true;
    private bool buffer_safe_value = true;
    public bool requested_enabled {
        get { return requested_enabled_value; }
    }
    public bool buffer_safe {
        get { return buffer_safe_value; }
    }
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
        requested_enabled_value = enabled;
        if (adapter != null) {
            adapter.set_enabled(enabled);
        }
    }

    public void prepare_buffer_mutation() {
        retire_adapter();
    }

    public void finish_buffer_mutation(bool has_inline_images) {
        buffer_safe_value = !has_inline_images;
        if (buffer_safe_value) {
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
        if (!buffer_safe_value || checker == null || adapter != null) {
            return;
        }
        var restored = new Spelling.TextBufferAdapter(buffer, (!) checker);
        restored.set_enabled(requested_enabled_value);
        adapter = restored;
        view.insert_action_group("spelling", restored);
        view.set_extra_menu(restored.get_menu_model());
    }
}

}
