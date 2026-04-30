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

private void test_parse_git_test_remote_result_full_and_defaults() {
    var full = parse_json_object(
        "{\"project_id\":\"p1\",\"remote_url\":\"git@example/repo.git\",\"branch\":\"main\",\"status\":\"ok\",\"remote_has_head\":true,\"error_code\":\"\",\"error_message\":\"\"}"
    );
    var full_result = HolderLinux.ApiParsersGit.parse_git_test_remote_result(full);
    assert(full_result.project_id == "p1");
    assert(full_result.remote_url == "git@example/repo.git");
    assert(full_result.branch == "main");
    assert(full_result.status == "ok");
    assert(full_result.remote_has_head);
    assert(full_result.error_code == "");
    assert(full_result.error_message == "");

    var defaults = parse_json_object("{\"project_id\":\"p2\"}");
    var defaults_result = HolderLinux.ApiParsersGit.parse_git_test_remote_result(defaults);
    assert(defaults_result.project_id == "p2");
    assert(defaults_result.remote_url == "");
    assert(defaults_result.branch == "");
    assert(defaults_result.status == "");
    assert(!defaults_result.remote_has_head);
    assert(defaults_result.error_code == "");
    assert(defaults_result.error_message == "");
}

private void test_parse_git_push_result_full_and_defaults() {
    var full = parse_json_object(
        "{\"project_id\":\"p1\",\"remote_url\":\"git@example/repo.git\",\"branch\":\"main\",\"status\":\"ok\",\"ahead_count\":3,\"behind_count\":1,\"error_code\":\"\",\"error_message\":\"\",\"next_action\":\"none\"}"
    );
    var full_result = HolderLinux.ApiParsersGit.parse_git_push_result(full);
    assert(full_result.project_id == "p1");
    assert(full_result.remote_url == "git@example/repo.git");
    assert(full_result.branch == "main");
    assert(full_result.status == "ok");
    assert(full_result.ahead_count == 3);
    assert(full_result.behind_count == 1);
    assert(full_result.error_code == "");
    assert(full_result.error_message == "");
    assert(full_result.next_action == "none");

    var defaults = parse_json_object("{\"project_id\":\"p2\"}");
    var defaults_result = HolderLinux.ApiParsersGit.parse_git_push_result(defaults);
    assert(defaults_result.project_id == "p2");
    assert(defaults_result.ahead_count == 0);
    assert(defaults_result.behind_count == 0);
    assert(defaults_result.remote_url == "");
    assert(defaults_result.branch == "");
    assert(defaults_result.status == "");
    assert(defaults_result.error_code == "");
    assert(defaults_result.error_message == "");
    assert(defaults_result.next_action == "");
}

private void test_parse_git_provider_catalog_missing_providers_returns_empty() {
    var root = parse_json_object("{\"ok\":true}");

    Gee.ArrayList<HolderLinux.GitProviderCatalogEntry> providers;
    try {
        providers = HolderLinux.ApiParsersGit.parse_git_provider_catalog(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(providers.size == 0);
}

private void test_parse_git_provider_catalog_full_and_defaults() {
    var root = parse_json_object(
        "{\"providers\":[" +
        "{\"id\":\"gh\",\"name\":\"GitHub\",\"kind\":\"cloud\",\"defaults\":{\"preferred_transport\":\"ssh\"},\"git\":{\"transports\":[\"ssh\",\"https\"],\"examples\":{\"ssh\":\"git@github.com:org/repo.git\",\"https\":\"https://github.com/org/repo.git\"}}}," +
        "{\"id\":\"bb\",\"name\":\"Bitbucket\",\"kind\":\"cloud\",\"git\":{\"transports\":[\"https\"]}}," +
        "{\"id\":\"gl\",\"name\":\"GitLab\",\"kind\":\"cloud\"}" +
        "]}"
    );

    Gee.ArrayList<HolderLinux.GitProviderCatalogEntry> providers;
    try {
        providers = HolderLinux.ApiParsersGit.parse_git_provider_catalog(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(providers.size == 3);

    assert(providers[0].id == "gh");
    assert(providers[0].name == "GitHub");
    assert(providers[0].kind == "cloud");
    assert(providers[0].preferred_transport == "ssh");
    assert(providers[0].transports_summary == "ssh, https");
    assert(providers[0].ssh_example == "git@github.com:org/repo.git");
    assert(providers[0].https_example == "https://github.com/org/repo.git");

    assert(providers[1].id == "bb");
    assert(providers[1].preferred_transport == "");
    assert(providers[1].transports_summary == "https");
    assert(providers[1].ssh_example == "");
    assert(providers[1].https_example == "");

    assert(providers[2].id == "gl");
    assert(providers[2].preferred_transport == "");
    assert(providers[2].transports_summary == "");
    assert(providers[2].ssh_example == "");
    assert(providers[2].https_example == "");
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/parsers/git/test-remote-full-and-defaults", test_parse_git_test_remote_result_full_and_defaults);
    Test.add_func("/parsers/git/push-result-full-and-defaults", test_parse_git_push_result_full_and_defaults);
    Test.add_func("/parsers/git/provider-catalog-missing-providers", test_parse_git_provider_catalog_missing_providers_returns_empty);
    Test.add_func("/parsers/git/provider-catalog-full-and-defaults", test_parse_git_provider_catalog_full_and_defaults);

    return Test.run();
}

}
