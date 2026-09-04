using GLib;

namespace HolderLinux.Tests {

private class RecordingWindowActionSink : Object, HolderLinux.IWindowActionSink {
    public int refresh_calls = 0;
    public int save_calls = 0;
    public int new_project_calls = 0;
    public int new_card_calls = 0;
    public int flowboard_new_child_card_calls = 0;
    public int move_selected_card_to_trash_calls = 0;
    public int toggle_toolbox_calls = 0;
    public int find_replace_calls = 0;
    public int print_calls = 0;
    public int show_local_info_calls = 0;
    public int show_preferences_calls = 0;
    public int show_about_calls = 0;

    public void on_refresh_requested() { refresh_calls++; }
    public void on_save_requested() { save_calls++; }
    public void on_new_project_requested() { new_project_calls++; }
    public void on_new_card_requested() { new_card_calls++; }
    public void on_flowboard_new_child_card_requested() { flowboard_new_child_card_calls++; }
    public void on_move_selected_card_to_trash_requested() { move_selected_card_to_trash_calls++; }
    public void on_toggle_toolbox_requested() { toggle_toolbox_calls++; }
    public void on_find_replace_requested() { find_replace_calls++; }
    public void on_print_requested() { print_calls++; }
    public void on_show_local_info_requested() { show_local_info_calls++; }
    public void on_show_preferences_requested() { show_preferences_calls++; }
    public void on_show_about_requested() { show_about_calls++; }
}

private void activate(GLib.ActionMap map, string name) {
    var action = map.lookup_action(name);
    assert(action != null);
    ((!) action).activate(null);
}

private void test_bind_registers_actions_that_call_sink_methods() {
    var action_group = new SimpleActionGroup();
    var sink = new RecordingWindowActionSink();
    var binder = new HolderLinux.WindowActionBinder(action_group, sink);

    binder.bind();

    activate(action_group, "refresh");
    activate(action_group, "save");
    activate(action_group, "new-project");
    activate(action_group, "new-card");
    activate(action_group, "flowboard-new-child-card");
    activate(action_group, "move-selected-card-to-trash");
    activate(action_group, "toggle-toolbox");
    activate(action_group, "find-replace");
    activate(action_group, "print");
    activate(action_group, "show-local-info");
    activate(action_group, "show-preferences");
    activate(action_group, "show-about");

    assert(sink.refresh_calls == 1);
    assert(sink.save_calls == 1);
    assert(sink.new_project_calls == 1);
    assert(sink.new_card_calls == 1);
    assert(sink.flowboard_new_child_card_calls == 1);
    assert(sink.move_selected_card_to_trash_calls == 1);
    assert(sink.toggle_toolbox_calls == 1);
    assert(sink.find_replace_calls == 1);
    assert(sink.print_calls == 1);
    assert(sink.show_local_info_calls == 1);
    assert(sink.show_preferences_calls == 1);
    assert(sink.show_about_calls == 1);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/window-action-binder/bind-registers-actions-that-call-sink-methods", test_bind_registers_actions_that_call_sink_methods);
    return Test.run();
}

}
