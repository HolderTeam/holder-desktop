namespace HolderLinux {

public class MainController : Object, IAiRunContext {
    private GLib.ListStore project_store;
    private ISelectionState project_selection;
    private GLib.ListStore card_store;
    private ISelectionState card_selection;
    private GLib.ListStore ai_thread_store;
    private ISelectionState ai_thread_selection;
    private GLib.ListStore search_store;
    private ISelectionState search_selection;
    private ITextProvider search_text;
    private ITextProvider editor_text;

    private IHolderApi? api;
    private IApiFactory api_factory;
    private IServerDiscovery server_discovery;
    private IClock clock;
    private IScheduler scheduler;
    private Project? current_project;
    private CardDetail? current_card;
    private AiThreadSummary? current_ai_thread;

    private bool suppress_project_selection_events = false;
    private bool suppress_card_selection_events = false;
    private bool create_card_in_flight = false;
    private uint autosave_id = 0;
    private uint search_debounce_id = 0;

    public signal void status_changed(string text);
    public signal void editor_state_changed(string text, bool editable);
    public signal void window_title_changed(string title_text);
    public signal void toast_requested(string message);
    public signal void error_reported(string title_text, string details);
    public signal void show_editor_requested();
    public signal void show_search_requested();
    public signal void search_summary_changed(string text);
    public signal void ai_status_refresh_requested();
    public signal void ai_thread_title_changed(string? title);
    public signal void api_client_ready(IHolderApi api);

    public MainController(GLib.ListStore project_store,
                          ISelectionState project_selection,
                          GLib.ListStore card_store,
                          ISelectionState card_selection,
                          GLib.ListStore ai_thread_store,
                          ISelectionState ai_thread_selection,
                          GLib.ListStore search_store,
                          ISelectionState search_selection,
                          ITextProvider search_text,
                          ITextProvider editor_text,
                          IApiFactory api_factory,
                          IServerDiscovery server_discovery,
                          IClock? clock = null,
                          IScheduler? scheduler = null,
                          IHolderApi? initial_api = null) {
        this.project_store = project_store;
        this.project_selection = project_selection;
        this.card_store = card_store;
        this.card_selection = card_selection;
        this.ai_thread_store = ai_thread_store;
        this.ai_thread_selection = ai_thread_selection;
        this.search_store = search_store;
        this.search_selection = search_selection;
        this.search_text = search_text;
        this.editor_text = editor_text;
        this.api_factory = api_factory;
        this.server_discovery = server_discovery;
        this.clock = clock ?? new SystemClock();
        this.scheduler = scheduler ?? new MainLoopScheduler();
        this.api = initial_api;
    }

    public bool should_ignore_project_selection_events() {
        return suppress_project_selection_events;
    }

    public bool should_ignore_card_selection_events() {
        return suppress_card_selection_events;
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
        for (uint i = 0; i < ai_thread_store.get_n_items(); i++) {
            var thread = ai_thread_store.get_item(i) as AiThreadSummary;
            if (thread != null && thread.thread_id == thread_id) {
                ai_thread_selection.set_selected_index(i);
                return true;
            }
        }
        return false;
    }

    public async string create_ai_thread(string title) throws Error {
        if (api == null || current_project == null) {
            throw new IOError.FAILED("No project/API context.");
        }
        return yield api.create_ai_thread(current_project.project_id, title);
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

    public void on_project_selected() {
        reload_cards_for_selected_project.begin();
    }

    public void on_card_selected() {
        load_selected_card.begin();
    }

    public void on_ai_thread_selected() {
        var selected = ai_thread_selection.get_selected_item() as AiThreadSummary;
        current_ai_thread = selected;
        if (selected == null) {
            ai_thread_title_changed(null);
            return;
        }
        ai_thread_title_changed(selected.title);
    }

    public async void create_card() {
        if (create_card_in_flight) {
            status_changed("Create card already in progress...");
            return;
        }
        if (api == null) {
            error_reported("Create card unavailable", "API client is not connected.");
            return;
        }

        if (current_project == null) {
            var selected = project_selection.get_selected_item() as Project;
            if (selected != null) {
                current_project = selected;
            }
        }
        if (current_project == null) {
            error_reported("No project selected", "Select or create a project first.");
            return;
        }

        create_card_in_flight = true;
        status_changed("Creating new card...");
        try {
            var new_id = yield api.create_card(current_project.project_id, "Untitled", "# Untitled\n\n");
            var cards = yield api.list_cards(current_project.project_id);
            replace_cards(cards);

            for (uint i = 0; i < card_store.get_n_items(); i++) {
                var item = card_store.get_item(i) as CardSummary;
                if (item != null && item.card_id == new_id) {
                    card_selection.set_selected_index(i);
                    break;
                }
            }

            toast_requested("New card created");
            status_changed("Created new card");
        } catch (Error e) {
            error_reported("Failed to create card", e.message);
        } finally {
            create_card_in_flight = false;
        }
    }

    public async void run_search() {
        if (api == null) {
            return;
        }
        if (current_project == null) {
            error_reported("Search unavailable", "No project selected.");
            return;
        }

        var query_text = search_text.get_text().strip();
        if (query_text.length == 0) {
            clear_search_results();
            show_editor_requested();
            return;
        }

        status_changed("Searching for \"%s\"...".printf(query_text));
        try {
            var results = yield api.search_cards(current_project.project_id, query_text);
            replace_search_results(results);
            search_summary_changed("%d result(s) for \"%s\"".printf(results.size, query_text));
            show_search_requested();
            status_changed("Search complete");
        } catch (Error e) {
            error_reported("Search failed", e.message);
        }
    }

    public void schedule_search() {
        if (search_debounce_id != 0) {
            scheduler.cancel(search_debounce_id);
        }
        search_debounce_id = scheduler.schedule_once(300, () => {
            search_debounce_id = 0;
            run_search.begin();
            return Source.REMOVE;
        });
    }

    public void cancel_pending_search() {
        if (search_debounce_id == 0) {
            return;
        }
        scheduler.cancel(search_debounce_id);
        search_debounce_id = 0;
    }

    public void clear_search_results() {
        search_store.remove_all();
        search_summary_changed("Search results will appear here.");
    }

    public async void open_search_result_at(uint position) {
        var item = search_store.get_item(position) as SearchCardResult;
        if (item == null) {
            return;
        }

        if (!select_card_by_id(item.card_id)) {
            yield reload_cards_for_selected_project(item.card_id);
        } else {
            load_selected_card.begin();
        }
    }

    public void schedule_autosave() {
        if (autosave_id != 0) {
            scheduler.cancel(autosave_id);
        }

        autosave_id = scheduler.schedule_once(900, () => {
            autosave_id = 0;
            autosave_current_card.begin();
            return Source.REMOVE;
        });
    }

    public async void autosave_current_card() {
        if (api == null || current_card == null) {
            return;
        }

        var text = editor_text.get_text();
        var title = TextUtils.title_from_content(text);
        var updated_at = now_epoch_seconds();

        try {
            yield api.update_card(current_card.card_id, title, text, updated_at);
            current_card.title = title;
            current_card.content = text;
            current_card.updated_at = updated_at;
            update_selected_card_summary(title, updated_at);
            window_title_changed(title);
            status_changed("Saved %s".printf(TextUtils.format_relative_time(now_epoch_seconds(), updated_at)));
        } catch (Error e) {
            error_reported("Autosave failed", e.message);
        }
    }

    public async void create_project_named(string name) {
        if (api == null) {
            return;
        }

        status_changed("Creating project...");
        try {
            var project_id = yield api.create_project(name);
            toast_requested("Created project: %s".printf(name));
            status_changed("Project created");
            yield reload_everything_with_selection(project_id, null);
        } catch (Error e) {
            error_reported("Failed to create project", e.message);
        }
    }

    public async void reload_ai_threads_for_project(string project_id) {
        if (api == null) {
            return;
        }
        try {
            var threads = yield api.list_ai_threads(project_id);
            replace_ai_threads(threads);
            if (ai_thread_store.get_n_items() > 0) {
                ai_thread_selection.set_selected_index(0);
            } else {
                current_ai_thread = null;
                ai_thread_title_changed(null);
            }
        } catch (Error e) {
            error_reported("Failed to load AI threads", e.message);
        }
    }

    private async void ensure_first_project() {
        if (api == null) {
            return;
        }

        try {
            var projects = yield api.list_projects();
            if (projects.size == 0) {
                var project_id = yield api.create_project("My Project");
                toast_requested("Created first project (%s)".printf(project_id));
            }
        } catch (Error e) {
            error_reported("Project bootstrap failed", e.message);
        }
    }

    private async void reload_everything_with_selection(string? preferred_project_id,
                                                        string? preferred_card_id) {
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
                editor_state_changed("# No Projects\n\nCreate a project to start writing.", false);
                return;
            }

            var selected = false;
            if (preferred_project_id != null) {
                selected = select_project_by_id(preferred_project_id);
            }
            if (!selected) {
                suppress_project_selection_events = true;
                project_selection.set_selected_index(0);
                suppress_project_selection_events = false;
            }
            yield reload_cards_for_selected_project(preferred_card_id);
            ai_status_refresh_requested();
        } catch (Error e) {
            error_reported("Failed to refresh", e.message);
        }
    }

    private async void reload_cards_for_selected_project(string? preferred_card_id = null) {
        if (api == null) {
            return;
        }

        var selected = project_selection.get_selected_item() as Project;
        if (selected == null) {
            current_project = null;
            clear_cards();
            return;
        }

        current_project = selected;
        window_title_changed(selected.name);
        status_changed("Loading cards for %s...".printf(selected.name));

        try {
            var cards = yield api.list_cards(selected.project_id);
            replace_cards(cards);
            yield reload_ai_threads_for_project(selected.project_id);
            if (card_store.get_n_items() == 0) {
                current_card = null;
                editor_state_changed(
                    "# %s\n\nNo cards yet. Create one with the + button.".printf(selected.name),
                    false
                );
                return;
            }

            var selected_card = false;
            if (preferred_card_id != null) {
                selected_card = select_card_by_id(preferred_card_id);
            }
            if (!selected_card) {
                suppress_card_selection_events = true;
                card_selection.set_selected_index(0);
                suppress_card_selection_events = false;
            }
            load_selected_card.begin();
        } catch (Error e) {
            error_reported("Failed to load cards", e.message);
        }
    }

    private async void load_selected_card() {
        if (api == null) {
            return;
        }

        var selected = card_selection.get_selected_item() as CardSummary;
        if (selected == null) {
            current_card = null;
            editor_state_changed("# No Card Selected\n\nSelect a card from the sidebar.", false);
            return;
        }

        status_changed("Loading card...");
        editor_state_changed("Loading card...", false);
        try {
            var card = yield api.get_card(selected.card_id);
            current_card = card;
            editor_state_changed(card.content, true);
            show_editor_requested();
            window_title_changed(card.title);
            status_changed("Loaded %s".printf(card.title));
        } catch (Error e) {
            editor_state_changed(
                "# Error\n\nFailed to load card `%s`.\n\n%s".printf(selected.card_id, e.message),
                false
            );
            error_reported("Failed to load card", e.message);
        }
    }

    private void replace_projects(Gee.ArrayList<Project> projects) {
        project_store.remove_all();
        foreach (var project in projects) {
            project_store.append(project);
        }
    }

    private void replace_cards(Gee.ArrayList<CardSummary> cards) {
        card_store.remove_all();
        foreach (var card in cards) {
            card_store.append(card);
        }
    }

    private void replace_ai_threads(Gee.ArrayList<AiThreadSummary> threads) {
        ai_thread_store.remove_all();
        foreach (var thread in threads) {
            ai_thread_store.append(thread);
        }
    }

    private void clear_cards() {
        card_store.remove_all();
        current_card = null;
        ai_thread_store.remove_all();
        current_ai_thread = null;
        ai_thread_title_changed(null);
    }

    private void replace_search_results(Gee.ArrayList<SearchCardResult> results) {
        search_store.remove_all();
        foreach (var result in results) {
            search_store.append(result);
        }
        if (results.size > 0) {
            search_selection.set_selected_index(0);
        }
    }

    private bool select_project_by_id(string project_id) {
        for (uint i = 0; i < project_store.get_n_items(); i++) {
            var project = project_store.get_item(i) as Project;
            if (project != null && project.project_id == project_id) {
                suppress_project_selection_events = true;
                project_selection.set_selected_index(i);
                suppress_project_selection_events = false;
                return true;
            }
        }
        return false;
    }

    private bool select_card_by_id(string card_id) {
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null && card.card_id == card_id) {
                suppress_card_selection_events = true;
                card_selection.set_selected_index(i);
                suppress_card_selection_events = false;
                return true;
            }
        }
        return false;
    }

    private void update_selected_card_summary(string title, int64 updated_at) {
        if (current_card == null) {
            return;
        }
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null || card.card_id != current_card.card_id) {
                continue;
            }
            var replacement = new CardSummary(
                card.card_id,
                card.project_id,
                title,
                card.rel_path,
                card.created_at,
                updated_at
            );
            var selected_pos = card_selection.get_selected_index();
            card_store.remove(i);
            card_store.insert(i, replacement);
            if (selected_pos == i) {
                suppress_card_selection_events = true;
                card_selection.set_selected_index(i);
                suppress_card_selection_events = false;
            }
            break;
        }
    }
}

}
