namespace HolderLinux {

public delegate void ProjectCreateRequested(string raw_name, bool is_private_mode);

internal class ProjectCreateDialogAdapter : Object {
    private Gtk.Window parent;

    public ProjectCreateDialogAdapter(Gtk.Window parent) {
        this.parent = parent;
    }

    public void show(owned ProjectCreateRequested on_create_requested) {
        var dialog = new Adw.AlertDialog(
            "New Project",
            "Enter a project name."
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("create", "Create");
        dialog.set_response_appearance("create", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("create");
        dialog.set_close_response("cancel");

        var entry = new Gtk.Entry();
        entry.set_placeholder_text("Project name");
        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        content.append(entry);

        var chooser_label = new Gtk.Label("Choose project visibility");
        chooser_label.set_halign(Gtk.Align.CENTER);
        content.append(chooser_label);

        var privacy_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        privacy_row.set_halign(Gtk.Align.CENTER);
        var private_btn = new Gtk.CheckButton.with_label("Private");
        var shared_btn = new Gtk.CheckButton.with_label("Shared");
        shared_btn.set_group(private_btn);
        private_btn.set_active(true);
        privacy_row.append(private_btn);
        privacy_row.append(shared_btn);
        content.append(privacy_row);

        var help = new Gtk.Label(
            "A private project is encrypted, only you can read it.\n\n" +
            "A shared project is useful for collaboration. You must be very careful not store sensitive information (passwords, personal data, private notes)."
        );
        help.set_xalign(0.0f);
        help.set_wrap(true);
        help.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        help.add_css_class("dim-label");
        content.append(help);

        dialog.set_extra_child(content);

        dialog.response.connect((response) => {
            if (response == "create") {
                on_create_requested(entry.get_text(), private_btn.get_active());
            }
        });

        dialog.present(parent);
    }
}

}
