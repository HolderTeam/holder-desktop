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

private void test_ai_models_preserve_constructor_values() {
    var model_names = new Gee.ArrayList<string>();
    model_names.add("llama3");
    model_names.add("qwen3");

    var recommended = new Gee.ArrayList<string>();
    recommended.add("llama3");

    var capabilities = new HolderLinux.AiCapabilitiesInfo(
        true, "", 111, "1.2.3", "Developer", model_names, recommended
    );
    assert(capabilities.runner_available);
    assert(capabilities.runner_error == "");
    assert(capabilities.last_checked == 111);
    assert(capabilities.runner_version == "1.2.3");
    assert(capabilities.caste_name == "Developer");
    assert(capabilities.models.size == 2);
    assert(capabilities.recommended_install.size == 1);

    var pull = new HolderLinux.AiRunnerPullInfo("job-1", "auto-local", "llama3", "pulling", 42.5, "download");
    assert(pull.job_id == "job-1");
    assert(pull.runner_id == "auto-local");
    assert(pull.model == "llama3");
    assert(pull.status == "pulling");
    assert(pull.percent == 42.5);
    assert(pull.stage == "download");

    var runtime_models = new Gee.ArrayList<string>();
    runtime_models.add("llama3");
    var pulls = new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>();
    pulls.add(pull);

    var runtime = new HolderLinux.AiRunnerRuntimeInfo(
        true, true, true, 222, "0.6.0", "", runtime_models, pulls
    );
    assert(runtime.configured);
    assert(runtime.available);
    assert(runtime.spawn_attempted);
    assert(runtime.last_checked == 222);
    assert(runtime.version == "0.6.0");
    assert(runtime.models.size == 1);
    assert(runtime.pulls.size == 1);
    assert(runtime.pulls[0] == pull);

    var runner = new HolderLinux.AiRunnerInfo(
        "manual-a", "Office Runner", "ollama", "http://127.0.0.1:11434", "user", true, 333, 444, runtime
    );
    assert(runner.runner_id == "manual-a");
    assert(runner.name == "Office Runner");
    assert(runner.kind == "ollama");
    assert(runner.base_url == "http://127.0.0.1:11434");
    assert(runner.source == "user");
    assert(runner.enabled);
    assert(runner.created_at == 333);
    assert(runner.updated_at == 444);
    assert(runner.runtime == runtime);

    var status = new HolderLinux.AiStatusInfo(555, false, "offline", 3, 1, 2, pulls);
    assert(status.checked_at == 555);
    assert(!status.runner_available);
    assert(status.runner_error == "offline");
    assert(status.active_runs == 3);
    assert(status.active_pull_jobs == 1);
    assert(status.cloud_configured_providers == 2);
    assert(status.pulls.size == 1);

    var thread = new HolderLinux.AiThreadSummary("thread-1", "proj-1", "Investigate bug", 666, 777);
    assert(thread.thread_id == "thread-1");
    assert(thread.project_id == "proj-1");
    assert(thread.title == "Investigate bug");
    assert(thread.created_at == 666);
    assert(thread.updated_at == 777);

    var message = new HolderLinux.AiMessage(
        "msg-1", "thread-1", "assistant", "runner", "openai", "gpt-4.1", "Try this next.", 888
    );
    assert(message.message_id == "msg-1");
    assert(message.thread_id == "thread-1");
    assert(message.role == "assistant");
    assert(message.source == "runner");
    assert(message.provider == "openai");
    assert(message.model == "gpt-4.1");
    assert(message.content == "Try this next.");
    assert(message.created_at == 888);

    var catalog_provider = new HolderLinux.AiCatalogProvider(
        "openai", "OpenAI", true, false, "https://platform.openai.com", "https://platform.openai.com/docs"
    );
    assert(catalog_provider.id == "openai");
    assert(catalog_provider.display_name == "OpenAI");
    assert(catalog_provider.enabled);
    assert(!catalog_provider.configured);
    assert(catalog_provider.setup_url.contains("openai.com"));
    assert(catalog_provider.docs_url.contains("/docs"));

    var runtime_provider = new HolderLinux.AiRuntimeProvider(
        "anthropic", "Anthropic", false, true, "https://console.anthropic.com", "https://docs.anthropic.com"
    );
    assert(runtime_provider.id == "anthropic");
    assert(runtime_provider.display_name == "Anthropic");
    assert(!runtime_provider.enabled);
    assert(runtime_provider.configured);

    var credential_state = new HolderLinux.AiProviderCredentialState("openai", true, "sk-...1234", 999);
    assert(credential_state.provider == "openai");
    assert(credential_state.configured);
    assert(credential_state.api_key_preview == "sk-...1234");
    assert(credential_state.updated_at == 999);

    var setting_state = new HolderLinux.AiProviderSettingState("openai", true, 1001);
    assert(setting_state.provider == "openai");
    assert(setting_state.enabled);
    assert(setting_state.updated_at == 1001);

    var local_model_config = new HolderLinux.AiLocalModelConfigInfo("fast", "strong", null, 1002);
    assert(local_model_config.fast_model == "fast");
    assert(local_model_config.strong_model == "strong");
    assert(local_model_config.deep_model == null);
    assert(local_model_config.updated_at == 1002);
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
    assert(nudge.suggestions.size == 0);

    var suggestions = new Gee.ArrayList<string>();
    suggestions.add("Wetland Nurseries");
    suggestions.add("Frog Habitat Notes");
    suggestions.add("Seasonal Pond Life");
    var title_nudge = new HolderLinux.AiNudge(
        "nudge-2", "card.title_suggestion", "proj-1", "card-1", "Suggest a title", "Pick one", "", "", 100, suggestions
    );
    assert(title_nudge.suggestions.size == 3);
    assert(title_nudge.suggestions[0] == "Wetland Nurseries");

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
    Test.add_func("/holder/models/ai-models", test_ai_models_preserve_constructor_values);
    Test.add_func("/holder/models/nudge-models", test_nudge_models_preserve_constructor_values_and_defaults);
    return Test.run();
}

}
