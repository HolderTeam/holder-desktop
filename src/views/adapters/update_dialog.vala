namespace HolderLinux {

internal delegate void UpdatePromptHandledFunc(UpdateCandidate candidate);

internal class UpdateDialogAdapter : Object {
    private Gtk.Window parent;
    private IUriLauncher uri_launcher;

    public UpdateDialogAdapter(Gtk.Window parent, IUriLauncher? uri_launcher = null) {
        this.parent = parent;
        this.uri_launcher = uri_launcher ?? new AppInfoUriLauncher();
    }

    public void show(UpdateCandidate candidate, string current_version, UpdatePromptHandledFunc on_handled) {
        var body = "%s\n\nHolder %s is available. You are running %s.".printf(
            candidate.message,
            candidate.version,
            current_version
        );
        var dialog = new Adw.MessageDialog(parent, "Update Available", body);
        dialog.add_response("later", "Later");
        dialog.add_response("download", "Download");
        dialog.set_response_appearance("download", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("download");
        dialog.set_close_response("later");
        dialog.response.connect((response) => {
            on_handled(candidate);
            if (response != "download") {
                return;
            }
            try {
                uri_launcher.launch(candidate.download_url);
            } catch (Error e) {
                warning("Failed to open update URL: %s", e.message);
            }
        });
        dialog.present();
    }
}

}
