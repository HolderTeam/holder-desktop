namespace HolderLinux {

public class RecoveryKeyToolView : Object, IToolShellAdapter {
    public Gtk.Widget widget { get; private set; }
    public string tool_id {
        owned get { return "recovery"; }
    }
    public string tool_label {
        owned get { return "Recovery Key"; }
    }

    public signal void send_recovery_key_as_email_requested();
    public signal void save_recovery_key_to_usb_requested();
    public signal void import_recovery_key_requested();

    public RecoveryKeyToolView() {
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

    private Gtk.Widget build_ui() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);

        var info = new Gtk.Label(
            "Keep a copy of your recovery key somewhere safe in case your computer is lost or damaged. " +
            "Email it to yourself, or store it on a USB stick."
        ) { xalign = 0.0f };
        info.set_wrap(true);
        info.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        info.add_css_class("dim-label");
        root.append(info);

        var email_btn = new Gtk.Button.with_label("Email Recovery Key");
        email_btn.set_halign(Gtk.Align.START);
        email_btn.clicked.connect(() => {
            send_recovery_key_as_email_requested();
        });
        root.append(email_btn);

        var usb_btn = new Gtk.Button.with_label("Save Recovery Key to USB Drive");
        usb_btn.set_halign(Gtk.Align.START);
        usb_btn.clicked.connect(() => {
            save_recovery_key_to_usb_requested();
        });
        root.append(usb_btn);

        var import_btn = new Gtk.Button.with_label("Import Recovery Key");
        import_btn.set_halign(Gtk.Align.START);
        import_btn.clicked.connect(() => {
            import_recovery_key_requested();
        });
        root.append(import_btn);

        return root;
    }
}

}
