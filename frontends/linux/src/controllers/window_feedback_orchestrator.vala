namespace HolderLinux {

internal interface IWindowFeedbackSink : Object {
    public abstract void add_toast(string message);
    public abstract void show_error(string title_text, string details);
}

internal class WindowFeedbackOrchestrator : Object {
    private FindReplaceController find_replace_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private ShareController share_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private CardAppendController card_append_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private RecoveryUiController recovery_ui_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private RecoveryDialogAdapter recovery_dialog_adapter; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private PrintUiController print_ui_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IWindowFeedbackSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public WindowFeedbackOrchestrator(FindReplaceController find_replace_controller,
                                      ShareController share_controller,
                                      CardAppendController card_append_controller,
                                      RecoveryUiController recovery_ui_controller,
                                      RecoveryDialogAdapter recovery_dialog_adapter,
                                      PrintUiController print_ui_controller,
                                      IWindowFeedbackSink sink) {
        this.find_replace_controller = find_replace_controller;
        this.share_controller = share_controller;
        this.card_append_controller = card_append_controller;
        this.recovery_ui_controller = recovery_ui_controller;
        this.recovery_dialog_adapter = recovery_dialog_adapter;
        this.print_ui_controller = print_ui_controller;
        this.sink = sink;
    }

    public void bind() {
        find_replace_controller.toast_requested.connect((message) => {
            sink.add_toast(message);
        });
        find_replace_controller.error_reported.connect((title_text, details) => {
            sink.show_error(title_text, details);
        });
        share_controller.toast_requested.connect((message) => {
            sink.add_toast(message);
        });
        share_controller.error_reported.connect((title_text, details) => {
            sink.show_error(title_text, details);
        });
        card_append_controller.toast_requested.connect((message) => {
            sink.add_toast(message);
        });
        recovery_ui_controller.toast_requested.connect((message) => {
            sink.add_toast(message);
        });
        recovery_ui_controller.error_reported.connect((title_text, details) => {
            sink.show_error(title_text, details);
        });
        recovery_dialog_adapter.error_reported.connect((title_text, details) => {
            sink.show_error(title_text, details);
        });
        print_ui_controller.toast_requested.connect((message) => {
            sink.add_toast(message);
        });
        print_ui_controller.error_reported.connect((title_text, details) => {
            sink.show_error(title_text, details);
        });
    }
}

}
