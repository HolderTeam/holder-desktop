namespace HolderLinux {

internal class MainProjectFlowController : Object {
    private MainController owner; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field declaration-only coverage artifact

    public MainProjectFlowController(MainController owner) {
        this.owner = owner;
    }

    public async void reload_everything() {
        var preferred_project_id = owner.selected_project_id();
        var preferred_card_id = owner.selected_card_id();
        yield reload_everything_with_selection(preferred_project_id, preferred_card_id);
    }

    public async void reload_everything_with_selection(string? preferred_project_id,
                                                       string? preferred_card_id,
                                                       bool allow_retry = true) {
        if (owner.api == null) {
            return;
        }

        owner.status_changed("Refreshing projects...");
        try {
            var projects = yield owner.api.list_projects();
            owner.replace_projects(projects);
            if (owner.project_store.get_n_items() == 0) {
                owner.current_project = null;
                owner.clear_cards();
                owner.set_editor_view_state("# No Projects\n\nCreate a project to start writing.", false);
                return;
            }

            var selected = false;
            if (preferred_project_id != null && owner.has_project_summary(preferred_project_id)) {
                owner.project_selection_requested(preferred_project_id);
                selected = true;
            }
            if (!selected) {
                var first_project = owner.project_store.get_item(0) as Project;
                if (first_project != null) {
                    owner.project_selection_requested(first_project.project_id);
                }
            }
            var loaded = yield reload_selected_project_cards_data();
            if (!loaded) {
                return;
            }
            if (preferred_card_id != null) {
                if (owner.has_card_summary(preferred_card_id)) {
                    owner.card_selection_requested(preferred_card_id);
                } else if (owner.card_store.get_n_items() > 0) {
                    var first_card = owner.card_store.get_item(0) as CardSummary;
                    if (first_card != null) {
                        owner.card_selection_requested(first_card.card_id);
                    }
                }
            } else {
                owner.card_selection_requested(null);
            }
            owner.ai_status_refresh_requested();
        } catch (Error e) {
            if (allow_retry && (yield owner.backend_session_controller.try_reconnect_after_transport_error(e))) {
                yield reload_everything_with_selection(preferred_project_id, preferred_card_id, false);
                return;
            }
            owner.error_reported("Failed to refresh", e.message);
        }
    }

    public async void reload_cards_for_selected_project() {
        var loaded = yield reload_selected_project_cards_data();
        if (!loaded) {
            return;
        }
        owner.card_selection_requested(null);
    }

    public async bool reload_selected_project_cards_data(bool allow_retry = true) {
        if (owner.api == null) {
            return false;
        }

        var selected = owner.project_selection.get_selected_item() as Project;
        if (selected == null) {
            return false;
        }

        owner.current_project = selected;
        owner.window_title_changed(selected.name);
        if (owner.project_cards_loading_status_id != 0) {
            owner.scheduler.cancel(owner.project_cards_loading_status_id);
            owner.project_cards_loading_status_id = 0;
        }
        var requested_project_id = selected.project_id;
        var requested_project_name = selected.name;
        owner.project_cards_loading_status_id = owner.scheduler.schedule_once(MainController.LOADING_STATUS_DEBOUNCE_MS, () => {
            owner.project_cards_loading_status_id = 0;
            var still_selected = owner.project_selection.get_selected_item() as Project;
            if (still_selected != null && still_selected.project_id == requested_project_id) {
                owner.status_changed("Loading cards for %s...".printf(requested_project_name));
            }
            return Source.REMOVE;
        });

        try {
            var cards = yield owner.api.list_cards(selected.project_id, "recent");
            var latest_selected = owner.project_selection.get_selected_item() as Project;
            if (latest_selected == null || latest_selected.project_id != requested_project_id) {
                return false;
            }
            if (owner.project_cards_loading_status_id != 0) {
                owner.scheduler.cancel(owner.project_cards_loading_status_id);
                owner.project_cards_loading_status_id = 0;
            }
            owner.replace_cards(cards);
            yield owner.reload_ai_threads_for_project(selected.project_id);
            return true;
        } catch (Error e) {
            if (owner.project_cards_loading_status_id != 0) {
                owner.scheduler.cancel(owner.project_cards_loading_status_id);
                owner.project_cards_loading_status_id = 0;
            }
            var latest_selected = owner.project_selection.get_selected_item() as Project;
            if (latest_selected == null || latest_selected.project_id != requested_project_id) {
                return false;
            }
            if (allow_retry && (yield owner.backend_session_controller.try_reconnect_after_transport_error(e))) {
                return yield reload_selected_project_cards_data(false);
            }
            owner.error_reported("Failed to load cards", e.message);
            return false;
        }
    }
}

}
