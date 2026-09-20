namespace HolderLinux {

internal class GitSyncPagePresentation : Object {
    public bool show_setup { get; construct; }
    public bool cancel_visible { get; construct; }

    public GitSyncPagePresentation(bool show_setup, bool cancel_visible) {
        Object(show_setup: show_setup, cancel_visible: cancel_visible);
    }
}

internal class GitSyncProjectState : Object {
    public bool editing_remote = false;
    public string locally_disconnected_project_id = "";
    public Project? configured_project { get; private set; default = null; }
    private uint refresh_generation = 0;

    public uint begin_refresh() {
        return ++refresh_generation;
    }

    public bool is_current(uint generation) {
        return generation == refresh_generation;
    }

    public Project? resolve_refreshed_project(Gee.ArrayList<Project> projects, string project_id) {
        foreach (var project in projects) {
            if (project.project_id != project_id) {
                continue;
            }
            if (locally_disconnected_project_id == project.project_id &&
                (project.git_remote_url == null || project.git_remote_url.strip().length == 0)) {
                locally_disconnected_project_id = "";
            }
            return project;
        }
        return null;
    }

    public GitSyncPagePresentation select_page(Project? project) {
        var remote_url = project != null && project.git_remote_url != null &&
                         project.project_id != locally_disconnected_project_id
            ? project.git_remote_url.strip()
            : "";
        if (editing_remote || project == null || remote_url.length == 0) {
            return new GitSyncPagePresentation(true, editing_remote && configured_project != null);
        }
        configured_project = project;
        return new GitSyncPagePresentation(false, false);
    }

    public void mark_connected() {
        locally_disconnected_project_id = "";
        editing_remote = false;
    }

    public void mark_disconnected(string project_id) {
        refresh_generation++;
        locally_disconnected_project_id = project_id;
        configured_project = null;
        editing_remote = false;
    }

    public static Project project_snapshot_with_remote(Project source, string? remote_url) {
        return new Project(
            source.project_id,
            source.name,
            source.privacy_mode,
            source.root_path,
            source.created_at,
            source.updated_at,
            remote_url,
            source.sync,
            source.card_count,
            source.root_card_count
        );
    }
}

}
