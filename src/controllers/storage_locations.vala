namespace HolderLinux {

public delegate string? PreferredLocationLookup();

public class StorageLocationsRefreshResult : Object {
    public bool success { get; construct; }
    public bool has_error { get; construct; }
    public Gee.ArrayList<StorageLocation> locations { get; construct; }
    public string? preferred_location_id { get; construct; }
    public bool empty_visible { get; construct; }
    public string empty_text { get; construct; }
    public string error_title { get; construct; }
    public string error_details { get; construct; }

    public StorageLocationsRefreshResult(bool success,
                                         bool has_error,
                                         Gee.ArrayList<StorageLocation>? locations,
                                         string? preferred_location_id,
                                         bool empty_visible,
                                         string empty_text,
                                         string error_title = "",
                                         string error_details = "") {
        Object(
            success: success,
            has_error: has_error,
            locations: locations ?? new Gee.ArrayList<StorageLocation>(),
            preferred_location_id: preferred_location_id,
            empty_visible: empty_visible,
            empty_text: empty_text,
            error_title: error_title,
            error_details: error_details
        );
    }
}

public class StorageLocationsController : Object {
    public const string EMPTY_TEXT = "No storage location configured for this project.";
    public const string LOAD_FAILED_TEXT = "Failed to load storage locations.";

    public async StorageLocationsRefreshResult refresh_flow(IResourceStorageApi? storage_api,
                                                            Project? project) {
        if (project == null || storage_api == null) {
            return new StorageLocationsRefreshResult(false, false, null, null, true, EMPTY_TEXT);
        }
        try {
            var result = yield storage_api.list_storage_locations(project.project_id);
            return new StorageLocationsRefreshResult(
                true,
                false,
                result.locations,
                result.preferred_location_id,
                result.locations.size == 0,
                EMPTY_TEXT
            );
        } catch (Error e) {
            return new StorageLocationsRefreshResult(
                false,
                true,
                null,
                null,
                true,
                LOAD_FAILED_TEXT,
                "Storage Locations refresh failed",
                e.message
            );
        }
    }

    public async ResourcesMutationResult create_and_bind_flow(IResourceStorageApi? storage_api,
                                                              string project_id,
                                                              string location_name,
                                                              StorageLocationSpec spec,
                                                              PreferredLocationLookup preferred_lookup) {
        if (storage_api == null) {
            return new ResourcesMutationResult(false, true);
        }
        try {
            var location_id = yield storage_api.create_storage_location(
                project_id, location_name, spec.provider, spec.configuration
            );
            yield storage_api.bind_storage_location(location_id, spec.values, spec.preview);
            if (preferred_lookup() == null) {
                yield storage_api.prefer_storage_location(project_id, location_id);
            }
            return new ResourcesMutationResult(true, false, true, "Storage location added.");
        } catch (Error e) {
            return new ResourcesMutationResult(
                false, false, false, "", "Failed to add storage location", e.message
            );
        }
    }

    public async ResourcesMutationResult prefer_flow(IResourceStorageApi? storage_api,
                                                     string project_id,
                                                     string location_id) {
        if (storage_api == null) {
            return new ResourcesMutationResult(false, true);
        }
        try {
            yield storage_api.prefer_storage_location(project_id, location_id);
            return new ResourcesMutationResult(true, false, true, "Preferred storage location updated.");
        } catch (Error e) {
            return new ResourcesMutationResult(
                false, false, false, "", "Failed to update preferred location", e.message
            );
        }
    }

    public async ResourcesMutationResult test_flow(IResourceStorageApi? storage_api, string location_id) {
        if (storage_api == null) {
            return new ResourcesMutationResult(false, true);
        }
        try {
            yield storage_api.test_storage_location(location_id);
            return new ResourcesMutationResult(true, false, false, "Storage location is available.");
        } catch (Error e) {
            return new ResourcesMutationResult(
                false, false, false, "", "Storage location test failed", e.message
            );
        }
    }

    public async ResourcesMutationResult delete_flow(IResourceStorageApi? storage_api, string location_id) {
        if (storage_api == null) {
            return new ResourcesMutationResult(false, true);
        }
        try {
            yield storage_api.delete_storage_location(location_id);
            return new ResourcesMutationResult(true, false, true, "Storage location removed.");
        } catch (Error e) {
            return new ResourcesMutationResult(
                false, false, false, "", "Failed to remove storage location", e.message
            );
        }
    }
}

}
