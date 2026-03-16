using GLib;

namespace HolderLinuxTests {

private Json.Object parse_json_object(string payload) {
    var parser = new Json.Parser();
    try {
        parser.load_from_data(payload, -1);
    } catch (Error e) {
        assert_not_reached();
    }
    return parser.get_root().get_object();
}

private void test_string_member_or_empty_paths() {
    var obj = parse_json_object("{\"present\":\"value\",\"nullish\":null}");

    assert(HolderLinux.ApiParsersCommon.string_member_or_empty(obj, "present") == "value");
    assert(HolderLinux.ApiParsersCommon.string_member_or_empty(obj, "missing") == "");
    assert(HolderLinux.ApiParsersCommon.string_member_or_empty(obj, "nullish") == "");
}

private void test_nullable_string_member_or_null_paths() {
    var obj = parse_json_object("{\"present\":\"value\",\"nullish\":null}");

    assert(HolderLinux.ApiParsersCommon.nullable_string_member_or_null(obj, "present") == "value");
    assert(HolderLinux.ApiParsersCommon.nullable_string_member_or_null(obj, "missing") == null);
    assert(HolderLinux.ApiParsersCommon.nullable_string_member_or_null(obj, "nullish") == null);
}

private void test_nullable_int_member_or_null_paths() {
    var obj = parse_json_object("{\"present\":42,\"nullish\":null}");

    assert(HolderLinux.ApiParsersCommon.nullable_int_member_or_null(obj, "present") == 42);
    assert(HolderLinux.ApiParsersCommon.nullable_int_member_or_null(obj, "missing") == null);
    assert(HolderLinux.ApiParsersCommon.nullable_int_member_or_null(obj, "nullish") == null);
}

private void test_object_member_or_null_paths() {
    var obj = parse_json_object("{\"present\":{\"x\":1},\"nullish\":null}");

    var present = HolderLinux.ApiParsersCommon.object_member_or_null(obj, "present");
    assert(present != null);
    assert(present.get_int_member("x") == 1);
    assert(HolderLinux.ApiParsersCommon.object_member_or_null(obj, "missing") == null);
    assert(HolderLinux.ApiParsersCommon.object_member_or_null(obj, "nullish") == null);
}

private void test_parse_response_object_success() {
    Json.Object root;
    try {
        root = HolderLinux.ApiParsersCommon.parse_response_object("{\"ok\":true,\"n\":7}");
    } catch (Error e) {
        assert_not_reached();
    }

    assert(root.get_boolean_member("ok"));
    assert(root.get_int_member("n") == 7);
}

private void test_parse_response_object_invalid_json_throws_parse_error() {
    bool got_parse = false;
    try {
        HolderLinux.ApiParsersCommon.parse_response_object("{not-json");
    } catch (Error e) {
        got_parse = e.message.contains("Invalid JSON response:");
    }

    assert(got_parse);
}

private void test_parse_response_object_non_object_root_throws_parse_error() {
    bool got_parse = false;
    try {
        HolderLinux.ApiParsersCommon.parse_response_object("[]");
    } catch (Error e) {
        got_parse = e.message.contains("Response JSON root is not an object");
    }

    assert(got_parse);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/parsers/common/string-member-or-empty-paths", test_string_member_or_empty_paths);
    Test.add_func("/parsers/common/nullable-string-member-or-null-paths", test_nullable_string_member_or_null_paths);
    Test.add_func("/parsers/common/nullable-int-member-or-null-paths", test_nullable_int_member_or_null_paths);
    Test.add_func("/parsers/common/object-member-or-null-paths", test_object_member_or_null_paths);
    Test.add_func("/parsers/common/parse-response-object-success", test_parse_response_object_success);
    Test.add_func("/parsers/common/parse-response-object-invalid-json", test_parse_response_object_invalid_json_throws_parse_error);
    Test.add_func("/parsers/common/parse-response-object-non-object-root", test_parse_response_object_non_object_root_throws_parse_error);

    return Test.run();
}

}
