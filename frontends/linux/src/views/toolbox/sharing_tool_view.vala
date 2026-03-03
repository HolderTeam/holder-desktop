namespace HolderLinux {

public class SharingToolView : Object {
    private Gtk.Button email_btn;

    public Gtk.Widget widget { get; private set; }

    public signal void send_card_as_email_requested();

    public SharingToolView() {
        widget = build_ui();
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
