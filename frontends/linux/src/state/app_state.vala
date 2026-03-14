namespace HolderLinux {

public class AppSelectionSnapshot : Object {
    public string? project_id { get; set; }
    public string? card_id { get; set; }
    public string? ai_thread_id { get; set; }

    public AppSelectionSnapshot(string? project_id = null,
                                string? card_id = null,
                                string? ai_thread_id = null) {
        this.project_id = project_id;
        this.card_id = card_id;
        this.ai_thread_id = ai_thread_id;
    }
}

public class AppTransitionSnapshot : Object {
    public uint sequence { get; set; }
    public bool in_flight { get; set; }
    public string reason { get; set; }
    public AppSelectionSnapshot pending_selection { get; set; }

    public AppTransitionSnapshot() {
        sequence = 0;
        in_flight = false;
        reason = "";
        pending_selection = new AppSelectionSnapshot();
    }
}

public class AppStateStore : Object, IExplorerStateSink {
    public AppSelectionSnapshot selection { get; private set; }
    public AppTransitionSnapshot transition { get; private set; }
    public Gee.ArrayList<Project> projects { get; private set; }
    public Gee.ArrayList<CardSummary> cards { get; private set; }
    public Gee.ArrayList<AiThreadSummary> ai_threads { get; private set; }
    public uint data_version { get; private set; default = 0; }

    public signal void state_changed();

    public AppStateStore() {
        selection = new AppSelectionSnapshot();
        transition = new AppTransitionSnapshot();
        projects = new Gee.ArrayList<Project>();
        cards = new Gee.ArrayList<CardSummary>();
        ai_threads = new Gee.ArrayList<AiThreadSummary>();
    }

    public void set_selected_project(string? project_id) {
        selection.project_id = project_id;
        state_changed();
    }

    public void set_selected_card(string? card_id) {
        selection.card_id = card_id;
        state_changed();
    }

    public void set_selected_ai_thread(string? thread_id) {
        selection.ai_thread_id = thread_id;
        state_changed();
    }

    public void set_selection_snapshot(string? project_id,
                                       string? card_id,
                                       string? ai_thread_id) {
        selection.project_id = project_id;
        selection.card_id = card_id;
        selection.ai_thread_id = ai_thread_id;
        state_changed();
    }

    public void replace_projects_snapshot(Gee.ArrayList<Project> values) {
        projects.clear();
        foreach (var value in values) {
            projects.add(value);
        }
        data_version++;
        state_changed();
    }

    public void replace_cards_snapshot(Gee.ArrayList<CardSummary> values) {
        cards.clear();
        foreach (var value in values) {
            cards.add(value);
        }
        data_version++;
        state_changed();
    }

    public void replace_ai_threads_snapshot(Gee.ArrayList<AiThreadSummary> values) {
        ai_threads.clear();
        foreach (var value in values) {
            ai_threads.add(value);
        }
        data_version++;
        state_changed();
    }

    public uint begin_transition(string reason,
                                 string? pending_project_id = null,
                                 string? pending_card_id = null,
                                 string? pending_ai_thread_id = null) {
        transition.sequence++;
        transition.in_flight = true;
        transition.reason = reason;
        transition.pending_selection.project_id = pending_project_id;
        transition.pending_selection.card_id = pending_card_id;
        transition.pending_selection.ai_thread_id = pending_ai_thread_id;
        state_changed();
        return transition.sequence;
    }

    public bool is_current(uint sequence) {
        return transition.sequence == sequence;
    }

    public void finish_transition(uint sequence) {
        if (!is_current(sequence)) {
            return;
        }
        transition.in_flight = false;
        transition.reason = "";
        transition.pending_selection.project_id = null;
        transition.pending_selection.card_id = null;
        transition.pending_selection.ai_thread_id = null;
        state_changed();
    }
}

}
