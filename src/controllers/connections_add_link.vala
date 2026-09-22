namespace HolderLinux {

public class ConnectionsAddLinkRequest : Object {
    public string to_card_id { get; construct; }
    public string kind { get; construct; }
    public string? label { get; construct; }
    public bool remember_kind { get; construct; }

    public ConnectionsAddLinkRequest(string to_card_id,
                                     string kind,
                                     string? label,
                                     bool remember_kind) {
        Object(
            to_card_id: to_card_id,
            kind: kind,
            label: label,
            remember_kind: remember_kind
        );
    }
}

public class ConnectionsAddLinkPresenter { // LCOV_EXCL_LINE: declaration-only coverage artifact
    // Turns the Add Graph Connection dialog state into a request. The kind dropdown lists
    // available_kinds followed by a trailing "custom" entry.
    public static ConnectionsAddLinkRequest? resolve(Gee.List<string> target_ids,
                                                     uint target_index,
                                                     Gee.List<string> available_kinds,
                                                     int kind_index,
                                                     string custom_kind_text,
                                                     string label_text) {
        if (target_index >= target_ids.size) {
            return null;
        }
        string kind = "ref";
        bool remember_kind = false;
        if (kind_index >= 0 && kind_index < available_kinds.size) {
            var chosen = available_kinds[kind_index];
            if (chosen.length > 0) {
                kind = chosen;
            }
        } else {
            var custom_kind = custom_kind_text.strip();
            kind = custom_kind.length > 0 ? custom_kind : "ref";
            remember_kind = custom_kind.length > 0;
        }
        var link_label = label_text.strip();
        return new ConnectionsAddLinkRequest(
            target_ids[(int) target_index],
            kind,
            link_label.length > 0 ? link_label : null,
            remember_kind
        );
    }
}

}
