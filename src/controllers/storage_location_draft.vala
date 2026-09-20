namespace HolderLinux {

public class StorageLocationSpec : Object {
    public string provider { get; construct; }
    public Gee.HashMap<string, string> configuration { get; construct; }
    public Gee.HashMap<string, string> values { get; construct; }
    public string preview { get; construct; }

    public StorageLocationSpec(string provider,
                               Gee.HashMap<string, string> configuration,
                               Gee.HashMap<string, string> values,
                               string preview) {
        Object(provider: provider, configuration: configuration, values: values, preview: preview);
    }
}

public class StorageLocationDraft : Object {
    private bool s3_compatible;
    private string name;
    private string path;
    private string endpoint;
    private string region;
    private string bucket;
    private string prefix;
    private string access_key;
    private string secret_key;
    private string session_token;

    public StorageLocationDraft(bool s3_compatible,
                                string name,
                                string path,
                                string endpoint,
                                string region,
                                string bucket,
                                string prefix,
                                string access_key,
                                string secret_key,
                                string session_token) {
        this.s3_compatible = s3_compatible;
        this.name = name;
        this.path = path;
        this.endpoint = endpoint;
        this.region = region;
        this.bucket = bucket;
        this.prefix = prefix;
        this.access_key = access_key;
        this.secret_key = secret_key;
        this.session_token = session_token;
    }

    public string location_name {
        owned get { return name.strip(); }
    }

    public bool can_save() {
        return validation_error() == null;
    }

    public string? validation_error() {
        if (name.strip().length == 0) {
            return "A storage location name is required.";
        }
        if (s3_compatible) {
            if (endpoint.strip().length == 0 ||
                region.strip().length == 0 ||
                bucket.strip().length == 0 ||
                access_key.strip().length == 0 ||
                secret_key.length == 0) {
                return "Endpoint, region, bucket and credentials are required.";
            }
            return null;
        }
        if (path.strip().length == 0) {
            return "Choose a storage folder.";
        }
        return null;
    }

    public StorageLocationSpec build_spec() {
        var configuration = new Gee.HashMap<string, string>();
        var values = new Gee.HashMap<string, string>();
        if (s3_compatible) {
            configuration.set("endpoint", endpoint.strip());
            configuration.set("region", region.strip());
            configuration.set("bucket", bucket.strip());
            configuration.set("prefix", prefix.strip());
            configuration.set("addressing_style", "path");
            values.set("access_key_id", access_key.strip());
            values.set("secret_access_key", secret_key);
            if (session_token.length > 0) {
                values.set("session_token", session_token);
            }
            return new StorageLocationSpec(
                "s3_compatible",
                configuration,
                values,
                "%s / %s".printf(endpoint.strip(), bucket.strip())
            );
        }
        values.set("root_path", path.strip());
        return new StorageLocationSpec("local_directory", configuration, values, path.strip());
    }
}

}
