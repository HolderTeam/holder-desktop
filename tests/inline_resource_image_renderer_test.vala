using GLib;

namespace HolderLinuxTests {

// A 1x1 PNG, so Gdk.Texture.from_filename has a real image to decode.
private const string ONE_PIXEL_PNG_BASE64 =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==";

private string ir_temp_dir() {
    try {
        return DirUtils.make_tmp("holder-inline-image-test-XXXXXX");
    } catch (Error e) {
        assert_not_reached();
    }
}

private string ir_write_png(string directory, string name) {
    var path = Path.build_filename(directory, name);
    try {
        FileUtils.set_data(path, Base64.decode(ONE_PIXEL_PNG_BASE64));
    } catch (Error e) {
        assert_not_reached();
    }
    return path;
}

private string ir_write_text(string directory, string name, string contents) {
    var path = Path.build_filename(directory, name);
    try {
        FileUtils.set_contents(path, contents);
    } catch (Error e) {
        assert_not_reached();
    }
    return path;
}

private void ir_settle() {
    var context = MainContext.default();
    for (int i = 0; i < 20; i++) {
        while (context.iteration(false)) {}
    }
}

private void ir_collect(Gtk.Widget root, Gee.ArrayList<Gtk.Widget> out_widgets) {
    out_widgets.add(root);
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        ir_collect((!) child, out_widgets);
    }
}

private Gee.ArrayList<Gtk.Widget> ir_descendants(Gtk.Widget root) {
    var widgets = new Gee.ArrayList<Gtk.Widget>();
    ir_collect(root, widgets);
    return widgets;
}

private Gee.ArrayList<Gtk.Button> ir_buttons(Gtk.Widget root) {
    var buttons = new Gee.ArrayList<Gtk.Button>();
    foreach (var widget in ir_descendants(root)) {
        if (widget is Gtk.Button) {
            buttons.add((Gtk.Button) widget);
        }
    }
    return buttons;
}

private Gtk.Stack ir_stack(Gtk.Button button) {
    foreach (var widget in ir_descendants(button)) {
        if (widget is Gtk.Stack) {
            return (Gtk.Stack) widget;
        }
    }
    assert_not_reached();
}

private Gee.ArrayList<string> ir_label_texts(Gtk.Widget root) {
    var texts = new Gee.ArrayList<string>();
    foreach (var widget in ir_descendants(root)) {
        if (widget is Gtk.Label) {
            texts.add(((Gtk.Label) widget).get_text());
        }
    }
    return texts;
}

private Gtk.Picture? ir_picture(Gtk.Button button) {
    foreach (var widget in ir_descendants(button)) {
        if (widget is Gtk.Picture) {
            return (Gtk.Picture) widget;
        }
    }
    return null;
}

private HolderLinux.ProjectResource ir_resource(string resource_id, string label, string asset_id) {
    var assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    assets.add(new HolderLinux.ResourceAsset(asset_id, resource_id, label + ".png", "image/png", 12));
    return new HolderLinux.ProjectResource(resource_id, "p1", "image", "", label, null, 1, 2, null, assets);
}

private const string TEXT =
    "# Title\n\n![Boiler](holder://resource/r1)\n\n![](holder://resource/r2)\n\nEnd\n";

private Gee.ArrayList<HolderLinux.ProjectResource> ir_resources(string boiler_label = "Boiler",
                                                                string boiler_asset = "a1") {
    var resources = new Gee.ArrayList<HolderLinux.ProjectResource>();
    resources.add(ir_resource("r1", boiler_label, boiler_asset));
    resources.add(ir_resource("r2", "Pipework", "a2"));
    return resources;
}

private class RendererHarness : Object {
    public GtkSource.Buffer buffer = new GtkSource.Buffer(null);
    public GtkSource.View view;
    public HolderLinux.InlineResourceImageRenderer renderer;
    public HolderLinux.MarkdownResourceImageController controller = new HolderLinux.MarkdownResourceImageController();
    public Gtk.Window? window = null;
    public int started { get; set; default = 0; }
    public int finished_with_images { get; set; default = 0; }
    public int finished_without_images { get; set; default = 0; }
    public Gee.ArrayList<string> previews = new Gee.ArrayList<string>();

    public RendererHarness(string text = TEXT, bool present = false) {
        buffer.set_text(text, -1);
        view = new GtkSource.View.with_buffer(buffer);
        if (present) {
            window = new Gtk.Window();
            window.set_default_size(900, 700);
            var scroller = new Gtk.ScrolledWindow();
            scroller.set_child(view);
            window.set_child(scroller);
            window.present();
        }
        renderer = new HolderLinux.InlineResourceImageRenderer(buffer, view);
        renderer.buffer_mutation_started.connect(() => { started++; });
        renderer.buffer_mutation_finished.connect((has_images) => {
            if (has_images) {
                finished_with_images++;
            } else {
                finished_without_images++;
            }
        });
        renderer.preview_requested.connect((resource, asset) => {
            previews.add("%s|%s".printf(resource.resource_id, asset.asset_id));
        });
    }

    public Gee.ArrayList<HolderLinux.InlineResourceImageItem> items(
        string text = TEXT,
        Gee.ArrayList<HolderLinux.ProjectResource>? resources = null
    ) {
        return controller.resolve(text, resources ?? ir_resources());
    }

    public string text() {
        Gtk.TextIter start;
        Gtk.TextIter end;
        buffer.get_bounds(out start, out end);
        return buffer.get_text(start, end, false);
    }

    // In document order. The renderer adds the last image first, so the view lists them reversed.
    public Gee.ArrayList<Gtk.Button> buttons() {
        var listed = ir_buttons(view);
        var in_document_order = new Gee.ArrayList<Gtk.Button>();
        for (int i = listed.size - 1; i >= 0; i--) {
            in_document_order.add(listed[i]);
        }
        return in_document_order;
    }

    public void destroy() {
        if (window != null) {
            ((!) window).destroy();
            ir_settle();
        }
    }
}

// ---- building decorations ------------------------------------------------------------------------

private void test_each_image_reference_gets_a_loading_button_that_leaves_the_text_alone() {
    var h = new RendererHarness();

    h.renderer.set_items(h.items());

    assert(h.renderer.decoration_count() == 2);
    var buttons = h.buttons();
    assert(buttons.size == 2);
    assert(h.text() == TEXT);
    foreach (var button in buttons) {
        assert(ir_stack(button).get_visible_child_name() == "loading");
    }
    assert(buttons[0].get_tooltip_text() == "Open Boiler in Asset Preview");
    assert(buttons[1].get_tooltip_text() == "Open Pipework in Asset Preview");
    var texts = ir_label_texts(h.view);
    assert(texts.contains("Loading Boiler…") && texts.contains("Loading Pipework…"));
    assert(!h.renderer.is_applying_buffer_decoration);
    assert(h.started == 1 && h.finished_with_images == 1 && h.finished_without_images == 0);
}

private void test_the_caption_shows_only_when_the_reference_has_alt_text() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());

    var buttons = h.buttons();
    Gtk.Label? boiler_caption = null;
    Gtk.Label? blank_caption = null;
    foreach (var widget in ir_descendants(buttons[0])) {
        if (widget is Gtk.Label && ((Gtk.Label) widget).get_text() == "Boiler") {
            boiler_caption = (Gtk.Label) widget;
        }
    }
    foreach (var widget in ir_descendants(buttons[1])) {
        if (widget is Gtk.Label && ((Gtk.Label) widget).get_text() == "") {
            blank_caption = (Gtk.Label) widget;
        }
    }
    assert(boiler_caption != null && ((!) boiler_caption).get_visible());
    // The blank caption is the second image's, and it is hidden.
    assert(blank_caption != null);
    var visible_blank = false;
    foreach (var widget in ir_descendants(buttons[1])) {
        if (widget is Gtk.Label && ((Gtk.Label) widget).get_text() == "" && ((Gtk.Label) widget).get_visible()
            && ((Gtk.Label) widget).has_css_class("dim-label") && ((Gtk.Label) widget).get_ellipsize() == Pango.EllipsizeMode.END) {
            visible_blank = true;
        }
    }
    assert(!visible_blank);
}

private void test_clicking_a_decoration_asks_to_preview_its_resource_and_asset() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());

    h.buttons()[1].clicked();
    h.buttons()[0].clicked();

    assert(h.previews.size == 2);
    assert(h.previews[0] == "r2|a2");
    assert(h.previews[1] == "r1|a1");
}

private void test_the_same_items_keep_their_widgets_and_do_not_touch_the_buffer() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());
    var before = h.buttons();
    assert(before.size == 2);

    h.renderer.set_items(h.items());

    var after = h.buttons();
    assert(after.size == 2 && after[0] == before[0] && after[1] == before[1]);
    assert(h.started == 1 && h.finished_with_images == 1);
    // Clicking still reports the current item.
    after[0].clicked();
    assert(h.previews.size == 1 && h.previews[0] == "r1|a1");
}

private void test_changed_content_a_different_count_or_a_moved_anchor_rebuild_the_decorations() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());
    var original = h.buttons()[0];

    // A renamed resource is different content.
    h.renderer.set_items(h.items(TEXT, ir_resources("Renamed")));
    var after_rename = h.buttons();
    assert(after_rename.size == 2 && after_rename[0] != original);
    assert(after_rename[0].get_tooltip_text() == "Open Renamed in Asset Preview");
    assert(h.started == 2);

    // A different asset is different content.
    h.renderer.set_items(h.items(TEXT, ir_resources("Renamed", "a9")));
    assert(h.started == 3);
    h.buttons()[0].clicked();
    assert(h.previews[0] == "r1|a9");

    // A different number of images.
    var only_first = h.items("![Boiler](holder://resource/r1)\n", ir_resources());
    h.renderer.set_items(only_first);
    assert(h.renderer.decoration_count() == 1);
    assert(h.started == 4);

    // Items whose offsets no longer match where the anchors sit.
    var stale = h.items("![Boiler](holder://resource/r1)\n", ir_resources());
    Gtk.TextIter start;
    h.buffer.get_start_iter(out start);
    h.buffer.insert(ref start, "Inserted\n", -1);
    var started_before = h.started;
    h.renderer.set_items(stale);
    assert(h.started == started_before + 1);
}

private void test_decorations_follow_text_inserted_before_them() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());
    var before = h.buttons();
    Gtk.TextIter start;
    h.buffer.get_start_iter(out start);
    h.buffer.insert(ref start, "Preface\n", -1);
    var started_before = h.started;

    h.renderer.set_items(h.items("Preface\n" + TEXT));

    // The anchors moved with the text and the new offsets say so, so nothing is rebuilt.
    assert(h.started == started_before);
    var after = h.buttons();
    assert(after.size == 2 && after[0] == before[0] && after[1] == before[1]);
}

private void test_a_decoration_whose_anchor_was_deleted_is_rebuilt() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());
    var original = h.buttons();
    // Delete the whole document, which takes the anchors with it.
    Gtk.TextIter start;
    Gtk.TextIter end;
    h.buffer.get_bounds(out start, out end);
    h.buffer.delete(ref start, ref end);
    h.buffer.set_text(TEXT, -1);
    var started_before = h.started;

    h.renderer.set_items(h.items());

    assert(h.started == started_before + 1);
    var rebuilt = h.buttons();
    assert(rebuilt.size == 2);
    assert(rebuilt[0] != original[0]);
    assert(h.text() == TEXT);
}

// ---- states --------------------------------------------------------------------------------------

private void test_show_image_replaces_the_spinner_with_the_picture_and_names_it() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());
    var dir = ir_temp_dir();
    var png = ir_write_png(dir, "one.png");

    h.renderer.show_image(h.items()[0].key(), png);

    var first = h.buttons()[0];
    assert(ir_stack(first).get_visible_child_name() == "image");
    var picture = ir_picture(first);
    assert(picture != null);
    // The alt text names the picture; a reference without alt text falls back to the resource label.
    assert(((!) picture).get_alternative_text() == "Boiler");
    h.renderer.show_image(h.items()[1].key(), png);
    var second_picture = ir_picture(h.buttons()[1]);
    assert(second_picture != null && ((!) second_picture).get_alternative_text() == "Pipework");
}

private void test_showing_the_same_file_again_keeps_the_picture_and_a_new_file_replaces_it() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());
    var dir = ir_temp_dir();
    var first_png = ir_write_png(dir, "one.png");
    var second_png = ir_write_png(dir, "two.png");
    h.renderer.show_image(h.items()[0].key(), first_png);
    var picture = ir_picture(h.buttons()[0]);
    assert(picture != null);

    h.renderer.show_image(h.items()[0].key(), first_png);
    assert(ir_picture(h.buttons()[0]) == picture);

    h.renderer.show_image(h.items()[0].key(), second_png);
    var replaced = ir_picture(h.buttons()[0]);
    assert(replaced != null && replaced != picture);
    assert(ir_stack(h.buttons()[0]).get_visible_child_name() == "image");
}

private void test_an_error_page_replaces_the_picture_and_a_later_good_file_recovers() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());
    var dir = ir_temp_dir();
    var png = ir_write_png(dir, "one.png");
    h.renderer.show_image(h.items()[0].key(), png);

    h.renderer.show_error(h.items()[0].key(), "Download failed");

    var button = h.buttons()[0];
    assert(ir_stack(button).get_visible_child_name() == "error");
    assert(ir_label_texts(button).contains("Download failed"));

    // The same path shown again must load it afresh, since the error cleared what was on show.
    h.renderer.show_image(h.items()[0].key(), png);
    assert(ir_stack(button).get_visible_child_name() == "image");
}

private void test_a_file_that_is_not_an_image_shows_an_error_instead_of_a_picture() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());
    var dir = ir_temp_dir();
    var text_file = ir_write_text(dir, "notes.png", "this is not a png");

    h.renderer.show_image(h.items()[0].key(), text_file);

    var button = h.buttons()[0];
    assert(ir_stack(button).get_visible_child_name() == "error");
    bool has_message = false;
    foreach (var text in ir_label_texts(button)) {
        if (text.has_prefix("Could not display this image: ")) {
            has_message = true;
        }
    }
    assert(has_message);
    assert(ir_picture(button) == null);
}

private void test_states_for_an_unknown_key_are_ignored() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());
    var dir = ir_temp_dir();
    var png = ir_write_png(dir, "one.png");

    h.renderer.show_image("99:missing", png);
    h.renderer.show_error("99:missing", "nope");

    foreach (var button in h.buttons()) {
        assert(ir_stack(button).get_visible_child_name() == "loading");
    }
}

// ---- clearing ------------------------------------------------------------------------------------

private void test_clear_removes_the_decorations_and_leaves_the_text() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());
    assert(h.buttons().size == 2);

    h.renderer.clear();

    assert(h.renderer.decoration_count() == 0);
    assert(h.buttons().size == 0);
    assert(h.text() == TEXT);
    assert(h.started == 2 && h.finished_without_images == 1);
    assert(!h.renderer.is_applying_buffer_decoration);
}

private void test_replace_buffer_text_clears_the_decorations_and_swaps_the_text() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());

    h.renderer.replace_buffer_text("# Home\n");

    assert(h.text() == "# Home\n");
    assert(h.renderer.decoration_count() == 0);
    assert(h.buttons().size == 0);
    assert(h.started == 2 && h.finished_without_images == 1);
}

private void test_clearing_copes_with_a_button_that_is_already_gone_from_the_view() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());
    var button = h.buttons()[0];
    h.view.remove(button);
    assert(button.get_parent() == null);

    h.renderer.clear();

    assert(h.renderer.decoration_count() == 0);
    assert(h.text() == TEXT);
}

private void test_clearing_copes_with_an_anchor_the_user_already_deleted() {
    var h = new RendererHarness();
    h.renderer.set_items(h.items());
    Gtk.TextIter start;
    Gtk.TextIter end;
    h.buffer.get_bounds(out start, out end);
    h.buffer.delete(ref start, ref end);

    h.renderer.clear();

    assert(h.renderer.decoration_count() == 0);
    assert(h.buttons().size == 0);
}

// ---- width ---------------------------------------------------------------------------------------

private void test_decorations_fall_back_to_a_fixed_width_when_the_view_has_none() {
    var h = new RendererHarness();
    assert(h.view.get_width() == 0);

    h.renderer.set_items(h.items());

    int width;
    int height;
    h.buttons()[0].get_size_request(out width, out height);
    assert(width == HolderLinux.InlineImageDecorationPlan.FALLBACK_WIDTH);
}

private bool ir_wait_for(SourceFunc predicate, int timeout_ms = 5000) {
    var deadline = GLib.get_monotonic_time() + (int64) timeout_ms * 1000;
    while (GLib.get_monotonic_time() < deadline) {
        ir_settle();
        if (predicate()) {
            return true;
        }
        Thread.usleep(5000);
    }
    return predicate();
}

// GDK's macOS backend warns "gdk_frame_timings_presented() called on skipped frame" once a window
// has been presented and drops a frame, and GLib's test harness makes warnings fatal (SIGTRAP), so the
// tests that present a window run everywhere else.
private bool ir_skip_when_presenting_is_fatal() {
    if (Environment.get_variable("HOLDER_DESKTOP_TEST_PLATFORM") == "darwin") {
        Test.skip("presenting a window makes GDK's macOS frame warning fatal");
        return true;
    }
    return false;
}

private void test_decorations_take_the_views_width_and_follow_it_when_it_changes() {
    if (ir_skip_when_presenting_is_fatal()) return;
    var h = new RendererHarness(TEXT, true);
    assert(ir_wait_for(() => h.view.get_width() > 200));
    h.renderer.set_items(h.items());
    int width;
    int height;
    h.buttons()[0].get_size_request(out width, out height);
    assert(width == HolderLinux.InlineImageDecorationPlan.decoration_width(h.view.get_width()));
    assert(width != HolderLinux.InlineImageDecorationPlan.FALLBACK_WIDTH);
    var wide = h.view.get_width();

    ((!) h.window).set_default_size(500, 700);
    assert(ir_wait_for(() => h.view.get_width() < wide));

    // A narrower view used to leave every image at the width it was first given.
    assert(ir_wait_for(() => {
        int current;
        int unused;
        h.buttons()[0].get_size_request(out current, out unused);
        return current == HolderLinux.InlineImageDecorationPlan.decoration_width(h.view.get_width());
    }));
    h.destroy();
}

private void test_the_renderer_is_freed_with_its_last_reference_while_the_view_lives_on() {
    if (ir_skip_when_presenting_is_fatal()) return;
    var buffer = new GtkSource.Buffer(null);
    var view = new GtkSource.View.with_buffer(buffer);
    var window = new Gtk.Window();
    window.set_child(view);
    window.present();
    bool freed = false;
    var renderer = new HolderLinux.InlineResourceImageRenderer(buffer, view);
    renderer.weak_ref(() => { freed = true; });

    renderer = null;

    // The per-frame width check must not be what keeps it alive.
    assert(freed);
    // A frame after that finds the renderer gone and unhooks itself without touching it.
    ir_wait_for(() => false, 300);
    window.destroy();
    ir_settle();
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping inline resource image renderer tests: GTK display is unavailable.\n");
        return 0;
    }

    Test.add_func("/holder/inline-image-renderer/builds-decorations", test_each_image_reference_gets_a_loading_button_that_leaves_the_text_alone);
    Test.add_func("/holder/inline-image-renderer/caption", test_the_caption_shows_only_when_the_reference_has_alt_text);
    Test.add_func("/holder/inline-image-renderer/click-previews", test_clicking_a_decoration_asks_to_preview_its_resource_and_asset);
    Test.add_func("/holder/inline-image-renderer/same-items-keep-widgets", test_the_same_items_keep_their_widgets_and_do_not_touch_the_buffer);
    Test.add_func("/holder/inline-image-renderer/rebuilds", test_changed_content_a_different_count_or_a_moved_anchor_rebuild_the_decorations);
    Test.add_func("/holder/inline-image-renderer/follows-inserted-text", test_decorations_follow_text_inserted_before_them);
    Test.add_func("/holder/inline-image-renderer/deleted-anchor", test_a_decoration_whose_anchor_was_deleted_is_rebuilt);
    Test.add_func("/holder/inline-image-renderer/show-image", test_show_image_replaces_the_spinner_with_the_picture_and_names_it);
    Test.add_func("/holder/inline-image-renderer/show-image-again", test_showing_the_same_file_again_keeps_the_picture_and_a_new_file_replaces_it);
    Test.add_func("/holder/inline-image-renderer/error-then-recover", test_an_error_page_replaces_the_picture_and_a_later_good_file_recovers);
    Test.add_func("/holder/inline-image-renderer/not-an-image", test_a_file_that_is_not_an_image_shows_an_error_instead_of_a_picture);
    Test.add_func("/holder/inline-image-renderer/unknown-key", test_states_for_an_unknown_key_are_ignored);
    Test.add_func("/holder/inline-image-renderer/clear", test_clear_removes_the_decorations_and_leaves_the_text);
    Test.add_func("/holder/inline-image-renderer/replace-text", test_replace_buffer_text_clears_the_decorations_and_swaps_the_text);
    Test.add_func("/holder/inline-image-renderer/clear-removed-button", test_clearing_copes_with_a_button_that_is_already_gone_from_the_view);
    Test.add_func("/holder/inline-image-renderer/clear-deleted-anchor", test_clearing_copes_with_an_anchor_the_user_already_deleted);
    Test.add_func("/holder/inline-image-renderer/fallback-width", test_decorations_fall_back_to_a_fixed_width_when_the_view_has_none);
    Test.add_func("/holder/inline-image-renderer/follows-width", test_decorations_take_the_views_width_and_follow_it_when_it_changes);
    Test.add_func("/holder/inline-image-renderer/freed-with-last-reference", test_the_renderer_is_freed_with_its_last_reference_while_the_view_lives_on);
    return Test.run();
}

}
