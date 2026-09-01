using GLib;

namespace HolderLinuxTests {

private string make_temp_dir() {
    try {
        return DirUtils.make_tmp("holder-terminal-sessions-XXXXXX");
    } catch (FileError e) {
        assert_not_reached();
    }
}

private void test_parse_power_shell_versions() {
    assert(HolderLinux.PowerShellDiscoveryService.parse_major_version("7.6.5") == 7);
    assert(HolderLinux.PowerShellDiscoveryService.parse_major_version(" 10.1.0 \n") == 10);
    assert(HolderLinux.PowerShellDiscoveryService.parse_major_version("5") == 5);
    assert(HolderLinux.PowerShellDiscoveryService.parse_major_version("") == -1);
    assert(HolderLinux.PowerShellDiscoveryService.parse_major_version("preview") == -1);
}

private void test_session_store_round_trip_and_bootstrap() {
    var root = make_temp_dir();
    var store = new HolderLinux.TerminalSessionStore(root);
    HolderLinux.TerminalSession session;
    try {
        session = store.create_session(
            "project-1",
            "House Admin",
            "card-1",
            "Boiler notes",
            "C:\\Users\\Person\\Holder Projects\\House"
        );
    } catch (Error e) {
        assert_not_reached();
    }

    assert(FileUtils.test(session.bootstrap_path, FileTest.IS_REGULAR));
    string script;
    try {
        FileUtils.get_contents(session.bootstrap_path, out script);
    } catch (FileError e) {
        assert_not_reached();
    }
    assert(script.contains("Start-Transcript -LiteralPath $HolderTranscriptPath -Force"));
    assert(script.contains("Set-Location -LiteralPath $HolderWorkingDirectory"));
    assert(!script.contains("House Admin"));

    Gee.ArrayList<HolderLinux.TerminalSession> loaded;
    try {
        loaded = store.load_sessions("project-1");
    } catch (Error e) {
        assert_not_reached();
    }
    assert(loaded.size == 1);
    assert(loaded[0].project_label == "House Admin");
    assert(loaded[0].card_id == "card-1");
    assert(loaded[0].working_directory == "C:\\Users\\Person\\Holder Projects\\House");
    assert(loaded[0].state == HolderLinux.TerminalSessionState.INTERRUPTED);
}

private void test_session_store_classifies_complete_and_interrupted_transcripts() {
    var root = make_temp_dir();
    var store = new HolderLinux.TerminalSessionStore(root);
    HolderLinux.TerminalSession completed;
    HolderLinux.TerminalSession interrupted;
    try {
        completed = store.create_session("p", "Project", null, null, "C:\\Work");
        interrupted = store.create_session("p", "Project", null, null, "C:\\Work");
        FileUtils.set_contents(
            completed.transcript_path,
            "**********************\nPowerShell transcript end\n**********************\n"
        );
        FileUtils.set_contents(
            interrupted.transcript_path,
            "PS C:\\Work> ping.exe 127.0.0.1\n"
        );
    } catch (Error e) {
        assert_not_reached();
    }

    Gee.ArrayList<HolderLinux.TerminalSession> loaded;
    try {
        loaded = store.load_sessions("p");
    } catch (Error e) {
        assert_not_reached();
    }
    assert(loaded.size == 2);
    bool saw_completed = false;
    bool saw_interrupted = false;
    foreach (var session in loaded) {
        saw_completed = saw_completed || session.state == HolderLinux.TerminalSessionState.COMPLETED;
        saw_interrupted = saw_interrupted || session.state == HolderLinux.TerminalSessionState.INTERRUPTED;
    }
    assert(saw_completed);
    assert(saw_interrupted);
}

private HolderLinux.PowerShellPrerequisites ready_prerequisites() {
    return new HolderLinux.PowerShellPrerequisites(
        HolderLinux.PowerShellPrerequisiteStatus.READY,
        "C:\\Program Files\\PowerShell\\7\\pwsh.exe",
        "7.6.5",
        "C:\\Users\\Person\\AppData\\Local\\Microsoft\\WindowsApps\\wt.exe",
        "C:\\Users\\Person\\AppData\\Local\\Microsoft\\WindowsApps\\winget.exe"
    );
}

private void test_session_launch_argv_keeps_paths_as_arguments() {
    var session = new HolderLinux.TerminalSession(
        "session-1",
        "project-1",
        "Person's Project & Notes",
        null,
        null,
        "C:\\Holder Projects\\Person's Project & Notes",
        "C:\\Cache\\session 1\\transcript.txt",
        "C:\\Cache\\session 1\\bootstrap.ps1",
        1
    );
    var launcher = new HolderLinux.WindowsTerminalLauncher();
    string[] argv;
    try {
        argv = launcher.build_session_argv(ready_prerequisites(), session);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(argv[0].has_suffix("wt.exe"));
    assert(argv[4] == "--startingDirectory");
    assert(argv[5] == session.working_directory);
    assert(argv[10] == session.bootstrap_path);
    assert(argv[12] == session.transcript_path);
    assert(argv[14] == session.working_directory);
}

private void test_install_argv_uses_official_winget_package() {
    var launcher = new HolderLinux.WindowsTerminalLauncher();
    string[] argv;
    try {
        argv = launcher.build_install_argv(ready_prerequisites());
    } catch (Error e) {
        assert_not_reached();
    }
    assert(argv[0].has_suffix("wt.exe"));
    assert(argv[4].has_suffix("winget.exe"));
    assert(argv[5] == "install");
    assert(argv[7] == "Microsoft.PowerShell");
    assert(argv[9] == "winget");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func(
        "/windows_terminal/parse_power_shell_versions",
        test_parse_power_shell_versions
    );
    Test.add_func(
        "/windows_terminal/session_store_round_trip_and_bootstrap",
        test_session_store_round_trip_and_bootstrap
    );
    Test.add_func(
        "/windows_terminal/session_store_classifies_transcripts",
        test_session_store_classifies_complete_and_interrupted_transcripts
    );
    Test.add_func(
        "/windows_terminal/session_launch_argv_is_safe",
        test_session_launch_argv_keeps_paths_as_arguments
    );
    Test.add_func(
        "/windows_terminal/install_argv_uses_official_package",
        test_install_argv_uses_official_winget_package
    );
    return Test.run();
}

}
