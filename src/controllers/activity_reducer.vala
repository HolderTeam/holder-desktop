namespace HolderLinux {

public class NudgeCandidate : Object {
    public string kind { get; construct; }
    public string project_id { get; construct; }
    public string? card_id { get; construct; }
    public int64 created_at { get; construct; }
    public string? basis_fingerprint { get; construct; }
    public string? basis_commit { get; construct; }
    public Json.Object facts { get; construct; }

    public NudgeCandidate(string kind,
                          string project_id,
                          string? card_id,
                          int64 created_at,
                          Json.Object facts,
                          string? basis_fingerprint = null,
                          string? basis_commit = null) {
        Object(
            kind: kind,
            project_id: project_id,
            card_id: card_id,
            created_at: created_at,
            facts: facts,
            basis_fingerprint: basis_fingerprint,
            basis_commit: basis_commit
        );
    }
}

public interface IActivityReducer : Object {
    public abstract Gee.ArrayList<NudgeCandidate> reduce(Gee.List<ActivityLogEntry> entries);
}

public class SessionActivityReducer : Object, IActivityReducer {
    private const int TITLE_ONLY_MAX_DOC_CHARS = 160;
    private const int STUCK_DRAFTING_MAX_BODY_CHARS = 160;
    private const int STUCK_DRAFTING_MIN_AUTOSAVES = 3;
    private const int STUCK_DRAFTING_WINDOW_SECONDS = 300;
    private const int GIT_PUSH_FAILURE_MIN_COUNT = 2;
    private const int GIT_PUSH_FAILURE_WINDOW_SECONDS = 1800;

    private Gee.HashSet<string> emitted_candidate_keys = new Gee.HashSet<string>();

    public Gee.ArrayList<NudgeCandidate> reduce(Gee.List<ActivityLogEntry> entries) {
        var candidates = new Gee.ArrayList<NudgeCandidate>();
        if (entries.size == 0) {
            return candidates;
        }

        var latest = entries.get(entries.size - 1);
        add_candidate_if_new(candidates, build_title_only_candidate(latest));
        add_candidate_if_new(candidates, build_stuck_drafting_candidate(entries, latest));
        add_candidate_if_new(candidates, build_git_push_failed_repeated_candidate(entries, latest));
        return candidates;
    }

    private void add_candidate_if_new(Gee.ArrayList<NudgeCandidate> candidates, NudgeCandidate? candidate) {
        if (candidate == null) {
            return;
        }
        var key = dedupe_key(candidate);
        if (emitted_candidate_keys.contains(key)) {
            return;
        }
        emitted_candidate_keys.add(key);
        candidates.add(candidate);
    }

    private NudgeCandidate? build_title_only_candidate(ActivityLogEntry entry) {
        if (entry.kind != "result.card.autosave") {
            return null;
        }
        var details = entry.details as CardAutosavedDetails;
        if (details == null || entry.project_id == null || entry.card_id == null) {
            return null;
        }
        if (!details.body_empty || details.doc_chars > TITLE_ONLY_MAX_DOC_CHARS) {
            return null;
        }
        if (is_placeholder_title(details.title)) {
            return null;
        }

        var facts = new Json.Object();
        facts.set_string_member("title", details.title);
        facts.set_boolean_member("body_empty", details.body_empty);
        facts.set_int_member("doc_chars", details.doc_chars);
        facts.set_int_member("body_chars", details.body_chars);

        return new NudgeCandidate(
            "card.title_only",
            entry.project_id,
            entry.card_id,
            entry.timestamp,
            facts,
            details.fingerprint,
            null
        );
    }

    private NudgeCandidate? build_stuck_drafting_candidate(Gee.List<ActivityLogEntry> entries,
                                                           ActivityLogEntry latest) {
        if (latest.kind != "result.card.autosave") {
            return null;
        }
        var details = latest.details as CardAutosavedDetails;
        if (details == null || latest.project_id == null || latest.card_id == null) {
            return null;
        }
        if (details.body_empty || details.body_chars > STUCK_DRAFTING_MAX_BODY_CHARS) {
            return null;
        }

        int autosave_count = 0;
        int64 earliest_timestamp = latest.timestamp;
        for (int i = entries.size - 1; i >= 0; i--) {
            var entry = entries.get(i);
            if (entry.timestamp < latest.timestamp - STUCK_DRAFTING_WINDOW_SECONDS) {
                break;
            }
            if (entry.kind != "result.card.autosave" || entry.card_id != latest.card_id) {
                continue;
            }
            autosave_count++;
            earliest_timestamp = entry.timestamp;
        }

        if (autosave_count < STUCK_DRAFTING_MIN_AUTOSAVES) {
            return null;
        }

        var facts = new Json.Object();
        facts.set_string_member("title", details.title);
        facts.set_int_member("autosave_count", autosave_count);
        facts.set_int_member("doc_chars", details.doc_chars);
        facts.set_int_member("body_chars", details.body_chars);
        facts.set_int_member("duration_seconds", (int) (latest.timestamp - earliest_timestamp));

        return new NudgeCandidate(
            "card.stuck_drafting",
            latest.project_id,
            latest.card_id,
            latest.timestamp,
            facts,
            details.fingerprint,
            null
        );
    }

    private NudgeCandidate? build_git_push_failed_repeated_candidate(Gee.List<ActivityLogEntry> entries,
                                                                     ActivityLogEntry latest) {
        if (latest.kind != "result.git.push") {
            return null;
        }
        var details = latest.details as GitPushDetails;
        if (details == null || latest.project_id == null) {
            return null;
        }
        if (is_successful_push_status(details.status)) {
            return null;
        }

        int failure_count = 0;
        for (int i = entries.size - 1; i >= 0; i--) {
            var entry = entries.get(i);
            if (entry.timestamp < latest.timestamp - GIT_PUSH_FAILURE_WINDOW_SECONDS) {
                break;
            }
            if (entry.kind != "result.git.push" || entry.project_id != latest.project_id) {
                continue;
            }
            var push_details = entry.details as GitPushDetails;
            if (push_details == null || is_successful_push_status(push_details.status)) {
                continue;
            }
            failure_count++;
        }

        if (failure_count < GIT_PUSH_FAILURE_MIN_COUNT) {
            return null;
        }

        var facts = new Json.Object();
        facts.set_int_member("failure_count", failure_count);
        facts.set_string_member("latest_status", details.status);
        facts.set_string_member("branch", details.branch);

        return new NudgeCandidate(
            "git.push_failed_repeated",
            latest.project_id,
            null,
            latest.timestamp,
            facts,
            null,
            details.local_head_commit.strip().length > 0 ? details.local_head_commit : null
        );
    }

    private static string dedupe_key(NudgeCandidate candidate) {
        return "%s|%s|%s|%s|%s".printf(
            candidate.kind,
            candidate.project_id,
            candidate.card_id ?? "",
            candidate.basis_fingerprint ?? "",
            candidate.basis_commit ?? ""
        );
    }

    private static bool is_placeholder_title(string title) {
        return title.strip().down().has_prefix("untitled");
    }

    private static bool is_successful_push_status(string status) {
        var normalized = status.strip();
        return normalized == "pushed" || normalized == "up_to_date";
    }
}

}
