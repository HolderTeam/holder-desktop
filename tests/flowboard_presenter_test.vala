private HolderLinux.FlowboardTile make_tile(bool is_container,
                                            int64 updated_at,
                                            int child_count = 0,
                                            string? card_id = "card-1",
                                            string? parent_card_id = "parent-1",
                                            int sibling_count = 3,
                                            int sibling_index = 1) {
    return new HolderLinux.FlowboardTile(
        "node-1",
        "Runbook Card",
        updated_at,
        is_container,
        card_id,
        "project-1",
        parent_card_id,
        sibling_count,
        sibling_index,
        child_count
    );
}

private void test_tile_presentation_for_empty_item() {
    var presentation = HolderLinux.FlowboardPresenter.tile(null, 1000);

    assert(presentation.title == "");
    assert(presentation.meta_text == "");
    assert(!presentation.folder_tab_visible);
    assert(presentation.header_margin_top == 0);
    assert(!presentation.branch_css);
    assert(presentation.card_id == "");
}

private void test_tile_presentation_for_leaf_card() {
    var presentation = HolderLinux.FlowboardPresenter.tile(make_tile(false, 940), 1000);

    assert(presentation.title == "Runbook Card");
    assert(presentation.meta_text == "1m ago");
    assert(!presentation.folder_tab_visible);
    assert(presentation.header_margin_top == 15);
    assert(!presentation.branch_css);
    assert(presentation.card_id == "card-1");
    assert(presentation.parent_card_id == "parent-1");
    assert(presentation.sibling_count == 3);
    assert(presentation.sibling_index == 1);
}

private void test_tile_presentation_for_container_card() {
    var one_child = HolderLinux.FlowboardPresenter.tile(make_tile(true, 900, 1), 1000);
    var many_children = HolderLinux.FlowboardPresenter.tile(make_tile(true, 900, 4), 1000);

    assert(one_child.meta_text == "1 item | 1m ago");
    assert(many_children.meta_text == "4 items | 1m ago");
    assert(one_child.folder_tab_visible);
    assert(one_child.header_margin_top == 0);
    assert(one_child.branch_css);
}

private void test_drop_fraction_defaults_and_clamps() {
    assert(HolderLinux.FlowboardPresenter.drop_fraction(10, 0) == 0.5);
    assert(HolderLinux.FlowboardPresenter.drop_fraction(-10, 100) == 0.0);
    assert(HolderLinux.FlowboardPresenter.drop_fraction(120, 100) == 1.0);
    assert(HolderLinux.FlowboardPresenter.drop_fraction(40, 100) == 0.4);
}

private void test_drop_hint_uses_quarters() {
    assert(HolderLinux.FlowboardPresenter.drop_hint(20, 100) == HolderLinux.FlowboardDropHint.BEFORE);
    assert(HolderLinux.FlowboardPresenter.drop_hint(50, 100) == HolderLinux.FlowboardDropHint.INTO);
    assert(HolderLinux.FlowboardPresenter.drop_hint(80, 100) == HolderLinux.FlowboardDropHint.AFTER);
}

private void test_reorder_button_sensitivity() {
    assert(!HolderLinux.FlowboardPresenter.move_up_sensitive(""));
    assert(HolderLinux.FlowboardPresenter.move_up_sensitive("parent-1"));
    assert(!HolderLinux.FlowboardPresenter.move_left_sensitive(1, 0));
    assert(!HolderLinux.FlowboardPresenter.move_left_sensitive(3, 0));
    assert(HolderLinux.FlowboardPresenter.move_left_sensitive(3, 1));
    assert(HolderLinux.FlowboardPresenter.move_right_sensitive(3, 1));
    assert(!HolderLinux.FlowboardPresenter.move_right_sensitive(3, 2));
    assert(!HolderLinux.FlowboardPresenter.move_to_boundary_sensitive(1));
    assert(HolderLinux.FlowboardPresenter.move_to_boundary_sensitive(2));
}

public int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/holder/flowboard-presenter/tile-empty", test_tile_presentation_for_empty_item);
    Test.add_func("/holder/flowboard-presenter/tile-leaf", test_tile_presentation_for_leaf_card);
    Test.add_func("/holder/flowboard-presenter/tile-container", test_tile_presentation_for_container_card);
    Test.add_func("/holder/flowboard-presenter/drop-fraction", test_drop_fraction_defaults_and_clamps);
    Test.add_func("/holder/flowboard-presenter/drop-hint", test_drop_hint_uses_quarters);
    Test.add_func("/holder/flowboard-presenter/reorder-button-sensitivity", test_reorder_button_sensitivity);

    return Test.run();
}
