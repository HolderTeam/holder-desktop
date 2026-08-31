namespace HolderLinux {

public class InlineResourceImageRenderer : Object {
    private class Decoration : Object {
        public InlineResourceImageItem item;
        public Gtk.TextChildAnchor anchor;
        public Gtk.Button button;
        public Gtk.Stack state_stack;
        public Gtk.Label error_label;
        public string? displayed_path;

        public Decoration(InlineResourceImageItem item,
                          Gtk.TextChildAnchor anchor,
                          Gtk.Button button,
                          Gtk.Stack state_stack,
                          Gtk.Label error_label) {
            this.item = item;
            this.anchor = anchor;
            this.button = button;
            this.state_stack = state_stack;
            this.error_label = error_label;
        }
    }

    private GtkSource.Buffer buffer;
    private GtkSource.View view;
    private Spelling.TextBufferAdapter? spelling_adapter;
    private Gee.ArrayList<Decoration> decorations = new Gee.ArrayList<Decoration>();

    public bool is_applying_buffer_decoration { get; private set; default = false; }
    public signal void preview_requested(ProjectResource resource, ResourceAsset asset);

    public InlineResourceImageRenderer(GtkSource.Buffer buffer, GtkSource.View view) {
        this.buffer = buffer;
        this.view = view;
        view.notify["width"].connect(() => {
            update_decoration_widths();
        });
    }

    public void set_spelling_adapter(Spelling.TextBufferAdapter? adapter) {
        spelling_adapter = adapter;
    }

    public void set_items(Gee.ArrayList<InlineResourceImageItem> items) {
        if (update_existing_items(items)) {
            return;
        }
        var restore_spelling = suspend_spelling();
        is_applying_buffer_decoration = true;
        try {
            clear_internal();
            for (int i = items.size - 1; i >= 0; i--) {
                var item = items[i];
                Gtk.TextIter iter;
                buffer.get_iter_at_offset(out iter, item.reference.char_offset);
                var anchor = buffer.create_child_anchor(iter);
                Gtk.Stack state_stack;
                Gtk.Label error_label;
                var button = build_decoration(item, out state_stack, out error_label);
                view.add_child_at_anchor(button, anchor);
                var decoration = new Decoration(item, anchor, button, state_stack, error_label);
                button.clicked.connect(() => {
                    preview_requested(decoration.item.resource, decoration.item.asset);
                });
                decorations.insert(0, decoration);
            }
        } finally {
            is_applying_buffer_decoration = false;
            resume_spelling(restore_spelling);
        }
        update_decoration_widths();
    }

    public void show_image(string key, string cached_path) {
        var decoration = find_decoration(key);
        if (decoration == null) {
            return;
        }
        if (decoration.displayed_path == cached_path) {
            var existing_image = decoration.state_stack.get_child_by_name("image");
            if (existing_image != null) {
                decoration.state_stack.set_visible_child((!) existing_image);
                return;
            }
        }
        try {
            var texture = Gdk.Texture.from_filename(cached_path);
            var picture = new Gtk.Picture.for_paintable(texture);
            picture.set_content_fit(Gtk.ContentFit.CONTAIN);
            picture.set_can_shrink(true);
            picture.set_alternative_text(
                decoration.item.reference.alt_text.length > 0
                    ? decoration.item.reference.alt_text
                    : decoration.item.resource.label
            );
            picture.set_size_request(-1, 280);
            var previous_image = decoration.state_stack.get_child_by_name("image");
            if (previous_image != null) {
                decoration.state_stack.remove((!) previous_image);
            }
            decoration.state_stack.add_named(picture, "image");
            decoration.state_stack.set_visible_child_name("image");
            decoration.displayed_path = cached_path;
        } catch (Error e) {
            show_error(key, "Could not display this image: " + e.message);
        }
    }

    public void show_error(string key, string message) {
        var decoration = find_decoration(key);
        if (decoration == null) {
            return;
        }
        decoration.error_label.set_text(message);
        decoration.state_stack.set_visible_child_name("error");
        decoration.displayed_path = null;
    }

    public void clear() {
        var restore_spelling = suspend_spelling();
        is_applying_buffer_decoration = true;
        try {
            clear_internal();
        } finally {
            is_applying_buffer_decoration = false;
            resume_spelling(restore_spelling);
        }
    }

    public void replace_buffer_text(string text) {
        var restore_spelling = suspend_spelling();
        is_applying_buffer_decoration = true;
        try {
            clear_internal();
            buffer.set_text(text, -1);
        } finally {
            is_applying_buffer_decoration = false;
            resume_spelling(restore_spelling);
        }
    }

    public uint decoration_count() {
        return (uint) decorations.size;
    }

    private Gtk.Button build_decoration(InlineResourceImageItem item,
                                        out Gtk.Stack state_stack,
                                        out Gtk.Label error_label) {
        var button = new Gtk.Button();
        button.add_css_class("flat");
        button.set_tooltip_text("Open %s in Asset Preview".printf(item.resource.label));
        button.update_property(
            Gtk.AccessibleProperty.LABEL,
            "Open image: %s".printf(
                item.reference.alt_text.length > 0
                    ? item.reference.alt_text
                    : item.resource.label
            ),
            -1
        );

        var frame = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        frame.set_margin_top(8);
        frame.set_margin_bottom(8);
        frame.set_margin_start(8);
        frame.set_margin_end(8);
        state_stack = new Gtk.Stack();
        state_stack.set_size_request(-1, 280);

        var loading = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        loading.set_halign(Gtk.Align.CENTER);
        loading.set_valign(Gtk.Align.CENTER);
        var spinner = new Gtk.Spinner();
        spinner.start();
        loading.append(spinner);
        var loading_label = new Gtk.Label("Loading %s…".printf(item.resource.label));
        loading_label.add_css_class("dim-label");
        loading.append(loading_label);
        state_stack.add_named(loading, "loading");

        error_label = new Gtk.Label("");
        error_label.set_wrap(true);
        error_label.set_justify(Gtk.Justification.CENTER);
        error_label.set_halign(Gtk.Align.CENTER);
        error_label.set_valign(Gtk.Align.CENTER);
        error_label.add_css_class("dim-label");
        state_stack.add_named(error_label, "error");
        state_stack.set_visible_child_name("loading");
        frame.append(state_stack);

        var caption = new Gtk.Label(item.reference.alt_text);
        caption.set_visible(item.reference.alt_text.strip().length > 0);
        caption.add_css_class("dim-label");
        caption.set_ellipsize(Pango.EllipsizeMode.END);
        frame.append(caption);
        button.set_child(frame);
        return button;
    }

    private bool update_existing_items(Gee.ArrayList<InlineResourceImageItem> items) {
        if (items.size != decorations.size) {
            return false;
        }
        Gtk.TextIter document_start;
        buffer.get_start_iter(out document_start);
        for (int i = 0; i < items.size; i++) {
            var decoration = decorations[i];
            var item = items[i];
            if (decoration.anchor.get_deleted() ||
                decoration.item.resource.resource_id != item.resource.resource_id ||
                decoration.item.resource.label != item.resource.label ||
                decoration.item.asset.asset_id != item.asset.asset_id ||
                decoration.item.reference.alt_text != item.reference.alt_text) {
                return false;
            }
            Gtk.TextIter anchor_iter;
            buffer.get_iter_at_child_anchor(out anchor_iter, decoration.anchor);
            var text_before_anchor = buffer.get_text(document_start, anchor_iter, false);
            if (text_before_anchor.char_count() != item.reference.char_offset) {
                return false;
            }
        }
        for (int i = 0; i < items.size; i++) {
            decorations[i].item = items[i];
        }
        return true;
    }

    private Decoration? find_decoration(string key) {
        foreach (var decoration in decorations) {
            if (decoration.item.key() == key) {
                return decoration;
            }
        }
        return null;
    }

    private bool suspend_spelling() {
        if (spelling_adapter == null || !spelling_adapter.get_enabled()) {
            return false;
        }
        spelling_adapter.set_enabled(false);
        return true;
    }

    private void resume_spelling(bool restore) {
        if (!restore || spelling_adapter == null) {
            return;
        }
        spelling_adapter.set_enabled(true);
        spelling_adapter.invalidate_all();
    }

    private void clear_internal() {
        foreach (var decoration in decorations) {
            if (decoration.button.get_parent() != null) {
                view.remove(decoration.button);
            }
            if (!decoration.anchor.get_deleted()) {
                Gtk.TextIter start;
                buffer.get_iter_at_child_anchor(out start, decoration.anchor);
                Gtk.TextIter end = start;
                if (end.forward_char()) {
                    buffer.delete(ref start, ref end);
                }
            }
        }
        decorations.clear();
    }

    private void update_decoration_widths() {
        var width = view.get_width() > 160 ? view.get_width() - 80 : 560;
        foreach (var decoration in decorations) {
            decoration.button.set_size_request(width, -1);
        }
    }
}

}
