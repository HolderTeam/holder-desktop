namespace HolderLinux {

internal class SearchController : Object {
    private MainController owner; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public SearchController(MainController owner) {
        this.owner = owner;
    }

    public async void run_search() {
        if (owner.api == null) {
            return;
        }
        if (owner.current_project == null) {
            owner.error_reported("Search unavailable", "No project selected.");
            return;
        }

        var query_text = owner.search_text.get_text().strip();
        if (query_text.length == 0) {
            clear_search_results();
            owner.show_editor_requested();
            return;
        }

        owner.status_changed("Searching for \"%s\"...".printf(query_text));
        try {
            var results = yield owner.api.search_cards(owner.current_project.project_id, query_text);
            owner.replace_search_results(results);
            owner.search_summary_changed("%d result(s) for \"%s\"".printf(results.size, query_text));
            owner.show_search_requested();
            owner.status_changed("Search complete");
        } catch (Error e) {
            owner.error_reported("Search failed", e.message);
        }
    }

    public void schedule_search() {
        if (owner.search_debounce_id != 0) {
            owner.scheduler.cancel(owner.search_debounce_id);
        }
        owner.search_debounce_id = owner.scheduler.schedule_once(300, () => {
            owner.search_debounce_id = 0;
            run_search.begin();
            return Source.REMOVE;
        });
    }

    public void cancel_pending_search() {
        if (owner.search_debounce_id == 0) {
            return;
        }
        owner.scheduler.cancel(owner.search_debounce_id);
        owner.search_debounce_id = 0;
    }

    public void clear_search_results() {
        owner.search_store.remove_all();
        owner.search_summary_changed("Search results will appear here.");
    }

    public async string? prepare_search_result_card_at(uint position) {
        var item = owner.search_store.get_item(position) as SearchCardResult;
        if (item == null) {
            return null;
        }

        if (owner.has_card_summary(item.card_id)) {
            return item.card_id;
        }

        yield owner.reload_cards_for_selected_project();
        if (owner.has_card_summary(item.card_id)) {
            return item.card_id;
        }

        return null;
    }
}

}
