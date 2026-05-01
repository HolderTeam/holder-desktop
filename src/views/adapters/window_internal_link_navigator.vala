namespace HolderLinux {

internal class WindowInternalLinkNavigator : Object {
    private InternalLinkController internal_link_controller;
    private GtkSource.Buffer editor_buffer;
    private GtkSource.View editor_view;
    private GLib.ListStore card_store;
    private MainController controller;
    private SelectionIntentOrchestrator selection_intent_orchestrator;
    private CardActionDialogAdapter card_action_dialog_adapter;
    private ToolboxPane toolbox;
    private Adw.ToastOverlay toast_overlay;

    public WindowInternalLinkNavigator(InternalLinkController internal_link_controller,
                                       GtkSource.Buffer editor_buffer,
                                       GtkSource.View editor_view,
                                       GLib.ListStore card_store,
                                       MainController controller,
                                       SelectionIntentOrchestrator selection_intent_orchestrator,
                                       CardActionDialogAdapter card_action_dialog_adapter,
                                       ToolboxPane toolbox,
                                       Adw.ToastOverlay toast_overlay) {
        this.internal_link_controller = internal_link_controller;
        this.editor_buffer = editor_buffer;
        this.editor_view = editor_view;
        this.card_store = card_store;
        this.controller = controller;
        this.selection_intent_orchestrator = selection_intent_orchestrator;
        this.card_action_dialog_adapter = card_action_dialog_adapter;
        this.toolbox = toolbox;
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
        if (n_press != 1) {
            return false;
        }
        var sequence = gesture.get_current_sequence();
        var event = gesture.get_last_event(sequence);
        if (event == null) {
            return false;
        }
        if ((event.get_modifier_state() & Gdk.ModifierType.CONTROL_MASK) == 0) {
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
        if ((state & Gdk.ModifierType.CONTROL_MASK) == 0) {
            return false;
        }
        if (keyval != Gdk.Key.Return && keyval != Gdk.Key.KP_Enter) {
            return false;
        }
        Gtk.TextIter cursor;
        editor_buffer.get_iter_at_mark(out cursor, editor_buffer.get_insert());
        return navigate_at_iter(cursor);
    }

    private string? target_at_iter(Gtk.TextIter iter) {
        Gtk.TextIter line_start = iter;
        line_start.set_line_offset(0);
        Gtk.TextIter line_end = line_start;
        line_end.forward_to_line_end();

        var line_text = editor_buffer.get_text(line_start, line_end, false);
        if (line_text == null || line_text.length == 0) {
            return null;
        }

        var before_cursor = editor_buffer.get_text(line_start, iter, false);
        var cursor_byte_offset = before_cursor.length;
        return internal_link_controller.extract_target_from_line(line_text, cursor_byte_offset);
    }

    private Gee.ArrayList<CardSummary> project_cards_for_selected_project() {
        var project_cards = new Gee.ArrayList<CardSummary>();
        var project_id = controller.selected_project_id();
        if (project_id == null) {
            return project_cards;
        }

        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null && card.project_id == project_id) {
                project_cards.add(card);
            }
        }
        return project_cards;
    }

    private bool navigate_at_iter(Gtk.TextIter iter) {
        var decision = internal_link_controller.decide_navigation(
            target_at_iter(iter),
            project_cards_for_selected_project()
        );
        if (!decision.handled) {
            return false;
        }

        if (decision.open_card_id == null) {
            if (decision.toast_message != null) {
                toast_overlay.add_toast(new Adw.Toast(decision.toast_message));
            }
            var target_copy = decision.create_target;
            Idle.add(() => {
                if (target_copy != null) {
                    card_action_dialog_adapter.confirm_create_linked_card(target_copy, () => {
                        controller.create_card_with_title.begin(target_copy);
                    });
                }
                return Source.REMOVE;
            });
            return true;
        }

        selection_intent_orchestrator.open_card_with_transition.begin(
            (!) decision.open_card_id,
            "tool-card-open"
        );
        return true;
    }
}

}
