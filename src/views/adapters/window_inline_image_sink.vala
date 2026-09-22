namespace HolderLinux {

internal class RendererInlineImageSink : Object, IInlineImageSink {
    private InlineResourceImageRenderer renderer;

    public RendererInlineImageSink(InlineResourceImageRenderer renderer) {
        this.renderer = renderer;
    }

    public void set_items(Gee.ArrayList<InlineResourceImageItem> items) {
        renderer.set_items(items);
    }

    public void show_image(string key, string cached_path) {
        renderer.show_image(key, cached_path);
    }

    public void show_error(string key, string message) {
        renderer.show_error(key, message);
    }

    public void clear() {
        renderer.clear();
    }
}

}
