using GLib;

namespace HolderLinuxTests {

public delegate void ListCardsBeforeCompleteHook(string project_id);
public delegate void HealthBeforeCompleteHook();
public delegate void ListResourcesBeforeCompleteHook(string project_id);

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

public class FakeEditorRecoveryDraftService : Object, HolderLinux.IEditorRecoveryDraftService {
    public int save_calls = 0;
    public int remove_calls = 0;
    public bool fail_save = false;
    public bool fail_remove = false;
    public HolderLinux.EditorRecoveryDraft? last_saved_draft = null;
    public Gee.HashMap<string, HolderLinux.EditorRecoveryDraft> drafts =
        new Gee.HashMap<string, HolderLinux.EditorRecoveryDraft>();

    public void save_draft(HolderLinux.EditorRecoveryDraft draft) throws Error {
        if (fail_save) {
            throw new IOError.FAILED("save draft failed");
        }
        save_calls++;
        last_saved_draft = draft;
        drafts.set(draft.card_id, draft);
    }

    public HolderLinux.EditorRecoveryDraft? load_draft(string card_id) throws Error {
        return drafts.get(card_id);
    }

    public void remove_draft(string card_id) throws Error {
        if (fail_remove) {
            throw new IOError.FAILED("remove draft failed");
        }
        remove_calls++;
        drafts.unset(card_id);
    }

    public string draft_path_for_card_id(string card_id) {
        return "/tmp/%s.json".printf(card_id);
    }
}

public class MainControllerFakeApi : Object, HolderLinux.IHolderApi {
    public int list_projects_calls = 0;
    public int list_cards_calls = 0;
    public int get_card_calls = 0;
    public int search_calls = 0;
    public int update_card_calls = 0;
    public int update_card_position_calls = 0;
    public int delete_card_calls = 0;
    public int create_card_calls = 0;
    public int create_project_calls = 0;
    public int list_threads_calls = 0;
    public int list_ai_messages_calls = 0;
    public int factory_create_calls = 0;
    public int list_resources_calls = 0;
    public int create_resource_calls = 0;
    public int update_resource_calls = 0;
    public int delete_resource_calls = 0;
    public int set_project_git_remote_calls = 0;
    public int test_project_git_remote_calls = 0;
    public int push_project_git_calls = 0;
    public int list_trash_calls = 0;
    public int empty_trash_calls = 0;
    public int restore_trash_calls = 0;
    public int hard_delete_trash_calls = 0;
    public int list_card_links_calls = 0;
    public int list_card_backlinks_calls = 0;
    public int list_card_links_in_flight = 0;
    public int max_list_card_links_in_flight = 0;
    public int create_card_link_calls = 0;
    public int delete_card_link_calls = 0;
    public string last_updated_card_id = "";
    public string last_created_project_id = "";
    public string last_created_project_name = "";
    public string last_created_title = "";
    public string last_created_content = "";
    public string? last_created_parent_card_id = null;
    public string last_updated_title = "";
    public string last_updated_content = "";
    public int64 last_updated_at = 0;
    public string last_move_card_id = "";
    public string? last_move_parent_card_id = null;
    public double last_move_sort_key = 0.0;
    public int64 last_move_updated_at = 0;
    public string last_move_project_id = "";
    public string last_move_intent = "";
    public string? last_move_target_card_id = null;
    public bool fail_health = false;
    public int health_failures_remaining = 0;
    public bool fail_create_card = false;
    public bool fail_create_project = false;
    public bool fail_list_threads = false;
    public bool fail_ai_capabilities = false;
    public bool fail_list_resources = false;
    public bool fail_create_resource = false;
    public bool fail_update_resource = false;
    public bool fail_delete_resource = false;
    public uint list_card_links_delay_ms = 0;
    public bool include_card2 = false;
    public string next_move_into_title = "";
    public bool search_returns_card2 = false;
    public bool list_projects_empty = false;
    public bool include_home_project = false;
    public bool list_projects_empty_first = false;
    public bool fail_list_projects = false;
    public bool fail_list_projects_once = false;
    public bool list_cards_empty = false;
    public bool slow_create_card = false;
    public bool list_threads_empty = false;
    public bool include_created_card = false;
    public bool fail_update_card = false;
    public bool fail_update_card_position = false;
    public bool fail_delete_card = false;
    public bool fail_search = false;
    public bool fail_get_card = false;
    public bool fail_get_card_once = false;
    public bool slow_get_card = false;
    public bool slow_health_once = false;
    public bool fail_list_cards = false;
    public bool fail_list_cards_first = false;
    public bool slow_list_cards_first = false;
    public bool fail_list_cards_once = false;
    public bool slow_list_cards_once = false;
    public bool slow_list_resources_once = false;
    public string fail_list_cards_for_project_id = "";
    public string health_failure_message = "health failed";
    public string list_projects_failure_message = "list projects failed";
    public string list_cards_failure_message = "list cards failed";
    public string get_card_failure_message = "get card failed";
    public string list_resources_failure_message = "list resources failed";
    public bool fail_set_project_git_remote = false;
    public bool fail_test_project_git_remote = false;
    public bool fail_push_project_git = false;
    public bool fail_list_trash = false;
    public bool fail_empty_trash = false;
    public bool fail_restore_trash = false;
    public bool fail_hard_delete_trash = false;
    public bool fail_list_card_links = false;
    public bool fail_list_card_backlinks = false;
    public bool fail_create_card_link = false;
    public bool fail_delete_card_link = false;
    public string test_project_git_remote_status = "reachable";
    public Gee.ArrayList<string> ai_capability_models = new Gee.ArrayList<string>();
    private int list_projects_index = 0;
    private int list_cards_index = 0;
    public string last_resource_project_id = "";
    public string last_resource_kind = "";
    public string last_resource_uri = "";
    public string last_resource_label = "";
    public string? last_resource_desc = null;
    public string last_resource_id = "";
    public int64 last_resource_updated_at = 0;
    public string last_git_project_id = "";
    public string? last_git_remote_url = null;
    public int64 last_git_remote_updated_at = 0;
    public string last_git_branch = "";
    public bool last_git_set_upstream = false;
    public string last_trash_project_id = "";
    public string last_trash_type = "";
    public string last_restore_item_type = "";
    public string last_restore_item_id = "";
    public string last_hard_delete_item_type = "";
    public string last_hard_delete_item_id = "";
    public string last_link_from_card_id = "";
    public string last_link_to_card_id = "";
    public string last_link_kind = "";
    public string? last_link_label = null;
    public string last_link_to_type = "";
    public Gee.ArrayList<HolderLinux.CardLink> card_links = new Gee.ArrayList<HolderLinux.CardLink>();
    public Gee.ArrayList<HolderLinux.CardLink> card_backlinks = new Gee.ArrayList<HolderLinux.CardLink>();
    public Gee.ArrayList<HolderLinux.TrashItem> trash_items = new Gee.ArrayList<HolderLinux.TrashItem>();
    public ListCardsBeforeCompleteHook? list_cards_before_complete_hook = null;
    public HealthBeforeCompleteHook? health_before_complete_hook = null;
    public ListResourcesBeforeCompleteHook? list_resources_before_complete_hook = null;
    public Gee.ArrayList<string?> health_check_sequence = new Gee.ArrayList<string?>();

    public async void health_check() throws Error {
        if (slow_health_once) {
            slow_health_once = false;
            var end = GLib.get_monotonic_time() + 50 * 1000;
            while (GLib.get_monotonic_time() < end) {
                while (MainContext.default().iteration(false)) {}
                Thread.usleep(1000);
            }
        }
        if (health_before_complete_hook != null) {
            ((!) health_before_complete_hook)();
        }
        if (health_check_sequence.size > 0) {
            var outcome = health_check_sequence[0];
            health_check_sequence.remove_at(0);
            if (outcome != null) {
                throw new IOError.FAILED((!) outcome);
            }
        }
        if (health_failures_remaining > 0) {
            health_failures_remaining--;
            throw new IOError.FAILED(health_failure_message);
        }
        if (fail_health) {
            throw new IOError.FAILED(health_failure_message);
        }
    }

    public async HolderLinux.HealthInfo get_health_info() throws Error {
        if (fail_health) {
            throw new IOError.FAILED("health failed");
        }
        return new HolderLinux.HealthInfo(true, 1234, "0.1", "dev", 42);
    }

    public async Gee.ArrayList<HolderLinux.Project> list_projects() throws Error {
        if (fail_list_projects_once) {
            fail_list_projects_once = false;
            throw new IOError.FAILED(list_projects_failure_message);
        }
        if (fail_list_projects) {
            throw new IOError.FAILED(list_projects_failure_message);
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
        if (include_home_project) {
            projects.add(new HolderLinux.Project("p-home", "Home", "encrypted_git", "/tmp/home", 11, 11));
        }
        if (create_project_calls > 0) {
            var created_name = last_created_project_name.length > 0 ? last_created_project_name : "Created Project";
            projects.add(new HolderLinux.Project("p-created", created_name, "encrypted_git", "/tmp/p-created", 12, 12));
        }
        projects.add(new HolderLinux.Project(
            "p1",
            "Project 1",
            "encrypted_git",
            "/tmp/p1",
            10,
            10,
            "https://example.com/p1.git",
            new HolderLinux.ProjectSyncState(
                0,
                1710000000,
                1710000100,
                2,
                3,
                "pushed",
                "pulled",
                "last sync failed",
                null,
                4,
                1710000200,
                5,
                1710000300
            )
        ));
        return projects;
    }

    public async string create_project(string name, string privacy_mode = "encrypted_git") throws Error {
        if (fail_create_project) {
            throw new IOError.FAILED("create project failed");
        }
        create_project_calls++;
        last_created_project_name = name;
        return "p-created";
    }

    public async HolderLinux.ProjectRecoveryTokenExport export_project_recovery_token(
        string project_id,
        string pin
    ) throws Error {
        return new HolderLinux.ProjectRecoveryTokenExport(project_id, "key-1", "{\"token\":\"fake\"}");
    }

    public async void import_project_recovery_token(
        string project_id,
        string pin,
        string recovery_token
    ) throws Error {}

    public async HolderLinux.RecoveryTokenImportResult import_recovery_token(
        string pin,
        string recovery_token
    ) throws Error {
        return new HolderLinux.RecoveryTokenImportResult(
            "p1",
            false,
            false,
            false,
            "",
            "not_attempted",
            ""
        );
    }

    public async Gee.ArrayList<HolderLinux.CardSummary> list_cards(string project_id,
                                                                    string view = "tree",
                                                                    string? parent_card_id = null,
                                                                    int limit = 0) throws Error {
        list_cards_calls++;
        list_cards_index++;
        if (slow_list_cards_once) {
            slow_list_cards_once = false;
            var end = GLib.get_monotonic_time() + 50 * 1000;
            while (GLib.get_monotonic_time() < end) {
                while (MainContext.default().iteration(false)) {}
                Thread.usleep(1000);
            }
        } else if (slow_list_cards_first && list_cards_index == 1) {
            var end = GLib.get_monotonic_time() + 50 * 1000;
            while (GLib.get_monotonic_time() < end) {
                while (MainContext.default().iteration(false)) {}
                Thread.usleep(1000);
            }
        }
        if (list_cards_before_complete_hook != null) {
            ((!) list_cards_before_complete_hook)(project_id);
        }
        if (fail_list_cards_for_project_id != ""
            && project_id == fail_list_cards_for_project_id) {
            throw new IOError.FAILED(list_cards_failure_message);
        }
        if (fail_list_cards_once) {
            fail_list_cards_once = false;
            throw new IOError.FAILED(list_cards_failure_message);
        }
        if (fail_list_cards_first && list_cards_index == 1) {
            throw new IOError.FAILED(list_cards_failure_message);
        }
        if (fail_list_cards) {
            throw new IOError.FAILED(list_cards_failure_message);
        }
        var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
        if (list_cards_empty) {
            return cards;
        }
        if (view == "tree" && parent_card_id != null && parent_card_id.strip().length > 0) {
            return cards;
        }
        if (create_card_calls > 0 && project_id == "p-created") {
            var created_title = last_created_title.length > 0 ? last_created_title : "Untitled";
            cards.add(new HolderLinux.CardSummary("c-created", project_id, created_title, "c-created.md", 1000.0, null, 22, 22));
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

    public async HolderLinux.CardContextData get_card_context(string project_id,
                                                              string? parent_card_id = null) throws Error {
        var project = new HolderLinux.CardContextProject(project_id, "Project 1");
        return new HolderLinux.CardContextData(
            project,
            parent_card_id,
            new Gee.ArrayList<HolderLinux.CardContextBreadcrumb>(),
            new Gee.ArrayList<HolderLinux.CardContextCard>()
        );
    }

    public async HolderLinux.CardDetail get_card(string card_id) throws Error {
        if (slow_get_card) {
            var end = GLib.get_monotonic_time() + 50 * 1000;
            while (GLib.get_monotonic_time() < end) {
                while (MainContext.default().iteration(false)) {}
                Thread.usleep(1000);
            }
        }
        get_card_calls++;
        if (fail_get_card_once) {
            fail_get_card_once = false;
            throw new IOError.FAILED(get_card_failure_message);
        }
        if (fail_get_card) {
            throw new IOError.FAILED(get_card_failure_message);
        }
        return new HolderLinux.CardDetail(card_id, "p1", "Card 1", "# Card 1\n\nBody", 20);
    }

    public async Gee.ArrayList<HolderLinux.CardLink> list_card_links(string card_id) throws Error {
        if (fail_list_card_links) {
            throw new IOError.FAILED("list card links failed");
        }
        list_card_links_in_flight++;
        if (list_card_links_in_flight > max_list_card_links_in_flight) {
            max_list_card_links_in_flight = list_card_links_in_flight;
        }
        if (list_card_links_delay_ms > 0) {
            var loop = new MainLoop(null, false);
            Timeout.add(list_card_links_delay_ms, () => {
                loop.quit();
                return Source.REMOVE;
            });
            loop.run();
        }
        list_card_links_calls++;
        list_card_links_in_flight--;
        return card_links;
    }

    public async Gee.ArrayList<HolderLinux.CardLink> list_card_backlinks(string card_id) throws Error {
        if (fail_list_card_backlinks) {
            throw new IOError.FAILED("list card backlinks failed");
        }
        list_card_backlinks_calls++;
        return card_backlinks;
    }

    public async Gee.ArrayList<HolderLinux.ProjectResource> list_resources(string project_id) throws Error {
        if (slow_list_resources_once) {
            slow_list_resources_once = false;
            var end = GLib.get_monotonic_time() + 50 * 1000;
            while (GLib.get_monotonic_time() < end) {
                while (MainContext.default().iteration(false)) {}
                Thread.usleep(1000);
            }
        }
        if (list_resources_before_complete_hook != null) {
            ((!) list_resources_before_complete_hook)(project_id);
        }
        if (fail_list_resources) {
            throw new IOError.FAILED(list_resources_failure_message);
        }
        list_resources_calls++;
        last_resource_project_id = project_id;
        return new Gee.ArrayList<HolderLinux.ProjectResource>();
    }

    public async Gee.ArrayList<HolderLinux.TrashItem> list_trash_items(string project_id,
                                                                        string type = "all") throws Error {
        if (fail_list_trash) {
            throw new IOError.FAILED("list trash failed");
        }
        list_trash_calls++;
        last_trash_project_id = project_id;
        last_trash_type = type;
        return trash_items;
    }

    public async void empty_trash(string project_id, string type = "all") throws Error {
        if (fail_empty_trash) {
            throw new IOError.FAILED("empty trash failed");
        }
        empty_trash_calls++;
        last_trash_project_id = project_id;
        last_trash_type = type;
    }

    public async void restore_trash_item(string item_type, string item_id) throws Error {
        if (fail_restore_trash) {
            throw new IOError.FAILED("restore trash failed");
        }
        restore_trash_calls++;
        last_restore_item_type = item_type;
        last_restore_item_id = item_id;
    }

    public async void hard_delete_trash_item(string item_type, string item_id) throws Error {
        if (fail_hard_delete_trash) {
            throw new IOError.FAILED("hard delete trash failed");
        }
        hard_delete_trash_calls++;
        last_hard_delete_item_type = item_type;
        last_hard_delete_item_id = item_id;
    }

    public async string create_resource(string project_id,
                                        string kind,
                                        string uri,
                                        string label,
                                        string? desc = null) throws Error {
        if (fail_create_resource) {
            throw new IOError.FAILED("create resource failed");
        }
        create_resource_calls++;
        last_resource_project_id = project_id;
        last_resource_kind = kind;
        last_resource_uri = uri;
        last_resource_label = label;
        last_resource_desc = desc;
        return "r1";
    }

    public async void update_resource(string resource_id,
                                      string? kind,
                                      string? uri,
                                      string? label,
                                      string? desc,
                                      int64 updated_at) throws Error {
        if (fail_update_resource) {
            throw new IOError.FAILED("update resource failed");
        }
        update_resource_calls++;
        last_resource_id = resource_id;
        last_resource_kind = kind ?? "";
        last_resource_uri = uri ?? "";
        last_resource_label = label ?? "";
        last_resource_desc = desc;
        last_resource_updated_at = updated_at;
    }

    public async void delete_resource(string resource_id) throws Error {
        if (fail_delete_resource) {
            throw new IOError.FAILED("delete resource failed");
        }
        delete_resource_calls++;
        last_resource_id = resource_id;
    }

    public async HolderLinux.CardLink create_card_link(string from_card_id,
                                                       string to_card_id,
                                                       string kind = "ref",
                                                       string? label = null,
                                                       string to_type = "card") throws Error {
        if (fail_create_card_link) {
            throw new IOError.FAILED("create card link failed");
        }
        create_card_link_calls++;
        last_link_from_card_id = from_card_id;
        last_link_to_card_id = to_card_id;
        last_link_kind = kind;
        last_link_label = label;
        last_link_to_type = to_type;
        return new HolderLinux.CardLink(from_card_id, to_card_id, to_type, kind, label, 0);
    }

    public async void delete_card_link(string from_card_id,
                                       string to_card_id,
                                       string kind,
                                       string to_type = "card") throws Error {
        if (fail_delete_card_link) {
            throw new IOError.FAILED("delete card link failed");
        }
        delete_card_link_calls++;
        last_link_from_card_id = from_card_id;
        last_link_to_card_id = to_card_id;
        last_link_kind = kind;
        last_link_to_type = to_type;
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
        if (fail_ai_capabilities) {
            throw new IOError.FAILED("ai capabilities failed");
        }
        return new HolderLinux.AiCapabilitiesInfo(
            true, "", 1, "1.0", "user", ai_capability_models, new Gee.ArrayList<string>()
        );
    }

    public async HolderLinux.AiStatusInfo get_ai_status() throws Error {
        return new HolderLinux.AiStatusInfo(
            1,
            true,
            "",
            0,
            0,
            0,
            new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>()
        );
    }

    public async string start_ai_runner_pull(string model_tag, string? runner_id = null) throws Error {
        return "job-1";
    }

    public async Gee.ArrayList<HolderLinux.AiRunnerInfo> list_ai_runners() throws Error {
        return new Gee.ArrayList<HolderLinux.AiRunnerInfo>();
    }

    public async HolderLinux.AiRunnerInfo create_ai_runner(string name,
                                                           string base_url,
                                                           bool enabled = true) throws Error {
        return new HolderLinux.AiRunnerInfo(
            "manual-created",
            name,
            "ollama",
            base_url,
            "manual",
            enabled,
            0,
            0,
            new HolderLinux.AiRunnerRuntimeInfo(false, false, false, 0, "", "", new Gee.ArrayList<string>(), new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>())
        );
    }

    public async HolderLinux.AiRunnerInfo update_ai_runner(string runner_id,
                                                           string? name = null,
                                                           string? base_url = null,
                                                           bool? enabled = null) throws Error {
        return new HolderLinux.AiRunnerInfo(
            runner_id,
            name ?? "Runner",
            "ollama",
            base_url,
            "manual",
            enabled ?? true,
            0,
            0,
            new HolderLinux.AiRunnerRuntimeInfo(false, false, false, 0, "", "", new Gee.ArrayList<string>(), new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>())
        );
    }

    public async void delete_ai_runner(string runner_id) throws Error {}

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

    public async Gee.ArrayList<HolderLinux.AiMessage> list_ai_messages(string thread_id) throws Error {
        list_ai_messages_calls++;
        return new Gee.ArrayList<HolderLinux.AiMessage>();
    }

    public async string create_ai_thread(string project_id, string title) throws Error {
        return "t-created";
    }

    public async Gee.ArrayList<HolderLinux.AiCatalogProvider> list_ai_provider_catalog() throws Error {
        return new Gee.ArrayList<HolderLinux.AiCatalogProvider>();
    }

    public async Gee.ArrayList<HolderLinux.AiRuntimeProvider> list_ai_runtime_providers() throws Error {
        return new Gee.ArrayList<HolderLinux.AiRuntimeProvider>();
    }

    public async HolderLinux.AiLocalModelConfigInfo get_ai_local_model_config() throws Error {
        return new HolderLinux.AiLocalModelConfigInfo(null, null, null, 0);
    }

    public async HolderLinux.AiLocalModelConfigInfo set_ai_local_model_config(string? fast_model,
                                                                              string? strong_model,
                                                                              string? deep_model) throws Error {
        return new HolderLinux.AiLocalModelConfigInfo(fast_model, strong_model, deep_model, 0);
    }

    public async Gee.ArrayList<HolderLinux.AiProviderCredentialState> list_ai_provider_credentials() throws Error {
        return new Gee.ArrayList<HolderLinux.AiProviderCredentialState>();
    }

    public async Gee.ArrayList<HolderLinux.AiProviderSettingState> list_ai_provider_settings() throws Error {
        return new Gee.ArrayList<HolderLinux.AiProviderSettingState>();
    }

    public async void upsert_ai_provider_credential(string provider, string api_key) throws Error {}

    public async void delete_ai_provider_credential(string provider) throws Error {}

    public async void set_ai_provider_enabled(string provider, bool enabled) throws Error {}

    public async Gee.ArrayList<HolderLinux.AiNudge> list_ai_nudges(string project_id,
                                                                   string? card_id = null) throws Error {
        return new Gee.ArrayList<HolderLinux.AiNudge>();
    }

    public async void dismiss_ai_nudge(string nudge_id) throws Error {}

    public async HolderLinux.NudgeEvaluationResult evaluate_nudge_candidate(string kind,
                                                                            string project_id,
                                                                            string? card_id,
                                                                            int64 created_at,
                                                                            Json.Object facts,
                                                                            string? basis_fingerprint = null,
                                                                            string? basis_commit = null) throws Error {
        return new HolderLinux.NudgeEvaluationResult(kind, false, false, "fake_not_implemented");
    }

    public async Gee.ArrayList<HolderLinux.GitProviderCatalogEntry> list_git_provider_catalog() throws Error {
        return new Gee.ArrayList<HolderLinux.GitProviderCatalogEntry>();
    }

    public async void set_project_git_remote(string project_id,
                                             string? git_remote_url,
                                             int64 updated_at) throws Error {
        if (fail_set_project_git_remote) {
            throw new IOError.FAILED("set project git remote failed");
        }
        set_project_git_remote_calls++;
        last_git_project_id = project_id;
        last_git_remote_url = git_remote_url;
        last_git_remote_updated_at = updated_at;
    }

    public async HolderLinux.GitTestRemoteResult test_project_git_remote(string project_id,
                                                                         string? remote_url = null,
                                                                         string branch = "") throws Error {
        if (fail_test_project_git_remote) {
            throw new IOError.FAILED("test project git remote failed");
        }
        test_project_git_remote_calls++;
        last_git_project_id = project_id;
        last_git_remote_url = remote_url;
        last_git_branch = branch;
        return new HolderLinux.GitTestRemoteResult(project_id,
                                                   remote_url ?? "",
                                                   branch,
                                                   test_project_git_remote_status,
                                                   test_project_git_remote_status == "reachable",
                                                   "",
                                                   "");
    }

    public async HolderLinux.GitPushResult push_project_git(string project_id,
                                                            string branch = "",
                                                            bool set_upstream = true) throws Error {
        if (fail_push_project_git) {
            throw new IOError.FAILED("push project git failed");
        }
        push_project_git_calls++;
        last_git_project_id = project_id;
        last_git_branch = branch;
        last_git_set_upstream = set_upstream;
        return new HolderLinux.GitPushResult(project_id,
                                             "",
                                             branch,
                                             "pushed",
                                             0,
                                             0,
                                             "",
                                             "",
                                             "",
                                             "");
    }

    public async void run_ai_stream(string prompt,
                                    string? project_id,
                                    string? thread_id,
                                    string? context_card_id,
                                    string? context_card_title,
                                    string? context_card_body,
                                    HolderLinux.AiRunEventHandler on_event,
                                    string? runner_id = null,
                                    string? model = null) throws Error {}

    public async string create_card(string project_id,
                                    string title,
                                    string content,
                                    string? parent_card_id = null) throws Error {
        if (fail_create_card) {
            throw new IOError.FAILED("create card failed");
        }
        create_card_calls++;
        last_created_project_id = project_id;
        last_created_title = title;
        last_created_content = content;
        last_created_parent_card_id = parent_card_id;
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
        if (fail_update_card_position) {
            throw new IOError.FAILED("update position failed");
        }
        update_card_position_calls++;
        last_move_card_id = card_id;
        last_move_parent_card_id = parent_card_id;
        last_move_sort_key = sort_key;
        last_move_updated_at = updated_at;
    }

    public async void delete_card(string card_id) throws Error {
        if (fail_delete_card) {
            throw new IOError.FAILED("delete card failed");
        }
        delete_card_calls++;
        last_updated_card_id = card_id;
    }

    public async HolderLinux.CardMoveResult move_card(string card_id,
                                                       string project_id,
                                                       string intent,
                                                       string? target_card_id = null,
                                                       string? parent_card_id = null) throws Error {
        if (fail_update_card_position) {
            throw new IOError.FAILED("move by intent failed");
        }
        update_card_position_calls++;
        last_move_project_id = project_id;
        last_move_intent = intent;
        last_move_target_card_id = target_card_id;
        last_move_card_id = card_id;
        last_move_parent_card_id = parent_card_id;
        return new HolderLinux.CardMoveResult(card_id, parent_card_id, 0.0, 1, next_move_into_title);
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

}
