namespace HolderLinux {

public class ResourcesService : Object {
    public async Gee.ArrayList<ProjectResource> list_resources(IHolderApi api,
                                                               string project_id) throws Error {
        return yield api.list_resources(project_id);
    }

    public async void create_resource(IHolderApi api,
                                      string project_id,
                                      string kind,
                                      string uri,
                                      string label,
                                      string? desc,
                                      Gee.HashMap<string, Gee.ArrayList<string>>? extra_metadata = null) throws Error {
        yield api.create_resource(project_id, kind, uri, label, desc, extra_metadata);
    }

    public async void update_resource(IHolderApi api,
                                      string resource_id,
                                      string kind,
                                      string uri,
                                      string label,
                                      string? desc,
                                      Gee.HashMap<string, Gee.ArrayList<string>>? extra_metadata = null) throws Error {
        var now = new DateTime.now_utc().to_unix();
        yield api.update_resource(resource_id, kind, uri, label, desc, now, extra_metadata);
    }

    public async void delete_resource(IHolderApi api, string resource_id) throws Error {
        yield api.delete_resource(resource_id);
    }
}

}
