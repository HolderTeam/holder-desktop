using GLib;

namespace HolderLinuxTests {

public class FakeClock : Object, HolderLinux.IClock {
    public int64 now_value = 1000;

    public int64 now_epoch_seconds() {
        return now_value;
    }
}

public class StoreSelectionState : Object, HolderLinux.ISelectionState {
    private GLib.ListStore store;
    private uint selected = uint.MAX;

    public StoreSelectionState(GLib.ListStore store) {
        this.store = store;
    }

    public Object? get_selected_item() {
        if (selected == uint.MAX) {
            return null;
        }
        return store.get_item(selected);
    }

    public uint get_selected_index() {
        return selected;
    }

    public void set_selected_index(uint index) {
        selected = index;
    }
}

public class MutableTextProvider : Object, HolderLinux.ITextProvider {
    public string value = "";

    public string get_text() {
        return value;
    }
}

public class MainControllerFakeApi : Object, HolderLinux.IHolderApi {
    public int list_projects_calls = 0;
    public int list_cards_calls = 0;
    public int get_card_calls = 0;
    public int search_calls = 0;
    public int update_card_calls = 0;
    public int update_card_position_calls = 0;
    public int create_card_calls = 0;
    public int create_project_calls = 0;
    public int list_threads_calls = 0;
    public int factory_create_calls = 0;
    public string last_updated_card_id = "";
    public string last_updated_title = "";
    public string last_updated_content = "";
    public int64 last_updated_at = 0;
    public string last_move_card_id = "";
    public string? last_move_parent_card_id = null;
    public double last_move_sort_key = 0.0;
    public int64 last_move_updated_at = 0;
    public bool fail_health = false;
    public bool fail_create_card = false;
    public bool fail_create_project = false;
    public bool fail_list_threads = false;
    public bool include_card2 = false;
    public bool search_returns_card2 = false;
    public bool list_projects_empty = false;
    public bool list_projects_empty_first = false;
    public bool fail_list_projects = false;
    public bool list_cards_empty = false;
    public bool slow_create_card = false;
    public bool list_threads_empty = false;
    public bool include_created_card = false;
    public bool fail_update_card = false;
    public bool fail_search = false;
    public bool fail_get_card = false;
    public bool fail_list_cards = false;
    private int list_projects_index = 0;

    public async void health_check() throws Error {
        if (fail_health) {
            throw new IOError.FAILED("health failed");
        }
    }

    public async Gee.ArrayList<HolderLinux.Project> list_projects() throws Error {
        if (fail_list_projects) {
            throw new IOError.FAILED("list projects failed");
        }
        list_projects_calls++;
        list_projects_index++;
        var projects = new Gee.ArrayList<HolderLinux.Project>();
        if (list_projects_empty_first && list_projects_index == 1) {
            return projects;
        }
        if (list_projects_empty) {
            return projects;
        }
        projects.add(new HolderLinux.Project("p1", "Project 1", "/tmp/p1", 10, 10));
        return projects;
    }

    public async string create_project(string name) throws Error {
        if (fail_create_project) {
            throw new IOError.FAILED("create project failed");
        }
        create_project_calls++;
        return "p-created";
    }

    public async Gee.ArrayList<HolderLinux.CardSummary> list_cards(string project_id,
                                                                    string scope = "root",
                                                                    string? parent_card_id = null) throws Error {
        if (fail_list_cards) {
            throw new IOError.FAILED("list cards failed");
        }
        list_cards_calls++;
        var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
        if (list_cards_empty) {
            return cards;
        }
        if (scope == "children" && parent_card_id != null && parent_card_id.strip().length > 0) {
            return cards;
        }
        cards.add(new HolderLinux.CardSummary("c1", project_id, "Card 1", "c1.md", 1024.0, null, 20, 20));
        if (include_card2) {
            cards.add(new HolderLinux.CardSummary("c2", project_id, "Card 2", "c2.md", 2048.0, null, 21, 21));
        }
        if (include_created_card) {
            cards.add(new HolderLinux.CardSummary("c-created", project_id, "Untitled", "c-created.md", 3072.0, null, 22, 22));
        }
        return cards;
    }

    public async HolderLinux.CardDetail get_card(string card_id) throws Error {
        if (fail_get_card) {
            throw new IOError.FAILED("get card failed");
        }
        get_card_calls++;
        return new HolderLinux.CardDetail(card_id, "p1", "Card 1", "# Card 1\n\nBody", 20);
    }

    public async Gee.ArrayList<HolderLinux.SearchCardResult> search_cards(string project_id,
                                                                           string query_text,
                                                                           int limit = 30) throws Error {
        if (fail_search) {
            throw new IOError.FAILED("search failed");
        }
        search_calls++;
        var results = new Gee.ArrayList<HolderLinux.SearchCardResult>();
        if (search_returns_card2) {
            results.add(new HolderLinux.SearchCardResult("c2", "Card 2", 21, 21, "snippet", 1.0));
        }
        return results;
    }

    public async HolderLinux.AiCapabilitiesInfo get_ai_capabilities(string? project_id = null) throws Error {
        return new HolderLinux.AiCapabilitiesInfo(
            true, "", 1, "1.0", "user", new Gee.ArrayList<string>(), new Gee.ArrayList<string>()
        );
    }

    public async HolderLinux.AiStatusInfo get_ai_status() throws Error {
        return new HolderLinux.AiStatusInfo(1, true, "", 0, 0, 0, new Gee.ArrayList<string>());
    }

    public async string start_ai_runner_pull(string model_tag) throws Error {
        return "job-1";
    }

    public async Gee.ArrayList<HolderLinux.AiThreadSummary> list_ai_threads(string project_id) throws Error {
        if (fail_list_threads) {
            throw new IOError.FAILED("list threads failed");
        }
        list_threads_calls++;
        var threads = new Gee.ArrayList<HolderLinux.AiThreadSummary>();
        if (list_threads_empty) {
            return threads;
        }
        threads.add(new HolderLinux.AiThreadSummary("t1", project_id, "Thread 1", 30, 30));
        return threads;
    }

    public async string create_ai_thread(string project_id, string title) throws Error {
        return "t-created";
    }

    public async Gee.ArrayList<HolderLinux.AiCatalogProvider> list_ai_provider_catalog() throws Error {
        return new Gee.ArrayList<HolderLinux.AiCatalogProvider>();
    }

    public async void run_ai_stream(string prompt,
                                    string? project_id,
                                    string? thread_id,
                                    string? context_card_id,
                                    string? context_card_title,
                                    string? context_card_body,
                                    HolderLinux.AiRunEventHandler on_event) throws Error {}

    public async string create_card(string project_id,
                                    string title,
                                    string content,
                                    string? parent_card_id = null) throws Error {
        if (fail_create_card) {
            throw new IOError.FAILED("create card failed");
        }
        create_card_calls++;
        if (slow_create_card) {
            var loop = new MainLoop();
            Timeout.add(200, () => {
                loop.quit();
                return Source.REMOVE;
            });
            loop.run();
        }
        return "c-created";
    }

    public async void update_card(string card_id,
                                  string title,
                                  string content,
                                  int64 updated_at) throws Error {
        if (fail_update_card) {
            throw new IOError.FAILED("update failed");
        }
        update_card_calls++;
        last_updated_card_id = card_id;
        last_updated_title = title;
        last_updated_content = content;
        last_updated_at = updated_at;
    }

    public async void update_card_position(string card_id,
                                           string? parent_card_id,
                                           double sort_key,
                                           int64 updated_at) throws Error {
        update_card_position_calls++;
        last_move_card_id = card_id;
        last_move_parent_card_id = parent_card_id;
        last_move_sort_key = sort_key;
        last_move_updated_at = updated_at;
    }
}

public class MainControllerFakeApiFactory : Object, HolderLinux.IApiFactory {
    private HolderLinux.IHolderApi api;
    private MainControllerFakeApi? fake_api;

    public MainControllerFakeApiFactory(HolderLinux.IHolderApi api, MainControllerFakeApi? fake_api = null) {
        this.api = api;
        this.fake_api = fake_api;
    }

    public HolderLinux.IHolderApi create(string base_url, string auth_token) {
        if (fake_api != null) {
            fake_api.factory_create_calls++;
        }
        return api;
    }
}

public class FakeServerDiscovery : Object, HolderLinux.IServerDiscovery {
    public HolderLinux.ServerInfo info;
    public bool should_fail = false;
    public string fail_message = "discovery failed";

    public FakeServerDiscovery() {
        info = new HolderLinux.ServerInfo(1, "127.0.0.1", 8080, 1, "0.1", "0.1", "token");
    }

    public HolderLinux.ServerInfo discover_server() throws Error {
        if (should_fail) {
            throw new IOError.FAILED(fail_message);
        }
        return info;
    }

    public string holder_info_path() {
        return "/tmp/holder.json";
    }
}

public class MainControllerTestHarness : Object {
    public GLib.ListStore project_store;
    public GLib.ListStore card_store;
    public GLib.ListStore thread_store;
    public GLib.ListStore search_store;
    public StoreSelectionState project_selection;
    public StoreSelectionState card_selection;
    public StoreSelectionState thread_selection;
    public StoreSelectionState search_selection;
    public MutableTextProvider search_text;
    public MutableTextProvider editor_text;
    public HolderLinux.MainController controller;

    public MainControllerTestHarness(MainControllerFakeApi api,
                                     TestScheduler scheduler,
                                     FakeClock clock,
                                     FakeServerDiscovery? discovery = null,
                                     HolderLinux.IHolderApi? initial_api = null,
                                     bool inject_initial_api = true) {
        project_store = new GLib.ListStore(typeof(HolderLinux.Project));
        card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
        thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));
        search_store = new GLib.ListStore(typeof(HolderLinux.SearchCardResult));
        project_selection = new StoreSelectionState(project_store);
        card_selection = new StoreSelectionState(card_store);
        thread_selection = new StoreSelectionState(thread_store);
        search_selection = new StoreSelectionState(search_store);
        search_text = new MutableTextProvider();
        editor_text = new MutableTextProvider();
        controller = new HolderLinux.MainController(
            project_store,
            project_selection,
            card_store,
            card_selection,
            thread_store,
            thread_selection,
            search_store,
            search_selection,
            search_text,
            editor_text,
            new MainControllerFakeApiFactory(api, api),
            discovery ?? new FakeServerDiscovery(),
            clock,
            scheduler,
            inject_initial_api ? (initial_api ?? api) : null
        );
    }
}

}
