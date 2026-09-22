namespace HolderLinux {

// The recovery dialog only needs these operations from the recovery UI flow.
// Keeping this contract separate lets the adapter remain independently testable.
internal interface IRecoveryDialogOps : Object {
    public abstract bool validate_pin(string pin);
    public abstract string? load_import_payload_from_path(string? path);
    public abstract string import_summary_body(RecoveryTokenImportResult result);
}

internal class RecoveryDialogPin : Object {
    public static string normalize(string pin) {
        return pin.strip();
    }

    public static bool is_submittable(string pin) {
        return normalize(pin).length > 0;
    }
}

}
