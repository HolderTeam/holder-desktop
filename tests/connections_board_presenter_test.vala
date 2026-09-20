using GLib;

namespace HolderLinuxTests {

private HolderLinux.ConnectionsBoardPresenter make_board_presenter() {
    return new HolderLinux.ConnectionsBoardPresenter(new HolderLinux.ConnectionsController());
}

private HolderLinux.Project board_project(string id, string name, int root_cards = 0) {
    return new HolderLinux.Project(id, name, "encrypted_git", "/tmp/" + id, 1, 5, null, null, 0, root_cards);
}

private HolderLinux.CardSummary board_card(string id, string project_id) {
    return new HolderLinux.CardSummary(id, project_id, "Card " + id, id + ".md", 1.0, null, 1, 1);
}

private void test_relations_title_prefers_projects_then_card_then_project() {
    var presenter = make_board_presenter();
    var project = board_project("p1", "Project One");
    var card = board_card("c1", "p1");
    assert(presenter.relations_title(true, project, card) == "Projects");
    assert(presenter.relations_title(false, project, card) == "Card c1");
    assert(presenter.relations_title(false, project, null) == "Project One");
    assert(presenter.relations_title(false, null, null) == "Relations");
}

private void test_relations_title_ellipsizes_long_titles() {
    var presenter = make_board_presenter();
    var project = board_project("p1", "123456789012345678901234567890123456789012345678901234567890");
    var title = presenter.relations_title(false, project, null);
    assert(title.has_suffix("..."));
    assert(title.char_count() == 47);
}

private void test_add_link_is_enabled_only_with_api_card_and_other_cards() {
    var presenter = make_board_presenter();
    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    var selected = board_card("c1", "p1");
    cards.add(selected);
    assert(!presenter.add_link_enabled(false, true, selected, cards));

    cards.add(board_card("c2", "p1"));
    assert(presenter.add_link_enabled(false, true, selected, cards));
    assert(!presenter.add_link_enabled(false, false, selected, cards));
    assert(!presenter.add_link_enabled(false, true, null, cards));
    assert(!presenter.add_link_enabled(true, true, selected, cards));
}

private void test_projects_root_nodes_are_prefixed_and_laid_out() {
    var presenter = make_board_presenter();
    assert(presenter.build_projects_root_nodes(new Gee.ArrayList<HolderLinux.Project>()).size == 0);

    var projects = new Gee.ArrayList<HolderLinux.Project>();
    projects.add(board_project("p1", "One", 3));
    projects.add(board_project("p2", "Two", 0));
    var nodes = presenter.build_projects_root_nodes(projects);
    assert(nodes.size == 2);
    assert(nodes[0].card_id == "project:p1");
    assert(nodes[0].title == "One");
    assert(nodes[0].child_count == 3);
    assert(nodes[0].updated_at == 5);
    assert(nodes[1].card_id == "project:p2");
    assert(nodes[0].x != nodes[1].x || nodes[0].y != nodes[1].y);
}

private void test_canvas_size_uses_minimums_for_empty_and_small_boards() {
    var presenter = make_board_presenter();
    var empty = presenter.canvas_size(new Gee.ArrayList<HolderLinux.ConnectionsBoardNode>());
    assert(empty.width == HolderLinux.ConnectionsBoardPresenter.MIN_WIDTH);
    assert(empty.height == 220);

    var nodes = new Gee.ArrayList<HolderLinux.ConnectionsBoardNode>();
    var node = new HolderLinux.ConnectionsBoardNode("c1", "One", 1, 0);
    node.x = 0;
    node.y = 0;
    nodes.add(node);
    var small = presenter.canvas_size(nodes);
    assert(small.width == HolderLinux.ConnectionsBoardPresenter.MIN_WIDTH);
    assert(small.height == HolderLinux.ConnectionsBoardPresenter.MIN_HEIGHT);
}

private void test_canvas_size_grows_to_fit_far_nodes() {
    var presenter = make_board_presenter();
    var nodes = new Gee.ArrayList<HolderLinux.ConnectionsBoardNode>();
    var far = new HolderLinux.ConnectionsBoardNode("c1", "Far", 1, 0);
    far.x = 1000;
    far.y = 500;
    nodes.add(far);
    var size = presenter.canvas_size(nodes);
    assert(size.width == 1000 + 220 + 48);
    assert(size.height == 500 + 76 + 16);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/connections-board/relations-title", test_relations_title_prefers_projects_then_card_then_project);
    Test.add_func("/holder/connections-board/relations-title-ellipsis", test_relations_title_ellipsizes_long_titles);
    Test.add_func("/holder/connections-board/add-link-enabled",
                  test_add_link_is_enabled_only_with_api_card_and_other_cards);
    Test.add_func("/holder/connections-board/projects-root-nodes", test_projects_root_nodes_are_prefixed_and_laid_out);
    Test.add_func("/holder/connections-board/canvas-minimums", test_canvas_size_uses_minimums_for_empty_and_small_boards);
    Test.add_func("/holder/connections-board/canvas-grows", test_canvas_size_grows_to_fit_far_nodes);
    return Test.run();
}

}
