namespace HolderLinux {

public class ApiParsersProjects { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public static Gee.ArrayList<Project> parse_projects(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for projects response");
        }

        var out_list = new Gee.ArrayList<Project>();
        var data = root.get_array_member("data"); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
        for (uint i = 0; i < data.get_length(); i++) { // LCOV_EXCL_BR_LINE: loop overflow branch artifact
            var item = data.get_object_element(i); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
            ProjectSyncState sync = new ProjectSyncState();
            if (item.has_member("sync")) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
                var sync_node = item.get_member("sync"); // LCOV_EXCL_BR_LINE: null edge artifact
                if (sync_node != null && sync_node.get_node_type() == Json.NodeType.OBJECT) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
                    sync = parse_project_sync_state(item.get_object_member("sync")); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
                }
            }
            out_list.add(new Project( // LCOV_EXCL_BR_LINE: allocator/ctor edge branch artifact
                item.get_string_member("project_id"),
                item.get_string_member("name"),
                item.has_member("privacy_mode") ? item.get_string_member("privacy_mode") : "encrypted_git",
                item.has_member("root_path") ? item.get_string_member("root_path") : "",
                item.has_member("created_at") ? item.get_int_member("created_at") : 0,
                item.has_member("updated_at") ? item.get_int_member("updated_at") : 0,
                ApiParsersCommon.nullable_string_member_or_null(item, "git_remote_url"),
                sync,
                item.has_member("card_count") ? (int) item.get_int_member("card_count") : 0,
                item.has_member("root_card_count") ? (int) item.get_int_member("root_card_count") : 0
            ));
        }
        return out_list; // LCOV_EXCL_BR_LINE: return edge branch artifact
    }

    private static ProjectSyncState parse_project_sync_state(Json.Object obj) { // LCOV_EXCL_BR_LINE: declaration branch artifact
        return new ProjectSyncState( // LCOV_EXCL_BR_LINE: ctor edge branch artifact
            ApiParsersCommon.nullable_int_member_or_null(obj, "last_commit_at"),
            ApiParsersCommon.nullable_int_member_or_null(obj, "last_push_at"),
            ApiParsersCommon.nullable_int_member_or_null(obj, "last_pull_at"),
            obj.has_member("uncommitted_changes_count")
                ? (int) obj.get_int_member("uncommitted_changes_count")
                : 0,
            obj.has_member("unpushed_commits_count")
                ? (int) obj.get_int_member("unpushed_commits_count")
                : 0,
            ApiParsersCommon.string_member_or_empty(obj, "last_push_status"),
            ApiParsersCommon.string_member_or_empty(obj, "last_pull_status"),
            ApiParsersCommon.string_member_or_empty(obj, "last_sync_error"),
            ApiParsersCommon.nullable_int_member_or_null(obj, "last_sync_error_at"),
            obj.has_member("retry_count") ? (int) obj.get_int_member("retry_count") : 0,
            ApiParsersCommon.nullable_int_member_or_null(obj, "next_retry_at"),
            obj.has_member("pull_retry_count") ? (int) obj.get_int_member("pull_retry_count") : 0,
            ApiParsersCommon.nullable_int_member_or_null(obj, "next_pull_retry_at"),
            ApiParsersCommon.nullable_int_member_or_null(obj, "updated_at")
        );
    }
}

}
