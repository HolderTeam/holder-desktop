using GLib;

namespace HolderLinuxTests {

private void test_finds_backend_validated_tag_at_cursor() {
    var controller = new HolderLinux.TagNavigationController();
    HolderLinux.CardTagOccurrence[] occurrences = {
        new HolderLinux.CardTagOccurrence("android", 4, 12),
        new HolderLinux.CardTagOccurrence("sync", 18, 23)
    };
    var text = "Fix #Android then #sync";
    assert(controller.tag_at_byte_offset(text, 4, occurrences) == "android");
    assert(controller.tag_at_byte_offset(text, 11, occurrences) == "android");
    assert(controller.tag_at_byte_offset(text, 19, occurrences) == "sync");
}

private void test_rejects_unvalidated_markdown_and_other_hash_uses() {
    var controller = new HolderLinux.TagNavigationController();
    HolderLinux.CardTagOccurrence[] only_real_tag = {
        new HolderLinux.CardTagOccurrence("todo", 34, 39)
    };
    var text = "# Heading `#todo` https://x/#todo #todo";
    assert(controller.tag_at_byte_offset(text, 0, only_real_tag) == null);
    assert(controller.tag_at_byte_offset(text, 12, only_real_tag) == null);
    assert(controller.tag_at_byte_offset(text, 29, only_real_tag) == null);
    assert(controller.tag_at_byte_offset(text, 36, only_real_tag) == "todo");
    var stale = new HolderLinux.CardTagOccurrence("todo", 0, 5);
    assert(controller.tag_at_byte_offset("changed", 2, { stale }) == null);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/tags/navigation-finds-validated-tag", test_finds_backend_validated_tag_at_cursor);
    Test.add_func("/holder/tags/navigation-rejects-other-hashes", test_rejects_unvalidated_markdown_and_other_hash_uses);
    return Test.run();
}

}
