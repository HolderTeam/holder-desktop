namespace HolderLinux {

internal class ToolHelpContent : Object {
    public string title { get; construct; }
    public string markdown { get; construct; }
    public string status_text { get; construct; }

    public ToolHelpContent(string title, string markdown, string status_text) {
        Object(
            title: title,
            markdown: markdown,
            status_text: status_text
        );
    }
}

internal class ToolHelpController : Object {
    public ToolHelpContent load(string tool_id) {
        var title = title_for_tool(tool_id);
        string markdown;
        string resource_path = "/io/holder/linux/help/toolbox/%s.md".printf(tool_id);
        try {
            var bytes = resources_lookup_data(resource_path, ResourceLookupFlags.NONE);
            markdown = (string) bytes.get_data();
        } catch (Error e) {
            markdown = "# %s\n\nHelp page resource missing: %s".printf(title, e.message);
        }
        return new ToolHelpContent(
            title,
            markdown,
            "Loaded %s help.".printf(title)
        );
    }

    private static string title_for_tool(string tool_id) {
        switch (tool_id) {
        case "flowboard":
            return "Flowboard";
        case "connections":
            return "Connections";
        case "resources":
            return "Resources";
        case "sharing":
            return "Sharing";
        case "terminals":
            return "Terminals";
        case "git":
            return "Git Sync";
        case "recovery":
            return "Recovery Key";
        case "trash":
            return "Trash";
        case "debug":
            return "Debug";
        default:
            var readable = tool_id.replace("-", " ").replace("_", " ");
            if (readable.strip().length == 0) {
                return "Tool Help";
            }
            return readable.substring(0, 1).up() + readable.substring(1);
        }
    }
}

}
