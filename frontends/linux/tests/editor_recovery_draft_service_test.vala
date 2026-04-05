using GLib;

namespace HolderLinuxTests {

private void test_save_load_and_remove_recovery_draft_round_trip() {
    string root_dir;
    try {
        root_dir = DirUtils.make_tmp("holder-editor-recovery-draft-XXXXXX");
    } catch (FileError e) {
        assert_not_reached();
    }

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

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func(
        "/editor_recovery_draft_service/save_load_and_remove_round_trip",
        test_save_load_and_remove_recovery_draft_round_trip
    );

    return Test.run();
}

}
