using GLib;

namespace HolderLinuxTests {

private HolderLinux.ResourceAsset make_asset(string asset_id, string filename, string media_type) {
    return new HolderLinux.ResourceAsset(asset_id, "r1", filename, media_type, 1, "");
}

private HolderLinux.CardAttachment make_attachment(string asset_id,
                                                   string filename = "file.bin",
                                                   string media_type = "application/octet-stream") {
    var assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    var asset = make_asset(asset_id, filename, media_type);
    assets.add(asset);
    var resource = new HolderLinux.ProjectResource(
        "r1", "p1", "thing", "", "Label", null, 1, 2, null, assets
    );
    return new HolderLinux.CardAttachment("c1", resource, asset);
}

private Gee.ArrayList<HolderLinux.CardAttachment> make_list(string[] asset_ids) {
    var list = new Gee.ArrayList<HolderLinux.CardAttachment>();
    foreach (var id in asset_ids) {
        list.add(make_attachment(id));
    }
    return list;
}

private void test_empty_attachment_list_selects_nothing() {
    var selection = new HolderLinux.AttachmentSelection();
    var applied = selection.apply_attachments(make_list({}));
    assert(applied.selected_index == -1);
    assert(applied.display_index == 0);
    assert(!applied.has_selection);
    assert(!applied.reveal_preview);
    assert(selection.selected_attachment() == null);
}

private void test_first_attachment_is_selected_without_revealing_the_preview() {
    var selection = new HolderLinux.AttachmentSelection();
    var applied = selection.apply_attachments(make_list({"a1", "a2"}));
    assert(applied.selected_index == 0);
    assert(applied.has_selection);
    assert(!applied.reveal_preview);
    assert(selection.selected_attachment().asset.asset_id == "a1");
}

private void test_previous_selection_is_restored_by_asset_id() {
    var selection = new HolderLinux.AttachmentSelection();
    selection.apply_attachments(make_list({"a1", "a2", "a3"}));
    selection.begin_load(2);

    var applied = selection.apply_attachments(make_list({"a3", "a1", "a2"}));
    assert(applied.selected_index == 0);
    assert(applied.reveal_preview);

    selection.begin_load(1);
    var missing = selection.apply_attachments(make_list({"x1", "x2"}));
    assert(missing.selected_index == 0);
    assert(missing.reveal_preview);
}

private void test_pending_preview_asset_wins_and_is_consumed() {
    var selection = new HolderLinux.AttachmentSelection();
    selection.apply_attachments(make_list({"a1", "a2"}));
    selection.pending_preview_asset_id = "a2";
    var applied = selection.apply_attachments(make_list({"a1", "a2", "a3"}));
    assert(applied.selected_index == 1);
    assert(applied.reveal_preview);
    assert(selection.pending_preview_asset_id == null);

    selection.pending_preview_asset_id = "gone";
    var fallback = selection.apply_attachments(make_list({"a1", "a2"}));
    assert(fallback.selected_index == 0);
    assert(fallback.reveal_preview);
}

private void test_pending_preview_with_no_attachments_does_not_reveal() {
    var selection = new HolderLinux.AttachmentSelection();
    selection.pending_preview_asset_id = "a1";
    var applied = selection.apply_attachments(make_list({}));
    assert(applied.selected_index == -1);
    assert(!applied.reveal_preview);
}

private void test_show_single_replaces_the_list() {
    var selection = new HolderLinux.AttachmentSelection();
    selection.apply_attachments(make_list({"a1", "a2"}));
    selection.show_single(make_attachment("solo"));
    assert(selection.attachments.size == 1);
    assert(selection.selected_index == 0);
    assert(selection.selected_attachment().asset.asset_id == "solo");
}

private void test_begin_load_validates_index_and_clears_cache_path() {
    var selection = new HolderLinux.AttachmentSelection();
    selection.apply_attachments(make_list({"a1", "a2"}));
    assert(selection.begin_load(-1) == null);
    assert(selection.begin_load(2) == null);

    selection.selected_cache_path = "/cache/old";
    var ticket = selection.begin_load(1);
    assert(ticket != null);
    assert(((!) ticket).index == 1);
    assert(((!) ticket).attachment.asset.asset_id == "a2");
    assert(selection.selected_index == 1);
    assert(selection.selected_cache_path == null);
}

private void test_newer_load_makes_older_tickets_stale() {
    var selection = new HolderLinux.AttachmentSelection();
    selection.apply_attachments(make_list({"a1", "a2"}));
    var first = selection.begin_load(0);
    assert(selection.is_load_current((!) first));
    assert(selection.is_error_current((!) first));

    var second = selection.begin_load(1);
    assert(!selection.is_load_current((!) first));
    assert(!selection.is_error_current((!) first));
    assert(selection.is_load_current((!) second));
}

private void test_selection_change_without_new_load_only_stales_success() {
    var selection = new HolderLinux.AttachmentSelection();
    selection.apply_attachments(make_list({"a1", "a2"}));
    var ticket = selection.begin_load(1);

    // The attachment list refreshes without a2, so the selection falls back to the first item.
    selection.apply_attachments(make_list({"a1"}));
    assert(selection.selected_index == 0);
    assert(!selection.is_load_current((!) ticket));
    assert(selection.is_error_current((!) ticket));
}

private void test_selected_attachment_is_null_when_index_is_out_of_range() {
    var selection = new HolderLinux.AttachmentSelection();
    assert(selection.selected_attachment() == null);
    selection.apply_attachments(make_list({"a1"}));
    assert(selection.selected_attachment() != null);
}

private void test_is_image_checks_the_media_type_prefix() {
    assert(HolderLinux.AttachmentSelection.is_image(make_attachment("a", "p.png", "image/png")));
    assert(!HolderLinux.AttachmentSelection.is_image(make_attachment("a", "p.pdf", "application/pdf")));
}

private void test_find_inline_image_uses_the_first_image_asset_of_the_resource() {
    var assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    assets.add(make_asset("doc", "doc.pdf", "application/pdf"));
    assets.add(make_asset("img1", "one.png", "image/png"));
    assets.add(make_asset("img2", "two.png", "image/png"));
    var with_image = new HolderLinux.ProjectResource("r1", "p1", "thing", "", "L", null, 1, 2, null, assets);
    var no_image_assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    no_image_assets.add(make_asset("doc2", "doc.pdf", "application/pdf"));
    var without_image = new HolderLinux.ProjectResource("r2", "p1", "thing", "", "L", null, 1, 2, null, no_image_assets);
    var resources = new Gee.ArrayList<HolderLinux.ProjectResource>();
    resources.add(without_image);
    resources.add(with_image);

    var found = HolderLinux.AttachmentSelection.find_inline_image(resources, "r1");
    assert(found != null);
    assert(((!) found).asset.asset_id == "img1");
    assert(((!) found).resource.resource_id == "r1");
    assert(HolderLinux.AttachmentSelection.find_inline_image(resources, "r2") == null);
    assert(HolderLinux.AttachmentSelection.find_inline_image(resources, "missing") == null);
    assert(HolderLinux.AttachmentSelection.NO_IMAGE_MESSAGE
        == "This Resource has no image available in the current project.");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/attachment-selection/empty", test_empty_attachment_list_selects_nothing);
    Test.add_func("/attachment-selection/first-selected", test_first_attachment_is_selected_without_revealing_the_preview);
    Test.add_func("/attachment-selection/restore-by-asset-id", test_previous_selection_is_restored_by_asset_id);
    Test.add_func("/attachment-selection/pending-preview", test_pending_preview_asset_wins_and_is_consumed);
    Test.add_func("/attachment-selection/pending-without-attachments", test_pending_preview_with_no_attachments_does_not_reveal);
    Test.add_func("/attachment-selection/show-single", test_show_single_replaces_the_list);
    Test.add_func("/attachment-selection/begin-load", test_begin_load_validates_index_and_clears_cache_path);
    Test.add_func("/attachment-selection/newer-load-stales-older", test_newer_load_makes_older_tickets_stale);
    Test.add_func("/attachment-selection/selection-change", test_selection_change_without_new_load_only_stales_success);
    Test.add_func("/attachment-selection/selected-attachment-bounds", test_selected_attachment_is_null_when_index_is_out_of_range);
    Test.add_func("/attachment-selection/is-image", test_is_image_checks_the_media_type_prefix);
    Test.add_func("/attachment-selection/find-inline-image", test_find_inline_image_uses_the_first_image_asset_of_the_resource);
    return Test.run();
}

}
