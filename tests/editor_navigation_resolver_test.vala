using GLib;

namespace HolderLinuxTests {

private class NavigationFixture : Object {
    public HolderLinux.InternalLinkController internal_links = new HolderLinux.InternalLinkController();
    public HolderLinux.TagNavigationController tags = new HolderLinux.TagNavigationController();
    public HolderLinux.MarkdownLinkController links = new HolderLinux.MarkdownLinkController();
    public HolderLinux.MarkdownResourceImageController images = new HolderLinux.MarkdownResourceImageController();
    public HolderLinux.EditorNavigationResolver resolver;
    public int resolutions { get; set; default = 0; }

    public NavigationFixture() {
        resolver = new HolderLinux.EditorNavigationResolver(internal_links, tags, links, images);
    }
}

private Gee.ArrayList<HolderLinux.CardSummary> make_cards() {
    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    cards.add(new HolderLinux.CardSummary("c1", "p1", "Alpha", "c1.md", 1.0, null, 1, 1));
    cards.add(new HolderLinux.CardSummary("c2", "p1", "Beta", "c2.md", 2.0, null, 1, 1));
    cards.add(new HolderLinux.CardSummary("c3", "p2", "Gamma", "c3.md", 3.0, null, 1, 1));
    return cards;
}

private HolderLinux.CardTagOccurrence[] tag_occurrences_for(string text, string tag) {
    var index = text.index_of(tag);
    assert(index >= 0);
    return { new HolderLinux.CardTagOccurrence(tag.substring(1), index, index + tag.length) };
}

private string describe(HolderLinux.EditorNavigationKind kind, string? payload, string? toast) {
    return "%d|%s|%s".printf((int) kind, payload ?? "(null)", toast ?? "(null)");
}

// The decision chain exactly as WindowInternalLinkNavigator ran it before it was hoisted:
// internal link decision, then resource image, tag, external link. Line text/offset are derived
// for '\n'-separated ASCII documents, which is what the GTK iterators produced there.
private string reference_navigate(NavigationFixture f,
                                  string text,
                                  int offset,
                                  Gee.List<HolderLinux.CardSummary> cards,
                                  bool has_unsaved,
                                  HolderLinux.CardTagOccurrence[]? occurrences) {
    int line_start = offset;
    while (line_start > 0 && text[line_start - 1] != '\n') {
        line_start--;
    }
    int line_end = offset;
    while (line_end < text.length && text[line_end] != '\n') {
        line_end++;
    }
    var line_text = text.substring(line_start, line_end - line_start);
    string? target = null;
    if (line_text.length > 0) {
        target = f.internal_links.extract_target_from_line(line_text, offset - line_start);
    }
    var decision = f.internal_links.decide_navigation(target, cards);
    if (!decision.handled) {
        var resource_id = f.images.resource_id_at_byte_offset(text, offset);
        if (resource_id != null) {
            return describe(HolderLinux.EditorNavigationKind.RESOURCE_PREVIEW, resource_id, null);
        }
        if (!has_unsaved && occurrences != null) {
            var tag = f.tags.tag_at_byte_offset(text, offset, occurrences);
            if (tag != null) {
                return describe(HolderLinux.EditorNavigationKind.SHOW_TAG, tag, null);
            }
        }
        var uri = f.links.uri_at_byte_offset(text, offset);
        if (uri != null) {
            return describe(HolderLinux.EditorNavigationKind.OPEN_URI, uri, null);
        }
        return describe(HolderLinux.EditorNavigationKind.NONE, null, null);
    }
    if (decision.open_card_id == null) {
        return describe(
            HolderLinux.EditorNavigationKind.CREATE_PROMPT,
            decision.create_target,
            decision.toast_message
        );
    }
    return describe(HolderLinux.EditorNavigationKind.OPEN_CARD, decision.open_card_id, null);
}

private HolderLinux.EditorNavigationResult resolve_at(NavigationFixture f,
                                                       string text,
                                                       int offset,
                                                       bool has_unsaved = false,
                                                       HolderLinux.CardTagOccurrence[]? occurrences = null) {
    int line_start = offset;
    while (line_start > 0 && text[line_start - 1] != '\n') {
        line_start--;
    }
    int line_end = offset;
    while (line_end < text.length && text[line_end] != '\n') {
        line_end++;
    }
    f.resolutions++;
    return f.resolver.resolve(
        text,
        offset,
        text.substring(line_start, line_end - line_start),
        offset - line_start,
        HolderLinux.EditorNavigationResolver.cards_for_project("p1", make_cards()),
        has_unsaved,
        occurrences
    );
}

private const string SAMPLE_DOC =
    "See [[Alpha]] and [[Missing]] here\n" +
    "![Pic](holder://resource/r1)\n" +
    "#todo <https://example.com/x>\n" +
    "plain line\n" +
    "\n" +
    "[docs](https://holder.team) [[Beta]] [#todo](https://tag.link)\n" +
    "![#todo](holder://resource/r2)";

private void test_matches_the_original_decision_chain_at_every_offset() {
    var f = new NavigationFixture();
    var cards = HolderLinux.EditorNavigationResolver.cards_for_project("p1", make_cards());
    var all_tags = new Gee.ArrayList<HolderLinux.CardTagOccurrence>();
    int from = 0;
    while (true) {
        var index = SAMPLE_DOC.index_of("#todo", from);
        if (index < 0) {
            break;
        }
        all_tags.add(new HolderLinux.CardTagOccurrence("todo", index, index + 5));
        from = index + 5;
    }
    HolderLinux.CardTagOccurrence[] empty_set = {};
    HolderLinux.CardTagOccurrence[] real_set = {};
    foreach (var occurrence in all_tags) {
        real_set += occurrence;
    }

    int compared = 0;
    for (int offset = 0; offset <= SAMPLE_DOC.length; offset++) {
        // 0: no current card, 1: current card without tags, 2: current card with tags.
        for (int mode = 0; mode < 3; mode++) {
            HolderLinux.CardTagOccurrence[]? occurrences = null;
            if (mode == 1) {
                occurrences = empty_set;
            } else if (mode == 2) {
                occurrences = real_set;
            }
            foreach (var unsaved in new bool[] { false, true }) {
                var expected = reference_navigate(f, SAMPLE_DOC, offset, cards, unsaved, occurrences);
                var actual = resolve_at(f, SAMPLE_DOC, offset, unsaved, occurrences);
                assert(describe(actual.kind, actual.payload, actual.toast_message) == expected);
                compared++;
            }
        }
    }
    assert(compared == (SAMPLE_DOC.length + 1) * 6);
}

private void test_every_navigation_kind_is_reachable() {
    var f = new NavigationFixture();
    var tags = tag_occurrences_for(SAMPLE_DOC, "#todo");
    assert(f.internal_links.extract_internal_links(SAMPLE_DOC).size == 3);

    var open = resolve_at(f, SAMPLE_DOC, SAMPLE_DOC.index_of("Alpha") + 1);
    assert(open.kind == HolderLinux.EditorNavigationKind.OPEN_CARD);
    assert(open.payload == "c1");

    var create = resolve_at(f, SAMPLE_DOC, SAMPLE_DOC.index_of("Missing") + 1);
    assert(create.kind == HolderLinux.EditorNavigationKind.CREATE_PROMPT);
    assert(create.payload == "Missing");

    var preview = resolve_at(f, SAMPLE_DOC, SAMPLE_DOC.index_of("holder://resource/r1") + 2);
    assert(preview.kind == HolderLinux.EditorNavigationKind.RESOURCE_PREVIEW);
    assert(preview.payload == "r1");

    var tag = resolve_at(f, SAMPLE_DOC, SAMPLE_DOC.index_of("#todo") + 1, false, tags);
    assert(tag.kind == HolderLinux.EditorNavigationKind.SHOW_TAG);
    assert(tag.payload == "todo");

    var uri = resolve_at(f, SAMPLE_DOC, SAMPLE_DOC.index_of("https://example.com/x") + 3);
    assert(uri.kind == HolderLinux.EditorNavigationKind.OPEN_URI);
    assert(uri.payload == "https://example.com/x");

    var nothing = resolve_at(f, SAMPLE_DOC, SAMPLE_DOC.index_of("plain") + 1);
    assert(nothing.kind == HolderLinux.EditorNavigationKind.NONE);
    assert(nothing.payload == null);

    var blank_line = resolve_at(f, SAMPLE_DOC, SAMPLE_DOC.index_of("plain line\n\n") + 11);
    assert(blank_line.kind == HolderLinux.EditorNavigationKind.NONE);
}

private void test_tags_only_navigate_for_a_saved_card_with_a_current_card() {
    var f = new NavigationFixture();
    var doc = "#todo and text";
    var occurrences = tag_occurrences_for(doc, "#todo");

    assert(resolve_at(f, doc, 1, false, occurrences).kind == HolderLinux.EditorNavigationKind.SHOW_TAG);
    assert(resolve_at(f, doc, 1, true, occurrences).kind == HolderLinux.EditorNavigationKind.NONE);
    assert(resolve_at(f, doc, 1, false, null).kind == HolderLinux.EditorNavigationKind.NONE);
}

private void test_precedence_internal_link_then_image_then_tag_then_uri() {
    var f = new NavigationFixture();

    var image_over_tag = "![#todo](holder://resource/r2)";
    var image_hit = resolve_at(f, image_over_tag, 3, false, tag_occurrences_for(image_over_tag, "#todo"));
    assert(image_hit.kind == HolderLinux.EditorNavigationKind.RESOURCE_PREVIEW);

    var tag_over_uri = "[#todo](https://tag.link)";
    var tag_occurrences = tag_occurrences_for(tag_over_uri, "#todo");
    var tag_hit = resolve_at(f, tag_over_uri, 3, false, tag_occurrences);
    assert(tag_hit.kind == HolderLinux.EditorNavigationKind.SHOW_TAG);
    var uri_when_unsaved = resolve_at(f, tag_over_uri, 3, true, tag_occurrences);
    assert(uri_when_unsaved.kind == HolderLinux.EditorNavigationKind.OPEN_URI);
    assert(uri_when_unsaved.payload == "https://tag.link");

    var link_over_uri = "[[Alpha]](https://x.example)";
    var link_hit = resolve_at(f, link_over_uri, 3);
    assert(link_hit.kind == HolderLinux.EditorNavigationKind.OPEN_CARD);
    assert(link_hit.payload == "c1");
}

private void test_cards_for_project_filters_and_preserves_order() {
    var cards = make_cards();
    var p1 = HolderLinux.EditorNavigationResolver.cards_for_project("p1", cards);
    assert(p1.size == 2);
    assert(p1[0].card_id == "c1");
    assert(p1[1].card_id == "c2");
    assert(HolderLinux.EditorNavigationResolver.cards_for_project("p2", cards).size == 1);
    assert(HolderLinux.EditorNavigationResolver.cards_for_project("nope", cards).size == 0);
    assert(HolderLinux.EditorNavigationResolver.cards_for_project(null, cards).size == 0);
}

private void test_click_key_and_failure_message_predicates() {
    assert(HolderLinux.EditorNavigationResolver.is_navigation_click(1, true));
    assert(!HolderLinux.EditorNavigationResolver.is_navigation_click(2, true));
    assert(!HolderLinux.EditorNavigationResolver.is_navigation_click(0, true));
    assert(!HolderLinux.EditorNavigationResolver.is_navigation_click(1, false));

    assert(HolderLinux.EditorNavigationResolver.is_navigation_key(Gdk.Key.Return, true));
    assert(HolderLinux.EditorNavigationResolver.is_navigation_key(Gdk.Key.KP_Enter, true));
    assert(!HolderLinux.EditorNavigationResolver.is_navigation_key(Gdk.Key.Return, false));
    assert(!HolderLinux.EditorNavigationResolver.is_navigation_key(Gdk.Key.Escape, true));
    assert(HolderLinux.EditorNavigationResolver.KEYVAL_RETURN == Gdk.Key.Return);
    assert(HolderLinux.EditorNavigationResolver.KEYVAL_KP_ENTER == Gdk.Key.KP_Enter);

    assert(HolderLinux.EditorNavigationResolver.launch_failure_message("no handler") ==
           "Could not open link: no handler");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/editor-navigation/matches-original-chain-at-every-offset",
                  test_matches_the_original_decision_chain_at_every_offset);
    Test.add_func("/holder/editor-navigation/every-kind-reachable",
                  test_every_navigation_kind_is_reachable);
    Test.add_func("/holder/editor-navigation/tags-need-saved-card-and-current-card",
                  test_tags_only_navigate_for_a_saved_card_with_a_current_card);
    Test.add_func("/holder/editor-navigation/precedence",
                  test_precedence_internal_link_then_image_then_tag_then_uri);
    Test.add_func("/holder/editor-navigation/cards-for-project",
                  test_cards_for_project_filters_and_preserves_order);
    Test.add_func("/holder/editor-navigation/predicates",
                  test_click_key_and_failure_message_predicates);
    return Test.run();
}

}
