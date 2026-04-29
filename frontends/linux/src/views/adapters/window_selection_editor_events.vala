namespace HolderLinux {

internal delegate void InternalLinkClickHandler(Gtk.GestureClick gesture,
                                                int n_press,
                                                double x,
                                                double y);
internal delegate bool InternalLinkKeyHandler(uint keyval,
                                              uint keycode,
                                              Gdk.ModifierType state);

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

internal interface IInternalLinkClickController : Object {
    public abstract Gtk.GestureClick gesture { get; }
    public abstract void set_button(uint button);
    public abstract void set_pressed_handler(owned InternalLinkClickHandler handler);
    public abstract void attach_to(GtkSource.View editor_view);
}

internal interface IInternalLinkKeyController : Object {
    public abstract void set_key_pressed_handler(owned InternalLinkKeyHandler handler);
    public abstract void attach_to(GtkSource.View editor_view);
}

internal interface IInternalLinkControllerFactory : Object {
    public abstract IInternalLinkClickController create_click_controller();
    public abstract IInternalLinkKeyController create_key_controller();
}

internal interface IEditorControllerAttachTarget : Object {
    public abstract void attach_click_controller(IInternalLinkClickController controller);
    public abstract void attach_key_controller(IInternalLinkKeyController controller);
}

private class GtkInternalLinkClickController : Object, IInternalLinkClickController {
    private Gtk.GestureClick inner = new Gtk.GestureClick();

    public Gtk.GestureClick gesture {
        get {
            return inner;
        }
    }

    public void set_button(uint button) {
        inner.set_button(button);
    }

    public void set_pressed_handler(owned InternalLinkClickHandler handler) {
        inner.pressed.connect((n_press, x, y) => {
            handler(inner, n_press, x, y);
        });
    }

    public void attach_to(GtkSource.View editor_view) {
        editor_view.add_controller(inner);
    }
}

private class GtkInternalLinkKeyController : Object, IInternalLinkKeyController {
    private Gtk.EventControllerKey inner = new Gtk.EventControllerKey();

    public void set_key_pressed_handler(owned InternalLinkKeyHandler handler) {
        inner.key_pressed.connect((keyval, keycode, state) => {
            return handler(keyval, keycode, state);
        });
    }

    public void attach_to(GtkSource.View editor_view) {
        editor_view.add_controller(inner);
    }
}

internal class GtkInternalLinkControllerFactory : Object, IInternalLinkControllerFactory {
    public IInternalLinkClickController create_click_controller() {
        return new GtkInternalLinkClickController();
    }

    public IInternalLinkKeyController create_key_controller() {
        return new GtkInternalLinkKeyController();
    }
}

internal class GtkSourceViewControllerAttachTarget : Object, IEditorControllerAttachTarget {
    private GtkSource.View editor_view;

    public GtkSourceViewControllerAttachTarget(GtkSource.View editor_view) {
        this.editor_view = editor_view;
    }

    public void attach_click_controller(IInternalLinkClickController controller) {
        controller.attach_to(editor_view);
    }

    public void attach_key_controller(IInternalLinkKeyController controller) {
        controller.attach_to(editor_view);
    }
}

internal class WindowSelectionEditorEventBinder : Object {
    private Gtk.SingleSelection project_selection; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private Gtk.SingleSelection card_selection; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private Gtk.SingleSelection ai_thread_selection; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private GtkSource.Buffer editor_buffer; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IWindowSelectionEditorEventSink sink; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IInternalLinkControllerFactory controller_factory; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IEditorControllerAttachTarget attach_target; // LCOV_EXCL_LINE: field declaration-only coverage artifact
    private IInternalLinkClickController? internal_link_click; // LCOV_EXCL_LINE: callback lifetime holder
    private IInternalLinkKeyController? internal_link_key; // LCOV_EXCL_LINE: callback lifetime holder

    public WindowSelectionEditorEventBinder(Gtk.SingleSelection project_selection,
                                            Gtk.SingleSelection card_selection,
                                            Gtk.SingleSelection ai_thread_selection,
                                            GtkSource.Buffer editor_buffer,
                                            GtkSource.View? editor_view,
                                            IWindowSelectionEditorEventSink sink,
                                            IInternalLinkControllerFactory? controller_factory = null,
                                            IEditorControllerAttachTarget? attach_target = null) {
        this.project_selection = project_selection;
        this.card_selection = card_selection;
        this.ai_thread_selection = ai_thread_selection;
        this.editor_buffer = editor_buffer;
        this.sink = sink;
        this.controller_factory = controller_factory ?? new GtkInternalLinkControllerFactory();
        if (attach_target != null) {
            this.attach_target = attach_target;
        } else {
            assert(editor_view != null);
            this.attach_target = new GtkSourceViewControllerAttachTarget((!) editor_view);
        }
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

        internal_link_click = controller_factory.create_click_controller();
        internal_link_click.set_button(Gdk.BUTTON_PRIMARY);
        internal_link_click.set_pressed_handler((gesture, n_press, x, y) => {
            sink.on_internal_link_click_pressed(gesture, n_press, x, y);
        });
        attach_target.attach_click_controller((!) internal_link_click);

        internal_link_key = controller_factory.create_key_controller();
        internal_link_key.set_key_pressed_handler((keyval, keycode, state) => {
            return sink.on_internal_link_key_pressed(keyval, keycode, state);
        });
        attach_target.attach_key_controller((!) internal_link_key);
    }
}

}
