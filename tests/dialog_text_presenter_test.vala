using GLib;

namespace HolderLinuxTests {

private void test_update_prompt_body_names_both_versions() {
    assert(HolderLinux.DialogTextPresenter.update_prompt_body("Bug fixes.", "1.2.0", "1.1.0") ==
           "Bug fixes.\n\nHolder 1.2.0 is available. You are running 1.1.0.");
}

private void test_card_dialog_bodies() {
    assert(HolderLinux.DialogTextPresenter.move_to_trash_body("My \"Card\"") ==
           "Move \"My \"Card\"\" to Trash?\n\nYou can restore it from the Trash tool.");
    assert(HolderLinux.DialogTextPresenter.create_linked_card_body("Roadmap") ==
           "No card matches [[Roadmap]] in this project.");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/dialog-text/update-prompt-body", test_update_prompt_body_names_both_versions);
    Test.add_func("/holder/dialog-text/card-dialog-bodies", test_card_dialog_bodies);
    return Test.run();
}

}
