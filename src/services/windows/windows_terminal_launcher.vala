namespace HolderLinux {

public class WindowsTerminalLauncher : Object {
    public string[] build_session_argv(PowerShellPrerequisites prerequisites,
                                       TerminalSession session) throws Error {
        if (!prerequisites.ready
            || prerequisites.powershell_path == null
            || prerequisites.windows_terminal_path == null) {
            throw new IOError.NOT_SUPPORTED("PowerShell 7 and Windows Terminal are required.");
        }
        return {
            (!) prerequisites.windows_terminal_path,
            "new-tab",
            "--title",
            "Holder — %s".printf(session.project_label),
            "--startingDirectory",
            session.working_directory,
            (!) prerequisites.powershell_path,
            "-NoLogo",
            "-NoExit",
            "-File",
            session.bootstrap_path,
            "-HolderTranscriptPath",
            session.transcript_path,
            "-HolderWorkingDirectory",
            session.working_directory
        };
    }

    public string[] build_install_argv(PowerShellPrerequisites prerequisites) throws Error {
        if (prerequisites.windows_terminal_path == null) {
            throw new IOError.NOT_SUPPORTED("Windows Terminal is required to show the installer.");
        }
        if (prerequisites.winget_path == null) {
            throw new IOError.NOT_SUPPORTED("WinGet is not available.");
        }
        return {
            (!) prerequisites.windows_terminal_path,
            "new-tab",
            "--title",
            "Install PowerShell 7 for Holder",
            (!) prerequisites.winget_path,
            "install",
            "--id",
            "Microsoft.PowerShell",
            "--source",
            "winget"
        };
    }

    public virtual void launch_session(PowerShellPrerequisites prerequisites,
                                       TerminalSession session) throws Error {
        launch(build_session_argv(prerequisites, session));
    }

    public virtual void launch_install(PowerShellPrerequisites prerequisites) throws Error {
        launch(build_install_argv(prerequisites));
    }

    protected virtual void launch(string[] argv) throws Error {
        new Subprocess.newv(argv, SubprocessFlags.NONE);
    }
}

}
