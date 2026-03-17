namespace HolderLinux {

public class DebugToolView : Object, IToolShellAdapter {
    private Gtk.Box debug_actions_bar;
    private Gtk.Button clear_btn;
    private Gtk.TextBuffer debug_buffer;
    private Gtk.TextView debug_view;
    private ActivityLogStore? activity_log_store;

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
        var project_id = selected_project != null ? selected_project.project_id : null;
        var project_label = selected_project != null ? selected_project.name : "(none)";
        var card_id = selected_card != null ? selected_card.card_id : null;
        var card_label = selected_card != null ? selected_card.title : "Overview";

        ToolScopeMode scope_mode = selected_card != null
            ? ToolScopeMode.CARD_FOCUS
            : ToolScopeMode.PROJECT_ROOT;
        if (project_id == null) {
            scope_mode = ToolScopeMode.PROJECTS_ROOT;
            project_label = "Projects";
            card_id = null;
            card_label = "Overview";
        }

        return new ToolScopeSnapshot(
            tool_id,
            tool_label,
            project_id,
            project_label,
            card_id,
            card_label,
            scope_mode,
            false
        );
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
        activity_log_store = store;
        foreach (var entry in store.snapshot()) {
            append_activity_entry(entry);
        }
        store.entry_added.connect((entry) => {
            append_activity_entry(entry);
        });
        store.cleared.connect(() => {
            debug_buffer.set_text("", -1);
        });
    }

    private void append_activity_entry(ActivityLogEntry entry) {
        var scope = build_scope_suffix(entry);
        append_log_line("ACTIVITY %s %s%s".printf(
            entry.kind,
            entry.message,
            scope
        ));
    }

    private static string build_scope_suffix(ActivityLogEntry entry) {
        var parts = new Gee.ArrayList<string>();
        if (entry.project_id != null && entry.project_id.strip().length > 0) {
            parts.add("project=%s".printf((!) entry.project_id));
        }
        if (entry.card_id != null && entry.card_id.strip().length > 0) {
            parts.add("card=%s".printf((!) entry.card_id));
        }
        if (parts.size == 0) {
            return "";
        }
        return " [%s]".printf(string.joinv(", ", parts.to_array()));
    }

    private Gtk.Widget build_ui() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        debug_actions_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        debug_actions_bar.set_hexpand(true);
        debug_buffer = new Gtk.TextBuffer(null);
        debug_view = new Gtk.TextView.with_buffer(debug_buffer);
        debug_view.set_editable(false);
        debug_view.set_monospace(true);
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
