using GLib;

namespace HolderLinuxTests {

private class FakeLocalInfoViewSink : Object, HolderLinux.ILocalInfoViewSink {
    public string editor_text = "";
    public bool editor_editable = true;
    public int show_editor_mode_calls = 0;
    public string title_text = "";
    public string status_text = "";
    public string error_title = "";
    public string error_details = "";

    public void set_editor_state(string text, bool editable) {
        editor_text = text;
        editor_editable = editable;
    }

    public void show_editor_mode() {
        show_editor_mode_calls++;
    }

    public void update_window_title(string title_text) {
        this.title_text = title_text;
    }

    public void set_status(string text) {
        status_text = text;
    }

    public void show_error(string title_text, string details) {
        error_title = title_text;
        error_details = details;
    }
}

private void test_local_info_view_adapter_not_connected() {
    var sink = new FakeLocalInfoViewSink();
    var presenter = new HolderLinux.LocalInfoPresenter();
    var adapter = new HolderLinux.LocalInfoViewAdapter(sink, presenter);

    adapter.render_not_connected();

    assert(sink.editor_text.contains("API client not connected"));
    assert(!sink.editor_editable);
    assert(sink.show_editor_mode_calls == 1);
}

private void test_local_info_view_adapter_success() {
    var sink = new FakeLocalInfoViewSink();
    var presenter = new HolderLinux.LocalInfoPresenter();
    var adapter = new HolderLinux.LocalInfoViewAdapter(sink, presenter);

    adapter.render_success("# Local info\n\nOK");

    assert(sink.editor_text.contains("OK"));
    assert(!sink.editor_editable);
    assert(sink.show_editor_mode_calls == 1);
    assert(sink.title_text == "Local info");
    assert(sink.status_text == "Loaded local info");
    assert(sink.error_title == "");
}

private void test_local_info_view_adapter_failure() {
    var sink = new FakeLocalInfoViewSink();
    var presenter = new HolderLinux.LocalInfoPresenter();
    var adapter = new HolderLinux.LocalInfoViewAdapter(sink, presenter);

    adapter.render_failure("boom");

    assert(sink.editor_text.contains("Could not load `/health`."));
    assert(sink.editor_text.contains("boom"));
    assert(!sink.editor_editable);
    assert(sink.show_editor_mode_calls == 1);
    assert(sink.title_text == "Local info");
    assert(sink.status_text == "Failed to load local info");
    assert(sink.error_title == "Local info failed");
    assert(sink.error_details == "boom");
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/local_info_view_adapter/not_connected",
                  test_local_info_view_adapter_not_connected);
    Test.add_func("/local_info_view_adapter/success",
                  test_local_info_view_adapter_success);
    Test.add_func("/local_info_view_adapter/failure",
                  test_local_info_view_adapter_failure);

    return Test.run();
}

}
