using GLib;

namespace HolderLinuxTests {

private HolderLinux.CardSummary rel_card(string id, string title, string? parent = null, double sort_key = 1.0) {
    return new HolderLinux.CardSummary(id, "p1", title, id + ".md", sort_key, parent, 1, 1);
}

private Gee.ArrayList<HolderLinux.CardSummary> rel_cards() {
    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    cards.add(rel_card("a", "Alpha", null, 1.0));
    cards.add(rel_card("b", "Beta", null, 2.0));
    return cards;
}

private HolderLinux.ConnectionsRelationsPresenter make_relations_presenter() {
    return new HolderLinux.ConnectionsRelationsPresenter(new HolderLinux.ConnectionsController());
}

private HolderLinux.CardLink rel_link(string from, string to, string to_type, string kind) {
    return new HolderLinux.CardLink(from, to, to_type, kind, null, 1);
}

private void test_plain_text_strips_tags_and_decodes_entities() {
    assert(HolderLinux.ConnectionsRelationsPresenter.plain_text_from_markup("plain") == "plain");
    assert(HolderLinux.ConnectionsRelationsPresenter.plain_text_from_markup(
        "Project: <a href=\"project:p1\">A &amp; B &lt;x&gt; &quot;q&quot; &apos;s&apos;</a>"
    ) == "Project: A & B <x> \"q\" 's'");
}

private void test_link_lines_are_none_when_empty() {
    var presenter = make_relations_presenter();
    assert(presenter.format_link_lines(new Gee.ArrayList<HolderLinux.CardLink>(), true, rel_cards()) == "None");
}

private void test_outgoing_link_lines_group_by_kind_and_escape_non_card_targets() {
    var presenter = make_relations_presenter();
    var links = new Gee.ArrayList<HolderLinux.CardLink>();
    links.add(rel_link("a", "b", "card", "blocks"));
    links.add(rel_link("a", "a", "card", "blocks"));
    links.add(rel_link("a", "r<1>", "resource", "attachment"));
    var text = presenter.format_link_lines(links, true, rel_cards());
    assert(text == "blocks: <a href=\"card:b\">Beta</a>, <a href=\"card:a\">Alpha</a>\n"
                   + "attachment: r&lt;1&gt;");
}

private void test_backlink_lines_use_source_cards() {
    var presenter = make_relations_presenter();
    var links = new Gee.ArrayList<HolderLinux.CardLink>();
    links.add(rel_link("b", "a", "resource", "ref"));
    var text = presenter.format_link_lines(links, false, rel_cards());
    assert(text == "ref: <a href=\"card:b\">Beta</a>");
}

private void test_internal_lines_resolve_titles_and_escape_unknown_targets() {
    var presenter = make_relations_presenter();
    var none = new Gee.ArrayList<string>();
    assert(presenter.format_internal_lines(none, "p1", rel_cards()) == "None");

    var targets = new Gee.ArrayList<string>();
    targets.add("Beta");
    targets.add("nowhere<1>");
    assert(presenter.format_internal_lines(targets, "p1", rel_cards())
        == "<a href=\"card:b\">Beta</a>\nnowhere&lt;1&gt;");
}

private void test_overview_presentation_hides_link_sections() {
    var presentation = make_relations_presenter().overview("A & B");
    assert(presentation.structure.markup == "A &amp; B");
    assert(presentation.structure.plain == "A & B");
    assert(presentation.outgoing.markup == "None");
    assert(presentation.backlinks.plain == "None");
    assert(presentation.internal_links.markup == "None");
    assert(!presentation.sections_visible);
}

private void test_card_presentation_combines_all_sections() {
    var presenter = make_relations_presenter();
    var project = new HolderLinux.Project("p1", "Project 1", "encrypted_git", "/tmp/p1", 1, 1);
    var cards = rel_cards();
    var outgoing = new Gee.ArrayList<HolderLinux.CardLink>();
    outgoing.add(rel_link("a", "b", "card", "ref"));
    var backlinks = new Gee.ArrayList<HolderLinux.CardLink>();
    var internal = new Gee.ArrayList<string>();
    internal.add("Beta");

    var presentation = presenter.for_card(project, cards[0], outgoing, backlinks, internal, cards);

    assert(presentation.sections_visible);
    assert(presentation.structure.markup.contains("<a href=\"project:p1\">Project 1</a>"));
    assert(presentation.structure.plain.has_prefix("Project: Project 1"));
    assert(presentation.outgoing.plain == "ref: Beta");
    assert(presentation.backlinks.markup == "None");
    assert(presentation.internal_links.plain == "Beta");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/connections-relations/plain-text", test_plain_text_strips_tags_and_decodes_entities);
    Test.add_func("/holder/connections-relations/link-lines-empty", test_link_lines_are_none_when_empty);
    Test.add_func("/holder/connections-relations/outgoing-lines",
                  test_outgoing_link_lines_group_by_kind_and_escape_non_card_targets);
    Test.add_func("/holder/connections-relations/backlink-lines", test_backlink_lines_use_source_cards);
    Test.add_func("/holder/connections-relations/internal-lines",
                  test_internal_lines_resolve_titles_and_escape_unknown_targets);
    Test.add_func("/holder/connections-relations/overview", test_overview_presentation_hides_link_sections);
    Test.add_func("/holder/connections-relations/card", test_card_presentation_combines_all_sections);
    return Test.run();
}

}
