namespace HolderLinux {

public class SharingToolView : Object, IToolShellAdapter {
    private Gtk.Button email_btn;

    public Gtk.Widget widget { get; private set; }
    public string tool_id {
        owned get { return "sharing"; }
    }
    public string tool_label {
        owned get { return "Sharing"; }
    }

    public signal void send_card_as_email_requested();

    public SharingToolView() {
        widget = build_ui();
    }

    public Gtk.Widget get_content_widget() {
        return widget;
    }

    public Gtk.Widget? get_actions_widget() {
        return null;
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

    public void set_has_selected_card(bool has_selected_card) {
        if (email_btn != null) {
            email_btn.set_sensitive(has_selected_card);
        }
    }

    private Gtk.Widget build_ui() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);

        var info = new Gtk.Label(
            "Share the currently selected card using desktop integrations."
        ) { xalign = 0.0f };
        info.set_wrap(true);
        info.add_css_class("dim-label");
        root.append(info);

        email_btn = new Gtk.Button.with_label("Send card as email");
        email_btn.set_halign(Gtk.Align.START);
        email_btn.clicked.connect(() => {
            send_card_as_email_requested();
        });
        root.append(email_btn);

        return root;
    }
}

}
