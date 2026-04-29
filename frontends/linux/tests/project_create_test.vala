using GLib;

namespace HolderLinux.Tests {

private void test_build_submission_requires_non_empty_name() {
    var controller = new HolderLinux.ProjectCreateController();
    string? error_title = null;
    string? error_details = null;
    controller.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });

    var submission = controller.build_submission("   ", false);

    assert(submission == null);
    assert(error_title == "Project name required");
    assert(error_details == "Please enter a non-empty project name.");
}

private void test_build_submission_trims_name_and_sets_privacy_mode() {
    var controller = new HolderLinux.ProjectCreateController();

    var plain = controller.build_submission("  Demo Project  ", false);
    assert(plain != null);
    assert(((!) plain).name == "Demo Project");
    assert(((!) plain).privacy_mode == "plain");

    var encrypted = controller.build_submission("Secure", true);
    assert(encrypted != null);
    assert(((!) encrypted).privacy_mode == "encrypted_git");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/project-create/build-submission-requires-non-empty-name", test_build_submission_requires_non_empty_name);
    Test.add_func("/holder/project-create/build-submission-trims-name-and-sets-privacy-mode", test_build_submission_trims_name_and_sets_privacy_mode);
    return Test.run();
}

}
