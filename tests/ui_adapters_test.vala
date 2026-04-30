using GLib;

namespace HolderLinuxTests {

private void test_single_selection_state_round_trip() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    var p1 = new HolderLinux.Project("p1", "One", "encrypted_git", "/tmp/one", 1, 1);
    var p2 = new HolderLinux.Project("p2", "Two", "encrypted_git", "/tmp/two", 2, 2);
    store.append(p1);
    store.append(p2);

    var selection = new Gtk.SingleSelection(store);
    var state = new HolderLinux.GtkSingleSelectionState(selection);

    state.set_selected_index(1);
    assert(state.get_selected_index() == 1);
    var selected = state.get_selected_item() as HolderLinux.Project;
    assert(selected != null);
    assert(selected.project_id == "p2");
}

private void test_single_selection_state_reflects_cleared_selection() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    store.append(new HolderLinux.Project("p1", "One", "encrypted_git", "/tmp/one", 1, 1));

    var selection = new Gtk.SingleSelection(store);
    selection.set_can_unselect(true);
    var state = new HolderLinux.GtkSingleSelectionState(selection);

    state.set_selected_index(0);
    assert(state.get_selected_item() != null);

    selection.unselect_item(0);
    assert(state.get_selected_index() == Gtk.INVALID_LIST_POSITION);
    assert(state.get_selected_item() == null);
}

private void test_single_selection_state_tracks_external_selection_changes() {
    var store = new GLib.ListStore(typeof(HolderLinux.Project));
    var p1 = new HolderLinux.Project("p1", "One", "encrypted_git", "/tmp/one", 1, 1);
    var p2 = new HolderLinux.Project("p2", "Two", "encrypted_git", "/tmp/two", 2, 2);
    store.append(p1);
    store.append(p2);

    var selection = new Gtk.SingleSelection(store);
    var state = new HolderLinux.GtkSingleSelectionState(selection);

    selection.set_selected(0);
    assert(state.get_selected_index() == 0);
    var selected_first = state.get_selected_item() as HolderLinux.Project;
    assert(selected_first != null);
    assert(selected_first.project_id == "p1");

    selection.set_selected(1);
    assert(state.get_selected_index() == 1);
    var selected_second = state.get_selected_item() as HolderLinux.Project;
    assert(selected_second != null);
    assert(selected_second.project_id == "p2");
}

private void test_source_buffer_text_provider_reads_buffer() {
    var buffer = new GtkSource.Buffer(null);
    buffer.set_text("# Title\nBody", -1);
    var provider = new HolderLinux.SourceBufferTextProvider(buffer);
    assert(provider.get_text() == "# Title\nBody");
}

private void test_source_buffer_text_provider_empty_buffer_returns_empty_string() {
    var buffer = new GtkSource.Buffer(null);
    var provider = new HolderLinux.SourceBufferTextProvider(buffer);
    assert(provider.get_text() == "");
}

private void test_system_clock_returns_plausible_epoch_seconds() {
    var before = new DateTime.now_utc().to_unix();
    var clock = new HolderLinux.SystemClock();
    var now = clock.now_epoch_seconds();
    var after = new DateTime.now_utc().to_unix();
    assert(now >= before);
    assert(now <= after);
}

private void test_main_loop_scheduler_schedule_once_runs_callback_once() {
    var scheduler = new HolderLinux.MainLoopScheduler();
    var loop = new MainLoop();
    int calls = 0;

    uint source_id = scheduler.schedule_once(1, () => {
        calls++;
        loop.quit();
        return Source.CONTINUE;
    });

    assert(source_id > 0);
    loop.run();
    assert(calls == 1);
}

private void test_main_loop_scheduler_schedule_repeating_and_cancel() {
    var scheduler = new HolderLinux.MainLoopScheduler();
    var loop = new MainLoop();
    int calls = 0;
    uint repeating_id = 0;

    repeating_id = scheduler.schedule_repeating(1, () => {
        calls++;
        if (calls >= 2) {
            bool cancelled = scheduler.cancel(repeating_id);
            assert(cancelled);
            loop.quit();
        }
        return Source.CONTINUE;
    });

    assert(repeating_id > 0);
    loop.run();
    assert(calls >= 2);
}

private void test_main_loop_scheduler_cancel_zero_is_false() {
    var scheduler = new HolderLinux.MainLoopScheduler();
    assert(!scheduler.cancel(0));
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/ui_adapters/single_selection_state_round_trip",
                  test_single_selection_state_round_trip);
    Test.add_func("/ui_adapters/single_selection_state_reflects_cleared_selection",
                  test_single_selection_state_reflects_cleared_selection);
    Test.add_func("/ui_adapters/single_selection_state_tracks_external_selection_changes",
                  test_single_selection_state_tracks_external_selection_changes);
    Test.add_func("/ui_adapters/source_buffer_text_provider_reads_buffer",
                  test_source_buffer_text_provider_reads_buffer);
    Test.add_func("/ui_adapters/source_buffer_text_provider_empty_buffer_returns_empty_string",
                  test_source_buffer_text_provider_empty_buffer_returns_empty_string);
    Test.add_func("/ui_adapters/system_clock_returns_plausible_epoch_seconds",
                  test_system_clock_returns_plausible_epoch_seconds);
    Test.add_func("/ui_adapters/main_loop_scheduler_schedule_once_runs_callback_once",
                  test_main_loop_scheduler_schedule_once_runs_callback_once);
    Test.add_func("/ui_adapters/main_loop_scheduler_schedule_repeating_and_cancel",
                  test_main_loop_scheduler_schedule_repeating_and_cancel);
    Test.add_func("/ui_adapters/main_loop_scheduler_cancel_zero_is_false",
                  test_main_loop_scheduler_cancel_zero_is_false);

    return Test.run();
}

}
