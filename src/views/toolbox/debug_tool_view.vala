namespace HolderLinux {

public class DebugToolView : Object, IToolShellAdapter {

    private Gtk.Box debug_actions_bar; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Button clear_btn; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.TextBuffer debug_buffer; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.TextView debug_view; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private ActivityLogStore? activity_log_store; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private ulong cleared_handler_id = 0;

    public Gtk.Widget widget { get; private set; }
    public string tool_id {
        owned get { return "debug"; }
    }
    public string tool_label {
        owned get { return "Debug"; }
    }

    public DebugToolView() {
        widget = build_ui();
    }

    public Gtk.Widget? get_actions_widget() {
        return debug_actions_bar;
    }

    public Gtk.Widget get_content_widget() {
        return widget;
    }

    public ToolScopeSnapshot get_scope_snapshot(Project? selected_project, CardSummary? selected_card) {
        return ToolScopePresenter.snapshot(tool_id, tool_label, selected_project, selected_card);
    }

    public async bool navigate_to_projects_root(string? selected_project_id) {
        return true;
    }

    public async bool navigate_to_project_root(string project_id) {
        return true;
    }

    public async bool navigate_to_card(string card_id) {
        return true;
    }

    public void append_log_line(string line) {
        Gtk.TextIter end;
        debug_buffer.get_end_iter(out end);
        var stamp = new DateTime.now_local().format("%H:%M:%S");
        debug_buffer.insert(ref end, "[%s] %s\n".printf(stamp, line), -1);
        if (debug_view != null) {
            Idle.add(() => {
                Gtk.TextIter latest_end;
                debug_buffer.get_end_iter(out latest_end);
                debug_buffer.place_cursor(latest_end);
                debug_view.scroll_to_iter(latest_end, 0.0, false, 0.0, 1.0);
                return Source.REMOVE;
            });
        }
    }

    public void bind_activity_log(ActivityLogStore store) {
        // Only the store bound now may clear the view; the previous one is let go.
        if (activity_log_store != null && cleared_handler_id != 0) {
            ((!) activity_log_store).disconnect(cleared_handler_id);
        }
        activity_log_store = store;
        cleared_handler_id = store.cleared.connect(() => {
            debug_buffer.set_text("", -1);
        });
    }

    private Gtk.Widget build_ui() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        debug_actions_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        debug_actions_bar.set_hexpand(true);
        debug_buffer = new Gtk.TextBuffer(null);
        debug_view = new Gtk.TextView.with_buffer(debug_buffer);
        debug_view.set_editable(false);
        WindowsMonospace.apply(debug_view);
        debug_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        debug_view.set_vexpand(true);

        clear_btn = new Gtk.Button.with_label("Clear");
        clear_btn.clicked.connect(() => {
            if (activity_log_store != null) {
                ((!) activity_log_store).clear();
                return;
            }
            debug_buffer.set_text("", -1);
        });
        debug_actions_bar.append(clear_btn);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_vexpand(true);
        scroll.set_child(debug_view);
        box.append(scroll);
        return box;
    }
}

}
