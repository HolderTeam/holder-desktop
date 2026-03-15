namespace HolderLinux {

internal class CardsController : Object {
    private MainController owner; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public CardsController(MainController owner) {
        this.owner = owner;
    }

    public async void create_card(string? parent_card_id = null) {
        yield create_card_with_content(
            "Untitled",
            "# Untitled\n\n",
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

            owner.toast_requested(success_toast);
            owner.status_changed("Created new card");
        } catch (Error e) {
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

        var text = owner.editor_text.get_text();
        var title = TextUtils.title_from_content(text);
        var updated_at = owner.now_epoch_seconds();

        try {
            yield owner.api.update_card(owner.current_card.card_id, title, text, updated_at);
            owner.current_card.title = title;
            owner.current_card.content = text;
            owner.current_card.updated_at = updated_at;
            owner.update_selected_card_summary(title, updated_at);
            owner.window_title_changed(title);
            owner.status_changed("Saved %s".printf(TextUtils.format_relative_time(owner.now_epoch_seconds(), updated_at)));
        } catch (Error e) {
            owner.error_reported("Autosave failed", e.message);
        }
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
            owner.status_changed("Moved card");
            yield owner.reload_cards_for_selected_project();
            if (owner.has_card_summary(card_id)) {
                owner.card_selection_requested(card_id);
                owner.load_selected_card.begin();
            }
        } catch (Error e) {
            owner.error_reported("Move card failed", e.message);
            owner.reload_cards_for_selected_project.begin();
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
            owner.status_changed("Moved card to trash");
            owner.toast_requested("Moved \"%s\" to Trash".printf(card_title));
            yield owner.reload_cards_for_selected_project();
            owner.card_trashed(card_id);
        } catch (Error e) {
            owner.error_reported("Move to trash failed", e.message);
        }
    }
}

}
