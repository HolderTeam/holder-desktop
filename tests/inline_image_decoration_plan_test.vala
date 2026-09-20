using GLib;

namespace HolderLinuxTests {

private HolderLinux.InlineResourceImageItem decoration_item(string resource_id = "r1",
                                                            string label = "Picture",
                                                            string asset_id = "a1",
                                                            string alt_text = "alt",
                                                            int char_offset = 10) {
    var assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    var asset = new HolderLinux.ResourceAsset(asset_id, resource_id, "p.png", "image/png", 1);
    assets.add(asset);
    var resource = new HolderLinux.ProjectResource(
        resource_id, "p1", "image", "", label, null, 1, 2, null, assets
    );
    var reference = new HolderLinux.MarkdownResourceImageReference(alt_text, resource_id, char_offset, 0, 1);
    return new HolderLinux.InlineResourceImageItem(reference, resource, asset);
}

private void test_same_content_requires_all_identity_fields_to_match() {
    var base_item = decoration_item();
    assert(HolderLinux.InlineImageDecorationPlan.same_content(base_item, decoration_item()));
    assert(!HolderLinux.InlineImageDecorationPlan.same_content(base_item, decoration_item("r2")));
    assert(!HolderLinux.InlineImageDecorationPlan.same_content(base_item, decoration_item("r1", "Other")));
    assert(!HolderLinux.InlineImageDecorationPlan.same_content(base_item, decoration_item("r1", "Picture", "a2")));
    assert(!HolderLinux.InlineImageDecorationPlan.same_content(base_item, decoration_item("r1", "Picture", "a1", "new alt")));
}

private void test_offset_position_is_not_part_of_content_identity() {
    assert(HolderLinux.InlineImageDecorationPlan.same_content(
        decoration_item("r1", "Picture", "a1", "alt", 10),
        decoration_item("r1", "Picture", "a1", "alt", 99)
    ));
}

private void test_anchor_at_expected_offset() {
    var item = decoration_item("r1", "Picture", "a1", "alt", 10);
    assert(HolderLinux.InlineImageDecorationPlan.anchor_at_expected_offset(10, item));
    assert(!HolderLinux.InlineImageDecorationPlan.anchor_at_expected_offset(9, item));
    assert(!HolderLinux.InlineImageDecorationPlan.anchor_at_expected_offset(11, item));
}

private void test_decoration_width_uses_view_width_or_fallback() {
    assert(HolderLinux.InlineImageDecorationPlan.decoration_width(0) == 560);
    assert(HolderLinux.InlineImageDecorationPlan.decoration_width(160) == 560);
    assert(HolderLinux.InlineImageDecorationPlan.decoration_width(161) == 81);
    assert(HolderLinux.InlineImageDecorationPlan.decoration_width(1000) == 920);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/inline-image-decoration-plan/same-content", test_same_content_requires_all_identity_fields_to_match);
    Test.add_func("/inline-image-decoration-plan/offset-not-identity", test_offset_position_is_not_part_of_content_identity);
    Test.add_func("/inline-image-decoration-plan/anchor-offset", test_anchor_at_expected_offset);
    Test.add_func("/inline-image-decoration-plan/width", test_decoration_width_uses_view_width_or_fallback);
    return Test.run();
}

}
