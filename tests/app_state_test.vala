using GLib;

private HolderLinux.Project make_project(string id, string name) {
    return new HolderLinux.Project(id, name, "private", "/tmp/%s".printf(id), 10, 20);
}

private HolderLinux.CardSummary make_card(string id, string project_id, string title) {
    return new HolderLinux.CardSummary(id, project_id, title, "%s.md".printf(id), 1.0, null, 10, 20);
}

private HolderLinux.AiThreadSummary make_thread(string id, string project_id, string title) {
    return new HolderLinux.AiThreadSummary(id, project_id, title, 10, 20);
}

private void test_setters_update_selection_and_emit_state_changed() {
    var state = new HolderLinux.AppStateStore();
    uint changed_count = 0;
    state.state_changed.connect(() => {
        changed_count++;
    });

    state.set_selected_card("card-1");
    state.set_selected_ai_thread("thread-1");

    assert(state.selection.card_id == "card-1");
    assert(state.selection.ai_thread_id == "thread-1");
    assert(changed_count == 2);
}

private void test_replace_snapshots_update_lists_increment_data_version_and_emit() {
    var state = new HolderLinux.AppStateStore();
    uint changed_count = 0;
    state.state_changed.connect(() => {
        changed_count++;
    });

    var projects = new Gee.ArrayList<HolderLinux.Project>();
    projects.add(make_project("p1", "Project One"));
    projects.add(make_project("p2", "Project Two"));
    state.replace_projects_snapshot(projects);

    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    cards.add(make_card("c1", "p1", "Card One"));
    state.replace_cards_snapshot(cards);

    var threads = new Gee.ArrayList<HolderLinux.AiThreadSummary>();
    threads.add(make_thread("t1", "p1", "Thread One"));
    threads.add(make_thread("t2", "p1", "Thread Two"));
    state.replace_ai_threads_snapshot(threads);

    assert(state.projects.size == 2);
    assert(state.projects[0].project_id == "p1");
    assert(state.cards.size == 1);
    assert(state.cards[0].card_id == "c1");
    assert(state.ai_threads.size == 2);
    assert(state.ai_threads[1].thread_id == "t2");
    assert(state.data_version == 3);
    assert(changed_count == 3);
}

private void test_finish_transition_ignores_stale_sequence() {
    var state = new HolderLinux.AppStateStore();

    var stale = state.begin_transition("stale", "p-stale", "c-stale", "t-stale");
    var current = state.begin_transition("current", "p-current", "c-current", "t-current");

    state.finish_transition(stale);

    assert(state.transition.in_flight);
    assert(state.transition.reason == "current");
    assert(state.transition.pending_selection.project_id == "p-current");
    assert(state.transition.pending_selection.card_id == "c-current");
    assert(state.transition.pending_selection.ai_thread_id == "t-current");

    state.finish_transition(current);

    assert(!state.transition.in_flight);
    assert(state.transition.reason == "");
    assert(state.transition.pending_selection.project_id == null);
    assert(state.transition.pending_selection.card_id == null);
    assert(state.transition.pending_selection.ai_thread_id == null);
}

public int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/app_state/setters_update_selection_and_emit_state_changed",
                  test_setters_update_selection_and_emit_state_changed);
    Test.add_func("/app_state/replace_snapshots_update_lists_increment_data_version_and_emit",
                  test_replace_snapshots_update_lists_increment_data_version_and_emit);
    Test.add_func("/app_state/finish_transition_ignores_stale_sequence",
                  test_finish_transition_ignores_stale_sequence);

    return Test.run();
}
