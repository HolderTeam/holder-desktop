namespace HolderLinux {

public class ResourceKindSelection : Object {
    public uint index { get; construct; }
    public string custom_text { get; construct; }

    public ResourceKindSelection(uint index, string custom_text) {
        Object(index: index, custom_text: custom_text);
    }
}

public class ResourceDialogSaveState : Object {
    public bool enabled { get; construct; }
    public string? error_message { get; construct; }

    public ResourceDialogSaveState(bool enabled, string? error_message) {
        Object(enabled: enabled, error_message: error_message);
    }
}

public class ResourceDraftResult : Object {
    public string? error_message { get; construct; }
    public string kind { get; construct; }
    public string uri { get; construct; }
    public string label { get; construct; }
    public string? desc { get; construct; }
    public Gee.HashMap<string, Gee.ArrayList<string>> extra_metadata { get; construct; }

    public ResourceDraftResult(string? error_message,
                               string kind,
                               string uri,
                               string label,
                               string? desc,
                               Gee.HashMap<string, Gee.ArrayList<string>>? extra_metadata) {
        Object(
            error_message: error_message,
            kind: kind,
            uri: uri,
            label: label,
            desc: desc,
            extra_metadata: extra_metadata ?? new Gee.HashMap<string, Gee.ArrayList<string>>()
        );
    }
}

public class ResourceDraft {
    public const string CUSTOM_KIND_OPTION = "custom";
    public const string DEFAULT_KIND = "thing";

    public static string[] kind_options(ResourcesController controller) {
        string[] options = {};
        foreach (var kind in controller.default_resource_kinds()) {
            options += kind;
        }
        options += CUSTOM_KIND_OPTION;
        return options;
    }

    public static ResourceKindSelection select_kind(string[] options, ProjectResource? existing) {
        if (existing == null) {
            return new ResourceKindSelection(0, "");
        }
        for (int i = 0; i < options.length; i++) {
            if (options[i] == existing.kind) {
                return new ResourceKindSelection((uint) i, "");
            }
        }
        return new ResourceKindSelection(options.length - 1, existing.kind);
    }

    public static string resolve_kind(string[] options, uint selected_index, string custom_text) {
        if (selected_index < options.length - 1) {
            return options[selected_index];
        }
        var custom = custom_text.strip();
        return custom.length > 0 ? custom : DEFAULT_KIND;
    }

    public static ResourceDialogSaveState save_state(ResourcesController controller,
                                                     string label,
                                                     string details_text) {
        if (label.strip().length == 0) {
            return new ResourceDialogSaveState(false, null);
        }
        try {
            controller.parse_additional_metadata(details_text);
            return new ResourceDialogSaveState(true, null);
        } catch (Error e) {
            return new ResourceDialogSaveState(false, e.message);
        }
    }

    public static ResourceDraftResult build(ResourcesController controller,
                                            ProjectResource? existing,
                                            string kind,
                                            string uri_text,
                                            string label_text,
                                            string description_text,
                                            string details_text) {
        var uri = uri_text.strip();
        var label = label_text.strip();
        var desc_raw = description_text.strip();
        if (label.length == 0) {
            return new ResourceDraftResult(
                "A label is required.", kind, uri, label, null, null
            );
        }
        var desc = desc_raw.length > 0 ? desc_raw : null;
        Gee.HashMap<string, Gee.ArrayList<string>> extra_metadata;
        try {
            extra_metadata = controller.parse_additional_metadata(details_text);
        } catch (Error e) {
            return new ResourceDraftResult(e.message, kind, uri, label, desc, null);
        }
        if (existing != null) {
            foreach (var entry in existing.metadata.entries) {
                if (entry.key != "identifier" && entry.key != "description" &&
                    !extra_metadata.has_key(entry.key)) {
                    extra_metadata.set(entry.key, new Gee.ArrayList<string>());
                }
            }
        }
        return new ResourceDraftResult(null, kind, uri, label, desc, extra_metadata);
    }
}

}
