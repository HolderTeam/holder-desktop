namespace HolderLinux {

internal interface ISidebarEventSource : Object {
    public abstract signal void card_move_to_trash_requested(string card_id);
    public abstract signal void card_context_selection_requested(string card_id);
    public abstract signal void card_create_child_requested(string card_id);
}

internal interface ISidebarEventSink : Object {
    public abstract void on_sidebar_card_move_to_trash_requested(string card_id);
    public abstract void on_sidebar_card_context_selection_requested(string card_id);
    public abstract void on_sidebar_card_create_child_requested(string card_id);
}

internal class WindowSidebarEventBinder : Object {
    private ISidebarEventSource sidebar; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private ISidebarEventSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public WindowSidebarEventBinder(ISidebarEventSource sidebar, ISidebarEventSink sink) {
        this.sidebar = sidebar;
        this.sink = sink;
    }

    public void bind() {
        sidebar.card_move_to_trash_requested.connect((card_id) => {
            sink.on_sidebar_card_move_to_trash_requested(card_id);
        });
        sidebar.card_context_selection_requested.connect((card_id) => {
            sink.on_sidebar_card_context_selection_requested(card_id);
        });
        sidebar.card_create_child_requested.connect((card_id) => {
            sink.on_sidebar_card_create_child_requested(card_id);
        });
    }
}

}
