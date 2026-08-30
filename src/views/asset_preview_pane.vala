namespace HolderLinux {

public class AssetPreviewPane : Object {
    private Gtk.Label resource_label;
    private Gtk.Label filename_label;
    private Gtk.DropDown attachment_selector;
    private Gtk.StringList attachment_names;
    private Gtk.Stack state_stack;
    private Gtk.Picture picture;
    private Gtk.ScrolledWindow picture_scroller;
    private Gtk.Label document_title;
    private Gtk.Label document_details;
    private Gtk.Label error_label;
    private Gtk.Label zoom_label;
    private Gtk.Button previous_button;
    private Gtk.Button next_button;
    private Gtk.Button open_external_button;
    private Gtk.Button export_button;
    private Gdk.Texture? texture;
    private double zoom = 0.0;
    private bool changing_selection = false;
    private Gee.ArrayList<CardAttachment> attachments = new Gee.ArrayList<CardAttachment>();

    public Gtk.Widget widget { get; private set; }
    public signal void close_requested();
    public signal void attachment_selected(uint index);
    public signal void open_external_requested();
    public signal void export_requested();

    public AssetPreviewPane() {
        widget = build_ui();
        show_empty();
    }

    public void set_attachments(Gee.ArrayList<CardAttachment> values, int selected_index = 0) {
        attachments = values;
        attachment_names.splice(0, attachment_names.get_n_items(), {});
        foreach (var attachment in attachments) {
            attachment_names.append(attachment.asset.original_filename);
        }
        var has_many = attachments.size > 1;
        attachment_selector.set_visible(has_many);
        previous_button.set_visible(has_many);
        next_button.set_visible(has_many);
        if (attachments.size == 0) {
            show_empty();
            return;
        }
        var index = selected_index.clamp(0, attachments.size - 1);
        changing_selection = true;
        attachment_selector.set_selected((uint) index);
        changing_selection = false;
        show_loading(attachments[index]);
        refresh_navigation_buttons(index);
    }

    public void select_attachment(int index) {
        if (index < 0 || index >= attachments.size) {
            return;
        }
        changing_selection = true;
        attachment_selector.set_selected((uint) index);
        changing_selection = false;
        attachment_selected((uint) index);
        refresh_navigation_buttons(index);
    }

    public void show_loading(CardAttachment attachment) {
        set_header(attachment);
        open_external_button.set_sensitive(false);
        export_button.set_sensitive(false);
        state_stack.set_visible_child_name("loading");
    }

    public void show_image(CardAttachment attachment, string cached_path) throws Error {
        set_header(attachment);
        texture = Gdk.Texture.from_filename(cached_path);
        picture.set_paintable(texture);
        picture.set_alternative_text(attachment.resource.desc ?? attachment.resource.label);
        set_fit();
        open_external_button.set_sensitive(true);
        export_button.set_sensitive(true);
        state_stack.set_visible_child_name("image");
    }

    public void show_document(CardAttachment attachment) {
        set_header(attachment);
        texture = null;
        picture.set_paintable(null);
        document_title.set_text(attachment.asset.original_filename);
        document_details.set_text("%s · %s".printf(
            attachment.asset.media_type,
            format_byte_size(attachment.asset.byte_size)
        ));
        open_external_button.set_sensitive(true);
        export_button.set_sensitive(true);
        state_stack.set_visible_child_name("document");
    }

    public void show_error(CardAttachment? attachment, string message) {
        if (attachment != null) {
            set_header(attachment);
        }
        error_label.set_text(message);
        open_external_button.set_sensitive(false);
        export_button.set_sensitive(false);
        state_stack.set_visible_child_name("error");
    }

    public void show_empty() {
        texture = null;
        picture.set_paintable(null);
        resource_label.set_text("Asset Preview");
        filename_label.set_text("No attachment selected");
        open_external_button.set_sensitive(false);
        export_button.set_sensitive(false);
        state_stack.set_visible_child_name("empty");
    }

    private Gtk.Widget build_ui() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        root.set_size_request(280, -1);
        root.add_css_class("view");

        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        header.set_margin_top(8);
        header.set_margin_bottom(8);
        header.set_margin_start(10);
        header.set_margin_end(6);
        var titles = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
        titles.set_hexpand(true);
        resource_label = new Gtk.Label("Asset Preview") { xalign = 0.0f };
        resource_label.add_css_class("heading");
        resource_label.set_ellipsize(Pango.EllipsizeMode.END);
        filename_label = new Gtk.Label("No attachment selected") { xalign = 0.0f };
        filename_label.add_css_class("dim-label");
        filename_label.set_ellipsize(Pango.EllipsizeMode.END);
        titles.append(resource_label);
        titles.append(filename_label);
        header.append(titles);
        var close_button = new Gtk.Button.from_icon_name("window-close-symbolic");
        close_button.set_tooltip_text("Close Asset Preview");
        close_button.add_css_class("flat");
        close_button.clicked.connect(() => { close_requested(); });
        header.append(close_button);
        root.append(header);
        root.append(new Gtk.Separator(Gtk.Orientation.HORIZONTAL));

        attachment_names = new Gtk.StringList(null);
        attachment_selector = new Gtk.DropDown(attachment_names, null);
        attachment_selector.set_margin_top(8);
        attachment_selector.set_margin_start(10);
        attachment_selector.set_margin_end(10);
        attachment_selector.set_tooltip_text("Choose an attachment on this Card");
        attachment_selector.notify["selected"].connect(() => {
            if (!changing_selection && attachment_selector.get_selected() != Gtk.INVALID_LIST_POSITION) {
                attachment_selected(attachment_selector.get_selected());
                refresh_navigation_buttons((int) attachment_selector.get_selected());
            }
        });
        root.append(attachment_selector);

        state_stack = new Gtk.Stack();
        state_stack.set_vexpand(true);
        state_stack.set_hexpand(true);
        state_stack.add_named(centered_label("No attachments on this Card."), "empty");
        var spinner = new Gtk.Spinner();
        spinner.start();
        spinner.set_halign(Gtk.Align.CENTER);
        spinner.set_valign(Gtk.Align.CENTER);
        state_stack.add_named(spinner, "loading");

        picture = new Gtk.Picture();
        picture.set_content_fit(Gtk.ContentFit.CONTAIN);
        picture.set_can_shrink(true);
        picture.set_halign(Gtk.Align.CENTER);
        picture.set_valign(Gtk.Align.CENTER);
        picture_scroller = new Gtk.ScrolledWindow();
        picture_scroller.set_child(picture);
        picture_scroller.set_vexpand(true);
        picture_scroller.set_hexpand(true);
        state_stack.add_named(picture_scroller, "image");

        var document_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        document_box.set_halign(Gtk.Align.CENTER);
        document_box.set_valign(Gtk.Align.CENTER);
        var document_icon = new Gtk.Image.from_icon_name("x-office-document-symbolic");
        document_icon.set_pixel_size(64);
        document_box.append(document_icon);
        document_title = new Gtk.Label("");
        document_title.set_wrap(true);
        document_title.set_justify(Gtk.Justification.CENTER);
        document_box.append(document_title);
        document_details = new Gtk.Label("");
        document_details.add_css_class("dim-label");
        document_box.append(document_details);
        state_stack.add_named(document_box, "document");

        error_label = centered_label("") as Gtk.Label;
        error_label.set_wrap(true);
        error_label.add_css_class("error");
        state_stack.add_named(error_label, "error");
        root.append(state_stack);

        var controls = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
        controls.set_margin_top(6);
        controls.set_margin_bottom(8);
        controls.set_margin_start(8);
        controls.set_margin_end(8);
        previous_button = icon_button("go-previous-symbolic", "Previous attachment");
        previous_button.clicked.connect(() => {
            select_attachment((int) attachment_selector.get_selected() - 1);
        });
        controls.append(previous_button);
        next_button = icon_button("go-next-symbolic", "Next attachment");
        next_button.clicked.connect(() => {
            select_attachment((int) attachment_selector.get_selected() + 1);
        });
        controls.append(next_button);
        var fit_button = new Gtk.Button.with_label("Fit");
        fit_button.set_tooltip_text("Fit image to preview");
        fit_button.clicked.connect(() => { set_fit(); });
        controls.append(fit_button);
        var actual_button = new Gtk.Button.with_label("100%");
        actual_button.set_tooltip_text("Show image at actual size");
        actual_button.clicked.connect(() => { set_zoom(1.0); });
        controls.append(actual_button);
        var zoom_out = icon_button("zoom-out-symbolic", "Zoom out");
        zoom_out.clicked.connect(() => { set_zoom(zoom == 0.0 ? 0.8 : zoom - 0.2); });
        controls.append(zoom_out);
        zoom_label = new Gtk.Label("Fit");
        zoom_label.set_width_chars(5);
        controls.append(zoom_label);
        var zoom_in = icon_button("zoom-in-symbolic", "Zoom in");
        zoom_in.clicked.connect(() => { set_zoom(zoom == 0.0 ? 1.2 : zoom + 0.2); });
        controls.append(zoom_in);
        root.append(controls);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        actions.set_margin_bottom(10);
        actions.set_margin_start(10);
        actions.set_margin_end(10);
        actions.set_halign(Gtk.Align.END);
        open_external_button = new Gtk.Button.with_label("Open Externally");
        open_external_button.clicked.connect(() => { open_external_requested(); });
        actions.append(open_external_button);
        export_button = new Gtk.Button.with_label("Export…");
        export_button.clicked.connect(() => { export_requested(); });
        actions.append(export_button);
        root.append(actions);
        return root;
    }

    private void set_header(CardAttachment attachment) {
        resource_label.set_text(attachment.resource.label);
        filename_label.set_text(attachment.asset.original_filename);
    }

    private void set_fit() {
        zoom = 0.0;
        picture.set_can_shrink(true);
        picture.set_content_fit(Gtk.ContentFit.CONTAIN);
        picture.set_size_request(-1, -1);
        picture.set_hexpand(true);
        picture.set_vexpand(true);
        zoom_label.set_text("Fit");
    }

    private void set_zoom(double requested_zoom) {
        if (texture == null) {
            return;
        }
        zoom = requested_zoom.clamp(0.2, 4.0);
        picture.set_can_shrink(false);
        picture.set_content_fit(Gtk.ContentFit.CONTAIN);
        picture.set_hexpand(false);
        picture.set_vexpand(false);
        picture.set_size_request(
            ((int) (((double) ((!) texture).get_width()) * zoom)).clamp(1, 16384),
            ((int) (((double) ((!) texture).get_height()) * zoom)).clamp(1, 16384)
        );
        zoom_label.set_text("%d%%".printf((int) (zoom * 100.0 + 0.5)));
    }

    private void refresh_navigation_buttons(int selected_index) {
        previous_button.set_sensitive(selected_index > 0);
        next_button.set_sensitive(selected_index >= 0 && selected_index + 1 < attachments.size);
    }

    private static Gtk.Label centered_label(string text) {
        var label = new Gtk.Label(text);
        label.set_halign(Gtk.Align.CENTER);
        label.set_valign(Gtk.Align.CENTER);
        label.set_margin_start(16);
        label.set_margin_end(16);
        label.add_css_class("dim-label");
        return label;
    }

    private static Gtk.Button icon_button(string icon_name, string tooltip) {
        var button = new Gtk.Button.from_icon_name(icon_name);
        button.set_tooltip_text(tooltip);
        return button;
    }

    private static string format_byte_size(int64 bytes) {
        return GLib.format_size((uint64) bytes);
    }
}

}
