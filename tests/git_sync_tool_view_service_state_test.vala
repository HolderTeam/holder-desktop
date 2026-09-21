using GLib;

namespace HolderLinuxTests {

// The configured page's Open/Copy actions (through a fake launcher and clipboard) and flows that
// finish after the selection has moved to another project.
private const string GFA_REMOTE = "git@github.com:octocat/runbook.git";

// ---- Open repository / Copy URL ----

private void gfa_test_the_repository_is_opened_in_the_browser() {
    var h = new GitSyncViewHarness(GFA_REMOTE);

    gsv_button(h.view.widget, "Open repository").clicked();

    assert(h.launcher.uris.size == 1 && h.launcher.uris[0] == "https://github.com/octocat/runbook");
    assert(h.errors.size == 0);
}

private void gfa_test_a_browser_that_cannot_open_the_repository_is_reported() {
    var h = new GitSyncViewHarness(GFA_REMOTE);
    h.launcher.failure = new IOError.FAILED("no browser");

    gsv_button(h.view.widget, "Open repository").clicked();

    assert(h.errors.contains("Could not open repository|no browser"));
}

private void gfa_test_a_remote_with_no_web_page_opens_nothing() {
    var h = new GitSyncViewHarness("/srv/git/p1.git");
    assert(!gsv_button(h.view.widget, "Open repository").get_sensitive());

    gsv_button(h.view.widget, "Open repository").clicked();

    assert(h.launcher.uris.size == 0);
    assert(h.errors.size == 0);
}

private void gfa_test_the_remote_url_is_copied() {
    var h = new GitSyncViewHarness(GFA_REMOTE);

    gsv_button(h.view.widget, "Copy URL").clicked();

    assert(h.clipboard.texts.size == 1 && h.clipboard.texts[0] == GFA_REMOTE);
    assert(h.toasts.contains("Repository URL copied."));
}

private void gfa_test_copying_the_remote_without_a_clipboard_is_reported() {
    var h = new GitSyncViewHarness(GFA_REMOTE);
    h.clipboard.available = false;

    gsv_button(h.view.widget, "Copy URL").clicked();

    // It used to do nothing at all, unlike copying the public key.
    assert(h.errors.contains("Clipboard unavailable|No display available."));
    assert(!h.toasts.contains("Repository URL copied."));
}

private void gfa_test_copying_with_nothing_configured_does_nothing() {
    var h = new GitSyncViewHarness(null);

    gsv_button(h.view.widget, "Copy URL").clicked();

    assert(h.clipboard.texts.size == 0);
    assert(h.toasts.size == 0);
    assert(h.errors.size == 0);
}

// ---- flows that finish after the selection moved ----

private void gfa_test_a_disconnect_that_finishes_after_the_selection_moved_leaves_the_new_project_alone() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    h.store.append(gsv_project("p2", "Second Project", "https://example.com/p2.git"));
    gsv_button(h.view.widget, "Disconnect…").clicked();
    assert(h.wait_for_dialog());
    h.api.stall_next_set_remote = true;
    ((!) h.dialog()).response("disconnect");
    assert(wait_for_condition(() => h.api.has_stalled_set_remote(), 5000));

    h.selection.set_selected(1);
    h.settle();
    assert(h.state_page() == "configured");
    assert(h.named_label("git-configured-project").get_text() == "Project: Second Project");

    h.api.release_stalled_set_remote();
    assert(h.wait_for_toast("Git sync disconnected."));
    h.settle();

    // The disconnect was for the first project; the second one is still configured and shown.
    assert(h.api.last_git_project_id == "p1");
    assert(h.state_page() == "configured");
    assert(h.named_label("git-configured-project").get_text() == "Project: Second Project");
    assert(h.named_label("git-configured-remote").get_text() == "https://example.com/p2.git");
}

private void gfa_test_a_setup_that_finishes_after_the_selection_moved_does_not_show_the_old_project() {
    var h = new GitSyncViewHarness(null);
    h.store.append(gsv_project("p2", "Second Project", null));
    h.remote_entry().set_text("https://example.com/p1.git");
    h.api.stall_next_push = true;
    h.setup_button("Save").clicked();
    assert(wait_for_condition(() => h.api.has_stalled_push(), 5000));

    h.selection.set_selected(1);
    h.settle();
    assert(h.state_page() == "setup");

    h.api.release_stalled_push();
    h.settle();

    // The remote was saved for the first project, but the second (unconfigured) one is selected.
    assert(h.api.last_git_project_id == "p1");
    assert(h.state_page() == "setup");
    assert(h.named_label("git-configured-project").get_text() != "Project: Runbook Project");
}

private void gfa_test_a_sync_that_finishes_after_the_selection_moved_does_not_show_the_old_project() {
    var h = new GitSyncViewHarness("https://example.com/p1.git");
    h.store.append(gsv_project("p2", "Second Project", null));
    h.api.stall_next_push = true;
    gsv_button(h.view.widget, "Sync now").clicked();
    assert(wait_for_condition(() => h.api.has_stalled_push(), 5000));

    h.selection.set_selected(1);
    h.settle();
    assert(h.state_page() == "setup");

    h.api.release_stalled_push();
    h.settle();

    assert(h.state_page() == "setup");
    assert(gsv_button(h.view.widget, "Sync now").get_sensitive());
}

private void gfa_test_a_replaced_project_selection_no_longer_drives_the_view() {
    var h = new GitSyncViewHarness(null);
    h.store.append(gsv_project("p2", "Second Project", null));
    var other_store = new GLib.ListStore(typeof(HolderLinux.Project));
    other_store.append(gsv_project("q1", "Q One", null));
    other_store.append(gsv_project("q2", "Q Two", null));
    var other = new Gtk.SingleSelection(other_store);
    h.view.set_project_selection(other);
    h.settle();
    var before = h.api.list_projects_calls;

    // Moving the old selection must not refresh the view any more...
    h.selection.set_selected(1);
    h.settle();
    assert(h.api.list_projects_calls == before);

    // ...while the new one does.
    other.set_selected(1);
    h.settle();
    assert(h.api.list_projects_calls > before);
}

public void register_git_sync_view_service_state_tests() {
    var prefix = "/holder/git-sync-view/fake-service/state/";
    Test.add_func(prefix + "open-repository/launches", gfa_test_the_repository_is_opened_in_the_browser);
    Test.add_func(prefix + "open-repository/failure", gfa_test_a_browser_that_cannot_open_the_repository_is_reported);
    Test.add_func(prefix + "open-repository/no-web-page", gfa_test_a_remote_with_no_web_page_opens_nothing);
    Test.add_func(prefix + "copy-url/copies", gfa_test_the_remote_url_is_copied);
    Test.add_func(prefix + "copy-url/no-clipboard", gfa_test_copying_the_remote_without_a_clipboard_is_reported);
    Test.add_func(prefix + "copy-url/nothing-configured", gfa_test_copying_with_nothing_configured_does_nothing);
    Test.add_func(prefix + "selection-moved/disconnect",
                  gfa_test_a_disconnect_that_finishes_after_the_selection_moved_leaves_the_new_project_alone);
    Test.add_func(prefix + "selection-moved/setup",
                  gfa_test_a_setup_that_finishes_after_the_selection_moved_does_not_show_the_old_project);
    Test.add_func(prefix + "selection-moved/sync",
                  gfa_test_a_sync_that_finishes_after_the_selection_moved_does_not_show_the_old_project);
    Test.add_func(prefix + "selection/replaced", gfa_test_a_replaced_project_selection_no_longer_drives_the_view);
}

}
