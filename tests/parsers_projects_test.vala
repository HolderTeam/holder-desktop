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

private void test_parse_projects_missing_data_is_protocol_error() {
    var root = parse_json_object("{\"ok\":true}");

    bool got_protocol = false;
    try {
        HolderLinux.ApiParsersProjects.parse_projects(root);
    } catch (Error e) {
        got_protocol = e.message.contains("Missing data for projects response");
    }

    assert(got_protocol);
}

private void test_parse_projects_full_and_defaults() {
    var root = parse_json_object(
        "{\"data\":[" +
        "{\"project_id\":\"p1\",\"name\":\"Project One\",\"privacy_mode\":\"encrypted_git\",\"root_path\":\"/tmp/p1\",\"created_at\":11,\"updated_at\":12,\"git_remote_url\":\"git@example/repo.git\",\"card_count\":7,\"root_card_count\":3," +
        "\"sync\":{" +
        "\"last_commit_at\":100,\"last_push_at\":101,\"last_pull_at\":102," +
        "\"uncommitted_changes_count\":1,\"unpushed_commits_count\":2," +
        "\"last_push_status\":\"ok\",\"last_pull_status\":\"ok\",\"last_sync_error\":\"\"," +
        "\"last_sync_error_at\":103,\"retry_count\":4,\"next_retry_at\":104," +
        "\"pull_retry_count\":5,\"next_pull_retry_at\":105,\"updated_at\":106" +
        "}}," +
        "{\"project_id\":\"p2\",\"name\":\"Project Two\",\"sync\":null}," +
        "{\"project_id\":\"p3\",\"name\":\"Project Three\"}" +
        "]}"
    );

    Gee.ArrayList<HolderLinux.Project> projects;
    try {
        projects = HolderLinux.ApiParsersProjects.parse_projects(root);
    } catch (Error e) {
        assert_not_reached();
    }

    assert(projects.size == 3);

    var p1 = projects[0];
    assert(p1.project_id == "p1");
    assert(p1.name == "Project One");
    assert(p1.privacy_mode == "encrypted_git");
    assert(p1.root_path == "/tmp/p1");
    assert(p1.created_at == 11);
    assert(p1.updated_at == 12);
    assert(p1.git_remote_url == "git@example/repo.git");
    assert(p1.card_count == 7);
    assert(p1.root_card_count == 3);
    assert(p1.sync.has_last_commit_at);
    assert(p1.sync.last_commit_at == 100);
    assert(p1.sync.has_last_push_at);
    assert(p1.sync.last_push_at == 101);
    assert(p1.sync.has_last_pull_at);
    assert(p1.sync.last_pull_at == 102);
    assert(p1.sync.uncommitted_changes_count == 1);
    assert(p1.sync.unpushed_commits_count == 2);
    assert(p1.sync.last_push_status == "ok");
    assert(p1.sync.last_pull_status == "ok");
    assert(p1.sync.last_sync_error == "");
    assert(p1.sync.has_last_sync_error_at);
    assert(p1.sync.last_sync_error_at == 103);
    assert(p1.sync.retry_count == 4);
    assert(p1.sync.has_next_retry_at);
    assert(p1.sync.next_retry_at == 104);
    assert(p1.sync.pull_retry_count == 5);
    assert(p1.sync.has_next_pull_retry_at);
    assert(p1.sync.next_pull_retry_at == 105);
    assert(p1.sync.has_updated_at);
    assert(p1.sync.updated_at == 106);

    var p2 = projects[1];
    assert(p2.project_id == "p2");
    assert(p2.privacy_mode == "encrypted_git");
    assert(p2.root_path == "");
    assert(p2.created_at == 0);
    assert(p2.updated_at == 0);
    assert(p2.git_remote_url == null);
    assert(p2.card_count == 0);
    assert(p2.root_card_count == 0);
    assert(!p2.sync.has_last_commit_at);
    assert(!p2.sync.has_last_push_at);
    assert(!p2.sync.has_last_pull_at);
    assert(p2.sync.uncommitted_changes_count == 0);
    assert(p2.sync.unpushed_commits_count == 0);
    assert(!p2.sync.has_last_sync_error_at);
    assert(p2.sync.retry_count == 0);
    assert(!p2.sync.has_next_retry_at);
    assert(p2.sync.pull_retry_count == 0);
    assert(!p2.sync.has_next_pull_retry_at);
    assert(!p2.sync.has_updated_at);

    var p3 = projects[2];
    assert(p3.project_id == "p3");
    assert(p3.name == "Project Three");
    assert(p3.privacy_mode == "encrypted_git");
    assert(p3.root_path == "");
    assert(p3.created_at == 0);
    assert(p3.updated_at == 0);
    assert(p3.git_remote_url == null);
    assert(p3.card_count == 0);
    assert(p3.root_card_count == 0);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/parsers/projects/missing-data-protocol-error", test_parse_projects_missing_data_is_protocol_error);
    Test.add_func("/parsers/projects/full-and-defaults", test_parse_projects_full_and_defaults);

    return Test.run();
}

}
