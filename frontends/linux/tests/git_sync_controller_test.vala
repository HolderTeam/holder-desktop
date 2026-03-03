using GLib;

private void test_normalize_repository_name_basic() {
    var controller = new HolderLinux.GitSyncController();
    var normalized = controller.normalize_repository_name("My Project/Name");
    assert(normalized == "My-Project-Name");
}

private void test_normalize_repository_name_strips_unsupported() {
    var controller = new HolderLinux.GitSyncController();
    var normalized = controller.normalize_repository_name("###");
    assert(normalized == "");
}

private void test_fill_remote_template_common_placeholders() {
    var controller = new HolderLinux.GitSyncController();
    var remote = controller.fill_remote_template(
        "git@{host}:{owner}/{repo}.git",
        "zeth",
        "CardApp",
        "github.com"
    );
    assert(remote == "git@github.com:zeth/CardApp.git");
}

private void test_fill_remote_template_region_alias() {
    var controller = new HolderLinux.GitSyncController();
    var remote = controller.fill_remote_template(
        "https://git-codecommit.{region}.amazonaws.com/v1/repos/{repo}",
        "ignored",
        "holder",
        "eu-west-1"
    );
    assert(remote == "https://git-codecommit.eu-west-1.amazonaws.com/v1/repos/holder");
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/git_sync_controller/normalize_repository_name_basic", test_normalize_repository_name_basic);
    Test.add_func("/git_sync_controller/normalize_repository_name_strips_unsupported",
                  test_normalize_repository_name_strips_unsupported);
    Test.add_func("/git_sync_controller/fill_remote_template_common_placeholders",
                  test_fill_remote_template_common_placeholders);
    Test.add_func("/git_sync_controller/fill_remote_template_region_alias",
                  test_fill_remote_template_region_alias);

    return Test.run();
}
