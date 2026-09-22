using GLib;

namespace HolderLinuxTests {

public delegate void StorageApiHook(string call);

public HolderLinux.StorageLocation make_location(string id,
                                                 string provider,
                                                 bool bound,
                                                 string? preview = null,
                                                 string name = "name") {
    return new HolderLinux.StorageLocation(id, "p1", name, provider, null, bound, preview);
}

public HolderLinux.StorageLocationList make_location_list(HolderLinux.StorageLocation[] items,
                                                         string? preferred = null) {
    var list = new Gee.ArrayList<HolderLinux.StorageLocation>();
    foreach (var item in items) {
        list.add(item);
    }
    return new HolderLinux.StorageLocationList(list, preferred);
}

public class FakeStorageLocationApi : Object, HolderLinux.IResourceStorageApi {
    public Gee.ArrayList<string> calls = new Gee.ArrayList<string>();
    public Gee.ArrayList<HolderLinux.StorageLocationList> list_responses =
        new Gee.ArrayList<HolderLinux.StorageLocationList>();
    public int list_calls = 0;
    public string created_id = "new-location";
    public string oauth_url = "https://auth.example/consent";
    public string? list_error = null;
    public string? create_error = null;
    public string? bind_error = null;
    public string? prefer_error = null;
    public string? test_error = null;
    public string? delete_error = null;
    public string? oauth_error = null;
    public StorageApiHook? on_call = null;

    public string? last_created_name = null;
    public string? last_created_provider = null;
    public Gee.HashMap<string, string>? last_configuration = null;
    public Gee.HashMap<string, string>? last_bound_values = null;
    public string? last_bound_preview = null;
    public string? last_bound_location = null;
    public string? last_oauth_location = null;

    private void record(string call) {
        calls.add(call);
        if (on_call != null) {
            on_call(call);
        }
    }

    public async HolderLinux.StorageLocationList list_storage_locations(string project_id) throws Error {
        list_calls++;
        record("list");
        if (list_error != null) {
            throw new IOError.FAILED((!) list_error);
        }
        if (list_responses.size == 0) {
            return make_location_list({});
        }
        return list_responses[int.min(list_calls - 1, list_responses.size - 1)];
    }

    public async string create_storage_location(string project_id, string name, string provider,
                                                Gee.HashMap<string, string> configuration) throws Error {
        record("create");
        if (create_error != null) {
            throw new IOError.FAILED((!) create_error);
        }
        last_created_name = name;
        last_created_provider = provider;
        last_configuration = configuration;
        return created_id;
    }

    public async void bind_storage_location(string location_id, Gee.HashMap<string, string> values,
                                            string preview) throws Error {
        record("bind");
        if (bind_error != null) {
            throw new IOError.FAILED((!) bind_error);
        }
        last_bound_location = location_id;
        last_bound_values = values;
        last_bound_preview = preview;
    }

    public async void prefer_storage_location(string project_id, string location_id) throws Error {
        record("prefer:" + location_id);
        if (prefer_error != null) {
            throw new IOError.FAILED((!) prefer_error);
        }
    }

    public async void test_storage_location(string location_id) throws Error {
        record("test:" + location_id);
        if (test_error != null) {
            throw new IOError.FAILED((!) test_error);
        }
    }

    public async void delete_storage_location(string location_id) throws Error {
        record("delete:" + location_id);
        if (delete_error != null) {
            throw new IOError.FAILED((!) delete_error);
        }
    }

    public async string start_google_drive_oauth(string location_id) throws Error {
        record("oauth");
        if (oauth_error != null) {
            throw new IOError.FAILED((!) oauth_error);
        }
        last_oauth_location = location_id;
        return oauth_url;
    }

    public async HolderLinux.AssetImportJob start_asset_import(string project_id, string card_id,
                                                               string location_id,
                                                               string source_path) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }

    public async HolderLinux.AssetImportJob get_asset_import_job(string job_id) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }

    public async void download_asset(string resource_id, string asset_id, string destination_path) throws Error {
        throw new IOError.NOT_SUPPORTED("unused");
    }
}

}
