namespace HolderLinux {

private class EditorSaveAttemptResult : Object {
    public bool durable_saved { get; construct; }
    public bool recovery_saved { get; construct; }

    public EditorSaveAttemptResult(bool durable_saved, bool recovery_saved) {
        Object(durable_saved: durable_saved, recovery_saved: recovery_saved);
    }
}

internal class EditorSaveController : Object {
    private const uint AUTOSAVE_DELAY_MS = 900;
    private const uint RECOVERY_SNAPSHOT_DELAY_MS = 250;
    // Duplicated for lightweight controller tests; AppSettings depends on Adwaita.
    private const string KEY_NO_PLAINTEXT_RECOVERY_FILES = "no-plaintext-recovery-files";
    private const string KEY_EXPLICIT_SAVE_COUNT = "explicit-save-count";

    private MainController owner; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IEditorRecoveryDraftService recovery_draft_service; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private uint autosave_id = 0;
    private uint autosave_retry_id = 0;
    private uint autosave_retry_attempts = 0;
    private uint recovery_snapshot_id = 0;
    private bool save_in_flight = false;
    private bool save_again_requested = false;
    private bool recovery_write_failure_reported = false;

    public EditorSaveController(MainController owner,
                                IEditorRecoveryDraftService? recovery_draft_service = null) {
        this.owner = owner;
        this.recovery_draft_service = recovery_draft_service ?? new EditorRecoveryDraftService();
    }

    public void schedule_autosave() {
        cancel_autosave_retry();
        if (autosave_id != 0) {
            owner.scheduler.cancel(autosave_id);
        }

        autosave_id = owner.scheduler.schedule_once(AUTOSAVE_DELAY_MS, () => {
            autosave_id = 0;
            autosave_current_card.begin();
            return Source.REMOVE;
        });
    }

    public async void autosave_current_card() {
        if (save_in_flight) {
            save_again_requested = true;
            return;
        }
        save_in_flight = true;
        var result = yield perform_save_current_card();
        save_in_flight = false;
        run_queued_save_if_needed();
        owner.editor_save_settled(result.durable_saved);
    }

    private async EditorSaveAttemptResult perform_save_current_card(
        bool recovery_already_saved = false
    ) {
        if (owner.current_card == null) {
            return new EditorSaveAttemptResult(true, false); // LCOV_EXCL_LINE: defensive race guard if selection changes after async save starts
        }

        var saving_card = owner.current_card;
        var previous_content = owner.editor_draft_state.committed_text;
        var raw_text = owner.editor_text.get_text();
        var text = trim_for_save(raw_text);
        if (!owner.editor_draft_state.has_unsaved_changes(saving_card, text)) {
            return new EditorSaveAttemptResult(true, false);
        }
        var recovery_saved = recovery_already_saved || save_local_recovery_draft(saving_card, raw_text);
        if (owner.api == null) {
            if (recovery_saved) {
                owner.status_changed("Backend unavailable, saved recovery draft locally");
            } else if (plaintext_recovery_enabled()) {
                owner.status_changed("Backend unavailable; no local recovery copy could be written");
            } else {
                owner.status_changed("Backend unavailable; recovery files are disabled");
            }
            set_editor_save_state("Unsaved");
            return new EditorSaveAttemptResult(false, recovery_saved);
        }
        var previous_title = saving_card.title;
        var saved_card_id = saving_card.card_id;
        var saved_project_id = saving_card.project_id;
        var title = TextUtils.title_from_content(text);
        var updated_at = owner.now_epoch_seconds();
        var doc_chars = text.char_count();
        var previous_doc_chars = previous_content.char_count();
        var delta_chars = doc_chars - previous_doc_chars;
        var body_text = body_text_from_content(text);
        var body_chars = body_text.char_count();
        var body_empty = body_text.strip().length == 0;
        var content_fingerprint = short_content_fingerprint(text);

        try {
            set_editor_save_state("Saving...");
            yield ((!) owner.api).update_card(saved_card_id, title, text, updated_at);
            note_confirmed_durable_save(
                saved_card_id,
                previous_title,
                title,
                text,
                updated_at,
                body_empty,
                doc_chars,
                body_chars,
                delta_chars,
                content_fingerprint
            );
            canonicalize_visible_editor_after_save(saved_card_id, text);
            yield refresh_validated_tag_occurrences(saved_card_id, text);
            return new EditorSaveAttemptResult(true, recovery_saved);
        } catch (Error e) {
            owner.emit_activity(
                "result.card.autosave_failed",
                "Autosave failed: %s".printf(e.message),
                saved_project_id,
                saved_card_id
            );
            var repeat_failure = autosave_retry_is_repeat_failure();
            var retry_delay_ms = owner.current_card != null
                && owner.current_card.card_id == saved_card_id
                ? note_autosave_retry_scheduled(saved_card_id)
                : 0;
            set_editor_save_state("Unsaved");
            if (retry_delay_ms == 0) {
                return new EditorSaveAttemptResult(false, recovery_saved);
            }
            if (repeat_failure) {
                owner.status_changed("Autosave failed, retrying in %u s".printf((retry_delay_ms + 999) / 1000));
                return new EditorSaveAttemptResult(false, recovery_saved);
            }
            owner.error_reported(
                "Autosave failed",
                "%s\n\nRetrying in %u s.".printf(e.message, (retry_delay_ms + 999) / 1000)
            );
            return new EditorSaveAttemptResult(false, recovery_saved);
        }
    }

    public async bool save_now() {
        cancel_scheduled_autosave();
        if (!has_unsaved_editor_changes()) {
            owner.toast_requested("Already saved — Holder saves as you type.");
            return true;
        }

        bool recovery_saved = false;
        try {
            recovery_saved = save_emergency_recovery_draft();
        } catch (Error e) {
            owner.error_reported(
                "Could not create a recovery copy",
                "%s\n\nHolder will still try to save through the backend.".printf(e.message)
            );
        }

        if (save_in_flight) {
            save_again_requested = true;
            owner.status_changed("Saving...");
            return false;
        }

        save_in_flight = true;
        var result = yield perform_save_current_card(recovery_saved);
        save_in_flight = false;
        run_queued_save_if_needed();
        owner.editor_save_settled(result.durable_saved);
        if (result.durable_saved) {
            note_explicit_save();
        } else if (result.recovery_saved) {
            owner.toast_requested("The backend did not respond; your recovery copy is safe on this device.");
        }
        return result.durable_saved;
    }

    public async void flush_before_navigation() {
        if (!has_unsaved_editor_changes() && !save_in_flight) {
            return;
        }

        try {
            save_emergency_recovery_draft();
        } catch (Error e) {
            report_recovery_write_failure_once(e);
        }
        autosave_current_card.begin();
        while (save_in_flight) {
            yield wait_for_save_progress();
        }
    }

    public bool save_emergency_recovery_draft() throws Error {
        if (owner.current_card == null || !has_unsaved_editor_changes() || !plaintext_recovery_enabled()) {
            return false;
        }
        recovery_draft_service.save_draft(draft_for_current_editor());
        recovery_write_failure_reported = false;
        return true;
    }

    public bool plaintext_recovery_enabled() {
        return owner.settings == null
            || !owner.settings.get_boolean(KEY_NO_PLAINTEXT_RECOVERY_FILES);
    }

    public bool is_save_in_flight() {
        return save_in_flight;
    }

    public EditorRecoveryDraft? recovery_draft_for_card(CardDetail card) throws Error {
        var draft = recovery_draft_service.load_draft(card.card_id);
        if (draft == null) {
            return null;
        }
        if (draft.content == card.content) {
            recovery_draft_service.remove_draft(card.card_id);
            return null;
        }
        return draft;
    }

    public void discard_recovery_draft(string card_id) throws Error {
        recovery_draft_service.remove_draft(card_id);
    }

    public void restore_recovery_draft(EditorRecoveryDraft draft) {
        if (owner.current_card == null || owner.current_card.card_id != draft.card_id) {
            return;
        }
        owner.editor_state_changed(draft.content, true);
        owner.editor_save_state_changed("Unsaved");
        schedule_recovery_snapshot();
        schedule_autosave();
    }

    public bool has_unsaved_editor_changes() {
        return owner.editor_draft_state.has_unsaved_changes(
            owner.current_card,
            trim_for_save(owner.editor_text.get_text())
        );
    }

    // Key names are duplicated from AppSettings.KEY_PRESERVE_TRAILING_WHITESPACE/
    // KEY_TRIM_TWO_SPACE_HARD_BREAKS/KEY_TRIM_WHITESPACE_IN_CODE_BLOCKS (team.holder.Holder
    // .gschema.xml) rather than referencing that class -- AppSettings also carries
    // Adw.ColorScheme-returning helpers, so referencing it here would pull a libadwaita
    // dependency into every lightweight controller-test executable that compiles this file,
    // several of which deliberately don't link GTK/Adwaita at all. Keep these three literals in
    // sync with the schema and with AppSettings if either ever changes.
    private const string KEY_PRESERVE_TRAILING_WHITESPACE = "preserve-trailing-whitespace";
    private const string KEY_TRIM_TWO_SPACE_HARD_BREAKS = "trim-two-space-hard-breaks";
    private const string KEY_TRIM_WHITESPACE_IN_CODE_BLOCKS = "trim-whitespace-in-code-blocks";

    // Reads the three trailing-whitespace settings fresh on every call rather than caching them,
    // since they can change at any time via the Preferences dialog and this is called on every
    // keystroke (via has_unsaved_editor_changes -> on_editor_content_changed) as well as every
    // autosave tick. No compiled GSettings schema (owner.settings == null) means preserving
    // everything untouched, not trimming with a guessed default -- never risk mutating content
    // when the actual preference can't be read.
    private string trim_for_save(string text) {
        if (owner.settings == null) {
            return text;
        }
        return TextUtils.trim_trailing_whitespace_for_save(
            text,
            owner.settings.get_boolean(KEY_PRESERVE_TRAILING_WHITESPACE),
            owner.settings.get_boolean(KEY_TRIM_TWO_SPACE_HARD_BREAKS),
            owner.settings.get_boolean(KEY_TRIM_WHITESPACE_IN_CODE_BLOCKS)
        );
    }

    public void on_editor_content_changed() {
        if (owner.current_card == null) {
            owner.editor_save_state_changed("");
            return;
        }
        owner.editor_save_state_changed(has_unsaved_editor_changes() ? "Unsaved" : "");
        schedule_recovery_snapshot();
    }

    public void set_editor_view_state(string text, bool editable) {
        cancel_autosave_retry();
        cancel_recovery_snapshot();
        owner.editor_draft_state.reset_to_view_state(text, editable);
        owner.editor_state_changed(text, editable);
        owner.editor_save_state_changed("");
    }

    public void set_loaded_card_editor_state(CardDetail card) {
        cancel_autosave_retry();
        cancel_recovery_snapshot();
        owner.editor_draft_state.load_card_state(card.card_id, card.content);
        owner.editor_state_changed(card.content, true);
        owner.editor_save_state_changed("");
    }

    public void set_editor_save_state(string text) {
        owner.editor_save_state_changed(text);
    }

    public bool has_pending_autosave_retry() {
        return autosave_retry_id != 0;
    }

    public uint get_autosave_retry_attempts() {
        return autosave_retry_attempts;
    }

    private void cancel_autosave_retry() {
        if (autosave_retry_id != 0) {
            owner.scheduler.cancel(autosave_retry_id);
            autosave_retry_id = 0;
        }
        autosave_retry_attempts = 0;
    }

    private void cancel_scheduled_autosave() {
        if (autosave_id != 0) {
            owner.scheduler.cancel(autosave_id);
            autosave_id = 0;
        }
    }

    private void schedule_recovery_snapshot() {
        if (!plaintext_recovery_enabled() || owner.current_card == null) {
            return;
        }
        cancel_recovery_snapshot();
        recovery_snapshot_id = owner.scheduler.schedule_once(RECOVERY_SNAPSHOT_DELAY_MS, () => {
            recovery_snapshot_id = 0;
            try {
                save_emergency_recovery_draft();
            } catch (Error e) {
                report_recovery_write_failure_once(e);
            }
            return Source.REMOVE;
        });
    }

    private void cancel_recovery_snapshot() {
        if (recovery_snapshot_id != 0) {
            owner.scheduler.cancel(recovery_snapshot_id);
            recovery_snapshot_id = 0;
        }
    }

    private void run_queued_save_if_needed() {
        if (!save_again_requested) {
            return;
        }
        save_again_requested = false;
        if (has_unsaved_editor_changes()) {
            autosave_current_card.begin();
        }
    }

    private async void wait_for_save_progress() {
        Timeout.add(10, () => {
            wait_for_save_progress.callback();
            return Source.REMOVE;
        });
        yield;
    }

    private EditorRecoveryDraft draft_for_current_editor() {
        var card = (!) owner.current_card;
        var content = owner.editor_text.get_text();
        return new EditorRecoveryDraft(
            card.card_id,
            card.project_id,
            TextUtils.title_from_content(content),
            content,
            owner.now_epoch_seconds()
        );
    }

    private void note_explicit_save() {
        if (owner.settings == null) {
            owner.toast_requested("Saved. Holder also saves your changes automatically.");
            return;
        }
        var count = owner.settings.get_int(KEY_EXPLICIT_SAVE_COUNT) + 1;
        if (count <= 3) {
            owner.settings.set_int(KEY_EXPLICIT_SAVE_COUNT, count);
            owner.toast_requested("Saved. Holder also saves your changes automatically.");
        }
    }

    private void note_autosave_success() {
        cancel_autosave_retry();
    }

    private uint note_autosave_retry_scheduled(string card_id) {
        if (autosave_retry_id != 0) {
            owner.scheduler.cancel(autosave_retry_id);
            autosave_retry_id = 0;
        }

        autosave_retry_attempts++;
        uint delay_ms = autosave_retry_delay_ms(autosave_retry_attempts);
        autosave_retry_id = owner.scheduler.schedule_once(delay_ms, () => {
            autosave_retry_id = 0;
            if (owner.current_card == null
                || owner.current_card.card_id != card_id
                || !has_unsaved_editor_changes()) {
                autosave_retry_attempts = 0;
                return Source.REMOVE;
            }
            autosave_current_card.begin();
            return Source.REMOVE;
        });
        return delay_ms;
    }

    private bool autosave_retry_is_repeat_failure() {
        return autosave_retry_attempts > 0;
    }

    private static uint autosave_retry_delay_ms(uint attempts) {
        switch (attempts) {
        case 1:
            return 1000;
        case 2:
            return 2000;
        case 3:
            return 5000;
        default:
            return 10000;
        }
    }

    // A save is confirmed only after the backend request returns success.
    // Frontend cleanup that assumes durability, such as clearing recovery
    // drafts or advancing the committed editor baseline, must happen here.
    private void note_confirmed_durable_save(string saved_card_id,
                                             string previous_title,
                                             string title,
                                             string text,
                                             int64 updated_at,
                                             bool body_empty,
                                             int doc_chars,
                                             int body_chars,
                                             int delta_chars,
                                             string content_fingerprint) {
        if (owner.current_card == null || owner.current_card.card_id != saved_card_id) {
            return; // LCOV_EXCL_LINE: defensive async race guard after successful save if selection changed mid-flight
        }

        if (previous_title != title) {
            owner.emit_activity(
                "result.card.rename",
                "Renamed card: %s -> %s [body_empty=%s]".printf(
                    previous_title,
                    title,
                    body_empty ? "true" : "false"
                ),
                owner.current_project != null ? owner.current_project.project_id : null,
                owner.current_card.card_id,
                new CardRenamedDetails(previous_title, title, body_empty)
            );
        }

        owner.current_card.title = title;
        owner.current_card.content = text;
        owner.current_card.updated_at = updated_at;
        owner.current_card.tag_occurrences = new CardTagOccurrence[0];
        owner.editor_draft_state.mark_save_succeeded(owner.current_card.card_id, text);
        remove_local_recovery_draft_if_current(owner.current_card.card_id, text);

        owner.emit_activity(
            "result.card.autosave",
            "Autosaved card: %s [doc_chars=%d, body_chars=%d, delta_chars=%+d, body_empty=%s, fingerprint=%s]".printf(
                title,
                doc_chars,
                body_chars,
                delta_chars,
                body_empty ? "true" : "false",
                content_fingerprint
            ),
            owner.current_project != null ? owner.current_project.project_id : null,
            owner.current_card.card_id,
            new CardAutosavedDetails(
                title,
                doc_chars,
                body_chars,
                delta_chars,
                body_empty,
                content_fingerprint
            )
        );
        owner.update_selected_card_summary(title, updated_at);
        owner.window_title_changed(title);
        note_autosave_success();
        set_editor_save_state("Saved");
        owner.status_changed("Saved %s".printf(TextUtils.format_relative_time(owner.now_epoch_seconds(), updated_at)));
    }

    private bool save_local_recovery_draft(CardDetail card, string content) {
        if (!plaintext_recovery_enabled()) {
            return false;
        }
        try {
            recovery_draft_service.save_draft(new EditorRecoveryDraft(
                card.card_id,
                card.project_id,
                TextUtils.title_from_content(content),
                content,
                owner.now_epoch_seconds()
            ));
            recovery_write_failure_reported = false;
            return true;
        } catch (Error e) {
            report_recovery_write_failure_once(e);
            return false;
        }
    }

    private void report_recovery_write_failure_once(Error error) {
        if (recovery_write_failure_reported) {
            return;
        }
        recovery_write_failure_reported = true;
        owner.error_reported(
            "Could not create a recovery copy",
            "%s\n\nHolder will continue trying to save through the backend.".printf(error.message)
        );
    }

    private void remove_local_recovery_draft_if_current(string card_id, string saved_content) {
        try {
            // A completed older request must never clear recovery for text typed while it was
            // in flight. If the live editor still matches, however, every older draft is stale.
            if (trim_for_save(owner.editor_text.get_text()) == saved_content) {
                recovery_draft_service.remove_draft(card_id);
            }
        } catch (Error e) {
            warning("Failed to remove local recovery draft for %s: %s", card_id, e.message); // LCOV_EXCL_LINE: warning path is fatal under this test runner
        }
    }

    private void canonicalize_visible_editor_after_save(string card_id, string saved_text) {
        if (owner.current_card == null || owner.current_card.card_id != card_id) {
            return;
        }
        var visible_text = owner.editor_text.get_text();
        if (visible_text == saved_text || trim_for_save(visible_text) != saved_text) {
            return;
        }
        owner.editor_saved_text_canonicalized(saved_text);
    }

    private async void refresh_validated_tag_occurrences(string card_id, string saved_text) {
        if (owner.api == null || owner.current_card == null ||
            owner.current_card.card_id != card_id) {
            return;
        }
        // Compared trimmed, not raw -- saved_text is already the trimmed text that was
        // persisted, and the live buffer is never itself rewritten by trimming, so a raw
        // comparison here would treat "nothing changed since the save" as "stale" on every card
        // that has any trailing whitespace to trim, permanently skipping the tag-occurrence
        // refresh below. See EditorDraftState.has_unsaved_changes's doc comment for the same
        // failure mode in the dirty-check.
        if (saved_text.index_of_char('#') < 0) {
            if (trim_for_save(owner.editor_text.get_text()) == saved_text) {
                owner.current_card.tag_occurrences = new CardTagOccurrence[0];
                owner.editor_state_changed(saved_text, true);
            }
            return;
        }
        try {
            var refreshed = yield ((!) owner.api).get_card(card_id);
            if (owner.current_card == null || owner.current_card.card_id != card_id ||
                trim_for_save(owner.editor_text.get_text()) != saved_text) {
                return;
            }
            if (refreshed.content != saved_text) {
                owner.editor_state_changed(saved_text, true);
                return;
            }
            owner.current_card.tag_occurrences = refreshed.tag_occurrences;
            owner.editor_state_changed(saved_text, true);
        } catch (Error e) {
            if (owner.current_card != null && owner.current_card.card_id == card_id &&
                trim_for_save(owner.editor_text.get_text()) == saved_text) {
                owner.editor_state_changed(saved_text, true);
            }
        }
    }

    private static string body_text_from_content(string content) {
        var newline_index = content.index_of_char('\n');
        if (newline_index < 0 || newline_index + 1 >= content.length) {
            return "";
        }
        return content.substring(newline_index + 1);
    }

    private static string short_content_fingerprint(string content) {
        var digest = Checksum.compute_for_string(ChecksumType.SHA256, content);
        return digest.substring(0, 12);
    }
}

}
