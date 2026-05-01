private void test_ai_panel_width_clamps_to_supported_range() {
    assert(HolderLinux.WorkspaceLayout.clamp_ai_panel_width(100) == 360);
    assert(HolderLinux.WorkspaceLayout.clamp_ai_panel_width(500) == 500);
    assert(HolderLinux.WorkspaceLayout.clamp_ai_panel_width(900) == 720);
}

private void test_default_ai_panel_width_uses_fraction_with_clamps() {
    assert(HolderLinux.WorkspaceLayout.default_ai_panel_width(1000) == 380);
    assert(HolderLinux.WorkspaceLayout.default_ai_panel_width(200) == 360);
    assert(HolderLinux.WorkspaceLayout.default_ai_panel_width(3000) == 720);
}

private void test_initial_ai_panel_position_uses_default_width() {
    assert(HolderLinux.WorkspaceLayout.initial_ai_panel_position(1000, -1, false, 0, 1000) == 620);
}

private void test_initial_ai_panel_position_uses_persisted_width_when_user_set() {
    assert(HolderLinux.WorkspaceLayout.initial_ai_panel_position(1000, 500, true, 0, 1000) == 500);
}

private void test_initial_ai_panel_position_clamps_to_paned_bounds() {
    assert(HolderLinux.WorkspaceLayout.initial_ai_panel_position(1000, 900, true, 100, 450) == 280);
    assert(HolderLinux.WorkspaceLayout.initial_ai_panel_position(1000, 100, true, 700, 900) == 700);
}

private void test_initial_toolbox_position_uses_default_fraction() {
    assert(HolderLinux.WorkspaceLayout.initial_toolbox_position(800, 0, 800) == 400);
}

private void test_initial_toolbox_position_clamps_to_paned_bounds() {
    assert(HolderLinux.WorkspaceLayout.initial_toolbox_position(800, 500, 900) == 500);
    assert(HolderLinux.WorkspaceLayout.initial_toolbox_position(800, 0, 300) == 300);
    assert(HolderLinux.WorkspaceLayout.initial_toolbox_position(800, 450, 200) == 450);
}

public int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/holder/workspace-layout/ai-panel-width-clamps", test_ai_panel_width_clamps_to_supported_range);
    Test.add_func("/holder/workspace-layout/default-ai-panel-width", test_default_ai_panel_width_uses_fraction_with_clamps);
    Test.add_func("/holder/workspace-layout/initial-ai-panel-position-default", test_initial_ai_panel_position_uses_default_width);
    Test.add_func("/holder/workspace-layout/initial-ai-panel-position-persisted", test_initial_ai_panel_position_uses_persisted_width_when_user_set);
    Test.add_func("/holder/workspace-layout/initial-ai-panel-position-clamps", test_initial_ai_panel_position_clamps_to_paned_bounds);
    Test.add_func("/holder/workspace-layout/initial-toolbox-position-default", test_initial_toolbox_position_uses_default_fraction);
    Test.add_func("/holder/workspace-layout/initial-toolbox-position-clamps", test_initial_toolbox_position_clamps_to_paned_bounds);

    return Test.run();
}
