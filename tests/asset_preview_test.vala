using GLib;

namespace HolderLinuxTests {

private class FakeStorageApi : Object, HolderLinux.IResourceStorageApi {
    public int downloads = 0;
    public string payload = "preview bytes";
    public Error? download_error = null;
    public bool corrupt_download = false;
    public bool slow_once = false;

    public async void download_asset(string resource_id,
                                     string asset_id,
                                     string destination_path) throws Error {
        downloads++;
        if (slow_once) {
            slow_once = false;
            var end = GLib.get_monotonic_time() + 50 * 1000;
            while (GLib.get_monotonic_time() < end) {
                while (MainContext.default().iteration(false)) {}
                Thread.usleep(1000);
            }
        }
        if (download_error != null) {
            throw download_error;
        }
        FileUtils.set_contents(destination_path, corrupt_download ? "corrupted" : payload);
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

private class FakeHolderApi : Object, HolderLinux.IHolderApi {
    public Gee.ArrayList<HolderLinux.CardLink> links = new Gee.ArrayList<HolderLinux.CardLink>();
    public Gee.ArrayList<HolderLinux.ProjectResource> resources = new Gee.ArrayList<HolderLinux.ProjectResource>();
    public Error? links_error = null;
    public Error? resources_error = null;
    public bool slow_links_once = false;
    public int list_card_links_calls = 0;
    public int list_resources_calls = 0;
    public string? last_card_id = null;
    public string? last_project_id = null;

    public async Gee.ArrayList<HolderLinux.CardLink> list_card_links(string card_id) throws Error {
        list_card_links_calls++;
        last_card_id = card_id;
        if (slow_links_once) {
            slow_links_once = false;
            var end = GLib.get_monotonic_time() + 50 * 1000;
            while (GLib.get_monotonic_time() < end) {
                while (MainContext.default().iteration(false)) {}
                Thread.usleep(1000);
            }
        }
        if (links_error != null) {
            throw links_error;
        }
        return links;
    }

    public async Gee.ArrayList<HolderLinux.ProjectResource> list_resources(string project_id) throws Error {
        list_resources_calls++;
        last_project_id = project_id;
        if (resources_error != null) {
            throw resources_error;
        }
        return resources;
    }

    public async void health_check() throws Error { throw new IOError.NOT_SUPPORTED("unused"); }
    public async HolderLinux.HealthInfo get_health_info() throws Error { throw new IOError.NOT_SUPPORTED("unused"); }
    public async Gee.ArrayList<HolderLinux.Project> list_projects() throws Error { throw new IOError.NOT_SUPPORTED("unused"); }
    public async string create_project(string name, string privacy_mode = "encrypted_git") throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async HolderLinux.ProjectRecoveryTokenExport export_project_recovery_token(
        string project_id, string pin
    ) throws Error { throw new IOError.NOT_SUPPORTED("unused"); }
    public async void import_project_recovery_token(
        string project_id, string pin, string recovery_token
    ) throws Error { throw new IOError.NOT_SUPPORTED("unused"); }
    public async HolderLinux.RecoveryTokenImportResult import_recovery_token(
        string pin, string recovery_token
    ) throws Error { throw new IOError.NOT_SUPPORTED("unused"); }
    public async Gee.ArrayList<HolderLinux.CardSummary> list_cards(string project_id,
                                                                    string view = "tree",
                                                                    string? parent_card_id = null,
                                                                    int limit = 0) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async HolderLinux.CardContextData get_card_context(string project_id,
                                                              string? parent_card_id = null) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async HolderLinux.CardDetail get_card(string card_id) throws Error { throw new IOError.NOT_SUPPORTED("unused"); }
    public async Gee.ArrayList<HolderLinux.TagCount> list_project_tags(string project_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async Gee.ArrayList<HolderLinux.CardSummary> list_cards_with_tag(string project_id,
                                                                            string tag) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async Gee.ArrayList<HolderLinux.CardLink> list_card_backlinks(string card_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async Gee.ArrayList<HolderLinux.TrashItem> list_trash_items(string project_id,
                                                                        string type = "all") throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void empty_trash(string project_id, string type = "all") throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void restore_trash_item(string item_type, string item_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void hard_delete_trash_item(string item_type, string item_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async string create_resource(string project_id,
                                        string kind,
                                        string uri,
                                        string label,
                                        string? desc = null,
                                        Gee.HashMap<string, Gee.ArrayList<string>>? extra_metadata = null) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void update_resource(string resource_id,
                                      string? kind,
                                      string? uri,
                                      string? label,
                                      string? desc,
                                      int64 updated_at,
                                      Gee.HashMap<string, Gee.ArrayList<string>>? extra_metadata = null) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void delete_resource(string resource_id) throws Error { throw new IOError.NOT_SUPPORTED("unused"); }
    public async HolderLinux.CardLink create_card_link(string from_card_id,
                                                       string to_card_id,
                                                       string kind = "ref",
                                                       string? label = null,
                                                       string to_type = "card") throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void delete_card_link(string from_card_id,
                                       string to_card_id,
                                       string kind,
                                       string to_type = "card") throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async Gee.ArrayList<HolderLinux.SearchCardResult> search_cards(string project_id,
                                                                           string query_text,
                                                                           int limit = 30) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async HolderLinux.AiCapabilitiesInfo get_ai_capabilities(string? project_id = null) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async HolderLinux.AiStatusInfo get_ai_status() throws Error { throw new IOError.NOT_SUPPORTED("unused"); }
    public async string start_ai_runner_pull(string model_tag, string? runner_id = null) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async Gee.ArrayList<HolderLinux.AiRunnerInfo> list_ai_runners() throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async HolderLinux.AiRunnerInfo create_ai_runner(string name,
                                                           string base_url,
                                                           bool enabled = true) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async HolderLinux.AiRunnerInfo update_ai_runner(string runner_id,
                                                           string? name = null,
                                                           string? base_url = null,
                                                           bool? enabled = null) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void delete_ai_runner(string runner_id) throws Error { throw new IOError.NOT_SUPPORTED("unused"); }
    public async Gee.ArrayList<HolderLinux.AiThreadSummary> list_ai_threads(string project_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async Gee.ArrayList<HolderLinux.AiMessage> list_ai_messages(string thread_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async string create_ai_thread(string project_id, string title) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async Gee.ArrayList<HolderLinux.AiCatalogProvider> list_ai_provider_catalog() throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async Gee.ArrayList<HolderLinux.AiRuntimeProvider> list_ai_runtime_providers() throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async HolderLinux.AiLocalModelConfigInfo get_ai_local_model_config() throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async HolderLinux.AiLocalModelConfigInfo set_ai_local_model_config(string? fast_model,
                                                                              string? strong_model,
                                                                              string? deep_model) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async Gee.ArrayList<HolderLinux.AiProviderCredentialState> list_ai_provider_credentials() throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async Gee.ArrayList<HolderLinux.AiProviderSettingState> list_ai_provider_settings() throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void upsert_ai_provider_credential(string provider, string api_key) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void delete_ai_provider_credential(string provider) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void set_ai_provider_enabled(string provider, bool enabled) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async Gee.ArrayList<HolderLinux.AiNudge> list_ai_nudges(string project_id,
                                                                    string? card_id = null) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void dismiss_ai_nudge(string nudge_id) throws Error { throw new IOError.NOT_SUPPORTED("unused"); }
    public async HolderLinux.NudgeEvaluationResult evaluate_nudge_candidate(string kind,
                                                                             string project_id,
                                                                             string? card_id,
                                                                             int64 created_at,
                                                                             Json.Object facts,
                                                                             string? basis_fingerprint = null,
                                                                             string? basis_commit = null) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async Gee.ArrayList<HolderLinux.GitProviderCatalogEntry> list_git_provider_catalog() throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void set_project_git_remote(string project_id,
                                             string? git_remote_url,
                                             int64 updated_at) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async HolderLinux.GitTestRemoteResult test_project_git_remote(string project_id,
                                                                         string? remote_url = null,
                                                                         string branch = "") throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async HolderLinux.GitPushResult push_project_git(string project_id,
                                                            string branch = "",
                                                            bool set_upstream = true) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void run_ai_stream(string prompt,
                                    string? project_id,
                                    string? thread_id,
                                    string? context_card_id,
                                    string? context_card_title,
                                    string? context_card_body,
                                    HolderLinux.AiRunEventHandler on_event,
                                    string? runner_id = null,
                                    string? model = null) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async string create_card(string project_id,
                                    string title,
                                    string content,
                                    string? parent_card_id = null) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void update_card(string card_id,
                                  string title,
                                  string content,
                                  int64 updated_at) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void update_card_position(string card_id,
                                           string? parent_card_id,
                                           double sort_key,
                                           int64 updated_at) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
    public async void delete_card(string card_id) throws Error { throw new IOError.NOT_SUPPORTED("unused"); }
    public async HolderLinux.CardMoveResult move_card(string card_id,
                                                      string project_id,
                                                      string intent,
                                                      string? target_card_id = null,
                                                      string? parent_card_id = null) throws Error {
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

private string make_temp_cache_dir() {
    try {
        return DirUtils.make_tmp("holder-asset-cache-test-XXXXXX");
    } catch (Error e) {
        assert_not_reached();
    }
}

private void test_validate_file_treats_missing_checksum_as_size_only() {
    var temp_dir = make_temp_cache_dir();
    var path = Path.build_filename(temp_dir, "plain.bin");
    try {
        FileUtils.set_contents(path, "hello");
    } catch (Error e) {
        assert_not_reached();
    }
    var asset = new HolderLinux.ResourceAsset("a1", "r1", "plain.bin", "application/octet-stream", 5, "");
    var cache = new HolderLinux.AssetCache(temp_dir);
    assert(cache.validate_file(path, asset));

    var wrong_size_asset = new HolderLinux.ResourceAsset("a1", "r1", "plain.bin", "application/octet-stream", 999, "");
    assert(!cache.validate_file(path, wrong_size_asset));
}

private void test_validate_file_returns_false_when_the_file_cannot_be_read() {
    var temp_dir = make_temp_cache_dir();
    var path = Path.build_filename(temp_dir, "locked.bin");
    var payload = "secret";
    try {
        FileUtils.set_contents(path, payload);
    } catch (Error e) {
        assert_not_reached();
    }
    FileUtils.chmod(path, 0000);

    string? readable = null;
    try {
        FileUtils.get_contents(path, out readable);
    } catch (Error e) {
        readable = null;
    }
    if (readable != null) {
        FileUtils.chmod(path, 0600);
        Test.skip("file permissions are not enforced for this user");
        return;
    }

    var asset = new HolderLinux.ResourceAsset(
        "a1", "r1", "locked.bin", "application/octet-stream", payload.length,
        Checksum.compute_for_string(ChecksumType.SHA256, payload)
    );
    var cache = new HolderLinux.AssetCache(temp_dir);
    assert(!cache.validate_file(path, asset));
    FileUtils.chmod(path, 0600);
    assert(cache.validate_file(path, asset));
}

private void test_export_cached_copies_file_and_overwrites_existing_destination() {
    var temp_dir = make_temp_cache_dir();
    var source = Path.build_filename(temp_dir, "source.bin");
    var destination = Path.build_filename(temp_dir, "exported.bin");
    try {
        FileUtils.set_contents(source, "exported bytes");
        FileUtils.set_contents(destination, "stale");
    } catch (Error e) {
        assert_not_reached();
    }
    var cache = new HolderLinux.AssetCache(temp_dir);

    Error? failure = null;
    var loop = new MainLoop();
    cache.export_cached.begin(source, destination, null, (obj, result) => {
        try {
            cache.export_cached.end(result);
        } catch (Error e) {
            failure = e;
        }
        loop.quit();
    });
    loop.run();

    assert(failure == null);
    string contents;
    try {
        FileUtils.get_contents(destination, out contents);
    } catch (Error e) {
        assert_not_reached();
    }
    assert(contents == "exported bytes");
}

private void test_export_cached_reports_missing_source() {
    var temp_dir = make_temp_cache_dir();
    var cache = new HolderLinux.AssetCache(temp_dir);

    Error? failure = null;
    var loop = new MainLoop();
    cache.export_cached.begin(
        Path.build_filename(temp_dir, "does-not-exist.bin"),
        Path.build_filename(temp_dir, "exported.bin"),
        null,
        (obj, result) => {
            try {
                cache.export_cached.end(result);
            } catch (Error e) {
                failure = e;
            }
            loop.quit();
        }
    );
    loop.run();

    assert(failure != null);
    assert(failure is IOError.NOT_FOUND);
    assert(!FileUtils.test(Path.build_filename(temp_dir, "exported.bin"), FileTest.EXISTS));
}

private void test_safe_filename_falls_back_for_dot_segments_and_sanitizes_characters() {
    assert(HolderLinux.AssetCache.safe_filename("..") == "asset");
    assert(HolderLinux.AssetCache.safe_filename(".") == "asset");
    assert(HolderLinux.AssetCache.safe_filename("") == "asset");
    assert(HolderLinux.AssetCache.safe_filename("my file!.png") == "my_file_.png");
}

private void test_cache_path_for_falls_back_when_asset_id_is_blank() {
    var temp_dir = make_temp_cache_dir();
    var cache = new HolderLinux.AssetCache(temp_dir);
    var asset = new HolderLinux.ResourceAsset("", "r1", "picture.png", "image/png", 1, "");
    assert(cache.cache_path_for(asset) == Path.build_filename(temp_dir, "asset", "picture.png"));
}

private void test_ensure_cached_fails_when_asset_directory_path_is_blocked() {
    var temp_dir = make_temp_cache_dir();
    var api = new FakeStorageApi();
    var asset = make_asset(api.payload);
    var resource = make_resource(asset);
    var cache = new HolderLinux.AssetCache(temp_dir);

    // Occupy the directory slot AssetCache needs for this asset's files with a plain file,
    // so DirUtils.create_with_parents cannot create the directory and it isn't one already.
    try {
        FileUtils.set_contents(Path.build_filename(temp_dir, "a1"), "blocking file");
    } catch (Error e) {
        assert_not_reached();
    }

    Error? failure = null;
    var loop = new MainLoop();
    cache.ensure_cached.begin(api, resource, asset, null, (obj, result) => {
        try {
            cache.ensure_cached.end(result);
        } catch (Error e) {
            failure = e;
        }
        loop.quit();
    });
    loop.run();

    assert(failure != null);
    assert(((!) failure).message.contains("private Asset cache directory"));
    assert(api.downloads == 0);
}

private void test_ensure_cached_removes_partial_file_and_rethrows_on_download_failure() {
    var temp_dir = make_temp_cache_dir();
    var api = new FakeStorageApi();
    api.download_error = new IOError.FAILED("network unreachable");
    var asset = make_asset(api.payload);
    var resource = make_resource(asset);
    var cache = new HolderLinux.AssetCache(temp_dir);

    Error? failure = null;
    var loop = new MainLoop();
    cache.ensure_cached.begin(api, resource, asset, null, (obj, result) => {
        try {
            cache.ensure_cached.end(result);
        } catch (Error e) {
            failure = e;
        }
        loop.quit();
    });
    loop.run();

    assert(failure != null);
    assert(((!) failure).message == "network unreachable");
    assert(!has_leftover_partial_files(Path.build_filename(temp_dir, "a1")));
}

private void test_ensure_cached_removes_partial_file_and_throws_on_checksum_mismatch() {
    var temp_dir = make_temp_cache_dir();
    var api = new FakeStorageApi();
    api.corrupt_download = true;
    var asset = make_asset(api.payload);
    var resource = make_resource(asset);
    var cache = new HolderLinux.AssetCache(temp_dir);

    Error? failure = null;
    var loop = new MainLoop();
    cache.ensure_cached.begin(api, resource, asset, null, (obj, result) => {
        try {
            cache.ensure_cached.end(result);
        } catch (Error e) {
            failure = e;
        }
        loop.quit();
    });
    loop.run();

    assert(failure != null);
    assert(((!) failure).message.contains("integrity check"));
    assert(!has_leftover_partial_files(Path.build_filename(temp_dir, "a1")));
}

private bool has_leftover_partial_files(string asset_dir) {
    try {
        var dir = Dir.open(asset_dir, 0);
        string? name;
        while ((name = dir.read_name()) != null) {
            if (((!) name).contains(".partial-")) {
                return true;
            }
        }
    } catch (Error e) {
        assert_not_reached();
    }
    return false;
}

private void test_ensure_cached_with_live_cancellable_completes_successfully() {
    var temp_dir = make_temp_cache_dir();
    var api = new FakeStorageApi();
    var asset = make_asset(api.payload);
    var resource = make_resource(asset);
    var cache = new HolderLinux.AssetCache(temp_dir);
    var cancellable = new Cancellable();

    string? result_path = null;
    Error? failure = null;
    var loop = new MainLoop();
    cache.ensure_cached.begin(api, resource, asset, cancellable, (obj, result) => {
        try {
            result_path = cache.ensure_cached.end(result);
        } catch (Error e) {
            failure = e;
        }
        loop.quit();
    });
    loop.run();

    assert(failure == null);
    assert(result_path != null);
}

private void test_ensure_cached_serializes_concurrent_calls_for_the_same_cache() {
    var temp_dir = make_temp_cache_dir();
    var api = new FakeStorageApi();
    api.slow_once = true;
    var asset = make_asset(api.payload);
    var resource = make_resource(asset);
    var cache = new HolderLinux.AssetCache(temp_dir);

    string? first_path = null;
    string? second_path = null;
    Error? first_error = null;
    Error? second_error = null;
    var loop = new MainLoop();
    int pending = 2;

    Timeout.add(5, () => {
        cache.ensure_cached.begin(api, resource, asset, null, (obj, result) => {
            try {
                second_path = cache.ensure_cached.end(result);
            } catch (Error e) {
                second_error = e;
            }
            pending--;
            if (pending == 0) {
                loop.quit();
            }
        });
        return Source.REMOVE;
    });

    cache.ensure_cached.begin(api, resource, asset, null, (obj, result) => {
        try {
            first_path = cache.ensure_cached.end(result);
        } catch (Error e) {
            first_error = e;
        }
        pending--;
        if (pending == 0) {
            loop.quit();
        }
    });

    loop.run();

    assert(first_error == null);
    assert(second_error == null);
    assert(first_path == second_path);
    assert(api.downloads == 1);
}

private void test_ensure_cached_rejects_a_call_already_cancelled_while_waiting_for_the_lock() {
    var temp_dir = make_temp_cache_dir();
    var api = new FakeStorageApi();
    api.slow_once = true;
    var asset = make_asset(api.payload);
    var resource = make_resource(asset);
    var cache = new HolderLinux.AssetCache(temp_dir);
    var cancellable = new Cancellable();

    Error? first_error = null;
    Error? second_error = null;
    var loop = new MainLoop();
    int pending = 2;

    Timeout.add(5, () => {
        cancellable.cancel();
        cache.ensure_cached.begin(api, resource, asset, cancellable, (obj, result) => {
            try {
                cache.ensure_cached.end(result);
            } catch (Error e) {
                second_error = e;
            }
            pending--;
            if (pending == 0) {
                loop.quit();
            }
        });
        return Source.REMOVE;
    });

    cache.ensure_cached.begin(api, resource, asset, null, (obj, result) => {
        try {
            cache.ensure_cached.end(result);
        } catch (Error e) {
            first_error = e;
        }
        pending--;
        if (pending == 0) {
            loop.quit();
        }
    });

    loop.run();

    assert(first_error == null);
    assert(second_error != null);
    assert(second_error is IOError.CANCELLED);
}

private void test_attachment_resolution_and_import_messages() {
    var asset = make_asset("preview bytes");
    var resource = make_resource(asset);
    var second_asset = new HolderLinux.ResourceAsset(
        "a2", "r2", "aardvark.png", "image/png", 5,
        Checksum.compute_for_string(ChecksumType.SHA256, "second")
    );
    var second_assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    second_assets.add(second_asset);
    var second_resource = new HolderLinux.ProjectResource(
        "r2", "p1", "image", "", "Aardvark", "Alternative text", 1, 2, null, second_assets
    );
    var resources = new Gee.ArrayList<HolderLinux.ProjectResource>();
    resources.add(resource);
    resources.add(second_resource);
    var links = new Gee.ArrayList<HolderLinux.CardLink>();
    links.add(new HolderLinux.CardLink("c1", "r1", "resource", "attachment", null, 1));
    links.add(new HolderLinux.CardLink("c1", "r1", "resource", "reference", null, 2));
    links.add(new HolderLinux.CardLink("c1", "r2", "resource", "attachment", null, 3));
    links.add(new HolderLinux.CardLink("c1", "missing-resource", "resource", "attachment", null, 4));
    var attachments = HolderLinux.AssetPreviewController.resolve_attachments("c1", links, resources);
    assert(attachments.size == 2);
    assert(attachments[0].asset.asset_id == "a1");
    assert(attachments[1].asset.asset_id == "a2");

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

private void test_refresh_card_attachments_short_circuits_on_missing_input() {
    var api = new FakeHolderApi();
    var controller = new HolderLinux.AssetPreviewController();
    int attachments_loaded_calls = 0;
    Gee.ArrayList<HolderLinux.CardAttachment>? last_attachments = null;
    int project_resources_loaded_calls = 0;
    int load_failed_calls = 0;
    controller.attachments_loaded.connect((attachments) => {
        attachments_loaded_calls++;
        last_attachments = attachments;
    });
    controller.project_resources_loaded.connect((project_id, resources) => {
        project_resources_loaded_calls++;
    });
    controller.load_failed.connect((message) => {
        load_failed_calls++;
    });

    var loop = new MainLoop();
    controller.refresh_card_attachments.begin(null, "p1", "c1", (obj, result) => {
        controller.refresh_card_attachments.end(result);
        loop.quit();
    });
    loop.run();
    assert(attachments_loaded_calls == 1);
    assert(last_attachments != null);
    assert(((!) last_attachments).size == 0);
    assert(project_resources_loaded_calls == 0);
    assert(load_failed_calls == 0);
    assert(api.list_card_links_calls == 0);
    assert(api.list_resources_calls == 0);

    controller.refresh_card_attachments.begin(api, null, "c1", (obj, result) => {
        controller.refresh_card_attachments.end(result);
        loop.quit();
    });
    loop.run();
    assert(attachments_loaded_calls == 2);

    controller.refresh_card_attachments.begin(api, "p1", null, (obj, result) => {
        controller.refresh_card_attachments.end(result);
        loop.quit();
    });
    loop.run();
    assert(attachments_loaded_calls == 3);
    assert(api.list_card_links_calls == 0);
    assert(api.list_resources_calls == 0);
}

private void test_refresh_card_attachments_success_emits_resources_and_attachments() {
    var asset = make_asset("preview bytes");
    var resource = make_resource(asset);
    var resources = new Gee.ArrayList<HolderLinux.ProjectResource>();
    resources.add(resource);
    var links = new Gee.ArrayList<HolderLinux.CardLink>();
    links.add(new HolderLinux.CardLink("c1", "r1", "resource", "attachment", null, 1));

    var api = new FakeHolderApi();
    api.resources = resources;
    api.links = links;

    var controller = new HolderLinux.AssetPreviewController();
    Gee.ArrayList<HolderLinux.CardAttachment>? last_attachments = null;
    string? loaded_project_id = null;
    Gee.ArrayList<HolderLinux.ProjectResource>? loaded_resources = null;
    controller.attachments_loaded.connect((attachments) => {
        last_attachments = attachments;
    });
    controller.project_resources_loaded.connect((project_id, resources_arg) => {
        loaded_project_id = project_id;
        loaded_resources = resources_arg;
    });
    controller.load_failed.connect((message) => {
        assert_not_reached();
    });

    var loop = new MainLoop();
    controller.refresh_card_attachments.begin(api, "p1", "c1", (obj, result) => {
        controller.refresh_card_attachments.end(result);
        loop.quit();
    });
    loop.run();

    assert(api.list_card_links_calls == 1);
    assert(api.last_card_id == "c1");
    assert(api.list_resources_calls == 1);
    assert(api.last_project_id == "p1");

    assert(loaded_project_id == "p1");
    assert(loaded_resources != null);
    assert(((!) loaded_resources).size == 1);

    assert(last_attachments != null);
    assert(((!) last_attachments).size == 1);
    assert(((!) last_attachments)[0].card_id == "c1");
    assert(((!) last_attachments)[0].asset.asset_id == "a1");
}

private void test_refresh_card_attachments_reports_failure_from_links() {
    var api = new FakeHolderApi();
    api.links_error = new IOError.FAILED("links unavailable");

    var controller = new HolderLinux.AssetPreviewController();
    int attachments_loaded_calls = 0;
    int project_resources_loaded_calls = 0;
    string? failure_message = null;
    controller.attachments_loaded.connect((attachments) => {
        attachments_loaded_calls++;
    });
    controller.project_resources_loaded.connect((project_id, resources) => {
        project_resources_loaded_calls++;
    });
    controller.load_failed.connect((message) => {
        failure_message = message;
    });

    var loop = new MainLoop();
    controller.refresh_card_attachments.begin(api, "p1", "c1", (obj, result) => {
        controller.refresh_card_attachments.end(result);
        loop.quit();
    });
    loop.run();

    assert(failure_message == "links unavailable");
    assert(attachments_loaded_calls == 0);
    assert(project_resources_loaded_calls == 0);
    assert(api.list_resources_calls == 0);
}

private void test_refresh_card_attachments_reports_failure_from_resources() {
    var api = new FakeHolderApi();
    api.resources_error = new IOError.FAILED("resources unavailable");

    var controller = new HolderLinux.AssetPreviewController();
    string? failure_message = null;
    controller.load_failed.connect((message) => {
        failure_message = message;
    });

    var loop = new MainLoop();
    controller.refresh_card_attachments.begin(api, "p1", "c1", (obj, result) => {
        controller.refresh_card_attachments.end(result);
        loop.quit();
    });
    loop.run();

    assert(failure_message == "resources unavailable");
}

private void test_refresh_card_attachments_ignores_stale_request() {
    var asset = make_asset("preview bytes");
    var resource = make_resource(asset);
    var resources = new Gee.ArrayList<HolderLinux.ProjectResource>();
    resources.add(resource);
    var links = new Gee.ArrayList<HolderLinux.CardLink>();
    links.add(new HolderLinux.CardLink("c1", "r1", "resource", "attachment", null, 1));

    var api = new FakeHolderApi();
    api.resources = resources;
    api.links = links;
    api.slow_links_once = true;

    var controller = new HolderLinux.AssetPreviewController();
    int attachments_loaded_calls = 0;
    Gee.ArrayList<HolderLinux.CardAttachment>? last_attachments = null;
    controller.attachments_loaded.connect((attachments) => {
        attachments_loaded_calls++;
        last_attachments = attachments;
    });

    var loop = new MainLoop();
    int pending = 2;

    Timeout.add(5, () => {
        controller.refresh_card_attachments.begin(api, "p1", "fresh-card", (obj, result) => {
            controller.refresh_card_attachments.end(result);
            pending--;
            if (pending == 0) {
                loop.quit();
            }
        });
        return Source.REMOVE;
    });

    controller.refresh_card_attachments.begin(api, "p1", "stale-card", (obj, result) => {
        controller.refresh_card_attachments.end(result);
        pending--;
        if (pending == 0) {
            loop.quit();
        }
    });

    loop.run();

    assert(attachments_loaded_calls == 1);
    assert(last_attachments != null);
    assert(((!) last_attachments).size == 1);
    assert(((!) last_attachments)[0].card_id == "fresh-card");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/asset-cache/validation-and-reuse", test_cache_sanitizes_paths_and_reuses_valid_file);
    Test.add_func("/holder/asset-cache/validate-file-treats-missing-checksum-as-size-only",
                  test_validate_file_treats_missing_checksum_as_size_only);
    Test.add_func("/holder/asset-cache/validate-file-returns-false-when-unreadable",
                  test_validate_file_returns_false_when_the_file_cannot_be_read);
    Test.add_func("/holder/asset-cache/export-copies-and-overwrites",
                  test_export_cached_copies_file_and_overwrites_existing_destination);
    Test.add_func("/holder/asset-cache/export-reports-missing-source",
                  test_export_cached_reports_missing_source);
    Test.add_func("/holder/asset-cache/safe-filename-falls-back-and-sanitizes",
                  test_safe_filename_falls_back_for_dot_segments_and_sanitizes_characters);
    Test.add_func("/holder/asset-cache/cache-path-for-falls-back-on-blank-asset-id",
                  test_cache_path_for_falls_back_when_asset_id_is_blank);
    Test.add_func("/holder/asset-cache/fails-when-asset-directory-path-is-blocked",
                  test_ensure_cached_fails_when_asset_directory_path_is_blocked);
    Test.add_func("/holder/asset-cache/removes-partial-file-and-rethrows-on-download-failure",
                  test_ensure_cached_removes_partial_file_and_rethrows_on_download_failure);
    Test.add_func("/holder/asset-cache/removes-partial-file-and-throws-on-checksum-mismatch",
                  test_ensure_cached_removes_partial_file_and_throws_on_checksum_mismatch);
    Test.add_func("/holder/asset-cache/completes-successfully-with-live-cancellable",
                  test_ensure_cached_with_live_cancellable_completes_successfully);
    Test.add_func("/holder/asset-cache/serializes-concurrent-calls",
                  test_ensure_cached_serializes_concurrent_calls_for_the_same_cache);
    Test.add_func("/holder/asset-cache/rejects-cancelled-call-while-waiting-for-lock",
                  test_ensure_cached_rejects_a_call_already_cancelled_while_waiting_for_the_lock);
    Test.add_func("/holder/asset-preview/attachments-and-messages", test_attachment_resolution_and_import_messages);
    Test.add_func("/holder/asset-preview/refresh-short-circuits-on-missing-input",
                  test_refresh_card_attachments_short_circuits_on_missing_input);
    Test.add_func("/holder/asset-preview/refresh-success-emits-resources-and-attachments",
                  test_refresh_card_attachments_success_emits_resources_and_attachments);
    Test.add_func("/holder/asset-preview/refresh-reports-failure-from-links",
                  test_refresh_card_attachments_reports_failure_from_links);
    Test.add_func("/holder/asset-preview/refresh-reports-failure-from-resources",
                  test_refresh_card_attachments_reports_failure_from_resources);
    Test.add_func("/holder/asset-preview/refresh-ignores-stale-request",
                  test_refresh_card_attachments_ignores_stale_request);
    return Test.run();
}

}
