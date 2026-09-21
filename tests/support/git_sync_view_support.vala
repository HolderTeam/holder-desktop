using GLib;

namespace HolderLinuxTests {

// MainControllerFakeApi plus the knobs the Git Sync view tests need: a provider catalog, a
// configurable push result, and stalls that hold an in-flight call open so tests can observe the
// view mid-flight (and resume it after a newer refresh has already committed).
public class GitSyncViewFakeApi : MainControllerFakeApi {
    public Gee.ArrayList<HolderLinux.GitProviderCatalogEntry> provider_catalog =
        new Gee.ArrayList<HolderLinux.GitProviderCatalogEntry>();
    public bool fail_provider_catalog = false;
    public int provider_catalog_calls = 0;
    public string push_status = "pushed";
    public string push_commit = "";
    public string push_error_message = "";
    public string push_next_action = "";
    public bool stall_next_list_projects = false;
    public bool stall_next_push = false;
    public bool stall_next_set_remote = false;
    private SourceFunc? stalled_list = null;
    private SourceFunc? stalled_push = null;
    private SourceFunc? stalled_set_remote = null;

    public bool has_stalled_set_remote() {
        return stalled_set_remote != null;
    }

    public void release_stalled_set_remote() {
        if (stalled_set_remote != null) {
            var resume = (owned) stalled_set_remote;
            stalled_set_remote = null;
            resume();
        }
    }

    public override async void set_project_git_remote(string project_id,
                                                      string? git_remote_url,
                                                      int64 updated_at) throws Error {
        if (stall_next_set_remote) {
            stall_next_set_remote = false;
            stalled_set_remote = set_project_git_remote.callback;
            yield;
        }
        yield base.set_project_git_remote(project_id, git_remote_url, updated_at);
    }

    public bool has_stalled_list() {
        return stalled_list != null;
    }

    public bool has_stalled_push() {
        return stalled_push != null;
    }

    public void release_stalled_list() {
        if (stalled_list != null) {
            var resume = (owned) stalled_list;
            stalled_list = null;
            resume();
        }
    }

    public void release_stalled_push() {
        if (stalled_push != null) {
            var resume = (owned) stalled_push;
            stalled_push = null;
            resume();
        }
    }

    // The list is captured before the stall, so a stalled call resumes with the backend state as it
    // was when the call started, like a slow real response would.
    public override async Gee.ArrayList<HolderLinux.Project> list_projects() throws Error {
        var projects = yield base.list_projects();
        if (stall_next_list_projects) {
            stall_next_list_projects = false;
            stalled_list = list_projects.callback;
            yield;
        }
        return projects;
    }

    public override async Gee.ArrayList<HolderLinux.GitProviderCatalogEntry> list_git_provider_catalog() throws Error {
        provider_catalog_calls++;
        if (fail_provider_catalog) {
            throw new IOError.FAILED("provider catalog failed");
        }
        return provider_catalog;
    }

    public override async HolderLinux.GitPushResult push_project_git(string project_id,
                                                                     string branch = "",
                                                                     bool set_upstream = true) throws Error {
        if (stall_next_push) {
            stall_next_push = false;
            stalled_push = push_project_git.callback;
            yield;
        }
        yield base.push_project_git(project_id, branch, set_upstream);
        return new HolderLinux.GitPushResult(
            project_id, "", branch, push_status, 0, 0, push_commit, "", push_error_message, push_next_action
        );
    }
}

// A GitSyncService that never starts a process: every gh/git/ssh answer is set by the test, so the
// view's CLI, guided and SSH logic runs the same on every platform (the shim based tests need POSIX
// shell scripts). configure_remote_and_sync is the real one, which talks to the fake backend API.
// A stalled call resumes with the answer that was set when the call started, like a slow real one.
public class GitSyncViewFakeService : HolderLinux.GitSyncService {
    public HolderLinux.GitHubCliState cli_state =
        new HolderLinux.GitHubCliState(true, true, "octocat", "");
    public HolderLinux.GitRepoCheckResult repo_check = new HolderLinux.GitRepoCheckResult(true, "");
    public HolderLinux.GitRepoCreateResult repo_create = new HolderLinux.GitRepoCreateResult(true, true, "");
    public string ssh_probe_output = "";
    public HolderLinux.GitCommandResult keygen_result = new HolderLinux.GitCommandResult(0, "");
    public bool keygen_writes_key = true;
    public bool stall_next_detect = false;
    public bool stall_next_repo_check = false;
    public bool stall_next_repo_create = false;
    public bool stall_next_probe = false;
    public Gee.ArrayList<string> calls = new Gee.ArrayList<string>();
    private SourceFunc? stalled_detect = null;
    private SourceFunc? stalled_repo_check = null;
    private SourceFunc? stalled_repo_create = null;
    private SourceFunc? stalled_probe = null;

    public int count(string prefix) {
        int total = 0;
        foreach (var call in calls) {
            if (call.has_prefix(prefix)) {
                total++;
            }
        }
        return total;
    }

    public bool has_stalled_detect() {
        return stalled_detect != null;
    }

    public bool has_stalled_repo_check() {
        return stalled_repo_check != null;
    }

    public bool has_stalled_repo_create() {
        return stalled_repo_create != null;
    }

    public bool has_stalled_probe() {
        return stalled_probe != null;
    }

    public void release_stalled_probe() {
        if (stalled_probe != null) {
            var resume = (owned) stalled_probe;
            stalled_probe = null;
            resume();
        }
    }

    public void release_stalled_detect() {
        if (stalled_detect != null) {
            var resume = (owned) stalled_detect;
            stalled_detect = null;
            resume();
        }
    }

    public void release_stalled_repo_check() {
        if (stalled_repo_check != null) {
            var resume = (owned) stalled_repo_check;
            stalled_repo_check = null;
            resume();
        }
    }

    public void release_stalled_repo_create() {
        if (stalled_repo_create != null) {
            var resume = (owned) stalled_repo_create;
            stalled_repo_create = null;
            resume();
        }
    }

    public override async HolderLinux.GitHubCliState detect_github_cli_state() {
        calls.add("detect");
        var state = cli_state;
        if (stall_next_detect) {
            stall_next_detect = false;
            stalled_detect = detect_github_cli_state.callback;
            yield;
        }
        return state;
    }

    public override async HolderLinux.GitRepoCheckResult check_repository_exists_via_ssh(string username,
                                                                                          string repo_name) {
        calls.add("check %s/%s".printf(username, repo_name));
        var result = repo_check;
        if (stall_next_repo_check) {
            stall_next_repo_check = false;
            stalled_repo_check = check_repository_exists_via_ssh.callback;
            yield;
        }
        return result;
    }

    public override async HolderLinux.GitRepoCreateResult create_private_repo_and_verify(string username,
                                                                                          string repo_name) {
        calls.add("create %s/%s".printf(username, repo_name));
        var result = repo_create;
        if (stall_next_repo_create) {
            stall_next_repo_create = false;
            stalled_repo_create = create_private_repo_and_verify.callback;
            yield;
        }
        return result;
    }

    public override async string probe_github_ssh() {
        calls.add("probe");
        var output = ssh_probe_output;
        if (stall_next_probe) {
            stall_next_probe = false;
            stalled_probe = probe_github_ssh.callback;
            yield;
        }
        return output;
    }

    public override async HolderLinux.GitCommandResult generate_ssh_key(string email, string key_path) {
        calls.add("keygen %s".printf(email));
        if (keygen_writes_key) {
            try {
                FileUtils.set_contents(key_path, "fake private key");
                FileUtils.set_contents("%s.pub".printf(key_path), "ssh-ed25519 AAAAFAKEKEY %s".printf(email));
            } catch (Error e) {
                assert_not_reached();
            }
        }
        return keygen_result;
    }
}

public class GitSyncViewFakeLauncher : Object, HolderLinux.IUriLauncher {
    public Gee.ArrayList<string> uris = new Gee.ArrayList<string>();
    public Error? failure = null;

    public void launch(string uri) throws Error {
        uris.add(uri);
        if (failure != null) {
            throw (!) failure;
        }
    }
}

public class GitSyncViewFakeClipboard : Object, HolderLinux.ITextClipboard {
    public Gee.ArrayList<string> texts = new Gee.ArrayList<string>();
    public bool available { get; set; default = true; }

    public bool set_text(string text) {
        if (!available) {
            return false;
        }
        texts.add(text);
        return true;
    }
}

public HolderLinux.Project gsv_project(string id,
                                       string name,
                                       string? remote_url,
                                       HolderLinux.ProjectSyncState? sync = null) {
    return new HolderLinux.Project(id, name, "encrypted_git", "/tmp/" + id, 10, 20, remote_url, sync);
}

public HolderLinux.GitProviderCatalogEntry gsv_provider(string id,
                                                        string name,
                                                        string preferred_transport = "ssh",
                                                        string transports = "ssh,https",
                                                        string ssh_example = "",
                                                        string https_example = "") {
    return new HolderLinux.GitProviderCatalogEntry(
        id, name, "hosted", preferred_transport, transports, ssh_example, https_example
    );
}

// Hosts a GitSyncToolView in a real (never presented) Adw.Window so dialogs have a root, and
// records everything the view reports.
public class GitSyncViewHarness : Object {
    public GitSyncViewFakeApi api = new GitSyncViewFakeApi();
    public HolderLinux.GitSyncToolView view;
    public Adw.Window window = new Adw.Window();
    public GLib.ListStore store = new GLib.ListStore(typeof(HolderLinux.Project));
    public Gtk.SingleSelection selection;
    public Gee.ArrayList<string> toasts = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> errors = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> histories = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> activities = new Gee.ArrayList<string>();
    public GitSyncViewFakeService? service = null;
    public GitSyncViewFakeLauncher launcher = new GitSyncViewFakeLauncher();
    public GitSyncViewFakeClipboard clipboard = new GitSyncViewFakeClipboard();
    public string home = "";

    // With use_fake_service the view runs against a GitSyncViewFakeService and its own empty home
    // directory, so nothing touches the real ~/.ssh or starts a process.
    public GitSyncViewHarness(string? remote_url = null,
                              bool with_project = true,
                              bool with_api = true,
                              bool attach_window = true,
                              bool auto_check_cli = false,
                              HolderLinux.ProjectSyncState? sync = null,
                              bool use_fake_service = false,
                              string? home_override = null) {
        string? view_home = null;
        if (use_fake_service) {
            service = new GitSyncViewFakeService();
            home = GitSyncViewEnv.make_home();
            view_home = home_override ?? home;
        }
        view = new HolderLinux.GitSyncToolView(auto_check_cli, service, launcher, clipboard, view_home);
        selection = new Gtk.SingleSelection(store);
        view.toast_requested.connect((message) => { toasts.add(message); });
        view.error_reported.connect((title, details) => { errors.add("%s|%s".printf(title, details)); });
        view.repository_history_changed.connect((project_id) => { histories.add(project_id); });
        view.activity_requested.connect((kind, message, project_id, card_id, details) => {
            activities.add("%s|%s".printf(kind, message));
        });
        if (attach_window) {
            window.set_content(view.widget);
        }
        api.project_git_remote_url = remote_url;
        if (with_api) {
            view.set_api_client(api);
        }
        if (with_project) {
            store.append(gsv_project("p1", "Runbook Project", remote_url, sync));
            selection.set_selected(0);
        }
        view.set_project_selection(selection);
        settle();
    }

    public GitSyncViewFakeService fake() {
        assert(service != null);
        return (!) service;
    }

    // Async calls hand their results back through idle callbacks even when nothing really waits, so
    // let every pending (and chained) idle run before looking at the view.
    public void settle() {
        var context = MainContext.default();
        for (int round = 0; round < 20; round++) {
            while (context.iteration(false)) {
            }
        }
    }

    public Gtk.Stack main_stack() {
        return (Gtk.Stack) view.widget;
    }

    public string page() {
        return (string) main_stack().get_visible_child_name();
    }

    public Gtk.Stack state_stack() {
        return (Gtk.Stack) gsv_named(view.widget, "git-start-state-stack");
    }

    public string state_page() {
        return (string) state_stack().get_visible_child_name();
    }

    public Gtk.Widget child_page(string name) {
        var found = main_stack().get_child_by_name(name);
        assert(found != null);
        return (!) found;
    }

    public Gtk.Widget setup_page() {
        var found = state_stack().get_child_by_name("setup");
        assert(found != null);
        return (!) found;
    }

    public Gtk.Label named_label(string name) {
        return (Gtk.Label) gsv_named(view.widget, name);
    }

    public Adw.AlertDialog? dialog() {
        return window.get_visible_dialog() as Adw.AlertDialog;
    }

    public bool wait_for_dialog() {
        return wait_for_condition(() => dialog() != null, 5000);
    }

    public bool wait_for_toast(string message) {
        return wait_for_condition(() => toasts.contains(message), 5000);
    }

    public bool wait_for_error(string message) {
        return wait_for_condition(() => errors.contains(message), 5000);
    }

    public bool wait_for_page(string name) {
        return wait_for_condition(() => page() == name, 5000);
    }

    // Setup page widgets that have no widget name.
    public Gtk.Entry remote_entry() {
        return gsv_entry(setup_page(), "https://example.com/repo.git");
    }

    public Gtk.Entry branch_entry() {
        return gsv_entry(setup_page(), "local default");
    }

    public Gtk.Label manual_status() {
        var row = remote_entry().get_parent();
        assert(row != null);
        return (Gtk.Label) ((!) row).get_next_sibling();
    }

    public Gtk.Label cli_status() {
        return (Gtk.Label) gsv_button(setup_page(), "Use GitHub CLI (Automatic)").get_next_sibling();
    }

    public Gtk.Button setup_button(string label) {
        return gsv_button(setup_page(), label);
    }

    // Guided pages.
    public Gtk.Entry username_entry() {
        return gsv_entry(child_page("guided-part1"), "your-github-username");
    }

    public Gtk.Entry email_entry() {
        return gsv_entry(child_page("guided-part2"), "you@example.com");
    }

    public Gtk.Label ssh_status() {
        return (Gtk.Label) gsv_child(child_page("guided-part2"), 2);
    }

    public Gtk.Widget missing_key_box() {
        return gsv_child(child_page("guided-part2"), 3);
    }

    public Gtk.Widget key_ready_box() {
        return gsv_child(child_page("guided-part2"), 4);
    }

    public Gtk.Button open_keys_button() {
        return (Gtk.Button) gsv_child(child_page("guided-part2"), 5);
    }

    public Gtk.Entry repo_name_entry() {
        return (Gtk.Entry) gsv_child(child_page("guided-part3"), 5);
    }

    public Gtk.Label repo_status() {
        return (Gtk.Label) gsv_child(child_page("guided-part3"), 6);
    }

    public Gtk.Label repo_mode() {
        return (Gtk.Label) gsv_child(child_page("guided-part3"), 1);
    }

    public Gtk.Button create_repo_cli_button() {
        return (Gtk.Button) gsv_child(child_page("guided-part3"), 7);
    }

    public Gtk.Label push_intro() {
        return (Gtk.Label) gsv_child(child_page("guided-part4"), 1);
    }

    public Gtk.Label push_status() {
        return (Gtk.Label) gsv_child(child_page("guided-part4"), 2);
    }

    public Gtk.Button click(string page_name, string label) {
        var button = gsv_button(child_page(page_name), label);
        button.clicked();
        return button;
    }

    public void select_none() {
        store.remove_all();
    }
}

// Widgets of the provider setup page, located by their fixed position in the page's box.
public class GitSyncProviderUi : Object {
    public Gtk.DropDown provider;
    public Gtk.DropDown transport;
    public Gtk.Entry namespace_entry;
    public Gtk.Entry repo;
    public Gtk.Box host_row;
    public Gtk.Entry host;
    public Gtk.Entry remote;
    public Gtk.Label template_label;
    public Gtk.Entry branch;
    public Gtk.Label status;
    public Gtk.Button apply;
    public Gtk.Button back;

    public GitSyncProviderUi(GitSyncViewHarness h) {
        var page = h.child_page("provider");
        provider = (Gtk.DropDown) gsv_child(gsv_child(page, 2), 1);
        transport = (Gtk.DropDown) gsv_child(gsv_child(page, 3), 1);
        namespace_entry = (Gtk.Entry) gsv_child(gsv_child(page, 4), 1);
        repo = (Gtk.Entry) gsv_child(gsv_child(page, 5), 1);
        host_row = (Gtk.Box) gsv_child(page, 6);
        host = (Gtk.Entry) gsv_child(host_row, 1);
        remote = (Gtk.Entry) gsv_child(gsv_child(page, 7), 1);
        template_label = (Gtk.Label) gsv_child(page, 8);
        branch = (Gtk.Entry) gsv_child(gsv_child(page, 9), 1);
        status = (Gtk.Label) gsv_child(page, 10);
        apply = gsv_button(page, "Save + Test + Push");
        back = gsv_button(page, "Back");
    }

    public string[] transport_choices() {
        string[] choices = {};
        var model = transport.get_model();
        assert(model != null);
        var strings = (Gtk.StringList) (!) model;
        for (uint i = 0; i < strings.get_n_items(); i++) {
            choices += (string) strings.get_string(i);
        }
        return choices;
    }

    public string[] provider_choices() {
        string[] choices = {};
        var model = provider.get_model();
        assert(model != null);
        var strings = (Gtk.StringList) (!) model;
        for (uint i = 0; i < strings.get_n_items(); i++) {
            choices += (string) strings.get_string(i);
        }
        return choices;
    }
}

public Gee.ArrayList<Gtk.Widget> gsv_descendants(Gtk.Widget root) {
    var found = new Gee.ArrayList<Gtk.Widget>();
    Gtk.Widget? child = root.get_first_child();
    while (child != null) {
        found.add((!) child);
        found.add_all(gsv_descendants((!) child));
        child = ((!) child).get_next_sibling();
    }
    return found;
}

public Gtk.Widget gsv_child(Gtk.Widget parent, int index) {
    Gtk.Widget? child = parent.get_first_child();
    for (int i = 0; i < index && child != null; i++) {
        child = ((!) child).get_next_sibling();
    }
    assert(child != null);
    return (!) child;
}

public Gtk.Widget gsv_named(Gtk.Widget root, string name) {
    foreach (var widget in gsv_descendants(root)) {
        if (widget.get_name() == name) {
            return widget;
        }
    }
    assert_not_reached();
}

public Gtk.Button gsv_button(Gtk.Widget root, string label) {
    foreach (var widget in gsv_descendants(root)) {
        var button = widget as Gtk.Button;
        if (button != null && ((!) button).get_label() == label) {
            return (!) button;
        }
    }
    assert_not_reached();
}

public Gtk.Entry gsv_entry(Gtk.Widget root, string placeholder) {
    foreach (var widget in gsv_descendants(root)) {
        var entry = widget as Gtk.Entry;
        if (entry != null && ((!) entry).get_placeholder_text() == placeholder) {
            return (!) entry;
        }
    }
    assert_not_reached();
}

public bool gsv_has_label(Gtk.Widget root, string text) {
    foreach (var widget in gsv_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label != null && ((!) label).get_text() == text) {
            return true;
        }
    }
    return false;
}

public string gsv_text_view_text(Gtk.TextView view) {
    Gtk.TextIter start;
    Gtk.TextIter end;
    view.get_buffer().get_bounds(out start, out end);
    return view.get_buffer().get_text(start, end, false);
}

// Process-wide test environment. GLib caches the home directory, so HOME is redirected once, before
// anything asks for it, and every test that touches ~/.ssh asserts the redirect took effect first.
// On POSIX the four CLI tools the service runs by name are replaced by shims placed first on PATH,
// so no test ever starts a real gh, git, ssh or ssh-keygen (and none touches the network).
public class GitSyncViewEnv : Object {
    public static string home = "";
    public static string shim_dir = "";
    public static string log_path = "";
    public static bool home_isolated = false;
    public static bool shims_available = false;
    public static Gee.ArrayList<string> temp_dirs;

    private const string SHIM_SCRIPT = """#!/bin/sh
name=$(basename "$0")
printf '%s\n' "$name $*" >> "$HOLDER_FAKE_CLI_LOG"
case "$name" in
gh)
  case "$1" in
  auth)
    if [ "$HOLDER_FAKE_GH_AUTH" = "ok" ]; then echo "Logged in to github.com"; exit 0; fi
    echo "You are not logged into any GitHub hosts."
    exit 1 ;;
  api)
    echo "$HOLDER_FAKE_GH_LOGIN"
    exit 0 ;;
  repo)
    if [ "$HOLDER_FAKE_GH_CREATE" = "ok" ]; then echo "created"; exit 0; fi
    if [ -n "$HOLDER_FAKE_GH_CREATE_OUTPUT" ]; then echo "$HOLDER_FAKE_GH_CREATE_OUTPUT"; fi
    exit 1 ;;
  esac ;;
git)
  if [ "$1" = "ls-remote" ]; then
    if [ "$HOLDER_FAKE_GIT_LSREMOTE" = "ok" ]; then exit 0; fi
    if [ -n "$HOLDER_FAKE_GIT_OUTPUT" ]; then echo "$HOLDER_FAKE_GIT_OUTPUT"; fi
    exit 128
  fi ;;
ssh)
  if [ "$HOLDER_FAKE_SSH_PROBE" = "ok" ]; then
    echo "Hi octocat! You've successfully authenticated, but GitHub does not provide shell access." >&2
    exit 1
  fi
  if [ "$HOLDER_FAKE_SSH_PROBE" = "other" ]; then
    echo "Connection timed out" >&2
    exit 255
  fi
  if [ "$HOLDER_FAKE_SSH_PROBE" = "silent" ]; then exit 255; fi
  echo "git@github.com: Permission denied (publickey)." >&2
  exit 255 ;;
ssh-keygen)
  key=""
  while [ $# -gt 0 ]; do
    if [ "$1" = "-f" ]; then key="$2"; fi
    shift
  done
  if [ "$HOLDER_FAKE_KEYGEN" = "ok" ]; then
    echo "fake private key" > "$key"
    echo "ssh-ed25519 AAAAFAKEKEY fake@example.com" > "$key.pub"
    exit 0
  fi
  if [ -n "$HOLDER_FAKE_KEYGEN_OUTPUT" ]; then echo "$HOLDER_FAKE_KEYGEN_OUTPUT"; fi
  exit 1 ;;
esac
exit 0
""";

    public static void install() {
        // The field initialisers above only run when the class type is initialised, which never
        // happens for this static-only helper, so the strings start out NULL. Windows returns early
        // below without creating shims, and reset() and cleanup() read every one of them.
        home = "";
        shim_dir = "";
        log_path = "";
        home_isolated = false;
        shims_available = false;
        temp_dirs = new Gee.ArrayList<string>();

        try {
            home = DirUtils.make_tmp("holder-git-view-home-XXXXXX");
        } catch (Error e) {
            return;
        }
        Environment.set_variable("HOME", home, true);
        home_isolated = Environment.get_home_dir() == home;

        if (Path.DIR_SEPARATOR == '\\') {
            return;
        }
        try {
            shim_dir = DirUtils.make_tmp("holder-git-view-shims-XXXXXX");
            log_path = Path.build_filename(shim_dir, "commands.log");
            foreach (var tool in new string[] { "gh", "git", "ssh", "ssh-keygen" }) {
                var path = Path.build_filename(shim_dir, tool);
                FileUtils.set_contents(path, SHIM_SCRIPT);
                FileUtils.chmod(path, 0755);
            }
        } catch (Error e) {
            return;
        }
        Environment.set_variable("HOLDER_FAKE_CLI_LOG", log_path, true);
        Environment.set_variable(
            "PATH",
            shim_dir + Path.SEARCHPATH_SEPARATOR_S + (Environment.get_variable("PATH") ?? ""),
            true
        );
        shims_available = true;
        reset();
    }

    // Puts every fake tool back to "everything works" and forgets earlier commands and ssh files.
    public static void reset() {
        set_env("HOLDER_FAKE_GH_AUTH", "ok");
        set_env("HOLDER_FAKE_GH_LOGIN", "octocat");
        set_env("HOLDER_FAKE_GH_CREATE", "ok");
        set_env("HOLDER_FAKE_GH_CREATE_OUTPUT", "");
        set_env("HOLDER_FAKE_GIT_LSREMOTE", "ok");
        set_env("HOLDER_FAKE_GIT_OUTPUT", "");
        set_env("HOLDER_FAKE_SSH_PROBE", "ok");
        set_env("HOLDER_FAKE_KEYGEN", "ok");
        set_env("HOLDER_FAKE_KEYGEN_OUTPUT", "");
        if (log_path.length > 0) {
            FileUtils.remove(log_path);
        }
        clear_ssh_dir();
    }

    public static void set_env(string name, string value) {
        Environment.set_variable(name, value, true);
    }

    public static string ssh_dir() {
        return Path.build_filename(home, ".ssh");
    }

    public static void clear_ssh_dir() {
        if (home.length == 0) {
            return;
        }
        foreach (var name in new string[] { "id_ed25519", "id_ed25519.pub", "id_rsa.pub" }) {
            FileUtils.remove(Path.build_filename(ssh_dir(), name));
        }
        FileUtils.remove(ssh_dir());
    }

    public static void write_ssh_file(string name, string contents) {
        DirUtils.create_with_parents(ssh_dir(), 0700);
        try {
            FileUtils.set_contents(Path.build_filename(ssh_dir(), name), contents);
        } catch (Error e) {
            assert_not_reached();
        }
    }

    // Removes the temporary HOME and shim directories (both only ever hold files this class wrote).
    public static void cleanup() {
        foreach (var root in new string[] { home, shim_dir }) {
            if (root.length > 0) {
                remove_tree(root);
            }
        }
        foreach (var root in temp_dirs) {
            remove_tree(root);
        }
    }

    // A fresh, empty directory for a view to use as its home directory; removed by cleanup(). The
    // fake service tests use it instead of redirecting HOME, so they run on every platform.
    public static string make_home() {
        try {
            var dir = DirUtils.make_tmp("holder-git-view-fakehome-XXXXXX");
            temp_dirs.add(dir);
            return dir;
        } catch (Error e) {
            assert_not_reached();
        }
    }

    private static void remove_tree(string path) {
        if (FileUtils.test(path, FileTest.IS_DIR) && !FileUtils.test(path, FileTest.IS_SYMLINK)) {
            try {
                var dir = Dir.open(path, 0);
                string? name;
                while ((name = dir.read_name()) != null) {
                    remove_tree(Path.build_filename(path, (!) name));
                }
            } catch (Error e) {
                // Best effort: a leftover temp directory is harmless.
            }
        }
        FileUtils.remove(path);
    }

    public static string commands() {
        string contents;
        try {
            FileUtils.get_contents(log_path, out contents);
        } catch (Error e) {
            return "";
        }
        return contents;
    }

    public static bool ran(string fragment) {
        return commands().contains(fragment);
    }

    public static bool require_home() {
        if (!home_isolated || Environment.get_home_dir() != home) {
            Test.skip("HOME could not be redirected on this platform");
            return false;
        }
        return true;
    }

    public static bool require_shims() {
        if (!require_home()) {
            return false;
        }
        if (!shims_available) {
            Test.skip("fake gh/git/ssh tools are POSIX shell scripts");
            return false;
        }
        return true;
    }
}

}
