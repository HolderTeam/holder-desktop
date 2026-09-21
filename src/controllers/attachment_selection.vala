namespace HolderLinux {

public class AttachmentApplyResult : Object {
    public int selected_index { get; construct; }
    public int display_index { get; construct; }
    public bool has_selection { get; construct; }
    public bool reveal_preview { get; construct; }

    public AttachmentApplyResult(int selected_index, bool reveal_preview) {
        Object(
            selected_index: selected_index,
            display_index: selected_index < 0 ? 0 : selected_index,
            has_selection: selected_index >= 0,
            reveal_preview: reveal_preview && selected_index >= 0
        );
    }
}

public class AttachmentLoadTicket : Object {
    public int index { get; construct; }
    public uint serial { get; construct; }
    public CardAttachment attachment { get; construct; }

    public AttachmentLoadTicket(int index, uint serial, CardAttachment attachment) {
        Object(index: index, serial: serial, attachment: attachment);
    }
}

public class InlineImagePreviewTarget : Object {
    public ProjectResource resource { get; construct; }
    public ResourceAsset asset { get; construct; }

    public InlineImagePreviewTarget(ProjectResource resource, ResourceAsset asset) {
        Object(resource: resource, asset: asset);
    }
}

// Tracks which Asset attachment the preview pane is showing and guards stale async loads.
public class AttachmentSelection : Object {
    public const string NO_IMAGE_MESSAGE =
        "This Resource has no image available in the current project.";

    public Gee.ArrayList<CardAttachment> attachments { get; private set; }
    public int selected_index { get; private set; default = -1; }
    public string? pending_preview_asset_id { get; set; default = null; }
    public string? selected_cache_path { get; set; default = null; }
    private uint load_serial = 0;

    public AttachmentSelection() {
        attachments = new Gee.ArrayList<CardAttachment>();
    }

    public static bool is_image(CardAttachment attachment) {
        return attachment.asset.media_type.has_prefix("image/");
    }

    public static InlineImagePreviewTarget? find_inline_image(
        Gee.ArrayList<ProjectResource> resources,
        string resource_id
    ) {
        foreach (var resource in resources) {
            if (resource.resource_id != resource_id) {
                continue;
            }
            foreach (var asset in resource.assets) {
                if (asset.media_type.has_prefix("image/")) {
                    return new InlineImagePreviewTarget(resource, asset);
                }
            }
        }
        return null;
    }

    public CardAttachment? selected_attachment() {
        if (selected_index < 0 || selected_index >= attachments.size) {
            return null;
        }
        return attachments[selected_index];
    }

    public AttachmentApplyResult apply_attachments(Gee.ArrayList<CardAttachment> incoming) {
        var previous_asset_id = selected_index >= 0 && selected_index < attachments.size
            ? attachments[selected_index].asset.asset_id
            : null;
        attachments = incoming;
        var requested_asset_id = pending_preview_asset_id ?? previous_asset_id;
        pending_preview_asset_id = null;
        selected_index = attachments.size > 0 ? 0 : -1;
        if (requested_asset_id != null) {
            for (int i = 0; i < attachments.size; i++) {
                if (attachments[i].asset.asset_id == requested_asset_id) {
                    selected_index = i;
                    break;
                }
            }
        }
        return new AttachmentApplyResult(selected_index, requested_asset_id != null);
    }

    public void show_single(CardAttachment attachment) {
        var items = new Gee.ArrayList<CardAttachment>();
        items.add(attachment);
        attachments = items;
        selected_index = 0;
    }

    public AttachmentLoadTicket? begin_load(int index) {
        if (index < 0 || index >= attachments.size) {
            return null;
        }
        selected_index = index;
        selected_cache_path = null;
        return new AttachmentLoadTicket(index, ++load_serial, attachments[index]);
    }

    public bool is_load_current(AttachmentLoadTicket ticket) {
        return ticket.serial == load_serial && ticket.index == selected_index;
    }

    public bool is_error_current(AttachmentLoadTicket ticket) {
        return ticket.serial == load_serial;
    }
}

}
