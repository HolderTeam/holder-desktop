using GLib;

namespace HolderLinuxTests {

private string test_executable;

private class SlowHiddenProcessDiscovery : HolderLinux.PowerShellDiscoveryService {
    public bool simulate_timeout = false;
    public int worker_started = 0;
    public int worker_finished = 0;
    public string? output_path;
    public uint received_timeout_ms;

    internal override int run_hidden_process(string executable, string command_line, uint timeout_ms) throws Error {
        AtomicInt.set(ref worker_started, 1);
        try {
            received_timeout_ms = timeout_ms;
            output_path = command_line.split("'")[1];
            Thread.usleep(200000);
            if (simulate_timeout) {
                throw new IOError.TIMED_OUT("simulated hidden query timeout");
            }
            FileUtils.set_contents((!) output_path, "7.4.1\n");
            return 0;
        } finally {
            AtomicInt.set(ref worker_finished, 1);
        }
    }
}

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
    assert(HolderLinux.PowerShellDiscoveryService.parse_major_version(null) == -1);
    assert(HolderLinux.PowerShellDiscoveryService.parse_major_version(".5") == -1);
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

    var candidates = discovery.find_powershell_candidates();
    assert(candidates.length > 0);
    assert(candidates[0] == powershell_path);
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

    var candidates = discovery.find_powershell_candidates();
    assert(candidates.length > 0);
    assert(candidates[0] == powershell_path);
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

    var result = run_discovery(discovery);

    assert(result.ready);
    assert(result.powershell_path == alias_path);
    assert(result.powershell_version == "7.6.5");
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

private class RecordingLauncher : HolderLinux.WindowsTerminalLauncher {
    public string[] last_argv = {};

    protected override void launch(string[] argv) throws Error {
        last_argv = argv;
    }
}

private HolderLinux.TerminalSession sample_session(string root) {
    return new HolderLinux.TerminalSession(
        "s1", "p1", "Project", null, null, "/work",
        Path.build_filename(root, "s1", "transcript.txt"),
        Path.build_filename(root, "s1", "bootstrap.ps1"),
        1
    );
}

private void test_launcher_rejects_missing_prerequisites() {
    var launcher = new HolderLinux.WindowsTerminalLauncher();
    var session = sample_session("/tmp");
    var not_ready = new HolderLinux.PowerShellPrerequisites(
        HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_MISSING, null, null, "wt.exe", "winget.exe"
    );
    var no_terminal = new HolderLinux.PowerShellPrerequisites(
        HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_MISSING, null, null, null, "winget.exe"
    );
    var no_winget = new HolderLinux.PowerShellPrerequisites(
        HolderLinux.PowerShellPrerequisiteStatus.READY, "pwsh.exe", "7.6.5", "wt.exe", null
    );

    bool session_rejected = false;
    try {
        launcher.build_session_argv(not_ready, session);
    } catch (Error e) {
        session_rejected = e is IOError.NOT_SUPPORTED;
    }
    assert(session_rejected);

    bool terminal_rejected = false;
    try {
        launcher.build_install_argv(no_terminal);
    } catch (Error e) {
        terminal_rejected = e.message.contains("Windows Terminal");
    }
    assert(terminal_rejected);

    bool winget_rejected = false;
    try {
        launcher.build_install_argv(no_winget);
    } catch (Error e) {
        winget_rejected = e.message.contains("WinGet");
    }
    assert(winget_rejected);
}

private void test_launcher_launch_methods_pass_the_built_argv_to_launch() {
    var launcher = new RecordingLauncher();
    var session = sample_session("/tmp");
    try {
        launcher.launch_session(ready_prerequisites(), session);
        assert(launcher.last_argv.length == 15);
        assert(launcher.last_argv[10] == session.bootstrap_path);
        launcher.launch_install(ready_prerequisites());
        assert(launcher.last_argv[5] == "install");
    } catch (Error e) {
        assert_not_reached();
    }
}

private void test_launcher_spawns_the_terminal_program_for_real() {
    if (!FileUtils.test("/bin/true", FileTest.IS_EXECUTABLE)) {
        Test.skip("/bin/true is not available");
        return;
    }
    var prerequisites = new HolderLinux.PowerShellPrerequisites(
        HolderLinux.PowerShellPrerequisiteStatus.READY, "pwsh.exe", "7.6.5", "/bin/true", "winget.exe"
    );
    try {
        new HolderLinux.WindowsTerminalLauncher().launch_session(prerequisites, sample_session("/tmp"));
    } catch (Error e) {
        assert_not_reached();
    }
}

private void test_session_store_handles_missing_root_filters_and_damaged_entries() {
    var root = make_temp_dir();
    var store = new HolderLinux.TerminalSessionStore(Path.build_filename(root, "does-not-exist"));
    try {
        assert(store.load_sessions().size == 0);
    } catch (Error e) {
        assert_not_reached();
    }

    store = new HolderLinux.TerminalSessionStore(root);
    try {
        store.create_session("project-a", "A", null, null, "/work");
        store.create_session("project-b", "B", null, null, "/work");
        DirUtils.create_with_parents(Path.build_filename(root, "no-metadata"), 0700);
        var broken = Path.build_filename(root, "broken");
        DirUtils.create_with_parents(broken, 0700);
        FileUtils.set_contents(Path.build_filename(broken, "session.json"), "not json");
        var not_object = Path.build_filename(root, "not-object");
        DirUtils.create_with_parents(not_object, 0700);
        FileUtils.set_contents(Path.build_filename(not_object, "session.json"), "[]");
    } catch (Error e) {
        assert_not_reached();
    }

    try {
        assert(store.load_sessions().size == 2);
        var only_a = store.load_sessions("project-a");
        assert(only_a.size == 1);
        assert(only_a[0].project_id == "project-a");
    } catch (Error e) {
        assert_not_reached();
    }
}

private HolderLinux.TerminalSession with_created_at(HolderLinux.TerminalSession source, int64 created_at) {
    return new HolderLinux.TerminalSession(
        source.session_id, source.project_id, source.project_label, source.card_id, source.card_label,
        source.working_directory, source.transcript_path, source.bootstrap_path,
        created_at, source.last_modified_at, source.state
    );
}

private void test_session_store_orders_newest_first() {
    var root = make_temp_dir();
    var store = new HolderLinux.TerminalSessionStore(root);
    try {
        var older = store.create_session("p", "Older", null, null, "/work");
        var newer = store.create_session("p", "Newer", null, null, "/work");
        store.save_session(with_created_at(older, 100));
        store.save_session(with_created_at(newer, 200));

        var loaded = store.load_sessions("p");
        assert(loaded.size == 2);
        assert(loaded[0].project_label == "Newer");
        assert(loaded[1].project_label == "Older");
    } catch (Error e) {
        assert_not_reached();
    }
}

private void test_session_store_read_transcript_without_file_or_when_unreadable() {
    var root = make_temp_dir();
    var store = new HolderLinux.TerminalSessionStore(root);
    HolderLinux.TerminalSession session;
    try {
        session = store.create_session("p", "Project", null, null, "/work");
        assert(!store.read_transcript(session).completed);
        FileUtils.set_contents(session.transcript_path, "PS /work> ls\n");
    } catch (Error e) {
        assert_not_reached();
    }

    FileUtils.chmod(session.transcript_path, 0000);
    string? readable = null;
    try {
        FileUtils.get_contents(session.transcript_path, out readable);
    } catch (Error e) {
        readable = null;
    }
    if (readable != null) {
        FileUtils.chmod(session.transcript_path, 0600);
        Test.skip("file permissions are not enforced for this user");
        return;
    }
    bool failed = false;
    try {
        store.read_transcript(session);
    } catch (Error e) {
        failed = e is IOError.FAILED && e.message.contains("Could not read terminal transcript");
    }
    FileUtils.chmod(session.transcript_path, 0600);
    assert(failed);
}

private void test_session_store_reports_unwritable_locations() {
    var root = make_temp_dir();
    var blocker = Path.build_filename(root, "blocker");
    try {
        FileUtils.set_contents(blocker, "a file, not a directory");
    } catch (Error e) {
        assert_not_reached();
    }

    var blocked_store = new HolderLinux.TerminalSessionStore(Path.build_filename(blocker, "sessions"));
    bool create_failed = false;
    try {
        blocked_store.create_session("p", "Project", null, null, "/work");
    } catch (Error e) {
        create_failed = e.message.contains("Could not create terminal session storage");
    }
    assert(create_failed);

    var store = new HolderLinux.TerminalSessionStore(root);
    bool save_failed = false;
    try {
        store.save_session(sample_session(Path.build_filename(root, "missing-parent")));
    } catch (Error e) {
        save_failed = e.message.contains("Could not save terminal session");
    }
    assert(save_failed);
}

private void test_session_store_reports_an_unreadable_session_root() {
    var root = make_temp_dir();
    var store = new HolderLinux.TerminalSessionStore(root);
    FileUtils.chmod(root, 0000);

    bool readable = true;
    try {
        Dir.open(root);
    } catch (FileError e) {
        readable = false;
    }
    if (readable) {
        FileUtils.chmod(root, 0700);
        Test.skip("file permissions are not enforced for this user");
        return;
    }

    bool failed = false;
    try {
        store.load_sessions();
    } catch (Error e) {
        failed = e is IOError.FAILED && e.message.contains("Could not read terminal sessions");
    }
    FileUtils.chmod(root, 0700);
    assert(failed);
}

private void register_powershell(FakePowerShellDiscoveryService discovery, string path, string? version) {
    discovery.existing_paths.add(path);
    discovery.programs.set("pwsh.exe", path);
    if (version != null) {
        discovery.versions.set(path, (!) version);
    }
}

private void test_discovery_reports_each_missing_prerequisite() {
    var missing = run_discovery(new FakePowerShellDiscoveryService());
    assert(missing.status == HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_MISSING);
    assert(!missing.ready);

    var unqueryable = new FakePowerShellDiscoveryService();
    register_powershell(unqueryable, "C:\\Tools\\pwsh.exe", null);
    var query_failed = run_discovery(unqueryable);
    assert(query_failed.status == HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_QUERY_FAILED);
    assert(query_failed.details.contains("C:\\Tools\\pwsh.exe"));

    var old = new FakePowerShellDiscoveryService();
    register_powershell(old, "C:\\Tools\\pwsh.exe", "5.1.0");
    old.programs.set("wt.exe", "C:\\Tools\\wt.exe");
    old.existing_paths.add("C:\\Tools\\wt.exe");
    var unsupported = run_discovery(old);
    assert(unsupported.status == HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_UNSUPPORTED);
    assert(unsupported.powershell_version == "5.1.0");

    var no_terminal = new FakePowerShellDiscoveryService();
    register_powershell(no_terminal, "C:\\Tools\\pwsh.exe", "7.6.5");
    var terminal_missing = run_discovery(no_terminal);
    assert(terminal_missing.status == HolderLinux.PowerShellPrerequisiteStatus.WINDOWS_TERMINAL_MISSING);
    assert(terminal_missing.powershell_path == "C:\\Tools\\pwsh.exe");
}

private void test_discovery_discards_a_stale_cache() {
    var settings = new Settings(HolderLinux.AppSettings.SCHEMA_ID);
    settings.set_string(HolderLinux.AppSettings.KEY_TERMINAL_POWERSHELL_PATH, "C:\\Gone\\pwsh.exe");
    settings.set_string(HolderLinux.AppSettings.KEY_TERMINAL_POWERSHELL_VERSION, "7.5.0");
    settings.set_string(HolderLinux.AppSettings.KEY_TERMINAL_WINDOWS_TERMINAL_PATH, "C:\\Gone\\wt.exe");
    var discovery = new FakePowerShellDiscoveryService(settings);

    var result = run_discovery(discovery);
    assert(result.status == HolderLinux.PowerShellPrerequisiteStatus.POWERSHELL_MISSING);
    assert(settings.get_string(HolderLinux.AppSettings.KEY_TERMINAL_POWERSHELL_PATH) == "");

    new FakePowerShellDiscoveryService().clear_cache();
}

private void test_discovery_default_environment_lookups() {
    var discovery = new HolderLinux.PowerShellDiscoveryService();

    assert(discovery.find_program("sh") != null);
    assert(discovery.find_program("holder-no-such-program") == null);
    assert(discovery.get_environment_variable("PATH") != null);
    assert(discovery.get_environment_variable("HOLDER_NO_SUCH_VARIABLE") == null);
    assert(discovery.path_exists("/"));
    assert(!discovery.path_exists("/holder/no/such/path"));
}

private string? query_fake_powershell(string script_body, out Error? failure, uint timeout_ms = 10000) {
    var dir = make_temp_dir();
    var path = Path.build_filename(dir, "pwsh");
    try {
        FileUtils.set_contents(path, "#!/bin/sh\n" + script_body + "\n");
    } catch (Error e) {
        assert_not_reached();
    }
    FileUtils.chmod(path, 0700);

    var discovery = new HolderLinux.PowerShellDiscoveryService();
    discovery.query_timeout_ms = timeout_ms;
    var loop = new MainLoop();
    string? version = null;
    Error? caught = null;
    discovery.query_version.begin(path, (obj, res) => {
        try {
            version = discovery.query_version.end(res);
        } catch (Error e) {
            caught = e;
        }
        loop.quit();
    });
    loop.run();
    failure = caught;
    FileUtils.remove(path);
    DirUtils.remove(dir);
    return version;
}

private void test_query_version_times_out_a_stuck_subprocess() {
    if (!FileUtils.test("/bin/sh", FileTest.IS_EXECUTABLE)) {
        Test.skip("/bin/sh is not available");
        return;
    }
    Error? failure;
    var started = get_monotonic_time();
    var version = query_fake_powershell("exec sleep 30", out failure, 100);
    assert(version == null);
    assert(failure is IOError.TIMED_OUT);
    assert(get_monotonic_time() - started < 5000000);
}

private void check_hidden_query_keeps_caller_context_responsive(bool simulate_timeout) {
    var context = new MainContext();
    context.push_thread_default();
    var loop = new MainLoop(context);
    var caller_thread = Thread.self<void*>();
    var discovery = new SlowHiddenProcessDiscovery();
    discovery.simulate_timeout = simulate_timeout;
    discovery.query_timeout_ms = 1234;
    int ticks_while_working = 0;
    var heartbeat = new TimeoutSource(5);
    heartbeat.set_callback(() => {
        if (AtomicInt.get(ref discovery.worker_started) != 0
            && AtomicInt.get(ref discovery.worker_finished) == 0) {
            ticks_while_working++;
        }
        return Source.CONTINUE;
    });
    heartbeat.attach(context);
    var watchdog = new TimeoutSource(5000);
    watchdog.set_callback(() => { assert_not_reached(); });
    watchdog.attach(context);
    string? version = null;
    Error? failure = null;
    discovery.query_version.begin("C:\\Microsoft\\WindowsApps\\pwsh.exe", (obj, res) => {
        assert(Thread.self<void*>() == caller_thread);
        assert(context.is_owner());
        try {
            version = discovery.query_version.end(res);
        } catch (Error e) {
            failure = e;
        }
        loop.quit();
    });
    loop.run();
    heartbeat.destroy();
    watchdog.destroy();
    context.pop_thread_default();

    assert(ticks_while_working > 0);
    assert(discovery.received_timeout_ms == 1234);
    assert(discovery.output_path != null);
    assert(!FileUtils.test((!) discovery.output_path, FileTest.EXISTS));
    assert(!FileUtils.test(Path.get_dirname((!) discovery.output_path), FileTest.EXISTS));
    if (simulate_timeout) {
        assert(version == null);
        assert(failure is IOError.TIMED_OUT);
        assert(failure.message == "simulated hidden query timeout");
    } else {
        assert(failure == null);
        assert(version == "7.4.1");
    }
}

private void test_hidden_query_keeps_caller_context_responsive() {
    check_hidden_query_keeps_caller_context_responsive(false);
    check_hidden_query_keeps_caller_context_responsive(true);
}

private void test_native_hidden_process_exit_and_timeout() {
    if (Path.DIR_SEPARATOR != '\\') {
        Test.skip("native hidden process creation requires Windows");
        return;
    }
    var discovery = new HolderLinux.PowerShellDiscoveryService();
    foreach (var child_mode in new string[] {"--hidden-child-exit", "--hidden-child-sleep"}) {
        bool expect_timeout = child_mode == "--hidden-child-sleep";
        discovery.query_timeout_ms = expect_timeout ? 100 : 10000;
        var loop = new MainLoop();
        Error? failure = null;
        int exit_code = -1;
        var started = get_monotonic_time();
        discovery.run_hidden_process_async.begin(test_executable,
            "\"%s\" %s".printf(test_executable, child_mode), (obj, res) => {
                try {
                    exit_code = discovery.run_hidden_process_async.end(res);
                } catch (Error e) {
                    failure = e;
                }
                loop.quit();
            });
        loop.run();
        if (expect_timeout) {
            assert(failure is IOError.TIMED_OUT);
            assert(get_monotonic_time() - started < 5000000);
        } else {
            assert(failure == null);
            assert(exit_code == 7);
        }
    }
}

private void test_query_version_runs_the_executable_and_reports_failures() {
    if (!FileUtils.test("/bin/sh", FileTest.IS_EXECUTABLE)) {
        Test.skip("/bin/sh is not available");
        return;
    }
    Error? failure;
    var version = query_fake_powershell("echo 7.4.1", out failure);
    assert(failure == null);
    assert(version == "7.4.1");

    version = query_fake_powershell("echo 'bad things' >&2; exit 3", out failure);
    assert(version == null);
    assert(failure is IOError.FAILED);
    assert(failure.message == "bad things");

    version = query_fake_powershell("exit 1", out failure);
    assert(version == null);
    assert(failure.message == "PowerShell version query failed.");

    // Output that is not a version falls back to the through-file query, which needs the Windows
    // helper and reports itself unsupported elsewhere.
    version = query_fake_powershell("echo preview", out failure);
    assert(version == null);
    assert(failure is IOError.NOT_SUPPORTED);
}

private void test_version_from_output_file_validates_the_helper_result() {
    var dir = make_temp_dir();
    var output_path = Path.build_filename(dir, "version.txt");
    try {
        FileUtils.set_contents(output_path, "  7.4.1\n");
        assert(HolderLinux.PowerShellDiscoveryService.version_from_output_file(output_path, 0) == "7.4.1");
    } catch (Error e) {
        assert_not_reached();
    }

    try {
        HolderLinux.PowerShellDiscoveryService.version_from_output_file(output_path, 3);
        assert_not_reached();
    } catch (Error e) {
        assert(e is IOError.FAILED);
        assert(e.message == "PowerShell version query exited with status 3.");
    }

    try {
        HolderLinux.PowerShellDiscoveryService.version_from_output_file(
            Path.build_filename(dir, "missing.txt"), 0
        );
        assert_not_reached();
    } catch (Error e) {
        assert(e is IOError.INVALID_DATA);
        assert(e.message.has_prefix("PowerShell returned no version output: "));
    }

    try {
        FileUtils.set_contents(output_path, "nonsense\n");
        HolderLinux.PowerShellDiscoveryService.version_from_output_file(output_path, 0);
        assert_not_reached();
    } catch (Error e) {
        assert(e is IOError.INVALID_DATA);
        assert(e.message == "PowerShell returned an invalid version: nonsense");
    }
}

private void test_query_version_through_file_is_unsupported_without_the_windows_helper() {
    if (Path.DIR_SEPARATOR == '\\') {
        Test.skip("the real Windows helper would run on this platform");
        return;
    }
    // A WindowsApps alias is queried by writing to a file through the hidden-process helper,
    // whose non-Windows stub reports that it is unsupported.
    var discovery = new HolderLinux.PowerShellDiscoveryService();
    var loop = new MainLoop();
    Error? caught = null;
    discovery.query_version.begin("C:\\Users\\me\\AppData\\Local\\Microsoft\\WindowsApps\\pwsh.exe", (obj, res) => {
        try {
            discovery.query_version.end(res);
        } catch (Error e) {
            caught = e;
        }
        loop.quit();
    });
    loop.run();

    assert(caught != null);
    assert(caught is IOError.NOT_SUPPORTED);
}

private void test_session_store_skips_unreadable_session_metadata() {
    var root = make_temp_dir();
    var store = new HolderLinux.TerminalSessionStore(root);
    HolderLinux.TerminalSession locked;
    try {
        locked = store.create_session("p", "Locked", null, null, "/work");
        store.create_session("p", "Readable", null, null, "/work");
    } catch (Error e) {
        assert_not_reached();
    }
    var metadata_path = Path.build_filename(Path.get_dirname(locked.transcript_path), "session.json");
    FileUtils.chmod(metadata_path, 0000);

    string? readable = null;
    try {
        FileUtils.get_contents(metadata_path, out readable);
    } catch (Error e) {
        readable = null;
    }
    if (readable != null) {
        FileUtils.chmod(metadata_path, 0600);
        Test.skip("file permissions are not enforced for this user");
        return;
    }
    try {
        var loaded = store.load_sessions("p");
        assert(loaded.size == 1);
        assert(loaded[0].project_label == "Readable");
    } catch (Error e) {
        assert_not_reached();
    }
    FileUtils.chmod(metadata_path, 0600);
}

public static int main(string[] args) {
    if (args.length == 2 && args[1] == "--hidden-child-exit") {
        return 7;
    }
    if (args.length == 2 && args[1] == "--hidden-child-sleep") {
        Thread.usleep(10000000);
        return 0;
    }
    test_executable = File.new_for_path(args[0]).get_path();
    Test.init(ref args);
    Test.add_func("/windows_terminal/query_version_times_out_a_stuck_subprocess",
                  test_query_version_times_out_a_stuck_subprocess);
    Test.add_func("/windows_terminal/hidden_query_keeps_caller_context_responsive",
                  test_hidden_query_keeps_caller_context_responsive);
    Test.add_func("/windows_terminal/native_hidden_process_exit_and_timeout",
                  test_native_hidden_process_exit_and_timeout);
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
    Test.add_func(
        "/windows_terminal/discovery_reports_each_missing_prerequisite",
        test_discovery_reports_each_missing_prerequisite
    );
    Test.add_func(
        "/windows_terminal/discovery_discards_a_stale_cache",
        test_discovery_discards_a_stale_cache
    );
    Test.add_func(
        "/windows_terminal/discovery_default_environment_lookups",
        test_discovery_default_environment_lookups
    );
    Test.add_func(
        "/windows_terminal/query_version_runs_the_executable_and_reports_failures",
        test_query_version_runs_the_executable_and_reports_failures
    );
    Test.add_func(
        "/windows_terminal/query_version_through_file_is_unsupported_without_the_windows_helper",
        test_query_version_through_file_is_unsupported_without_the_windows_helper
    );
    Test.add_func(
        "/windows_terminal/launcher_rejects_missing_prerequisites",
        test_launcher_rejects_missing_prerequisites
    );
    Test.add_func(
        "/windows_terminal/launcher_launch_methods_pass_the_built_argv",
        test_launcher_launch_methods_pass_the_built_argv_to_launch
    );
    Test.add_func(
        "/windows_terminal/launcher_spawns_the_terminal_program",
        test_launcher_spawns_the_terminal_program_for_real
    );
    Test.add_func(
        "/windows_terminal/session_store_missing_root_filters_and_damaged_entries",
        test_session_store_handles_missing_root_filters_and_damaged_entries
    );
    Test.add_func(
        "/windows_terminal/session_store_skips_unreadable_session_metadata",
        test_session_store_skips_unreadable_session_metadata
    );
    Test.add_func(
        "/windows_terminal/session_store_reports_an_unreadable_session_root",
        test_session_store_reports_an_unreadable_session_root
    );
    Test.add_func(
        "/windows_terminal/version_from_output_file_validates_the_helper_result",
        test_version_from_output_file_validates_the_helper_result
    );
    Test.add_func(
        "/windows_terminal/session_store_orders_newest_first",
        test_session_store_orders_newest_first
    );
    Test.add_func(
        "/windows_terminal/session_store_read_transcript_edge_cases",
        test_session_store_read_transcript_without_file_or_when_unreadable
    );
    Test.add_func(
        "/windows_terminal/session_store_reports_unwritable_locations",
        test_session_store_reports_unwritable_locations
    );
    return Test.run();
}

}
