using GLib;

namespace HolderLinuxTests {

private string join_parts(string separator, Gee.List<string> parts) {
    var joined = new StringBuilder();
    bool first = true;
    foreach (var part in parts) {
        if (!first) {
            joined.append(separator);
        }
        joined.append(part);
        first = false;
    }
    return joined.str;
}

private delegate void DownloadHook(string asset_id);

private class DownloadApi : Object, HolderLinux.IResourceStorageApi {
    public Gee.HashSet<string> failing_assets = new Gee.HashSet<string>();
    public DownloadHook? on_download = null;
    public int downloads { get; set; default = 0; }

    public async void download_asset(string resource_id, string asset_id, string destination_path) throws Error {
        downloads++;
        if (on_download != null) {
            on_download(asset_id);
        }
        if (failing_assets.contains(asset_id)) {
            throw new IOError.FAILED("offline");
        }
        FileUtils.set_contents(destination_path, "bytes");
    }

    public async HolderLinux.StorageLocationList list_storage_locations(string project_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async string create_storage_location(string project_id, string name, string provider,
                                                Gee.HashMap<string, string> configuration) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void bind_storage_location(string location_id, Gee.HashMap<string, string> values,
                                            string preview) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void prefer_storage_location(string project_id, string location_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void test_storage_location(string location_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void delete_storage_location(string location_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async string start_google_drive_oauth(string location_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async HolderLinux.AssetImportJob start_asset_import(string project_id, string card_id,
                                                               string location_id,
                                                               string source_path) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async HolderLinux.AssetImportJob get_asset_import_job(string job_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
}

private class RecordingSink : Object, HolderLinux.IInlineImageSink {
    public Gee.ArrayList<string> events = new Gee.ArrayList<string>();

    public void set_items(Gee.ArrayList<HolderLinux.InlineResourceImageItem> items) {
        events.add("items:%d".printf(items.size));
    }

    public void show_image(string key, string cached_path) {
        events.add("image:" + key);
    }

    public void show_error(string key, string message) {
        events.add("error:%s:%s".printf(key, message));
    }

    public void clear() {
        events.add("clear");
    }

    public string joined() {
        return join_parts("|", events);
    }
}

private class RefreshFixture : Object {
    public TestScheduler scheduler = new TestScheduler();
    public RecordingSink sink = new RecordingSink();
    public DownloadApi api = new DownloadApi();
    public HolderLinux.InlineImageRefresh refresh;
    public int due { get; set; default = 0; }

    public RefreshFixture() {
        string cache_dir;
        try {
            cache_dir = DirUtils.make_tmp("holder-inline-refresh-XXXXXX");
        } catch (Error e) {
            assert_not_reached();
        }
        refresh = new HolderLinux.InlineImageRefresh(
            scheduler,
            new HolderLinux.AssetCache(cache_dir),
            sink,
            new HolderLinux.MarkdownResourceImageController()
        );
        refresh.refresh_due.connect(() => { due++; });
    }

    public Gee.ArrayList<HolderLinux.ProjectResource> resources() {
        var list = new Gee.ArrayList<HolderLinux.ProjectResource>();
        foreach (var id in new string[] {"r1", "r2"}) {
            var assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
            assets.add(new HolderLinux.ResourceAsset("a-" + id, id, id + ".png", "image/png", 5, ""));
            list.add(new HolderLinux.ProjectResource(id, "p1", "thing", "", id, null, 1, 2, null, assets));
        }
        return list;
    }

    public void load_project_resources() {
        refresh.apply_project_resources("p1", resources(), "p1");
        sink.events.clear();
        scheduler.run_all_once();
        due = 0;
    }

    public void run(bool has_card,
                    string? project_id,
                    string markdown,
                    bool with_api = true) {
        bool done = false;
        refresh.refresh.begin(has_card, project_id, markdown, with_api ? api : null, (obj, res) => {
            refresh.refresh.end(res);
            done = true;
        });
        assert(wait_for_condition(() => done, 10000));
    }
}

private const string TWO_IMAGES =
    "![one](holder://resource/r1)\n\n![two](holder://resource/r2)\n";

private void test_disabled_refresh_only_clears_and_never_schedules() {
    var fixture = new RefreshFixture();
    fixture.refresh.queue_refresh();
    assert(fixture.scheduler.pending_one_shots() == 0);
    fixture.run(true, "p1", TWO_IMAGES);
    assert(fixture.sink.joined() == "clear");
    assert(!fixture.refresh.is_enabled());
}

private void test_enabling_queues_a_debounced_refresh_and_requeue_replaces_it() {
    var fixture = new RefreshFixture();
    fixture.refresh.set_enabled(true);
    assert(fixture.refresh.is_enabled());
    fixture.refresh.queue_refresh();
    assert(fixture.scheduler.cancel_calls == 1);
    fixture.scheduler.run_all_once();
    assert(fixture.due == 1);

    fixture.refresh.set_enabled(true);
    assert(fixture.scheduler.pending_one_shots() == 0);
}

private void test_disabling_cancels_pending_refresh_and_clears() {
    var fixture = new RefreshFixture();
    fixture.refresh.set_enabled(true);
    fixture.refresh.set_enabled(false);
    assert(fixture.sink.joined() == "clear");
    fixture.scheduler.run_all_once();
    assert(fixture.due == 0);
    fixture.refresh.set_enabled(false);
    assert(fixture.sink.joined() == "clear");
}

private void test_project_change_resets_resources_and_only_reports_changes() {
    var fixture = new RefreshFixture();
    fixture.refresh.note_current_project(null);
    assert(fixture.sink.joined() == "");

    fixture.refresh.set_enabled(true);
    fixture.scheduler.run_all_once();
    fixture.refresh.apply_project_resources("p1", fixture.resources(), "p1");
    assert(fixture.refresh.project_resources.size == 2);
    fixture.sink.events.clear();

    fixture.refresh.note_current_project("p1");
    assert(fixture.sink.joined() == "");
    assert(fixture.refresh.project_resources.size == 2);

    fixture.refresh.note_current_project("p2");
    assert(fixture.sink.joined() == "clear");
    assert(fixture.refresh.project_resources.size == 0);
}

private void test_resources_for_another_project_are_ignored() {
    var fixture = new RefreshFixture();
    fixture.refresh.set_enabled(true);
    fixture.scheduler.run_all_once();
    fixture.due = 0;
    fixture.refresh.apply_project_resources("p1", fixture.resources(), "p2");
    fixture.refresh.apply_project_resources("p1", fixture.resources(), null);
    assert(fixture.refresh.project_resources.size == 0);
    fixture.scheduler.run_all_once();
    assert(fixture.due == 0);
}

private void test_refresh_requires_card_and_matching_project() {
    var fixture = new RefreshFixture();
    fixture.refresh.set_enabled(true);
    fixture.load_project_resources();

    fixture.run(false, "p1", TWO_IMAGES);
    fixture.run(true, null, TWO_IMAGES);
    fixture.run(true, "other", TWO_IMAGES);
    assert(fixture.sink.joined() == "clear|clear|clear");
    assert(fixture.api.downloads == 0);
}

private void test_refresh_loads_every_referenced_image_through_the_cache() {
    var fixture = new RefreshFixture();
    fixture.refresh.set_enabled(true);
    fixture.load_project_resources();

    fixture.run(true, "p1", TWO_IMAGES);
    assert(fixture.sink.joined() == "items:2|image:0:r1|image:%d:r2".printf(
        (int) "![one](holder://resource/r1)\n\n".char_count()
    ));
    assert(fixture.api.downloads == 2);
}

private void test_refresh_reports_unavailable_storage_for_each_image() {
    var fixture = new RefreshFixture();
    fixture.refresh.set_enabled(true);
    fixture.load_project_resources();

    fixture.run(true, "p1", TWO_IMAGES, false);
    assert(fixture.sink.events.size == 3);
    assert(fixture.sink.events[0] == "items:2");
    assert(fixture.sink.events[1] == "error:0:r1:Asset storage is unavailable.");
    assert(fixture.sink.events[2].has_suffix(":r2:Asset storage is unavailable."));
}

private void test_download_failure_is_reported_and_loading_continues() {
    var fixture = new RefreshFixture();
    fixture.refresh.set_enabled(true);
    fixture.load_project_resources();
    fixture.api.failing_assets.add("a-r1");

    fixture.run(true, "p1", TWO_IMAGES);
    assert(fixture.sink.events[0] == "items:2");
    assert(fixture.sink.events[1] == "error:0:r1:Image unavailable: offline");
    assert(fixture.sink.events[2].has_prefix("image:"));
    assert(fixture.sink.events.size == 3);
}

private void test_refresh_superseded_while_downloading_stops_reporting() {
    var fixture = new RefreshFixture();
    fixture.refresh.set_enabled(true);
    fixture.load_project_resources();
    fixture.api.on_download = (asset_id) => {
        fixture.refresh.set_enabled(false);
    };

    fixture.run(true, "p1", TWO_IMAGES);
    assert(fixture.sink.joined() == "items:2|clear");
    assert(fixture.api.downloads == 1);
}

private void test_failure_after_being_superseded_is_not_reported() {
    var fixture = new RefreshFixture();
    fixture.refresh.set_enabled(true);
    fixture.load_project_resources();
    fixture.api.failing_assets.add("a-r1");
    fixture.api.on_download = (asset_id) => {
        fixture.refresh.note_current_project("elsewhere");
    };

    fixture.run(true, "p1", TWO_IMAGES);
    assert(fixture.sink.joined() == "items:2|clear");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/inline-image-refresh/disabled", test_disabled_refresh_only_clears_and_never_schedules);
    Test.add_func("/inline-image-refresh/enable-and-debounce", test_enabling_queues_a_debounced_refresh_and_requeue_replaces_it);
    Test.add_func("/inline-image-refresh/disable", test_disabling_cancels_pending_refresh_and_clears);
    Test.add_func("/inline-image-refresh/project-change", test_project_change_resets_resources_and_only_reports_changes);
    Test.add_func("/inline-image-refresh/other-project-resources", test_resources_for_another_project_are_ignored);
    Test.add_func("/inline-image-refresh/requires-card-and-project", test_refresh_requires_card_and_matching_project);
    Test.add_func("/inline-image-refresh/loads-images", test_refresh_loads_every_referenced_image_through_the_cache);
    Test.add_func("/inline-image-refresh/storage-unavailable", test_refresh_reports_unavailable_storage_for_each_image);
    Test.add_func("/inline-image-refresh/download-failure", test_download_failure_is_reported_and_loading_continues);
    Test.add_func("/inline-image-refresh/superseded-success", test_refresh_superseded_while_downloading_stops_reporting);
    Test.add_func("/inline-image-refresh/superseded-failure", test_failure_after_being_superseded_is_not_reported);
    return Test.run();
}

}
