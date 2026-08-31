using GLib;

namespace HolderLinuxTests {

private class FakeStorageApi : Object, HolderLinux.IResourceStorageApi {
    public int downloads = 0;
    public string payload = "preview bytes";

    public async void download_asset(string resource_id,
                                     string asset_id,
                                     string destination_path) throws Error {
        downloads++;
        FileUtils.set_contents(destination_path, payload);
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

private HolderLinux.ProjectResource make_resource(HolderLinux.ResourceAsset asset) {
    var assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    assets.add(asset);
    return new HolderLinux.ProjectResource(
        "r1", "p1", "image", "", "Picture", "Alternative text", 1, 2, null, assets
    );
}

private HolderLinux.ResourceAsset make_asset(string payload) {
    return new HolderLinux.ResourceAsset(
        "a1",
        "r1",
        "../unsafe/picture.png",
        "image/png",
        payload.length,
        Checksum.compute_for_string(ChecksumType.SHA256, payload)
    );
}

private void test_cache_sanitizes_paths_and_reuses_valid_file() {
    string temp_dir;
    try {
        temp_dir = DirUtils.make_tmp("holder-asset-cache-test-XXXXXX");
    } catch (Error e) {
        assert_not_reached();
    }
    var api = new FakeStorageApi();
    var asset = make_asset(api.payload);
    var resource = make_resource(asset);
    var cache = new HolderLinux.AssetCache(temp_dir);
    string? first_path = null;
    string? second_path = null;
    Error? failure = null;
    var loop = new MainLoop();
    cache.ensure_cached.begin(api, resource, asset, null, (obj, result) => {
        try {
            first_path = cache.ensure_cached.end(result);
        } catch (Error e) {
            failure = e;
        }
        loop.quit();
    });
    loop.run();
    assert(failure == null);
    assert(first_path != null);
    assert((!) first_path == Path.build_filename(temp_dir, "a1", "picture.png"));
    assert(api.downloads == 1);

    cache.ensure_cached.begin(api, resource, asset, null, (obj, result) => {
        try {
            second_path = cache.ensure_cached.end(result);
        } catch (Error e) {
            failure = e;
        }
        loop.quit();
    });
    loop.run();
    assert(failure == null);
    assert(second_path == first_path);
    assert(api.downloads == 1);

    try {
        FileUtils.set_contents((!) first_path, "corrupt");
    } catch (Error e) {
        assert_not_reached();
    }
    cache.ensure_cached.begin(api, resource, asset, null, (obj, result) => {
        try {
            cache.ensure_cached.end(result);
        } catch (Error e) {
            failure = e;
        }
        loop.quit();
    });
    loop.run();
    assert(failure == null);
    assert(api.downloads == 2);
    assert(cache.validate_file((!) first_path, asset));
}

private void test_attachment_resolution_and_import_messages() {
    var asset = make_asset("preview bytes");
    var resource = make_resource(asset);
    var resources = new Gee.ArrayList<HolderLinux.ProjectResource>();
    resources.add(resource);
    var links = new Gee.ArrayList<HolderLinux.CardLink>();
    links.add(new HolderLinux.CardLink("c1", "r1", "resource", "attachment", null, 1));
    links.add(new HolderLinux.CardLink("c1", "r1", "resource", "reference", null, 2));
    var attachments = HolderLinux.AssetPreviewController.resolve_attachments("c1", links, resources);
    assert(attachments.size == 1);
    assert(attachments[0].asset.asset_id == "a1");

    assert(HolderLinux.AssetPreviewController.import_completion_message(
        new HolderLinux.AssetImportJob("j", "completed", "r", "a", true, false)
    ).has_prefix("Already attached"));
    assert(HolderLinux.AssetPreviewController.import_completion_message(
        new HolderLinux.AssetImportJob("j", "completed", "r", "a", true, true)
    ).has_prefix("Existing Asset attached"));
    assert(HolderLinux.AssetPreviewController.import_completion_message(
        new HolderLinux.AssetImportJob("j", "completed", "r", "a", false, true)
    ).has_prefix("Asset imported"));
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/asset-cache/validation-and-reuse", test_cache_sanitizes_paths_and_reuses_valid_file);
    Test.add_func("/holder/asset-preview/attachments-and-messages", test_attachment_resolution_and_import_messages);
    return Test.run();
}

}
