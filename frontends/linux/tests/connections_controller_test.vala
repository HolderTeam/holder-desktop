namespace HolderLinux.Tests {

private CardSummary card(string id,
                         string project_id,
                         string title,
                         double sort_key,
                         string? parent = null,
                         int64 updated_at = 100) {
    return new CardSummary(id, project_id, title, "cards/%s.md".printf(id), sort_key, parent, 1, updated_at);
}

private void test_ellipsize_title() {
    var controller = new ConnectionsController();
    var short_title = "short";
    assert(controller.ellipsize_title(short_title) == short_title);

    var long_title = "123456789012345678901234567890123456789012345678901234567890";
    var result = controller.ellipsize_title(long_title);
    assert(result.char_count() == 47);
    assert(result.has_suffix("..."));
}

private void test_resolve_internal_link() {
    var controller = new ConnectionsController();
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("a", "p1", "Alpha", 10));
    cards.add(card("b", "p1", "Beta", 20));
    cards.add(card("c", "p2", "Alpha", 30));

    assert(controller.resolve_internal_link_target_card_id("b", "p1", cards) == "b");
    assert(controller.resolve_internal_link_target_card_id("Beta", "p1", cards) == "b");
    assert(controller.resolve_internal_link_target_card_id("alpha", "p1", cards) == "a");
    assert(controller.resolve_internal_link_target_card_id("Alpha", "p2", cards) == "c");
    assert(controller.resolve_internal_link_target_card_id("missing", "p1", cards) == null);
}

private void test_compact_structure_markup() {
    var controller = new ConnectionsController();
    var project = new Project("p1", "My Project", "plain", "/tmp/p1", 1, 1);
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("parent", "p1", "Parent", 10, null, 10));
    cards.add(card("sel", "p1", "Selected", 20, null, 20));
    cards.add(card("next", "p1", "Next Card", 30, null, 30));
    cards.add(card("child", "p1", "Child Card", 10, "sel", 40));

    var selected = cards[1];
    var markup = controller.compact_structure_markup(project, selected, cards);
    assert(markup.contains("Project:"));
    assert(markup.contains("Previous:"));
    assert(markup.contains("Next:"));
    assert(markup.contains("Children:"));
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/connections/ellipsize_title", test_ellipsize_title);
    Test.add_func("/holder/connections/resolve_internal_link", test_resolve_internal_link);
    Test.add_func("/holder/connections/compact_structure_markup", test_compact_structure_markup);
    return Test.run();
}

}
