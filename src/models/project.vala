namespace HolderLinux {

public class Project : Object {
    public string project_id { get; construct; }
    public string name { get; set; }
    public string privacy_mode { get; construct; }
    public string root_path { get; construct; }
    public string? git_remote_url { get; construct; }
    public ProjectSyncState sync { get; set; }
    public int card_count { get; set; }
    public int root_card_count { get; set; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; set; }

    public Project(string project_id,
                   string name,
                   string privacy_mode,
                   string root_path,
                   int64 created_at,
                   int64 updated_at,
                   string? git_remote_url = null,
                   ProjectSyncState? sync = null,
                   int card_count = 0,
                   int root_card_count = 0) {
        Object(
            project_id: project_id,
            name: name,
            privacy_mode: privacy_mode,
            root_path: root_path,
            git_remote_url: git_remote_url,
            sync: sync ?? new ProjectSyncState(),
            card_count: card_count,
            root_card_count: root_card_count,
            created_at: created_at,
            updated_at: updated_at
        );
    }
}

public class ProjectSyncState : Object {
    public bool has_last_commit_at { get; set; }
    public int64 last_commit_at { get; set; }
    public bool has_last_push_at { get; set; }
    public int64 last_push_at { get; set; }
    public bool has_last_pull_at { get; set; }
    public int64 last_pull_at { get; set; }
    public int uncommitted_changes_count { get; set; }
    public int unpushed_commits_count { get; set; }
    public string last_push_status { get; set; }
    public string last_pull_status { get; set; }
    public string last_sync_error { get; set; }
    public bool has_last_sync_error_at { get; set; }
    public int64 last_sync_error_at { get; set; }
    public int retry_count { get; set; }
    public bool has_next_retry_at { get; set; }
    public int64 next_retry_at { get; set; }
    public int pull_retry_count { get; set; }
    public bool has_next_pull_retry_at { get; set; }
    public int64 next_pull_retry_at { get; set; }
    public bool has_updated_at { get; set; }
    public int64 updated_at { get; set; }

    public ProjectSyncState(int64? last_commit_at = null,
                            int64? last_push_at = null,
                            int64? last_pull_at = null,
                            int uncommitted_changes_count = 0,
                            int unpushed_commits_count = 0,
                            string last_push_status = "",
                            string last_pull_status = "",
                            string last_sync_error = "",
                            int64? last_sync_error_at = null,
                            int retry_count = 0,
                            int64? next_retry_at = null,
                            int pull_retry_count = 0,
                            int64? next_pull_retry_at = null,
                            int64? updated_at = null) {
        this.has_last_commit_at = last_commit_at != null;
        this.last_commit_at = last_commit_at ?? 0;
        this.has_last_push_at = last_push_at != null;
        this.last_push_at = last_push_at ?? 0;
        this.has_last_pull_at = last_pull_at != null;
        this.last_pull_at = last_pull_at ?? 0;
        this.uncommitted_changes_count = uncommitted_changes_count;
        this.unpushed_commits_count = unpushed_commits_count;
        this.last_push_status = last_push_status;
        this.last_pull_status = last_pull_status;
        this.last_sync_error = last_sync_error;
        this.has_last_sync_error_at = last_sync_error_at != null;
        this.last_sync_error_at = last_sync_error_at ?? 0;
        this.retry_count = retry_count;
        this.has_next_retry_at = next_retry_at != null;
        this.next_retry_at = next_retry_at ?? 0;
        this.pull_retry_count = pull_retry_count;
        this.has_next_pull_retry_at = next_pull_retry_at != null;
        this.next_pull_retry_at = next_pull_retry_at ?? 0;
        this.has_updated_at = updated_at != null;
        this.updated_at = updated_at ?? 0;
    }
}

public class ProjectResource : Object {
    public string resource_id { get; construct; }
    public string project_id { get; construct; }
    public string resource_type { get; set; }
    public string label { get; set; }
    public Gee.HashMap<string, Gee.ArrayList<string>> metadata { get; construct; }
    public Gee.ArrayList<ResourceAsset> assets { get; construct; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; set; }

    // Compatibility aliases keep the existing Resources controller/tests source-compatible while
    // the UI moves from pointer-shaped kind/URI/desc fields to the metadata model.
    public string kind {
        owned get { return resource_type; }
        set { resource_type = value; }
    }
    public string uri {
        owned get { return first_metadata_value("identifier"); }
        set { set_single_metadata_value("identifier", value); }
    }
    public string? desc {
        owned get {
            var value = first_metadata_value("description");
            return value.length > 0 ? value : null;
        }
        set { set_single_metadata_value("description", value ?? ""); }
    }

    public ProjectResource(string resource_id,
                           string project_id,
                           string kind,
                           string uri,
                           string label,
                           string? desc,
                           int64 created_at,
                           int64 updated_at,
                           Gee.HashMap<string, Gee.ArrayList<string>>? metadata = null,
                           Gee.ArrayList<ResourceAsset>? assets = null) {
        var actual_metadata = metadata ?? new Gee.HashMap<string, Gee.ArrayList<string>>();
        Object(
            resource_id: resource_id,
            project_id: project_id,
            resource_type: kind,
            label: label,
            metadata: actual_metadata,
            assets: assets ?? new Gee.ArrayList<ResourceAsset>(),
            created_at: created_at,
            updated_at: updated_at
        );
        if (metadata == null) {
            this.uri = uri;
            this.desc = desc;
        }
    }

    public string first_metadata_value(string key) {
        var values = metadata.get(key);
        return values != null && values.size > 0 ? values[0] : "";
    }

    private void set_single_metadata_value(string key, string value) {
        if (value.strip().length == 0) {
            metadata.unset(key);
            return;
        }
        var values = new Gee.ArrayList<string>();
        values.add(value);
        metadata.set(key, values);
    }
}

public class AssetPlacement : Object {
    public string placement_id { get; construct; }
    public string location_id { get; construct; }
    public string encoding { get; construct; }
    public int64 stored_byte_size { get; construct; }

    public AssetPlacement(string placement_id, string location_id, string encoding, int64 stored_byte_size) {
        Object(
            placement_id: placement_id,
            location_id: location_id,
            encoding: encoding,
            stored_byte_size: stored_byte_size
        );
    }
}

public class ResourceAsset : Object {
    public string asset_id { get; construct; }
    public string resource_id { get; construct; }
    public string original_filename { get; construct; }
    public string media_type { get; construct; }
    public int64 byte_size { get; construct; }
    public Gee.ArrayList<AssetPlacement> placements { get; construct; }

    public ResourceAsset(string asset_id,
                         string resource_id,
                         string original_filename,
                         string media_type,
                         int64 byte_size,
                         Gee.ArrayList<AssetPlacement>? placements = null) {
        Object(
            asset_id: asset_id,
            resource_id: resource_id,
            original_filename: original_filename,
            media_type: media_type,
            byte_size: byte_size,
            placements: placements ?? new Gee.ArrayList<AssetPlacement>()
        );
    }
}

public class StorageLocation : Object {
    public string location_id { get; construct; }
    public string project_id { get; construct; }
    public string name { get; construct; }
    public string provider { get; construct; }
    public Gee.HashMap<string, string> configuration { get; construct; }
    public bool bound { get; construct; }
    public string? binding_preview { get; construct; }

    public StorageLocation(string location_id,
                           string project_id,
                           string name,
                           string provider,
                           Gee.HashMap<string, string>? configuration = null,
                           bool bound = false,
                           string? binding_preview = null) {
        Object(
            location_id: location_id,
            project_id: project_id,
            name: name,
            provider: provider,
            configuration: configuration ?? new Gee.HashMap<string, string>(),
            bound: bound,
            binding_preview: binding_preview
        );
    }
}

public class StorageLocationList : Object {
    public Gee.ArrayList<StorageLocation> locations { get; construct; }
    public string? preferred_location_id { get; construct; }

    public StorageLocationList(Gee.ArrayList<StorageLocation> locations, string? preferred_location_id) {
        Object(locations: locations, preferred_location_id: preferred_location_id);
    }
}

public class AssetImportJob : Object {
    public string job_id { get; construct; }
    public string status { get; construct; }
    public string? resource_id { get; construct; }
    public string? asset_id { get; construct; }
    public string? error { get; construct; }

    public AssetImportJob(string job_id,
                          string status,
                          string? resource_id = null,
                          string? asset_id = null,
                          string? error = null) {
        Object(
            job_id: job_id,
            status: status,
            resource_id: resource_id,
            asset_id: asset_id,
            error: error
        );
    }
}

public class TrashItem : Object {
    public string item_type { get; construct; }
    public string item_id { get; construct; }
    public string title { get; construct; }
    public int64 deleted_at { get; construct; }

    public TrashItem(string item_type,
                     string item_id,
                     string title,
                     int64 deleted_at) {
        Object(
            item_type: item_type,
            item_id: item_id,
            title: title,
            deleted_at: deleted_at
        );
    }
}

}
