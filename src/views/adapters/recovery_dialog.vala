namespace HolderLinux {

public delegate void RecoveryPinAccepted(string pin);
public delegate void RecoveryImportReady(string pin, string recovery_token);
// The path is null when the chosen location is not a local file; the receiver reports that.
public delegate void RecoverySavePathReady(string? path);

internal class RecoveryDialogAdapter : Object {
    private Gtk.Window parent;
    private RecoveryUiController recovery_ui_controller;
    private IFilePicker file_picker;

    public signal void error_reported(string title, string details);

    public RecoveryDialogAdapter(Gtk.Window parent,
                                 RecoveryUiController recovery_ui_controller,
                                 IFilePicker? file_picker = null) {
        this.parent = parent;
        this.recovery_ui_controller = recovery_ui_controller;
        this.file_picker = file_picker ?? new GtkFilePicker();
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
            dialog.set_response_enabled("continue", RecoveryUiController.pin_is_submittable(pin_entry.get_text()));
        });

        dialog.response.connect((response) => {
            if (response != "continue") {
                return;
            }
            var pin = RecoveryUiController.normalize_pin(pin_entry.get_text());
            if (!recovery_ui_controller.validate_pin(pin)) {
                return;
            }
            on_pin(pin);
        });
        dialog.present(parent);
    }

    public void open_import_dialog(owned RecoveryImportReady on_import_ready) {
        choose_import_file.begin((owned) on_import_ready);
    }

    private async void choose_import_file(owned RecoveryImportReady on_import_ready) {
        try {
            var file = yield file_picker.pick_file(parent, "Import Recovery Key", false);
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
    }

    public void open_save_dialog(string default_filename, owned RecoverySavePathReady on_save_path_ready) {
        choose_save_file.begin(default_filename, (owned) on_save_path_ready);
    }

    private async void choose_save_file(string default_filename,
                                        owned RecoverySavePathReady on_save_path_ready) {
        try {
            var file = yield file_picker.save_file(parent, "Save Recovery Key", default_filename);
            if (file == null) {
                return;
            }
            // A location that is not a local file has no path; the receiver tells the user so, the
            // same way importing does, instead of the choice silently doing nothing.
            on_save_path_ready(file.get_path());
        } catch (IOError.CANCELLED e) {
            // User cancelled.
        } catch (Error e) {
            error_reported("Recovery key export failed", e.message);
        }
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
