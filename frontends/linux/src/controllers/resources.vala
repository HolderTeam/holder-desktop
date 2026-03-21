namespace HolderLinux {

public class ResourcesRefreshResult : Object {
    public bool success { get; construct; }
    public bool has_error { get; construct; }
    public Gee.ArrayList<ProjectResource> resources { get; construct; }
    public string empty_text { get; construct; }
    public string error_title { get; construct; }
    public string error_details { get; construct; }

    public ResourcesRefreshResult(bool success,
                                  bool has_error = false,
                                  Gee.ArrayList<ProjectResource>? resources = null,
                                  string empty_text = "",
                                  string error_title = "",
                                  string error_details = "") {
        Object(
            success: success,
            has_error: has_error,
            resources: resources ?? new Gee.ArrayList<ProjectResource>(),
            empty_text: empty_text,
            error_title: error_title,
            error_details: error_details
        );
    }
}

public class ResourcesFilterResult : Object {
    public Gee.ArrayList<ProjectResource> filtered { get; construct; }
    public bool empty { get; construct; }
    public string empty_text { get; construct; }

    public ResourcesFilterResult(Gee.ArrayList<ProjectResource> filtered,
                                 bool empty,
                                 string empty_text = "") {
        Object(filtered: filtered, empty: empty, empty_text: empty_text);
    }
}

public class ResourcesMutationResult : Object {
    public bool success { get; construct; }
    public bool ignored { get; construct; }
    public bool should_refresh { get; construct; }
    public string toast_message { get; construct; }
    public string error_title { get; construct; }
    public string error_details { get; construct; }

    public ResourcesMutationResult(bool success,
                                   bool ignored = false,
                                   bool should_refresh = false,
                                   string toast_message = "",
                                   string error_title = "",
                                   string error_details = "") {
        Object(
            success: success,
            ignored: ignored,
            should_refresh: should_refresh,
            toast_message: toast_message,
            error_title: error_title,
            error_details: error_details
        );
    }
}

public class ResourcesController : Object {
    private ResourcesService service;
    internal int ellipsize_cutoff_override_for_tests = -1;

    public signal void activity_requested(string kind,
                                          string message,
                                          string? project_id,
                                          string? resource_id,
                                          ActivityDetails? details);

    public ResourcesController(ResourcesService? service = null) {
        this.service = service ?? new ResourcesService();
    }

    public async Gee.ArrayList<ProjectResource> list_resources(IHolderApi api,
                                                               string project_id) throws Error {
        return yield service.list_resources(api, project_id);
    }

    public async void create_resource(IHolderApi api,
                                      string project_id,
                                      string kind,
                                      string uri,
                                      string label,
                                      string? desc) throws Error {
        yield service.create_resource(api, project_id, kind, uri, label, desc);
    }

    public async void update_resource(IHolderApi api,
                                      string resource_id,
                                      string kind,
                                      string uri,
                                      string label,
                                      string? desc) throws Error {
        yield service.update_resource(api, resource_id, kind, uri, label, desc);
    }

    public async void delete_resource(IHolderApi api, string resource_id) throws Error {
        yield service.delete_resource(api, resource_id);
    }

    public string format_epoch(int64 epoch) {
        if (epoch <= 0) {
            return "";
        }
        var dt = new DateTime.from_unix_local(epoch);
        return dt.format("%Y-%m-%d %H:%M");
    }

    public string ellipsize_title(string? title) {
        if (title == null) {
            return "";
        }
        if (title.char_count() < 47) {
            return title;
        }
        int cutoff_chars = ellipsize_cutoff_override_for_tests >= 0
            ? ellipsize_cutoff_override_for_tests
            : 44;
        int cutoff = title.index_of_nth_char(cutoff_chars);
        if (cutoff < 0 || cutoff > title.length) {
            return title;
        }
        return title.substring(0, cutoff) + "...";
    }

    public Gee.ArrayList<ProjectResource> filter_resources(Gee.ArrayList<ProjectResource> all_resources,
                                                           string query_text) {
        var filtered = new Gee.ArrayList<ProjectResource>();
        var query = query_text.strip().down();
        foreach (var resource in all_resources) {
            if (query.length > 0) {
                var haystack = "%s %s %s %s".printf(
                    resource.label,
                    resource.kind,
                    resource.uri,
                    resource.desc ?? ""
                ).down();
                if (!haystack.contains(query)) {
                    continue;
                }
            }
            filtered.add(resource);
        }
        return filtered;
    }

    public string[] default_resource_kinds() {
        return {"url", "file", "dir", "repo", "image"};
    }

    public async ResourcesRefreshResult refresh_resources_flow(IHolderApi? api, Project? project) {
        if (project == null) {
            return new ResourcesRefreshResult(false, false, null, "Select a project to view resources.");
        }
        if (api == null) {
            return new ResourcesRefreshResult(false, false, null, "API unavailable.");
        }

        try {
            var resources = yield list_resources(api, project.project_id);
            return new ResourcesRefreshResult(true, false, resources);
        } catch (Error e) {
            return new ResourcesRefreshResult(
                false,
                true,
                null,
                "Failed to load resources.",
                "Resources refresh failed",
                e.message
            );
        }
    }

    public ResourcesFilterResult apply_resources_filter_flow(Gee.ArrayList<ProjectResource> all_resources,
                                                             string query_text) {
        var filtered = filter_resources(all_resources, query_text);
        var is_empty = filtered.size == 0;
        var empty_text = "";
        if (is_empty) {
            empty_text = query_text.strip().length > 0
                ? "No resources match this filter."
                : "No resources in this project.";
        }
        return new ResourcesFilterResult(filtered, is_empty, empty_text);
    }

    public async ResourcesMutationResult create_resource_flow(IHolderApi? api,
                                                              string project_id,
                                                              string kind,
                                                              string uri,
                                                              string label,
                                                              string? desc) {
        if (api == null) {
            return new ResourcesMutationResult(false, true);
        }
        try {
            yield create_resource(api, project_id, kind, uri, label, desc);
            activity_requested(
                "result.resource.create",
                "Created resource: %s".printf(label),
                project_id,
                null,
                new ResourceChangedDetails("create", label)
            );
            return new ResourcesMutationResult(true, false, true, "Resource added.");
        } catch (Error e) {
            activity_requested(
                "result.resource.create_failed",
                "Failed to create resource: %s".printf(e.message),
                project_id,
                null,
                null
            );
            return new ResourcesMutationResult(
                false,
                false,
                false,
                "",
                "Failed to create resource",
                e.message
            );
        }
    }

    public async ResourcesMutationResult update_resource_flow(IHolderApi? api,
                                                              string resource_id,
                                                              string kind,
                                                              string uri,
                                                              string label,
                                                              string? desc) {
        return yield update_resource_flow_scoped(api, resource_id, null, kind, uri, label, desc);
    }

    public async ResourcesMutationResult update_resource_flow_scoped(IHolderApi? api,
                                                                     string resource_id,
                                                                     string? project_id,
                                                                     string kind,
                                                                     string uri,
                                                                     string label,
                                                                     string? desc) {
        if (api == null) {
            return new ResourcesMutationResult(false, true);
        }
        try {
            yield update_resource(api, resource_id, kind, uri, label, desc);
            activity_requested(
                "result.resource.update",
                "Updated resource: %s".printf(label),
                project_id,
                resource_id,
                new ResourceChangedDetails("update", label)
            );
            return new ResourcesMutationResult(true, false, true, "Resource updated.");
        } catch (Error e) {
            activity_requested(
                "result.resource.update_failed",
                "Failed to update resource: %s".printf(e.message),
                project_id,
                resource_id,
                null
            );
            return new ResourcesMutationResult(
                false,
                false,
                false,
                "",
                "Failed to update resource",
                e.message
            );
        }
    }

    public async ResourcesMutationResult delete_resource_flow(IHolderApi? api,
                                                              string resource_id) {
        return yield delete_resource_flow_scoped(api, resource_id, null, "resource");
    }

    public async ResourcesMutationResult delete_resource_flow_scoped(IHolderApi? api,
                                                                     string resource_id,
                                                                     string? project_id,
                                                                     string resource_label = "resource") {
        if (api == null) {
            return new ResourcesMutationResult(false, true);
        }
        try {
            yield delete_resource(api, resource_id);
            activity_requested(
                "result.resource.delete",
                "Deleted resource: %s".printf(resource_label),
                project_id,
                resource_id,
                new ResourceChangedDetails("delete", resource_label)
            );
            return new ResourcesMutationResult(true, false, true, "Resource deleted.");
        } catch (Error e) {
            activity_requested(
                "result.resource.delete_failed",
                "Failed to delete resource: %s".printf(e.message),
                project_id,
                resource_id,
                null
            );
            return new ResourcesMutationResult(
                false,
                false,
                false,
                "",
                "Failed to delete resource",
                e.message
            );
        }
    }
}

}
