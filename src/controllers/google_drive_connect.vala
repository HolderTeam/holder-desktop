namespace HolderLinux {

public enum GoogleDriveConnectOutcome {
    CONNECTED,
    CANCELLED,
    TIMED_OUT,
    FAILED
}

public class GoogleDriveConnectResult : Object {
    public GoogleDriveConnectOutcome outcome { get; construct; }
    public string toast_message { get; construct; }
    public string error_title { get; construct; }
    public string error_details { get; construct; }

    public GoogleDriveConnectResult(GoogleDriveConnectOutcome outcome,
                                    string toast_message = "",
                                    string error_title = "",
                                    string error_details = "") {
        Object(
            outcome: outcome,
            toast_message: toast_message,
            error_title: error_title,
            error_details: error_details
        );
    }
}

public class GoogleDriveConnectFlow : Object {
    // Matches the daemon's own pending-attempt TTL (10 minutes) at roughly a 1s poll
    // interval, generous for "switch to a browser tab and sign in."
    public const int MAX_POLL_ATTEMPTS = 600;
    public const uint POLL_INTERVAL_MS = 1000;

    private IResourceStorageApi storage_api;
    private IUriLauncher uri_launcher;
    private IScheduler scheduler;
    private PreferredLocationLookup preferred_lookup;
    private bool cancelled = false;

    public signal void status_changed(string text);

    public GoogleDriveConnectFlow(IResourceStorageApi storage_api,
                                  IUriLauncher uri_launcher,
                                  IScheduler scheduler,
                                  owned PreferredLocationLookup preferred_lookup) {
        this.storage_api = storage_api;
        this.uri_launcher = uri_launcher;
        this.scheduler = scheduler;
        this.preferred_lookup = (owned) preferred_lookup;
    }

    public void cancel() {
        cancelled = true;
    }

    public async GoogleDriveConnectResult run(string project_id) {
        try {
            var locations = yield storage_api.list_storage_locations(project_id);
            var location_id = find_unbound_google_drive_location_id(locations);
            if (location_id == null) {
                location_id = yield storage_api.create_storage_location(
                    project_id, "Google Drive", "google-drive", new Gee.HashMap<string, string>()
                );
            }
            if (cancelled) {
                return new GoogleDriveConnectResult(GoogleDriveConnectOutcome.CANCELLED);
            }

            status_changed("Opening your browser…");
            var authorization_url = yield storage_api.start_google_drive_oauth(location_id);
            if (cancelled) {
                return new GoogleDriveConnectResult(GoogleDriveConnectOutcome.CANCELLED);
            }

            uri_launcher.launch(authorization_url);
            status_changed("Waiting for you to finish in your browser…");

            for (int attempt = 0; attempt < MAX_POLL_ATTEMPTS && !cancelled; attempt++) {
                yield wait_for_poll();
                if (cancelled) {
                    return new GoogleDriveConnectResult(GoogleDriveConnectOutcome.CANCELLED);
                }
                var refreshed = yield storage_api.list_storage_locations(project_id);
                if (location_is_bound(refreshed, location_id)) {
                    if (preferred_lookup() == null) {
                        yield storage_api.prefer_storage_location(project_id, location_id);
                    }
                    return new GoogleDriveConnectResult(
                        GoogleDriveConnectOutcome.CONNECTED, "Google Drive connected."
                    );
                }
            }
            if (cancelled) {
                return new GoogleDriveConnectResult(GoogleDriveConnectOutcome.CANCELLED);
            }
            return new GoogleDriveConnectResult(
                GoogleDriveConnectOutcome.TIMED_OUT,
                "",
                "Google Drive connection timed out",
                "Try connecting again from the Resources tool."
            );
        } catch (Error e) {
            if (cancelled) {
                return new GoogleDriveConnectResult(GoogleDriveConnectOutcome.CANCELLED);
            }
            return new GoogleDriveConnectResult(
                GoogleDriveConnectOutcome.FAILED, "", "Failed to connect Google Drive", e.message
            );
        }
    }

    // Finds an existing unbound "google-drive" Location for reuse -- so retrying a
    // cancelled or failed connect attempt doesn't leave duplicate "Configuration
    // required" rows behind. Deliberately doesn't match an already-bound one: clicking
    // "Add Google Drive" again when one's already connected should offer to connect a
    // second account, not silently reuse the first (desktop has no equivalent of
    // Android's one-account-per-device limitation -- see GoogleDriveProvider's own doc
    // comment in holder-daemon).
    internal static string? find_unbound_google_drive_location_id(StorageLocationList locations) {
        foreach (var location in locations.locations) {
            if (location.provider == "google-drive" && !location.bound) {
                return location.location_id;
            }
        }
        return null;
    }

    internal static bool location_is_bound(StorageLocationList locations, string location_id) {
        foreach (var location in locations.locations) {
            if (location.location_id == location_id) return location.bound;
        }
        return false;
    }

    private async void wait_for_poll() {
        scheduler.schedule_once(POLL_INTERVAL_MS, () => {
            wait_for_poll.callback();
            return Source.REMOVE;
        });
        yield;
    }
}

}
