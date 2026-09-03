namespace HolderLinux {

public delegate void RecoveryPinAccepted(string pin);
public delegate void RecoveryImportReady(string pin, string recovery_token);
public delegate void RecoverySavePathReady(string path);

internal class RecoveryDialogAdapter : Object {
    private Gtk.Window parent;
    private RecoveryUiController recovery_ui_controller;

    public signal void error_reported(string title, string details);

    public RecoveryDialogAdapter(Gtk.Window parent, RecoveryUiController recovery_ui_controller) {
        this.parent = parent;
        this.recovery_ui_controller = recovery_ui_controller;
    }

    public void request_pin(string title, string body, owned RecoveryPinAccepted on_pin) {
        var dialog = new Adw.AlertDialog(title, body);
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("continue", "Continue");
        dialog.set_response_appearance("continue", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("continue");
        dialog.set_close_response("cancel");

        var pin_entry = new Gtk.Entry();
        pin_entry.set_placeholder_text("PIN");
        pin_entry.set_input_purpose(Gtk.InputPurpose.PASSWORD);
        pin_entry.set_visibility(false);
        pin_entry.set_activates_default(true);

        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        var pin_label = new Gtk.Label("PIN") { xalign = 0.0f };
        content.append(pin_label);
        content.append(pin_entry);
        dialog.set_extra_child(content);
        dialog.set_response_enabled("continue", false);
        pin_entry.changed.connect(() => {
            dialog.set_response_enabled("continue", pin_entry.get_text().strip().length > 0);
        });

        dialog.response.connect((response) => {
            if (response != "continue") {
                return;
            }
            var pin = pin_entry.get_text().strip();
            if (!recovery_ui_controller.validate_pin(pin)) {
                return;
            }
            on_pin(pin);
        });
        dialog.present(parent);
    }

    public void open_import_dialog(owned RecoveryImportReady on_import_ready) {
        var dialog = new Gtk.FileDialog();
        dialog.set_title("Import Recovery Key");
        dialog.open.begin(parent, null, (obj, res) => {
            try {
                var file = dialog.open.end(res);
                if (file == null) {
                    return;
                }
                var recovery_token = recovery_ui_controller.load_import_payload_from_path(file.get_path());
                if (recovery_token == null) {
                    return;
                }
                request_pin(
                    "Unlock Recovery Key",
                    "Set your recovery key PIN to unlock and import this `.hrk` file.",
                    (pin) => {
                        on_import_ready(pin, recovery_token);
                    }
                );
            } catch (IOError.CANCELLED e) {
                // User cancelled.
            } catch (Error e) {
                error_reported("Recovery key import failed", e.message);
            }
        });
    }

    public void open_save_dialog(string default_filename, owned RecoverySavePathReady on_save_path_ready) {
        var dialog = new Gtk.FileDialog();
        dialog.set_title("Save Recovery Key");
        dialog.set_initial_name(default_filename);
        dialog.save.begin(parent, null, (obj, res) => {
            try {
                var file = dialog.save.end(res);
                if (file == null) {
                    return;
                }
                var path = file.get_path();
                if (path == null || path.strip().length == 0) {
                    return;
                }
                on_save_path_ready(path);
            } catch (IOError.CANCELLED e) {
                // User cancelled.
            } catch (Error e) {
                error_reported("Recovery key export failed", e.message);
            }
        });
    }

    public void show_import_summary(RecoveryTokenImportResult result) {
        var dialog = new Adw.AlertDialog(
            "Recovery Key Imported",
            recovery_ui_controller.import_summary_body(result)
        );
        dialog.add_response("ok", "OK");
        dialog.set_default_response("ok");
        dialog.set_close_response("ok");
        dialog.present(parent);
    }
}

}
