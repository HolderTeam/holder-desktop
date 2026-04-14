using GLib;

namespace HolderLinux.Tests {

private HolderLinux.ActivityLogEntry entry_with_details(int64 timestamp,
                                                        string kind,
                                                        string? project_id,
                                                        string? card_id,
                                                        HolderLinux.ActivityDetails? details) {
    return new HolderLinux.ActivityLogEntry(timestamp, kind, kind, project_id, card_id, details);
}

private Gee.ArrayList<HolderLinux.ActivityLogEntry> entries(params HolderLinux.ActivityLogEntry[] items) {
    var out = new Gee.ArrayList<HolderLinux.ActivityLogEntry>();
    foreach (var item in items) {
        out.add(item);
    }
    return out;
}

private void test_reduce_returns_empty_for_no_entries() {
    var reducer = new HolderLinux.SessionActivityReducer();
    var input = new Gee.ArrayList<HolderLinux.ActivityLogEntry>();

    var candidates = reducer.reduce(input);

    assert(candidates.size == 0);
}

private void test_title_only_candidate_is_emitted_for_short_non_placeholder_empty_doc() {
    var reducer = new HolderLinux.SessionActivityReducer();
    var input = entries(
        entry_with_details(
            100,
            "result.card.autosave",
            "proj-1",
            "card-1",
            new HolderLinux.CardAutosavedDetails("Real Title", 120, 0, 0, true, "fp-1")
        )
    );

    var candidates = reducer.reduce(input);

    assert(candidates.size == 1);
    var candidate = candidates[0];
    assert(candidate.kind == "card.title_only");
    assert(candidate.project_id == "proj-1");
    assert(candidate.card_id == "card-1");
    assert(candidate.basis_fingerprint == "fp-1");
    assert(candidate.basis_commit == null);
    assert(candidate.facts.get_string_member("title") == "Real Title");
    assert(candidate.facts.get_boolean_member("body_empty"));
    assert(candidate.facts.get_int_member("doc_chars") == 120);
    assert(candidate.facts.get_int_member("body_chars") == 0);
}

private void test_title_only_candidate_is_rejected_for_placeholder_or_long_doc() {
    var reducer = new HolderLinux.SessionActivityReducer();

    var placeholder = entries(
        entry_with_details(
            100,
            "result.card.autosave",
            "proj-1",
            "card-1",
            new HolderLinux.CardAutosavedDetails("Untitled Note", 80, 0, 0, true, "fp-a")
        )
    );
    assert(reducer.reduce(placeholder).size == 0);

    var too_long = entries(
        entry_with_details(
            101,
            "result.card.autosave",
            "proj-1",
            "card-1",
            new HolderLinux.CardAutosavedDetails("Real Title", 161, 0, 0, true, "fp-b")
        )
    );
    assert(reducer.reduce(too_long).size == 0);
}

private void test_title_only_candidate_rejects_missing_details_or_ids() {
    var reducer = new HolderLinux.SessionActivityReducer();

    var missing_details = entries(
        entry_with_details(100, "result.card.autosave", "proj-1", "card-1", null)
    );
    assert(reducer.reduce(missing_details).size == 0);

    var missing_project = entries(
        entry_with_details(
            101,
            "result.card.autosave",
            null,
            "card-1",
            new HolderLinux.CardAutosavedDetails("Real Title", 120, 0, 0, true, "fp-x")
        )
    );
    assert(reducer.reduce(missing_project).size == 0);

    var missing_card = entries(
        entry_with_details(
            102,
            "result.card.autosave",
            "proj-1",
            null,
            new HolderLinux.CardAutosavedDetails("Real Title", 120, 0, 0, true, "fp-y")
        )
    );
    assert(reducer.reduce(missing_card).size == 0);
}

private void test_stuck_drafting_candidate_counts_recent_autosaves_for_same_card() {
    var reducer = new HolderLinux.SessionActivityReducer();
    var input = entries(
        entry_with_details(
            10,
            "result.card.autosave",
            "proj-1",
            "card-1",
            new HolderLinux.CardAutosavedDetails("Draft", 120, 80, 5, false, "fp-1")
        ),
        entry_with_details(
            120,
            "result.card.autosave",
            "proj-1",
            "card-1",
            new HolderLinux.CardAutosavedDetails("Draft", 125, 85, 5, false, "fp-1")
        ),
        entry_with_details(
            180,
            "result.card.autosave",
            "proj-1",
            "card-1",
            new HolderLinux.CardAutosavedDetails("Draft", 130, 90, 5, false, "fp-2")
        )
    );

    var candidates = reducer.reduce(input);

    assert(candidates.size == 1);
    var candidate = candidates[0];
    assert(candidate.kind == "card.stuck_drafting");
    assert(candidate.project_id == "proj-1");
    assert(candidate.card_id == "card-1");
    assert(candidate.basis_fingerprint == "fp-2");
    assert(candidate.facts.get_int_member("autosave_count") == 3);
    assert(candidate.facts.get_int_member("duration_seconds") == 170);
    assert(candidate.facts.get_int_member("body_chars") == 90);
}

private void test_stuck_drafting_rejects_latest_entry_with_large_body() {
    var reducer = new HolderLinux.SessionActivityReducer();

    var oversized_body = entries(
        entry_with_details(
            100,
            "result.card.autosave",
            "proj-1",
            "card-1",
            new HolderLinux.CardAutosavedDetails("Draft", 170, 161, 3, false, "fp-1")
        ),
        entry_with_details(
            120,
            "result.card.autosave",
            "proj-1",
            "card-1",
            new HolderLinux.CardAutosavedDetails("Draft", 172, 162, 2, false, "fp-2")
        )
    );

    assert(reducer.reduce(oversized_body).size == 0);
}

private void test_stuck_drafting_rejects_missing_details_or_ids() {
    var reducer = new HolderLinux.SessionActivityReducer();

    var missing_details = entries(
        entry_with_details(100, "result.card.autosave", "proj-1", "card-1", null)
    );
    assert(reducer.reduce(missing_details).size == 0);

    var missing_project = entries(
        entry_with_details(
            101,
            "result.card.autosave",
            null,
            "card-1",
            new HolderLinux.CardAutosavedDetails("Draft", 120, 80, 2, false, "fp-x")
        )
    );
    assert(reducer.reduce(missing_project).size == 0);

    var missing_card = entries(
        entry_with_details(
            102,
            "result.card.autosave",
            "proj-1",
            null,
            new HolderLinux.CardAutosavedDetails("Draft", 120, 80, 2, false, "fp-y")
        )
    );
    assert(reducer.reduce(missing_card).size == 0);
}

private void test_stuck_drafting_breaks_on_old_entries_and_skips_other_cards() {
    var reducer = new HolderLinux.SessionActivityReducer();
    var input = entries(
        entry_with_details(
            100,
            "result.card.autosave",
            "proj-1",
            "card-1",
            new HolderLinux.CardAutosavedDetails("Draft", 120, 80, 2, false, "fp-old")
        ),
        entry_with_details(
            750,
            "result.card.autosave",
            "proj-1",
            "card-1",
            new HolderLinux.CardAutosavedDetails("Draft", 120, 80, 2, false, "fp-a")
        ),
        entry_with_details(
            900,
            "result.card.autosave",
            "proj-1",
            "card-2",
            new HolderLinux.CardAutosavedDetails("Other", 125, 82, 2, false, "fp-b")
        ),
        entry_with_details(
            1000,
            "result.card.autosave",
            "proj-1",
            "card-1",
            new HolderLinux.CardAutosavedDetails("Draft", 130, 90, 2, false, "fp-c")
        )
    );

    assert(reducer.reduce(input).size == 0);
}

private void test_git_push_failed_repeated_candidate_is_emitted_after_multiple_failures() {
    var reducer = new HolderLinux.SessionActivityReducer();
    var input = entries(
        entry_with_details(
            100,
            "result.git.push",
            "proj-1",
            null,
            new HolderLinux.GitPushDetails("failed", "abc123", "main")
        ),
        entry_with_details(
            200,
            "result.git.push",
            "proj-1",
            null,
            new HolderLinux.GitPushDetails("network_error", "abc123", "main")
        )
    );

    var candidates = reducer.reduce(input);

    assert(candidates.size == 1);
    var candidate = candidates[0];
    assert(candidate.kind == "git.push_failed_repeated");
    assert(candidate.project_id == "proj-1");
    assert(candidate.card_id == null);
    assert(candidate.basis_fingerprint == null);
    assert(candidate.basis_commit == "abc123");
    assert(candidate.facts.get_int_member("failure_count") == 2);
    assert(candidate.facts.get_string_member("latest_status") == "network_error");
    assert(candidate.facts.get_string_member("branch") == "main");
}

private void test_git_push_candidate_rejects_missing_details_or_project() {
    var reducer = new HolderLinux.SessionActivityReducer();

    var missing_details = entries(
        entry_with_details(100, "result.git.push", "proj-1", null, null)
    );
    assert(reducer.reduce(missing_details).size == 0);

    var missing_project = entries(
        entry_with_details(
            101,
            "result.git.push",
            null,
            null,
            new HolderLinux.GitPushDetails("failed", "abc123", "main")
        )
    );
    assert(reducer.reduce(missing_project).size == 0);
}

private void test_git_push_candidate_ignores_successful_statuses_and_old_failures() {
    var reducer = new HolderLinux.SessionActivityReducer();

    var successful = entries(
        entry_with_details(
            100,
            "result.git.push",
            "proj-1",
            null,
            new HolderLinux.GitPushDetails("pushed", "abc123", "main")
        )
    );
    assert(reducer.reduce(successful).size == 0);

    var stale = entries(
        entry_with_details(
            1,
            "result.git.push",
            "proj-1",
            null,
            new HolderLinux.GitPushDetails("failed", "abc123", "main")
        ),
        entry_with_details(
            1900,
            "result.git.push",
            "proj-1",
            null,
            new HolderLinux.GitPushDetails("failed", "abc123", "main")
        )
    );
    assert(reducer.reduce(stale).size == 0);
}

private void test_git_push_skips_other_projects_and_successes_and_allows_blank_commit() {
    var reducer = new HolderLinux.SessionActivityReducer();
    var input = entries(
        entry_with_details(
            100,
            "result.git.push",
            "proj-2",
            null,
            new HolderLinux.GitPushDetails("failed", "abc999", "main")
        ),
        entry_with_details(
            200,
            "result.git.push",
            "proj-1",
            null,
            new HolderLinux.GitPushDetails("pushed", "abc123", "main")
        ),
        entry_with_details(
            300,
            "result.git.push",
            "proj-1",
            null,
            new HolderLinux.GitPushDetails("failed", "", "main")
        ),
        entry_with_details(
            400,
            "result.git.push",
            "proj-1",
            null,
            new HolderLinux.GitPushDetails("network_error", "", "main")
        )
    );

    var candidates = reducer.reduce(input);

    assert(candidates.size == 1);
    var candidate = candidates[0];
    assert(candidate.kind == "git.push_failed_repeated");
    assert(candidate.project_id == "proj-1");
    assert(candidate.basis_commit == null);
    assert(candidate.facts.get_int_member("failure_count") == 2);
    assert(candidate.facts.get_string_member("latest_status") == "network_error");
}

private void test_reduce_dedupes_candidates_across_repeated_calls() {
    var reducer = new HolderLinux.SessionActivityReducer();
    var input = entries(
        entry_with_details(
            100,
            "result.card.autosave",
            "proj-1",
            "card-1",
            new HolderLinux.CardAutosavedDetails("Real Title", 120, 0, 0, true, "fp-1")
        )
    );

    var first = reducer.reduce(input);
    var second = reducer.reduce(input);

    assert(first.size == 1);
    assert(second.size == 0);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/activity-reducer/empty-input", test_reduce_returns_empty_for_no_entries);
    Test.add_func("/holder/activity-reducer/title-only-candidate", test_title_only_candidate_is_emitted_for_short_non_placeholder_empty_doc);
    Test.add_func("/holder/activity-reducer/title-only-rejections", test_title_only_candidate_is_rejected_for_placeholder_or_long_doc);
    Test.add_func("/holder/activity-reducer/title-only-missing-details-or-ids", test_title_only_candidate_rejects_missing_details_or_ids);
    Test.add_func("/holder/activity-reducer/stuck-drafting-candidate", test_stuck_drafting_candidate_counts_recent_autosaves_for_same_card);
    Test.add_func("/holder/activity-reducer/stuck-drafting-rejections", test_stuck_drafting_rejects_latest_entry_with_large_body);
    Test.add_func("/holder/activity-reducer/stuck-drafting-missing-details-or-ids", test_stuck_drafting_rejects_missing_details_or_ids);
    Test.add_func("/holder/activity-reducer/stuck-drafting-window-and-skip-logic", test_stuck_drafting_breaks_on_old_entries_and_skips_other_cards);
    Test.add_func("/holder/activity-reducer/git-push-failed-repeated", test_git_push_failed_repeated_candidate_is_emitted_after_multiple_failures);
    Test.add_func("/holder/activity-reducer/git-push-missing-details-or-project", test_git_push_candidate_rejects_missing_details_or_project);
    Test.add_func("/holder/activity-reducer/git-push-rejections", test_git_push_candidate_ignores_successful_statuses_and_old_failures);
    Test.add_func("/holder/activity-reducer/git-push-skip-and-blank-commit", test_git_push_skips_other_projects_and_successes_and_allows_blank_commit);
    Test.add_func("/holder/activity-reducer/dedupes-across-calls", test_reduce_dedupes_candidates_across_repeated_calls);
    return Test.run();
}

}
