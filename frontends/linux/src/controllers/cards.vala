namespace HolderLinux {

internal class CardsController : Object {
    private MainController owner; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public CardsController(MainController owner) {
        this.owner = owner;
    }

    public async void create_card(string? parent_card_id = null) {
        var default_title = default_title_for_parent(parent_card_id);
        yield create_card_with_content(
            default_title,
            "# %s\n\n".printf(default_title),
            parent_card_id,
            "New card created"
        );
    }

    public async void create_card_with_title(string title, string? parent_card_id = null) {
        var clean_title = title.strip();
        if (clean_title.length == 0) {
            owner.error_reported("Card title required", "Please enter a non-empty title.");
            return;
        }
        yield create_card_with_content(
            clean_title,
            "# %s\n\n".printf(clean_title),
            parent_card_id,
            "Created card: %s".printf(clean_title)
        );
    }

    public async void create_card_with_content(string title,
                                               string content,
                                               string? parent_card_id,
                                               string success_toast) {
        if (owner.create_card_in_flight) {
            owner.status_changed("Create card already in progress...");
            return;
        }
        if (owner.api == null) {
            owner.error_reported("Create card unavailable", "API client is not connected.");
            return;
        }

        if (owner.current_project == null) {
            var selected = owner.project_selection.get_selected_item() as Project;
            if (selected != null) {
                owner.current_project = selected;
            }
        }
        if (owner.current_project == null) {
            owner.error_reported("No project selected", "Select or create a project first.");
            return;
        }

        owner.create_card_in_flight = true;
        owner.status_changed("Creating new card...");
        try {
            var new_id = yield owner.api.create_card(
                owner.current_project.project_id,
                title,
                content,
                parent_card_id
            );
            var cards = yield owner.api.list_cards(owner.current_project.project_id, "recent");
            owner.replace_cards(cards);
            if (owner.has_card_summary(new_id)) {
                owner.card_selection_requested(new_id);
            }

            owner.emit_activity(
                "result.card.create",
                "Created card: %s".printf(title),
                owner.current_project.project_id,
                new_id,
                new CardCreatedDetails(title, parent_card_id)
            );
            owner.toast_requested(success_toast);
            owner.status_changed("Created new card");
        } catch (Error e) {
            owner.emit_activity(
                "result.card.create_failed",
                "Failed to create card: %s".printf(e.message),
                owner.current_project.project_id,
                null
            );
            owner.error_reported("Failed to create card", e.message);
        } finally {
            owner.create_card_in_flight = false;
        }
    }

    public void schedule_autosave() {
        if (owner.autosave_id != 0) {
            owner.scheduler.cancel(owner.autosave_id);
        }

        owner.autosave_id = owner.scheduler.schedule_once(900, () => {
            owner.autosave_id = 0;
            autosave_current_card.begin();
            return Source.REMOVE;
        });
    }

    public async void autosave_current_card() {
        if (owner.api == null || owner.current_card == null) {
            return;
        }

        var previous_content = owner.editor_draft_state.committed_text;
        var text = owner.editor_text.get_text();
        if (!owner.has_unsaved_editor_changes()) {
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
            yield owner.api.update_card(owner.current_card.card_id, title, text, updated_at);
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
            owner.status_changed("Saved %s".printf(TextUtils.format_relative_time(owner.now_epoch_seconds(), updated_at)));
        } catch (Error e) {
            owner.emit_activity(
                "result.card.autosave_failed",
                "Autosave failed: %s".printf(e.message),
                owner.current_project != null ? owner.current_project.project_id : null,
                owner.current_card.card_id
            );
            owner.error_reported("Autosave failed", e.message);
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

    private string default_title_for_parent(string? parent_card_id) {
        if (parent_card_id == null || parent_card_id.strip().length == 0) {
            return "Untitled";
        }
        string? parent_title = null;
        for (uint i = 0; i < owner.card_store.get_n_items(); i++) {
            var card = owner.card_store.get_item(i) as CardSummary;
            if (card != null && card.card_id == parent_card_id) {
                parent_title = card.title;
                break;
            }
        }
        if (parent_title == null || parent_title.strip().length == 0) {
            return "Untitled";
        }

        var base_title = "Untitled child of %s".printf(parent_title);
        int next_suffix = 1;
        for (uint i = 0; i < owner.card_store.get_n_items(); i++) {
            var card = owner.card_store.get_item(i) as CardSummary;
            if (card == null || card.parent_card_id != parent_card_id) {
                continue;
            }
            if (card.title == base_title) {
                next_suffix = int.max(next_suffix, 2);
                continue;
            }
            if (!card.title.has_prefix(base_title + " ")) {
                continue;
            }
            var suffix_text = card.title.substring((base_title + " ").length).strip();
            int parsed_suffix = 0;
            if (int.try_parse(suffix_text, out parsed_suffix) && parsed_suffix >= 2) {
                next_suffix = int.max(next_suffix, parsed_suffix + 1);
            }
        }

        if (next_suffix == 1) {
            return base_title;
        }
        return "%s %d".printf(base_title, next_suffix);
    }

    public async void move_card_by_intent(string card_id,
                                          string intent,
                                          string? target_card_id = null,
                                          string? parent_card_id = null) {
        if (owner.api == null) {
            return;
        }
        var selected = owner.project_selection.get_selected_item() as Project;
        if (selected == null) {
            owner.error_reported("Move card failed", "Select a project first.");
            return;
        }

        try {
            var moved = yield owner.api.move_card(
                card_id,
                selected.project_id,
                intent,
                target_card_id,
                parent_card_id
            );
            if (intent == "into" && moved.moved_into_title.length > 0) {
                owner.toast_requested("Moved card into %s".printf(moved.moved_into_title));
            }
            owner.emit_activity(
                "result.card.move",
                "Moved card (%s)".printf(intent),
                selected.project_id,
                card_id
            );
            owner.status_changed("Moved card");
            if (!(yield owner.reload_selected_project_cards_data())) {
                return;
            }
            if (owner.has_card_summary(card_id)) {
                owner.card_selection_requested(card_id);
            }
        } catch (Error e) {
            owner.emit_activity(
                "result.card.move_failed",
                "Move card failed: %s".printf(e.message),
                selected.project_id,
                card_id
            );
            owner.error_reported("Move card failed", e.message);
            owner.reload_selected_project_cards_data.begin();
        }
    }

    public async void move_card_to_trash(string card_id) {
        if (owner.api == null) {
            owner.error_reported("Move to trash unavailable", "API client is not connected.");
            return;
        }

        string card_title = "card";
        for (uint i = 0; i < owner.card_store.get_n_items(); i++) {
            var card = owner.card_store.get_item(i) as CardSummary;
            if (card != null && card.card_id == card_id) {
                card_title = card.title;
                break;
            }
        }

        try {
            yield owner.api.delete_card(card_id);
            owner.emit_activity(
                "result.card.trash",
                "Moved \"%s\" to Trash".printf(card_title),
                owner.current_project != null ? owner.current_project.project_id : null,
                card_id,
                new CardTrashedDetails(card_title)
            );
            owner.status_changed("Moved card to trash");
            owner.toast_requested("Moved \"%s\" to Trash".printf(card_title));
            yield owner.reload_cards_for_selected_project();
            owner.card_trashed(card_id);
        } catch (Error e) {
            owner.emit_activity(
                "result.card.trash_failed",
                "Move to trash failed: %s".printf(e.message),
                owner.current_project != null ? owner.current_project.project_id : null,
                card_id
            );
            owner.error_reported("Move to trash failed", e.message);
        }
    }
}

}
