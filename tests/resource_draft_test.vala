using GLib;

namespace HolderLinuxTests {

private HolderLinux.ProjectResource existing_resource(string kind) {
    var metadata = new Gee.HashMap<string, Gee.ArrayList<string>>();
    var identifier = new Gee.ArrayList<string>();
    identifier.add("https://example.com");
    metadata.set("identifier", identifier);
    var description = new Gee.ArrayList<string>();
    description.add("Docs");
    metadata.set("description", description);
    var creator = new Gee.ArrayList<string>();
    creator.add("Ada");
    metadata.set("creator", creator);
    return new HolderLinux.ProjectResource(
        "r1", "p1", kind, "https://example.com", "Example", "Docs", 1, 2, metadata
    );
}

private void test_kind_options_are_defaults_followed_by_custom() {
    var controller = new HolderLinux.ResourcesController();
    var options = HolderLinux.ResourceDraft.kind_options(controller);
    assert(options.length == controller.default_resource_kinds().length + 1);
    assert(options[0] == "thing");
    assert(options[options.length - 1] == "custom");
}

private void test_select_kind_defaults_matches_and_falls_back_to_custom_slot() {
    var controller = new HolderLinux.ResourcesController();
    var options = HolderLinux.ResourceDraft.kind_options(controller);

    var fresh = HolderLinux.ResourceDraft.select_kind(options, null);
    assert(fresh.index == 0);
    assert(fresh.custom_text == "");

    var matched = HolderLinux.ResourceDraft.select_kind(options, existing_resource("website"));
    assert(options[matched.index] == "website");
    assert(matched.custom_text == "");

    var unknown = HolderLinux.ResourceDraft.select_kind(options, existing_resource("recipe"));
    assert(unknown.index == options.length - 1);
    assert(unknown.custom_text == "recipe");

    var literal_custom = HolderLinux.ResourceDraft.select_kind(options, existing_resource("custom"));
    assert(literal_custom.index == options.length - 1);
    assert(literal_custom.custom_text == "");
}

private void test_resolve_kind_uses_listed_option_or_stripped_custom_text() {
    var controller = new HolderLinux.ResourcesController();
    var options = HolderLinux.ResourceDraft.kind_options(controller);
    var custom_slot = (uint) (options.length - 1);

    assert(HolderLinux.ResourceDraft.resolve_kind(options, 1, "ignored") == options[1]);
    assert(HolderLinux.ResourceDraft.resolve_kind(options, custom_slot, "  recipe  ") == "recipe");
    assert(HolderLinux.ResourceDraft.resolve_kind(options, custom_slot, "   ") == "thing");
    assert(HolderLinux.ResourceDraft.resolve_kind(options, custom_slot, "") == "thing");
}

private void test_save_state_requires_label_and_valid_details() {
    var controller = new HolderLinux.ResourcesController();

    var blank = HolderLinux.ResourceDraft.save_state(controller, "   ", "not valid details");
    assert(!blank.enabled);
    assert(blank.error_message == null);

    var valid = HolderLinux.ResourceDraft.save_state(controller, "Label", "creator: Ada");
    assert(valid.enabled);
    assert(valid.error_message == null);

    var empty_details = HolderLinux.ResourceDraft.save_state(controller, "Label", "");
    assert(empty_details.enabled);

    var invalid = HolderLinux.ResourceDraft.save_state(controller, "Label", "no separator here");
    assert(!invalid.enabled);
    assert(invalid.error_message != null);
    assert(((!) invalid.error_message).contains("property: value"));
}

private void test_build_rejects_blank_label_and_bad_details() {
    var controller = new HolderLinux.ResourcesController();

    var no_label = HolderLinux.ResourceDraft.build(controller, null, "thing", "", "  ", "", "");
    assert(no_label.error_message == "A label is required.");

    var bad_details = HolderLinux.ResourceDraft.build(controller, null, "thing", "", "Label", "", "oops");
    assert(bad_details.error_message != null);
    assert(((!) bad_details.error_message).contains("property: value"));
}

private void test_build_strips_fields_and_parses_details_for_a_new_resource() {
    var controller = new HolderLinux.ResourcesController();
    var draft = HolderLinux.ResourceDraft.build(
        controller, null, "book", "  https://example.com  ", "  My Book ", "  A description ",
        "creator: Ada\ncreator: Bob"
    );
    assert(draft.error_message == null);
    assert(draft.kind == "book");
    assert(draft.uri == "https://example.com");
    assert(draft.label == "My Book");
    assert(draft.desc == "A description");
    assert(draft.extra_metadata.get("creator").size == 2);

    var blank_desc = HolderLinux.ResourceDraft.build(controller, null, "thing", "", "Label", "   ", "");
    assert(blank_desc.desc == null);
    assert(blank_desc.extra_metadata.size == 0);
}

private void test_build_for_existing_resource_clears_removed_custom_properties() {
    var controller = new HolderLinux.ResourcesController();
    var existing = existing_resource("website");

    var removed = HolderLinux.ResourceDraft.build(controller, existing, "website", "", "Example", "", "");
    assert(removed.error_message == null);
    assert(removed.extra_metadata.has_key("creator"));
    assert(removed.extra_metadata.get("creator").size == 0);
    assert(!removed.extra_metadata.has_key("identifier"));
    assert(!removed.extra_metadata.has_key("description"));

    var kept = HolderLinux.ResourceDraft.build(
        controller, existing, "website", "", "Example", "", "creator: Grace"
    );
    assert(kept.extra_metadata.get("creator").size == 1);
    assert(kept.extra_metadata.get("creator")[0] == "Grace");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/resource-draft/kind-options", test_kind_options_are_defaults_followed_by_custom);
    Test.add_func("/holder/resource-draft/select-kind", test_select_kind_defaults_matches_and_falls_back_to_custom_slot);
    Test.add_func("/holder/resource-draft/resolve-kind", test_resolve_kind_uses_listed_option_or_stripped_custom_text);
    Test.add_func("/holder/resource-draft/save-state", test_save_state_requires_label_and_valid_details);
    Test.add_func("/holder/resource-draft/build-rejections", test_build_rejects_blank_label_and_bad_details);
    Test.add_func("/holder/resource-draft/build-new", test_build_strips_fields_and_parses_details_for_a_new_resource);
    Test.add_func("/holder/resource-draft/build-existing", test_build_for_existing_resource_clears_removed_custom_properties);
    return Test.run();
}

}
