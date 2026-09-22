namespace HolderLinux {

public class GitTransportOptions : Object {
    public Gee.ArrayList<string> options { get; construct; }
    public uint selected_index { get; construct; }

    public GitTransportOptions(Gee.ArrayList<string> options, uint selected_index) {
        Object(options: options, selected_index: selected_index);
    }
}

public class GitProviderOptions : Object { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public static GitTransportOptions transport_options(GitProviderCatalogEntry? provider) {
        var normalized = new Gee.ArrayList<string>();
        if (provider != null && provider.transports_summary.strip().length > 0) {
            foreach (var raw in provider.transports_summary.split(",")) {
                var item = raw.strip();
                if (item.length > 0) {
                    normalized.add(item);
                }
            }
        }
        if (normalized.size == 0) {
            normalized.add("ssh");
            normalized.add("https");
        }

        uint selected_index = 0;
        if (provider != null && provider.preferred_transport.strip().length > 0) {
            for (int i = 0; i < normalized.size; i++) {
                if (normalized[i] == provider.preferred_transport) {
                    selected_index = (uint) i;
                    break;
                }
            }
        }
        return new GitTransportOptions(normalized, selected_index);
    }

    public static string provider_label(GitProviderCatalogEntry provider) {
        return "%s (%s)".printf(provider.name, provider.id);
    }

    public static GitProviderCatalogEntry? entry_at(Gee.ArrayList<GitProviderCatalogEntry> entries,
                                                    uint selected) {
        if (selected >= (uint) entries.size) {
            return null;
        }
        return entries[(int) selected];
    }

    public static string resolve_transport(Gee.ArrayList<string> options, uint selected) {
        if (options.size == 0) {
            return "ssh";
        }
        var index = selected >= (uint) options.size ? 0 : (int) selected;
        return options[index];
    }
}

}
