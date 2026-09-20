using GLib;

namespace HolderLinuxTests {

private Gee.ArrayList<string> string_list(string[] values) {
    var list = new Gee.ArrayList<string>();
    foreach (var value in values) {
        list.add(value);
    }
    return list;
}

private void test_listed_kind_is_used_as_is() {
    var request = HolderLinux.ConnectionsAddLinkPresenter.resolve(
        string_list({ "c2", "c3" }), 1, string_list({ "ref", "blocks" }), 1, "ignored", ""
    );
    assert(request != null);
    assert(request.to_card_id == "c3");
    assert(request.kind == "blocks");
    assert(request.label == null);
    assert(!request.remember_kind);
}

private void test_custom_kind_is_trimmed_and_remembered() {
    var request = HolderLinux.ConnectionsAddLinkPresenter.resolve(
        string_list({ "c2" }), 0, string_list({ "ref", "blocks" }), 2, "  cites  ", "  because  "
    );
    assert(request.kind == "cites");
    assert(request.remember_kind);
    assert(request.label == "because");
}

private void test_blank_custom_kind_falls_back_to_ref_without_remembering() {
    var request = HolderLinux.ConnectionsAddLinkPresenter.resolve(
        string_list({ "c2" }), 0, string_list({ "ref" }), 1, "   ", "   "
    );
    assert(request.kind == "ref");
    assert(!request.remember_kind);
    assert(request.label == null);
}

private void test_invalid_kind_index_is_treated_as_custom() {
    var request = HolderLinux.ConnectionsAddLinkPresenter.resolve(
        string_list({ "c2" }), 0, string_list({ "ref" }), -1, "mine", ""
    );
    assert(request.kind == "mine");
    assert(request.remember_kind);
}

private void test_empty_listed_kind_falls_back_to_ref() {
    var request = HolderLinux.ConnectionsAddLinkPresenter.resolve(
        string_list({ "c2" }), 0, string_list({ "" }), 0, "", ""
    );
    assert(request.kind == "ref");
    assert(!request.remember_kind);
}

private void test_out_of_range_target_yields_no_request() {
    assert(HolderLinux.ConnectionsAddLinkPresenter.resolve(
        string_list({ "c2" }), 1, string_list({ "ref" }), 0, "", ""
    ) == null);
    assert(HolderLinux.ConnectionsAddLinkPresenter.resolve(
        string_list({}), uint.MAX, string_list({ "ref" }), 0, "", ""
    ) == null);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/connections-add-link/listed-kind", test_listed_kind_is_used_as_is);
    Test.add_func("/holder/connections-add-link/custom-kind", test_custom_kind_is_trimmed_and_remembered);
    Test.add_func("/holder/connections-add-link/blank-custom-kind",
                  test_blank_custom_kind_falls_back_to_ref_without_remembering);
    Test.add_func("/holder/connections-add-link/invalid-kind-index", test_invalid_kind_index_is_treated_as_custom);
    Test.add_func("/holder/connections-add-link/empty-listed-kind", test_empty_listed_kind_falls_back_to_ref);
    Test.add_func("/holder/connections-add-link/out-of-range-target", test_out_of_range_target_yields_no_request);
    return Test.run();
}

}
