namespace HolderLinux {

public class CardAttachment : Object {
    public string card_id { get; construct; }
    public ProjectResource resource { get; construct; }
    public ResourceAsset asset { get; construct; }

    public CardAttachment(string card_id, ProjectResource resource, ResourceAsset asset) {
        Object(card_id: card_id, resource: resource, asset: asset);
    }
}

public class AssetPreviewController : Object {
    private uint refresh_serial = 0;

    public signal void attachments_loaded(Gee.ArrayList<CardAttachment> attachments);
    public signal void load_failed(string message);

    public async void refresh_card_attachments(IHolderApi? api,
                                               string? project_id,
                                               string? card_id) {
        var serial = ++refresh_serial;
        if (api == null || project_id == null || card_id == null) {
            attachments_loaded(new Gee.ArrayList<CardAttachment>());
            return;
        }
        try {
            var links = yield api.list_card_links(card_id);
            var resources = yield api.list_resources(project_id);
            if (serial != refresh_serial) {
                return;
            }
            attachments_loaded(resolve_attachments(card_id, links, resources));
        } catch (Error e) {
            if (serial == refresh_serial) {
                load_failed(e.message);
            }
        }
    }

    public static Gee.ArrayList<CardAttachment> resolve_attachments(
        string card_id,
        Gee.ArrayList<CardLink> links,
        Gee.ArrayList<ProjectResource> resources
    ) {
        var resource_by_id = new Gee.HashMap<string, ProjectResource>();
        foreach (var resource in resources) {
            resource_by_id.set(resource.resource_id, resource);
        }
        var attachments = new Gee.ArrayList<CardAttachment>();
        foreach (var link in links) {
            if (link.to_type != "resource" || link.kind != "attachment") {
                continue;
            }
            var resource = resource_by_id.get(link.to_card_id);
            if (resource == null) {
                continue;
            }
            foreach (var asset in resource.assets) {
                attachments.add(new CardAttachment(card_id, resource, asset));
            }
        }
        attachments.sort((left, right) => {
            return strcmp(left.asset.original_filename.down(), right.asset.original_filename.down());
        });
        return attachments;
    }

    public static string import_completion_message(AssetImportJob job) {
        if (job.duplicate_reused && !job.link_created) {
            return "Already attached — existing Asset reused.";
        }
        if (job.duplicate_reused) {
            return "Existing Asset attached to this Card.";
        }
        return "Asset imported and attached to this Card.";
    }
}

}
