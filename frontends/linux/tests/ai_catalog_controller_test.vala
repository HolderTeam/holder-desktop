namespace HolderLinux.Tests {

private AiCatalogProvider sample_provider() {
    return new AiCatalogProvider(
        "openai",
        "OpenAI",
        true,
        false,
        "https://example.com/setup",
        "https://example.com/docs"
    );
}

private void test_title_and_status() {
    var controller = new AiCatalogController();
    var provider = sample_provider();

    assert(controller.title_for_provider(provider) == "OpenAI (openai)");
    assert(controller.status_for_provider(provider) == "enabled=yes configured=no");
}

private void test_urls_presence() {
    var controller = new AiCatalogController();
    var provider = sample_provider();
    assert(controller.has_urls(provider));
    assert(controller.urls_for_provider(provider).contains("setup:"));
    assert(controller.urls_for_provider(provider).contains("docs:"));

    var no_urls = new AiCatalogProvider("x", "X", false, false, "", "");
    assert(!controller.has_urls(no_urls));
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/ai-catalog/title-and-status", test_title_and_status);
    Test.add_func("/holder/ai-catalog/urls-presence", test_urls_presence);
    return Test.run();
}

}
