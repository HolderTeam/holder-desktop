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
    public string[] tags { get; private set; }
    public CardTagOccurrence[] tag_occurrences;

    public CardDetail(string card_id,
                      string project_id,
                      string title,
                      string content,
                      int64 updated_at,
                      string[]? tags = null,
                      CardTagOccurrence[]? tag_occurrences = null) {
        Object(
            card_id: card_id,
            project_id: project_id,
            title: title,
            content: content,
            updated_at: updated_at
        );
        this.tags = tags ?? new string[0];
        this.tag_occurrences = tag_occurrences ?? new CardTagOccurrence[0];
    }
}

public class CardTagOccurrence : Object {
    public string tag { get; construct; }
    public int byte_start { get; construct; }
    public int byte_end { get; construct; }

    public CardTagOccurrence(string tag, int byte_start, int byte_end) {
        Object(tag: tag, byte_start: byte_start, byte_end: byte_end);
    }
}

public class TagCount : Object {
    public string tag { get; construct; }
    public int card_count { get; construct; }

    public TagCount(string tag, int card_count) {
        Object(tag: tag, card_count: card_count);
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

public class Milestone : Object {
    public string milestone_id { get; construct; }
    public string card_id { get; construct; }
    public int64 start_at { get; construct; }
    public int64? end_at;
    public bool all_day { get; construct; }
    public string? kind { get; construct; }
    public string? description { get; construct; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; construct; }
    public string? card_title { get; construct; }

    public Milestone(string milestone_id,
                     string card_id,
                     int64 start_at,
                     int64? end_at,
                     bool all_day,
                     string? kind,
                     string? description,
                     int64 created_at,
                     int64 updated_at,
                     string? card_title = null) {
        Object(
            milestone_id: milestone_id,
            card_id: card_id,
            start_at: start_at,
            all_day: all_day,
            kind: kind,
            description: description,
            created_at: created_at,
            updated_at: updated_at,
            card_title: card_title
        );
        this.end_at = end_at;
    }
}

public class CalendarCardActivity : Object {
    public string card_id { get; construct; }
    public string title { get; construct; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; construct; }

    public CalendarCardActivity(string card_id,
                                string title,
                                int64 created_at,
                                int64 updated_at) {
        Object(
            card_id: card_id,
            title: title,
            created_at: created_at,
            updated_at: updated_at
        );
    }
}

public class ProjectCalendar : Object {
    public string project_id { get; construct; }
    public int64 from_epoch { get; construct; }
    public int64 to_epoch { get; construct; }
    public Milestone[] milestones;
    public CalendarCardActivity[] created_cards;
    public CalendarCardActivity[] updated_cards;

    public ProjectCalendar(string project_id,
                           int64 from_epoch,
                           int64 to_epoch,
                           Milestone[] milestones,
                           CalendarCardActivity[] created_cards,
                           CalendarCardActivity[] updated_cards) {
        Object(
            project_id: project_id,
            from_epoch: from_epoch,
            to_epoch: to_epoch
        );
        this.milestones = milestones;
        this.created_cards = created_cards;
        this.updated_cards = updated_cards;
    }
}

public class CardHistoryEntry : Object {
    public string first_oid { get; construct; }
    public string last_oid { get; construct; }
    public string[] parent_oids;
    public string author_name { get; construct; }
    public string author_email { get; construct; }
    public int64 started_at { get; construct; }
    public int64 ended_at { get; construct; }
    public string kind { get; construct; }
    public string summary { get; construct; }
    public int commit_count { get; construct; }
    public bool is_merge { get; construct; }

    public CardHistoryEntry(string first_oid,
                            string last_oid,
                            string[] parent_oids,
                            string author_name,
                            string author_email,
                            int64 started_at,
                            int64 ended_at,
                            string kind,
                            string summary,
                            int commit_count,
                            bool is_merge) {
        Object(
            first_oid: first_oid,
            last_oid: last_oid,
            author_name: author_name,
            author_email: author_email,
            started_at: started_at,
            ended_at: ended_at,
            kind: kind,
            summary: summary,
            commit_count: commit_count,
            is_merge: is_merge
        );
        this.parent_oids = parent_oids;
    }
}

public class CardHistoryPage : Object {
    public string? head_oid { get; construct; }
    public CardHistoryEntry[] entries;
    public string? next_cursor { get; construct; }

    public CardHistoryPage(string? head_oid,
                           CardHistoryEntry[] entries,
                           string? next_cursor) {
        Object(head_oid: head_oid, next_cursor: next_cursor);
        this.entries = entries;
    }
}

public class CardHistoryVersion : Object {
    public bool exists { get; construct; }
    public string oid { get; construct; }
    public string title { get; construct; }
    public string body { get; construct; }

    public CardHistoryVersion(bool exists, string oid, string title, string body) {
        Object(exists: exists, oid: oid, title: title, body: body);
    }
}

public class CardHistoryDiffLine : Object {
    public string origin { get; construct; }
    public string text { get; construct; }
    public int64? old_line;
    public int64? new_line;

    public CardHistoryDiffLine(string origin, string text, int64? old_line, int64? new_line) {
        Object(origin: origin, text: text);
        this.old_line = old_line;
        this.new_line = new_line;
    }
}

public class CardHistoryComparison : Object {
    public CardHistoryVersion from_version { get; construct; }
    public CardHistoryVersion to_version { get; construct; }
    public string summary { get; construct; }
    public CardHistoryDiffLine[] lines;
    public bool truncated { get; construct; }

    public CardHistoryComparison(CardHistoryVersion from_version,
                                 CardHistoryVersion to_version,
                                 string summary,
                                 CardHistoryDiffLine[] lines,
                                 bool truncated) {
        Object(
            from_version: from_version,
            to_version: to_version,
            summary: summary,
            truncated: truncated
        );
        this.lines = lines;
    }
}

}
