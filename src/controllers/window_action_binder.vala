namespace HolderLinux {

private delegate void ActionCallback();

internal interface IWindowActionSink : Object {
    public abstract void on_refresh_requested();
    public abstract void on_new_project_requested();
    public abstract void on_new_card_requested();
    public abstract void on_flowboard_new_child_card_requested();
    public abstract void on_toggle_toolbox_requested();
    public abstract void on_find_replace_requested();
    public abstract void on_print_requested();
    public abstract void on_show_local_info_requested();
    public abstract void on_show_preferences_requested();
    public abstract void on_show_about_requested();
}

internal class WindowActionBinder : Object {
    private GLib.ActionMap action_map; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IWindowActionSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public WindowActionBinder(GLib.ActionMap action_map, IWindowActionSink sink) {
        this.action_map = action_map;
        this.sink = sink;
    }

    public void bind() {
        bind_action("refresh", () => {
            sink.on_refresh_requested();
        });
        bind_action("new-project", () => {
            sink.on_new_project_requested();
        });
        bind_action("new-card", () => {
            sink.on_new_card_requested();
        });
        bind_action("flowboard-new-child-card", () => {
            sink.on_flowboard_new_child_card_requested();
        });
        bind_action("toggle-toolbox", () => {
            sink.on_toggle_toolbox_requested();
        });
        bind_action("find-replace", () => {
            sink.on_find_replace_requested();
        });
        bind_action("print", () => {
            sink.on_print_requested();
        });
        bind_action("show-local-info", () => {
            sink.on_show_local_info_requested();
        });
        bind_action("show-preferences", () => {
            sink.on_show_preferences_requested();
        });
        bind_action("show-about", () => {
            sink.on_show_about_requested();
        });
    }

    private void bind_action(string name, owned ActionCallback callback) {
        var action = new SimpleAction(name, null);
        action.activate.connect(() => {
            callback();
        });
        action_map.add_action(action);
    }
}

}
