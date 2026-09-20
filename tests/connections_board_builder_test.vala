using GLib;

namespace HolderLinuxTests {

private HolderLinux.ConnectionsBoardBuilder make_builder() {
    return new HolderLinux.ConnectionsBoardBuilder(new HolderLinux.ConnectionsController());
}

private HolderLinux.Project builder_project(string id) {
    return new HolderLinux.Project(id, "Project " + id, "encrypted_git", "/tmp/" + id, 1, 5);
}

private HolderLinux.CardSummary builder_card(string id, string project_id, string? parent = null, double sort_key = 1.0) {
    return new HolderLinux.CardSummary(id, project_id, "Card " + id, id + ".md", sort_key, parent, 1, 1);
}

private bool has_edge(Gee.ArrayList<HolderLinux.ConnectionsBoardEdge> edges, string from, string to, string kind) {
    foreach (var edge in edges) {
        if (edge.from_card_id == from && edge.to_card_id == to && edge.kind == kind) {
            return true;
        }
    }
    return false;
}

private bool has_node(Gee.ArrayList<HolderLinux.ConnectionsBoardNode> nodes, string id) {
    foreach (var node in nodes) {
        if (node.card_id == id) {
            return true;
        }
    }
    return false;
}

private void test_cards_in_project_filters_by_project() {
    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    cards.add(builder_card("a", "p1"));
    cards.add(builder_card("b", "p2"));
    cards.add(builder_card("c", "p1"));
    var filtered = HolderLinux.ConnectionsBoardBuilder.cards_in_project(builder_project("p1"), cards);
    assert(filtered.size == 2);
    assert(filtered[0].card_id == "a");
    assert(filtered[1].card_id == "c");
}

private void test_card_mode_alone_has_only_the_selected_node() {
    var builder = make_builder();
    var selected = builder_card("c1", "p1");
    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    cards.add(selected);
    var model = builder.build_card_mode(
        builder_project("p1"), selected,
        new Gee.ArrayList<HolderLinux.CardLink>(), new Gee.ArrayList<HolderLinux.CardLink>(),
        new Gee.ArrayList<string>(), cards
    );
    assert(model.nodes.size == 1);
    assert(model.nodes[0].card_id == "c1");
    assert(model.edges.size == 0);
    assert(model.summary == "Card-focused graph.");
}

private void test_card_mode_collects_links_structure_and_internal_links() {
    var builder = make_builder();
    var project = builder_project("p1");
    var selected = builder_card("c1", "p1", null, 1.0);
    var sibling = builder_card("c2", "p1", null, 2.0);
    var child = builder_card("c3", "p1", "c1", 1.0);
    var linked = builder_card("c4", "p1", null, 3.0);
    var back = builder_card("c5", "p1", null, 4.0);
    var target = builder_card("c6", "p1", null, 5.0);
    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    cards.add(selected);
    cards.add(sibling);
    cards.add(child);
    cards.add(linked);
    cards.add(back);
    cards.add(target);

    var outgoing = new Gee.ArrayList<HolderLinux.CardLink>();
    outgoing.add(new HolderLinux.CardLink("c1", "c4", "card", "ref", null, 1));
    outgoing.add(new HolderLinux.CardLink("c1", "r1", "resource", "attachment", null, 2));
    var backlinks = new Gee.ArrayList<HolderLinux.CardLink>();
    backlinks.add(new HolderLinux.CardLink("c5", "c1", "card", "ref", null, 3));
    backlinks.add(new HolderLinux.CardLink("c5", "r1", "resource", "attachment", null, 4));
    var internal_links = new Gee.ArrayList<string>();
    internal_links.add("c6");
    internal_links.add("c1");
    internal_links.add("");

    var model = builder.build_card_mode(project, selected, outgoing, backlinks, internal_links, cards);

    assert(has_edge(model.edges, "c1", "c4", "ref"));
    assert(has_edge(model.edges, "c5", "c1", "ref"));
    assert(has_edge(model.edges, "c1", "c2", "next"));
    assert(has_edge(model.edges, "c1", "c3", "child"));
    assert(has_edge(model.edges, "c1", "c6", "internal"));
    foreach (var edge in model.edges) {
        assert(edge.to_card_id != "r1");
        assert(edge.from_card_id != edge.to_card_id);
    }
    foreach (var id in new string[] { "c1", "c2", "c3", "c4", "c5", "c6" }) {
        assert(has_node(model.nodes, id));
    }
    // nodes were laid out (not all left at the origin)
    bool moved = false;
    foreach (var node in model.nodes) {
        if (node.x != 0 || node.y != 0) {
            moved = true;
        }
    }
    assert(moved);
}

private void test_card_mode_ignores_cards_from_other_projects_for_structure() {
    var builder = make_builder();
    var selected = builder_card("c1", "p1", null, 1.0);
    var other_project_sibling = builder_card("x1", "p2", null, 2.0);
    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    cards.add(selected);
    cards.add(other_project_sibling);
    var model = builder.build_card_mode(
        builder_project("p1"), selected,
        new Gee.ArrayList<HolderLinux.CardLink>(), new Gee.ArrayList<HolderLinux.CardLink>(),
        new Gee.ArrayList<string>(), cards
    );
    assert(model.edges.size == 0);
    assert(model.nodes.size == 1);
}

private void test_project_mode_without_links_shows_structure_summary() {
    var builder = make_builder();
    var project_cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    project_cards.add(builder_card("a", "p1", null, 1.0));
    project_cards.add(builder_card("b", "p1", null, 2.0));
    project_cards.add(builder_card("c", "p1", "a", 1.0));
    var model = builder.build_project_mode(project_cards, new Gee.ArrayList<HolderLinux.CardLink>());
    assert(model.nodes.size == 3);
    assert(has_edge(model.edges, "a", "b", "next"));
    assert(has_edge(model.edges, "a", "c", "child"));
    assert(model.summary.contains("• child: 1"));
    assert(model.summary.contains("• next: 1"));
}

private void test_project_mode_counts_links_and_dedupes() {
    var builder = make_builder();
    var project_cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    project_cards.add(builder_card("a", "p1"));
    project_cards.add(builder_card("b", "p1"));
    var links = new Gee.ArrayList<HolderLinux.CardLink>();
    links.add(new HolderLinux.CardLink("a", "b", "card", "ref", null, 1));
    links.add(new HolderLinux.CardLink("a", "b", "card", "ref", null, 2));
    var model = builder.build_project_mode(project_cards, links);
    assert(has_edge(model.edges, "a", "b", "ref"));
    assert(model.summary.contains("• ref: 1"));
}

private void test_project_mode_with_no_relationships() {
    var builder = make_builder();
    var project_cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    project_cards.add(builder_card("a", "p1", null, 1.0));
    var model = builder.build_project_mode(project_cards, new Gee.ArrayList<HolderLinux.CardLink>());
    assert(model.nodes.size == 1);
    assert(model.edges.size == 0);
    assert(model.summary == "No graph relationships yet.");
}

private void link_many_kinds(Gee.ArrayList<HolderLinux.CardLink> links, string from, string to) {
    foreach (var kind in new string[] { "ref", "blocks", "related", "cites", "extends" }) {
        links.add(new HolderLinux.CardLink(from, to, "card", kind, null, 1));
    }
}

private void test_project_mode_keeps_the_most_connected_cards_when_over_the_limit() {
    var builder = make_builder();
    var project_cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    var links = new Gee.ArrayList<HolderLinux.CardLink>();
    for (int i = 0; i < 14; i++) {
        project_cards.add(builder_card("a%02d".printf(i), "p1"));
    }
    project_cards.add(builder_card("z1", "p1"));
    project_cards.add(builder_card("z2", "p1"));
    link_many_kinds(links, "z1", "z2");

    var model = builder.build_project_mode(project_cards, links);
    assert(model.nodes.size == HolderLinux.ConnectionsBoardBuilder.PROJECT_MODE_MAX_NODES);
    assert(has_node(model.nodes, "z1"));
    assert(has_node(model.nodes, "z2"));
    assert(has_edge(model.edges, "z1", "z2", "ref"));
    foreach (var edge in model.edges) {
        assert(has_node(model.nodes, edge.from_card_id));
        assert(has_node(model.nodes, edge.to_card_id));
    }
}

private void test_project_mode_drops_edges_touching_trimmed_cards() {
    var builder = make_builder();
    var project_cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    var links = new Gee.ArrayList<HolderLinux.CardLink>();
    var ids = new Gee.ArrayList<string>();
    for (int i = 0; i < 13; i++) {
        var id = "a%02d".printf(i);
        ids.add(id);
        project_cards.add(builder_card(id, "p1"));
    }
    link_many_kinds(links, "a00", "a01");
    var model = builder.build_project_mode(project_cards, links);
    assert(model.nodes.size == 12);

    string missing = "";
    foreach (var id in ids) {
        if (!has_node(model.nodes, id)) {
            missing = id;
        }
    }
    assert(missing != "");
    foreach (var edge in model.edges) {
        assert(edge.from_card_id != missing);
        assert(edge.to_card_id != missing);
    }
    assert(has_edge(model.edges, "a00", "a01", "ref"));
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/connections-board-builder/cards-in-project", test_cards_in_project_filters_by_project);
    Test.add_func("/connections-board-builder/card-mode-alone", test_card_mode_alone_has_only_the_selected_node);
    Test.add_func("/connections-board-builder/card-mode-full", test_card_mode_collects_links_structure_and_internal_links);
    Test.add_func("/connections-board-builder/card-mode-other-project", test_card_mode_ignores_cards_from_other_projects_for_structure);
    Test.add_func("/connections-board-builder/project-mode-structure", test_project_mode_without_links_shows_structure_summary);
    Test.add_func("/connections-board-builder/project-mode-links", test_project_mode_counts_links_and_dedupes);
    Test.add_func("/connections-board-builder/project-mode-empty", test_project_mode_with_no_relationships);
    Test.add_func("/connections-board-builder/project-mode-trims", test_project_mode_keeps_the_most_connected_cards_when_over_the_limit);
    Test.add_func("/connections-board-builder/project-mode-drops-edges", test_project_mode_drops_edges_touching_trimmed_cards);
    return Test.run();
}

}
