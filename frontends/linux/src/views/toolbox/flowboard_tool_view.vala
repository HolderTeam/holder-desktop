namespace HolderLinux {

public class FlowboardToolView : Object, IToolShellAdapter {
    private FlowboardPane flowboard;
    private FlowboardController? flowboard_controller;

    public Gtk.Widget widget { get; private set; }
    public string tool_id {
        owned get { return "flowboard"; }
    }
    public string tool_label {
        owned get { return "Flowboard"; }
    }

    public signal void card_open_requested(string card_id);
    public signal void card_move_to_trash_requested(string card_id);
    public signal void move_intent_requested(string card_id,
                                             string project_id,
                                             string intent,
                                             string? target_card_id,
                                             string? parent_card_id);
    public signal void new_card_requested(string? parent_card_id);
    public signal void toast_requested(string message);

    public FlowboardToolView() {
        flowboard = new FlowboardPane();
        widget = flowboard.widget;
    }

    public void bind_controller(FlowboardController controller) {
        flowboard_controller = controller;
        flowboard.set_model(controller.get_visible_model());
        controller.empty_message_changed.connect((text) => {
            flowboard.set_empty_message(text);
        });
        controller.card_open_requested.connect((card_id) => {
            card_open_requested(card_id);
        });
        flowboard.tile_activated.connect((position) => {
            controller.activate_position(position);
        });
        flowboard.navigate_up_requested.connect(() => {
            controller.navigate_up();
        });
        flowboard.card_drop_requested.connect((source_card_id, target_card_id, target_x_fraction) => {
            controller.on_card_drop(source_card_id, target_card_id, target_x_fraction);
        });
        flowboard.background_drop_requested.connect((source_card_id) => {
            controller.on_background_drop(source_card_id);
        });
        flowboard.background_new_card_requested.connect(() => {
            controller.request_create_card_here();
        });
        flowboard.card_open_requested.connect((card_id) => {
            controller.open_card_from_context_menu(card_id);
        });
        flowboard.card_create_child_requested.connect((card_id) => {
            new_card_requested(card_id);
        });
        flowboard.card_move_to_trash_requested.connect((card_id) => {
            card_move_to_trash_requested(card_id);
        });
        flowboard.card_move_up_level_requested.connect((card_id) => {
            controller.move_card_up_level_from_context_menu(card_id);
        });
        flowboard.card_move_left_requested.connect((card_id) => {
            controller.move_card_left_from_context_menu(card_id);
        });
        flowboard.card_move_right_requested.connect((card_id) => {
            controller.move_card_right_from_context_menu(card_id);
        });
        flowboard.card_move_to_start_requested.connect((card_id) => {
            controller.move_card_to_start_from_context_menu(card_id);
        });
        flowboard.card_move_to_end_requested.connect((card_id) => {
            controller.move_card_to_end_from_context_menu(card_id);
        });
        controller.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
            move_intent_requested(card_id, project_id, intent, target_card_id, parent_card_id);
        });
        controller.create_card_requested.connect((parent_card_id) => {
            new_card_requested(parent_card_id);
        });
        controller.toast_requested.connect((message) => {
            toast_requested(message);
        });
        controller.refresh();
    }

    public void show_projects_root() {
        if (flowboard_controller == null) {
            return;
        }
        flowboard_controller.navigate_to_breadcrumb_index(0);
    }

    public void show_project_root() {
        if (flowboard_controller == null) {
            return;
        }
        flowboard_controller.navigate_to_breadcrumb_index(1);
    }

    public bool is_showing_projects_root() {
        return flowboard_controller != null && flowboard_controller.is_showing_projects_root();
    }

    public bool is_showing_project_root_level() {
        return flowboard_controller != null && flowboard_controller.is_showing_project_root_level();
    }

    public Gtk.Widget get_content_widget() {
        return widget;
    }

    public Gtk.Widget? get_actions_widget() {
        return null;
    }

    public ToolScopeSnapshot get_scope_snapshot(Project? selected_project, CardSummary? selected_card) {
        var project_id = selected_project != null ? selected_project.project_id : null;
        var project_label = selected_project != null ? selected_project.name : "(none)";
        var card_id = selected_card != null ? selected_card.card_id : null;
        var card_label = selected_card != null ? selected_card.title : "Overview";

        ToolScopeMode scope_mode = ToolScopeMode.CARD_FOCUS;
        if (is_showing_projects_root()) {
            scope_mode = ToolScopeMode.PROJECTS_ROOT;
            project_label = "Projects";
            card_label = "Overview";
            project_id = null;
            card_id = null;
        } else if (is_showing_project_root_level() || selected_card == null) {
            scope_mode = ToolScopeMode.PROJECT_ROOT;
            card_label = "Overview";
            card_id = null;
        }

        return new ToolScopeSnapshot(
            tool_id,
            tool_label,
            project_id,
            project_label,
            card_id,
            card_label,
            scope_mode,
            false
        );
    }

    public async bool navigate_to_projects_root(string? selected_project_id) {
        show_projects_root();
        return true;
    }

    public async bool navigate_to_project_root(string project_id) {
        show_project_root();
        return true;
    }

    public async bool navigate_to_card(string card_id) {
        card_open_requested(card_id);
        return true;
    }
}

}
