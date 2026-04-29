namespace HolderLinux {

internal interface IWindowFlowboardEventSink : Object {
    public abstract void on_card_store_items_changed(uint position, uint removed, uint added);
    public abstract void on_flowboard_project_overview_requested(string project_id);
    public abstract void on_flowboard_context_load_requested(string project_id, string? parent_card_id);
}

internal class WindowFlowboardEventBinder : Object {
    private GLib.ListStore card_store; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private FlowboardController flowboard_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IWindowFlowboardEventSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public WindowFlowboardEventBinder(GLib.ListStore card_store,
                                      FlowboardController flowboard_controller,
                                      IWindowFlowboardEventSink sink) {
        this.card_store = card_store;
        this.flowboard_controller = flowboard_controller;
        this.sink = sink;
    }

    public void bind() {
        card_store.items_changed.connect((position, removed, added) => {
            sink.on_card_store_items_changed(position, removed, added);
        });
        flowboard_controller.project_overview_requested.connect((project_id) => {
            sink.on_flowboard_project_overview_requested(project_id);
        });
        flowboard_controller.context_load_requested.connect((project_id, parent_card_id) => {
            sink.on_flowboard_context_load_requested(project_id, parent_card_id);
        });
    }
}

}
