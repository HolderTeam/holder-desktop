using GLib;

namespace HolderLinux.Tests {

private string make_temp_dir() {
    try {
        return DirUtils.make_tmp("holder-recovery-service-test-XXXXXX");
    } catch (FileError e) {
        assert_not_reached();
    }
}

private bool wait_for_file(string path) {
    for (int i = 0; i < 500; i++) {
        if (FileUtils.test(path, FileTest.EXISTS)) {
            return true;
        }
        MainContext.default().iteration(false);
    }
    return false;
}

private string wait_for_nonempty_file_contents(string path) {
    string contents = "";
    for (int i = 0; i < 500; i++) {
        if (FileUtils.test(path, FileTest.EXISTS)) {
            try {
                FileUtils.get_contents(path, out contents);
                if (contents.length > 0) {
                    return contents;
                }
            } catch (FileError e) {
            }
        }
        MainContext.default().iteration(false);
    }
    return contents;
}

private void test_build_safe_filename_replaces_spaces() {
    var service = new HolderLinux.RecoveryService();
    assert(service.build_safe_filename("Project Name") == "Project-Name-recovery.hrk");
}

private void test_write_payload_to_temp_attachment_writes_expected_file() {
    var service = new HolderLinux.RecoveryService();

    string attachment_path = "";
    try {
        attachment_path = service.write_payload_to_temp_attachment("Project Name", "{\"token\":\"abc\"}");
    } catch (Error e) {
        assert_not_reached();
    }

    assert(attachment_path.has_suffix("Project-Name-recovery.hrk"));
    assert(FileUtils.test(attachment_path, FileTest.EXISTS));

    string payload = "";
    try {
        FileUtils.get_contents(attachment_path, out payload);
    } catch (FileError e) {
        assert_not_reached();
    }
    assert(payload == "{\"token\":\"abc\"}");
}

private void test_write_payload_to_temp_attachment_rejects_empty_payload() {
    var service = new HolderLinux.RecoveryService();

    try {
        service.write_payload_to_temp_attachment("Project", "   ");
        assert_not_reached();
    } catch (Error e) {
        assert(e.message.contains("Empty recovery token payload."));
    }
}

private void test_open_email_with_attachment_uses_xdg_email() {
    var service = new HolderLinux.RecoveryService();
    var temp_dir = make_temp_dir();
    var script_path = Path.build_filename(temp_dir, "xdg-email");
    var output_path = Path.build_filename(temp_dir, "args.txt");

    var script = "#!/bin/sh\necho HOLDER_FAKE_EMAIL > %s\nprintf '%%s\\n' \"$@\" >> %s\n".printf(
        Shell.quote(output_path),
        Shell.quote(output_path)
    );
    try {
        FileUtils.set_contents(script_path, script);
    } catch (FileError e) {
        assert_not_reached();
    }

    try {
        assert(Process.spawn_command_line_sync("chmod 755 %s".printf(Shell.quote(script_path)), null, null, null));
    } catch (SpawnError e) {
        assert_not_reached();
    }

    var old_path = Environment.get_variable("PATH");
    Environment.set_variable("PATH", "%s:%s".printf(temp_dir, old_path ?? ""), true);

    try {
        service.open_email_with_attachment("/tmp/recovery.hrk");
    } catch (Error e) {
        Environment.set_variable("PATH", old_path ?? "", true);
        assert_not_reached();
    }

    Environment.set_variable("PATH", old_path ?? "", true);

    assert(wait_for_file(output_path));

    string args_output = wait_for_nonempty_file_contents(output_path);

    assert(args_output.contains("HOLDER_FAKE_EMAIL"));
}

private void test_save_and_load_payload_round_trip() {
    var service = new HolderLinux.RecoveryService();
    var temp_dir = make_temp_dir();
    var path = Path.build_filename(temp_dir, "token.hrk");

    try {
        service.save_payload_to_path(path, "{\"token\":\"abc\"}");
    } catch (Error e) {
        assert_not_reached();
    }

    string payload = "";
    try {
        payload = service.load_payload_from_path(path);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(payload == "{\"token\":\"abc\"}");
}

private void test_save_payload_to_path_validates_inputs() {
    var service = new HolderLinux.RecoveryService();

    try {
        service.save_payload_to_path("   ", "payload");
        assert_not_reached();
    } catch (Error e) {
        assert(e.message.contains("Please choose a local filesystem path."));
    }

    try {
        service.save_payload_to_path("/tmp/out.hrk", "   ");
        assert_not_reached();
    } catch (Error e) {
        assert(e.message.contains("Empty recovery token payload."));
    }
}

private void test_load_payload_from_path_validates_inputs() {
    var service = new HolderLinux.RecoveryService();

    try {
        service.load_payload_from_path("   ");
        assert_not_reached();
    } catch (Error e) {
        assert(e.message.contains("Please choose a local filesystem path."));
    }

    var temp_dir = make_temp_dir();
    var empty_path = Path.build_filename(temp_dir, "empty.hrk");
    try {
        FileUtils.set_contents(empty_path, "   ");
    } catch (FileError e) {
        assert_not_reached();
    }

    try {
        service.load_payload_from_path(empty_path);
        assert_not_reached();
    } catch (Error e) {
        assert(e.message.contains("Selected file is empty."));
    }
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/holder/recovery-service/build-safe-filename-replaces-spaces",
                  test_build_safe_filename_replaces_spaces);
    Test.add_func("/holder/recovery-service/write-payload-to-temp-attachment-writes-expected-file",
                  test_write_payload_to_temp_attachment_writes_expected_file);
    Test.add_func("/holder/recovery-service/write-payload-to-temp-attachment-rejects-empty-payload",
                  test_write_payload_to_temp_attachment_rejects_empty_payload);
    Test.add_func("/holder/recovery-service/open-email-with-attachment-uses-xdg-email",
                  test_open_email_with_attachment_uses_xdg_email);
    Test.add_func("/holder/recovery-service/save-and-load-payload-round-trip",
                  test_save_and_load_payload_round_trip);
    Test.add_func("/holder/recovery-service/save-payload-to-path-validates-inputs",
                  test_save_payload_to_path_validates_inputs);
    Test.add_func("/holder/recovery-service/load-payload-from-path-validates-inputs",
                  test_load_payload_from_path_validates_inputs);

    return Test.run();
}

}
