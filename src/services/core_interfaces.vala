namespace HolderLinux {

public delegate void AiRunEventHandler(string event_name, Json.Object data);

public interface IHolderApi : Object {
    public abstract async void health_check() throws Error;
    public abstract async Gee.ArrayList<Project> list_projects() throws Error;
    public abstract async string create_project(string name) throws Error;
    public abstract async Gee.ArrayList<CardSummary> list_cards(string project_id) throws Error;
    public abstract async CardDetail get_card(string card_id) throws Error;
    public abstract async Gee.ArrayList<SearchCardResult> search_cards(string project_id,
                                                                       string query_text,
                                                                       int limit = 30) throws Error;
    public abstract async AiCapabilitiesInfo get_ai_capabilities(string? project_id = null) throws Error;
    public abstract async AiStatusInfo get_ai_status() throws Error;
    public abstract async string start_ai_runner_pull(string model_tag) throws Error;
    public abstract async Gee.ArrayList<AiThreadSummary> list_ai_threads(string project_id) throws Error;
    public abstract async string create_ai_thread(string project_id, string title) throws Error;
    public abstract async Gee.ArrayList<AiCatalogProvider> list_ai_provider_catalog() throws Error;
    public abstract async void run_ai_stream(string prompt,
                                             string? project_id,
                                             string? thread_id,
                                             string? context_card_id,
                                             string? context_card_title,
                                             string? context_card_body,
                                             AiRunEventHandler on_event) throws Error;
    public abstract async string create_card(string project_id,
                                             string title,
                                             string content) throws Error;
    public abstract async void update_card(string card_id,
                                           string title,
                                           string content,
                                           int64 updated_at) throws Error;
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

}
