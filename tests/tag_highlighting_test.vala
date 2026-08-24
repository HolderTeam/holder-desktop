using GLib;

namespace HolderLinuxTests {

private void test_maps_validated_byte_offsets_to_character_ranges() {
    var controller = new HolderLinux.TagHighlightingController();
    var text = "Café #Android and #sync";
    HolderLinux.CardTagOccurrence[] occurrences = {
        new HolderLinux.CardTagOccurrence("android", text.index_of("#Android"), text.index_of("#Android") + 8),
        new HolderLinux.CardTagOccurrence("sync", text.index_of("#sync"), text.index_of("#sync") + 5)
    };

    var ranges = controller.ranges_for(text, occurrences);

    assert(ranges.size == 2);
    assert(ranges[0].char_start == 5);
    assert(ranges[0].char_end == 13);
    assert(ranges[1].char_start == 18);
    assert(ranges[1].char_end == 23);
}

private void test_rejects_stale_or_invalid_backend_ranges() {
    var controller = new HolderLinux.TagHighlightingController();
    var text = "#todo changed";
    HolderLinux.CardTagOccurrence[] occurrences = {
        new HolderLinux.CardTagOccurrence("other", 0, 5),
        new HolderLinux.CardTagOccurrence("todo", -1, 5),
        new HolderLinux.CardTagOccurrence("todo", 0, 100),
        new HolderLinux.CardTagOccurrence("todo", 5, 5)
    };

    assert(controller.ranges_for(text, occurrences).size == 0);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/tag-highlighting/utf8-ranges", test_maps_validated_byte_offsets_to_character_ranges);
    Test.add_func("/holder/tag-highlighting/rejects-stale-ranges", test_rejects_stale_or_invalid_backend_ranges);
    return Test.run();
}

}
