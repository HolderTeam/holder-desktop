namespace HolderLinux {

public interface ILocalInfoLogger : Object {
    public abstract void log_debug(string message);
}

public class LocalInfoController : Object {
    private ILocalInfoLogger? logger;

    public LocalInfoController(ILocalInfoLogger? logger = null) {
        this.logger = logger;
    }

    public async string build_local_info_markdown(IHolderApi api) throws Error {
        var health = yield api.get_health_info();
        var uptime_seconds = health.uptime_ms / 1000;
        var projects = yield api.list_projects();
        var ordered_projects = order_projects_home_first(projects);
        string local_models_section = "- Installed models: `none`\n";

        try {
            var capabilities = yield api.get_ai_capabilities();
            local_models_section = "- Installed models: `%s`\n".printf(join_list(capabilities.models));
        } catch (Error e) {
            local_models_section = "- Installed models: `unavailable`\n";
            if (logger != null) {
                logger.log_debug("Local info: failed to load AI capabilities: %s".printf(e.message));
            }
        }

        int total_card_count = 0;
        int total_thread_count = 0;
        var sync_section = new StringBuilder();
        foreach (var project in ordered_projects) {
            try {
                var cards = yield api.list_cards(project.project_id, "recent");
                total_card_count += cards.size;
            } catch (Error e) {
                if (logger != null) {
                    logger.log_debug(
                        "Local info: failed to count cards for project %s: %s".printf(
                            project.project_id,
                            e.message
                        )
                    );
                }
            }

            try {
                var threads = yield api.list_ai_threads(project.project_id);
                total_thread_count += threads.size;
            } catch (Error e) {
                if (logger != null) {
                    logger.log_debug(
                        "Local info: failed to count threads for project %s: %s".printf(
                            project.project_id,
                            e.message
                        )
                    );
                }
            }

            if (project.git_remote_url != null && project.git_remote_url.strip().length > 0) {
                var push_time = format_sync_time(
                    project.sync.has_last_push_at,
                    project.sync.last_push_at
                );
                var pull_time = format_sync_time(
                    project.sync.has_last_pull_at,
                    project.sync.last_pull_at
                );
                var push_status = project.sync.last_push_status.strip().length > 0
                    ? project.sync.last_push_status
                    : "unknown";
                var next_push_retry = format_sync_time(
                    project.sync.has_next_retry_at,
                    project.sync.next_retry_at
                );
                var next_pull_retry = format_sync_time(
                    project.sync.has_next_pull_retry_at,
                    project.sync.next_pull_retry_at
                );
                sync_section.append(
                    "- %s: push `%s` (%s), pull `%s`, uncommitted `%d`, unpushed `%d`, push_retry `%d` (next `%s`), pull_retry `%d` (next `%s`)\n".printf(
                        project.name,
                        push_status,
                        push_time,
                        pull_time,
                        project.sync.uncommitted_changes_count,
                        project.sync.unpushed_commits_count,
                        project.sync.retry_count,
                        next_push_retry,
                        project.sync.pull_retry_count,
                        next_pull_retry
                    )
                );
                if (project.sync.last_sync_error.strip().length > 0) {
                    sync_section.append("  error: `%s`\n".printf(project.sync.last_sync_error));
                }
            } else {
                sync_section.append("- %s: no project remote repository set\n".printf(project.name));
            }
        }

        return
            "# Local info\n\n" +
            "## Health\n" +
            "- db_ok: `%s`\n".printf(health.db_ok ? "true" : "false") +
            "- uptime_ms: `%lld`\n".printf(health.uptime_ms) +
            "- uptime_seconds: `%lld`\n".printf(uptime_seconds) +
            "- api_version: `%s`\n".printf(health.api_version) +
            "- server_version: `%s`\n".printf(health.server_version) +
            "- pid: `%d`\n\n".printf(health.pid) +
            "## Content\n" +
            "- Projects: `%d`\n".printf(projects.size) +
            "- Cards: `%d`\n".printf(total_card_count) +
            "- AI Threads: `%d`\n\n".printf(total_thread_count) +
            "## Local Models\n" +
            local_models_section + "\n" +
            "## Sync\n" +
            sync_section.str;
    }

    private Gee.ArrayList<Project> order_projects_home_first(Gee.ArrayList<Project> projects) {
        Project? home_project = null;
        var ordered_projects = new Gee.ArrayList<Project>();
        foreach (var project in projects) {
            if (home_project == null && project.name.strip().down() == "home") {
                home_project = project;
            } else {
                ordered_projects.add(project);
            }
        }
        if (home_project != null) {
            ordered_projects.insert(0, home_project);
        }
        return ordered_projects;
    }

    private string format_sync_time(bool has_timestamp, int64 timestamp) {
        if (!has_timestamp || timestamp <= 0) {
            return "never";
        }
        var now = new DateTime.now_utc().to_unix();
        return TextUtils.format_relative_time(now, timestamp);
    }

    private string join_list(Gee.ArrayList<string> values) {
        if (values.size == 0) {
            return "none";
        }
        var builder = new StringBuilder();
        for (int i = 0; i < values.size; i++) {
            if (i > 0) {
                builder.append(", ");
            }
            builder.append(values[i]);
        }
        return builder.str;
    }
}

}
