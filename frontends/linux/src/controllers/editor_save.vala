namespace HolderLinux {

internal class EditorSaveController : Object {
    private const uint AUTOSAVE_DELAY_MS = 900;

    private MainController owner; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IEditorRecoveryDraftService recovery_draft_service;
    private uint autosave_id = 0;
    private uint autosave_retry_id = 0;
    private uint autosave_retry_attempts = 0;

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
        if (owner.current_card == null) {
            return;
        }

        var previous_content = owner.editor_draft_state.committed_text;
        var text = owner.editor_text.get_text();
        if (!has_unsaved_editor_changes()) {
            return;
        }
        if (owner.api == null) {
            save_local_recovery_draft(owner.current_card, text);
            owner.status_changed("Backend unavailable, saved recovery draft locally");
            set_editor_save_state("Unsaved");
            return;
        }
        var previous_title = owner.current_card.title;
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
            yield ((!) owner.api).update_card(owner.current_card.card_id, title, text, updated_at);
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
            owner.editor_draft_state.mark_save_succeeded(owner.current_card.card_id, text);
            owner.current_card.updated_at = updated_at;
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
        } catch (Error e) {
            save_local_recovery_draft(owner.current_card, text);
            owner.emit_activity(
                "result.card.autosave_failed",
                "Autosave failed: %s".printf(e.message),
                owner.current_project != null ? owner.current_project.project_id : null,
                owner.current_card.card_id
            );
            var repeat_failure = autosave_retry_is_repeat_failure();
            var retry_delay_ms = note_autosave_retry_scheduled(owner.current_card.card_id);
            set_editor_save_state("Unsaved");
            if (repeat_failure) {
                owner.status_changed("Autosave failed, retrying in %u s".printf((retry_delay_ms + 999) / 1000));
                return;
            }
            owner.error_reported(
                "Autosave failed",
                "%s\n\nRetrying in %u s.".printf(e.message, (retry_delay_ms + 999) / 1000)
            );
        }
    }

    public bool has_unsaved_editor_changes() {
        return owner.editor_draft_state.has_unsaved_changes(owner.current_card, owner.editor_text);
    }

    public void on_editor_content_changed() {
        if (owner.current_card == null) {
            owner.editor_save_state_changed("");
            return;
        }
        owner.editor_save_state_changed(has_unsaved_editor_changes() ? "Unsaved" : "");
    }

    public void set_editor_view_state(string text, bool editable) {
        cancel_autosave_retry();
        owner.editor_draft_state.reset_to_view_state(text, editable);
        owner.editor_state_changed(text, editable);
        owner.editor_save_state_changed("");
    }

    public void set_loaded_card_editor_state(CardDetail card) {
        cancel_autosave_retry();
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

    private void save_local_recovery_draft(CardDetail card, string content) {
        try {
            recovery_draft_service.save_draft(new EditorRecoveryDraft(
                card.card_id,
                card.project_id,
                TextUtils.title_from_content(content),
                content,
                owner.now_epoch_seconds()
            ));
        } catch (Error e) {
            warning("Failed to save local recovery draft for %s: %s", card.card_id, e.message);
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
