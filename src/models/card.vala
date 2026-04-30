namespace HolderLinux {

public class CardSummary : Object {
    public string card_id { get; construct; }
    public string project_id { get; construct; }
    public string title { get; set; }
    public string rel_path { get; construct; }
    public double sort_key { get; set; }
    public string? parent_card_id { get; set; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; set; }

    public CardSummary(string card_id,
                       string project_id,
                       string title,
                       string rel_path,
                       double sort_key,
                       string? parent_card_id,
                       int64 created_at,
                       int64 updated_at) {
        Object(
            card_id: card_id,
            project_id: project_id,
            title: title,
            rel_path: rel_path,
            sort_key: sort_key,
            parent_card_id: parent_card_id,
            created_at: created_at,
            updated_at: updated_at
        );
    }
}

public class CardLink : Object {
    public string from_card_id { get; construct; }
    public string to_card_id { get; construct; }
    public string to_type { get; construct; }
    public string kind { get; construct; }
    public string? label { get; construct; }
    public int64 created_at { get; construct; }

    public CardLink(string from_card_id,
                    string to_card_id,
                    string to_type,
                    string kind,
                    string? label,
                    int64 created_at) {
        Object(
            from_card_id: from_card_id,
            to_card_id: to_card_id,
            to_type: to_type,
            kind: kind,
            label: label,
            created_at: created_at
        );
    }
}

public class CardDetail : Object {
    public string card_id { get; construct; }
    public string project_id { get; construct; }
    public string title { get; set; }
    public string content { get; set; }
    public int64 updated_at { get; set; }

    public CardDetail(string card_id,
                      string project_id,
                      string title,
                      string content,
                      int64 updated_at) {
        Object(
            card_id: card_id,
            project_id: project_id,
            title: title,
            content: content,
            updated_at: updated_at
        );
    }
}

public class SearchCardResult : Object {
    public string card_id { get; construct; }
    public string title { get; construct; }
    public int64 updated_at { get; construct; }
    public int64 created_at { get; construct; }
    public string snippet { get; construct; }
    public double rank { get; construct; }

    public SearchCardResult(string card_id,
                            string title,
                            int64 updated_at,
                            int64 created_at,
                            string snippet,
                            double rank) {
        Object(
            card_id: card_id,
            title: title,
            updated_at: updated_at,
            created_at: created_at,
            snippet: snippet,
            rank: rank
        );
    }
}

public class CardMoveResult : Object {
    public string card_id { get; construct; }
    public string? parent_card_id { get; construct; }
    public double sort_key { get; construct; }
    public int64 revision { get; construct; }
    public string moved_into_title { get; construct; }

    public CardMoveResult(string card_id,
                          string? parent_card_id,
                          double sort_key,
                          int64 revision,
                          string moved_into_title) {
        Object(
            card_id: card_id,
            parent_card_id: parent_card_id,
            sort_key: sort_key,
            revision: revision,
            moved_into_title: moved_into_title
        );
    }
}

}
