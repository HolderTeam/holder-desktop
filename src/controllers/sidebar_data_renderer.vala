namespace HolderLinux {

internal class SidebarDataRenderer : Object {
    private GLib.ListStore project_store;
    private GLib.ListStore card_store;
    private GLib.ListStore ai_thread_store;

    public SidebarDataRenderer(GLib.ListStore project_store,
                               GLib.ListStore card_store,
                               GLib.ListStore ai_thread_store) {
        this.project_store = project_store;
        this.card_store = card_store;
        this.ai_thread_store = ai_thread_store;
    }

    public void apply(Gee.ArrayList<Project> projects,
                      Gee.ArrayList<CardSummary> cards,
                      Gee.ArrayList<AiThreadSummary> ai_threads) {
        if (!projects_equal(project_store, projects)) {
            project_store.remove_all();
            foreach (var project in projects) {
                project_store.append(project);
            }
        }

        if (!cards_equal(card_store, cards)) {
            card_store.remove_all();
            foreach (var card in cards) {
                card_store.append(card);
            }
        }

        if (!threads_equal(ai_thread_store, ai_threads)) {
            ai_thread_store.remove_all();
            foreach (var thread in ai_threads) {
                ai_thread_store.append(thread);
            }
        }
    }

    private static bool projects_equal(GLib.ListStore store, Gee.ArrayList<Project> values) {
        if (store.get_n_items() != values.size) {
            return false;
        }
        for (uint i = 0; i < store.get_n_items(); i++) {
            var existing = store.get_item(i) as Project;
            var incoming = values[(int) i];
            if (existing == null || incoming == null) {
                return false; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: strongly typed store/list defensive guard
            }
            if (existing.project_id != incoming.project_id
                || existing.name != incoming.name
                || existing.privacy_mode != incoming.privacy_mode
                || existing.root_path != incoming.root_path
                || existing.git_remote_url != incoming.git_remote_url
                || existing.card_count != incoming.card_count
                || existing.root_card_count != incoming.root_card_count
                || existing.updated_at != incoming.updated_at) {
                return false;
            }
        }
        return true;
    }

    private static bool cards_equal(GLib.ListStore store, Gee.ArrayList<CardSummary> values) {
        if (store.get_n_items() != values.size) {
            return false;
        }
        for (uint i = 0; i < store.get_n_items(); i++) {
            var existing = store.get_item(i) as CardSummary;
            var incoming = values[(int) i];
            if (existing == null || incoming == null) {
                return false; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: strongly typed store/list defensive guard
            }
            if (existing.card_id != incoming.card_id
                || existing.project_id != incoming.project_id
                || existing.title != incoming.title
                || existing.rel_path != incoming.rel_path
                || existing.sort_key != incoming.sort_key
                || existing.parent_card_id != incoming.parent_card_id
                || existing.updated_at != incoming.updated_at) {
                return false;
            }
        }
        return true;
    }

    private static bool threads_equal(GLib.ListStore store, Gee.ArrayList<AiThreadSummary> values) {
        if (store.get_n_items() != values.size) {
            return false;
        }
        for (uint i = 0; i < store.get_n_items(); i++) {
            var existing = store.get_item(i) as AiThreadSummary;
            var incoming = values[(int) i];
            if (existing == null || incoming == null) {
                return false; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: strongly typed store/list defensive guard
            }
            if (existing.thread_id != incoming.thread_id
                || existing.project_id != incoming.project_id
                || existing.title != incoming.title
                || existing.updated_at != incoming.updated_at) {
                return false;
            }
        }
        return true;
    }
}

}
