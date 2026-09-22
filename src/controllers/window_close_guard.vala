namespace HolderLinux {

public interface IWindowCloseHost : Object {
    public abstract bool has_unsaved_editor_changes();
    public abstract bool is_editor_save_in_flight();
    public abstract bool save_emergency_recovery_draft() throws Error;
    public abstract async bool save_now();
}

public enum WindowCloseDecision {
    ALLOW,
    BLOCK
}

public enum WindowCloseDialogOutcome {
    KEEP_EDITING,
    RETRY,
    QUIT
}

// Protects unsaved edits when the window is asked to close: writes an emergency recovery
// copy, races a normal save against a timeout, and either lets the close finish or asks the
// view to show the "not safely stored" dialog. The view owns close() and the dialog.
public class WindowCloseGuard : Object {
    public const uint SAVE_TIMEOUT_MS = 2000;
    public const string TIMEOUT_DETAILS =
        "The backend did not finish saving and local recovery files are disabled.";
    public const string SAVE_FAILED_DETAILS =
        "The backend did not save this card and local recovery files are disabled.";
    public const string UNSAFE_DIALOG_TITLE = "This card is not safely stored yet";

    private IWindowCloseHost host; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private IScheduler scheduler; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private bool in_progress = false;
    private bool authorized = false;
    private uint timeout_id = 0;
    private bool has_recovery_copy = false;
    private string? recovery_error = null; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private bool decision_visible = false;

    public signal void close_ready();
    public signal void unsafe_close_detected(string details);

    public WindowCloseGuard(IWindowCloseHost host, IScheduler scheduler) {
        this.host = host;
        this.scheduler = scheduler;
    }

    public static string unsafe_dialog_body(string details) {
        return "%s\n\nRetry saving, keep Holder open, or quit and discard the unsaved changes."
            .printf(details);
    }

    public WindowCloseDecision request_close() {
        if (authorized) {
            return WindowCloseDecision.ALLOW;
        }
        if (!host.has_unsaved_editor_changes() && !host.is_editor_save_in_flight()) {
            return WindowCloseDecision.ALLOW;
        }
        if (in_progress) {
            return WindowCloseDecision.BLOCK;
        }

        in_progress = true;
        has_recovery_copy = false;
        recovery_error = null;
        try {
            has_recovery_copy = host.save_emergency_recovery_draft();
        } catch (Error e) {
            recovery_error = e.message;
        }

        timeout_id = scheduler.schedule_once(SAVE_TIMEOUT_MS, () => {
            timeout_id = 0;
            if ((!host.has_unsaved_editor_changes() && !host.is_editor_save_in_flight())
                || has_recovery_copy) {
                finish();
            } else {
                show_unsafe(recovery_error ?? TIMEOUT_DETAILS);
            }
            return Source.REMOVE;
        });
        host.save_now.begin((obj, result) => {
            bool saved = host.save_now.end(result);
            if (!in_progress) {
                return;
            }
            if (saved) {
                finish();
                return;
            }
            if (host.is_editor_save_in_flight()) {
                return;
            }
            if (has_recovery_copy) {
                finish();
                return;
            }
            show_unsafe(recovery_error ?? SAVE_FAILED_DETAILS);
        });
        return WindowCloseDecision.BLOCK;
    }

    public void on_editor_save_settled(bool saved) {
        if (!in_progress || host.is_editor_save_in_flight()) {
            return;
        }
        if (saved && !host.has_unsaved_editor_changes()) {
            finish();
        } else if (has_recovery_copy) {
            finish();
        } else {
            show_unsafe(recovery_error ?? SAVE_FAILED_DETAILS);
        }
    }

    public WindowCloseDialogOutcome resolve_unsafe_dialog(string response) {
        decision_visible = false;
        cancel();
        if (response == "retry") {
            return WindowCloseDialogOutcome.RETRY;
        }
        if (response == "quit") {
            authorized = true;
            return WindowCloseDialogOutcome.QUIT;
        }
        return WindowCloseDialogOutcome.KEEP_EDITING;
    }

    private void clear_timeout() {
        if (timeout_id != 0) {
            scheduler.cancel(timeout_id);
            timeout_id = 0;
        }
    }

    private void finish() {
        clear_timeout();
        in_progress = false;
        authorized = true;
        close_ready();
    }

    private void cancel() {
        clear_timeout();
        in_progress = false;
        has_recovery_copy = false;
        recovery_error = null;
        decision_visible = false;
    }

    private void show_unsafe(string details) {
        if (decision_visible) {
            return;
        }
        decision_visible = true;
        clear_timeout();
        unsafe_close_detected(details);
    }
}

}
