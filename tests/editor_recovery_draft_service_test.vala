using GLib;

namespace HolderLinuxTests {

private string make_temp_dir() {
    try {
        return DirUtils.make_tmp("holder-editor-recovery-draft-XXXXXX");
    } catch (FileError e) {
        assert_not_reached();
    }
}

private void test_save_load_and_remove_recovery_draft_round_trip() {
    string root_dir = make_temp_dir();
    var service = new HolderLinux.EditorRecoveryDraftService(root_dir);
    var draft = new HolderLinux.EditorRecoveryDraft(
        "card-1",
        "project-1",
        "Card 1",
        "# Card 1\n\nBody",
        123
    );

    try {
        service.save_draft(draft);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(FileUtils.test(service.draft_path_for_card_id("card-1"), FileTest.EXISTS));

    HolderLinux.EditorRecoveryDraft? loaded = null;
    try {
        loaded = service.load_draft("card-1");
    } catch (Error e) {
        assert_not_reached();
    }

    assert(loaded != null);
    assert(loaded.card_id == "card-1");
    assert(loaded.project_id == "project-1");
    assert(loaded.title == "Card 1");
    assert(loaded.content == "# Card 1\n\nBody");
    assert(loaded.saved_at == 123);

    try {
        service.remove_draft("card-1");
    } catch (Error e) {
        assert_not_reached();
    }

    assert(!FileUtils.test(service.draft_path_for_card_id("card-1"), FileTest.EXISTS));
}

private void test_save_draft_reports_write_failure() {
    var root_dir = make_temp_dir();
    var service = new HolderLinux.EditorRecoveryDraftService(root_dir);
    var path = service.draft_path_for_card_id("card-1");
    DirUtils.create(path, 0700);

    bool got_error = false;
    try {
        service.save_draft(new HolderLinux.EditorRecoveryDraft("card-1", "project-1", "Title", "Body", 1));
    } catch (Error e) {
        got_error = e.message.contains("Could not save recovery draft:");
    }

    assert(got_error);
}

private void test_load_draft_missing_file_returns_null() {
    var service = new HolderLinux.EditorRecoveryDraftService(make_temp_dir());
    HolderLinux.EditorRecoveryDraft? loaded = null;
    try {
        loaded = service.load_draft("missing-card");
    } catch (Error e) {
        assert_not_reached();
    }
    assert(loaded == null);
}

private void test_load_draft_reports_read_failure_for_directory() {
    var root_dir = make_temp_dir();
    var service = new HolderLinux.EditorRecoveryDraftService(root_dir);
    var path = service.draft_path_for_card_id("card-1");
    DirUtils.create(path, 0700);

    bool got_error = false;
    try {
        service.load_draft("card-1");
    } catch (Error e) {
        got_error = e.message.contains("Could not read recovery draft:");
    }

    assert(got_error);
}

private void test_load_draft_reports_parse_failure_for_invalid_json() {
    var root_dir = make_temp_dir();
    var service = new HolderLinux.EditorRecoveryDraftService(root_dir);
    try {
        FileUtils.set_contents(service.draft_path_for_card_id("card-1"), "{not-json");
    } catch (FileError e) {
        assert_not_reached();
    }

    bool got_error = false;
    try {
        service.load_draft("card-1");
    } catch (Error e) {
        got_error = e.message.contains("Could not parse recovery draft:");
    }

    assert(got_error);
}

private void test_load_draft_rejects_non_object_payload() {
    var root_dir = make_temp_dir();
    var service = new HolderLinux.EditorRecoveryDraftService(root_dir);
    try {
        FileUtils.set_contents(service.draft_path_for_card_id("card-1"), "[1,2,3]");
    } catch (FileError e) {
        assert_not_reached();
    }

    bool got_error = false;
    try {
        service.load_draft("card-1");
    } catch (Error e) {
        got_error = e.message == "Recovery draft payload is not an object.";
    }

    assert(got_error);
}

private void test_remove_draft_reports_delete_failure_for_directory() {
    var root_dir = make_temp_dir();
    var service = new HolderLinux.EditorRecoveryDraftService(root_dir);
    var path = service.draft_path_for_card_id("card-1");
    DirUtils.create(path, 0700);
    try {
        FileUtils.set_contents(Path.build_filename(path, "child.txt"), "x");
    } catch (FileError e) {
        assert_not_reached();
    }

    bool got_error = false;
    try {
        service.remove_draft("card-1");
    } catch (Error e) {
        got_error = e.message.contains("Could not remove recovery draft:");
    }

    assert(got_error);
}

private void test_save_draft_reports_root_dir_creation_failure() {
    var root_dir = make_temp_dir();
    var blocked_root = Path.build_filename(root_dir, "blocked");
    try {
        FileUtils.set_contents(blocked_root, "x");
    } catch (FileError e) {
        assert_not_reached();
    }
    var service = new HolderLinux.EditorRecoveryDraftService(blocked_root);

    bool got_error = false;
    try {
        service.save_draft(new HolderLinux.EditorRecoveryDraft("card-1", "project-1", "Title", "Body", 1));
    } catch (Error e) {
        got_error = e.message == "Could not create recovery draft directory: %s".printf(blocked_root);
    }

    assert(got_error);
}

private void test_draft_path_normalizes_unsafe_characters() {
    var service = new HolderLinux.EditorRecoveryDraftService(make_temp_dir());
    var path = service.draft_path_for_card_id("Abc-123_/x y");
    assert(path.has_suffix("Abc-123__x_y.json"));
}

private void test_saving_again_atomically_replaces_existing_draft() {
    var service = new HolderLinux.EditorRecoveryDraftService(make_temp_dir());
    try {
        service.save_draft(new HolderLinux.EditorRecoveryDraft("card-1", "project-1", "Old", "old", 1));
        service.save_draft(new HolderLinux.EditorRecoveryDraft("card-1", "project-1", "New", "new", 2));
        var loaded = service.load_draft("card-1");
        assert(loaded != null);
        assert(loaded.title == "New");
        assert(loaded.content == "new");
        assert(loaded.saved_at == 2);
    } catch (Error e) {
        assert_not_reached();
    }
}

private void test_recovery_draft_uses_private_permissions_when_supported() {
    var service = new HolderLinux.EditorRecoveryDraftService(make_temp_dir());
    var path = service.draft_path_for_card_id("card-1");
    try {
        service.save_draft(new HolderLinux.EditorRecoveryDraft("card-1", "project-1", "Title", "Body", 1));
        var file_info = File.new_for_path(path).query_info(
            "unix::mode",
            FileQueryInfoFlags.NONE,
            null
        );
        if (file_info.has_attribute("unix::mode")) {
            var file_mode = file_info.get_attribute_uint32("unix::mode");
            assert((file_mode & 0777) == 0600);

            var directory_info = File.new_for_path(Path.get_dirname(path)).query_info(
                "unix::mode",
                FileQueryInfoFlags.NONE,
                null
            );
            assert((directory_info.get_attribute_uint32("unix::mode") & 0777) == 0700);
        }
    } catch (Error e) {
        assert_not_reached();
    }
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func(
        "/editor_recovery_draft_service/save_load_and_remove_round_trip",
        test_save_load_and_remove_recovery_draft_round_trip
    );
    Test.add_func(
        "/editor_recovery_draft_service/save_draft_reports_write_failure",
        test_save_draft_reports_write_failure
    );
    Test.add_func(
        "/editor_recovery_draft_service/load_draft_missing_file_returns_null",
        test_load_draft_missing_file_returns_null
    );
    Test.add_func(
        "/editor_recovery_draft_service/load_draft_reports_read_failure_for_directory",
        test_load_draft_reports_read_failure_for_directory
    );
    Test.add_func(
        "/editor_recovery_draft_service/load_draft_reports_parse_failure_for_invalid_json",
        test_load_draft_reports_parse_failure_for_invalid_json
    );
    Test.add_func(
        "/editor_recovery_draft_service/load_draft_rejects_non_object_payload",
        test_load_draft_rejects_non_object_payload
    );
    Test.add_func(
        "/editor_recovery_draft_service/remove_draft_reports_delete_failure_for_directory",
        test_remove_draft_reports_delete_failure_for_directory
    );
    Test.add_func(
        "/editor_recovery_draft_service/save_draft_reports_root_dir_creation_failure",
        test_save_draft_reports_root_dir_creation_failure
    );
    Test.add_func(
        "/editor_recovery_draft_service/draft_path_normalizes_unsafe_characters",
        test_draft_path_normalizes_unsafe_characters
    );
    Test.add_func(
        "/editor_recovery_draft_service/saving_again_atomically_replaces_existing_draft",
        test_saving_again_atomically_replaces_existing_draft
    );
    Test.add_func(
        "/editor_recovery_draft_service/recovery_draft_uses_private_permissions_when_supported",
        test_recovery_draft_uses_private_permissions_when_supported
    );

    return Test.run();
}

}
