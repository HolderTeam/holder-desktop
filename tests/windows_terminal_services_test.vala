using GLib;

namespace HolderLinuxTests {

private class FakePowerShellDiscoveryService : HolderLinux.PowerShellDiscoveryService {
    public Gee.HashMap<string, string> environment = new Gee.HashMap<string, string>();
    public Gee.HashSet<string> existing_paths = new Gee.HashSet<string>();
    public Gee.HashMap<string, string> programs = new Gee.HashMap<string, string>();
    public Gee.HashMap<string, string> versions = new Gee.HashMap<string, string>();
    public Gee.HashSet<string> failed_queries = new Gee.HashSet<string>();
    public int query_count = 0;

    public FakePowerShellDiscoveryService(Settings? settings = null) {
        base(settings);
    }

    public override string? find_program(string name) {
        return programs.get(name);
    }

    public override string? get_environment_variable(string name) {
        return environment.get(name);
    }

    public override bool path_exists(string path) {
        return existing_paths.contains(path);
    }

    public override async string query_version(string path) throws Error {
        query_count++;
        if (failed_queries.contains(path)) {
            throw new IOError.FAILED("simulated query failure");
        }
        var version = versions.get(path);
        if (version == null) {
            throw new IOError.INVALID_DATA("simulated missing version");
        }
        return (!) version;
    }
}

private HolderLinux.PowerShellPrerequisites run_discovery(
    HolderLinux.PowerShellDiscoveryService discovery,
    bool force_refresh = false
) {
    HolderLinux.PowerShellPrerequisites? result = null;
    var loop = new MainLoop();
    discovery.discover.begin(force_refresh, (obj, async_result) => {
        result = discovery.discover.end(async_result);
        loop.quit();
    });
    loop.run();
    return (!) result;
}

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

private void test_windows_apps_alias_detection() {
    assert(HolderLinux.PowerShellDiscoveryService.is_windows_apps_alias(
        "C:\\Users\\Person\\AppData\\Local\\Microsoft\\WindowsApps\\pwsh.exe"
    ));
    assert(HolderLinux.PowerShellDiscoveryService.is_windows_apps_alias(
        "C:/Users/Person/AppData/Local/Microsoft/WindowsApps/pwsh.exe"
    ));
    assert(!HolderLinux.PowerShellDiscoveryService.is_windows_apps_alias(
        "C:\\Program Files\\PowerShell\\7\\pwsh.exe"
    ));
}

private void test_discovery_finds_standard_windows_install_locations() {
    var discovery = new FakePowerShellDiscoveryService();
    discovery.environment.set("ProgramFiles", "C:\\Program Files");
    discovery.environment.set("LOCALAPPDATA", "C:\\Users\\Person\\AppData\\Local");

    var powershell_path = Path.build_filename(
        "C:\\Program Files", "PowerShell", "7", "pwsh.exe"
    );
    var terminal_path = Path.build_filename(
        "C:\\Users\\Person\\AppData\\Local",
        "Microsoft",
        "WindowsApps",
        "wt.exe"
    );
    var winget_path = Path.build_filename(
        "C:\\Users\\Person\\AppData\\Local",
        "Microsoft",
        "WindowsApps",
        "winget.exe"
    );
    discovery.existing_paths.add(powershell_path);
    discovery.existing_paths.add(terminal_path);
    discovery.existing_paths.add(winget_path);

    assert(discovery.find_powershell() == powershell_path);
    assert(discovery.find_windows_app("wt.exe", "wt") == terminal_path);
    assert(discovery.find_windows_app("winget.exe", "winget") == winget_path);
}

private void test_discovery_finds_store_powershell_alias() {
    var discovery = new FakePowerShellDiscoveryService();
    discovery.environment.set("LOCALAPPDATA", "C:\\Users\\Person\\AppData\\Local");
    var powershell_path = Path.build_filename(
        "C:\\Users\\Person\\AppData\\Local",
        "Microsoft",
        "WindowsApps",
        "pwsh.exe"
    );
    discovery.existing_paths.add(powershell_path);

    assert(discovery.find_powershell() == powershell_path);
}

private void test_discovery_prefers_program_files_and_falls_back_after_query_failure() {
    var discovery = new FakePowerShellDiscoveryService();
    discovery.environment.set("ProgramFiles", "C:\\Program Files");
    discovery.environment.set("LOCALAPPDATA", "C:\\Users\\Person\\AppData\\Local");
    var installed_path = Path.build_filename(
        "C:\\Program Files", "PowerShell", "7", "pwsh.exe"
    );
    var alias_path = Path.build_filename(
        "C:\\Users\\Person\\AppData\\Local",
        "Microsoft",
        "WindowsApps",
        "pwsh.exe"
    );
    var terminal_path = Path.build_filename(
        "C:\\Users\\Person\\AppData\\Local",
        "Microsoft",
        "WindowsApps",
        "wt.exe"
    );
    discovery.existing_paths.add(installed_path);
    discovery.existing_paths.add(alias_path);
    discovery.existing_paths.add(terminal_path);
    discovery.programs.set("pwsh.exe", alias_path);
    discovery.failed_queries.add(installed_path);
    discovery.versions.set(alias_path, "7.6.5");

    var candidates = discovery.find_powershell_candidates();
    assert(candidates.length == 2);
    assert(candidates[0] == installed_path);
    assert(candidates[1] == alias_path);

    HolderLinux.PowerShellPrerequisites? result = null;
    Error? failure = null;
    var loop = new MainLoop();
    discovery.discover.begin(false, (obj, async_result) => {
        try {
            result = discovery.discover.end(async_result);
        } catch (Error e) {
            failure = e;
        }
        loop.quit();
    });
    loop.run();

    assert(failure == null);
    assert(result != null);
    assert(((!) result).ready);
    assert(((!) result).powershell_path == alias_path);
    assert(((!) result).powershell_version == "7.6.5");
}

private void test_discovery_uses_valid_cache_and_force_refresh_bypasses_it() {
    var settings = new Settings(HolderLinux.AppSettings.SCHEMA_ID);
    var powershell_path = "C:\\Tools\\pwsh.exe";
    var terminal_path = "C:\\Tools\\wt.exe";
    settings.set_string(
        HolderLinux.AppSettings.KEY_TERMINAL_POWERSHELL_PATH,
        powershell_path
    );
    settings.set_string(
        HolderLinux.AppSettings.KEY_TERMINAL_POWERSHELL_VERSION,
        "7.5.0"
    );
    settings.set_string(
        HolderLinux.AppSettings.KEY_TERMINAL_WINDOWS_TERMINAL_PATH,
        terminal_path
    );

    var discovery = new FakePowerShellDiscoveryService(settings);
    discovery.existing_paths.add(powershell_path);
    discovery.existing_paths.add(terminal_path);
    discovery.programs.set("pwsh.exe", powershell_path);
    discovery.programs.set("wt.exe", terminal_path);
    discovery.versions.set(powershell_path, "7.6.5");

    var cached = run_discovery(discovery);
    assert(cached.ready);
    assert(cached.powershell_version == "7.5.0");
    assert(discovery.query_count == 0);

    var refreshed = run_discovery(discovery, true);
    assert(refreshed.ready);
    assert(refreshed.powershell_version == "7.6.5");
    assert(discovery.query_count == 1);
    assert(settings.get_string(
        HolderLinux.AppSettings.KEY_TERMINAL_POWERSHELL_VERSION
    ) == "7.6.5");
    discovery.clear_cache();
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
        "/windows_terminal/windows_apps_alias_detection",
        test_windows_apps_alias_detection
    );
    Test.add_func(
        "/windows_terminal/discovery_finds_standard_install_locations",
        test_discovery_finds_standard_windows_install_locations
    );
    Test.add_func(
        "/windows_terminal/discovery_finds_store_powershell_alias",
        test_discovery_finds_store_powershell_alias
    );
    Test.add_func(
        "/windows_terminal/discovery_prefers_install_and_falls_back",
        test_discovery_prefers_program_files_and_falls_back_after_query_failure
    );
    Test.add_func(
        "/windows_terminal/discovery_cache_and_force_refresh",
        test_discovery_uses_valid_cache_and_force_refresh_bypasses_it
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
