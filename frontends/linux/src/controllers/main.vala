namespace HolderLinux {

public class MainController : Object, IAiRunContext {
    private const uint LOADING_STATUS_DEBOUNCE_MS = 300;
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
    internal Project? current_project;
    internal CardDetail? current_card;
    internal AiThreadSummary? current_ai_thread;

    internal bool create_card_in_flight = false;
    internal uint autosave_id = 0;
    internal uint search_debounce_id = 0;
    internal uint card_loading_status_id = 0;
    internal uint project_cards_loading_status_id = 0;
    private uint project_overview_request_serial = 0;
    private bool reconnect_in_flight = false;

    private ProjectsController projects_controller;
    private CardsController cards_controller;
    private SearchController search_controller;
    private AiThreadsController ai_threads_controller;
    private IExplorerStateSink? explorer_state_sink;
    // LCOV_EXCL_STOP

    public signal void status_changed(string text);
    public signal void editor_state_changed(string text, bool editable);
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
                          IExplorerStateSink? explorer_state_sink = null) {
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
        this.api = initial_api;
        this.explorer_state_sink = explorer_state_sink;
        this.projects_controller = new ProjectsController(this);
        this.cards_controller = new CardsController(this);
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
        status_changed("Discovering local server...");
        editor_state_changed("# Loading\n\nDiscovering local server...", false);

        ServerInfo info;
        try {
            info = server_discovery.discover_server();
        } catch (Error e) {
            status_changed(e.message);
            editor_state_changed(
                "# Holder Not Found\n\n" +
                "Start the backend first, then reopen this app.\n\n" +
                "Expected file:\n`%s`\n".printf(server_discovery.holder_info_path()),
                false
            );
            return;
        }

        api = api_factory.create(info.base_url(), info.auth_token);
        api_client_ready(api);

        status_changed("Checking API health...");
        editor_state_changed("# Loading\n\nChecking API health...", false);
        try {
            yield api.health_check();
        } catch (Error e) {
            status_changed("Health check failed");
            editor_state_changed(
                "# Health Check Failed\n\n" +
                "Could not connect to the Holder API.\n\n" +
                e.message,
                false
            );
            error_reported("Health check failed", e.message);
            return;
        }

        status_changed("Connected to %s:%d (API %s)".printf(info.bind, info.port, info.api_version));
        yield ensure_first_project();
        yield reload_everything();
        ai_status_refresh_requested();
    }

    public async void reload_everything() {
        var preferred_project_id = selected_project_id();
        var preferred_card_id = selected_card_id();
        yield reload_everything_with_selection(preferred_project_id, preferred_card_id);
    }

    public async void show_project_overview() {
        project_overview_request_serial++;
        var request_serial = project_overview_request_serial;
        var selected = project_selection.get_selected_item() as Project;
        if (selected == null) {
            current_project = null;
            current_card = null;
            set_editor_view_state("# No Project Selected\n\nSelect a project to view its overview.", false);
            return;
        }
        var selected_project_id = selected.project_id;

        current_project = selected;
        current_card = null;

        int card_count = (int) card_store.get_n_items();
        int thread_count = (int) ai_thread_store.get_n_items();
        string resources_text = "unknown";
        if (api != null) {
            try {
                var resources = yield api.list_resources(selected.project_id);
                if (request_serial != project_overview_request_serial) {
                    return;
                }
                resources_text = resources.size.to_string();
            } catch (Error e) {
                if (request_serial != project_overview_request_serial) {
                    return;
                }
                resources_text = "unknown";
            }
        }

        if (request_serial != project_overview_request_serial) {
            return;
        }
        var latest_selected = project_selection.get_selected_item() as Project;
        if (latest_selected == null || latest_selected.project_id != selected_project_id) {
            return;
        }

        set_editor_view_state(build_project_overview_text(selected, card_count, resources_text, thread_count), false);
        show_editor_requested();
        window_title_changed(selected.name);
        status_changed("Loaded project overview");
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

    public async string? prepare_search_result_card_at(uint position) {
        return yield search_controller.prepare_search_result_card_at(position);
    }

    public void schedule_autosave() {
        cards_controller.schedule_autosave();
    }

    public async void autosave_current_card() {
        yield cards_controller.autosave_current_card();
    }

    public bool has_unsaved_editor_changes() {
        return editor_draft_state.has_unsaved_changes(current_card, editor_text);
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
        if (api == null) {
            return;
        }

        status_changed("Refreshing projects...");
        try {
            var projects = yield api.list_projects();
            replace_projects(projects);
            if (project_store.get_n_items() == 0) {
                current_project = null;
                clear_cards();
                set_editor_view_state("# No Projects\n\nCreate a project to start writing.", false);
                return;
            }

            var selected = false;
            if (preferred_project_id != null && has_project_summary(preferred_project_id)) {
                project_selection_requested(preferred_project_id);
                selected = true;
            }
            if (!selected) {
                var first_project = project_store.get_item(0) as Project;
                if (first_project != null) {
                    project_selection_requested(first_project.project_id);
                }
            }
            var loaded = yield reload_selected_project_cards_data();
            if (!loaded) {
                return;
            }
            if (preferred_card_id != null) {
                if (has_card_summary(preferred_card_id)) {
                    card_selection_requested(preferred_card_id);
                } else if (card_store.get_n_items() > 0) {
                    var first_card = card_store.get_item(0) as CardSummary;
                    if (first_card != null) {
                        card_selection_requested(first_card.card_id);
                    }
                }
            } else {
                card_selection_requested(null);
            }
            ai_status_refresh_requested();
        } catch (Error e) {
            if (allow_retry && (yield try_reconnect_after_transport_error(e))) {
                yield reload_everything_with_selection(preferred_project_id, preferred_card_id, false);
                return;
            }
            error_reported("Failed to refresh", e.message);
        }
    }

    internal async void reload_cards_for_selected_project() {
        var loaded = yield reload_selected_project_cards_data();
        if (!loaded) {
            return;
        }
        card_selection_requested(null);
    }

    internal async bool reload_selected_project_cards_data(bool allow_retry = true) {
        if (api == null) {
            return false;
        }

        var selected = project_selection.get_selected_item() as Project;
        if (selected == null) {
            // Keep committed sidebar/editor state during transient deselection
            // while a newer selection is resolving.
            return false;
        }

        current_project = selected;
        window_title_changed(selected.name);
        if (project_cards_loading_status_id != 0) {
            scheduler.cancel(project_cards_loading_status_id);
            project_cards_loading_status_id = 0;
        }
        var requested_project_id = selected.project_id;
        var requested_project_name = selected.name;
        project_cards_loading_status_id = scheduler.schedule_once(LOADING_STATUS_DEBOUNCE_MS, () => {
            project_cards_loading_status_id = 0;
            var still_selected = project_selection.get_selected_item() as Project;
            if (still_selected != null && still_selected.project_id == requested_project_id) {
                status_changed("Loading cards for %s...".printf(requested_project_name));
            }
            return Source.REMOVE;
        });

        try {
            var cards = yield api.list_cards(selected.project_id, "recent");
            var latest_selected = project_selection.get_selected_item() as Project;
            if (latest_selected == null || latest_selected.project_id != requested_project_id) {
                return false;
            }
            if (project_cards_loading_status_id != 0) {
                scheduler.cancel(project_cards_loading_status_id);
                project_cards_loading_status_id = 0;
            }
            replace_cards(cards);
            yield reload_ai_threads_for_project(selected.project_id);
            return true;
        } catch (Error e) {
            if (project_cards_loading_status_id != 0) {
                scheduler.cancel(project_cards_loading_status_id);
                project_cards_loading_status_id = 0;
            }
            var latest_selected = project_selection.get_selected_item() as Project;
            if (latest_selected == null || latest_selected.project_id != requested_project_id) {
                return false;
            }
            if (allow_retry && (yield try_reconnect_after_transport_error(e))) {
                return yield reload_selected_project_cards_data(false);
            }
            error_reported("Failed to load cards", e.message);
            return false;
        }
    }

    private string build_project_overview_text(Project project,
                                               int card_count,
                                               string resource_count_text,
                                               int thread_count) {
        var sb = new StringBuilder();
        sb.append("# %s\n\n".printf(project.name));
        sb.append("## Overview\n");
        sb.append("- Cards: %d\n".printf(card_count));
        sb.append("- Resources: %s\n".printf(resource_count_text));
        sb.append("- AI Threads: %d\n\n".printf(thread_count));
        sb.append("## Sync\n");
        sb.append("- Visibility: %s\n\n".printf(project_visibility_label(project)));
        sb.append("## Metadata\n");
        sb.append("- Project ID: `%s`\n".printf(project.project_id));
        sb.append("- Root Path: `%s`\n".printf(project.root_path));
        sb.append("- Created: %s\n".printf(format_timestamp(project.created_at)));
        sb.append("- Updated: %s\n".printf(format_timestamp(project.updated_at)));
        return sb.str;
    }

    private string project_visibility_label(Project project) {
        return project.privacy_mode == "plain" ? "Shared" : "Private";
    }

    private string format_timestamp(int64 epoch) {
        if (epoch <= 0) {
            return "unknown";
        }
        var dt = new DateTime.from_unix_local(epoch);
        return dt.format("%Y-%m-%d %H:%M");
    }

    internal async void load_card_by_id(string requested_card_id, bool allow_retry = true) {
        if (api == null) {
            return;
        }

        if (card_loading_status_id != 0) {
            scheduler.cancel(card_loading_status_id);
            card_loading_status_id = 0;
        }
        card_loading_status_id = scheduler.schedule_once(LOADING_STATUS_DEBOUNCE_MS, () => {
            card_loading_status_id = 0;
            if (selected_card_id() == requested_card_id) {
                status_changed("Loading card...");
            }
            return Source.REMOVE;
        });
        try {
            var card = yield api.get_card(requested_card_id);
            if (card_loading_status_id != 0) {
                scheduler.cancel(card_loading_status_id);
                card_loading_status_id = 0;
            }
            if (selected_card_id() != requested_card_id) {
                return;
            }
            current_card = card;
            set_loaded_card_editor_state(card);
            show_editor_requested();
            window_title_changed(card.title);
            status_changed("Loaded %s".printf(card.title));
        } catch (Error e) {
            if (card_loading_status_id != 0) {
                scheduler.cancel(card_loading_status_id);
                card_loading_status_id = 0;
            }
            if (selected_card_id() != requested_card_id) {
                return;
            }
            if (allow_retry && (yield try_reconnect_after_transport_error(e))) {
                yield load_card_by_id(requested_card_id, false);
                return;
            }
            status_changed("Failed to load card.");
            error_reported("Failed to load card", e.message);
        }
    }

    private bool is_transport_error_message(string message) {
        var lower = message.down();
        return lower.contains("connection")
            || lower.contains("connect")
            || lower.contains("refused")
            || lower.contains("timed out")
            || lower.contains("socket")
            || lower.contains("network")
            || lower.contains("http 401")
            || lower.contains("unauthorized")
            || lower.contains("could not resolve")
            || lower.contains("unreachable");
    }

    private async bool try_reconnect_after_transport_error(Error e) {
        if (!is_transport_error_message(e.message)) {
            return false;
        }
        if (reconnect_in_flight) {
            return false;
        }
        reconnect_in_flight = true;
        try {
            status_changed("Reconnecting to backend...");
            var info = server_discovery.discover_server();
            api = api_factory.create(info.base_url(), info.auth_token);
            api_client_ready(api);
            try {
                yield ((!) api).health_check();
            } catch (Error health_error) {
                warning("Reconnect health-check failed: %s", health_error.message);
                return false;
            }
            status_changed("Reconnected to %s:%d".printf(info.bind, info.port));
            ai_status_refresh_requested();
            return true;
        } catch (Error reconnect_error) {
            warning("Reconnect failed: %s", reconnect_error.message);
            return false;
        } finally {
            reconnect_in_flight = false;
        }
    }

    internal void replace_projects(Gee.ArrayList<Project> projects) {
        project_store.remove_all();
        foreach (var project in projects) {
            project_store.append(project);
        }
        if (explorer_state_sink != null) {
            ((!) explorer_state_sink).replace_projects_snapshot(projects);
        }
    }

    internal void replace_cards(Gee.ArrayList<CardSummary> cards) {
        cards.sort((a, b) => compare_cards_for_sidebar(a, b));
        card_store.remove_all();
        foreach (var card in cards) {
            card_store.append(card);
        }
        if (explorer_state_sink != null) {
            ((!) explorer_state_sink).replace_cards_snapshot(cards);
        }
    }

    internal void replace_ai_threads(Gee.ArrayList<AiThreadSummary> threads) {
        ai_thread_store.remove_all();
        foreach (var thread in threads) {
            ai_thread_store.append(thread);
        }
        if (explorer_state_sink != null) {
            ((!) explorer_state_sink).replace_ai_threads_snapshot(threads);
        }
    }

    internal void clear_cards() {
        card_store.remove_all();
        current_card = null;
        ai_thread_store.remove_all();
        current_ai_thread = null;
        ai_thread_title_changed(null);
        if (explorer_state_sink != null) {
            ((!) explorer_state_sink).replace_cards_snapshot(new Gee.ArrayList<CardSummary>());
            ((!) explorer_state_sink).replace_ai_threads_snapshot(new Gee.ArrayList<AiThreadSummary>());
        }
    }

    internal void replace_search_results(Gee.ArrayList<SearchCardResult> results) {
        search_store.remove_all();
        foreach (var result in results) {
            search_store.append(result);
        }
        if (results.size > 0) {
            search_selection_requested(0);
            return;
        }
        search_selection_requested(-1);
    }

    internal bool has_card_summary(string card_id) {
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null && card.card_id == card_id) {
                return true;
            }
        }
        return false;
    }

    internal bool has_project_summary(string project_id) {
        for (uint i = 0; i < project_store.get_n_items(); i++) {
            var project = project_store.get_item(i) as Project;
            if (project != null && project.project_id == project_id) {
                return true;
            }
        }
        return false;
    }

    internal void update_selected_card_summary(string title, int64 updated_at) {
        if (current_card == null) {
            return;
        }
        var target_card_id = current_card.card_id;
        var source_cards = new Gee.ArrayList<CardSummary?>();
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            source_cards.add(card_store.get_item(i) as CardSummary);
        }
        var updated_cards = rebuild_card_summaries(source_cards, target_card_id, title, updated_at);
        card_store.remove_all();
        foreach (var card in updated_cards) {
            card_store.append(card);
        }
        if (explorer_state_sink != null) {
            ((!) explorer_state_sink).replace_cards_snapshot(updated_cards);
        }
        // Keep the current editor draft in place after autosave. The refreshed
        // card snapshot will fan out through app state to sidebar/flowboard/
        // connections without re-entering the card-open navigation path.
    }

    public static Gee.ArrayList<CardSummary> rebuild_card_summaries(
        Gee.ArrayList<CardSummary?> source_cards,
        string target_card_id,
        string title,
        int64 updated_at
    ) {
        var updated_cards = new Gee.ArrayList<CardSummary>();
        foreach (var card in source_cards) {
            if (card == null) {
                continue;
            }
            if (card.card_id != target_card_id) {
                updated_cards.add(card);
                continue;
            }
            updated_cards.add(new CardSummary(
                card.card_id,
                card.project_id,
                title,
                card.rel_path,
                card.sort_key,
                card.parent_card_id,
                card.created_at,
                updated_at
            ));
        }
        return updated_cards;
    }

    internal static int compare_cards_for_sidebar(CardSummary a, CardSummary b) {
        if (a.updated_at > b.updated_at) {
            return -1;
        }
        if (a.updated_at < b.updated_at) {
            return 1;
        }
        return strcmp(a.title.down(), b.title.down());
    }

    internal void set_editor_view_state(string text, bool editable) {
        editor_draft_state.reset_to_view_state(text, editable);
        editor_state_changed(text, editable);
    }

    internal void set_loaded_card_editor_state(CardDetail card) {
        editor_draft_state.load_card_state(card.card_id, card.content);
        editor_state_changed(card.content, true);
    }
}

}
