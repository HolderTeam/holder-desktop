using GLib;

namespace HolderLinuxTests {

private string join_parts(string separator, Gee.List<string> parts) {
    var joined = new StringBuilder();
    bool first = true;
    foreach (var part in parts) {
        if (!first) {
            joined.append(separator);
        }
        joined.append(part);
        first = false;
    }
    return joined.str;
}

private void flush_main_context() {
    while (MainContext.default().iteration(false)) {}
}

private class FakeCloseHost : Object, HolderLinux.IWindowCloseHost {
    public bool unsaved = true;
    public bool in_flight = false;
    public bool recovery_result = false;
    public string? recovery_error = null;
    public bool save_result = true;
    public bool defer_save = false;
    public int save_calls { get; set; default = 0; }
    public int recovery_calls = 0;
    private SourceFunc? resume = null;
    private bool deferred_result = false;

    public bool has_unsaved_editor_changes() {
        return unsaved;
    }

    public bool is_editor_save_in_flight() {
        return in_flight;
    }

    public bool save_emergency_recovery_draft() throws Error {
        recovery_calls++;
        if (recovery_error != null) {
            throw new IOError.FAILED((!) recovery_error);
        }
        return recovery_result;
    }

    public async bool save_now() {
        save_calls++;
        if (defer_save) {
            resume = save_now.callback;
            yield;
            return deferred_result;
        }
        return save_result;
    }

    public void complete_save(bool result) {
        deferred_result = result;
        var callback = (owned) resume;
        resume = null;
        callback();
        flush_main_context();
    }
}

private interface CloseSubject : Object {
    public abstract string request_close();
    public abstract void settled(bool saved);
    public abstract void respond(string response);
}

// The window's original guarded-close code, kept verbatim (window.vala before the
// WindowCloseGuard extraction) except that the view calls become trace entries and the
// two GLib timeout calls go through the injected scheduler so timing is deterministic.
private class LegacyCloseSubject : Object, CloseSubject {
    private FakeCloseHost controller;
    private HolderLinux.IScheduler scheduler;
    private Gee.ArrayList<string> trace;
    private bool close_in_progress = false;
    private bool close_is_authorized = false;
    private uint close_timeout_id = 0;
    private bool close_has_recovery_copy = false;
    private string? close_recovery_error = null;
    private bool close_decision_visible = false;

    public LegacyCloseSubject(FakeCloseHost controller,
                              HolderLinux.IScheduler scheduler,
                              Gee.ArrayList<string> trace) {
        this.controller = controller;
        this.scheduler = scheduler;
        this.trace = trace;
    }

    public string request_close() {
        var blocked = on_window_close_requested();
        var text = blocked ? "block" : "allow";
        trace.add(text);
        flush_main_context();
        return text;
    }

    public void settled(bool saved) {
        if (!close_in_progress || controller.is_editor_save_in_flight()) {
            return;
        }
        if (saved && !controller.has_unsaved_editor_changes()) {
            finish_guarded_close();
        } else if (close_has_recovery_copy) {
            finish_guarded_close();
        } else {
            show_unsafe_close_dialog(close_recovery_error ??
                "The backend did not save this card and local recovery files are disabled.");
        }
    }

    public void respond(string response) {
        close_decision_visible = false;
        cancel_guarded_close();
        if (response == "retry") {
            trace.add("idle-close");
        } else if (response == "quit") {
            close_is_authorized = true;
            trace.add("close");
        }
    }

    private bool on_window_close_requested() {
        if (close_is_authorized) {
            return false;
        }
        if (!controller.has_unsaved_editor_changes() && !controller.is_editor_save_in_flight()) {
            return false;
        }
        if (close_in_progress) {
            return true;
        }

        close_in_progress = true;
        close_has_recovery_copy = false;
        close_recovery_error = null;
        try {
            close_has_recovery_copy = controller.save_emergency_recovery_draft();
        } catch (Error e) {
            close_recovery_error = e.message;
        }

        close_timeout_id = scheduler.schedule_once(2000, () => {
            close_timeout_id = 0;
            if ((!controller.has_unsaved_editor_changes() && !controller.is_editor_save_in_flight())
                || close_has_recovery_copy) {
                finish_guarded_close();
            } else {
                show_unsafe_close_dialog(close_recovery_error ??
                    "The backend did not finish saving and local recovery files are disabled.");
            }
            return Source.REMOVE;
        });
        controller.save_now.begin((obj, result) => {
            bool saved = controller.save_now.end(result);
            if (!close_in_progress) {
                return;
            }
            if (saved) {
                finish_guarded_close();
                return;
            }
            if (controller.is_editor_save_in_flight()) {
                return;
            }
            if (close_has_recovery_copy) {
                finish_guarded_close();
                return;
            }
            show_unsafe_close_dialog(close_recovery_error ??
                "The backend did not save this card and local recovery files are disabled.");
        });
        return true;
    }

    private void finish_guarded_close() {
        if (close_timeout_id != 0) {
            scheduler.cancel(close_timeout_id);
            close_timeout_id = 0;
        }
        close_in_progress = false;
        close_is_authorized = true;
        trace.add("close");
    }

    private void cancel_guarded_close() {
        if (close_timeout_id != 0) {
            scheduler.cancel(close_timeout_id);
            close_timeout_id = 0;
        }
        close_in_progress = false;
        close_has_recovery_copy = false;
        close_recovery_error = null;
        close_decision_visible = false;
    }

    private void show_unsafe_close_dialog(string details) {
        if (close_decision_visible) {
            return;
        }
        close_decision_visible = true;
        if (close_timeout_id != 0) {
            scheduler.cancel(close_timeout_id);
            close_timeout_id = 0;
        }
        trace.add("unsafe:" + details);
    }
}

private class GuardSubject : Object, CloseSubject {
    private HolderLinux.WindowCloseGuard guard;
    private Gee.ArrayList<string> trace;

    public GuardSubject(FakeCloseHost host,
                        HolderLinux.IScheduler scheduler,
                        Gee.ArrayList<string> trace) {
        this.trace = trace;
        guard = new HolderLinux.WindowCloseGuard(host, scheduler);
        guard.close_ready.connect(() => { trace.add("close"); });
        guard.unsafe_close_detected.connect((details) => { trace.add("unsafe:" + details); });
    }

    public string request_close() {
        var text = guard.request_close() == HolderLinux.WindowCloseDecision.BLOCK ? "block" : "allow";
        trace.add(text);
        flush_main_context();
        return text;
    }

    public void settled(bool saved) {
        guard.on_editor_save_settled(saved);
    }

    public void respond(string response) {
        var outcome = guard.resolve_unsafe_dialog(response);
        if (outcome == HolderLinux.WindowCloseDialogOutcome.RETRY) {
            trace.add("idle-close");
        } else if (outcome == HolderLinux.WindowCloseDialogOutcome.QUIT) {
            trace.add("close");
        }
    }
}

private delegate void CloseScript(CloseSubject subject, FakeCloseHost host, TestScheduler scheduler);

private string run_close_scenario(bool legacy, CloseScript script) {
    var host = new FakeCloseHost();
    var scheduler = new TestScheduler();
    var trace = new Gee.ArrayList<string>();
    CloseSubject subject = legacy
        ? (CloseSubject) new LegacyCloseSubject(host, scheduler, trace)
        : (CloseSubject) new GuardSubject(host, scheduler, trace);
    script(subject, host, scheduler);
    scheduler.run_all_once();
    trace.add("saves=%d recoveries=%d".printf(host.save_calls, host.recovery_calls));
    return join_parts("|", trace);
}

// Runs the script against the original code and the extracted guard, requires identical
// behaviour, and returns the trace so the test can also pin the expected outcome.
private string check_close_scenario(CloseScript script) {
    var expected = run_close_scenario(true, script);
    var actual = run_close_scenario(false, script);
    if (expected != actual) {
        stderr.printf("legacy: %s\nguard:  %s\n", expected, actual);
    }
    assert(expected == actual);
    return actual;
}

private void test_clean_editor_allows_close_without_side_effects() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.unsaved = false;
        subject.request_close();
    });
    assert(trace == "allow|saves=0 recoveries=0");
}

private void test_dirty_save_success_finishes_then_allows_close() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.save_result = true;
        subject.request_close();
        subject.request_close();
    });
    assert(trace == "block|close|allow|saves=1 recoveries=1");
}

private void test_dirty_save_failure_with_recovery_copy_finishes() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.save_result = false;
        host.recovery_result = true;
        subject.request_close();
    });
    assert(trace == "block|close|saves=1 recoveries=1");
}

private void test_dirty_save_failure_without_recovery_shows_unsafe_dialog() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.save_result = false;
        subject.request_close();
    });
    assert(trace == "block|unsafe:The backend did not save this card and local recovery files are disabled.|saves=1 recoveries=1");
}

private void test_recovery_error_replaces_default_details() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.save_result = false;
        host.recovery_error = "disk full";
        subject.request_close();
    });
    assert(trace == "block|unsafe:disk full|saves=1 recoveries=1");
}

// A failed save while another save is still running takes no action; only the timeout decides.
private void test_save_failure_while_another_save_is_in_flight_waits() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.save_result = false;
        host.in_flight = true;
        subject.request_close();
    });
    assert(trace == "block|unsafe:The backend did not finish saving and local recovery files are disabled.|saves=1 recoveries=1");
}

private void test_timeout_without_recovery_shows_unsafe_dialog() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.defer_save = true;
        subject.request_close();
        scheduler.run_all_once();
    });
    assert(trace == "block|unsafe:The backend did not finish saving and local recovery files are disabled.|saves=1 recoveries=1");
}

private void test_timeout_with_recovery_copy_finishes() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.defer_save = true;
        host.recovery_result = true;
        subject.request_close();
        scheduler.run_all_once();
    });
    assert(trace == "block|close|saves=1 recoveries=1");
}

private void test_timeout_when_editor_became_clean_finishes() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.defer_save = true;
        subject.request_close();
        host.unsaved = false;
        scheduler.run_all_once();
    });
    assert(trace == "block|close|saves=1 recoveries=1");
}

private void test_timeout_with_recovery_error_reports_that_error() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.defer_save = true;
        host.recovery_error = "no space";
        subject.request_close();
        scheduler.run_all_once();
    });
    assert(trace == "block|unsafe:no space|saves=1 recoveries=1");
}

private void test_repeated_requests_while_in_progress_block_without_restarting() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.defer_save = true;
        host.recovery_result = true;
        subject.request_close();
        subject.request_close();
        subject.request_close();
    });
    assert(trace == "block|block|block|close|saves=1 recoveries=1");
}

private void test_late_save_completion_after_finish_is_ignored() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.defer_save = true;
        subject.request_close();
        host.unsaved = false;
        scheduler.run_all_once();
        host.complete_save(false);
    });
    assert(trace == "block|close|saves=1 recoveries=1");
}

private void test_deferred_save_success_finishes_and_cancels_timeout() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.defer_save = true;
        subject.request_close();
        host.complete_save(true);
        scheduler.run_all_once();
    });
    assert(trace == "block|close|saves=1 recoveries=1");
}

private void test_settled_event_finishes_when_saved_and_clean() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.defer_save = true;
        subject.request_close();
        host.unsaved = false;
        subject.settled(true);
    });
    assert(trace == "block|close|saves=1 recoveries=1");
}

// Settled events are ignored before a close starts and while a save is in flight; the
// timeout at the end of the scenario is the only thing that produces the dialog.
private void test_settled_event_ignored_when_not_closing_or_save_in_flight() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        subject.settled(true);
        host.defer_save = true;
        subject.request_close();
        host.in_flight = true;
        subject.settled(true);
    });
    assert(trace == "block|unsafe:The backend did not finish saving and local recovery files are disabled.|saves=1 recoveries=1");
}

private void test_settled_event_with_recovery_copy_finishes_even_if_unsaved() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.defer_save = true;
        host.recovery_result = true;
        subject.request_close();
        subject.settled(false);
    });
    assert(trace == "block|close|saves=1 recoveries=1");
}

private void test_settled_event_without_recovery_shows_unsafe_dialog() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.defer_save = true;
        subject.request_close();
        subject.settled(false);
    });
    assert(trace == "block|unsafe:The backend did not save this card and local recovery files are disabled.|saves=1 recoveries=1");
}

private void test_settled_saved_but_still_dirty_uses_recovery_or_dialog() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.defer_save = true;
        subject.request_close();
        subject.settled(true);
    });
    assert(trace == "block|unsafe:The backend did not save this card and local recovery files are disabled.|saves=1 recoveries=1");
}

private void test_unsafe_dialog_is_only_raised_once_while_visible() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.defer_save = true;
        subject.request_close();
        scheduler.run_all_once();
        host.complete_save(false);
        subject.settled(false);
    });
    assert(trace == "block|unsafe:The backend did not finish saving and local recovery files are disabled.|saves=1 recoveries=1");
}

private void test_dialog_retry_resets_state_and_next_request_starts_over() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.save_result = false;
        subject.request_close();
        subject.respond("retry");
        subject.request_close();
    });
    assert(trace == "block|unsafe:The backend did not save this card and local recovery files are disabled.|idle-close|block|unsafe:The backend did not save this card and local recovery files are disabled.|saves=2 recoveries=2");
}

private void test_dialog_keep_editing_resets_state() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.save_result = false;
        subject.request_close();
        subject.respond("keep");
        subject.request_close();
    });
    assert(trace == "block|unsafe:The backend did not save this card and local recovery files are disabled.|block|unsafe:The backend did not save this card and local recovery files are disabled.|saves=2 recoveries=2");
}

private void test_dialog_quit_authorizes_the_next_close() {
    var trace = check_close_scenario((subject, host, scheduler) => {
        host.save_result = false;
        subject.request_close();
        subject.respond("quit");
        subject.request_close();
    });
    assert(trace == "block|unsafe:The backend did not save this card and local recovery files are disabled.|close|allow|saves=1 recoveries=1");
}

private void test_unsafe_dialog_body_and_constants() {
    assert(HolderLinux.WindowCloseGuard.unsafe_dialog_body("Why")
        == "Why\n\nRetry saving, keep Holder open, or quit and discard the unsaved changes.");
    assert(HolderLinux.WindowCloseGuard.SAVE_TIMEOUT_MS == 2000);
    assert(HolderLinux.WindowCloseGuard.UNSAFE_DIALOG_TITLE == "This card is not safely stored yet");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/window-close-guard/clean-editor-allows", test_clean_editor_allows_close_without_side_effects);
    Test.add_func("/window-close-guard/save-success", test_dirty_save_success_finishes_then_allows_close);
    Test.add_func("/window-close-guard/save-failure-with-recovery", test_dirty_save_failure_with_recovery_copy_finishes);
    Test.add_func("/window-close-guard/save-failure-without-recovery", test_dirty_save_failure_without_recovery_shows_unsafe_dialog);
    Test.add_func("/window-close-guard/recovery-error-details", test_recovery_error_replaces_default_details);
    Test.add_func("/window-close-guard/save-failure-in-flight-waits", test_save_failure_while_another_save_is_in_flight_waits);
    Test.add_func("/window-close-guard/timeout-without-recovery", test_timeout_without_recovery_shows_unsafe_dialog);
    Test.add_func("/window-close-guard/timeout-with-recovery", test_timeout_with_recovery_copy_finishes);
    Test.add_func("/window-close-guard/timeout-editor-clean", test_timeout_when_editor_became_clean_finishes);
    Test.add_func("/window-close-guard/timeout-recovery-error", test_timeout_with_recovery_error_reports_that_error);
    Test.add_func("/window-close-guard/repeated-requests", test_repeated_requests_while_in_progress_block_without_restarting);
    Test.add_func("/window-close-guard/late-save-ignored", test_late_save_completion_after_finish_is_ignored);
    Test.add_func("/window-close-guard/deferred-save-success", test_deferred_save_success_finishes_and_cancels_timeout);
    Test.add_func("/window-close-guard/settled-saved-and-clean", test_settled_event_finishes_when_saved_and_clean);
    Test.add_func("/window-close-guard/settled-ignored", test_settled_event_ignored_when_not_closing_or_save_in_flight);
    Test.add_func("/window-close-guard/settled-with-recovery", test_settled_event_with_recovery_copy_finishes_even_if_unsaved);
    Test.add_func("/window-close-guard/settled-without-recovery", test_settled_event_without_recovery_shows_unsafe_dialog);
    Test.add_func("/window-close-guard/settled-saved-but-dirty", test_settled_saved_but_still_dirty_uses_recovery_or_dialog);
    Test.add_func("/window-close-guard/unsafe-dialog-once", test_unsafe_dialog_is_only_raised_once_while_visible);
    Test.add_func("/window-close-guard/dialog-retry", test_dialog_retry_resets_state_and_next_request_starts_over);
    Test.add_func("/window-close-guard/dialog-keep", test_dialog_keep_editing_resets_state);
    Test.add_func("/window-close-guard/dialog-quit", test_dialog_quit_authorizes_the_next_close);
    Test.add_func("/window-close-guard/dialog-body-and-constants", test_unsafe_dialog_body_and_constants);
    return Test.run();
}

}
