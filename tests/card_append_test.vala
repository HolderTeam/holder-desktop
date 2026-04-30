using GLib;

namespace HolderLinux.Tests {

private void test_requires_selected_card() {
    var controller = new HolderLinux.CardAppendController();
    string? last_toast = null;
    controller.toast_requested.connect((message) => {
        last_toast = message;
    });

    var suffix = controller.build_append_suffix(false, "Existing text", "Copied");

    assert(suffix == null);
    assert(last_toast == "Select a card first.");
}

private void test_requires_non_empty_extra_text() {
    var controller = new HolderLinux.CardAppendController();
    string? last_toast = null;
    controller.toast_requested.connect((message) => {
        last_toast = message;
    });

    var null_suffix = controller.build_append_suffix(true, "Existing text", null);
    assert(null_suffix == null);
    assert(last_toast == "Nothing to copy.");

    last_toast = null;
    var empty_suffix = controller.build_append_suffix(true, "Existing text", "");
    assert(empty_suffix == null);
    assert(last_toast == "Nothing to copy.");
}

private void test_appends_with_double_newline_when_existing_text_has_no_trailing_newline() {
    var controller = new HolderLinux.CardAppendController();
    string? last_toast = null;
    controller.toast_requested.connect((message) => {
        last_toast = message;
    });

    var suffix = controller.build_append_suffix(true, "Existing text", "Copied output");

    assert(suffix == "\n\nCopied output");
    assert(last_toast == "Copied terminal output into card.");
}

private void test_appends_with_single_newline_when_existing_text_empty_or_newline_terminated() {
    var controller = new HolderLinux.CardAppendController();
    string? last_toast = null;
    controller.toast_requested.connect((message) => {
        last_toast = message;
    });

    var empty_existing_suffix = controller.build_append_suffix(true, "", "Copied output");
    assert(empty_existing_suffix == "\nCopied output");
    assert(last_toast == "Copied terminal output into card.");

    last_toast = null;
    var newline_terminated_suffix = controller.build_append_suffix(true, "Existing text\n", "Copied output");
    assert(newline_terminated_suffix == "\nCopied output");
    assert(last_toast == "Copied terminal output into card.");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/card-append/requires-selected-card", test_requires_selected_card);
    Test.add_func("/holder/card-append/requires-non-empty-extra-text", test_requires_non_empty_extra_text);
    Test.add_func(
        "/holder/card-append/double-newline-when-existing-text-has-no-trailing-newline",
        test_appends_with_double_newline_when_existing_text_has_no_trailing_newline
    );
    Test.add_func(
        "/holder/card-append/single-newline-when-existing-text-empty-or-newline-terminated",
        test_appends_with_single_newline_when_existing_text_empty_or_newline_terminated
    );
    return Test.run();
}

}
