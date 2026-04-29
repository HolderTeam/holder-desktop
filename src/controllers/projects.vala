namespace HolderLinux {

internal class ProjectsController : Object {
    private MainController owner; // LCOV_EXCL_LINE: field declaration-only coverage artifact

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
            string? starter_card_id = null;
            try {
                var starter_title = "Untitled in %s".printf(name);
                starter_card_id = yield owner.api.create_card(
                    project_id,
                    starter_title,
                    "# %s\n\n".printf(starter_title),
                    null
                );
                owner.emit_activity(
                    "result.card.create",
                    "Created card: %s".printf(starter_title),
                    project_id,
                    starter_card_id,
                    new CardCreatedDetails(starter_title, null)
                );
            } catch (Error e) {
                owner.emit_activity(
                    "result.card.create_failed",
                    "Failed to create starter card: %s".printf(e.message),
                    project_id,
                    null
                );
                owner.error_reported("Failed to create starter card", e.message);
            }
            owner.emit_activity(
                "result.project.create",
                "Created project: %s".printf(name),
                project_id,
                null
            );
            owner.toast_requested("Created project: %s".printf(name));
            owner.status_changed(starter_card_id != null ? "Project ready" : "Project created");
            yield owner.reload_everything_with_selection(project_id, starter_card_id);
        } catch (Error e) {
            owner.emit_activity(
                "result.project.create_failed",
                "Failed to create project: %s".printf(e.message),
                null,
                null
            );
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
                owner.emit_activity(
                    "result.project.bootstrap",
                    "Created first project: My Project",
                    project_id,
                    null
                );
                owner.toast_requested("Created first project (%s)".printf(project_id));
            }
        } catch (Error e) {
            owner.error_reported("Project bootstrap failed", e.message);
        }
    }
}

}
