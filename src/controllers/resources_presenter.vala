namespace HolderLinux {

public class ResourceCellPresentation : Object {
    public string text { get; construct; }
    public string? tooltip { get; construct; }

    public ResourceCellPresentation(string text, string? tooltip) {
        Object(text: text, tooltip: tooltip);
    }
}

public class ResourceUsagePresentation : Object {
    public Gee.ArrayList<ResourceCardReference> visible_references { get; construct; }
    public int remaining_count { get; construct; }
    public string overflow_tooltip { get; construct; }

    public ResourceUsagePresentation(Gee.ArrayList<ResourceCardReference> visible_references,
                                     int remaining_count,
                                     string overflow_tooltip) {
        Object(
            visible_references: visible_references,
            remaining_count: remaining_count,
            overflow_tooltip: overflow_tooltip
        );
    }

    public bool is_unused {
        get { return visible_references.size == 0; }
    }

    public string overflow_label {
        owned get { return "+%d more".printf(remaining_count); }
    }
}

public enum ResourceOpenKind {
    PREVIEW_ASSET,
    TOAST,
    LAUNCH_URI
}

public class ResourceOpenAction : Object {
    public ResourceOpenKind kind { get; construct; }
    public ResourceAsset? asset { get; construct; }
    public string text { get; construct; }

    public ResourceOpenAction(ResourceOpenKind kind, ResourceAsset? asset, string text) {
        Object(kind: kind, asset: asset, text: text);
    }
}

public class ResourcesPresenter { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public static ResourceCellPresentation cell(ResourcesController controller,
                                                ProjectResource resource,
                                                string field) {
        switch (field) {
            case "label":
                return new ResourceCellPresentation(controller.ellipsize_title(resource.label), resource.label);
            case "kind":
                return new ResourceCellPresentation(resource.kind, resource.kind);
            case "uri":
                return new ResourceCellPresentation(controller.ellipsize_title(resource.uri), resource.uri);
            case "assets":
                return new ResourceCellPresentation(
                    resource.assets.size.to_string(),
                    resource.assets.size == 1 ? "1 attached asset" : "%d attached assets".printf(resource.assets.size)
                );
            case "desc":
                var desc = resource.desc ?? "";
                return new ResourceCellPresentation(controller.ellipsize_title(desc), desc);
            case "updated":
                return new ResourceCellPresentation(
                    controller.format_epoch(resource.updated_at),
                    resource.updated_at.to_string()
                );
            default:
                return new ResourceCellPresentation("", null);
        }
    }

    public static ResourceUsagePresentation usage(ProjectResource resource) {
        var references = resource.referenced_by_cards;
        var visible = new Gee.ArrayList<ResourceCardReference>();
        int visible_count = int.min(references.size, 2);
        if (references.size > 2) {
            visible_count = 1;
        }
        for (int index = 0; index < visible_count; index++) {
            visible.add(references[index]);
        }
        return new ResourceUsagePresentation(
            visible,
            references.size - visible_count,
            all_reference_titles(resource)
        );
    }

    public static string reference_tooltip(ResourceCardReference reference) {
        if (reference.link_kinds.size == 0) {
            return reference.title;
        }
        var kinds = new Gee.ArrayList<string>();
        foreach (var kind in reference.link_kinds) {
            kinds.add(friendly_link_kind(kind));
        }
        return "%s · %s".printf(reference.title, join_parts(", ", kinds));
    }

    public static string all_reference_titles(ProjectResource resource) {
        var titles = new Gee.ArrayList<string>();
        foreach (var reference in resource.referenced_by_cards) {
            titles.add(reference.title);
        }
        return join_parts("\n", titles);
    }

    public static string friendly_link_kind(string kind) {
        switch (kind) {
            case "attachment":
                return "Attachment";
            case "reference":
                return "Reference";
            default:
                if (kind.length == 0) {
                    return "Linked";
                }
                return kind.substring(0, 1).up() + kind.substring(1).replace("_", " ");
        }
    }

    public static ResourceOpenAction open_action(ProjectResource resource) {
        if (resource.assets.size > 0) {
            return new ResourceOpenAction(ResourceOpenKind.PREVIEW_ASSET, resource.assets[0], "");
        }
        if (resource.uri.strip().length == 0) {
            return new ResourceOpenAction(
                ResourceOpenKind.TOAST, null, "This Resource has no Asset or identifier to open."
            );
        }
        return new ResourceOpenAction(ResourceOpenKind.LAUNCH_URI, null, resource.uri);
    }

    public static string? picked_file_label(string current_label, string? basename) {
        if (current_label.strip().length == 0 && basename != null && basename.length > 0) {
            return basename;
        }
        return null;
    }

    private static string join_parts(string separator, Gee.List<string> parts) {
        var joined = new StringBuilder();
        bool first = true;
        foreach (var part in parts) {
            if (!first) {
                joined.append(separator);
            }
            joined.append(part);
            first = false;
        }
        return joined.str;
    }
}

}
