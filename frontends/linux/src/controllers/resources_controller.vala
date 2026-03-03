namespace HolderLinux {

public class ResourcesController : Object {
    private ResourcesService service;

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

    public string ellipsize_title(string title) {
        if (title == null) {
            return "";
        }
        if (title.char_count() < 47) {
            return title;
        }
        int cutoff = title.index_of_nth_char(44);
        if (cutoff < 0) {
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
}

}
