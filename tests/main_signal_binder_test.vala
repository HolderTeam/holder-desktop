using GLib;

namespace HolderLinux {

private class FakeMainControllerSignalSource : Object, IMainControllerSignalSource {
    public void emit_status_changed(string text) { status_changed(text); }
    public void emit_editor_state_changed(string text, bool editable) { editor_state_changed(text, editable); }
    public void emit_editor_save_state_changed(string text) { editor_save_state_changed(text); }
    public void emit_window_title_changed(string title_text) { window_title_changed(title_text); }
    public void emit_toast_requested(string message) { toast_requested(message); }
    public void emit_error_reported(string title_text, string details) { error_reported(title_text, details); }
    public void emit_show_editor_requested() { show_editor_requested(); }
    public void emit_show_search_requested() { show_search_requested(); }
    public void emit_search_summary_changed(string text) { search_summary_changed(text); }
    public void emit_ai_status_refresh_requested() { ai_status_refresh_requested(); }
    public void emit_project_selection_requested(string? project_id) { project_selection_requested(project_id); }
    public void emit_card_selection_requested(string? card_id) { card_selection_requested(card_id); }
    public void emit_search_selection_requested(int position) { search_selection_requested(position); }
    public void emit_ai_thread_title_changed(string? title_text) { ai_thread_title_changed(title_text); }
    public void emit_ai_thread_selection_requested(string? thread_id) { ai_thread_selection_requested(thread_id); }
    public void emit_api_client_ready(IHolderApi api_client) { api_client_ready(api_client); }
    public void emit_card_trashed(string card_id) { card_trashed(card_id); }
    public void emit_activity_requested(string kind,
                                        string message,
                                        string? project_id,
                                        string? card_id,
                                        ActivityDetails? details) {
        activity_requested(kind, message, project_id, card_id, details);
    }
}

private class RecordingMainControllerSignalSink : Object, IMainControllerSignalSink {
    public string status_text = "";
    public string editor_text = "";
    public bool editor_editable = false;
    public string editor_save_text = "";
    public string window_title = "";
    public string toast_message = "";
    public string error_title = "";
    public string error_details = "";
    public int show_editor_calls = 0;
    public int show_search_calls = 0;
    public string search_summary = "";
    public int ai_status_refresh_calls = 0;
    public string? project_id = "unset";
    public string? card_id = "unset";
    public int search_position = -1;
    public string? ai_thread_title = "unset";
    public string? ai_thread_id = "unset";
    public IHolderApi? api_client = null;
    public string trashed_card_id = "";
    public string activity_kind = "";
    public string activity_message = "";
    public string? activity_project_id = "unset";
    public string? activity_card_id = "unset";
    public ActivityDetails? activity_details = null;

    public void on_status_changed(string text) { status_text = text; }
    public void on_editor_state_changed(string text, bool editable) { editor_text = text; editor_editable = editable; }
    public void on_editor_save_state_changed(string text) { editor_save_text = text; }
    public void on_window_title_changed(string title_text) { window_title = title_text; }
    public void on_toast_requested(string message) { toast_message = message; }
    public void on_error_reported(string title_text, string details) { error_title = title_text; error_details = details; }
    public void on_show_editor_requested() { show_editor_calls++; }
    public void on_show_search_requested() { show_search_calls++; }
    public void on_search_summary_changed(string text) { search_summary = text; }
    public void on_ai_status_refresh_requested() { ai_status_refresh_calls++; }
    public void on_project_selection_requested(string? project_id) { this.project_id = project_id; }
    public void on_card_selection_requested(string? card_id) { this.card_id = card_id; }
    public void on_search_selection_requested(int position) { search_position = position; }
    public void on_ai_thread_title_changed(string? title_text) { ai_thread_title = title_text; }
    public void on_ai_thread_selection_requested(string? thread_id) { ai_thread_id = thread_id; }
    public void on_api_client_ready(IHolderApi api_client) { this.api_client = api_client; }
    public void on_card_trashed(string card_id) { trashed_card_id = card_id; }
    public void on_activity_requested(string kind,
                                      string message,
                                      string? project_id,
                                      string? card_id,
                                      ActivityDetails? details) {
        activity_kind = kind;
        activity_message = message;
        activity_project_id = project_id;
        activity_card_id = card_id;
        activity_details = details;
    }
}

}

namespace HolderLinux.Tests {

private void test_bind_forwards_all_main_controller_signals_to_sink() {
    var source = new HolderLinux.FakeMainControllerSignalSource();
    var sink = new HolderLinux.RecordingMainControllerSignalSink();
    var binder = new HolderLinux.MainControllerSignalBinder(source, sink);
    var api = new HolderLinuxTests.AiRunFakeApi();
    var details = new HolderLinux.CardCreatedDetails("Card A", "parent-1");

    binder.bind();

    source.emit_status_changed("ready");
    source.emit_editor_state_changed("# Card", true);
    source.emit_editor_save_state_changed("Saved");
    source.emit_window_title_changed("Holder - Card");
    source.emit_toast_requested("Toast");
    source.emit_error_reported("Error", "Details");
    source.emit_show_editor_requested();
    source.emit_show_search_requested();
    source.emit_search_summary_changed("3 results");
    source.emit_ai_status_refresh_requested();
    source.emit_project_selection_requested("proj-1");
    source.emit_card_selection_requested("card-1");
    source.emit_search_selection_requested(4);
    source.emit_ai_thread_title_changed("Thread title");
    source.emit_ai_thread_selection_requested("thread-1");
    source.emit_api_client_ready(api);
    source.emit_card_trashed("card-2");
    source.emit_activity_requested("result.card.create", "Created card", "proj-1", "card-1", details);

    assert(sink.status_text == "ready");
    assert(sink.editor_text == "# Card");
    assert(sink.editor_editable);
    assert(sink.editor_save_text == "Saved");
    assert(sink.window_title == "Holder - Card");
    assert(sink.toast_message == "Toast");
    assert(sink.error_title == "Error");
    assert(sink.error_details == "Details");
    assert(sink.show_editor_calls == 1);
    assert(sink.show_search_calls == 1);
    assert(sink.search_summary == "3 results");
    assert(sink.ai_status_refresh_calls == 1);
    assert(sink.project_id == "proj-1");
    assert(sink.card_id == "card-1");
    assert(sink.search_position == 4);
    assert(sink.ai_thread_title == "Thread title");
    assert(sink.ai_thread_id == "thread-1");
    assert(sink.api_client == api);
    assert(sink.trashed_card_id == "card-2");
    assert(sink.activity_kind == "result.card.create");
    assert(sink.activity_message == "Created card");
    assert(sink.activity_project_id == "proj-1");
    assert(sink.activity_card_id == "card-1");
    assert(sink.activity_details == details);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/main-signal-binder/bind-forwards-all-main-controller-signals-to-sink",
                  test_bind_forwards_all_main_controller_signals_to_sink);
    return Test.run();
}

}
