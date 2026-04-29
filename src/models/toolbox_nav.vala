namespace HolderLinux {

public enum ToolScopeMode {
    PROJECTS_ROOT,
    PROJECT_ROOT,
    CARD_FOCUS
}

public class ToolScopeSnapshot : Object {
    public string tool_id { get; construct; }
    public string tool_label { get; construct; }
    public string? project_id { get; construct; }
    public string project_label { get; construct; }
    public string? card_id { get; construct; }
    public string card_label { get; construct; }
    public ToolScopeMode scope_mode { get; construct; }
    public bool is_loading { get; construct; }

    public ToolScopeSnapshot(string tool_id,
                             string tool_label,
                             string? project_id,
                             string project_label,
                             string? card_id,
                             string card_label,
                             ToolScopeMode scope_mode = ToolScopeMode.CARD_FOCUS,
                             bool is_loading = false) {
        Object(
            tool_id: tool_id,
            tool_label: tool_label,
            project_id: project_id,
            project_label: project_label,
            card_id: card_id,
            card_label: card_label,
            scope_mode: scope_mode,
            is_loading: is_loading
        );
    }
}

public class NavigationBreadcrumbSegment : Object {
    public string label { get; construct; }
    public bool emphasized { get; construct; }
    public bool clickable { get; construct; }
    public int index { get; construct; }

    public NavigationBreadcrumbSegment(string label,
                                       bool emphasized,
                                       bool clickable,
                                       int index) {
        Object(
            label: label,
            emphasized: emphasized,
            clickable: clickable,
            index: index
        );
    }
}

}
