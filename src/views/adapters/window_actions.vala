namespace HolderLinux {

internal class WindowActionsAdapter : Object {
    private Gtk.Window parent;

    public WindowActionsAdapter(Gtk.Window parent) {
        this.parent = parent;
    }

    public void show_preferences(GtkSource.Buffer editor_buffer,
                                 GtkSource.View editor_view,
                                 Spelling.TextBufferAdapter? spelling_adapter,
                                 Settings? settings) {
        var dialog = new PreferencesDialog(editor_buffer, editor_view, spelling_adapter, settings);
        dialog.present(parent);
    }

    public void show_about() {
        var dialog = new Adw.MessageDialog(
            parent,
            "Holder 0.1.0",
            "Holder desktop frontend"
        );
        dialog.add_response("close", "Close");
        dialog.set_default_response("close");
        dialog.set_close_response("close");

        var logo = new Gtk.Picture.for_resource("/team/holder/Holder/assets/holder.jpg");
        logo.set_can_shrink(true);
        logo.set_content_fit(Gtk.ContentFit.CONTAIN);
        logo.set_size_request(220, 220);

        var link = new Gtk.LinkButton.with_label(
            "https://github.com/HolderTeam",
            "github.com/HolderTeam"
        );
        link.set_halign(Gtk.Align.CENTER);

        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
        content.append(logo);
        content.append(link);
        dialog.set_extra_child(content);
        dialog.present();
    }
}

}
