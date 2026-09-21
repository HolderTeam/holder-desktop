using GLib;

namespace HolderLinuxTests {

private delegate bool PaneWidgetPredicate(Gtk.Widget widget);

private Gtk.Widget? pane_find(Gtk.Widget root, PaneWidgetPredicate predicate) {
    if (predicate(root)) {
        return root;
    }
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        var found = pane_find((!) child, predicate);
        if (found != null) {
            return found;
        }
    }
    return null;
}

private Gtk.Button pane_button_with_tooltip(Gtk.Widget root, string tooltip) {
    var found = pane_find(root, (w) => w is Gtk.Button && w.get_tooltip_text() == tooltip);
    assert(found != null);
    return (Gtk.Button) (!) found;
}

private Gtk.Button pane_button_with_label(Gtk.Widget root, string label) {
    var found = pane_find(root, (w) => w is Gtk.Button && ((Gtk.Button) w).get_label() == label);
    assert(found != null);
    return (Gtk.Button) (!) found;
}

// The pane's own page stack, not a stack that belongs to a child widget such as the dropdown.
private Gtk.Stack pane_stack(Gtk.Widget root) {
    var found = pane_find(root, (w) => w is Gtk.Stack && ((Gtk.Stack) w).get_child_by_name("loading") != null);
    assert(found != null);
    return (Gtk.Stack) (!) found;
}

private Gtk.DropDown pane_dropdown(Gtk.Widget root) {
    var found = pane_find(root, (w) => w is Gtk.DropDown);
    assert(found != null);
    return (Gtk.DropDown) (!) found;
}

private Gtk.Picture pane_picture(Gtk.Widget root) {
    var found = pane_find(root, (w) => w is Gtk.Picture);
    assert(found != null);
    return (Gtk.Picture) (!) found;
}

private Gtk.Label pane_resource_label(Gtk.Widget root) {
    var found = pane_find(root, (w) => w is Gtk.Label && w.has_css_class("heading"));
    assert(found != null);
    return (Gtk.Label) (!) found;
}

private Gtk.Label pane_filename_label(Gtk.Widget root) {
    var found = pane_find(root, (w) => w is Gtk.Label && w.has_css_class("dim-label")
        && ((Gtk.Label) w).get_ellipsize() == Pango.EllipsizeMode.END);
    assert(found != null);
    return (Gtk.Label) (!) found;
}

private Gtk.Label pane_zoom_label(Gtk.Widget root) {
    var found = pane_find(root, (w) => w is Gtk.Label && ((Gtk.Label) w).get_width_chars() == 5);
    assert(found != null);
    return (Gtk.Label) (!) found;
}

private Gtk.Label pane_error_label(Gtk.Widget root) {
    var found = pane_find(root, (w) => w is Gtk.Label && w.has_css_class("error"));
    assert(found != null);
    return (Gtk.Label) (!) found;
}

private bool pane_has_label_text(Gtk.Widget root, string text) {
    return pane_find(root, (w) => w is Gtk.Label && ((Gtk.Label) w).get_text() == text) != null;
}

private HolderLinux.CardAttachment pane_attachment(string asset_id,
                                                   string filename,
                                                   string media_type = "image/png",
                                                   int64 size = 2048,
                                                   string label = "Picture",
                                                   string? desc = "A picture") {
    var asset = new HolderLinux.ResourceAsset(
        asset_id, "r-" + asset_id, filename, media_type, size,
        Checksum.compute_for_string(ChecksumType.SHA256, asset_id)
    );
    var assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    assets.add(asset);
    var resource = new HolderLinux.ProjectResource(
        "r-" + asset_id, "p1", "image", "", label, desc, 1, 2, null, assets
    );
    return new HolderLinux.CardAttachment("c1", resource, asset);
}

private Gee.ArrayList<HolderLinux.CardAttachment> pane_attachments(int count) {
    var list = new Gee.ArrayList<HolderLinux.CardAttachment>();
    for (int i = 0; i < count; i++) {
        list.add(pane_attachment("a%d".printf(i + 1), "file%d.png".printf(i + 1)));
    }
    return list;
}

// A real PNG so Gdk can decode it: 40x20 pixels.
private string pane_make_png() {
    string dir;
    try {
        dir = DirUtils.make_tmp("holder-asset-pane-XXXXXX");
    } catch (Error e) {
        assert_not_reached();
    }
    var path = Path.build_filename(dir, "picture.png");
    var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, 40, 20);
    surface.write_to_png(path);
    assert(FileUtils.test(path, FileTest.IS_REGULAR));
    return path;
}

private class PaneSignals : Object {
    public int closes { get; set; default = 0; }
    public int opens { get; set; default = 0; }
    public int exports { get; set; default = 0; }
    public Gee.ArrayList<uint> selected = new Gee.ArrayList<uint>();

    public PaneSignals(HolderLinux.AssetPreviewPane pane) {
        pane.close_requested.connect(() => { closes++; });
        pane.open_external_requested.connect(() => { opens++; });
        pane.export_requested.connect(() => { exports++; });
        pane.attachment_selected.connect((index) => { selected.add(index); });
    }
}

private void test_pane_starts_empty() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;

    assert(pane_stack(root).get_visible_child_name() == "empty");
    assert(pane_resource_label(root).get_text() == "Asset Preview");
    assert(pane_filename_label(root).get_text() == "No attachment selected");
    assert(!pane_button_with_label(root, "Open Externally").get_sensitive());
    assert(!pane_button_with_label(root, "Export…").get_sensitive());
    assert(pane_zoom_label(root).get_text() == "Fit");
}

private void test_set_attachments_with_one_attachment_shows_loading_without_navigation() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    var list = pane_attachments(1);

    pane.set_attachments(list);

    assert(pane_stack(root).get_visible_child_name() == "loading");
    assert(pane_resource_label(root).get_text() == "Picture");
    assert(pane_filename_label(root).get_text() == "file1.png");
    assert(!pane_dropdown(root).get_visible());
    assert(!pane_button_with_tooltip(root, "Previous attachment").get_visible());
    assert(!pane_button_with_tooltip(root, "Next attachment").get_visible());
    assert(!pane_button_with_label(root, "Open Externally").get_sensitive());
    assert(!pane_button_with_label(root, "Export…").get_sensitive());
}

private void test_set_attachments_with_several_shows_the_selector_and_selected_one() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    var signals = new PaneSignals(pane);

    pane.set_attachments(pane_attachments(3), 1);

    assert(pane_dropdown(root).get_visible());
    assert(pane_dropdown(root).get_selected() == 1);
    assert(pane_filename_label(root).get_text() == "file2.png");
    assert(pane_button_with_tooltip(root, "Previous attachment").get_visible());
    assert(pane_button_with_tooltip(root, "Next attachment").get_visible());
    assert(pane_button_with_tooltip(root, "Previous attachment").get_sensitive());
    assert(pane_button_with_tooltip(root, "Next attachment").get_sensitive());
    // Rebuilding the list is the caller's own doing: it must not look like the user picked one.
    assert(signals.selected.size == 0);
}

private void test_set_attachments_rebuilds_without_announcing_a_selection() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    var signals = new PaneSignals(pane);

    pane.set_attachments(pane_attachments(3), 2);
    assert(pane_dropdown(root).get_selected() == 2);
    // Replace the list with a longer one, then a shorter one, then none.
    pane.set_attachments(pane_attachments(5), 4);
    assert(pane_dropdown(root).get_selected() == 4);
    pane.set_attachments(pane_attachments(2), 1);
    assert(pane_dropdown(root).get_selected() == 1);
    pane.set_attachments(new Gee.ArrayList<HolderLinux.CardAttachment>());

    assert(signals.selected.size == 0);
}

private void test_set_attachments_clamps_the_selected_index() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;

    pane.set_attachments(pane_attachments(3), 99);
    assert(pane_dropdown(root).get_selected() == 2);
    assert(pane_filename_label(root).get_text() == "file3.png");
    assert(!pane_button_with_tooltip(root, "Next attachment").get_sensitive());

    pane.set_attachments(pane_attachments(3), -5);
    assert(pane_dropdown(root).get_selected() == 0);
    assert(pane_filename_label(root).get_text() == "file1.png");
    assert(!pane_button_with_tooltip(root, "Previous attachment").get_sensitive());
}

private void test_set_attachments_with_none_shows_the_empty_state() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    pane.set_attachments(pane_attachments(3), 1);
    assert(pane_dropdown(root).get_visible());

    pane.set_attachments(new Gee.ArrayList<HolderLinux.CardAttachment>());

    assert(pane_stack(root).get_visible_child_name() == "empty");
    assert(!pane_dropdown(root).get_visible());
    assert(!pane_button_with_tooltip(root, "Previous attachment").get_visible());
    assert(!pane_button_with_tooltip(root, "Next attachment").get_visible());
    assert(pane_filename_label(root).get_text() == "No attachment selected");
    assert(!pane_button_with_label(root, "Export…").get_sensitive());
}

private void test_select_attachment_moves_the_selection_and_announces_it_once() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    pane.set_attachments(pane_attachments(3), 0);
    var signals = new PaneSignals(pane);
    assert(!pane_button_with_tooltip(root, "Previous attachment").get_sensitive());

    pane.select_attachment(2);

    assert(signals.selected.size == 1);
    assert(signals.selected[0] == 2);
    assert(pane_dropdown(root).get_selected() == 2);
    assert(pane_button_with_tooltip(root, "Previous attachment").get_sensitive());
    assert(!pane_button_with_tooltip(root, "Next attachment").get_sensitive());
}

private void test_select_attachment_ignores_positions_outside_the_list() {
    var pane = new HolderLinux.AssetPreviewPane();
    pane.set_attachments(pane_attachments(2), 0);
    var signals = new PaneSignals(pane);

    pane.select_attachment(-1);
    pane.select_attachment(2);
    pane.select_attachment(50);

    assert(signals.selected.size == 0);
    assert(pane_dropdown(pane.widget).get_selected() == 0);
}

private void test_choosing_from_the_dropdown_announces_and_updates_navigation() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    pane.set_attachments(pane_attachments(3), 0);
    var signals = new PaneSignals(pane);

    pane_dropdown(root).set_selected(1);

    assert(signals.selected.size == 1);
    assert(signals.selected[0] == 1);
    assert(pane_button_with_tooltip(root, "Previous attachment").get_sensitive());
    assert(pane_button_with_tooltip(root, "Next attachment").get_sensitive());
}

private void test_previous_and_next_buttons_step_through_the_attachments() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    pane.set_attachments(pane_attachments(3), 1);
    var signals = new PaneSignals(pane);

    pane_button_with_tooltip(root, "Next attachment").clicked();
    pane_button_with_tooltip(root, "Previous attachment").clicked();
    pane_button_with_tooltip(root, "Previous attachment").clicked();
    // Now at the first attachment: another Previous goes nowhere.
    pane_button_with_tooltip(root, "Previous attachment").clicked();

    assert(signals.selected.size == 3);
    assert(signals.selected[0] == 2);
    assert(signals.selected[1] == 1);
    assert(signals.selected[2] == 0);
    assert(pane_dropdown(root).get_selected() == 0);
}

private void test_show_image_displays_it_and_enables_the_actions() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    var attachment = pane_attachment("a1", "photo.png", "image/png", 2048, "Holiday", "Beach at dusk");
    pane.set_attachments(pane_attachments(1));

    try {
        pane.show_image(attachment, pane_make_png());
    } catch (Error e) {
        assert_not_reached();
    }

    assert(pane_stack(root).get_visible_child_name() == "image");
    assert(pane_resource_label(root).get_text() == "Holiday");
    assert(pane_filename_label(root).get_text() == "photo.png");
    assert(pane_picture(root).get_paintable() != null);
    assert(pane_picture(root).get_alternative_text() == "Beach at dusk");
    assert(pane_button_with_label(root, "Open Externally").get_sensitive());
    assert(pane_button_with_label(root, "Export…").get_sensitive());
    assert(pane_zoom_label(root).get_text() == "Fit");
    assert(pane_picture(root).get_can_shrink());
}

private void test_show_image_falls_back_to_the_label_for_alternative_text() {
    var pane = new HolderLinux.AssetPreviewPane();
    var attachment = pane_attachment("a1", "photo.png", "image/png", 10, "Holiday", null);

    try {
        pane.show_image(attachment, pane_make_png());
    } catch (Error e) {
        assert_not_reached();
    }

    assert(pane_picture(pane.widget).get_alternative_text() == "Holiday");
}

private void test_show_image_reports_a_file_that_is_not_an_image() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    pane.set_attachments(pane_attachments(1));
    string dir;
    try {
        dir = DirUtils.make_tmp("holder-asset-pane-XXXXXX");
    } catch (Error e) {
        assert_not_reached();
    }
    var path = Path.build_filename(dir, "not-an-image.png");
    try {
        FileUtils.set_contents(path, "this is not a picture");
    } catch (Error e) {
        assert_not_reached();
    }

    Error? failure = null;
    try {
        pane.show_image(pane_attachment("a1", "broken.png"), path);
    } catch (Error e) {
        failure = e;
    }

    assert(failure != null);
    // The caller turns the failure into an error page; the pane must not claim to show an image.
    assert(pane_stack(root).get_visible_child_name() != "image");
    assert(pane_picture(root).get_paintable() == null);
}

private void test_zoom_buttons_step_clamp_and_reset() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    try {
        pane.show_image(pane_attachment("a1", "photo.png"), pane_make_png());
    } catch (Error e) {
        assert_not_reached();
    }
    var zoom_label = pane_zoom_label(root);
    var picture = pane_picture(root);

    pane_button_with_tooltip(root, "Zoom in").clicked();
    assert(zoom_label.get_text() == "120%");
    int width;
    int height;
    picture.get_size_request(out width, out height);
    assert(width == 48 && height == 24);
    assert(!picture.get_can_shrink());

    pane_button_with_tooltip(root, "Zoom in").clicked();
    assert(zoom_label.get_text() == "140%");

    pane_button_with_tooltip(root, "Zoom out").clicked();
    pane_button_with_tooltip(root, "Zoom out").clicked();
    pane_button_with_tooltip(root, "Zoom out").clicked();
    assert(zoom_label.get_text() == "80%");

    for (int i = 0; i < 20; i++) {
        pane_button_with_tooltip(root, "Zoom out").clicked();
    }
    assert(zoom_label.get_text() == "20%");
    for (int i = 0; i < 40; i++) {
        pane_button_with_tooltip(root, "Zoom in").clicked();
    }
    assert(zoom_label.get_text() == "400%");

    pane_button_with_label(root, "100%").clicked();
    assert(zoom_label.get_text() == "100%");
    picture.get_size_request(out width, out height);
    assert(width == 40 && height == 20);

    pane_button_with_label(root, "Fit").clicked();
    assert(zoom_label.get_text() == "Fit");
    picture.get_size_request(out width, out height);
    assert(width == -1 && height == -1);
    assert(picture.get_can_shrink());
}

private void test_zoom_does_nothing_without_an_image() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    pane.show_document(pane_attachment("a1", "notes.pdf", "application/pdf"));

    pane_button_with_tooltip(root, "Zoom in").clicked();
    pane_button_with_label(root, "100%").clicked();

    assert(pane_zoom_label(root).get_text() == "Fit");
}

private void test_show_document_describes_the_file() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;

    pane.show_document(pane_attachment("a1", "notes.pdf", "application/pdf", 2048, "Meeting notes"));

    assert(pane_stack(root).get_visible_child_name() == "document");
    assert(pane_resource_label(root).get_text() == "Meeting notes");
    assert(pane_filename_label(root).get_text() == "notes.pdf");
    assert(pane_has_label_text(root, "notes.pdf"));
    assert(pane_has_label_text(root, "application/pdf · %s".printf(GLib.format_size(2048))));
    assert(pane_picture(root).get_paintable() == null);
    assert(pane_button_with_label(root, "Open Externally").get_sensitive());
    assert(pane_button_with_label(root, "Export…").get_sensitive());
}

private void test_show_document_after_an_image_drops_the_picture() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    try {
        pane.show_image(pane_attachment("a1", "photo.png"), pane_make_png());
    } catch (Error e) {
        assert_not_reached();
    }
    assert(pane_picture(root).get_paintable() != null);

    pane.show_document(pane_attachment("a2", "notes.pdf", "application/pdf"));

    assert(pane_picture(root).get_paintable() == null);
    // The old image must not be zoomable behind the document.
    pane_button_with_tooltip(root, "Zoom in").clicked();
    assert(pane_zoom_label(root).get_text() == "Fit");
}

private void test_show_loading_disables_the_actions() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    pane.show_document(pane_attachment("a1", "notes.pdf", "application/pdf"));

    pane.show_loading(pane_attachment("a2", "next.pdf", "application/pdf", 10, "Next one"));

    assert(pane_stack(root).get_visible_child_name() == "loading");
    assert(pane_resource_label(root).get_text() == "Next one");
    assert(pane_filename_label(root).get_text() == "next.pdf");
    assert(!pane_button_with_label(root, "Open Externally").get_sensitive());
    assert(!pane_button_with_label(root, "Export…").get_sensitive());
}

private void test_show_error_keeps_the_header_only_when_given_an_attachment() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    pane.show_document(pane_attachment("a1", "notes.pdf", "application/pdf", 10, "Meeting notes"));

    pane.show_error(null, "Could not load this Card's attachments: down");

    assert(pane_stack(root).get_visible_child_name() == "error");
    assert(pane_error_label(root).get_text() == "Could not load this Card's attachments: down");
    assert(pane_resource_label(root).get_text() == "Meeting notes");
    assert(!pane_button_with_label(root, "Open Externally").get_sensitive());
    assert(!pane_button_with_label(root, "Export…").get_sensitive());

    pane.show_error(pane_attachment("a2", "other.pdf", "application/pdf", 10, "Other"), "Not in the cache");

    assert(pane_resource_label(root).get_text() == "Other");
    assert(pane_filename_label(root).get_text() == "other.pdf");
    assert(pane_error_label(root).get_text() == "Not in the cache");
}

private void test_show_empty_resets_the_page() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    try {
        pane.show_image(pane_attachment("a1", "photo.png"), pane_make_png());
    } catch (Error e) {
        assert_not_reached();
    }

    pane.show_empty();

    assert(pane_stack(root).get_visible_child_name() == "empty");
    assert(pane_resource_label(root).get_text() == "Asset Preview");
    assert(pane_filename_label(root).get_text() == "No attachment selected");
    assert(pane_picture(root).get_paintable() == null);
    assert(!pane_button_with_label(root, "Open Externally").get_sensitive());
}

private void test_close_open_and_export_buttons_emit_their_signals() {
    var pane = new HolderLinux.AssetPreviewPane();
    var root = pane.widget;
    var signals = new PaneSignals(pane);
    pane.show_document(pane_attachment("a1", "notes.pdf", "application/pdf"));

    pane_button_with_tooltip(root, "Close Asset Preview").clicked();
    pane_button_with_label(root, "Open Externally").clicked();
    pane_button_with_label(root, "Export…").clicked();
    pane_button_with_label(root, "Export…").clicked();

    assert(signals.closes == 1);
    assert(signals.opens == 1);
    assert(signals.exports == 2);
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping asset preview pane tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    var prefix = "/holder/asset-preview-pane/";
    Test.add_func(prefix + "starts-empty", test_pane_starts_empty);
    Test.add_func(prefix + "one-attachment", test_set_attachments_with_one_attachment_shows_loading_without_navigation);
    Test.add_func(prefix + "several-attachments", test_set_attachments_with_several_shows_the_selector_and_selected_one);
    Test.add_func(prefix + "rebuild-is-silent", test_set_attachments_rebuilds_without_announcing_a_selection);
    Test.add_func(prefix + "clamps-index", test_set_attachments_clamps_the_selected_index);
    Test.add_func(prefix + "no-attachments", test_set_attachments_with_none_shows_the_empty_state);
    Test.add_func(prefix + "select-attachment", test_select_attachment_moves_the_selection_and_announces_it_once);
    Test.add_func(prefix + "select-out-of-range", test_select_attachment_ignores_positions_outside_the_list);
    Test.add_func(prefix + "dropdown-choice", test_choosing_from_the_dropdown_announces_and_updates_navigation);
    Test.add_func(prefix + "previous-next", test_previous_and_next_buttons_step_through_the_attachments);
    Test.add_func(prefix + "show-image", test_show_image_displays_it_and_enables_the_actions);
    Test.add_func(prefix + "image-alt-fallback", test_show_image_falls_back_to_the_label_for_alternative_text);
    Test.add_func(prefix + "image-decode-failure", test_show_image_reports_a_file_that_is_not_an_image);
    Test.add_func(prefix + "zoom", test_zoom_buttons_step_clamp_and_reset);
    Test.add_func(prefix + "zoom-without-image", test_zoom_does_nothing_without_an_image);
    Test.add_func(prefix + "show-document", test_show_document_describes_the_file);
    Test.add_func(prefix + "document-after-image", test_show_document_after_an_image_drops_the_picture);
    Test.add_func(prefix + "show-loading", test_show_loading_disables_the_actions);
    Test.add_func(prefix + "show-error", test_show_error_keeps_the_header_only_when_given_an_attachment);
    Test.add_func(prefix + "show-empty", test_show_empty_resets_the_page);
    Test.add_func(prefix + "buttons-emit-signals", test_close_open_and_export_buttons_emit_their_signals);
    return Test.run();
}

}
