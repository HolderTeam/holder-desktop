namespace HolderLinux {

internal interface IToolboxEventSource : Object {
    public abstract signal void error_reported(string title_text, string details);
    public abstract signal void toast_requested(string message);
    public abstract signal void breadcrumb_navigation_requested(string tool_id,
                                                               int segment_index,
                                                               string? project_id,
                                                               string? card_id);
    public abstract signal void flowboard_card_open_requested(string card_id);
    public abstract signal void connections_card_open_requested(string card_id);
    public abstract signal void tags_card_open_requested(string card_id);
    public abstract signal void connections_card_create_child_requested(string card_id);
    public abstract signal void flowboard_card_move_to_trash_requested(string card_id);
    public abstract signal void flowboard_move_intent_requested(string card_id,
                                                                string project_id,
                                                                string intent,
                                                                string? target_card_id,
                                                                string? parent_card_id);
    public abstract signal void flowboard_new_card_requested(string? parent_card_id);
    public abstract signal void send_card_as_email_requested();
    public abstract signal void send_recovery_key_as_email_requested();
    public abstract signal void save_recovery_key_to_usb_requested();
    public abstract signal void import_recovery_key_requested();
    public abstract signal void terminal_copy_to_card_requested(string text);
    public abstract signal void activity_requested(string kind,
                                                  string message,
                                                  string? project_id,
                                                  string? card_id,
                                                  ActivityDetails? details);
}

internal interface IToolboxEventSink : Object {
    public abstract void show_error(string title_text, string details);
    public abstract void add_toast(string message);
    public abstract void show_tool_help_page(string tool_id);
    public abstract void confirm_move_card_to_trash(string card_id);
    public abstract void send_current_card_as_email();
    public abstract void request_send_recovery_key_as_email();
    public abstract void request_save_recovery_key_to_usb();
    public abstract void request_import_recovery_key();
    public abstract void append_text_to_current_card(string text);
    public abstract void log_activity(string kind,
                                      string message,
                                      string? project_id,
                                      string? card_id,
                                      ActivityDetails? details);
}

internal class ToolboxEventOrchestrator : Object {
    private IToolboxEventSource toolbox; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private ToolboxBreadcrumbController toolbox_breadcrumb_controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private SelectionIntentOrchestrator selection_intent_orchestrator; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private MainController controller; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IToolboxEventSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public ToolboxEventOrchestrator(IToolboxEventSource toolbox,
                                    ToolboxBreadcrumbController toolbox_breadcrumb_controller,
                                    SelectionIntentOrchestrator selection_intent_orchestrator,
                                    MainController controller,
                                    IToolboxEventSink sink) {
        this.toolbox = toolbox;
        this.toolbox_breadcrumb_controller = toolbox_breadcrumb_controller;
        this.selection_intent_orchestrator = selection_intent_orchestrator;
        this.controller = controller;
        this.sink = sink;
    }

    public void bind() {
        toolbox.error_reported.connect((title, details) => {
            sink.show_error(title, details);
        });
        toolbox.toast_requested.connect((message) => {
            sink.add_toast(message);
        });
        toolbox.breadcrumb_navigation_requested.connect((tool_id, segment_index, project_id, card_id) => {
            toolbox_breadcrumb_controller.navigate.begin(
                tool_id,
                segment_index,
                project_id,
                card_id,
                (id) => {
                    selection_intent_orchestrator.open_card_with_transition.begin(
                        id,
                        "toolbox-breadcrumb-card-open"
                    );
                },
                (id) => {
                    sink.show_tool_help_page(id);
                }
            );
        });
        toolbox.flowboard_card_open_requested.connect((card_id) => {
            selection_intent_orchestrator.open_card_with_transition.begin(
                card_id,
                "toolbox-flowboard-card-open"
            );
        });
        toolbox.connections_card_open_requested.connect((card_id) => {
            selection_intent_orchestrator.open_card_with_transition.begin(
                card_id,
                "toolbox-connections-card-open"
            );
        });
        toolbox.tags_card_open_requested.connect((card_id) => {
            selection_intent_orchestrator.open_card_with_transition.begin(
                card_id,
                "toolbox-tags-card-open"
            );
        });
        toolbox.connections_card_create_child_requested.connect((card_id) => {
            controller.create_card.begin(card_id);
        });
        toolbox.flowboard_card_move_to_trash_requested.connect((card_id) => {
            sink.confirm_move_card_to_trash(card_id);
        });
        toolbox.flowboard_move_intent_requested.connect((card_id, _project_id, intent, target_card_id, parent_card_id) => {
            controller.move_card_by_intent.begin(card_id, intent, target_card_id, parent_card_id);
        });
        toolbox.flowboard_new_card_requested.connect((parent_card_id) => {
            controller.create_card.begin(parent_card_id);
        });
        toolbox.send_card_as_email_requested.connect(() => {
            sink.send_current_card_as_email();
        });
        toolbox.send_recovery_key_as_email_requested.connect(() => {
            sink.request_send_recovery_key_as_email();
        });
        toolbox.save_recovery_key_to_usb_requested.connect(() => {
            sink.request_save_recovery_key_to_usb();
        });
        toolbox.import_recovery_key_requested.connect(() => {
            sink.request_import_recovery_key();
        });
        toolbox.terminal_copy_to_card_requested.connect((text) => {
            sink.append_text_to_current_card(text);
        });
        toolbox.activity_requested.connect((kind, message, project_id, card_id, details) => {
            sink.log_activity(kind, message, project_id, card_id, details);
        });
    }
}

}
