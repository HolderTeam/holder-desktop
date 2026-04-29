using GLib;

namespace HolderLinux {

public class MainController : Object {
    private string? selected_project;
    private string? selected_card;

    public MainController(string? selected_project = null, string? selected_card = null) {
        this.selected_project = selected_project;
        this.selected_card = selected_card;
    }

    public string? selected_project_id() {
        return selected_project;
    }

    public string? selected_card_id() {
        return selected_card;
    }
}

}

namespace HolderLinux.Tests {

private HolderLinux.ActivityLogEntry latest_entry(HolderLinux.ActivityLogStore store) {
    var entries = store.snapshot();
    assert(entries.size > 0);
    return entries[entries.size - 1];
}

private void test_log_appends_explicit_values() {
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.ActivityLogController(
        store,
        new HolderLinux.MainController("proj-current", "card-current")
    );

    controller.log("kind.example", "Message body", "proj-1", "card-1", null);

    var entry = latest_entry(store);
    assert(entry.kind == "kind.example");
    assert(entry.message == "Message body");
    assert(entry.project_id == "proj-1");
    assert(entry.card_id == "card-1");
    assert(entry.details == null);
}

private void test_get_store_returns_original_store() {
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.ActivityLogController(
        store,
        new HolderLinux.MainController("proj-current", "card-current")
    );

    assert(controller.get_store() == store);
}

private void test_log_uses_default_null_optional_arguments() {
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.ActivityLogController(
        store,
        new HolderLinux.MainController("proj-current", "card-current")
    );

    controller.log("kind.default", "Message default");

    var entry = latest_entry(store);
    assert(entry.kind == "kind.default");
    assert(entry.message == "Message default");
    assert(entry.project_id == null);
    assert(entry.card_id == null);
    assert(entry.details == null);
}

private void test_log_from_current_selection_uses_main_controller_selection() {
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.ActivityLogController(
        store,
        new HolderLinux.MainController("proj-selected", "card-selected")
    );

    controller.log_from_current_selection("feedback.status", "Loaded");

    var entry = latest_entry(store);
    assert(entry.kind == "feedback.status");
    assert(entry.message == "Loaded");
    assert(entry.project_id == "proj-selected");
    assert(entry.card_id == "card-selected");
}

private void test_log_from_current_selection_preserves_details() {
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.ActivityLogController(
        store,
        new HolderLinux.MainController("proj-selected", "card-selected")
    );
    var details = new HolderLinux.CardCreatedDetails("New Card", "parent-1");

    controller.log_from_current_selection("intent.card.create", "Created", details);

    var entry = latest_entry(store);
    assert(entry.kind == "intent.card.create");
    assert(entry.message == "Created");
    assert(entry.project_id == "proj-selected");
    assert(entry.card_id == "card-selected");
    assert(entry.details == details);
}

private void test_feedback_and_intent_helpers_emit_expected_messages() {
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.ActivityLogController(
        store,
        new HolderLinux.MainController("proj-ctx", "card-ctx")
    );

    controller.log_status("Syncing");
    controller.log_toast("Saved");
    controller.log_error("Failure", "Disk full");
    controller.log_new_project_requested();
    controller.log_new_card_requested();
    controller.log_search_activated("needle");
    controller.log_search_result_open_requested();

    var entries = store.snapshot();
    assert(entries.size == 7);

    assert(entries[0].kind == "feedback.status");
    assert(entries[0].message == "Syncing");
    assert(entries[1].kind == "feedback.toast");
    assert(entries[1].message == "Saved");
    assert(entries[2].kind == "feedback.error");
    assert(entries[2].message == "Failure: Disk full");
    assert(entries[3].kind == "intent.project.create");
    assert(entries[3].message == "New project requested");
    assert(entries[4].kind == "intent.card.create");
    assert(entries[4].message == "New card requested");
    assert(entries[5].kind == "intent.search.activate");
    assert(entries[5].message == "Search activated: needle");
    assert(entries[6].kind == "intent.search.open_result");
    assert(entries[6].message == "Search result activated");

    foreach (var entry in entries) {
        assert(entry.project_id == "proj-ctx");
        assert(entry.card_id == "card-ctx");
    }
}

private void test_selection_helpers_log_selected_entities() {
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.ActivityLogController(
        store,
        new HolderLinux.MainController()
    );

    var project = new HolderLinux.Project("proj-2", "Project Two", "plain", "/tmp/proj2", 10, 20);
    var card = new HolderLinux.CardSummary("card-2", "proj-2", "Card Two", "cards/card-2.md", 1.0, null, 10, 20);
    var thread = new HolderLinux.AiThreadSummary("thread-2", "proj-2", "Thread Two", 10, 20);

    controller.log_project_selected(project);
    controller.log_card_selected(card);
    controller.log_ai_thread_selected(thread, "card-2");

    var entries = store.snapshot();
    assert(entries.size == 3);

    assert(entries[0].kind == "intent.project.select");
    assert(entries[0].message == "Project selected: Project Two");
    assert(entries[0].project_id == "proj-2");
    assert(entries[0].card_id == null);

    assert(entries[1].kind == "intent.card.select");
    assert(entries[1].message == "Card selected: Card Two");
    assert(entries[1].project_id == "proj-2");
    assert(entries[1].card_id == "card-2");

    assert(entries[2].kind == "intent.ai_thread.select");
    assert(entries[2].message == "AI thread selected: Thread Two");
    assert(entries[2].project_id == "proj-2");
    assert(entries[2].card_id == "card-2");
}

private void test_ai_thread_selection_defaults_card_id_to_null() {
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.ActivityLogController(
        store,
        new HolderLinux.MainController()
    );
    var thread = new HolderLinux.AiThreadSummary("thread-3", "proj-3", "Thread Three", 10, 20);

    controller.log_ai_thread_selected(thread);

    var entry = latest_entry(store);
    assert(entry.kind == "intent.ai_thread.select");
    assert(entry.project_id == "proj-3");
    assert(entry.card_id == null);
}

private void test_clear_delegates_to_store() {
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.ActivityLogController(
        store,
        new HolderLinux.MainController("proj-clear", "card-clear")
    );

    controller.log_status("Before clear");
    assert(store.snapshot().size == 1);

    controller.clear();

    assert(store.snapshot().size == 0);
}

private void test_store_discards_oldest_entries_when_capacity_is_exceeded() {
    var store = new HolderLinux.ActivityLogStore();
    var controller = new HolderLinux.ActivityLogController(
        store,
        new HolderLinux.MainController("proj-cap", "card-cap")
    );

    for (int i = 0; i < 501; i++) {
        controller.log("kind.%d".printf(i), "Message %d".printf(i));
    }

    var entries = store.snapshot();
    assert(entries.size == 500);
    assert(entries[0].kind == "kind.1");
    assert(entries[0].message == "Message 1");
    assert(entries[entries.size - 1].kind == "kind.500");
    assert(entries[entries.size - 1].message == "Message 500");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/activity-log/log-appends-explicit-values", test_log_appends_explicit_values);
    Test.add_func("/holder/activity-log/get-store-returns-original-store", test_get_store_returns_original_store);
    Test.add_func("/holder/activity-log/log-default-null-optional-arguments", test_log_uses_default_null_optional_arguments);
    Test.add_func("/holder/activity-log/log-from-current-selection", test_log_from_current_selection_uses_main_controller_selection);
    Test.add_func("/holder/activity-log/log-from-current-selection-preserves-details", test_log_from_current_selection_preserves_details);
    Test.add_func("/holder/activity-log/feedback-and-intent-helpers", test_feedback_and_intent_helpers_emit_expected_messages);
    Test.add_func("/holder/activity-log/selection-helpers", test_selection_helpers_log_selected_entities);
    Test.add_func("/holder/activity-log/ai-thread-selection-default-card-id", test_ai_thread_selection_defaults_card_id_to_null);
    Test.add_func("/holder/activity-log/clear-delegates-to-store", test_clear_delegates_to_store);
    Test.add_func("/holder/activity-log/store-discards-oldest-entries-when-capacity-is-exceeded",
                  test_store_discards_oldest_entries_when_capacity_is_exceeded);
    return Test.run();
}

}
