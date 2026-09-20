using GLib;

namespace HolderLinuxTests {

private Gee.ArrayList<HolderLinux.ResourceCardReference> references(int count) {
    var list = new Gee.ArrayList<HolderLinux.ResourceCardReference>();
    for (int i = 1; i <= count; i++) {
        list.add(new HolderLinux.ResourceCardReference("c%d".printf(i), "Card %d".printf(i), i));
    }
    return list;
}

private HolderLinux.ProjectResource presented_resource(Gee.ArrayList<HolderLinux.ResourceAsset>? assets = null,
                                                       Gee.ArrayList<HolderLinux.ResourceCardReference>? refs = null,
                                                       string uri = "https://example.com",
                                                       string? desc = "Docs") {
    return new HolderLinux.ProjectResource(
        "r1", "p1", "website", uri, "Example", desc, 1700000000, 1700000100, null, assets, refs
    );
}

private HolderLinux.ResourceAsset presented_asset(string id) {
    return new HolderLinux.ResourceAsset(id, "r1", id + ".png", "image/png", 3);
}

private void test_cell_presents_text_and_tooltip_for_each_field() {
    var controller = new HolderLinux.ResourcesController();
    var resource = presented_resource();

    var label = HolderLinux.ResourcesPresenter.cell(controller, resource, "label");
    assert(label.text == "Example" && label.tooltip == "Example");
    var kind = HolderLinux.ResourcesPresenter.cell(controller, resource, "kind");
    assert(kind.text == "website" && kind.tooltip == "website");
    var uri = HolderLinux.ResourcesPresenter.cell(controller, resource, "uri");
    assert(uri.text == "https://example.com" && uri.tooltip == "https://example.com");
    var desc = HolderLinux.ResourcesPresenter.cell(controller, resource, "desc");
    assert(desc.text == "Docs" && desc.tooltip == "Docs");
    var updated = HolderLinux.ResourcesPresenter.cell(controller, resource, "updated");
    assert(updated.text == controller.format_epoch(1700000100));
    assert(updated.tooltip == "1700000100");
}

private void test_cell_ellipsizes_long_text_but_keeps_full_tooltip() {
    var controller = new HolderLinux.ResourcesController();
    var long_uri = "https://example.com/" + string.nfill(60, 'a');
    var resource = presented_resource(null, null, long_uri, null);

    var uri = HolderLinux.ResourcesPresenter.cell(controller, resource, "uri");
    assert(uri.text.has_suffix("..."));
    assert(uri.text.char_count() < long_uri.char_count());
    assert(uri.tooltip == long_uri);

    var desc = HolderLinux.ResourcesPresenter.cell(controller, resource, "desc");
    assert(desc.text == "");
    assert(desc.tooltip == "");
}

private void test_cell_pluralises_asset_tooltip_and_ignores_unknown_fields() {
    var controller = new HolderLinux.ResourcesController();
    var none = HolderLinux.ResourcesPresenter.cell(controller, presented_resource(), "assets");
    assert(none.text == "0" && none.tooltip == "0 attached assets");

    var one_asset = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    one_asset.add(presented_asset("a1"));
    var one = HolderLinux.ResourcesPresenter.cell(controller, presented_resource(one_asset), "assets");
    assert(one.text == "1" && one.tooltip == "1 attached asset");

    var two_assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    two_assets.add(presented_asset("a1"));
    two_assets.add(presented_asset("a2"));
    var two = HolderLinux.ResourcesPresenter.cell(controller, presented_resource(two_assets), "assets");
    assert(two.text == "2" && two.tooltip == "2 attached assets");

    var unknown = HolderLinux.ResourcesPresenter.cell(controller, presented_resource(), "nope");
    assert(unknown.text == "" && unknown.tooltip == null);
}

private void test_usage_collapses_references_after_two() {
    var unused = HolderLinux.ResourcesPresenter.usage(presented_resource());
    assert(unused.is_unused);

    var one = HolderLinux.ResourcesPresenter.usage(presented_resource(null, references(1)));
    assert(!one.is_unused);
    assert(one.visible_references.size == 1);
    assert(one.remaining_count == 0);

    var two = HolderLinux.ResourcesPresenter.usage(presented_resource(null, references(2)));
    assert(two.visible_references.size == 2);
    assert(two.remaining_count == 0);

    var three = HolderLinux.ResourcesPresenter.usage(presented_resource(null, references(3)));
    assert(three.visible_references.size == 1);
    assert(three.visible_references[0].card_id == "c1");
    assert(three.remaining_count == 2);
    assert(three.overflow_label == "+2 more");
    assert(three.overflow_tooltip == "Card 1\nCard 2\nCard 3");
}

private void test_reference_tooltip_and_link_kind_names() {
    var plain = new HolderLinux.ResourceCardReference("c1", "Notes", 1);
    assert(HolderLinux.ResourcesPresenter.reference_tooltip(plain) == "Notes");

    var kinds = new Gee.ArrayList<string>();
    kinds.add("attachment");
    kinds.add("see_also");
    var detailed = new HolderLinux.ResourceCardReference("c1", "Notes", 1, kinds);
    assert(HolderLinux.ResourcesPresenter.reference_tooltip(detailed) == "Notes · Attachment, See also");

    assert(HolderLinux.ResourcesPresenter.friendly_link_kind("attachment") == "Attachment");
    assert(HolderLinux.ResourcesPresenter.friendly_link_kind("reference") == "Reference");
    assert(HolderLinux.ResourcesPresenter.friendly_link_kind("") == "Linked");
    assert(HolderLinux.ResourcesPresenter.friendly_link_kind("see_also") == "See also");
}

private void test_open_action_prefers_asset_then_reports_then_launches() {
    var assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    assets.add(presented_asset("first"));
    assets.add(presented_asset("second"));
    var preview = HolderLinux.ResourcesPresenter.open_action(presented_resource(assets));
    assert(preview.kind == HolderLinux.ResourceOpenKind.PREVIEW_ASSET);
    assert(preview.asset.asset_id == "first");

    var nothing = HolderLinux.ResourcesPresenter.open_action(presented_resource(null, null, "   "));
    assert(nothing.kind == HolderLinux.ResourceOpenKind.TOAST);
    assert(nothing.text == "This Resource has no Asset or identifier to open.");

    var launch = HolderLinux.ResourcesPresenter.open_action(presented_resource());
    assert(launch.kind == HolderLinux.ResourceOpenKind.LAUNCH_URI);
    assert(launch.text == "https://example.com");
}

private void test_picked_file_label_only_fills_a_blank_label() {
    assert(HolderLinux.ResourcesPresenter.picked_file_label("", "photo.png") == "photo.png");
    assert(HolderLinux.ResourcesPresenter.picked_file_label("   ", "photo.png") == "photo.png");
    assert(HolderLinux.ResourcesPresenter.picked_file_label("Mine", "photo.png") == null);
    assert(HolderLinux.ResourcesPresenter.picked_file_label("", null) == null);
    assert(HolderLinux.ResourcesPresenter.picked_file_label("", "") == null);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/resources-presenter/cell-fields", test_cell_presents_text_and_tooltip_for_each_field);
    Test.add_func("/holder/resources-presenter/cell-ellipsis", test_cell_ellipsizes_long_text_but_keeps_full_tooltip);
    Test.add_func("/holder/resources-presenter/cell-assets-and-unknown",
                  test_cell_pluralises_asset_tooltip_and_ignores_unknown_fields);
    Test.add_func("/holder/resources-presenter/usage", test_usage_collapses_references_after_two);
    Test.add_func("/holder/resources-presenter/reference-tooltip", test_reference_tooltip_and_link_kind_names);
    Test.add_func("/holder/resources-presenter/open-action", test_open_action_prefers_asset_then_reports_then_launches);
    Test.add_func("/holder/resources-presenter/picked-file-label", test_picked_file_label_only_fills_a_blank_label);
    return Test.run();
}

}
