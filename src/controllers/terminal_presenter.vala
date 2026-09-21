namespace HolderLinux {

public class PrerequisitePresentation : Object {
    public string title { get; construct; }
    public string detail { get; construct; }
    public bool install_available { get; construct; }
    public bool manual_link_visible { get; construct; }

    public PrerequisitePresentation(string title,
                                    string detail,
                                    bool install_available,
                                    bool manual_link_visible) {
        Object(
            title: title,
            detail: detail,
            install_available: install_available,
            manual_link_visible: manual_link_visible
        );
    }
}

public class SessionListPresentation : Object {
    public string text { get; construct; }
    public bool visible { get; construct; }

    public SessionListPresentation(string text, bool visible) {
        Object(text: text, visible: visible);
    }
}

// Text and decisions for the Windows external-terminal view.
public class TerminalPresenter { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public const uint INSTALL_POLL_INTERVAL_SECONDS = 3;
    public const int INSTALL_POLL_MAX_COUNT = 40;
    public const string NOT_READY_MESSAGE = "PowerShell 7 is not ready yet.";
    public const string SELECT_PROJECT_MESSAGE = "Select a project first.";
    public const string SELECT_TEXT_MESSAGE = "Select terminal text first.";
    public const string NOTHING_TO_COPY_MESSAGE = "Terminal has no text to copy.";
    public const string NO_SESSION_TITLE = "No terminal selected";

    private const string INSTALL_PURPOSE =
        "Holder uses PowerShell 7 to preserve useful terminal commands and output in your cards.";

    public static string session_state_text(TerminalSessionState state) {
        switch (state) {
        case TerminalSessionState.ACTIVE:
            return "Recording";
        case TerminalSessionState.COMPLETED:
            return "Completed";
        default:
            return "Interrupted";
        }
    }

    public static string session_title(TerminalSession session) {
        return session.card_label ?? session.project_label;
    }

    public static string session_row_subtitle(TerminalSession session, TimeZone time_zone) {
        var created = new DateTime.from_unix_utc(session.created_at).to_timezone(time_zone);
        return "%s · %s".printf(
            session_state_text(session.state),
            created.format("%d %b %H:%M")
        );
    }

    public static bool interrupted_notice_visible(TerminalSessionState state) {
        return state == TerminalSessionState.INTERRUPTED;
    }

    public static PrerequisitePresentation prerequisite_presentation(PowerShellPrerequisites current) {
        var automatic_install_available = current.winget_path != null
                                           && current.windows_terminal_path != null;
        switch (current.status) {
        case PowerShellPrerequisiteStatus.POWERSHELL_MISSING:
            return new PrerequisitePresentation(
                "PowerShell 7 is required",
                power_shell_install_detail(current),
                automatic_install_available,
                true
            );
        case PowerShellPrerequisiteStatus.POWERSHELL_UNSUPPORTED:
            return new PrerequisitePresentation(
                "A newer PowerShell is required",
                "Holder found PowerShell %s, but PowerShell 7 or newer is required. %s".printf(
                    current.powershell_version ?? "",
                    power_shell_install_detail(current)
                ),
                automatic_install_available,
                true
            );
        case PowerShellPrerequisiteStatus.WINDOWS_TERMINAL_MISSING:
            return new PrerequisitePresentation(
                "Windows Terminal is required",
                "PowerShell 7 is ready, but Holder could not find Windows Terminal (wt.exe).",
                false,
                false
            );
        default:
            return new PrerequisitePresentation(
                "Could not check PowerShell 7",
                current.details.length > 0
                    ? current.details
                    : "Holder could not verify the PowerShell installation.",
                false,
                true
            );
        }
    }

    public static string power_shell_install_detail(PowerShellPrerequisites current) {
        if (current.winget_path == null && current.windows_terminal_path == null) {
            return "%s Automatic installation is unavailable because Holder could not find Windows Terminal or WinGet; use the Microsoft link below."
                .printf(INSTALL_PURPOSE);
        }
        if (current.windows_terminal_path == null) {
            return "%s Automatic installation is unavailable because Holder could not find Windows Terminal; use the Microsoft link below."
                .printf(INSTALL_PURPOSE);
        }
        if (current.winget_path == null) {
            return "%s Automatic installation is unavailable because Holder could not find WinGet; use the Microsoft link below."
                .printf(INSTALL_PURPOSE);
        }
        return INSTALL_PURPOSE;
    }

    public static bool install_poll_exhausted(int poll_count) {
        return poll_count >= INSTALL_POLL_MAX_COUNT;
    }

    public static bool new_terminal_enabled(bool has_project, PowerShellPrerequisites? prerequisites) {
        return has_project && prerequisites != null && ((!) prerequisites).ready;
    }

    // Returns the toast explaining why a new terminal cannot open, or null when it can.
    public static string? new_terminal_block_message(PowerShellPrerequisites? prerequisites,
                                                     bool has_project) {
        if (prerequisites == null || !((!) prerequisites).ready) {
            return NOT_READY_MESSAGE;
        }
        if (!has_project) {
            return SELECT_PROJECT_MESSAGE;
        }
        return null;
    }

    public static SessionListPresentation sessions_for_no_project() {
        return new SessionListPresentation("Select a project, then open a terminal.", true);
    }

    public static SessionListPresentation sessions_for_loaded(int session_count) {
        return new SessionListPresentation(
            "No terminal sessions for this project yet.",
            session_count == 0
        );
    }

    public static SessionListPresentation sessions_for_load_failure() {
        return new SessionListPresentation("Could not load terminal sessions.", true);
    }

    public static string transcript_text(PowerShellTranscriptSnapshot snapshot, bool raw) {
        return raw ? snapshot.raw_text : snapshot.useful_text;
    }

    public static bool has_copyable_text(string text) {
        return text.strip().length > 0;
    }

    // Returns the text "Copy All" should send to the card, or null when there is nothing to copy.
    public static string? copy_all_text(PowerShellTranscriptSnapshot? snapshot, bool raw) {
        if (snapshot == null) {
            return null;
        }
        var text = transcript_text((!) snapshot, raw);
        return has_copyable_text(text) ? text : null;
    }
}

}
