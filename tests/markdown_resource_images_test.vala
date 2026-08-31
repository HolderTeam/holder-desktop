using GLib;

namespace HolderLinuxTests {

private void test_extracts_standalone_holder_images() {
    var controller = new HolderLinux.MarkdownResourceImageController();
    var markdown = "Before\n![Boiler photograph](holder://resource/abc123)\n" +
        "   ![Escaped \\] label](<holder://resource/def-456>)\nAfter";
    var references = controller.extract(markdown);

    assert(references.size == 2);
    assert(references[0].alt_text == "Boiler photograph");
    assert(references[0].resource_id == "abc123");
    assert(references[0].char_offset == "Before\n".char_count());
    assert(references[1].alt_text == "Escaped ] label");
    assert(references[1].resource_id == "def-456");
    assert(controller.resource_id_at_byte_offset(
        markdown, markdown.index_of("resource/abc123") + 10
    ) == "abc123");
}

private void test_ignores_code_and_nonstandalone_images() {
    var controller = new HolderLinux.MarkdownResourceImageController();
    var markdown = "```md\n![No](holder://resource/code)\n```\n" +
        "    ![No](holder://resource/indented)\n" +
        "Text ![No](holder://resource/inline)\n" +
        "![Yes](holder://resource/live)";
    var references = controller.extract(markdown);

    assert(references.size == 1);
    assert(references[0].resource_id == "live");
    assert(controller.resource_id_at_byte_offset(
        markdown, markdown.index_of("resource/code") + 10
    ) == null);
}

private void test_builds_readable_safe_markdown() {
    assert(HolderLinux.MarkdownResourceImageController.markdown_for_file(
        "/tmp/Boiler_photograph-2026.jpg", "abc123"
    ) == "![Boiler photograph 2026](holder://resource/abc123)");
    assert(HolderLinux.MarkdownResourceImageController.markdown_for_file(
        "/tmp/a]b.png", "r1"
    ) == "![a\\]b](holder://resource/r1)");
    assert(HolderLinux.MarkdownResourceImageController.block_insertion(
        "![Image](holder://resource/r1)", false, false
    ) == "\n![Image](holder://resource/r1)\n");
    assert(HolderLinux.MarkdownResourceImageController.filename_is_image("PHOTO.JPEG"));
    assert(!HolderLinux.MarkdownResourceImageController.filename_is_image("manual.pdf"));
}

private void test_resolves_first_image_asset_only() {
    var image = new HolderLinux.ResourceAsset("a-image", "r1", "photo.png", "image/png", 12);
    var pdf = new HolderLinux.ResourceAsset("a-pdf", "r1", "manual.pdf", "application/pdf", 15);
    var assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    assets.add(pdf);
    assets.add(image);
    var resources = new Gee.ArrayList<HolderLinux.ProjectResource>();
    resources.add(new HolderLinux.ProjectResource(
        "r1", "p1", "image", "", "Boiler", null, 1, 2, null, assets
    ));

    var controller = new HolderLinux.MarkdownResourceImageController();
    var items = controller.resolve("![Boiler](holder://resource/r1)", resources);
    assert(items.size == 1);
    assert(items[0].asset.asset_id == "a-image");
    assert(items[0].key() == "0:r1");
}

private void test_inline_decoration_does_not_change_markdown_text() {
    var text = "# Boiler\n\n![Boiler](holder://resource/r1)\n\n" +
        "![Pipework](holder://resource/r2)\n";
    var image = new HolderLinux.ResourceAsset("a-image", "r1", "photo.png", "image/png", 12);
    var assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    assets.add(image);
    var second_image = new HolderLinux.ResourceAsset(
        "a-image-2", "r2", "pipework.png", "image/png", 13
    );
    var second_assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    second_assets.add(second_image);
    var resources = new Gee.ArrayList<HolderLinux.ProjectResource>();
    resources.add(new HolderLinux.ProjectResource(
        "r1", "p1", "image", "", "Boiler", null, 1, 2, null, assets
    ));
    resources.add(new HolderLinux.ProjectResource(
        "r2", "p1", "image", "", "Pipework", null, 1, 2, null, second_assets
    ));
    var controller = new HolderLinux.MarkdownResourceImageController();
    var items = controller.resolve(text, resources);
    var buffer = new GtkSource.Buffer(null);
    buffer.set_highlight_syntax(true);
    var language_manager = new GtkSource.LanguageManager();
    var language_dir = Environment.get_variable("HOLDER_MARKDOWN_LANGUAGE_DIR");
    assert(language_dir != null);
    language_manager.prepend_search_path((!) language_dir);
    var markdown_language = language_manager.get_language("holder-markdown");
    assert(markdown_language != null);
    buffer.set_language((!) markdown_language);
    buffer.set_text(text, -1);
    var view = new GtkSource.View.with_buffer(buffer);
    var window = new Gtk.Window();
    window.set_default_size(900, 700);
    window.set_child(view);
    window.present();
    var renderer = new HolderLinux.InlineResourceImageRenderer(buffer, view);
    var spellcheck = new HolderLinux.EditorSpellcheckController(buffer, view);
    renderer.buffer_mutation_started.connect(() => {
        spellcheck.prepare_buffer_mutation();
    });
    renderer.buffer_mutation_finished.connect((has_inline_images) => {
        spellcheck.finish_buffer_mutation(has_inline_images);
    });

    assert(spellcheck.adapter != null);
    bool retired_adapter_destroyed = false;
    Spelling.TextBufferAdapter? retired_adapter = spellcheck.adapter;
    retired_adapter.weak_ref(() => {
        retired_adapter_destroyed = true;
    });
    assert(retired_adapter.get_enabled());
    retired_adapter = null;
    renderer.set_items(items);
    assert(!spellcheck.buffer_safe);
    assert(spellcheck.adapter == null);
    assert(retired_adapter_destroyed);
    for (int i = 0; i < 20; i++) {
        while (MainContext.default().pending()) {
            MainContext.default().iteration(false);
        }
        Thread.usleep(1000);
    }
    Gtk.TextIter start;
    Gtk.TextIter end;
    buffer.get_bounds(out start, out end);
    assert(buffer.get_text(start, end, false) == text);
    assert(renderer.decoration_count() == 2);

    int buffer_changes = 0;
    buffer.changed.connect(() => {
        buffer_changes++;
    });
    buffer.get_start_iter(out start);
    buffer.insert(ref start, "Updated\n", -1);
    var changes_after_edit = buffer_changes;
    var updated_text = "Updated\n" + text;
    renderer.set_items(controller.resolve(updated_text, resources));
    buffer.get_bounds(out start, out end);
    assert(buffer.get_text(start, end, false) == updated_text);
    assert(buffer_changes == changes_after_edit);
    assert(renderer.decoration_count() == 2);

    var replacement_text = "# Home\n\nProject overview";
    renderer.replace_buffer_text(replacement_text);
    buffer.get_bounds(out start, out end);
    assert(buffer.get_text(start, end, false) == replacement_text);
    assert(renderer.decoration_count() == 0);
    assert(spellcheck.buffer_safe);
    assert(spellcheck.adapter != null);
    assert(((Spelling.TextBufferAdapter) spellcheck.adapter).get_enabled());

    bool restored_adapter_destroyed = false;
    Spelling.TextBufferAdapter? restored_adapter = spellcheck.adapter;
    restored_adapter.weak_ref(() => {
        restored_adapter_destroyed = true;
    });
    spellcheck.set_enabled_preference(false);
    restored_adapter = null;
    renderer.clear();
    buffer.get_bounds(out start, out end);
    assert(buffer.get_text(start, end, false) == replacement_text);
    assert(renderer.decoration_count() == 0);
    assert(spellcheck.adapter != null);
    assert(!((Spelling.TextBufferAdapter) spellcheck.adapter).get_enabled());
    assert(restored_adapter_destroyed);
    window.destroy();
}

public static int main(string[] args) {
    Test.init(ref args);
    var gtk_available = Gtk.init_check();
    Test.add_func("/holder/markdown-resource-images/extract", test_extracts_standalone_holder_images);
    Test.add_func("/holder/markdown-resource-images/exclusions", test_ignores_code_and_nonstandalone_images);
    Test.add_func("/holder/markdown-resource-images/build", test_builds_readable_safe_markdown);
    Test.add_func("/holder/markdown-resource-images/resolve", test_resolves_first_image_asset_only);
    if (gtk_available) {
        Test.add_func("/holder/markdown-resource-images/buffer-purity",
                      test_inline_decoration_does_not_change_markdown_text);
    }
    return Test.run();
}

}
