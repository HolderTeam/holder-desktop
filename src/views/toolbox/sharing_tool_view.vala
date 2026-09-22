namespace HolderLinux {

public class SharingToolView : Object, IToolShellAdapter {
    private Gtk.Button email_btn; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer

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
