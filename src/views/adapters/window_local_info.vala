namespace HolderLinux {

internal class WindowLocalInfoLogger : Object, ILocalInfoLogger {
    private ToolboxPane toolbox;

    public WindowLocalInfoLogger(ToolboxPane toolbox) {
        this.toolbox = toolbox;
    }

    public void log_debug(string message) {
        toolbox.log_debug(message);
    }
}

internal class WindowLocalInfoFlowContext : Object, ILocalInfoFlowContext {
    private MainController owner;

    public WindowLocalInfoFlowContext(MainController owner) {
        this.owner = owner;
    }

    public IHolderApi? get_api_client() {
        return owner.get_api_client();
    }
}

internal class WindowLocalInfoViewSink : Object, ILocalInfoViewSink {
    private MainWindow owner;

    public WindowLocalInfoViewSink(MainWindow owner) {
        this.owner = owner;
    }

    public void set_editor_state(string text, bool editable) {
        owner.set_editor_state(text, editable);
    }

    public void show_editor_mode() {
        owner.show_editor_mode();
    }

    public void update_window_title(string title_text) {
        owner.update_window_title(title_text);
    }

    public void set_status(string text) {
        owner.set_status(text);
    }

    public void show_error(string title_text, string details) {
        owner.show_error(title_text, details);
    }
}

}
