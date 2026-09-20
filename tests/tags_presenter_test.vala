using GLib;

namespace HolderLinuxTests {

private Gee.ArrayList<HolderLinux.TagCount> tag_counts(string[] tags, int[] counts) {
    var list = new Gee.ArrayList<HolderLinux.TagCount>();
    for (int i = 0; i < tags.length; i++) {
        list.add(new HolderLinux.TagCount(tags[i], counts[i]));
    }
    return list;
}

private void test_sort_tags_orders_by_tag_name() {
    var tags = tag_counts({ "zeta", "alpha", "Beta" }, { 1, 2, 3 });
    HolderLinux.TagsPresenter.sort_tags(tags);
    assert(tags[0].tag == "Beta");
    assert(tags[1].tag == "alpha");
    assert(tags[2].tag == "zeta");
}

private void test_chip_labels_and_tooltips() {
    var card_chip = HolderLinux.TagsPresenter.card_tag_chip("todo");
    assert(card_chip.tag == "todo");
    assert(card_chip.label == "#todo");
    assert(card_chip.tooltip == "Show cards tagged #todo");
    assert(card_chip.css_class == "");

    var single = HolderLinux.TagsPresenter.cloud_chip("todo", 1, "heading");
    assert(single.label == "#todo  1");
    assert(single.tooltip == "1 card tagged #todo");
    assert(single.css_class == "heading");

    var plural = HolderLinux.TagsPresenter.cloud_chip("todo", 5, "");
    assert(plural.tooltip == "5 cards tagged #todo");
}

private void test_weight_class_thresholds() {
    assert(HolderLinux.TagsPresenter.weight_class(1, 1) == "");
    assert(HolderLinux.TagsPresenter.weight_class(0, 0) == "");
    assert(HolderLinux.TagsPresenter.weight_class(6, 9) == "title-4");
    assert(HolderLinux.TagsPresenter.weight_class(9, 9) == "title-4");
    assert(HolderLinux.TagsPresenter.weight_class(3, 9) == "heading");
    assert(HolderLinux.TagsPresenter.weight_class(5, 9) == "heading");
    assert(HolderLinux.TagsPresenter.weight_class(2, 9) == "");
}

private void test_cloud_without_filter_weights_every_tag() {
    var tags = tag_counts({ "big", "mid", "small" }, { 9, 4, 1 });
    var cloud = HolderLinux.TagsPresenter.cloud(tags, "");
    assert(cloud.chips.size == 3);
    assert(cloud.chips[0].css_class == "title-4");
    assert(cloud.chips[1].css_class == "heading");
    assert(cloud.chips[2].css_class == "");
    assert(!cloud.empty_visible);
}

private void test_cloud_filter_is_case_insensitive_and_trimmed() {
    var tags = tag_counts({ "Alpha", "beta", "alphabet" }, { 3, 3, 1 });
    var cloud = HolderLinux.TagsPresenter.cloud(tags, "  ALPHA ");
    assert(cloud.chips.size == 2);
    assert(cloud.chips[0].tag == "Alpha");
    assert(cloud.chips[1].tag == "alphabet");
    // weighting still uses the max over all tags (3), not just the filtered ones
    assert(cloud.chips[0].css_class == "title-4");
    assert(cloud.chips[1].css_class == "heading");
    assert(!cloud.empty_visible);
}

private void test_cloud_empty_states() {
    var none = HolderLinux.TagsPresenter.cloud(new Gee.ArrayList<HolderLinux.TagCount>(), "");
    assert(none.chips.size == 0);
    assert(none.empty_visible);
    assert(none.empty_text == "No tags in this project yet.");

    var still_none = HolderLinux.TagsPresenter.cloud(new Gee.ArrayList<HolderLinux.TagCount>(), "x");
    // Preserved from the original view: any active filter with zero results reports "no match".
    assert(still_none.empty_text == "No tags match this filter.");

    var tags = tag_counts({ "alpha" }, { 1 });
    var no_match = HolderLinux.TagsPresenter.cloud(tags, "zzz");
    assert(no_match.chips.size == 0);
    assert(no_match.empty_visible);
    assert(no_match.empty_text == "No tags match this filter.");
}

private void test_format_updated_at() {
    assert(HolderLinux.TagsPresenter.format_updated_at(0) == "");
    assert(HolderLinux.TagsPresenter.format_updated_at(-5) == "");
    var text = HolderLinux.TagsPresenter.format_updated_at(1700000000);
    assert(text.has_prefix("Updated "));
    assert(text.length > "Updated ".length);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/tags-presenter/sort", test_sort_tags_orders_by_tag_name);
    Test.add_func("/tags-presenter/chips", test_chip_labels_and_tooltips);
    Test.add_func("/tags-presenter/weight-class", test_weight_class_thresholds);
    Test.add_func("/tags-presenter/cloud-weights", test_cloud_without_filter_weights_every_tag);
    Test.add_func("/tags-presenter/cloud-filter", test_cloud_filter_is_case_insensitive_and_trimmed);
    Test.add_func("/tags-presenter/cloud-empty", test_cloud_empty_states);
    Test.add_func("/tags-presenter/format-updated-at", test_format_updated_at);
    return Test.run();
}

}
