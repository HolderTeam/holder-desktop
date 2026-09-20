using GLib;

namespace HolderLinuxTests {

private HolderLinux.Project empty_state_project(string id = "p1", int root_card_count = 0) {
    return new HolderLinux.Project(id, "Project", "encrypted_git", "/tmp/" + id, 1, 1, null, null, 0, root_card_count);
}

private HolderLinux.CardSummary empty_state_card(string id, string project_id) {
    return new HolderLinux.CardSummary(id, project_id, "Card", id + ".md", 1.0, null, 1, 1);
}

private void test_project_has_known_cards_uses_root_card_count() {
    assert(!HolderLinux.ConnectionsEmptyStatePolicy.project_has_known_cards(empty_state_project("p1", 0)));
    assert(HolderLinux.ConnectionsEmptyStatePolicy.project_has_known_cards(empty_state_project("p1", 2)));
}

private void test_plan_renders_when_project_has_cards() {
    assert(HolderLinux.ConnectionsEmptyStatePolicy.plan_for_project_cards(empty_state_project(), 3, true)
        == HolderLinux.ConnectionsProjectRenderPlan.RENDER_BOARD);
}

private void test_plan_waits_when_metadata_says_cards_exist() {
    assert(HolderLinux.ConnectionsEmptyStatePolicy.plan_for_project_cards(empty_state_project("p1", 4), 0, false)
        == HolderLinux.ConnectionsProjectRenderPlan.SCHEDULE_EMPTY_CHECK);
}

private void test_plan_shows_empty_immediately_only_before_any_board_is_drawn() {
    assert(HolderLinux.ConnectionsEmptyStatePolicy.plan_for_project_cards(empty_state_project(), 0, false)
        == HolderLinux.ConnectionsProjectRenderPlan.SHOW_EMPTY_NOW);
    assert(HolderLinux.ConnectionsEmptyStatePolicy.plan_for_project_cards(empty_state_project(), 0, true)
        == HolderLinux.ConnectionsProjectRenderPlan.SCHEDULE_EMPTY_CHECK);
}

private void test_should_show_no_cards_when_everything_is_still_empty() {
    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    cards.add(empty_state_card("c1", "other"));
    assert(HolderLinux.ConnectionsEmptyStatePolicy.should_show_no_cards(
        false, empty_state_project(), "p1", null, cards
    ));
}

private void test_should_not_show_no_cards_when_state_changed() {
    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    var project = empty_state_project();

    assert(!HolderLinux.ConnectionsEmptyStatePolicy.should_show_no_cards(true, project, "p1", null, cards));
    assert(!HolderLinux.ConnectionsEmptyStatePolicy.should_show_no_cards(false, null, "p1", null, cards));
    assert(!HolderLinux.ConnectionsEmptyStatePolicy.should_show_no_cards(
        false, empty_state_project("p2"), "p1", null, cards
    ));
    assert(!HolderLinux.ConnectionsEmptyStatePolicy.should_show_no_cards(
        false, empty_state_project("p1", 1), "p1", null, cards
    ));
    assert(!HolderLinux.ConnectionsEmptyStatePolicy.should_show_no_cards(
        false, project, "p1", empty_state_card("c9", "p1"), cards
    ));
    cards.add(empty_state_card("c1", "p1"));
    assert(!HolderLinux.ConnectionsEmptyStatePolicy.should_show_no_cards(false, project, "p1", null, cards));
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/connections-empty-state/known-cards", test_project_has_known_cards_uses_root_card_count);
    Test.add_func("/holder/connections-empty-state/plan-render", test_plan_renders_when_project_has_cards);
    Test.add_func("/holder/connections-empty-state/plan-waits-for-known-cards",
                  test_plan_waits_when_metadata_says_cards_exist);
    Test.add_func("/holder/connections-empty-state/plan-empty-now-vs-later",
                  test_plan_shows_empty_immediately_only_before_any_board_is_drawn);
    Test.add_func("/holder/connections-empty-state/show-no-cards", test_should_show_no_cards_when_everything_is_still_empty);
    Test.add_func("/holder/connections-empty-state/do-not-show-no-cards",
                  test_should_not_show_no_cards_when_state_changed);
    return Test.run();
}

}
