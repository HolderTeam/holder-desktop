namespace HolderLinux {

internal class WindowEditorRenderer : Object {
    private class RenderState : Object {
        public string text = "";
        public bool editable = false;
        public bool show_search = false;
        public string window_title = "Holder";
        public string save_state = "";
        public string search_summary = "";
        public string? ai_thread_title = null;
    }

    private Gtk.Window window;
    private WorkspacePane workspace;
    private Gtk.Label search_summary_label;
    private AiPanel ai_panel;
    private RenderState state;

    public bool is_applying_content { get; private set; default = false; }

    public signal void content_rendered();

    public WindowEditorRenderer(Gtk.Window window,
                                WorkspacePane workspace,
                                Gtk.Label search_summary_label,
                                AiPanel ai_panel) {
        this.window = window;
        this.workspace = workspace;
        this.search_summary_label = search_summary_label;
        this.ai_panel = ai_panel;
        this.state = new RenderState();
    }

    public void apply() {
        apply_content();
        apply_chrome();
    }

    public void set_editor_state(string text, bool editable) {
        state.text = text;
        state.editable = editable;
        apply_content();
        apply_chrome();
    }

    public void update_window_title(string title_text) {
        state.window_title = title_text;
        apply_chrome();
    }

    public void set_save_state_text(string text) {
        state.save_state = text;
        apply_chrome();
    }

    public void set_search_summary_text(string text) {
        state.search_summary = text;
        apply_chrome();
    }

    public void set_ai_thread_title(string? title_text) {
        state.ai_thread_title = title_text;
        apply_chrome();
    }

    public void show_editor_mode() {
        state.show_search = false;
        apply_chrome();
    }

    public void show_search_mode() {
        state.show_search = true;
        apply_chrome();
    }

    private void apply_content() {
        is_applying_content = true;
        try {
            workspace.set_editor_state(state.text, state.editable);
        } finally {
            is_applying_content = false;
        }
        content_rendered();
    }

    private void apply_chrome() {
        workspace.set_window_title_text(state.window_title);
        workspace.set_save_state_text(state.save_state);
        window.set_title(state.window_title);
        search_summary_label.set_text(state.search_summary);
        ai_panel.set_thread_title(state.ai_thread_title);

        if (state.show_search) {
            workspace.show_search_mode();
        } else {
            workspace.show_editor_mode();
        }
    }
}

}
