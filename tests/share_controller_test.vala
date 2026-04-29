using GLib;

namespace HolderLinux {

internal class CardDetail : Object {
    public string title { get; construct; }

    public CardDetail(string title) {
        Object(title: title);
    }
}

internal errordomain TestShareError {
    FAILED
}

internal class RecordingUriLauncher : Object, IUriLauncher {
    public int launch_calls = 0;
    public string last_uri = "";
    public Error? launch_error = null;

    public void launch(string uri) throws Error {
        launch_calls++;
        last_uri = uri;
        if (launch_error != null) {
            throw launch_error;
        }
    }
}

}

namespace HolderLinux.Tests {

private void test_send_card_as_email_requires_card() {
    var launcher = new HolderLinux.RecordingUriLauncher();
    var controller = new HolderLinux.ShareController(launcher);
    string? last_toast = null;
    controller.toast_requested.connect((message) => {
        last_toast = message;
    });

    controller.send_card_as_email(null, "Body");

    assert(launcher.launch_calls == 0);
    assert(last_toast == "Select a card first.");
}

private void test_send_card_as_email_launches_mailto_and_reports_success() {
    var launcher = new HolderLinux.RecordingUriLauncher();
    var controller = new HolderLinux.ShareController(launcher);
    string? last_toast = null;
    controller.toast_requested.connect((message) => {
        last_toast = message;
    });

    controller.send_card_as_email(new HolderLinux.CardDetail("My Card & More"), "Line 1\nLine 2");

    assert(launcher.launch_calls == 1);
    assert(launcher.last_uri == "mailto:?subject=My%20Card%20%26%20More&body=Line%201%0ALine%202");
    assert(last_toast == "Opened default email app.");
}

private void test_send_card_as_email_reports_launcher_errors() {
    var launcher = new HolderLinux.RecordingUriLauncher();
    launcher.launch_error = new HolderLinux.TestShareError.FAILED("launch failed");
    var controller = new HolderLinux.ShareController(launcher);
    string? error_title = null;
    string? error_details = null;
    controller.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });

    controller.send_card_as_email(new HolderLinux.CardDetail("Card"), "Body");

    assert(error_title == "Email share failed");
    assert(error_details == "launch failed");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/share-controller/send-card-as-email-requires-card", test_send_card_as_email_requires_card);
    Test.add_func("/holder/share-controller/send-card-as-email-launches-mailto-and-reports-success", test_send_card_as_email_launches_mailto_and_reports_success);
    Test.add_func("/holder/share-controller/send-card-as-email-reports-launcher-errors", test_send_card_as_email_reports_launcher_errors);
    return Test.run();
}

}
