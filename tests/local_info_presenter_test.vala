using GLib;

namespace HolderLinuxTests {

private void test_local_info_presenter_static_strings() {
    var presenter = new HolderLinux.LocalInfoPresenter();

    assert(presenter.page_title() == "Local info");
    assert(presenter.loaded_status_text() == "Loaded local info");
    assert(presenter.failed_status_text() == "Failed to load local info");
    assert(presenter.error_title() == "Local info failed");
}

private void test_local_info_presenter_markdown_templates() {
    var presenter = new HolderLinux.LocalInfoPresenter();
    var disconnected = presenter.not_connected_markdown();
    var failed = presenter.load_error_markdown("boom");

    assert(disconnected.contains("# Local info"));
    assert(disconnected.contains("API client not connected"));

    assert(failed.contains("# Local info"));
    assert(failed.contains("Could not load `/health`."));
    assert(failed.contains("boom"));
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/local_info_presenter/static_strings",
                  test_local_info_presenter_static_strings);
    Test.add_func("/local_info_presenter/markdown_templates",
                  test_local_info_presenter_markdown_templates);

    return Test.run();
}

}
