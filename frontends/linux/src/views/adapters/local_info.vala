namespace HolderLinux {

public interface ILocalInfoViewSink : Object {
    public abstract void set_editor_state(string text, bool editable);
    public abstract void show_editor_mode();
    public abstract void update_window_title(string title_text);
    public abstract void set_status(string text);
    public abstract void show_error(string title_text, string details);
}

public class LocalInfoViewAdapter : Object {
    private ILocalInfoViewSink sink;
    private LocalInfoPresenter presenter;

    public LocalInfoViewAdapter(ILocalInfoViewSink sink, LocalInfoPresenter presenter) {
        this.sink = sink;
        this.presenter = presenter;
    }

    public void render_not_connected() {
        sink.set_editor_state(presenter.not_connected_markdown(), false);
        sink.show_editor_mode();
    }

    public void render_success(string markdown) {
        sink.set_editor_state(markdown, false);
        sink.show_editor_mode();
        sink.update_window_title(presenter.page_title());
        sink.set_status(presenter.loaded_status_text());
    }

    public void render_failure(string details) {
        sink.set_editor_state(presenter.load_error_markdown(details), false);
        sink.show_editor_mode();
        sink.update_window_title(presenter.page_title());
        sink.set_status(presenter.failed_status_text());
        sink.show_error(presenter.error_title(), details);
    }
}

}
