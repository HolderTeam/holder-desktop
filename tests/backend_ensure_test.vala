using GLib;

namespace HolderLinuxTests {

private void test_builds_the_command_with_the_api_range_and_idle_exit() {
    var command = HolderLinux.BackendEnsure.build_command("/usr/bin/holderctl", "0.1", "0.2", 60);
    string[] expected = {
        "/usr/bin/holderctl", "ensure", "--json",
        "--api-min", "0.1", "--api-max-exclusive", "0.2", "--idle-exit", "60"
    };
    assert(command.length == expected.length);
    for (int i = 0; i < expected.length; i++) {
        assert(command[i] == expected[i]);
    }
}

private void test_leaves_out_an_empty_api_bound() {
    var command = HolderLinux.BackendEnsure.build_command("holderctl", "", "", 30);
    assert(command.length == 5);
    assert(command[3] == "--idle-exit");
    assert(command[4] == "30");
}

private string make_temp_dir() {
    try {
        return DirUtils.make_tmp("holder-ensure-XXXXXX");
    } catch (FileError e) {
        assert_not_reached();
    }
}

private void test_prefers_holderctl_beside_the_program() {
    var dir = make_temp_dir();
    var beside = Path.build_filename(dir, HolderLinux.BackendEnsure.program_file_name());
    try {
        FileUtils.set_contents(beside, "#!/bin/sh\n");
        FileUtils.chmod(beside, 0755);
    } catch (FileError e) {
        assert_not_reached();
    }

    assert(HolderLinux.BackendEnsure.locate_holderctl(dir, "/elsewhere/holderctl") == beside);
    FileUtils.remove(beside);
    DirUtils.remove(dir);
}

private void test_an_executable_override_wins() {
    var dir = make_temp_dir();
    var beside = Path.build_filename(dir, HolderLinux.BackendEnsure.program_file_name());
    var override_ctl = write_fake_holderctl("exit 0\n");
    try {
        FileUtils.set_contents(beside, "#!/bin/sh\n");
        FileUtils.chmod(beside, 0755);
    } catch (FileError e) {
        assert_not_reached();
    }

    assert(HolderLinux.BackendEnsure.locate_holderctl(dir, "/usr/bin/holderctl", override_ctl) == override_ctl);
}

private void test_an_override_that_is_not_executable_is_ignored() {
    var empty = make_temp_dir();

    assert(HolderLinux.BackendEnsure.locate_holderctl(empty, "/usr/bin/holderctl", "/no/such/holderctl")
           == "/usr/bin/holderctl");
    assert(HolderLinux.BackendEnsure.locate_holderctl(empty, null, "") == null);
}

// A directory laid out like a macOS app bundle, with holderctl in Contents/Resources/bin.
private string make_bundle_with_holderctl(string base_dir) {
    var contents = Path.build_filename(base_dir, "Holder.app", "Contents");
    DirUtils.create_with_parents(Path.build_filename(contents, "MacOS"), 0755);
    DirUtils.create_with_parents(Path.build_filename(contents, "Resources", "bin"), 0755);
    var holderctl = Path.build_filename(contents, "Resources", "bin", HolderLinux.BackendEnsure.program_file_name());
    try {
        FileUtils.set_contents(holderctl, "#!/bin/sh\n");
        FileUtils.chmod(holderctl, 0755);
    } catch (FileError e) {
        assert_not_reached();
    }
    return contents;
}

private void test_finds_holderctl_in_the_bundle_when_the_desktop_is_the_main_executable() {
    var contents = make_bundle_with_holderctl(make_temp_dir());
    var holderctl = Path.build_filename(contents, "Resources", "bin", HolderLinux.BackendEnsure.program_file_name());

    var found = HolderLinux.BackendEnsure.locate_holderctl(Path.build_filename(contents, "MacOS"), "/usr/bin/holderctl");

    assert(found == holderctl);
}

private void test_prefers_holderctl_beside_the_program_over_the_bundle() {
    var contents = make_bundle_with_holderctl(make_temp_dir());
    var macos_dir = Path.build_filename(contents, "MacOS");
    var beside = Path.build_filename(macos_dir, HolderLinux.BackendEnsure.program_file_name());
    try {
        FileUtils.set_contents(beside, "#!/bin/sh\n");
        FileUtils.chmod(beside, 0755);
    } catch (FileError e) {
        assert_not_reached();
    }

    assert(HolderLinux.BackendEnsure.locate_holderctl(macos_dir, null) == beside);
}

private void test_the_bundle_is_only_searched_from_contents_macos() {
    var contents = make_bundle_with_holderctl(make_temp_dir());
    var elsewhere = Path.build_filename(Path.get_dirname(contents), "SomewhereElse");
    DirUtils.create_with_parents(elsewhere, 0755);

    assert(HolderLinux.BackendEnsure.locate_holderctl(elsewhere, null) == null);
    // Not inside a Contents directory at all.
    var plain = make_temp_dir();
    var macos_lookalike = Path.build_filename(plain, "MacOS");
    DirUtils.create_with_parents(macos_lookalike, 0755);
    assert(HolderLinux.BackendEnsure.locate_holderctl(macos_lookalike, null) == null);
}

private void test_falls_back_to_path_then_to_nothing() {
    var empty = make_temp_dir();
    assert(HolderLinux.BackendEnsure.locate_holderctl(empty, "/usr/bin/holderctl") == "/usr/bin/holderctl");
    assert(HolderLinux.BackendEnsure.locate_holderctl(null, "/usr/bin/holderctl") == "/usr/bin/holderctl");
    assert(HolderLinux.BackendEnsure.locate_holderctl(empty, null) == null);
    DirUtils.remove(empty);
}

private void test_parses_a_started_daemon() {
    var outcome = HolderLinux.BackendEnsure.parse_result(
        "{\"ok\":true,\"state\":\"started\",\"exit_code\":0}", "", 0);
    assert(outcome.ok);
    assert(outcome.state == "started");
}

private void test_parses_an_already_running_daemon() {
    var outcome = HolderLinux.BackendEnsure.parse_result(
        "{\"ok\":true,\"state\":\"running\",\"mode\":\"existing\"}", "", 0);
    assert(outcome.ok);
    assert(outcome.state == "running");
}

private void test_reports_the_error_message_on_failure() {
    var outcome = HolderLinux.BackendEnsure.parse_result(
        "{\"ok\":false,\"state\":\"failed\",\"error\":{\"code\":\"api_incompatible\","
        + "\"message\":\"the daemon API version 0.1 is older than the minimum supported 99\"}}",
        "", 10);
    assert(!outcome.ok);
    assert(outcome.state == "failed");
    assert(outcome.message.contains("older than the minimum"));
}

private void test_a_failure_without_a_message_still_says_something() {
    var outcome = HolderLinux.BackendEnsure.parse_result("{\"ok\":false,\"state\":\"failed\"}", "", 12);
    assert(!outcome.ok);
    assert(outcome.message.contains("12"));
}

private void test_a_nonzero_exit_is_never_a_success() {
    var outcome = HolderLinux.BackendEnsure.parse_result("{\"ok\":true,\"state\":\"running\"}", "", 3);
    assert(!outcome.ok);
}

private void test_falls_back_to_standard_error_without_json() {
    var outcome = HolderLinux.BackendEnsure.parse_result("", "Invalid --idle-exit value\n", 2);
    assert(!outcome.ok);
    assert(outcome.message == "Invalid --idle-exit value");
}

private void test_falls_back_to_the_exit_status_with_nothing_else() {
    var outcome = HolderLinux.BackendEnsure.parse_result("not json", "", 7);
    assert(!outcome.ok);
    assert(outcome.message.contains("7"));
}

private string write_fake_holderctl(string script_body) {
    var dir = make_temp_dir();
    // Windows only treats files with an executable extension as programs.
    var path = Path.build_filename(dir, HolderLinux.BackendEnsure.program_file_name());
    try {
        FileUtils.set_contents(path, "#!/bin/sh\n" + script_body);
        FileUtils.chmod(path, 0755);
    } catch (FileError e) {
        assert_not_reached();
    }
    return path;
}

private void test_ensure_runs_holderctl_and_reports_how_it_went() {
    if (Path.DIR_SEPARATOR_S == "\\") {
        return;
    }
    var path = write_fake_holderctl("echo '{\"ok\":true,\"state\":\"started\"}'\n");
    HolderLinux.EnsureOutcome? outcome = null;
    new HolderLinux.BackendEnsure(path).ensure.begin((obj, res) => {
        try {
            outcome = ((HolderLinux.BackendEnsure) obj).ensure.end(res);
        } catch (Error e) {
            assert_not_reached();
        }
    });
    assert(wait_for_condition(() => outcome != null));
    assert(((!) outcome).ok);
    assert(((!) outcome).state == "started");
    var details = ((!) outcome).details;
    assert(details.contains(path + " ensure --json"));
    assert(details.contains("--idle-exit 60"));
    assert(details.contains("(exit status 0)"));
}

private void test_ensure_reports_a_failing_holderctl_with_its_standard_error() {
    if (Path.DIR_SEPARATOR_S == "\\") {
        return;
    }
    var path = write_fake_holderctl("echo 'no such unit' >&2\nexit 12\n");
    HolderLinux.EnsureOutcome? outcome = null;
    new HolderLinux.BackendEnsure(path).ensure.begin((obj, res) => {
        try {
            outcome = ((HolderLinux.BackendEnsure) obj).ensure.end(res);
        } catch (Error e) {
            assert_not_reached();
        }
    });
    assert(wait_for_condition(() => outcome != null));
    assert(!((!) outcome).ok);
    assert(((!) outcome).message == "no such unit");
    assert(((!) outcome).details.contains("(exit status 12)"));
    assert(((!) outcome).details.contains("stderr: no such unit"));
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/backend_ensure/builds_the_command", test_builds_the_command_with_the_api_range_and_idle_exit);
    Test.add_func("/backend_ensure/leaves_out_empty_bounds", test_leaves_out_an_empty_api_bound);
    Test.add_func("/backend_ensure/prefers_holderctl_beside_the_program", test_prefers_holderctl_beside_the_program);
    Test.add_func("/backend_ensure/override_wins", test_an_executable_override_wins);
    Test.add_func("/backend_ensure/bad_override_is_ignored", test_an_override_that_is_not_executable_is_ignored);
    Test.add_func("/backend_ensure/finds_holderctl_in_the_bundle", test_finds_holderctl_in_the_bundle_when_the_desktop_is_the_main_executable);
    Test.add_func("/backend_ensure/beside_wins_over_the_bundle", test_prefers_holderctl_beside_the_program_over_the_bundle);
    Test.add_func("/backend_ensure/bundle_only_from_contents_macos", test_the_bundle_is_only_searched_from_contents_macos);
    Test.add_func("/backend_ensure/falls_back_to_path", test_falls_back_to_path_then_to_nothing);
    Test.add_func("/backend_ensure/parses_started", test_parses_a_started_daemon);
    Test.add_func("/backend_ensure/parses_running", test_parses_an_already_running_daemon);
    Test.add_func("/backend_ensure/reports_the_error_message", test_reports_the_error_message_on_failure);
    Test.add_func("/backend_ensure/failure_without_message", test_a_failure_without_a_message_still_says_something);
    Test.add_func("/backend_ensure/nonzero_exit_is_not_success", test_a_nonzero_exit_is_never_a_success);
    Test.add_func("/backend_ensure/falls_back_to_stderr", test_falls_back_to_standard_error_without_json);
    Test.add_func("/backend_ensure/falls_back_to_exit_status", test_falls_back_to_the_exit_status_with_nothing_else);

    Test.add_func("/backend_ensure/runs_holderctl_and_reports", test_ensure_runs_holderctl_and_reports_how_it_went);
    Test.add_func("/backend_ensure/reports_a_failing_holderctl", test_ensure_reports_a_failing_holderctl_with_its_standard_error);

    return Test.run();
}

}
