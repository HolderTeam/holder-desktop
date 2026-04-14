namespace HolderLinux {

public class AiNudge : Object {
    public string nudge_id { get; construct; }
    public string kind { get; construct; }
    public string project_id { get; construct; }
    public string card_id { get; construct; }
    public string title { get; construct; }
    public string body { get; construct; }
    public string basis_fingerprint { get; construct; }
    public string basis_commit { get; construct; }
    public int64 created_at { get; construct; }

    public AiNudge(string nudge_id,
                   string kind,
                   string project_id,
                   string card_id,
                   string title,
                   string body,
                   string basis_fingerprint,
                   string basis_commit,
                   int64 created_at) {
        Object(
            nudge_id: nudge_id,
            kind: kind,
            project_id: project_id,
            card_id: card_id,
            title: title,
            body: body,
            basis_fingerprint: basis_fingerprint,
            basis_commit: basis_commit,
            created_at: created_at
        );
    }
}

public class NudgeEvaluationResult : Object {
    public string kind { get; construct; }
    public bool accepted { get; construct; }
    public bool should_nudge { get; construct; }
    public string reason { get; construct; }
    public AiNudge? nudge { get; construct; }

    public NudgeEvaluationResult(string kind,
                                 bool accepted,
                                 bool should_nudge,
                                 string reason,
                                 AiNudge? nudge = null) {
        Object(
            kind: kind,
            accepted: accepted,
            should_nudge: should_nudge,
            reason: reason,
            nudge: nudge
        );
    }
}

}
