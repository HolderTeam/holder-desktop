namespace HolderLinux {

internal interface IWindowSelectionEditorEventSink : Object {
    public abstract void on_project_selection_changed();
    public abstract void on_card_selection_changed();
    public abstract void on_ai_thread_selection_changed();
    public abstract void on_editor_buffer_changed();
    public abstract void on_internal_link_click_pressed(Gtk.GestureClick gesture,
                                                        int n_press,
                                                        double x,
                                                        double y);
    public abstract bool on_internal_link_key_pressed(uint keyval,
                                                      uint keycode,
                                                      Gdk.ModifierType state);
}

internal class WindowSelectionEditorEventBinder : Object {
    private Gtk.SingleSelection project_selection; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private Gtk.SingleSelection card_selection; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private Gtk.SingleSelection ai_thread_selection; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private GtkSource.Buffer editor_buffer; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private GtkSource.View editor_view; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IWindowSelectionEditorEventSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private Gtk.GestureClick? internal_link_click; // LCOV_EXCL_LINE: callback lifetime holder
    private Gtk.EventControllerKey? internal_link_key; // LCOV_EXCL_LINE: callback lifetime holder

    public WindowSelectionEditorEventBinder(Gtk.SingleSelection project_selection,
                                            Gtk.SingleSelection card_selection,
                                            Gtk.SingleSelection ai_thread_selection,
                                            GtkSource.Buffer editor_buffer,
                                            GtkSource.View editor_view,
                                            IWindowSelectionEditorEventSink sink) {
        this.project_selection = project_selection;
        this.card_selection = card_selection;
        this.ai_thread_selection = ai_thread_selection;
        this.editor_buffer = editor_buffer;
        this.editor_view = editor_view;
        this.sink = sink;
    }

    public void bind() {
        project_selection.notify["selected"].connect(() => {
            sink.on_project_selection_changed();
        });
        card_selection.notify["selected"].connect(() => {
            sink.on_card_selection_changed();
        });
        ai_thread_selection.notify["selected"].connect(() => {
            sink.on_ai_thread_selection_changed();
        });

        editor_buffer.changed.connect(() => {
            sink.on_editor_buffer_changed();
        });

        internal_link_click = new Gtk.GestureClick();
        internal_link_click.set_button(Gdk.BUTTON_PRIMARY);
        internal_link_click.pressed.connect((n_press, x, y) => {
            sink.on_internal_link_click_pressed(internal_link_click, n_press, x, y);
        });
        editor_view.add_controller(internal_link_click);

        internal_link_key = new Gtk.EventControllerKey();
        internal_link_key.key_pressed.connect((keyval, keycode, state) => {
            return sink.on_internal_link_key_pressed(keyval, keycode, state);
        });
        editor_view.add_controller(internal_link_key);
    }
}

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

internal interface IWindowLifecycleEventSink : Object {
    public abstract void on_project_create_error_reported(string title_text, string details);
    public abstract bool on_window_close_requested();
}

internal class WindowLifecycleEventBinder : Object {
    private ProjectCreateController project_create_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private Gtk.Window window; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IWindowLifecycleEventSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public WindowLifecycleEventBinder(ProjectCreateController project_create_controller,
                                      Gtk.Window window,
                                      IWindowLifecycleEventSink sink) {
        this.project_create_controller = project_create_controller;
        this.window = window;
        this.sink = sink;
    }

    public void bind() {
        project_create_controller.error_reported.connect((title_text, details) => {
            sink.on_project_create_error_reported(title_text, details);
        });
        window.close_request.connect(() => {
            return sink.on_window_close_requested();
        });
    }
}

internal interface IWindowStateEventSink : Object {
    public abstract void on_root_paned_position_changed(int position);
    public abstract void on_app_state_changed();
    public abstract void on_navigation_loading_changed(bool loading);
}

internal class WindowStateEventBinder : Object {
    private Gtk.Paned root_paned; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private AppStateStore app_state_store; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private SelectionTransitionController selection_transition_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IWindowStateEventSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public WindowStateEventBinder(Gtk.Paned root_paned,
                                  AppStateStore app_state_store,
                                  SelectionTransitionController selection_transition_controller,
                                  IWindowStateEventSink sink) {
        this.root_paned = root_paned;
        this.app_state_store = app_state_store;
        this.selection_transition_controller = selection_transition_controller;
        this.sink = sink;
    }

    public void bind() {
        root_paned.notify["position"].connect(() => {
            sink.on_root_paned_position_changed(root_paned.get_position());
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
