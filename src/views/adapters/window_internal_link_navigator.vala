namespace HolderLinux {

internal class WindowInternalLinkNavigator : Object {
    private InternalLinkController internal_link_controller;
    private EditorNavigationResolver resolver;
    private IUriLauncher uri_launcher;
    private GtkSource.Buffer editor_buffer;
    private GtkSource.View editor_view;
    private GLib.ListStore card_store;
    private MainController controller;
    private SelectionIntentOrchestrator selection_intent_orchestrator;
    private CardActionDialogAdapter card_action_dialog_adapter;
    private ToolboxPane toolbox;
    private WorkspacePane workspace;
    private Adw.ToastOverlay toast_overlay;

    public signal void resource_preview_requested(string resource_id);

    public WindowInternalLinkNavigator(InternalLinkController internal_link_controller,
                                       TagNavigationController tag_navigation_controller,
                                       GtkSource.Buffer editor_buffer,
                                       GtkSource.View editor_view,
                                       GLib.ListStore card_store,
                                       MainController controller,
                                       SelectionIntentOrchestrator selection_intent_orchestrator,
                                       CardActionDialogAdapter card_action_dialog_adapter,
                                       ToolboxPane toolbox,
                                       WorkspacePane workspace,
                                       Adw.ToastOverlay toast_overlay,
                                       MarkdownLinkController? markdown_link_controller = null,
                                       MarkdownResourceImageController? resource_image_controller = null,
                                       IUriLauncher? uri_launcher = null) {
        this.internal_link_controller = internal_link_controller;
        this.resolver = new EditorNavigationResolver(
            internal_link_controller,
            tag_navigation_controller,
            markdown_link_controller ?? new MarkdownLinkController(),
            resource_image_controller ?? new MarkdownResourceImageController()
        );
        this.uri_launcher = uri_launcher ?? new AppInfoUriLauncher();
        this.editor_buffer = editor_buffer;
        this.editor_view = editor_view;
        this.card_store = card_store;
        this.controller = controller;
        this.selection_intent_orchestrator = selection_intent_orchestrator;
        this.card_action_dialog_adapter = card_action_dialog_adapter;
        this.toolbox = toolbox;
        this.workspace = workspace;
        this.toast_overlay = toast_overlay;
    }

    public void refresh_connections_from_editor() {
        Gtk.TextIter start;
        Gtk.TextIter end;
        editor_buffer.get_bounds(out start, out end);
        var text = editor_buffer.get_text(start, end, false);
        var links = internal_link_controller.extract_internal_links(text);
        toolbox.set_connections_internal_links(links);
    }

    public bool handle_click(Gtk.GestureClick gesture, int n_press, double x, double y) {
        var sequence = gesture.get_current_sequence();
        var event = gesture.get_last_event(sequence);
        if (event == null) {
            return false;
        }
        var ctrl_held = (event.get_modifier_state() & Gdk.ModifierType.CONTROL_MASK) != 0;
        if (!EditorNavigationResolver.is_navigation_click(n_press, ctrl_held)) {
            return false;
        }

        int buffer_x;
        int buffer_y;
        editor_view.window_to_buffer_coords(
            Gtk.TextWindowType.WIDGET,
            (int) x,
            (int) y,
            out buffer_x,
            out buffer_y
        );
        Gtk.TextIter iter;
        if (!editor_view.get_iter_at_location(out iter, buffer_x, buffer_y)) {
            return false;
        }
        if (!navigate_at_iter(iter)) {
            return false;
        }
        gesture.set_state(Gtk.EventSequenceState.CLAIMED);
        return true;
    }

    public bool handle_key(uint keyval, uint keycode, Gdk.ModifierType state) {
        var ctrl_held = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
        if (!EditorNavigationResolver.is_navigation_key(keyval, ctrl_held)) {
            return false;
        }
        Gtk.TextIter cursor;
        editor_buffer.get_iter_at_mark(out cursor, editor_buffer.get_insert());
        return navigate_at_iter(cursor);
    }

    private Gee.ArrayList<CardSummary> project_cards_for_selected_project() {
        var all_cards = new Gee.ArrayList<CardSummary>();
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null) {
                all_cards.add(card);
            }
        }
        return EditorNavigationResolver.cards_for_project(controller.selected_project_id(), all_cards);
    }

    private bool navigate_at_iter(Gtk.TextIter iter) {
        Gtk.TextIter line_start = iter;
        line_start.set_line_offset(0);
        Gtk.TextIter line_end = line_start;
        line_end.forward_to_line_end();
        var line_text = editor_buffer.get_text(line_start, line_end, false);
        var line_byte_offset = editor_buffer.get_text(line_start, iter, false).length;

        Gtk.TextIter document_start;
        Gtk.TextIter document_end;
        editor_buffer.get_bounds(out document_start, out document_end);
        var editor_text = editor_buffer.get_text(document_start, document_end, false);
        var document_byte_offset = editor_buffer.get_text(document_start, iter, false).length;

        var current_card = controller.get_current_card();
        CardTagOccurrence[]? tag_occurrences = null;
        if (current_card != null) {
            tag_occurrences = current_card.tag_occurrences;
        }

        var result = resolver.resolve(
            editor_text,
            document_byte_offset,
            line_text,
            line_byte_offset,
            project_cards_for_selected_project(),
            controller.has_unsaved_editor_changes(),
            tag_occurrences
        );
        switch (result.kind) {
            case EditorNavigationKind.CREATE_PROMPT:
                if (result.toast_message != null) {
                    toast_overlay.add_toast(new Adw.Toast(result.toast_message));
                }
                var target_copy = result.payload;
                Idle.add(() => {
                    if (target_copy != null) {
                        card_action_dialog_adapter.confirm_create_linked_card(target_copy, () => {
                            controller.create_card_with_title.begin(target_copy);
                        });
                    }
                    return Source.REMOVE;
                });
                return true;
            case EditorNavigationKind.OPEN_CARD:
                selection_intent_orchestrator.open_card_with_transition.begin(
                    (!) result.payload,
                    "tool-card-open"
                );
                return true;
            case EditorNavigationKind.RESOURCE_PREVIEW:
                resource_preview_requested((!) result.payload);
                return true;
            case EditorNavigationKind.SHOW_TAG:
                workspace.show_tag((!) result.payload);
                return true;
            case EditorNavigationKind.OPEN_URI:
                try {
                    uri_launcher.launch((!) result.payload);
                } catch (Error e) {
                    toast_overlay.add_toast(
                        new Adw.Toast(EditorNavigationResolver.launch_failure_message(e.message))
                    );
                }
                return true;
            default:
                return false;
        }
    }
}

}
