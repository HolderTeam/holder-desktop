using GLib;

namespace HolderLinuxTests {

private class TestPrintService : HolderLinux.PrintService {
    public string next_tmp_dir = "/tmp/holder-print-test";
    public bool fail_make_tmp = false;
    public bool fail_write = false;
    public bool fail_print = false;

    public string written_path = "";
    public string written_text = "";
    public bool print_called = false;
    public string printed_path = "";
    public bool cleanup_called = false;
    public string cleanup_path = "";
    public string cleanup_dir = "";

    protected override string make_temp_dir() throws Error {
        if (fail_make_tmp) {
            throw new IOError.FAILED("tmp failed");
        }
        return next_tmp_dir;
    }

    protected override void write_file(string path, string text) throws Error {
        if (fail_write) {
            throw new IOError.FAILED("write failed");
        }
        written_path = path;
        written_text = text;
    }

    protected override async void run_print_dialog(Gtk.Window? parent, string path) throws Error {
        if (fail_print) {
            throw new IOError.FAILED("print failed");
        }
        print_called = true;
        printed_path = path;
    }

    protected override void cleanup(string path, string dir) {
        cleanup_called = true;
        cleanup_path = path;
        cleanup_dir = dir;
    }
}

private void test_print_service_writes_and_cleans_up() {
    var service = new TestPrintService();
    service.next_tmp_dir = "/tmp/holder-print-a";
    bool done = false;

    service.print_text.begin(null, "hello", (obj, res) => {
        try {
            service.print_text.end(res);
        } catch (Error e) {
            assert_not_reached();
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(service.written_path == "/tmp/holder-print-a/card.txt");
    assert(service.written_text == "hello");
    assert(service.print_called);
    assert(service.printed_path == "/tmp/holder-print-a/card.txt");
    assert(service.cleanup_called);
    assert(service.cleanup_path == "/tmp/holder-print-a/card.txt");
    assert(service.cleanup_dir == "/tmp/holder-print-a");
}

private void test_print_service_maps_make_tmp_error() {
    var service = new TestPrintService();
    service.fail_make_tmp = true;
    bool done = false;
    bool got_error = false;

    service.print_text.begin(null, "hello", (obj, res) => {
        try {
            service.print_text.end(res);
        } catch (Error e) {
            got_error = e.message.contains("Could not create temporary print directory");
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_error);
}

private void test_print_service_maps_write_error() {
    var service = new TestPrintService();
    service.next_tmp_dir = "/tmp/holder-print-b";
    service.fail_write = true;
    bool done = false;
    bool got_error = false;

    service.print_text.begin(null, "hello", (obj, res) => {
        try {
            service.print_text.end(res);
        } catch (Error e) {
            got_error = e.message.contains("Could not prepare print file");
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_error);
    assert(service.cleanup_called);
    assert(service.cleanup_dir == "/tmp/holder-print-b");
}

private void test_print_service_empty_text_fails_fast() {
    var service = new TestPrintService();
    bool done = false;
    bool got_error = false;

    service.print_text.begin(null, "   ", (obj, res) => {
        try {
            service.print_text.end(res);
        } catch (Error e) {
            got_error = e.message == "Nothing to print.";
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_error);
}

private void test_print_service_cleans_up_on_print_error() {
    var service = new TestPrintService();
    service.next_tmp_dir = "/tmp/holder-print-c";
    service.fail_print = true;
    bool done = false;
    bool got_error = false;

    service.print_text.begin(null, "hello", (obj, res) => {
        try {
            service.print_text.end(res);
        } catch (Error e) {
            got_error = e.message.contains("print failed");
        }
        done = true;
    });

    assert(wait_for_condition(() => done));
    assert(got_error);
    assert(service.cleanup_called);
    assert(service.cleanup_dir == "/tmp/holder-print-c");
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/print_service/writes_and_cleans_up",
                  test_print_service_writes_and_cleans_up);
    Test.add_func("/print_service/maps_make_tmp_error",
                  test_print_service_maps_make_tmp_error);
    Test.add_func("/print_service/maps_write_error",
                  test_print_service_maps_write_error);
    Test.add_func("/print_service/empty_text_fails_fast",
                  test_print_service_empty_text_fails_fast);
    Test.add_func("/print_service/cleans_up_on_print_error",
                  test_print_service_cleans_up_on_print_error);

    return Test.run();
}

}
