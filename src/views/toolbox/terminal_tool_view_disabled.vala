namespace HolderLinux {

public class TerminalToolView : Object, IToolShellAdapter {
    public Gtk.Widget widget { get; private set; }
    public string tool_id {
        owned get { return "terminals"; }
    }
    public string tool_label {
        owned get { return "Terminals"; }
    }

    public signal void debug_log_requested(string line);
    public signal void toast_requested(string message);
    public signal void copy_to_card_requested(string text);

    public TerminalToolView() {
        widget = build_disabled_view();
    }

    public Gtk.Widget? get_actions_widget() {
        return null;
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

    private Gtk.Widget build_disabled_view() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        box.set_margin_top(24);
        box.set_margin_bottom(24);
        box.set_margin_start(24);
        box.set_margin_end(24);
        box.set_vexpand(true);
        box.set_hexpand(true);

        var title = new Gtk.Label("Terminal is not available on Windows yet");
        title.add_css_class("title-4");
        title.set_halign(Gtk.Align.START);

        var detail = new Gtk.Label("The Windows terminal tool will need a ConPTY backend.");
        detail.add_css_class("dim-label");
        detail.set_halign(Gtk.Align.START);

        box.append(title);
        box.append(detail);
        return box;
    }
}

}
