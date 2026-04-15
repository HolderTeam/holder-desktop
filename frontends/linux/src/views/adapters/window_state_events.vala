namespace HolderLinux {

internal interface IWindowStateEventSink : Object {
    public abstract void on_root_paned_position_changed(int position);
    public abstract void on_app_state_changed();
    public abstract void on_navigation_loading_changed(bool loading);
}

internal interface IPanedPositionSource : Object {
    public abstract signal void position_changed(int position);
}

internal class GtkPanedPositionSource : Object, IPanedPositionSource {
    public GtkPanedPositionSource(Gtk.Paned root_paned) {
        root_paned.notify["position"].connect(() => {
            position_changed(root_paned.get_position());
        });
    }
}

internal class WindowStateEventBinder : Object {
    private IPanedPositionSource root_paned; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private AppStateStore app_state_store; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private SelectionTransitionController selection_transition_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IWindowStateEventSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public WindowStateEventBinder(IPanedPositionSource root_paned,
                                  AppStateStore app_state_store,
                                  SelectionTransitionController selection_transition_controller,
                                  IWindowStateEventSink sink) {
        this.root_paned = root_paned;
        this.app_state_store = app_state_store;
        this.selection_transition_controller = selection_transition_controller;
        this.sink = sink;
    }

    public void bind() {
        root_paned.position_changed.connect((position) => {
            sink.on_root_paned_position_changed(position);
        });
        app_state_store.state_changed.connect(() => {
            sink.on_app_state_changed();
        });
        selection_transition_controller.navigation_loading_changed.connect((loading) => {
            sink.on_navigation_loading_changed(loading);
        });
    }
}

}
