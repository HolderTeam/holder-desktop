using GLib;

namespace HolderLinux.Tests {

private void test_recovery_and_git_models_preserve_constructor_values() {
    var export = new HolderLinux.ProjectRecoveryTokenExport("proj-1", "key-1", "token-1");
    assert(export.project_id == "proj-1");
    assert(export.key_id == "key-1");
    assert(export.recovery_token == "token-1");

    var import_result = new HolderLinux.RecoveryTokenImportResult(
        "proj-2", true, false, true, "remote failed", "pulled", "none"
    );
    assert(import_result.project_id == "proj-2");
    assert(import_result.project_created);
    assert(!import_result.remote_hint_present);
    assert(import_result.remote_configured);
    assert(import_result.remote_error == "remote failed");
    assert(import_result.pull_status == "pulled");
    assert(import_result.pull_error == "none");

    var provider = new HolderLinux.GitProviderCatalogEntry(
        "github", "GitHub", "cloud", "ssh", "ssh or https", "git@github.com:me/repo.git", "https://github.com/me/repo.git"
    );
    assert(provider.id == "github");
    assert(provider.preferred_transport == "ssh");

    var test_remote = new HolderLinux.GitTestRemoteResult(
        "proj-3", "https://example/repo.git", "main", "ok", true, "", ""
    );
    assert(test_remote.project_id == "proj-3");
    assert(test_remote.remote_has_head);

    var push = new HolderLinux.GitPushResult(
        "proj-4", "https://example/repo.git", "main", "failed", 2, 1, "abc123", "network", "no route", "retry"
    );
    assert(push.project_id == "proj-4");
    assert(push.ahead_count == 2);
    assert(push.behind_count == 1);
    assert(push.local_head_commit == "abc123");
    assert(push.next_action == "retry");
}

private void test_card_context_models_preserve_constructor_values() {
    var project = new HolderLinux.CardContextProject("proj-1", "Project One");
    var breadcrumb = new HolderLinux.CardContextBreadcrumb("project", "Project One", "proj-1", null);
    var card = new HolderLinux.CardContextCard(
        "card-1", "proj-1", "Card One", "cards/card-1.md", 1.5, null, 10, 20, 3
    );

    var breadcrumbs = new Gee.ArrayList<HolderLinux.CardContextBreadcrumb>();
    breadcrumbs.add(breadcrumb);
    var cards = new Gee.ArrayList<HolderLinux.CardContextCard>();
    cards.add(card);

    var data = new HolderLinux.CardContextData(project, null, breadcrumbs, cards);

    assert(project.name == "Project One");
    assert(breadcrumb.crumb_type == "project");
    assert(breadcrumb.project_id == "proj-1");
    assert(card.card_id == "card-1");
    assert(card.child_count == 3);
    assert(data.project == project);
    assert(data.current_parent_card_id == null);
    assert(data.breadcrumbs.size == 1);
    assert(data.cards.size == 1);
}

private void test_activity_details_models_preserve_constructor_values() {
    var renamed = new HolderLinux.CardRenamedDetails("Old", "New", true);
    assert(renamed.old_title == "Old");
    assert(renamed.new_title == "New");
    assert(renamed.body_empty);

    var autosaved = new HolderLinux.CardAutosavedDetails("Title", 100, 80, 20, false, "fp-1");
    assert(autosaved.title == "Title");
    assert(autosaved.doc_chars == 100);
    assert(autosaved.body_chars == 80);
    assert(autosaved.delta_chars == 20);
    assert(!autosaved.body_empty);
    assert(autosaved.fingerprint == "fp-1");

    var created = new HolderLinux.CardCreatedDetails("New Card", "parent-1");
    assert(created.title == "New Card");
    assert(created.parent_card_id == "parent-1");

    var trashed = new HolderLinux.CardTrashedDetails("Card A");
    assert(trashed.title == "Card A");

    var trash_action = new HolderLinux.TrashActionDetails("card", "Card A");
    assert(trash_action.item_type == "card");
    assert(trash_action.title == "Card A");

    var resource = new HolderLinux.ResourceChangedDetails("create", "README.md");
    assert(resource.operation == "create");
    assert(resource.name == "README.md");

    var run = new HolderLinux.AiRunDetails("thread-1", "run-1", "openai", "gpt", "router", 321, true);
    assert(run.thread_id == "thread-1");
    assert(run.run_id == "run-1");
    assert(run.provider == "openai");
    assert(run.model == "gpt");
    assert(run.router_model == "router");
    assert(run.prompt_chars == 321);
    assert(run.success);

    var push = new HolderLinux.GitPushDetails("failed", "abc123", "main");
    assert(push.status == "failed");
    assert(push.local_head_commit == "abc123");
    assert(push.branch == "main");
}

private void test_nudge_models_preserve_constructor_values_and_defaults() {
    var nudge = new HolderLinux.AiNudge(
        "nudge-1", "card.title_only", "proj-1", "card-1", "Title", "Body", "fp-1", "abc123", 99
    );
    assert(nudge.nudge_id == "nudge-1");
    assert(nudge.kind == "card.title_only");
    assert(nudge.project_id == "proj-1");
    assert(nudge.card_id == "card-1");
    assert(nudge.title == "Title");
    assert(nudge.body == "Body");
    assert(nudge.basis_fingerprint == "fp-1");
    assert(nudge.basis_commit == "abc123");
    assert(nudge.created_at == 99);

    var with_nudge = new HolderLinux.NudgeEvaluationResult("accepted", true, true, "good", nudge);
    assert(with_nudge.kind == "accepted");
    assert(with_nudge.accepted);
    assert(with_nudge.should_nudge);
    assert(with_nudge.reason == "good");
    assert(with_nudge.nudge == nudge);

    var without_nudge = new HolderLinux.NudgeEvaluationResult("rejected", false, false, "skip");
    assert(without_nudge.kind == "rejected");
    assert(!without_nudge.accepted);
    assert(!without_nudge.should_nudge);
    assert(without_nudge.reason == "skip");
    assert(without_nudge.nudge == null);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/models/recovery-and-git-models", test_recovery_and_git_models_preserve_constructor_values);
    Test.add_func("/holder/models/card-context-models", test_card_context_models_preserve_constructor_values);
    Test.add_func("/holder/models/activity-details-models", test_activity_details_models_preserve_constructor_values);
    Test.add_func("/holder/models/nudge-models", test_nudge_models_preserve_constructor_values_and_defaults);
    return Test.run();
}

}
