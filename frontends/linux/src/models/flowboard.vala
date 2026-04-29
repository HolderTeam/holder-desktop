namespace HolderLinux {

public class FlowboardTile : Object {
    public string node_key { get; construct; }
    public string title { get; construct; }
    public int64 updated_at { get; construct; }
    public bool is_container { get; construct; }
    public string? card_id { get; construct; }
    public string? project_id { get; construct; }
    public string? parent_card_id { get; construct; }
    public int sibling_count { get; construct; }
    public int sibling_index { get; construct; }
    public int child_count { get; construct; }

    public FlowboardTile(string node_key,
                         string title,
                         int64 updated_at,
                         bool is_container,
                         string? card_id = null,
                         string? project_id = null,
                         string? parent_card_id = null,
                         int sibling_count = 0,
                         int sibling_index = 0,
                         int child_count = 0) {
        Object(
            node_key: node_key,
            title: title,
            updated_at: updated_at,
            is_container: is_container,
            card_id: card_id,
            project_id: project_id,
            parent_card_id: parent_card_id,
            sibling_count: sibling_count,
            sibling_index: sibling_index,
            child_count: child_count
        );
    }
}

public class FlowboardBreadcrumbSegment : Object {
    public string label { get; construct; }

    public FlowboardBreadcrumbSegment(string label) {
        Object(label: label);
    }
}

}
