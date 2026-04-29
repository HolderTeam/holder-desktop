namespace HolderLinux {

public class CardContextProject : Object {
    public string project_id { get; construct; }
    public string name { get; construct; }

    public CardContextProject(string project_id, string name) {
        Object(
            project_id: project_id,
            name: name
        );
    }
}

public class CardContextBreadcrumb : Object {
    public string crumb_type { get; construct; }
    public string title { get; construct; }
    public string? project_id { get; construct; }
    public string? card_id { get; construct; }

    public CardContextBreadcrumb(string crumb_type,
                                 string title,
                                 string? project_id = null,
                                 string? card_id = null) {
        Object(
            crumb_type: crumb_type,
            title: title,
            project_id: project_id,
            card_id: card_id
        );
    }
}

public class CardContextCard : Object {
    public string card_id { get; construct; }
    public string project_id { get; construct; }
    public string title { get; construct; }
    public string rel_path { get; construct; }
    public double sort_key { get; construct; }
    public string? parent_card_id { get; construct; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; construct; }
    public int child_count { get; construct; }

    public CardContextCard(string card_id,
                           string project_id,
                           string title,
                           string rel_path,
                           double sort_key,
                           string? parent_card_id,
                           int64 created_at,
                           int64 updated_at,
                           int child_count) {
        Object(
            card_id: card_id,
            project_id: project_id,
            title: title,
            rel_path: rel_path,
            sort_key: sort_key,
            parent_card_id: parent_card_id,
            created_at: created_at,
            updated_at: updated_at,
            child_count: child_count
        );
    }
}

public class CardContextData : Object {
    public CardContextProject project { get; construct; }
    public string? current_parent_card_id { get; construct; }
    public Gee.ArrayList<CardContextBreadcrumb> breadcrumbs { get; construct; }
    public Gee.ArrayList<CardContextCard> cards { get; construct; }

    public CardContextData(CardContextProject project,
                           string? current_parent_card_id,
                           Gee.ArrayList<CardContextBreadcrumb> breadcrumbs,
                           Gee.ArrayList<CardContextCard> cards) {
        Object(
            project: project,
            current_parent_card_id: current_parent_card_id,
            breadcrumbs: breadcrumbs,
            cards: cards
        );
    }
}

}
