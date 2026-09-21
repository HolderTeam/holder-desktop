using GLib;

namespace HolderLinuxTests {

// ---- Verbatim copies of the decisions terminal_tool_view_windows.vala used to make inline ----

private string original_install_detail(HolderLinux.PowerShellPrerequisites current) {
    const string PURPOSE =
        "Holder uses PowerShell 7 to preserve useful terminal commands and output in your cards.";
    if (current.winget_path == null && current.windows_terminal_path == null) {
        return "%s Automatic installation is unavailable because Holder could not find Windows Terminal or WinGet; use the Microsoft link below."
            .printf(PURPOSE);
    }
    if (current.windows_terminal_path == null) {
        return "%s Automatic installation is unavailable because Holder could not find Windows Terminal; use the Microsoft link below."
            .printf(PURPOSE);
    }
    if (current.winget_path == null) {
        return "%s Automatic installation is unavailable because Holder could not find WinGet; use the Microsoft link below."
            .printf(PURPOSE);
    }
    return PURPOSE;
}

// Mirrors render_prerequisites(): the widget writes it performed, captured as values.
private void original_render_prerequisites(HolderLinux.PowerShellPrerequisites current,
                                           out string title,
                                           out string detail,
                                           out bool install_visible,
                                           out bool link_visible) {
    title = "";
    detail = "";
    install_visible = false;
    link_visible = false;
    var automatic_install_available = current.winget_path != null
                                       && current.windows_terminal_path != null;
    switch (current.status) {
    case HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_MISSING:
        title = "PowerShell 7 is required";
        detail = original_install_detail(current);
        install_visible = automatic_install_available;
        link_visible = true;
        break;
    case HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_UNSUPPORTED:
        title = "A newer PowerShell is required";
        detail = "Holder found PowerShell %s, but PowerShell 7 or newer is required. %s"
            .printf(current.powershell_version ?? "", original_install_detail(current));
        install_visible = automatic_install_available;
        link_visible = true;
        break;
    case HolderLinux.PowerShellPrerequisiteStatus.WINDOWS_TERMINAL_MISSING:
        title = "Windows Terminal is required";
        detail = "PowerShell 7 is ready, but Holder could not find Windows Terminal (wt.exe).";
        break;
    default:
        title = "Could not check PowerShell 7";
        detail = current.details.length > 0
            ? current.details
            : "Holder could not verify the PowerShell installation.";
        link_visible = true;
        break;
    }
}

private string original_state_text(HolderLinux.TerminalSessionState state) {
    switch (state) {
    case HolderLinux.TerminalSessionState.ACTIVE:
        return "Recording";
    case HolderLinux.TerminalSessionState.COMPLETED:
        return "Completed";
    default:
        return "Interrupted";
    }
}

private HolderLinux.TerminalSession make_session(string? card_label,
                                                 HolderLinux.TerminalSessionState state,
                                                 int64 created_at = 1700000000) {
    return new HolderLinux.TerminalSession(
        "s1", "p1", "Project One", card_label != null ? "c1" : null, card_label,
        "/tmp/work", "/tmp/t.txt", "/tmp/b.ps1", created_at, 0, state
    );
}

private HolderLinux.PowerShellPrerequisites make_prereqs(HolderLinux.PowerShellPrerequisiteStatus status,
                                                        string? version,
                                                        bool has_terminal,
                                                        bool has_winget,
                                                        string details) {
    return new HolderLinux.PowerShellPrerequisites(
        status,
        status == HolderLinux.PowerShellPrerequisiteStatus.READY ? "pwsh.exe" : null,
        version,
        has_terminal ? "wt.exe" : null,
        has_winget ? "winget.exe" : null,
        details
    );
}

private void test_prerequisite_presentation_matches_the_original_for_every_combination() {
    HolderLinux.PowerShellPrerequisiteStatus[] statuses = {
        HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_MISSING,
        HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_UNSUPPORTED,
        HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_QUERY_FAILED,
        HolderLinux.PowerShellPrerequisiteStatus.WINDOWS_TERMINAL_MISSING
    };
    int compared = 0;
    for (int si = 0; si < statuses.length; si++) {
        for (int v = 0; v < 2; v++) {
            for (int t = 0; t < 2; t++) {
                for (int w = 0; w < 2; w++) {
                    for (int d = 0; d < 2; d++) {
                        var current = make_prereqs(
                            statuses[si], v == 0 ? null : "5.1.1", t == 1, w == 1, d == 0 ? "" : "boom"
                        );
                        string title, detail;
                        bool install_visible, link_visible;
                        original_render_prerequisites(
                            current, out title, out detail, out install_visible, out link_visible
                        );
                        var presentation = HolderLinux.TerminalPresenter.prerequisite_presentation(current);
                        assert(presentation.title == title);
                        assert(presentation.detail == detail);
                        assert(presentation.install_available == install_visible);
                        assert(presentation.manual_link_visible == link_visible);
                        compared++;
                    }
                }
            }
        }
    }
    assert(compared == 4 * 2 * 2 * 2 * 2);
}

private void test_install_detail_names_whichever_tool_is_missing() {
    var both_missing = make_prereqs(HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_MISSING, null, false, false, "");
    var no_terminal = make_prereqs(HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_MISSING, null, false, true, "");
    var no_winget = make_prereqs(HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_MISSING, null, true, false, "");
    var both_present = make_prereqs(HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_MISSING, null, true, true, "");
    assert(HolderLinux.TerminalPresenter.power_shell_install_detail(both_missing).contains("Windows Terminal or WinGet"));
    assert(!HolderLinux.TerminalPresenter.power_shell_install_detail(no_terminal).contains("WinGet"));
    assert(HolderLinux.TerminalPresenter.power_shell_install_detail(no_terminal).contains("Windows Terminal;"));
    assert(HolderLinux.TerminalPresenter.power_shell_install_detail(no_winget).contains("find WinGet;"));
    assert(!HolderLinux.TerminalPresenter.power_shell_install_detail(both_present).contains("unavailable"));
    assert(HolderLinux.TerminalPresenter.prerequisite_presentation(both_present).install_available);
}

private void test_session_text_matches_the_original() {
    HolderLinux.TerminalSessionState[] states = {
        HolderLinux.TerminalSessionState.ACTIVE,
        HolderLinux.TerminalSessionState.COMPLETED,
        HolderLinux.TerminalSessionState.INTERRUPTED
    };
    for (int i = 0; i < states.length; i++) {
        assert(HolderLinux.TerminalPresenter.session_state_text(states[i]) == original_state_text(states[i]));
        assert(HolderLinux.TerminalPresenter.interrupted_notice_visible(states[i])
               == (states[i] == HolderLinux.TerminalSessionState.INTERRUPTED));
    }
    assert(HolderLinux.TerminalPresenter.session_title(make_session("Card One", HolderLinux.TerminalSessionState.ACTIVE)) == "Card One");
    assert(HolderLinux.TerminalPresenter.session_title(make_session(null, HolderLinux.TerminalSessionState.ACTIVE)) == "Project One");
}

private void test_row_subtitle_matches_the_original_local_time_formatting_and_honours_the_zone() {
    var session = make_session(null, HolderLinux.TerminalSessionState.COMPLETED, 1700000000);
    // Original: DateTime.from_unix_local(created_at).format("%d %b %H:%M")
    var original_created = new DateTime.from_unix_local(session.created_at);
    var original = "%s · %s".printf(original_state_text(session.state), original_created.format("%d %b %H:%M"));
    assert(HolderLinux.TerminalPresenter.session_row_subtitle(session, new TimeZone.local()) == original);

    assert(HolderLinux.TerminalPresenter.session_row_subtitle(session, new TimeZone.utc())
           == "Completed · 14 Nov 22:13");
    // Fixed offset: named zones need a tz database, which the Windows CI runner lacks.
    TimeZone tokyo;
    try {
        tokyo = new TimeZone.identifier("+09:00");
    } catch (Error e) {
        assert_not_reached();
    }
    assert(HolderLinux.TerminalPresenter.session_row_subtitle(session, tokyo)
           == "Completed · 15 Nov 07:13");
}

private void test_install_polling_stops_after_forty_polls() {
    assert(HolderLinux.TerminalPresenter.INSTALL_POLL_INTERVAL_SECONDS == 3);
    assert(!HolderLinux.TerminalPresenter.install_poll_exhausted(1));
    assert(!HolderLinux.TerminalPresenter.install_poll_exhausted(39));
    assert(HolderLinux.TerminalPresenter.install_poll_exhausted(40));
    assert(HolderLinux.TerminalPresenter.install_poll_exhausted(41));
}

private void test_new_terminal_gating_matches_the_original_ladder() {
    var ready = make_prereqs(HolderLinux.PowerShellPrerequisiteStatus.READY, "7.4", true, true, "");
    var missing = make_prereqs(HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_MISSING, null, true, true, "");

    assert(HolderLinux.TerminalPresenter.new_terminal_enabled(true, ready));
    assert(!HolderLinux.TerminalPresenter.new_terminal_enabled(false, ready));
    assert(!HolderLinux.TerminalPresenter.new_terminal_enabled(true, missing));
    assert(!HolderLinux.TerminalPresenter.new_terminal_enabled(true, null));

    // Prerequisites are checked before the project, as in the original open_new_terminal().
    assert(HolderLinux.TerminalPresenter.new_terminal_block_message(null, false) == "PowerShell 7 is not ready yet.");
    assert(HolderLinux.TerminalPresenter.new_terminal_block_message(missing, true) == "PowerShell 7 is not ready yet.");
    assert(HolderLinux.TerminalPresenter.new_terminal_block_message(ready, false) == "Select a project first.");
    assert(HolderLinux.TerminalPresenter.new_terminal_block_message(ready, true) == null);
}

private void test_session_list_presentations() {
    var none = HolderLinux.TerminalPresenter.sessions_for_no_project();
    assert(none.text == "Select a project, then open a terminal.");
    assert(none.visible);

    var empty = HolderLinux.TerminalPresenter.sessions_for_loaded(0);
    assert(empty.text == "No terminal sessions for this project yet.");
    assert(empty.visible);
    assert(!HolderLinux.TerminalPresenter.sessions_for_loaded(3).visible);

    var failed = HolderLinux.TerminalPresenter.sessions_for_load_failure();
    assert(failed.text == "Could not load terminal sessions.");
    assert(failed.visible);
}

private void test_transcript_text_and_copy_decisions() {
    var snapshot = new HolderLinux.PowerShellTranscriptSnapshot("raw text", "useful text", false);
    assert(HolderLinux.TerminalPresenter.transcript_text(snapshot, true) == "raw text");
    assert(HolderLinux.TerminalPresenter.transcript_text(snapshot, false) == "useful text");

    assert(HolderLinux.TerminalPresenter.has_copyable_text("x"));
    assert(!HolderLinux.TerminalPresenter.has_copyable_text(""));
    assert(!HolderLinux.TerminalPresenter.has_copyable_text("  \n\t "));

    assert(HolderLinux.TerminalPresenter.copy_all_text(snapshot, false) == "useful text");
    assert(HolderLinux.TerminalPresenter.copy_all_text(snapshot, true) == "raw text");
    assert(HolderLinux.TerminalPresenter.copy_all_text(null, false) == null);
    var blank = new HolderLinux.PowerShellTranscriptSnapshot("raw", "   ", true);
    assert(HolderLinux.TerminalPresenter.copy_all_text(blank, false) == null);
    assert(HolderLinux.TerminalPresenter.copy_all_text(blank, true) == "raw");

    assert(HolderLinux.TerminalPresenter.NO_SESSION_TITLE == "No terminal selected");
    assert(HolderLinux.TerminalPresenter.SELECT_TEXT_MESSAGE == "Select terminal text first.");
    assert(HolderLinux.TerminalPresenter.NOTHING_TO_COPY_MESSAGE == "Terminal has no text to copy.");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/terminal-presenter/prerequisites-match-original",
                  test_prerequisite_presentation_matches_the_original_for_every_combination);
    Test.add_func("/holder/terminal-presenter/install-detail", test_install_detail_names_whichever_tool_is_missing);
    Test.add_func("/holder/terminal-presenter/session-text", test_session_text_matches_the_original);
    Test.add_func("/holder/terminal-presenter/row-subtitle",
                  test_row_subtitle_matches_the_original_local_time_formatting_and_honours_the_zone);
    Test.add_func("/holder/terminal-presenter/install-polling", test_install_polling_stops_after_forty_polls);
    Test.add_func("/holder/terminal-presenter/new-terminal-gating", test_new_terminal_gating_matches_the_original_ladder);
    Test.add_func("/holder/terminal-presenter/session-list", test_session_list_presentations);
    Test.add_func("/holder/terminal-presenter/transcript-and-copy", test_transcript_text_and_copy_decisions);
    return Test.run();
}

}
