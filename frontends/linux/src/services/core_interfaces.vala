namespace HolderLinux {

public delegate void AiRunEventHandler(string event_name, Json.Object data);

public interface IHolderApi : Object {
    public abstract async void health_check() throws Error;
    public abstract async HealthInfo get_health_info() throws Error;
    public abstract async Gee.ArrayList<Project> list_projects() throws Error;
    public abstract async string create_project(string name,
                                                string privacy_mode = "encrypted_git") throws Error;
    public abstract async ProjectRecoveryTokenExport export_project_recovery_token(
        string project_id,
        string pin
    ) throws Error;
    public abstract async void import_project_recovery_token(
        string project_id,
        string pin,
        string recovery_token
    ) throws Error;
    public abstract async RecoveryTokenImportResult import_recovery_token(
        string pin,
        string recovery_token
    ) throws Error;
    public abstract async Gee.ArrayList<CardSummary> list_cards(string project_id,
                                                                 string view = "tree",
                                                                 string? parent_card_id = null,
                                                                 int limit = 0) throws Error;
    public abstract async CardContextData get_card_context(string project_id,
                                                           string? parent_card_id = null) throws Error;
    public abstract async CardDetail get_card(string card_id) throws Error;
    public abstract async Gee.ArrayList<CardLink> list_card_links(string card_id) throws Error;
    public abstract async Gee.ArrayList<CardLink> list_card_backlinks(string card_id) throws Error;
    public abstract async Gee.ArrayList<ProjectResource> list_resources(string project_id) throws Error;
    public abstract async Gee.ArrayList<TrashItem> list_trash_items(string project_id,
                                                                     string type = "all") throws Error;
    public abstract async void empty_trash(string project_id, string type = "all") throws Error;
    public abstract async void restore_trash_item(string item_type, string item_id) throws Error;
    public abstract async void hard_delete_trash_item(string item_type, string item_id) throws Error;
    public abstract async string create_resource(string project_id,
                                                 string kind,
                                                 string uri,
                                                 string label,
                                                 string? desc = null) throws Error;
    public abstract async void update_resource(string resource_id,
                                               string? kind,
                                               string? uri,
                                               string? label,
                                               string? desc,
                                               int64 updated_at) throws Error;
    public abstract async void delete_resource(string resource_id) throws Error;
    public abstract async CardLink create_card_link(string from_card_id,
                                                    string to_card_id,
                                                    string kind = "ref",
                                                    string? label = null,
                                                    string to_type = "card") throws Error;
    public abstract async void delete_card_link(string from_card_id,
                                                string to_card_id,
                                                string kind,
                                                string to_type = "card") throws Error;
    public abstract async Gee.ArrayList<SearchCardResult> search_cards(string project_id,
                                                                       string query_text,
                                                                       int limit = 30) throws Error;
    public abstract async AiCapabilitiesInfo get_ai_capabilities(string? project_id = null) throws Error;
    public abstract async AiStatusInfo get_ai_status() throws Error;
    public abstract async string start_ai_runner_pull(string model_tag) throws Error;
    public abstract async Gee.ArrayList<AiThreadSummary> list_ai_threads(string project_id) throws Error;
    public abstract async string create_ai_thread(string project_id, string title) throws Error;
    public abstract async Gee.ArrayList<AiCatalogProvider> list_ai_provider_catalog() throws Error;
    public abstract async Gee.ArrayList<GitProviderCatalogEntry> list_git_provider_catalog() throws Error;
    public abstract async void set_project_git_remote(string project_id,
                                                      string? git_remote_url,
                                                      int64 updated_at) throws Error;
    public abstract async GitTestRemoteResult test_project_git_remote(string project_id,
                                                                      string? remote_url = null,
                                                                      string branch = "") throws Error;
    public abstract async GitPushResult push_project_git(string project_id,
                                                         string branch = "",
                                                         bool set_upstream = true) throws Error;
    public abstract async void run_ai_stream(string prompt,
                                             string? project_id,
                                             string? thread_id,
                                             string? context_card_id,
                                             string? context_card_title,
                                             string? context_card_body,
                                             AiRunEventHandler on_event) throws Error;
    public abstract async string create_card(string project_id,
                                             string title,
                                             string content,
                                             string? parent_card_id = null) throws Error;
    public abstract async void update_card(string card_id,
                                           string title,
                                           string content,
                                           int64 updated_at) throws Error;
    public abstract async void update_card_position(string card_id,
                                                    string? parent_card_id,
                                                    double sort_key,
                                                    int64 updated_at) throws Error;
    public abstract async void delete_card(string card_id) throws Error;
    public abstract async CardMoveResult move_card(string card_id,
                                                   string project_id,
                                                   string intent,
                                                   string? target_card_id = null,
                                                   string? parent_card_id = null) throws Error;
}

public interface IApiFactory : Object {
    public abstract IHolderApi create(string base_url, string auth_token);
}

public interface IServerDiscovery : Object {
    public abstract ServerInfo discover_server() throws Error;
    public abstract string holder_info_path();
}

public interface IClock : Object {
    public abstract int64 now_epoch_seconds();
}

public class SystemClock : Object, IClock {
    public int64 now_epoch_seconds() {
        return new DateTime.now_utc().to_unix();
    }
}

public interface IScheduler : Object {
    public abstract uint schedule_once(uint delay_ms, owned SourceFunc callback);
    public abstract uint schedule_repeating(uint interval_ms, owned SourceFunc callback);
    public abstract bool cancel(uint source_id);
}

public interface ISelectionState : Object {
    public abstract Object? get_selected_item();
    public abstract uint get_selected_index();
    public abstract void set_selected_index(uint index);
}

public interface ITextProvider : Object {
    public abstract string get_text();
}

public class MainLoopScheduler : Object, IScheduler {
    public uint schedule_once(uint delay_ms, owned SourceFunc callback) {
        return Timeout.add(delay_ms, () => {
            callback();
            return Source.REMOVE;
        });
    }

    public uint schedule_repeating(uint interval_ms, owned SourceFunc callback) {
        return Timeout.add(interval_ms, (owned) callback);
    }

    public bool cancel(uint source_id) {
        if (source_id == 0) {
            return false;
        }
        return Source.remove(source_id);
    }
}

public interface IAiRunContext : Object {
    public abstract IHolderApi? get_api_client();
    public abstract string? selected_project_id();
    public abstract Project? get_current_project();
    public abstract CardDetail? get_current_card();
    public abstract AiThreadSummary? get_current_ai_thread();
    public abstract int64 now_epoch_seconds();
    public abstract async string create_ai_thread(string title) throws Error;
    public abstract async void reload_ai_threads_for_project(string project_id);
    public abstract bool select_ai_thread_by_id(string thread_id);
}

public interface IRecoveryContext : Object {
    public abstract IHolderApi? get_api_client();
    public abstract async void reload_everything();
}

}
