namespace HolderLinux {

public class AiCatalogController : Object {
    public string title_for_provider(AiCatalogProvider provider) {
        return "%s (%s)".printf(provider.display_name, provider.id);
    }

    public string status_for_provider(AiCatalogProvider provider) {
        return "enabled=%s configured=%s".printf(
            provider.enabled ? "yes" : "no",
            provider.configured ? "yes" : "no"
        );
    }

    public bool has_urls(AiCatalogProvider provider) {
        return provider.setup_url.length > 0 || provider.docs_url.length > 0;
    }

    public string urls_for_provider(AiCatalogProvider provider) {
        return "setup: %s\ndocs: %s".printf(provider.setup_url, provider.docs_url);
    }
}

}
