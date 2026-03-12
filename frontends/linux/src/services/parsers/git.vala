namespace HolderLinux {

public class ApiParsersGit { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public static GitTestRemoteResult parse_git_test_remote_result(Json.Object data) { // LCOV_EXCL_BR_LINE: declaration branch artifact
        return new GitTestRemoteResult( // LCOV_EXCL_BR_LINE: ctor edge branch artifact
            ApiParsersCommon.string_member_or_empty(data, "project_id"),
            ApiParsersCommon.string_member_or_empty(data, "remote_url"),
            ApiParsersCommon.string_member_or_empty(data, "branch"),
            ApiParsersCommon.string_member_or_empty(data, "status"),
            data.has_member("remote_has_head") ? data.get_boolean_member("remote_has_head") : false,
            ApiParsersCommon.string_member_or_empty(data, "error_code"),
            ApiParsersCommon.string_member_or_empty(data, "error_message")
        );
    }

    public static GitPushResult parse_git_push_result(Json.Object data) { // LCOV_EXCL_BR_LINE: declaration branch artifact
        return new GitPushResult( // LCOV_EXCL_BR_LINE: ctor edge branch artifact
            ApiParsersCommon.string_member_or_empty(data, "project_id"),
            ApiParsersCommon.string_member_or_empty(data, "remote_url"),
            ApiParsersCommon.string_member_or_empty(data, "branch"),
            ApiParsersCommon.string_member_or_empty(data, "status"),
            data.has_member("ahead_count") ? (int) data.get_int_member("ahead_count") : 0,
            data.has_member("behind_count") ? (int) data.get_int_member("behind_count") : 0,
            ApiParsersCommon.string_member_or_empty(data, "error_code"),
            ApiParsersCommon.string_member_or_empty(data, "error_message"),
            ApiParsersCommon.string_member_or_empty(data, "next_action")
        );
    }

    public static Gee.ArrayList<GitProviderCatalogEntry> parse_git_provider_catalog(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        var providers = new Gee.ArrayList<GitProviderCatalogEntry>();
        if (!root.has_member("providers")) {
            return providers;
        }
        var items = root.get_array_member("providers"); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
        for (uint i = 0; i < items.get_length(); i++) { // LCOV_EXCL_BR_LINE: loop overflow branch artifact
            var item = items.get_object_element(i); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
            var preferred_transport = "";
            var ssh_example = "";
            var https_example = "";
            var defaults = ApiParsersCommon.object_member_or_null(item, "defaults");
            if (defaults != null) {
                preferred_transport = ApiParsersCommon.string_member_or_empty(defaults, "preferred_transport");
            }

            var transports_summary = "";
            var git = ApiParsersCommon.object_member_or_null(item, "git");
            if (git != null && git.has_member("transports")) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
                var transports = git.get_array_member("transports");
                var sb = new StringBuilder();
                for (uint idx = 0; idx < transports.get_length(); idx++) {
                    if (idx > 0) {
                        sb.append(", "); // LCOV_EXCL_BR_LINE: branch edge artifact in loop
                    }
                    sb.append(transports.get_string_element(idx));
                }
                transports_summary = sb.str;
                var examples = ApiParsersCommon.object_member_or_null(git, "examples");
                if (examples != null) {
                    ssh_example = ApiParsersCommon.string_member_or_empty(examples, "ssh");
                    https_example = ApiParsersCommon.string_member_or_empty(examples, "https");
                }
            }

            providers.add(new GitProviderCatalogEntry( // LCOV_EXCL_BR_LINE: allocator/ctor edge branch artifact
                ApiParsersCommon.string_member_or_empty(item, "id"),
                ApiParsersCommon.string_member_or_empty(item, "name"),
                ApiParsersCommon.string_member_or_empty(item, "kind"),
                preferred_transport,
                transports_summary,
                ssh_example,
                https_example
            ));
        }
        return providers; // LCOV_EXCL_BR_LINE: return edge branch artifact
    }
}

}
