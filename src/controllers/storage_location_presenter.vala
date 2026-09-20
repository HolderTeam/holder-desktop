namespace HolderLinux {

public class StorageLocationRowPresentation : Object {
    public string title { get; construct; }
    public string summary { get; construct; }
    public bool is_preferred { get; construct; }
    public bool offers_use_by_default { get; construct; }
    public bool test_enabled { get; construct; }

    public StorageLocationRowPresentation(string title,
                                          string summary,
                                          bool is_preferred,
                                          bool offers_use_by_default,
                                          bool test_enabled) {
        Object(
            title: title,
            summary: summary,
            is_preferred: is_preferred,
            offers_use_by_default: offers_use_by_default,
            test_enabled: test_enabled
        );
    }
}

public class StorageLocationPresenter {
    public static string provider_label(string provider) {
        switch (provider) {
            case "local_directory":
                return "Local folder";
            case "google-drive":
                return "Google Drive";
            default:
                return "S3-compatible storage";
        }
    }

    public static StorageLocationRowPresentation row(StorageLocation location,
                                                     string? preferred_location_id) {
        var summary = provider_label(location.provider);
        if (location.binding_preview != null) {
            summary += " · " + (!) location.binding_preview;
        } else {
            summary += " · Configuration required";
        }
        var is_preferred = preferred_location_id == location.location_id;
        return new StorageLocationRowPresentation(
            location.name,
            summary,
            is_preferred,
            !is_preferred && location.bound,
            location.bound
        );
    }
}

}
