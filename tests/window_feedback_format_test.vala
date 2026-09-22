private void test_serious_status_classification() {
    assert(HolderLinux.WindowFeedbackFormat.is_serious_status("Connecting to backend"));
    assert(HolderLinux.WindowFeedbackFormat.is_serious_status("Backend unavailable"));
    assert(HolderLinux.WindowFeedbackFormat.is_serious_status("Request timeout"));
    assert(!HolderLinux.WindowFeedbackFormat.is_serious_status("Loaded project"));
}

private void test_activity_debug_line_without_scope() {
    var line = HolderLinux.WindowFeedbackFormat.activity_debug_line(
        "feedback.toast",
        "Saved"
    );

    assert(line == "ACTIVITY feedback.toast Saved");
}

private void test_activity_debug_line_with_project_and_card_scope() {
    var line = HolderLinux.WindowFeedbackFormat.activity_debug_line(
        "intent.card.select",
        "Card selected",
        "project-1",
        "card-2"
    );

    assert(line == "ACTIVITY intent.card.select Card selected [project=project-1, card=card-2]");
}

private void test_activity_debug_line_with_ai_details() {
    var details = new HolderLinux.AiRunDetails(
        "thread-1",
        "run-2",
        "local",
        "llama",
        "router",
        123,
        true
    );
    var line = HolderLinux.WindowFeedbackFormat.activity_debug_line(
        "result.ai.run",
        "Run completed",
        "project-1",
        "card-2",
        details
    );

    assert(line == "ACTIVITY result.ai.run Run completed " +
                   "[project=project-1, card=card-2, thread=thread-1, run=run-2, " +
                   "provider=local, model=llama, router=router, prompt_chars=123, success=true]");
}

private void test_activity_debug_line_omits_blank_ai_detail_fields() {
    var details = new HolderLinux.AiRunDetails("", "", "", "", "", 0, false);
    var line = HolderLinux.WindowFeedbackFormat.activity_debug_line(
        "result.ai.run",
        "Run failed",
        null,
        null,
        details
    );

    assert(line == "ACTIVITY result.ai.run Run failed [success=false]");
}

private void test_error_text_and_debug_line() {
    assert(HolderLinux.WindowFeedbackFormat.error_status_text("Save failed", "disk full") ==
           "Save failed: disk full");
    assert(HolderLinux.WindowFeedbackFormat.error_debug_line("Save failed", "disk full") ==
           "ERROR: Save failed | disk full");
    // The status text is what is_serious_status inspects, so the details must stay in it.
    assert(HolderLinux.WindowFeedbackFormat.is_serious_status(
        HolderLinux.WindowFeedbackFormat.error_status_text("Oops", "backend unavailable")
    ));
}

public int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/window-feedback-format/error-text-and-debug-line", test_error_text_and_debug_line);

    Test.add_func(
        "/holder/window-feedback-format/serious-status",
        test_serious_status_classification
    );
    Test.add_func(
        "/holder/window-feedback-format/activity-debug-line-without-scope",
        test_activity_debug_line_without_scope
    );
    Test.add_func(
        "/holder/window-feedback-format/activity-debug-line-with-project-and-card-scope",
        test_activity_debug_line_with_project_and_card_scope
    );
    Test.add_func(
        "/holder/window-feedback-format/activity-debug-line-with-ai-details",
        test_activity_debug_line_with_ai_details
    );
    Test.add_func(
        "/holder/window-feedback-format/activity-debug-line-omits-blank-ai-detail-fields",
        test_activity_debug_line_omits_blank_ai_detail_fields
    );

    return Test.run();
}
