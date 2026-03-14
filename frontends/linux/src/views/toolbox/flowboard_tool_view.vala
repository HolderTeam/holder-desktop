namespace HolderLinux {

public class FlowboardToolView : Object {
    private FlowboardPane flowboard;
    private FlowboardController? flowboard_controller;

    public Gtk.Widget widget { get; private set; }

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
}

}
