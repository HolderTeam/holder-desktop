using GLib;

namespace HolderLinuxTests {

private class SaveFixture : Object {
    public MainControllerFakeApi api { get; private set; }
    public FakeEditorRecoveryDraftService drafts { get; private set; }
    public TestScheduler scheduler = new TestScheduler();
    public MainControllerTestHarness harness;
    public HolderLinux.MainController controller;
    public Gee.ArrayList<string> errors = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> toasts = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> statuses = new Gee.ArrayList<string>();
    public int tag_signals = 0;
    public int last_tag_count = -1;

    public SaveFixture(Settings? settings = null) {
        api = new MainControllerFakeApi();
        drafts = new FakeEditorRecoveryDraftService();
        harness = new MainControllerTestHarness(
            api, scheduler, new FakeClock(), null, null, true, drafts, null, settings
        );
        controller = harness.controller;
        controller.error_reported.connect((title, details) => { errors.add(title); });
        controller.toast_requested.connect((message) => { toasts.add(message); });
        controller.status_changed.connect((text) => { statuses.add(text); });
        controller.validated_tag_occurrences_changed.connect((occurrences) => {
            tag_signals++;
            last_tag_count = occurrences.length;
        });
    }

    public void load_card() {
        controller.reload_everything.begin();
        assert(wait_for_condition(() => controller.get_current_project() != null));
        harness.card_selection.set_selected_index(0);
        controller.load_card_by_id.begin("c1");
        assert(wait_for_condition(() => controller.get_current_card() != null));
    }

    public void type(string text) {
        harness.editor_text.value = text;
        controller.on_editor_content_changed();
    }

    public bool save_now() {
        bool done = false;
        bool result = false;
        controller.save_now.begin((obj, res) => {
            result = controller.save_now.end(res);
            done = true;
        });
        assert(wait_for_condition(() => done));
        return result;
    }

    public void autosave() {
        bool done = false;
        controller.autosave_current_card.begin((obj, res) => {
            controller.autosave_current_card.end(res);
            done = true;
        });
        assert(wait_for_condition(() => done));
    }

    public void flush_before_navigation() {
        bool done = false;
        controller.save_before_navigation.begin((obj, res) => {
            controller.save_before_navigation.end(res);
            done = true;
        });
        assert(wait_for_condition(() => done));
    }
}

private void test_save_now_without_changes_toasts_saved() {
    var f = new SaveFixture();
    f.load_card();

    assert(f.save_now());
    assert(f.toasts.contains("Card saved"));
    assert(f.api.update_card_calls == 0);
}

private void test_save_now_reports_recovery_failure_once_and_still_saves() {
    var f = new SaveFixture();
    f.load_card();
    f.drafts.fail_save = true;

    f.type("# Changed\n\nText");
    assert(f.save_now());
    assert(f.api.update_card_calls == 1);
    assert(f.errors.contains("Could not create a recovery copy"));

    var reported = f.errors.size;
    f.type("# Changed again\n\nText");
    f.autosave();
    assert(f.api.update_card_calls == 2);
    assert(f.errors.size == reported);
}

private void test_save_now_backend_failure_keeps_recovery_copy_and_says_so() {
    var f = new SaveFixture();
    f.load_card();
    f.api.fail_update_card = true;

    f.type("# Changed\n\nText");
    assert(!f.save_now());
    assert(f.drafts.save_calls >= 1);
    assert(f.toasts.contains("The backend did not respond; your recovery copy is safe on this device."));
    assert(f.controller.has_pending_autosave_retry());
}

private void test_save_now_during_in_flight_save_is_queued() {
    var f = new SaveFixture();
    f.load_card();

    bool inner_started = false;
    bool inner_done = false;
    bool inner_result = true;
    f.api.update_card_before_complete_hook = (card_id) => {
        if (inner_started) {
            return;
        }
        inner_started = true;
        f.controller.save_now.begin((obj, res) => {
            inner_result = f.controller.save_now.end(res);
            inner_done = true;
        });
    };

    f.type("# Changed\n\nText");
    assert(f.save_now());
    assert(inner_done);
    assert(!inner_result);
    assert(f.statuses.contains("Saving..."));
    assert(f.api.update_card_calls == 1);
}

private void test_explicit_save_cancels_pending_autosave() {
    var f = new SaveFixture();
    f.load_card();

    var draft = new HolderLinux.EditorRecoveryDraft("c1", "p1", "Recovered", "# Recovered\n\nText", 5);
    f.controller.restore_recovery_draft(draft);
    assert(f.save_now());
    assert(f.api.last_updated_content == "# Recovered\n\nText");
    f.scheduler.run_all_once();
    assert(f.api.update_card_calls == 1);
}

private void test_no_backend_saves_recovery_draft_locally() {
    var f = new SaveFixture();
    f.load_card();
    f.controller.api = null;

    f.type("# Offline\n\nText");
    f.autosave();
    assert(f.statuses.contains("Backend unavailable, saved recovery draft locally"));
    assert(f.drafts.drafts.has_key("c1"));
}

private void test_no_backend_and_recovery_write_failure_says_no_copy() {
    var f = new SaveFixture();
    f.load_card();
    f.controller.api = null;
    f.drafts.fail_save = true;

    f.type("# Offline\n\nText");
    f.autosave();
    assert(f.statuses.contains("Backend unavailable; no local recovery copy could be written"));
    assert(f.errors.contains("Could not create a recovery copy"));
}

private void test_no_backend_with_recovery_files_disabled_says_so() {
    var settings = new Settings("team.holder.Holder");
    settings.set_boolean("no-plaintext-recovery-files", true);
    var f = new SaveFixture(settings);
    f.load_card();
    f.controller.api = null;

    f.type("# Offline\n\nText");
    f.autosave();
    assert(f.statuses.contains("Backend unavailable; recovery files are disabled"));
    assert(f.drafts.save_calls == 0);
    assert(!f.controller.plaintext_recovery_enabled());
    settings.reset("no-plaintext-recovery-files");
}

private void test_failed_save_after_card_changed_does_not_schedule_retry() {
    var f = new SaveFixture();
    f.load_card();
    f.api.fail_update_card_after_hook = true;
    f.api.update_card_before_complete_hook = (card_id) => {
        f.controller.current_card = null;
    };

    f.type("# Changed\n\nText");
    f.autosave();
    assert(!f.controller.has_pending_autosave_retry());
}

private void test_successful_save_after_card_changed_skips_tag_refresh() {
    var f = new SaveFixture();
    f.load_card();
    f.api.update_card_before_complete_hook = (card_id) => {
        f.controller.current_card = null;
    };

    f.type("# Changed #tag\n\nText");
    f.autosave();
    assert(f.api.update_card_calls == 1);
    assert(f.tag_signals == 0);
}

private void test_saved_text_without_hash_clears_tag_occurrences() {
    var f = new SaveFixture();
    f.load_card();

    f.type("Plain text with no tags");
    f.autosave();
    assert(f.tag_signals == 1);
    assert(f.last_tag_count == 0);
}

private void test_tag_refresh_failure_keeps_current_occurrences() {
    var f = new SaveFixture();
    f.load_card();
    f.api.fail_get_card = true;

    f.type("# Title #tag");
    f.autosave();
    assert(f.api.update_card_calls == 1);
    assert(f.tag_signals == 1);
}

private void test_recovery_snapshot_failure_is_reported_once() {
    var f = new SaveFixture();
    f.load_card();
    f.drafts.fail_save = true;

    f.type("# Changed\n\nText");
    f.scheduler.run_all_once();
    assert(f.errors.size == 1);
    f.type("# Changed more\n\nText");
    f.scheduler.run_all_once();
    assert(f.errors.size == 1);
    assert(f.errors[0] == "Could not create a recovery copy");
}

private void test_flush_before_navigation_without_changes_returns_immediately() {
    var f = new SaveFixture();
    f.load_card();

    f.flush_before_navigation();
    assert(f.api.update_card_calls == 0);
}

private void test_flush_before_navigation_waits_for_in_flight_save() {
    var f = new SaveFixture();
    f.load_card();
    f.api.update_card_before_complete_hook = (card_id) => {};

    f.type("# Changed\n\nText");
    f.flush_before_navigation();
    assert(f.api.update_card_calls == 1);
    assert(!f.controller.is_editor_save_in_flight());
    assert(f.drafts.save_calls >= 1);
}

private void test_flush_before_navigation_reports_recovery_failure_and_still_saves() {
    var f = new SaveFixture();
    f.load_card();
    f.drafts.fail_save = true;

    f.type("# Changed\n\nText");
    f.flush_before_navigation();
    assert(f.errors.contains("Could not create a recovery copy"));
    assert(f.api.update_card_calls == 1);
}

private void test_tidy_text_and_plaintext_recovery_defaults() {
    var f = new SaveFixture();
    assert(f.controller.tidy_text_for_save("keep  \n") == "keep  \n");
    assert(f.controller.plaintext_recovery_enabled());
}

private void test_discard_recovery_draft_removes_or_reports_failure() {
    var f = new SaveFixture();
    f.drafts.drafts.set("c1", new HolderLinux.EditorRecoveryDraft("c1", "p1", "T", "# T", 1));

    f.controller.discard_recovery_draft("c1");
    assert(f.drafts.remove_calls == 1);
    assert(!f.drafts.drafts.has_key("c1"));

    f.drafts.fail_remove = true;
    f.controller.discard_recovery_draft("c1");
    assert(f.errors.contains("Could not discard recovery copy"));
}

private void test_inspect_recovery_draft_failure_is_reported() {
    var f = new SaveFixture();
    f.drafts.fail_load = true;

    f.controller.inspect_recovery_draft(new HolderLinux.CardDetail("c1", "p1", "T", "# T", 1));
    assert(f.errors.contains("Could not inspect recovery copy"));
}

private void test_restore_recovery_draft_for_another_card_is_ignored() {
    var f = new SaveFixture();
    f.load_card();
    var before = f.harness.editor_text.value;

    f.controller.restore_recovery_draft(
        new HolderLinux.EditorRecoveryDraft("other-card", "p1", "Other", "# Other", 1)
    );
    assert(f.harness.editor_text.value == before);
    assert(!f.controller.has_unsaved_editor_changes());
}

private void test_resource_reference_snippets_for_missing_and_blank_kinds() {
    var f = new SaveFixture();
    var resource = new HolderLinux.ProjectResource("r1", "p1", "image", "", "Photo", null, 1, 2);
    resource.referenced_by_cards.add(new HolderLinux.ResourceCardReference(
        "card-1", "No kinds", 1, new Gee.ArrayList<string>()
    ));
    var blank_kinds = new Gee.ArrayList<string>();
    blank_kinds.add("");
    resource.referenced_by_cards.add(new HolderLinux.ResourceCardReference(
        "card-2", "Blank kind", 2, blank_kinds
    ));

    f.controller.show_resource_references(resource);
    var first = f.harness.search_store.get_item(0) as HolderLinux.SearchCardResult;
    var second = f.harness.search_store.get_item(1) as HolderLinux.SearchCardResult;
    assert(first != null && first.snippet == "Linked resource");
    assert(second != null && second.snippet == "Linked");
}

public static int main(string[] args) {
    Test.init(ref args);
    Log.set_always_fatal(LogLevelFlags.LEVEL_ERROR);

    Test.add_func("/editor_save/save_now_without_changes_toasts_saved",
                  test_save_now_without_changes_toasts_saved);
    Test.add_func("/editor_save/save_now_reports_recovery_failure_once_and_still_saves",
                  test_save_now_reports_recovery_failure_once_and_still_saves);
    Test.add_func("/editor_save/save_now_backend_failure_keeps_recovery_copy_and_says_so",
                  test_save_now_backend_failure_keeps_recovery_copy_and_says_so);
    Test.add_func("/editor_save/save_now_during_in_flight_save_is_queued",
                  test_save_now_during_in_flight_save_is_queued);
    Test.add_func("/editor_save/explicit_save_cancels_pending_autosave",
                  test_explicit_save_cancels_pending_autosave);
    Test.add_func("/editor_save/no_backend_saves_recovery_draft_locally",
                  test_no_backend_saves_recovery_draft_locally);
    Test.add_func("/editor_save/no_backend_and_recovery_write_failure_says_no_copy",
                  test_no_backend_and_recovery_write_failure_says_no_copy);
    Test.add_func("/editor_save/no_backend_with_recovery_files_disabled_says_so",
                  test_no_backend_with_recovery_files_disabled_says_so);
    Test.add_func("/editor_save/failed_save_after_card_changed_does_not_schedule_retry",
                  test_failed_save_after_card_changed_does_not_schedule_retry);
    Test.add_func("/editor_save/successful_save_after_card_changed_skips_tag_refresh",
                  test_successful_save_after_card_changed_skips_tag_refresh);
    Test.add_func("/editor_save/saved_text_without_hash_clears_tag_occurrences",
                  test_saved_text_without_hash_clears_tag_occurrences);
    Test.add_func("/editor_save/tag_refresh_failure_keeps_current_occurrences",
                  test_tag_refresh_failure_keeps_current_occurrences);
    Test.add_func("/editor_save/recovery_snapshot_failure_is_reported_once",
                  test_recovery_snapshot_failure_is_reported_once);
    Test.add_func("/editor_save/flush_before_navigation_without_changes_returns_immediately",
                  test_flush_before_navigation_without_changes_returns_immediately);
    Test.add_func("/editor_save/flush_before_navigation_waits_for_in_flight_save",
                  test_flush_before_navigation_waits_for_in_flight_save);
    Test.add_func("/editor_save/flush_before_navigation_reports_recovery_failure_and_still_saves",
                  test_flush_before_navigation_reports_recovery_failure_and_still_saves);
    Test.add_func("/editor_save/tidy_text_and_plaintext_recovery_defaults",
                  test_tidy_text_and_plaintext_recovery_defaults);
    Test.add_func("/editor_save/discard_recovery_draft_removes_or_reports_failure",
                  test_discard_recovery_draft_removes_or_reports_failure);
    Test.add_func("/editor_save/inspect_recovery_draft_failure_is_reported",
                  test_inspect_recovery_draft_failure_is_reported);
    Test.add_func("/editor_save/restore_recovery_draft_for_another_card_is_ignored",
                  test_restore_recovery_draft_for_another_card_is_ignored);
    Test.add_func("/editor_save/resource_reference_snippets_for_missing_and_blank_kinds",
                  test_resource_reference_snippets_for_missing_and_blank_kinds);

    return Test.run();
}

}
