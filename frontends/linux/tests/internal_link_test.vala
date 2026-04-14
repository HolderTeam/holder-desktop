using GLib;

namespace HolderLinux {

internal class CardSummary : Object {
    public string card_id { get; construct; }
    public string title { get; construct; }

    public CardSummary(string card_id, string title) {
        Object(card_id: card_id, title: title);
    }
}

}

namespace HolderLinux.Tests {

private Gee.ArrayList<HolderLinux.CardSummary> sample_cards() {
    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    cards.add(new HolderLinux.CardSummary("card-1", "Alpha"));
    cards.add(new HolderLinux.CardSummary("card-2", "Beta"));
    cards.add(new HolderLinux.CardSummary("card-3", "gamma"));
    return cards;
}

private void test_extract_internal_links_deduplicates_and_skips_empty_targets() {
    var controller = new HolderLinux.InternalLinkController();

    var result = controller.extract_internal_links("[[Alpha]] [[ Alpha ]] [[Beta]] [[]] [[Gamma]]");

    assert(result.size == 3);
    assert(result[0] == "Alpha");
    assert(result[1] == "Beta");
    assert(result[2] == "Gamma");
}

private void test_extract_target_from_line_requires_cursor_inside_complete_link() {
    var controller = new HolderLinux.InternalLinkController();
    var line = "Before [[Alpha Link]] after";

    assert(controller.extract_target_from_line("", 0) == null);
    assert(controller.extract_target_from_line(line, -1) == null);
    assert(controller.extract_target_from_line(line, 0) == null);
    assert(controller.extract_target_from_line(line, 10) == "Alpha Link");
    assert(controller.extract_target_from_line(line, 100) == null);
    assert(controller.extract_target_from_line("Before [[Unclosed", 12) == null);
}

private void test_resolve_target_card_id_matches_id_exact_title_and_case_insensitive_title() {
    var controller = new HolderLinux.InternalLinkController();
    var cards = sample_cards();

    assert(controller.resolve_target_card_id("card-2", cards) == "card-2");
    assert(controller.resolve_target_card_id("Alpha", cards) == "card-1");
    assert(controller.resolve_target_card_id("Gamma", cards) == "card-3");
    assert(controller.resolve_target_card_id("missing", cards) == null);
}

private void test_decide_navigation_opens_existing_or_requests_creation() {
    var controller = new HolderLinux.InternalLinkController();
    var cards = sample_cards();

    var no_target = controller.decide_navigation(null, cards);
    assert(!no_target.handled);

    var existing = controller.decide_navigation("Alpha", cards);
    assert(existing.handled);
    assert(existing.open_card_id == "card-1");
    assert(existing.create_target == null);
    assert(existing.toast_message == null);

    var missing = controller.decide_navigation("Missing", cards);
    assert(missing.handled);
    assert(missing.open_card_id == null);
    assert(missing.create_target == "Missing");
    assert(missing.toast_message == "No card matches [[Missing]].");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/internal-link/extract-internal-links", test_extract_internal_links_deduplicates_and_skips_empty_targets);
    Test.add_func("/holder/internal-link/extract-target-from-line", test_extract_target_from_line_requires_cursor_inside_complete_link);
    Test.add_func("/holder/internal-link/resolve-target-card-id", test_resolve_target_card_id_matches_id_exact_title_and_case_insensitive_title);
    Test.add_func("/holder/internal-link/decide-navigation", test_decide_navigation_opens_existing_or_requests_creation);
    return Test.run();
}

}
