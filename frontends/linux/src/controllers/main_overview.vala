namespace HolderLinux {

internal class MainOverviewController : Object {
    private MainController owner;
    private uint project_overview_request_serial = 0;

    public MainOverviewController(MainController owner) {
        this.owner = owner;
    }

    public async void show_project_overview() {
        project_overview_request_serial++;
        var request_serial = project_overview_request_serial;
        var selected = owner.project_selection.get_selected_item() as Project;
        if (selected == null) {
            owner.current_project = null;
            owner.current_card = null;
            owner.set_editor_view_state("# No Project Selected\n\nSelect a project to view its overview.", false);
            return;
        }
        var selected_project_id = selected.project_id;

        owner.current_project = selected;
        owner.current_card = null;

        int card_count = (int) owner.card_store.get_n_items();
        int thread_count = (int) owner.ai_thread_store.get_n_items();
        string resources_text = "unknown";
        if (owner.api != null) {
            try {
                var resources = yield owner.api.list_resources(selected.project_id);
                if (request_serial != project_overview_request_serial) {
                    return;
                }
                resources_text = resources.size.to_string();
            } catch (Error e) {
                if (request_serial != project_overview_request_serial) {
                    return;
                }
                resources_text = "unknown";
            }
        }

        if (request_serial != project_overview_request_serial) {
            return;
        }
        var latest_selected = owner.project_selection.get_selected_item() as Project;
        if (latest_selected == null || latest_selected.project_id != selected_project_id) {
            return;
        }

        owner.set_editor_view_state(build_project_overview_text(selected, card_count, resources_text, thread_count), false);
        owner.show_editor_requested();
        owner.window_title_changed(selected.name);
        owner.status_changed("Loaded project overview");
    }

    private string build_project_overview_text(Project project,
                                               int card_count,
                                               string resource_count_text,
                                               int thread_count) {
        var sb = new StringBuilder();
        sb.append("# %s\n\n".printf(project.name));
        sb.append("## Overview\n");
        sb.append("- Cards: %d\n".printf(card_count));
        sb.append("- Resources: %s\n".printf(resource_count_text));
        sb.append("- AI Threads: %d\n\n".printf(thread_count));
        sb.append("## Sync\n");
        sb.append("- Visibility: %s\n\n".printf(project_visibility_label(project)));
        sb.append("## Metadata\n");
        sb.append("- Project ID: `%s`\n".printf(project.project_id));
        sb.append("- Root Path: `%s`\n".printf(project.root_path));
        sb.append("- Created: %s\n".printf(format_timestamp(project.created_at)));
        sb.append("- Updated: %s\n".printf(format_timestamp(project.updated_at)));
        return sb.str;
    }

    private string project_visibility_label(Project project) {
        return project.privacy_mode == "plain" ? "Shared" : "Private";
    }

    private string format_timestamp(int64 epoch) {
        if (epoch <= 0) {
            return "unknown";
        }
        var dt = new DateTime.from_unix_local(epoch);
        return dt.format("%Y-%m-%d %H:%M");
    }
}

}
