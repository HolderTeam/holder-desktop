using GLib;

namespace HolderLinuxTests {

private string? at(HolderLinux.MarkdownLinkController controller,
                   string text,
                   string needle,
                   int within = 1) {
    return controller.uri_at_byte_offset(text, text.index_of(needle) + within);
}

private void test_markdown_link_opens_from_label_or_destination() {
    var controller = new HolderLinux.MarkdownLinkController();
    var text = "Read [the documentation](https://holder.team/docs) today";

    assert(at(controller, text, "documentation") == "https://holder.team/docs");
    assert(at(controller, text, "holder.team") == "https://holder.team/docs");
}

private void test_autolinks_and_bare_urls() {
    var controller = new HolderLinux.MarkdownLinkController();

    var angle = "Visit <https://holder.team/help> now";
    assert(at(controller, angle, "holder.team") == "https://holder.team/help");

    var email = "Write to <releases@holder.team>.";
    assert(at(controller, email, "releases") == "mailto:releases@holder.team");

    var bare = "Visit https://holder.team/help, then return.";
    assert(at(controller, bare, "holder.team") == "https://holder.team/help");
}

private void test_bare_url_trims_sentence_punctuation_but_keeps_balanced_parentheses() {
    var controller = new HolderLinux.MarkdownLinkController();
    var text = "See https://example.com/a_(b)).";

    assert(at(controller, text, "example.com") == "https://example.com/a_(b)");
}

private void test_rejects_unsafe_schemes_and_code() {
    var controller = new HolderLinux.MarkdownLinkController();

    var unsafe = "[do not](javascript:alert(1))";
    assert(at(controller, unsafe, "do not") == null);

    var inline = "`https://example.com/inline`";
    assert(at(controller, inline, "example.com") == null);

    var fenced = "```\nhttps://example.com/fenced\n```\nhttps://example.com/live";
    assert(at(controller, fenced, "fenced") == null);
    assert(at(controller, fenced, "live") == "https://example.com/live");

    var indented = "    https://example.com/code";
    assert(at(controller, indented, "example.com") == null);
}

private void test_uses_utf8_byte_offsets() {
    var controller = new HolderLinux.MarkdownLinkController();
    var text = "Café — https://holder.team";

    assert(at(controller, text, "holder.team") == "https://holder.team");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/markdown-links/markdown", test_markdown_link_opens_from_label_or_destination);
    Test.add_func("/holder/markdown-links/autolinks-and-bare", test_autolinks_and_bare_urls);
    Test.add_func("/holder/markdown-links/punctuation", test_bare_url_trims_sentence_punctuation_but_keeps_balanced_parentheses);
    Test.add_func("/holder/markdown-links/rejects-unsafe-and-code", test_rejects_unsafe_schemes_and_code);
    Test.add_func("/holder/markdown-links/utf8-byte-offset", test_uses_utf8_byte_offsets);
    return Test.run();
}

}
