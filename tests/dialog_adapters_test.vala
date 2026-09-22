using GLib;

namespace HolderLinuxTests {

// Each test gets its own never-presented window as the dialogs' parent. libadwaita 1.5 (the minimum
// the project supports) never removes a closed dialog from a window that is not shown, so a shared
// window would hand later tests an earlier test's dialog.
private class DialogHost : Object {
    public Adw.Window window = new Adw.Window();

    public Adw.AlertDialog wait_for_dialog(Adw.AlertDialog? previous = null) {
        assert(wait_for_condition(() => {
            var current = window.get_visible_dialog();
            return current != null && current != previous;
        }));
        return (Adw.AlertDialog) (!) window.get_visible_dialog();
    }

    public void assert_no_new_dialog(Adw.AlertDialog? previous = null) {
        assert(!wait_for_condition(() => {
            var current = window.get_visible_dialog();
            return current != null && current != previous;
        }, 100));
    }
}

// An async call that never suspends still completes from an idle callback, so a flow started by
// `.begin()` finishes on the next main loop turns. Running the loop until it is idle lets negative
// assertions ("nothing happened") be made after the flow has really finished.
private void settle() {
    while (MainContext.default().iteration(false)) {}
}

private class FakeLauncher : Object, HolderLinux.IUriLauncher {
    public Gee.ArrayList<string> launched = new Gee.ArrayList<string>();
    public bool fail = false;

    public void launch(string uri) throws Error {
        if (fail) {
            throw new IOError.FAILED("no browser");
        }
        launched.add(uri);
    }
}

private class FakeRecoveryService : Object, HolderLinux.IRecoveryService {
    public string payload = "recovery-token-payload";
    public bool fail_load = false;
    public string loaded_from = "";

    public string build_safe_filename(string project_name) {
        return "%s.hrk".printf(project_name);
    }

    public string write_payload_to_temp_attachment(string project_name, string payload) throws Error {
        return "/tmp/fake.hrk";
    }

    public void open_email_with_attachment(string attachment_path) throws Error {}

    public void save_payload_to_path(string path, string payload) throws Error {}

    public string load_payload_from_path(string path) throws Error {
        loaded_from = path;
        if (fail_load) {
            throw new IOError.FAILED("unreadable key file");
        }
        return payload;
    }
}

private class FakeRecoveryContext : Object, HolderLinux.IRecoveryContext {
    public HolderLinux.IHolderApi? get_api_client() {
        return null;
    }

    public async void reload_everything() {}
}

// Answers the chooser questions: `choice` is what the user "picked", `cancel` dismisses the chooser,
// `error` makes it fail.
private class FakePicker : Object, HolderLinux.IFilePicker {
    public File? choice = null;
    public bool cancel = false;
    public string? error = null;
    public Gee.ArrayList<string> requests = new Gee.ArrayList<string>();

    public async File? pick_folder(Gtk.Window parent, string title) throws Error {
        requests.add("folder|" + title);
        return answer();
    }

    public async File? pick_file(Gtk.Window parent, string title, bool images_only) throws Error {
        requests.add("file|%s|%s".printf(title, images_only ? "images" : "any"));
        return answer();
    }

    public async File? save_file(Gtk.Window parent, string title, string initial_name) throws Error {
        requests.add("save|%s|%s".printf(title, initial_name));
        return answer();
    }

    private File? answer() throws Error {
        if (cancel) {
            throw new IOError.CANCELLED("Dismissed by user");
        }
        if (error != null) {
            throw new IOError.FAILED((!) error);
        }
        return choice;
    }
}

private class RecoveryFixture : Object {
    public DialogHost host = new DialogHost();
    public FakeRecoveryService service = new FakeRecoveryService();
    public FakePicker picker = new FakePicker();
    public HolderLinux.RecoveryUiController ui;
    public HolderLinux.RecoveryDialogAdapter adapter;
    public Gee.ArrayList<string> toasts = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> ui_errors = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> adapter_errors = new Gee.ArrayList<string>();

    public RecoveryFixture() {
        var controller = new HolderLinux.RecoveryController(new FakeRecoveryContext(), service);
        ui = new HolderLinux.RecoveryUiController(controller);
        ui.toast_requested.connect((message) => { toasts.add(message); });
        ui.error_reported.connect((title, details) => { ui_errors.add("%s|%s".printf(title, details)); });
        adapter = new HolderLinux.RecoveryDialogAdapter(host.window, ui, picker);
        adapter.error_reported.connect((title, details) => {
            adapter_errors.add("%s|%s".printf(title, details));
        });
    }
}

private Gtk.Widget? find_widget(Gtk.Widget root, Type type) {
    if (root.get_type().is_a(type)) {
        return root;
    }
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        var found = find_widget((!) child, type);
        if (found != null) {
            return found;
        }
    }
    return null;
}

private Gtk.Entry entry_in(Adw.AlertDialog dialog) {
    var content = dialog.get_extra_child();
    assert(content != null);
    var entry = find_widget((!) content, typeof(Gtk.Entry));
    assert(entry != null);
    return (Gtk.Entry) (!) entry;
}

private Gtk.CheckButton check_button_labeled(Gtk.Widget root, string label) {
    Gtk.CheckButton? found = null;
    collect_check_buttons(root, label, ref found);
    assert(found != null);
    return (!) found;
}

private void collect_check_buttons(Gtk.Widget root, string label, ref Gtk.CheckButton? found) {
    var check = root as Gtk.CheckButton;
    if (check != null && ((!) check).get_label() == label) {
        found = check;
        return;
    }
    for (var child = root.get_first_child(); child != null; child = ((!) child).get_next_sibling()) {
        collect_check_buttons((!) child, label, ref found);
    }
}

private void assert_responses(Adw.AlertDialog dialog,
                              string first,
                              string second,
                              string default_response,
                              string close_response) {
    assert(dialog.has_response(first));
    assert(dialog.has_response(second));
    assert(dialog.get_default_response() == default_response);
    assert(dialog.get_close_response() == close_response);
}

// --- update dialog -------------------------------------------------------------------------

private HolderLinux.UpdateCandidate update_candidate() {
    return new HolderLinux.UpdateCandidate("2.0.0", "Faster sync.", "https://holder.team/download");
}

private void test_update_dialog_offers_later_and_download() {
    var host = new DialogHost();
    var adapter = new HolderLinux.UpdateDialogAdapter(host.window, new FakeLauncher());

    adapter.show(update_candidate(), "1.4.0", (candidate) => {});

    var dialog = host.wait_for_dialog();
    assert(dialog.get_heading() == "Update Available");
    assert(dialog.get_body() == HolderLinux.DialogTextPresenter.update_prompt_body("Faster sync.", "2.0.0", "1.4.0"));
    assert_responses(dialog, "later", "download", "download", "later");
    assert(dialog.get_response_appearance("download") == Adw.ResponseAppearance.SUGGESTED);
    assert(dialog.get_response_appearance("later") == Adw.ResponseAppearance.DEFAULT);
}

private void test_update_dialog_later_marks_the_prompt_handled_without_opening_anything() {
    var host = new DialogHost();
    var launcher = new FakeLauncher();
    var adapter = new HolderLinux.UpdateDialogAdapter(host.window, launcher);
    var candidate = update_candidate();
    HolderLinux.UpdateCandidate? handled = null;
    adapter.show(candidate, "1.4.0", (c) => { handled = c; });
    var dialog = host.wait_for_dialog();
    assert(handled == null);

    dialog.response("later");

    assert(handled == candidate);
    assert(launcher.launched.size == 0);
}

private void test_update_dialog_download_marks_it_handled_then_opens_the_download_page() {
    var host = new DialogHost();
    var launcher = new FakeLauncher();
    var adapter = new HolderLinux.UpdateDialogAdapter(host.window, launcher);
    var order = new Gee.ArrayList<string>();
    adapter.show(update_candidate(), "1.4.0", (c) => { order.add("handled"); });
    var dialog = host.wait_for_dialog();

    dialog.response("download");

    order.add("launched:%d".printf(launcher.launched.size));
    assert(order.size == 2 && order[0] == "handled" && order[1] == "launched:1");
    assert(launcher.launched[0] == "https://holder.team/download");
}

private void test_update_dialog_survives_a_browser_that_cannot_open() {
    var host = new DialogHost();
    var launcher = new FakeLauncher();
    launcher.fail = true;
    var adapter = new HolderLinux.UpdateDialogAdapter(host.window, launcher);
    bool handled = false;
    adapter.show(update_candidate(), "1.4.0", (c) => { handled = true; });
    var dialog = host.wait_for_dialog();

    Test.expect_message(null, LogLevelFlags.LEVEL_WARNING, "*Failed to open update URL: no browser*");
    dialog.response("download");
    Test.assert_expected_messages();

    // The prompt still counts as handled, so the user is not nagged again straight away.
    assert(handled);
}

private void test_update_dialog_defaults_to_the_desktop_launcher() {
    var host = new DialogHost();
    var adapter = new HolderLinux.UpdateDialogAdapter(host.window);

    adapter.show(update_candidate(), "1.4.0", (c) => {});

    assert(host.wait_for_dialog().get_heading() == "Update Available");
}

// --- card action dialogs -------------------------------------------------------------------

private void test_move_to_trash_confirmation_is_destructive_and_only_confirms_on_trash() {
    var host = new DialogHost();
    var adapter = new HolderLinux.CardActionDialogAdapter(host.window);
    int confirmed = 0;
    adapter.confirm_move_to_trash("Quarterly plan", () => { confirmed++; });

    var dialog = host.wait_for_dialog();
    assert(dialog.get_heading() == "Move to Trash");
    assert(dialog.get_body() == HolderLinux.DialogTextPresenter.move_to_trash_body("Quarterly plan"));
    assert_responses(dialog, "cancel", "trash", "trash", "cancel");
    assert(dialog.get_response_appearance("trash") == Adw.ResponseAppearance.DESTRUCTIVE);

    dialog.response("cancel");
    assert(confirmed == 0);
    dialog.response("trash");
    assert(confirmed == 1);
}

private void test_create_linked_card_confirmation_only_confirms_on_create() {
    var host = new DialogHost();
    var adapter = new HolderLinux.CardActionDialogAdapter(host.window);
    int confirmed = 0;
    adapter.confirm_create_linked_card("Roadmap", () => { confirmed++; });

    var dialog = host.wait_for_dialog();
    assert(dialog.get_heading() == "Create Linked Card?");
    assert(dialog.get_body() == HolderLinux.DialogTextPresenter.create_linked_card_body("Roadmap"));
    assert_responses(dialog, "cancel", "create", "create", "cancel");
    assert(dialog.get_response_appearance("create") == Adw.ResponseAppearance.SUGGESTED);

    dialog.response("cancel");
    assert(confirmed == 0);
    dialog.response("create");
    assert(confirmed == 1);
}

// --- project create dialog -----------------------------------------------------------------

private void test_project_create_dialog_layout() {
    var host = new DialogHost();
    var adapter = new HolderLinux.ProjectCreateDialogAdapter(host.window);
    adapter.show((name, is_private) => {});

    var dialog = host.wait_for_dialog();
    assert(dialog.get_heading() == "New Project");
    assert(dialog.get_body() == "Enter a project name.");
    assert_responses(dialog, "cancel", "create", "create", "cancel");
    assert(dialog.get_response_appearance("create") == Adw.ResponseAppearance.SUGGESTED);
    var entry = entry_in(dialog);
    assert(entry.get_placeholder_text() == "Project name");
    assert(entry.get_text() == "");
    var content = (!) dialog.get_extra_child();
    assert(check_button_labeled(content, "Private").get_active());
    assert(!check_button_labeled(content, "Shared").get_active());
}

private void test_project_create_dialog_passes_the_typed_name_and_visibility() {
    var host = new DialogHost();
    var adapter = new HolderLinux.ProjectCreateDialogAdapter(host.window);
    var requests = new Gee.ArrayList<string>();
    adapter.show((name, is_private) => {
        requests.add("%s|%s".printf(name, is_private.to_string()));
    });
    var dialog = host.wait_for_dialog();
    entry_in(dialog).set_text("  Field Notes ");

    dialog.response("cancel");
    assert(requests.size == 0);

    dialog.response("create");
    assert(requests.size == 1 && requests[0] == "  Field Notes |true");

    check_button_labeled((!) dialog.get_extra_child(), "Shared").set_active(true);
    dialog.response("create");
    assert(requests.size == 2 && requests[1] == "  Field Notes |false");
}

// --- recovery dialogs ----------------------------------------------------------------------

private void test_pin_dialog_only_enables_continue_for_a_non_blank_pin() {
    var f = new RecoveryFixture();
    f.adapter.request_pin("Export", "Choose a PIN.", (pin) => {});

    var dialog = f.host.wait_for_dialog();
    assert(dialog.get_heading() == "Export");
    assert(dialog.get_body() == "Choose a PIN.");
    assert_responses(dialog, "cancel", "continue", "continue", "cancel");
    assert(dialog.get_response_appearance("continue") == Adw.ResponseAppearance.SUGGESTED);
    var entry = entry_in(dialog);
    assert(entry.get_placeholder_text() == "PIN");
    assert(!entry.get_visibility());
    assert(entry.get_activates_default());
    assert(!dialog.get_response_enabled("continue"));

    entry.set_text("   ");
    assert(!dialog.get_response_enabled("continue"));
    entry.set_text("1234");
    assert(dialog.get_response_enabled("continue"));
    entry.set_text("");
    assert(!dialog.get_response_enabled("continue"));
}

private void test_pin_dialog_hands_over_the_trimmed_pin_only_on_continue() {
    var f = new RecoveryFixture();
    string? accepted = null;
    f.adapter.request_pin("Export", "Choose a PIN.", (pin) => { accepted = pin; });
    var dialog = f.host.wait_for_dialog();
    entry_in(dialog).set_text("  1234 ");

    dialog.response("cancel");
    assert(accepted == null);
    assert(f.toasts.size == 0);

    dialog.response("continue");
    assert(accepted == "1234");
}

private void test_pin_dialog_refuses_a_blank_pin_even_if_the_response_is_forced() {
    var f = new RecoveryFixture();
    bool accepted = false;
    f.adapter.request_pin("Export", "Choose a PIN.", (pin) => { accepted = true; });
    var dialog = f.host.wait_for_dialog();
    entry_in(dialog).set_text("   ");

    dialog.response("continue");

    assert(!accepted);
    assert(f.toasts.size == 1 && f.toasts[0] == "PIN is required.");
}

private HolderLinux.RecoveryTokenImportResult import_result() {
    return new HolderLinux.RecoveryTokenImportResult("p1", true, true, false, "", "not_attempted", "");
}

private void test_import_summary_dialog_shows_the_controllers_summary() {
    var f = new RecoveryFixture();
    var result = import_result();

    f.adapter.show_import_summary(result);

    var dialog = f.host.wait_for_dialog();
    assert(dialog.get_heading() == "Recovery Key Imported");
    assert(dialog.get_body() == f.ui.import_summary_body(result));
    assert(dialog.has_response("ok"));
    assert(dialog.get_default_response() == "ok");
    assert(dialog.get_close_response() == "ok");
}

private void test_importing_a_key_asks_for_its_pin_and_hands_over_the_payload() {
    var f = new RecoveryFixture();
    f.picker.choice = File.new_for_path(Path.build_filename(Environment.get_tmp_dir(), "team.hrk"));
    string? pin = null;
    string? token = null;
    f.adapter.open_import_dialog((p, t) => { pin = p; token = t; });

    var dialog = f.host.wait_for_dialog();
    assert(f.picker.requests.size == 1 && f.picker.requests[0] == "file|Import Recovery Key|any");
    assert(f.service.loaded_from == f.picker.choice.get_path());
    assert(dialog.get_heading() == "Unlock Recovery Key");
    assert(dialog.get_body() == "Set your recovery key PIN to unlock and import this `.hrk` file.");
    assert(pin == null);

    entry_in(dialog).set_text("9876");
    dialog.response("continue");

    assert(pin == "9876");
    assert(token == "recovery-token-payload");
    assert(f.adapter_errors.size == 0 && f.ui_errors.size == 0);
}

private void test_importing_does_nothing_when_no_file_is_chosen_or_the_chooser_is_dismissed() {
    var f = new RecoveryFixture();
    bool ready = false;

    f.adapter.open_import_dialog((p, t) => { ready = true; });
    assert(f.picker.requests.size == 1);
    settle();
    f.host.assert_no_new_dialog();

    f.picker.cancel = true;
    f.adapter.open_import_dialog((p, t) => { ready = true; });
    assert(f.picker.requests.size == 2);
    settle();
    f.host.assert_no_new_dialog();

    assert(!ready);
    assert(f.adapter_errors.size == 0 && f.ui_errors.size == 0);
}

private void test_importing_reports_a_chooser_failure() {
    var f = new RecoveryFixture();
    f.picker.error = "portal unavailable";

    f.adapter.open_import_dialog((p, t) => {});

    assert(wait_for_condition(() => f.adapter_errors.size == 1));
    assert(f.adapter_errors[0] == "Recovery key import failed|portal unavailable");
    f.host.assert_no_new_dialog();
}

private void test_importing_reports_an_unreadable_key_and_a_non_local_file() {
    var f = new RecoveryFixture();
    f.service.fail_load = true;
    f.picker.choice = File.new_for_path(Path.build_filename(Environment.get_tmp_dir(), "broken.hrk"));

    f.adapter.open_import_dialog((p, t) => {});
    assert(wait_for_condition(() => f.ui_errors.size == 1));
    assert(f.ui_errors[0] == "Recovery key import failed|unreadable key file");

    f.picker.choice = File.new_for_uri("https://example.test/remote.hrk");
    f.adapter.open_import_dialog((p, t) => {});
    assert(wait_for_condition(() => f.ui_errors.size == 2));
    assert(f.ui_errors[1] == "Recovery key import failed|Please choose a local filesystem path.");
    f.host.assert_no_new_dialog();
}

private void test_saving_a_key_asks_the_chooser_for_the_default_name_and_hands_over_the_path() {
    var f = new RecoveryFixture();
    var path = Path.build_filename(Environment.get_tmp_dir(), "team-recovery.hrk");
    f.picker.choice = File.new_for_path(path);
    bool called = false;
    string? saved = null;

    f.adapter.open_save_dialog("team-recovery.hrk", (p) => { called = true; saved = p; });

    assert(f.picker.requests.size == 1 && f.picker.requests[0] == "save|Save Recovery Key|team-recovery.hrk");
    assert(wait_for_condition(() => called));
    assert(saved == path);
}

private void test_saving_to_a_non_local_location_is_reported_instead_of_ignored() {
    var f = new RecoveryFixture();
    f.picker.choice = File.new_for_uri("https://example.test/remote.hrk");
    bool called = false;
    string? saved = "unset";

    // The window hands whatever it gets to RecoveryUiController.save_payload_to_path.
    f.adapter.open_save_dialog("team-recovery.hrk", (p) => {
        called = true;
        saved = p;
        f.ui.save_payload_to_path(p, "payload");
    });

    assert(wait_for_condition(() => called));
    assert(saved == null);
    assert(f.ui_errors.size == 1);
    assert(f.ui_errors[0] == "Recovery key export failed|Please choose a local filesystem path.");
}

private void test_saving_does_nothing_when_dismissed_and_reports_a_chooser_failure() {
    var f = new RecoveryFixture();
    bool called = false;

    f.adapter.open_save_dialog("x.hrk", (p) => { called = true; });
    assert(f.picker.requests.size == 1);
    settle();
    assert(!called);

    f.picker.cancel = true;
    f.adapter.open_save_dialog("x.hrk", (p) => { called = true; });
    assert(f.picker.requests.size == 2);
    settle();
    assert(!called);
    assert(f.adapter_errors.size == 0);

    f.picker.cancel = false;
    f.picker.error = "disk not mounted";
    f.adapter.open_save_dialog("x.hrk", (p) => { called = true; });
    assert(wait_for_condition(() => f.adapter_errors.size == 1));
    assert(!called);
    assert(f.adapter_errors[0] == "Recovery key export failed|disk not mounted");
}

// --- print adapter -------------------------------------------------------------------------

private class FakePrintService : HolderLinux.PrintService {
    public bool fail_write = false;
    public string? printed_text = null;

    protected override void write_file(string path, string text) throws Error {
        if (fail_write) {
            throw new IOError.FAILED("disk full");
        }
        printed_text = text;
    }

    protected override async void run_print_dialog(Gtk.Window? parent, string path) throws Error {}
}

private class PrintFixture : Object {
    public FakePrintService service = new FakePrintService();
    public HolderLinux.PrintAdapter adapter;
    public Gee.ArrayList<string> toasts = new Gee.ArrayList<string>();
    public Gee.ArrayList<string> errors = new Gee.ArrayList<string>();
    public Gtk.Window parent = new Gtk.Window();

    public PrintFixture() {
        adapter = new HolderLinux.PrintAdapter(service);
        adapter.toast_requested.connect((message) => { toasts.add(message); });
        adapter.error_reported.connect((title, details) => { errors.add("%s|%s".printf(title, details)); });
    }

    public void print(string text) {
        bool done = false;
        adapter.print_text.begin(parent, text, (obj, res) => {
            adapter.print_text.end(res);
            done = true;
        });
        assert(wait_for_condition(() => done));
    }
}

private void test_printing_nothing_is_a_toast_not_an_error() {
    var f = new PrintFixture();

    f.print("   \n ");

    assert(f.toasts.size == 1 && f.toasts[0] == "Nothing to print.");
    assert(f.errors.size == 0);
    assert(f.service.printed_text == null);
}

private void test_printing_a_card_hands_its_text_to_the_print_service() {
    var f = new PrintFixture();

    f.print("Meeting notes");

    assert(f.service.printed_text == "Meeting notes");
    assert(f.toasts.size == 0 && f.errors.size == 0);
}

private void test_a_print_failure_is_reported_as_an_error() {
    var f = new PrintFixture();
    f.service.fail_write = true;

    f.print("Meeting notes");

    assert(f.toasts.size == 0);
    assert(f.errors.size == 1);
    assert(f.errors[0] == "Print failed|Could not prepare print file: disk full");
}

public static int main(string[] args) {
    Test.init(ref args);
    if (!Gtk.init_check()) {
        stdout.printf("Skipping dialog adapter tests: GTK display is unavailable.\n");
        return 0;
    }
    Adw.init();

    var update = "/holder/dialog-adapters/update/";
    Test.add_func(update + "layout", test_update_dialog_offers_later_and_download);
    Test.add_func(update + "later", test_update_dialog_later_marks_the_prompt_handled_without_opening_anything);
    Test.add_func(update + "download", test_update_dialog_download_marks_it_handled_then_opens_the_download_page);
    Test.add_func(update + "download-failure", test_update_dialog_survives_a_browser_that_cannot_open);
    Test.add_func(update + "default-launcher", test_update_dialog_defaults_to_the_desktop_launcher);

    var card = "/holder/dialog-adapters/card-action/";
    Test.add_func(card + "trash", test_move_to_trash_confirmation_is_destructive_and_only_confirms_on_trash);
    Test.add_func(card + "linked-card", test_create_linked_card_confirmation_only_confirms_on_create);

    var project = "/holder/dialog-adapters/project-create/";
    Test.add_func(project + "layout", test_project_create_dialog_layout);
    Test.add_func(project + "create", test_project_create_dialog_passes_the_typed_name_and_visibility);

    var recovery = "/holder/dialog-adapters/recovery/";
    Test.add_func(recovery + "pin-gating", test_pin_dialog_only_enables_continue_for_a_non_blank_pin);
    Test.add_func(recovery + "pin-continue", test_pin_dialog_hands_over_the_trimmed_pin_only_on_continue);
    Test.add_func(recovery + "pin-forced-blank", test_pin_dialog_refuses_a_blank_pin_even_if_the_response_is_forced);
    Test.add_func(recovery + "summary", test_import_summary_dialog_shows_the_controllers_summary);
    Test.add_func(recovery + "import", test_importing_a_key_asks_for_its_pin_and_hands_over_the_payload);
    Test.add_func(recovery + "import-nothing", test_importing_does_nothing_when_no_file_is_chosen_or_the_chooser_is_dismissed);
    Test.add_func(recovery + "import-chooser-failure", test_importing_reports_a_chooser_failure);
    Test.add_func(recovery + "import-bad-file", test_importing_reports_an_unreadable_key_and_a_non_local_file);
    Test.add_func(recovery + "save", test_saving_a_key_asks_the_chooser_for_the_default_name_and_hands_over_the_path);
    Test.add_func(recovery + "save-non-local", test_saving_to_a_non_local_location_is_reported_instead_of_ignored);
    Test.add_func(recovery + "save-dismissed", test_saving_does_nothing_when_dismissed_and_reports_a_chooser_failure);

    var print = "/holder/dialog-adapters/print/";
    Test.add_func(print + "nothing", test_printing_nothing_is_a_toast_not_an_error);
    Test.add_func(print + "success", test_printing_a_card_hands_its_text_to_the_print_service);
    Test.add_func(print + "failure", test_a_print_failure_is_reported_as_an_error);
    return Test.run();
}

}
