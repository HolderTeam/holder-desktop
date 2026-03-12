namespace HolderLinux {

internal class AiThreadsController : Object {
    private MainController owner;

    public AiThreadsController(MainController owner) {
        this.owner = owner;
    }

    public bool select_ai_thread_by_id(string thread_id) {
        for (uint i = 0; i < owner.ai_thread_store.get_n_items(); i++) {
            var thread = owner.ai_thread_store.get_item(i) as AiThreadSummary;
            if (thread != null && thread.thread_id == thread_id) {
                owner.ai_thread_selection.set_selected_index(i);
                return true;
            }
        }
        return false;
    }

    public async string create_ai_thread(string title) throws Error {
        if (owner.api == null || owner.current_project == null) {
            throw new IOError.FAILED("No project/API context.");
        }
        return yield owner.api.create_ai_thread(owner.current_project.project_id, title);
    }

    public void on_ai_thread_selected() {
        var selected = owner.ai_thread_selection.get_selected_item() as AiThreadSummary;
        owner.current_ai_thread = selected;
        if (selected == null) {
            owner.ai_thread_title_changed(null);
            return;
        }
        owner.ai_thread_title_changed(selected.title);
    }

    public async void reload_ai_threads_for_project(string project_id) {
        if (owner.api == null) {
            return;
        }
        try {
            var threads = yield owner.api.list_ai_threads(project_id);
            owner.replace_ai_threads(threads);
            if (owner.ai_thread_store.get_n_items() > 0) {
                owner.ai_thread_selection.set_selected_index(0);
            } else {
                owner.current_ai_thread = null;
                owner.ai_thread_title_changed(null);
            }
        } catch (Error e) {
            owner.error_reported("Failed to load AI threads", e.message);
        }
    }
}

}
