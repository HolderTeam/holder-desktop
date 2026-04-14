using GLib;

namespace HolderLinux {

public class FindReplaceController : Object {
    public signal void toast_requested(string message);
    public signal void error_reported(string title, string details);
}

public class ShareController : Object {
    public signal void toast_requested(string message);
    public signal void error_reported(string title, string details);
}

public class CardAppendController : Object {
    public signal void toast_requested(string message);
}

public class RecoveryUiController : Object {
    public signal void toast_requested(string message);
    public signal void error_reported(string title, string details);
}

internal class RecoveryDialogAdapter : Object {
    public signal void error_reported(string title, string details);
}

public class PrintAdapter : Object {
    public signal void toast_requested(string message);
    public signal void error_reported(string title, string details);
}

}

namespace HolderLinux.Tests {

private class RecordingWindowFeedbackSink : Object, HolderLinux.IWindowFeedbackSink {
    public int toast_calls = 0;
    public int error_calls = 0;
    public string last_toast = "";
    public string last_error_title = "";
    public string last_error_details = "";

    public void add_toast(string message) {
        toast_calls++;
        last_toast = message;
    }

    public void show_error(string title_text, string details) {
        error_calls++;
        last_error_title = title_text;
        last_error_details = details;
    }
}

private void test_bind_forwards_toasts_and_errors_from_all_sources() {
    var find_replace = new HolderLinux.FindReplaceController();
    var share = new HolderLinux.ShareController();
    var card_append = new HolderLinux.CardAppendController();
    var recovery_ui = new HolderLinux.RecoveryUiController();
    var recovery_dialog = new HolderLinux.RecoveryDialogAdapter();
    var print_ui = new HolderLinux.PrintAdapter();
    var sink = new RecordingWindowFeedbackSink();

    var orchestrator = new HolderLinux.WindowFeedbackOrchestrator(
        find_replace,
        share,
        card_append,
        recovery_ui,
        recovery_dialog,
        print_ui,
        sink
    );
    orchestrator.bind();

    find_replace.toast_requested("find toast");
    share.toast_requested("share toast");
    card_append.toast_requested("append toast");
    recovery_ui.toast_requested("recovery toast");
    print_ui.toast_requested("print toast");
    assert(sink.toast_calls == 5);
    assert(sink.last_toast == "print toast");

    find_replace.error_reported("find title", "find details");
    share.error_reported("share title", "share details");
    recovery_ui.error_reported("recovery title", "recovery details");
    recovery_dialog.error_reported("dialog title", "dialog details");
    print_ui.error_reported("print title", "print details");
    assert(sink.error_calls == 5);
    assert(sink.last_error_title == "print title");
    assert(sink.last_error_details == "print details");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/window-feedback-orchestrator/bind-forwards-toasts-and-errors-from-all-sources", test_bind_forwards_toasts_and_errors_from_all_sources);
    return Test.run();
}

}
