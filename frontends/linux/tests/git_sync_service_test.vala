using GLib;

namespace HolderLinuxTests {

private void test_run_command_success_captures_stdout() {
    var service = new HolderLinux.GitSyncService();
    bool done = false;

    service.run_command.begin({"/bin/sh", "-lc", "printf 'hello'"}, (obj, res) => {
        var result = service.run_command.end(res);
        assert(result.exit_code == 0);
        assert(result.output == "hello");
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_run_command_missing_binary_returns_error_result() {
    var service = new HolderLinux.GitSyncService();
    bool done = false;

    service.run_command.begin({"__holder_missing_command__"}, (obj, res) => {
        var result = service.run_command.end(res);
        assert(result.exit_code == -1);
        assert(result.output.length > 0);
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_configure_remote_and_sync_pushes_when_reachable() {
    var service = new HolderLinux.GitSyncService();
    var api = new MainControllerFakeApi();
    api.test_project_git_remote_status = "reachable";
    bool done = false;

    service.configure_remote_and_sync.begin(api, "p1", "git@github.com:z/u.git", "cards", (obj, res) => {
        try {
            var result = service.configure_remote_and_sync.end(res);
            assert(api.set_project_git_remote_calls == 1);
            assert(api.test_project_git_remote_calls == 1);
            assert(api.push_project_git_calls == 1);
            assert(result.test_result != null);
            assert(result.push_result != null);
            assert(result.test_result.status == "reachable");
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
}

private void test_configure_remote_and_sync_skips_push_when_unreachable() {
    var service = new HolderLinux.GitSyncService();
    var api = new MainControllerFakeApi();
    api.test_project_git_remote_status = "unreachable";
    bool done = false;

    service.configure_remote_and_sync.begin(api, "p1", "git@github.com:z/u.git", "cards", (obj, res) => {
        try {
            var result = service.configure_remote_and_sync.end(res);
            assert(api.set_project_git_remote_calls == 1);
            assert(api.test_project_git_remote_calls == 1);
            assert(api.push_project_git_calls == 0);
            assert(result.test_result != null);
            assert(result.push_result == null);
            assert(result.test_result.status == "unreachable");
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/git_sync_service/run_command_success_captures_stdout",
                  test_run_command_success_captures_stdout);
    Test.add_func("/git_sync_service/run_command_missing_binary_returns_error_result",
                  test_run_command_missing_binary_returns_error_result);
    Test.add_func("/git_sync_service/configure_remote_and_sync_pushes_when_reachable",
                  test_configure_remote_and_sync_pushes_when_reachable);
    Test.add_func("/git_sync_service/configure_remote_and_sync_skips_push_when_unreachable",
                  test_configure_remote_and_sync_skips_push_when_unreachable);

    return Test.run();
}

}
