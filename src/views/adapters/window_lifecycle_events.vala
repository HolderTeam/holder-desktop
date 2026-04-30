namespace HolderLinux {

internal interface IWindowLifecycleEventSink : Object {
    public abstract void on_project_create_error_reported(string title_text, string details);
    public abstract bool on_window_close_requested();
}

internal interface IWindowCloseRequestSource : Object {
    public abstract signal bool close_requested();
}

internal class GtkWindowCloseRequestSource : Object, IWindowCloseRequestSource {
    public GtkWindowCloseRequestSource(Gtk.Window window) {
        window.close_request.connect(() => {
            return close_requested();
        });
    }
}

internal class WindowLifecycleEventBinder : Object {
    private ProjectCreateController project_create_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IWindowCloseRequestSource window; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IWindowLifecycleEventSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public WindowLifecycleEventBinder(ProjectCreateController project_create_controller,
                                      IWindowCloseRequestSource window,
                                      IWindowLifecycleEventSink sink) {
        this.project_create_controller = project_create_controller;
        this.window = window;
        this.sink = sink;
    }

    public void bind() {
        project_create_controller.error_reported.connect((title_text, details) => {
            sink.on_project_create_error_reported(title_text, details);
        });
        window.close_requested.connect(() => {
            return sink.on_window_close_requested();
        });
    }
}

}
