namespace HolderLinux {

internal class ProjectsController : Object {
    private MainController owner;

    public ProjectsController(MainController owner) {
        this.owner = owner;
    }

    public async void create_project_named(string name, string privacy_mode = "encrypted_git") {
        if (owner.api == null) {
            return;
        }

        owner.status_changed("Creating project...");
        try {
            var project_id = yield owner.api.create_project(name, privacy_mode);
            owner.toast_requested("Created project: %s".printf(name));
            owner.status_changed("Project created");
            yield owner.reload_everything_with_selection(project_id, null);
        } catch (Error e) {
            owner.error_reported("Failed to create project", e.message);
        }
    }

    public async void ensure_first_project() {
        if (owner.api == null) {
            return;
        }

        try {
            var projects = yield owner.api.list_projects();
            if (projects.size == 0) {
                var project_id = yield owner.api.create_project("My Project");
                owner.toast_requested("Created first project (%s)".printf(project_id));
            }
        } catch (Error e) {
            owner.error_reported("Project bootstrap failed", e.message);
        }
    }
}

}
