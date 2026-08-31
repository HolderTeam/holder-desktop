namespace HolderLinux {

public class MainController : Object, IAiRunContext {
    internal const uint LOADING_STATUS_DEBOUNCE_MS = 300;
    // LCOV_EXCL_START: field declaration-only coverage artifacts
    internal GLib.ListStore project_store;
    internal ISelectionState project_selection;
    internal GLib.ListStore card_store;
    internal ISelectionState card_selection;
    internal GLib.ListStore ai_thread_store;
    internal ISelectionState ai_thread_selection;
    internal GLib.ListStore search_store;
    internal ITextProvider search_text;
    internal ITextProvider editor_text;

    internal IHolderApi? api;
    internal IApiFactory api_factory;
    internal IServerDiscovery server_discovery;
    internal IClock clock;
    internal IScheduler scheduler;
    internal EditorDraftState editor_draft_state;
    internal Settings? settings;
    internal Project? current_project;
    internal CardDetail? current_card;
    internal AiThreadSummary? current_ai_thread;

    internal bool create_card_in_flight = false;
    internal uint search_debounce_id = 0;
    internal uint card_loading_status_id = 0;
    internal uint project_cards_loading_status_id = 0;

    private ProjectsController projects_controller;
    private CardsController cards_controller;
    private EditorSaveController editor_save_controller;
    private SearchController search_controller;
    private AiThreadsController ai_threads_controller;
    internal BackendSessionController backend_session_controller;
    private MainBootstrapController main_bootstrap_controller;
    private MainProjectFlowController main_project_flow_controller;
    private MainCardLoadController main_card_load_controller;
    private MainOverviewController main_overview_controller;
    private StoreSyncController store_sync_controller;
    internal IExplorerStateSink? explorer_state_sink;
    // LCOV_EXCL_STOP

    public signal void status_changed(string text);
    public signal void editor_state_changed(string text, bool editable);
    public signal void editor_save_state_changed(string text);
    public signal void window_title_changed(string title_text);
    public signal void toast_requested(string message);
    public signal void error_reported(string title_text, string details);
    public signal void show_editor_requested();
    public signal void show_search_requested();
    public signal void search_summary_changed(string text);
    public signal void ai_status_refresh_requested();
    public signal void project_selection_requested(string? project_id);
    public signal void card_selection_requested(string? card_id);
    public signal void search_selection_requested(int position);
    public signal void ai_thread_title_changed(string? title);
    public signal void ai_thread_selection_requested(string? thread_id);
    public signal void api_client_ready(IHolderApi api);
    public signal void card_trashed(string card_id);
    public signal void activity_requested(string kind,
                                          string message,
                                          string? project_id,
                                          string? card_id,
                                          ActivityDetails? details);

    public MainController(GLib.ListStore project_store,
                          ISelectionState project_selection,
                          GLib.ListStore card_store,
                          ISelectionState card_selection,
                          GLib.ListStore ai_thread_store,
                          ISelectionState ai_thread_selection,
                          GLib.ListStore search_store,
                          ITextProvider search_text,
                          ITextProvider editor_text,
                          IApiFactory api_factory,
                          IServerDiscovery server_discovery,
                          IClock? clock = null,
                          IScheduler? scheduler = null,
                          IHolderApi? initial_api = null,
                          IExplorerStateSink? explorer_state_sink = null,
                          IEditorRecoveryDraftService? recovery_draft_service = null,
                          Settings? settings = null) {
        this.project_store = project_store;
        this.project_selection = project_selection;
        this.card_store = card_store;
        this.card_selection = card_selection;
        this.ai_thread_store = ai_thread_store;
        this.ai_thread_selection = ai_thread_selection;
        this.search_store = search_store;
        this.search_text = search_text;
        this.editor_text = editor_text;
        this.api_factory = api_factory;
        this.server_discovery = server_discovery;
        this.clock = clock ?? new SystemClock();
        this.scheduler = scheduler ?? new MainLoopScheduler();
        this.editor_draft_state = new EditorDraftState();
        this.settings = settings;
        this.api = initial_api;
        this.explorer_state_sink = explorer_state_sink;
        this.store_sync_controller = new StoreSyncController(this);
        this.backend_session_controller = new BackendSessionController(this);
        this.main_bootstrap_controller = new MainBootstrapController(this);
        this.main_project_flow_controller = new MainProjectFlowController(this);
        this.main_card_load_controller = new MainCardLoadController(this);
        this.main_overview_controller = new MainOverviewController(this);
        this.projects_controller = new ProjectsController(this);
        this.cards_controller = new CardsController(this);
        this.editor_save_controller = new EditorSaveController(this, recovery_draft_service);
        this.search_controller = new SearchController(this);
        this.ai_threads_controller = new AiThreadsController(this);
    }

    public IHolderApi? get_api_client() {
        return api;
    }

    public Project? get_current_project() {
        return current_project;
    }

    public CardDetail? get_current_card() {
        return current_card;
    }

    public AiThreadSummary? get_current_ai_thread() {
        return current_ai_thread;
    }

    public int64 now_epoch_seconds() {
        return clock.now_epoch_seconds();
    }

    internal void emit_activity(string kind,
                                string message,
                                string? project_id = null,
                                string? card_id = null,
                                ActivityDetails? details = null) {
        activity_requested(kind, message, project_id, card_id, details);
    }

    public string? selected_project_id() {
        var selected = project_selection.get_selected_item() as Project;
        if (selected == null) {
            return null;
        }
        return selected.project_id;
    }

    public string? selected_card_id() {
        var selected = card_selection.get_selected_item() as CardSummary;
        if (selected == null) {
            return null;
        }
        return selected.card_id;
    }

    public bool select_ai_thread_by_id(string thread_id) {
        return ai_threads_controller.select_ai_thread_by_id(thread_id);
    }

    public async string create_ai_thread(string title) throws Error {
        return yield ai_threads_controller.create_ai_thread(title);
    }

    public async Gee.ArrayList<AiMessage> list_ai_messages(string thread_id) throws Error {
        if (api == null) {
            throw new IOError.FAILED("No API context.");
        }
        return yield api.list_ai_messages(thread_id);
    }

    public async void bootstrap() {
        yield main_bootstrap_controller.bootstrap();
    }

    public async void reload_everything() {
        yield main_project_flow_controller.reload_everything();
    }

    public async void show_project_overview() {
        yield main_overview_controller.show_project_overview();
    }

    public void on_ai_thread_selected() {
        ai_threads_controller.on_ai_thread_selected();
    }

    public async void create_card(string? parent_card_id = null) {
        yield cards_controller.create_card(parent_card_id);
    }

    public async void create_card_with_title(string title, string? parent_card_id = null) {
        yield cards_controller.create_card_with_title(title, parent_card_id);
    }

    public async void run_search() {
        yield search_controller.run_search();
    }

    public void schedule_search() {
        search_controller.schedule_search();
    }

    public void cancel_pending_search() {
        search_controller.cancel_pending_search();
    }

    public void clear_search_results() {
        search_controller.clear_search_results();
    }

    public void show_resource_references(ProjectResource resource) {
        var results = new Gee.ArrayList<SearchCardResult>();
        foreach (var reference in resource.referenced_by_cards) {
            results.add(new SearchCardResult(
                reference.card_id,
                reference.title,
                reference.updated_at,
                reference.updated_at,
                resource_reference_snippet(reference),
                0.0
            ));
        }
        replace_search_results(results);
        search_summary_changed(
            "%d card(s) using “%s”".printf(results.size, resource.label)
        );
        show_search_requested();
    }

    private static string resource_reference_snippet(ResourceCardReference reference) {
        if (reference.link_kinds.size == 0) {
            return "Linked resource";
        }
        var labels = new Gee.ArrayList<string>();
        foreach (var kind in reference.link_kinds) {
            switch (kind) {
                case "attachment":
                    labels.add("Attachment");
                    break;
                case "reference":
                    labels.add("Reference");
                    break;
                default:
                    labels.add(kind.length > 0
                        ? kind.substring(0, 1).up() + kind.substring(1).replace("_", " ")
                        : "Linked");
                    break;
            }
        }
        return string.joinv(" · ", labels.to_array());
    }

    public async string? prepare_search_result_card_at(uint position) {
        return yield search_controller.prepare_search_result_card_at(position);
    }

    public void schedule_autosave() {
        editor_save_controller.schedule_autosave();
    }

    public async void autosave_current_card() {
        yield editor_save_controller.autosave_current_card();
    }

    public bool has_unsaved_editor_changes() {
        return editor_save_controller.has_unsaved_editor_changes();
    }

    public void on_editor_content_changed() {
        editor_save_controller.on_editor_content_changed();
    }

    public bool has_pending_autosave_retry() {
        return editor_save_controller.has_pending_autosave_retry();
    }

    public uint get_autosave_retry_attempts() {
        return editor_save_controller.get_autosave_retry_attempts();
    }

    public async void move_card_by_intent(string card_id,
                                          string intent,
                                          string? target_card_id = null,
                                          string? parent_card_id = null) {
        yield cards_controller.move_card_by_intent(card_id, intent, target_card_id, parent_card_id);
    }

    public async void move_card_to_trash(string card_id) {
        yield cards_controller.move_card_to_trash(card_id);
    }

    public async void create_project_named(string name, string privacy_mode = "encrypted_git") {
        yield projects_controller.create_project_named(name, privacy_mode);
    }

    public async void reload_ai_threads_for_project(string project_id,
                                                    string? preferred_thread_id = null) {
        yield ai_threads_controller.reload_ai_threads_for_project(project_id, preferred_thread_id);
    }

    internal async void ensure_first_project() {
        yield projects_controller.ensure_first_project();
    }

    internal async void reload_everything_with_selection(string? preferred_project_id,
                                                         string? preferred_card_id,
                                                         bool allow_retry = true) {
        yield main_project_flow_controller.reload_everything_with_selection(
            preferred_project_id,
            preferred_card_id,
            allow_retry
        );
    }

    internal async void reload_cards_for_selected_project() {
        yield main_project_flow_controller.reload_cards_for_selected_project();
    }

    internal async bool reload_selected_project_cards_data(bool allow_retry = true) {
        return yield main_project_flow_controller.reload_selected_project_cards_data(allow_retry);
    }

    internal async void load_card_by_id(string requested_card_id, bool allow_retry = true) {
        yield main_card_load_controller.load_card_by_id(requested_card_id, allow_retry);
    }

    internal void replace_projects(Gee.ArrayList<Project> projects) {
        store_sync_controller.replace_projects(projects);
    }

    internal void replace_cards(Gee.ArrayList<CardSummary> cards) {
        store_sync_controller.replace_cards(cards);
    }

    internal void replace_ai_threads(Gee.ArrayList<AiThreadSummary> threads) {
        store_sync_controller.replace_ai_threads(threads);
    }

    internal void clear_cards() {
        store_sync_controller.clear_cards();
    }

    internal void replace_search_results(Gee.ArrayList<SearchCardResult> results) {
        store_sync_controller.replace_search_results(results);
    }

    internal bool has_card_summary(string card_id) {
        return store_sync_controller.has_card_summary(card_id);
    }

    internal bool has_project_summary(string project_id) {
        return store_sync_controller.has_project_summary(project_id);
    }

    internal void update_selected_card_summary(string title, int64 updated_at) {
        store_sync_controller.update_selected_card_summary(title, updated_at);
    }

    public static Gee.ArrayList<CardSummary> rebuild_card_summaries(
        Gee.ArrayList<CardSummary?> source_cards,
        string target_card_id,
        string title,
        int64 updated_at
    ) {
        return StoreSyncController.rebuild_card_summaries(
            source_cards,
            target_card_id,
            title,
            updated_at
        );
    }

    internal void set_editor_view_state(string text, bool editable) {
        editor_save_controller.set_editor_view_state(text, editable);
    }

    internal void set_loaded_card_editor_state(CardDetail card) {
        editor_save_controller.set_loaded_card_editor_state(card);
    }

}

}
