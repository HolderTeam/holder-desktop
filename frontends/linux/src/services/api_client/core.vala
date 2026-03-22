namespace HolderLinux {

public class ApiClient : Object, IHolderApi { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    private IApiHttpTransport transport; // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    private string base_url;
    private string auth_token;

    public ApiClient(string base_url, string auth_token, IApiHttpTransport? transport = null) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        this.base_url = base_url;
        this.auth_token = auth_token;
        this.transport = transport ?? new SoupApiHttpTransport(); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    // Health
    public async void health_check() throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        yield ApiClientHealthEndpoints.health_check(this);
    }

    public async HealthInfo get_health_info() throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientHealthEndpoints.get_health_info(this); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    // Projects
    public async Gee.ArrayList<Project> list_projects() throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientProjectsEndpoints.list_projects(this); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async string create_project(string name, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                       string privacy_mode = "encrypted_git") throws Error {
        return yield ApiClientProjectsEndpoints.create_project(this, name, privacy_mode); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async ProjectRecoveryTokenExport export_project_recovery_token( // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        string project_id,
        string pin
    ) throws Error {
        return yield ApiClientProjectsEndpoints.export_project_recovery_token(this, project_id, pin); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async void import_project_recovery_token( // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        string project_id,
        string pin,
        string recovery_token
    ) throws Error {
        yield ApiClientProjectsEndpoints.import_project_recovery_token(this, project_id, pin, recovery_token); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async RecoveryTokenImportResult import_recovery_token( // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        string pin,
        string recovery_token
    ) throws Error {
        return yield ApiClientProjectsEndpoints.import_recovery_token(this, pin, recovery_token); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    // Cards
    public async Gee.ArrayList<CardSummary> list_cards(string project_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                                       string view = "tree",
                                                       string? parent_card_id = null,
                                                       int limit = 0) throws Error {
        return yield ApiClientCardsEndpoints.list_cards(this, project_id, view, parent_card_id, limit); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async CardContextData get_card_context(string project_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                                  string? parent_card_id = null) throws Error {
        return yield ApiClientCardsEndpoints.get_card_context(this, project_id, parent_card_id); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async CardDetail get_card(string card_id) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientCardsEndpoints.get_card(this, card_id); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async string create_card(string project_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                    string title,
                                    string content,
                                    string? parent_card_id = null) throws Error {
        return yield ApiClientCardsEndpoints.create_card(this, project_id, title, content, parent_card_id); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async void update_card(string card_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                  string title,
                                  string content,
                                  int64 updated_at) throws Error {
        yield ApiClientCardsEndpoints.update_card(this, card_id, title, content, updated_at); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async void update_card_position(string card_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                           string? parent_card_id,
                                           double sort_key,
                                           int64 updated_at) throws Error {
        yield ApiClientCardsEndpoints.update_card_position( // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
            this, card_id, parent_card_id, sort_key, updated_at
        );
    }

    public async void delete_card(string card_id) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        yield ApiClientCardsEndpoints.delete_card(this, card_id); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async CardMoveResult move_card(string card_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                          string project_id,
                                          string intent,
                                          string? target_card_id = null,
                                          string? parent_card_id = null) throws Error {
        return yield ApiClientCardsEndpoints.move_card( // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
            this, card_id, project_id, intent, target_card_id, parent_card_id
        );
    }

    public async Gee.ArrayList<CardLink> list_card_links(string card_id) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientCardsEndpoints.list_card_links(this, card_id); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async Gee.ArrayList<CardLink> list_card_backlinks(string card_id) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientCardsEndpoints.list_card_backlinks(this, card_id); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async CardLink create_card_link(string from_card_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                           string to_card_id,
                                           string kind = "ref",
                                           string? label = null,
                                           string to_type = "card") throws Error {
        return yield ApiClientCardsEndpoints.create_card_link( // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
            this, from_card_id, to_card_id, kind, label, to_type
        );
    }

    public async void delete_card_link(string from_card_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                       string to_card_id,
                                       string kind,
                                       string to_type = "card") throws Error {
        yield ApiClientCardsEndpoints.delete_card_link(this, from_card_id, to_card_id, kind, to_type); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    // Resources
    public async Gee.ArrayList<ProjectResource> list_resources(string project_id) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientResourcesEndpoints.list_resources(this, project_id); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async string create_resource(string project_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                        string kind,
                                        string uri,
                                        string label,
                                        string? desc = null) throws Error {
        return yield ApiClientResourcesEndpoints.create_resource(this, project_id, kind, uri, label, desc); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async void update_resource(string resource_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                      string? kind,
                                      string? uri,
                                      string? label,
                                      string? desc,
                                      int64 updated_at) throws Error {
        yield ApiClientResourcesEndpoints.update_resource( // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
            this, resource_id, kind, uri, label, desc, updated_at
        );
    }

    public async void delete_resource(string resource_id) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        yield ApiClientResourcesEndpoints.delete_resource(this, resource_id); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    // Trash
    public async Gee.ArrayList<TrashItem> list_trash_items(string project_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                                           string type = "all") throws Error {
        return yield ApiClientTrashEndpoints.list_trash_items(this, project_id, type); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async void empty_trash(string project_id, string type = "all") throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        yield ApiClientTrashEndpoints.empty_trash(this, project_id, type); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async void restore_trash_item(string item_type, string item_id) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        yield ApiClientTrashEndpoints.restore_trash_item(this, item_type, item_id);
    }

    public async void hard_delete_trash_item(string item_type, string item_id) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        yield ApiClientTrashEndpoints.hard_delete_trash_item(this, item_type, item_id); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    // Search
    public async Gee.ArrayList<SearchCardResult> search_cards(string project_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                                              string query_text,
                                                              int limit = 30) throws Error {
        return yield ApiClientSearchEndpoints.search_cards(this, project_id, query_text, limit); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    // AI
    public async AiCapabilitiesInfo get_ai_capabilities(string? project_id = null) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientAiEndpoints.get_ai_capabilities(this, project_id); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async AiStatusInfo get_ai_status() throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientAiEndpoints.get_ai_status(this); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async string start_ai_runner_pull(string model_tag) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientAiEndpoints.start_ai_runner_pull(this, model_tag); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async Gee.ArrayList<AiThreadSummary> list_ai_threads(string project_id) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientAiEndpoints.list_ai_threads(this, project_id); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async Gee.ArrayList<AiMessage> list_ai_messages(string thread_id) throws Error {
        return yield ApiClientAiEndpoints.list_ai_messages(this, thread_id);
    }

    public async string create_ai_thread(string project_id, string title) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientAiEndpoints.create_ai_thread(this, project_id, title); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async Gee.ArrayList<AiCatalogProvider> list_ai_provider_catalog() throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientAiEndpoints.list_ai_provider_catalog(this); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async Gee.ArrayList<AiRuntimeProvider> list_ai_runtime_providers() throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientAiEndpoints.list_ai_runtime_providers(this); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async AiLocalModelConfigInfo get_ai_local_model_config() throws Error {
        return yield ApiClientAiEndpoints.get_ai_local_model_config(this);
    }

    public async AiLocalModelConfigInfo set_ai_local_model_config(string? fast_model,
                                                                  string? strong_model,
                                                                  string? deep_model) throws Error {
        return yield ApiClientAiEndpoints.set_ai_local_model_config(
            this,
            fast_model,
            strong_model,
            deep_model
        );
    }

    public async Gee.ArrayList<AiProviderCredentialState> list_ai_provider_credentials() throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientAiEndpoints.list_ai_provider_credentials(this); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async Gee.ArrayList<AiProviderSettingState> list_ai_provider_settings() throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientAiEndpoints.list_ai_provider_settings(this); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async void upsert_ai_provider_credential(string provider, string api_key) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        yield ApiClientAiEndpoints.upsert_ai_provider_credential(this, provider, api_key); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async void delete_ai_provider_credential(string provider) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        yield ApiClientAiEndpoints.delete_ai_provider_credential(this, provider); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async void set_ai_provider_enabled(string provider, bool enabled) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        yield ApiClientAiEndpoints.set_ai_provider_enabled(this, provider, enabled); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async Gee.ArrayList<AiNudge> list_ai_nudges(string project_id,
                                                       string? card_id = null) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientAiEndpoints.list_ai_nudges(this, project_id, card_id); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async void dismiss_ai_nudge(string nudge_id) throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        yield ApiClientAiEndpoints.dismiss_ai_nudge(this, nudge_id); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async NudgeEvaluationResult evaluate_nudge_candidate(string kind,
                                                                string project_id,
                                                                string? card_id,
                                                                int64 created_at,
                                                                Json.Object facts,
                                                                string? basis_fingerprint = null,
                                                                string? basis_commit = null) throws Error {
        return yield ApiClientAiEndpoints.evaluate_nudge_candidate(
            this,
            kind,
            project_id,
            card_id,
            created_at,
            facts,
            basis_fingerprint,
            basis_commit
        );
    }

    public async void run_ai_stream(string prompt, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                    string? project_id,
                                    string? thread_id,
                                    string? context_card_id,
                                    string? context_card_title,
                                    string? context_card_body,
                                    AiRunEventHandler on_event) throws Error {
        yield ApiClientAiStream.run(
            transport,
            base_url,
            auth_token,
            prompt,
            project_id,
            thread_id,
            context_card_id,
            context_card_title,
            context_card_body,
            on_event
        );
    }

    // Git
    public async Gee.ArrayList<GitProviderCatalogEntry> list_git_provider_catalog() throws Error { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return yield ApiClientGitEndpoints.list_git_provider_catalog(this); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async void set_project_git_remote(string project_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                             string? git_remote_url,
                                             int64 updated_at) throws Error {
        yield ApiClientGitEndpoints.set_project_git_remote(this, project_id, git_remote_url, updated_at); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async GitTestRemoteResult test_project_git_remote(string project_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                                             string? remote_url = null,
                                                             string branch = "") throws Error {
        return yield ApiClientGitEndpoints.test_project_git_remote(this, project_id, remote_url, branch); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    public async GitPushResult push_project_git(string project_id, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                                string branch = "",
                                                bool set_upstream = true) throws Error {
        return yield ApiClientGitEndpoints.push_project_git(this, project_id, branch, set_upstream); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    // Transport internals
    internal async Json.Object request_json(string method, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                            string path,
                                            string? request_body,
                                            HashTable<string, string>? query) throws Error {
        return yield ApiClientTransport.request_json( // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
            transport,
            base_url,
            auth_token,
            method,
            path,
            request_body,
            query
        );
    }

    internal async Json.Object request_json_unwrapped(string method, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                                      string path,
                                                      string? request_body,
                                                      HashTable<string, string>? query) throws Error {
        return yield ApiClientTransport.request_json_unwrapped( // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
            transport,
            base_url,
            auth_token,
            method,
            path,
            request_body,
            query
        );
    }

    public async Json.Object request_json_unwrapped_for_tests(string method, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
                                                              string path,
                                                              string? request_body,
                                                              HashTable<string, string>? query = null) throws Error {
        return yield request_json_unwrapped(method, path, request_body, query); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
    }

    internal string json_string_from_builder(Json.Builder builder) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return ApiClientTransport.json_string_from_builder(builder);
    }
}

public class DefaultApiFactory : Object, IApiFactory {
    public IHolderApi create(string base_url, string auth_token) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: delegation-only branch artifact
        return new ApiClient(base_url, auth_token);
    }
}

}
