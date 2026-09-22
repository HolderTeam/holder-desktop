namespace HolderLinux {

public interface IInlineImageSink : Object {
    public abstract void set_items(Gee.ArrayList<InlineResourceImageItem> items);
    public abstract void show_image(string key, string cached_path);
    public abstract void show_error(string key, string message);
    public abstract void clear();
}

// Decides when the inline Resource images embedded in the editor are (re)loaded: debounces
// bursts, invalidates in-flight loads, tracks which project's Resources are current and
// loads each image through the private Asset cache into the sink.
public class InlineImageRefresh : Object {
    public const uint DEBOUNCE_MS = 180;
    public const string STORAGE_UNAVAILABLE_MESSAGE = "Asset storage is unavailable.";
    public const string IMAGE_UNAVAILABLE_PREFIX = "Image unavailable: ";

    private IScheduler scheduler;
    private AssetCache asset_cache;
    private IInlineImageSink sink;
    private MarkdownResourceImageController resolver;
    private bool enabled = false;
    private uint refresh_id = 0;
    private uint load_serial = 0;
    private string? resources_project_id = null;

    public Gee.ArrayList<ProjectResource> project_resources { get; private set; }

    public signal void refresh_due();

    public InlineImageRefresh(IScheduler scheduler,
                              AssetCache asset_cache,
                              IInlineImageSink sink,
                              MarkdownResourceImageController resolver) {
        this.scheduler = scheduler;
        this.asset_cache = asset_cache;
        this.sink = sink;
        this.resolver = resolver;
        project_resources = new Gee.ArrayList<ProjectResource>();
    }

    public bool is_enabled() {
        return enabled;
    }

    public void set_enabled(bool value) {
        if (enabled == value) {
            return;
        }
        enabled = value;
        if (enabled) {
            queue_refresh();
            return;
        }
        cancel_pending();
        load_serial++;
        sink.clear();
    }

    public void queue_refresh() {
        if (!enabled) {
            return;
        }
        if (refresh_id != 0) {
            scheduler.cancel(refresh_id);
        }
        refresh_id = scheduler.schedule_once(DEBOUNCE_MS, () => {
            refresh_id = 0;
            refresh_due();
            return Source.REMOVE;
        });
    }

    public void note_current_project(string? project_id) {
        if (project_id == resources_project_id) {
            return;
        }
        resources_project_id = project_id;
        project_resources = new Gee.ArrayList<ProjectResource>();
        load_serial++;
        sink.clear();
    }

    public void apply_project_resources(string project_id,
                                        Gee.ArrayList<ProjectResource> resources,
                                        string? current_project_id) {
        if (current_project_id == null || current_project_id != project_id) {
            return;
        }
        resources_project_id = project_id;
        project_resources = resources;
        queue_refresh();
    }

    public async void refresh(bool has_current_card,
                              string? current_project_id,
                              string markdown,
                              IResourceStorageApi? storage_api) {
        if (!enabled) {
            load_serial++;
            sink.clear();
            return;
        }
        if (!has_current_card || current_project_id == null ||
            resources_project_id != current_project_id) {
            load_serial++;
            sink.clear();
            return;
        }

        var items = resolver.resolve(markdown, project_resources);
        var serial = ++load_serial;
        sink.set_items(items);
        if (storage_api == null) {
            foreach (var item in items) {
                sink.show_error(item.key(), STORAGE_UNAVAILABLE_MESSAGE);
            }
            return;
        }

        foreach (var item in items) {
            try {
                var cached_path = yield asset_cache.ensure_cached(
                    (!) storage_api,
                    item.resource,
                    item.asset
                );
                if (serial != load_serial) {
                    return;
                }
                sink.show_image(item.key(), cached_path);
            } catch (Error e) {
                if (serial != load_serial) {
                    return;
                }
                sink.show_error(item.key(), IMAGE_UNAVAILABLE_PREFIX + e.message);
            }
        }
    }

    private void cancel_pending() {
        if (refresh_id != 0) {
            scheduler.cancel(refresh_id);
            refresh_id = 0;
        }
    }
}

}
