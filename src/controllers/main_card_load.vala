namespace HolderLinux {

internal class MainCardLoadController : Object {
    private MainController owner; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field declaration-only coverage artifact

    public MainCardLoadController(MainController owner) {
        this.owner = owner;
    }

    public async void load_card_by_id(string requested_card_id, bool allow_retry = true) {
        if (owner.api == null) {
            return;
        }

        if (owner.card_loading_status_id != 0) {
            owner.scheduler.cancel(owner.card_loading_status_id);
            owner.card_loading_status_id = 0;
        }
        owner.card_loading_status_id = owner.scheduler.schedule_once(MainController.LOADING_STATUS_DEBOUNCE_MS, () => {
            owner.card_loading_status_id = 0;
            if (owner.selected_card_id() == requested_card_id) {
                owner.status_changed("Loading card...");
            }
            return Source.REMOVE;
        });
        try {
            var card = yield owner.api.get_card(requested_card_id);
            if (owner.card_loading_status_id != 0) {
                owner.scheduler.cancel(owner.card_loading_status_id);
                owner.card_loading_status_id = 0;
            }
            if (owner.selected_card_id() != requested_card_id) {
                return;
            }
            owner.current_card = card;
            owner.set_loaded_card_editor_state(card);
            owner.inspect_recovery_draft(card);
            owner.show_editor_requested();
            owner.window_title_changed(card.title);
            owner.status_changed("Loaded %s".printf(card.title));
        } catch (Error e) {
            if (owner.card_loading_status_id != 0) {
                owner.scheduler.cancel(owner.card_loading_status_id);
                owner.card_loading_status_id = 0;
            }
            if (owner.selected_card_id() != requested_card_id) {
                return;
            }
            if (allow_retry && (yield owner.backend_session_controller.try_reconnect_after_transport_error(e))) {
                yield load_card_by_id(requested_card_id, false);
                return;
            }
            owner.status_changed("Failed to load card.");
            owner.error_reported("Failed to load card", e.message);
        }
    }
}

}
