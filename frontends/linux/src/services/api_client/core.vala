namespace HolderLinux {

public class ApiClient : Object, IHolderApi {
    private IApiHttpTransport transport;
    private string base_url;
    private string auth_token;

    public ApiClient(string base_url, string auth_token, IApiHttpTransport? transport = null) {
        this.base_url = base_url;
        this.auth_token = auth_token;
        this.transport = transport ?? new SoupApiHttpTransport();
    }

    // Health
    public async void health_check() throws Error {
        yield ApiClientHealthEndpoints.health_check(this);
    }

    public async HealthInfo get_health_info() throws Error {
        return yield ApiClientHealthEndpoints.get_health_info(this);
    }

    // Projects
    public async Gee.ArrayList<Project> list_projects() throws Error {
        return yield ApiClientProjectsEndpoints.list_projects(this);
    }

    public async string create_project(string name,
                                       string privacy_mode = "encrypted_git") throws Error {
        return yield ApiClientProjectsEndpoints.create_project(this, name, privacy_mode);
    }

    public async ProjectRecoveryTokenExport export_project_recovery_token(
        string project_id,
        string pin
    ) throws Error {
        return yield ApiClientProjectsEndpoints.export_project_recovery_token(this, project_id, pin);
    }

    public async void import_project_recovery_token(
        string project_id,
        string pin,
        string recovery_token
    ) throws Error {
        yield ApiClientProjectsEndpoints.import_project_recovery_token(this, project_id, pin, recovery_token);
    }

    public async RecoveryTokenImportResult import_recovery_token(
        string pin,
        string recovery_token
    ) throws Error {
        return yield ApiClientProjectsEndpoints.import_recovery_token(this, pin, recovery_token);
    }

    // Cards
    public async Gee.ArrayList<CardSummary> list_cards(string project_id,
                                                       string view = "tree",
                                                       string? parent_card_id = null,
                                                       int limit = 0) throws Error {
        return yield ApiClientCardsEndpoints.list_cards(this, project_id, view, parent_card_id, limit);
    }

    public async CardContextData get_card_context(string project_id,
                                                  string? parent_card_id = null) throws Error {
        return yield ApiClientCardsEndpoints.get_card_context(this, project_id, parent_card_id);
    }

    public async CardDetail get_card(string card_id) throws Error {
        return yield ApiClientCardsEndpoints.get_card(this, card_id);
    }

    public async string create_card(string project_id,
                                    string title,
                                    string content,
                                    string? parent_card_id = null) throws Error {
        return yield ApiClientCardsEndpoints.create_card(this, project_id, title, content, parent_card_id);
    }

    public async void update_card(string card_id,
                                  string title,
                                  string content,
                                  int64 updated_at) throws Error {
        yield ApiClientCardsEndpoints.update_card(this, card_id, title, content, updated_at);
    }

    public async void update_card_position(string card_id,
                                           string? parent_card_id,
                                           double sort_key,
                                           int64 updated_at) throws Error {
        yield ApiClientCardsEndpoints.update_card_position(
            this, card_id, parent_card_id, sort_key, updated_at
        );
    }

    public async CardMoveResult move_card(string card_id,
                                          string project_id,
                                          string intent,
                                          string? target_card_id = null,
                                          string? parent_card_id = null) throws Error {
        return yield ApiClientCardsEndpoints.move_card(
            this, card_id, project_id, intent, target_card_id, parent_card_id
        );
    }

    public async Gee.ArrayList<CardLink> list_card_links(string card_id) throws Error {
        return yield ApiClientCardsEndpoints.list_card_links(this, card_id);
    }

    public async Gee.ArrayList<CardLink> list_card_backlinks(string card_id) throws Error {
        return yield ApiClientCardsEndpoints.list_card_backlinks(this, card_id);
    }

    public async CardLink create_card_link(string from_card_id,
                                           string to_card_id,
                                           string kind = "ref",
                                           string? label = null,
                                           string to_type = "card") throws Error {
        return yield ApiClientCardsEndpoints.create_card_link(
            this, from_card_id, to_card_id, kind, label, to_type
        );
    }

    public async void delete_card_link(string from_card_id,
                                       string to_card_id,
                                       string kind,
                                       string to_type = "card") throws Error {
        yield ApiClientCardsEndpoints.delete_card_link(this, from_card_id, to_card_id, kind, to_type);
    }

    // Resources
    public async Gee.ArrayList<ProjectResource> list_resources(string project_id) throws Error {
        return yield ApiClientResourcesEndpoints.list_resources(this, project_id);
    }

    public async string create_resource(string project_id,
                                        string kind,
                                        string uri,
                                        string label,
                                        string? desc = null) throws Error {
        return yield ApiClientResourcesEndpoints.create_resource(this, project_id, kind, uri, label, desc);
    }

    public async void update_resource(string resource_id,
                                      string? kind,
                                      string? uri,
                                      string? label,
                                      string? desc,
                                      int64 updated_at) throws Error {
        yield ApiClientResourcesEndpoints.update_resource(
            this, resource_id, kind, uri, label, desc, updated_at
        );
    }

    public async void delete_resource(string resource_id) throws Error {
        yield ApiClientResourcesEndpoints.delete_resource(this, resource_id);
    }

    // Trash
    public async Gee.ArrayList<TrashItem> list_trash_items(string project_id,
                                                           string type = "all") throws Error {
        return yield ApiClientTrashEndpoints.list_trash_items(this, project_id, type);
    }

    public async void empty_trash(string project_id, string type = "all") throws Error {
        yield ApiClientTrashEndpoints.empty_trash(this, project_id, type);
    }

    public async void restore_trash_item(string item_type, string item_id) throws Error {
        yield ApiClientTrashEndpoints.restore_trash_item(this, item_type, item_id);
    }

    public async void hard_delete_trash_item(string item_type, string item_id) throws Error {
        yield ApiClientTrashEndpoints.hard_delete_trash_item(this, item_type, item_id);
    }

    // Search
    public async Gee.ArrayList<SearchCardResult> search_cards(string project_id,
                                                              string query_text,
                                                              int limit = 30) throws Error {
        return yield ApiClientSearchEndpoints.search_cards(this, project_id, query_text, limit);
    }

    // AI
    public async AiCapabilitiesInfo get_ai_capabilities(string? project_id = null) throws Error {
        return yield ApiClientAiEndpoints.get_ai_capabilities(this, project_id);
    }

    public async AiStatusInfo get_ai_status() throws Error {
        return yield ApiClientAiEndpoints.get_ai_status(this);
    }

    public async string start_ai_runner_pull(string model_tag) throws Error {
        return yield ApiClientAiEndpoints.start_ai_runner_pull(this, model_tag);
    }

    public async Gee.ArrayList<AiThreadSummary> list_ai_threads(string project_id) throws Error {
        return yield ApiClientAiEndpoints.list_ai_threads(this, project_id);
    }

    public async string create_ai_thread(string project_id, string title) throws Error {
        return yield ApiClientAiEndpoints.create_ai_thread(this, project_id, title);
    }

    public async Gee.ArrayList<AiCatalogProvider> list_ai_provider_catalog() throws Error {
        return yield ApiClientAiEndpoints.list_ai_provider_catalog(this);
    }

    public async void run_ai_stream(string prompt,
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
    public async Gee.ArrayList<GitProviderCatalogEntry> list_git_provider_catalog() throws Error {
        return yield ApiClientGitEndpoints.list_git_provider_catalog(this);
    }

    public async void set_project_git_remote(string project_id,
                                             string? git_remote_url,
                                             int64 updated_at) throws Error {
        yield ApiClientGitEndpoints.set_project_git_remote(this, project_id, git_remote_url, updated_at);
    }

    public async GitTestRemoteResult test_project_git_remote(string project_id,
                                                             string? remote_url = null,
                                                             string branch = "") throws Error {
        return yield ApiClientGitEndpoints.test_project_git_remote(this, project_id, remote_url, branch);
    }

    public async GitPushResult push_project_git(string project_id,
                                                string branch = "",
                                                bool set_upstream = true) throws Error {
        return yield ApiClientGitEndpoints.push_project_git(this, project_id, branch, set_upstream);
    }

    // Transport internals
    internal async Json.Object request_json(string method,
                                            string path,
                                            string? request_body,
                                            HashTable<string, string>? query) throws Error {
        return yield ApiClientTransport.request_json(
            transport,
            base_url,
            auth_token,
            method,
            path,
            request_body,
            query
        );
    }

    internal async Json.Object request_json_unwrapped(string method,
                                                      string path,
                                                      string? request_body,
                                                      HashTable<string, string>? query) throws Error {
        return yield ApiClientTransport.request_json_unwrapped(
            transport,
            base_url,
            auth_token,
            method,
            path,
            request_body,
            query
        );
    }

    public async Json.Object request_json_unwrapped_for_tests(string method,
                                                              string path,
                                                              string? request_body,
                                                              HashTable<string, string>? query = null) throws Error {
        return yield request_json_unwrapped(method, path, request_body, query);
    }

    internal string json_string_from_builder(Json.Builder builder) {
        return ApiClientTransport.json_string_from_builder(builder);
    }
}

public class DefaultApiFactory : Object, IApiFactory {
    public IHolderApi create(string base_url, string auth_token) {
        return new ApiClient(base_url, auth_token);
    }
}

}
