namespace HolderLinux {

public interface IToolShellAdapter : Object {
    public abstract string tool_id { owned get; }
    public abstract string tool_label { owned get; }
    public abstract Gtk.Widget get_content_widget();
    public abstract Gtk.Widget? get_actions_widget();
    public abstract ToolScopeSnapshot get_scope_snapshot(Project? selected_project,
                                                         CardSummary? selected_card);

    public abstract async bool navigate_to_projects_root(string? selected_project_id);
    public abstract async bool navigate_to_project_root(string project_id);
    public abstract async bool navigate_to_card(string card_id);
}

}
