namespace HolderLinux {

// Validated input for creating or updating a manual model runner.
public class AiRunnerDraft : Object {
    public const string REQUIRED_MESSAGE = "Runner name and base URL are required.";

    public string name { get; construct; }
    public string base_url { get; construct; }

    public bool valid {
        get { return name.length > 0 && base_url.length > 0; }
    }

    public string? error_message {
        get { return valid ? null : REQUIRED_MESSAGE; }
    }

    public AiRunnerDraft(string name, string base_url) {
        Object(name: name.strip(), base_url: base_url.strip());
    }
}

// Validated input for saving a cloud provider's API key.
public class AiProviderKeyDraft : Object {
    public const string EMPTY_MESSAGE = "API key cannot be empty.";

    public string key { get; construct; }

    public bool valid {
        get { return key.length > 0; }
    }

    public string? error_message {
        get { return valid ? null : EMPTY_MESSAGE; }
    }

    public AiProviderKeyDraft(string raw_key) {
        Object(key: raw_key.strip());
    }
}

}
