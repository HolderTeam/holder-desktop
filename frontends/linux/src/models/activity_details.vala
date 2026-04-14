namespace HolderLinux {

public abstract class ActivityDetails : Object {
}

public class CardRenamedDetails : ActivityDetails {
    public string old_title { get; construct; }
    public string new_title { get; construct; }
    public bool body_empty { get; construct; }

    public CardRenamedDetails(string old_title, string new_title, bool body_empty) {
        Object(old_title: old_title, new_title: new_title, body_empty: body_empty);
    }
}

public class CardAutosavedDetails : ActivityDetails {
    public string title { get; construct; }
    public int doc_chars { get; construct; }
    public int body_chars { get; construct; }
    public int delta_chars { get; construct; }
    public bool body_empty { get; construct; }
    public string fingerprint { get; construct; }

    public CardAutosavedDetails(string title,
                                int doc_chars,
                                int body_chars,
                                int delta_chars,
                                bool body_empty,
                                string fingerprint) {
        Object(
            title: title,
            doc_chars: doc_chars,
            body_chars: body_chars,
            delta_chars: delta_chars,
            body_empty: body_empty,
            fingerprint: fingerprint
        );
    }
}

public class CardCreatedDetails : ActivityDetails {
    public string title { get; construct; }
    public string? parent_card_id { get; construct; }

    public CardCreatedDetails(string title, string? parent_card_id = null) {
        Object(title: title, parent_card_id: parent_card_id);
    }
}

public class CardTrashedDetails : ActivityDetails {
    public string title { get; construct; }

    public CardTrashedDetails(string title) {
        Object(title: title);
    }
}

public class TrashActionDetails : ActivityDetails {
    public string item_type { get; construct; }
    public string title { get; construct; }

    public TrashActionDetails(string item_type, string title) {
        Object(item_type: item_type, title: title);
    }
}

public class ResourceChangedDetails : ActivityDetails {
    public string operation { get; construct; }
    public string name { get; construct; }

    public ResourceChangedDetails(string operation, string name) {
        Object(operation: operation, name: name);
    }
}

public class AiRunDetails : ActivityDetails {
    public string thread_id { get; construct; }
    public string run_id { get; construct; }
    public string provider { get; construct; }
    public string model { get; construct; }
    public string router_model { get; construct; }
    public int prompt_chars { get; construct; }
    public bool success { get; construct; }

    public AiRunDetails(string thread_id,
                        string run_id,
                        string provider,
                        string model,
                        string router_model,
                        int prompt_chars,
                        bool success) {
        Object(
            thread_id: thread_id,
            run_id: run_id,
            provider: provider,
            model: model,
            router_model: router_model,
            prompt_chars: prompt_chars,
            success: success
        );
    }
}

}
