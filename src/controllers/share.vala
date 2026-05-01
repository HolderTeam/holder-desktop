namespace HolderLinux {

internal class ShareController : Object {
    private IUriLauncher uri_launcher;

    public signal void toast_requested(string message);
    public signal void error_reported(string title, string details);

    public ShareController(IUriLauncher? uri_launcher = null) {
        this.uri_launcher = uri_launcher ?? new AppInfoUriLauncher();
    }

    public void send_card_as_email(CardDetail? card, string body_text) {
        if (card == null) {
            toast_requested("Select a card first.");
            return;
        }

        var subject = Uri.escape_string(card.title, null, false);
        var body = Uri.escape_string(body_text, null, false);
        var mailto_uri = "mailto:?subject=%s&body=%s".printf(subject, body);
        try {
            uri_launcher.launch(mailto_uri);
            toast_requested("Opened default email app.");
        } catch (Error e) {
            error_reported("Email share failed", e.message);
        }
    }
}

}
