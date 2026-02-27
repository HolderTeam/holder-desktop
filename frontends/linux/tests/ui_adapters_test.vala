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

private void test_source_buffer_text_provider_reads_buffer() {
    var buffer = new GtkSource.Buffer(null);
    buffer.set_text("# Title\nBody", -1);
    var provider = new HolderLinux.SourceBufferTextProvider(buffer);
    assert(provider.get_text() == "# Title\nBody");
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/ui_adapters/single_selection_state_round_trip",
                  test_single_selection_state_round_trip);
    Test.add_func("/ui_adapters/source_buffer_text_provider_reads_buffer",
                  test_source_buffer_text_provider_reads_buffer);

    return Test.run();
}

}
