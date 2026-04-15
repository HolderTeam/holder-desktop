namespace HolderLinux {

internal class StoreSyncController : Object {
    private MainController owner;

    public StoreSyncController(MainController owner) {
        this.owner = owner;
    }

    public void replace_projects(Gee.ArrayList<Project> projects) {
        owner.project_store.remove_all();
        foreach (var project in projects) {
            owner.project_store.append(project);
        }
        if (owner.explorer_state_sink != null) {
            ((!) owner.explorer_state_sink).replace_projects_snapshot(projects);
        }
    }

    public void replace_cards(Gee.ArrayList<CardSummary> cards) {
        cards.sort((a, b) => compare_cards_for_sidebar(a, b));
        owner.card_store.remove_all();
        foreach (var card in cards) {
            owner.card_store.append(card);
        }
        if (owner.explorer_state_sink != null) {
            ((!) owner.explorer_state_sink).replace_cards_snapshot(cards);
        }
    }

    public void replace_ai_threads(Gee.ArrayList<AiThreadSummary> threads) {
        owner.ai_thread_store.remove_all();
        foreach (var thread in threads) {
            owner.ai_thread_store.append(thread);
        }
        if (owner.explorer_state_sink != null) {
            ((!) owner.explorer_state_sink).replace_ai_threads_snapshot(threads);
        }
    }

    public void clear_cards() {
        owner.card_store.remove_all();
        owner.current_card = null;
        owner.ai_thread_store.remove_all();
        owner.current_ai_thread = null;
        owner.ai_thread_title_changed(null);
        if (owner.explorer_state_sink != null) {
            ((!) owner.explorer_state_sink).replace_cards_snapshot(new Gee.ArrayList<CardSummary>());
            ((!) owner.explorer_state_sink).replace_ai_threads_snapshot(new Gee.ArrayList<AiThreadSummary>());
        }
    }

    public void replace_search_results(Gee.ArrayList<SearchCardResult> results) {
        owner.search_store.remove_all();
        foreach (var result in results) {
            owner.search_store.append(result);
        }
        if (results.size > 0) {
            owner.search_selection_requested(0);
            return;
        }
        owner.search_selection_requested(-1);
    }

    public bool has_card_summary(string card_id) {
        for (uint i = 0; i < owner.card_store.get_n_items(); i++) {
            var card = owner.card_store.get_item(i) as CardSummary;
            if (card != null && card.card_id == card_id) {
                return true;
            }
        }
        return false;
    }

    public bool has_project_summary(string project_id) {
        for (uint i = 0; i < owner.project_store.get_n_items(); i++) {
            var project = owner.project_store.get_item(i) as Project;
            if (project != null && project.project_id == project_id) {
                return true;
            }
        }
        return false;
    }

    public void update_selected_card_summary(string title, int64 updated_at) {
        if (owner.current_card == null) {
            return;
        }
        var target_card_id = owner.current_card.card_id;
        var source_cards = new Gee.ArrayList<CardSummary?>();
        for (uint i = 0; i < owner.card_store.get_n_items(); i++) {
            source_cards.add(owner.card_store.get_item(i) as CardSummary);
        }
        var updated_cards = rebuild_card_summaries(source_cards, target_card_id, title, updated_at);
        owner.card_store.remove_all();
        foreach (var card in updated_cards) {
            owner.card_store.append(card);
        }
        if (owner.explorer_state_sink != null) {
            ((!) owner.explorer_state_sink).replace_cards_snapshot(updated_cards);
        }
    }

    public static Gee.ArrayList<CardSummary> rebuild_card_summaries(
        Gee.ArrayList<CardSummary?> source_cards,
        string target_card_id,
        string title,
        int64 updated_at
    ) {
        var updated_cards = new Gee.ArrayList<CardSummary>();
        foreach (var card in source_cards) {
            if (card == null) {
                continue;
            }
            if (card.card_id != target_card_id) {
                updated_cards.add(card);
                continue;
            }
            updated_cards.add(new CardSummary(
                card.card_id,
                card.project_id,
                title,
                card.rel_path,
                card.sort_key,
                card.parent_card_id,
                card.created_at,
                updated_at
            ));
        }
        return updated_cards;
    }

    public static int compare_cards_for_sidebar(CardSummary a, CardSummary b) {
        if (a.updated_at > b.updated_at) {
            return -1;
        }
        if (a.updated_at < b.updated_at) {
            return 1;
        }
        return strcmp(a.title.down(), b.title.down());
    }
}

}
