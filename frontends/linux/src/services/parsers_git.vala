namespace HolderLinux {

public class ApiParsersGit {
    public static GitTestRemoteResult parse_git_test_remote_result(Json.Object data) {
        return new GitTestRemoteResult(
            ApiParsersCommon.string_member_or_empty(data, "project_id"),
            ApiParsersCommon.string_member_or_empty(data, "remote_url"),
            ApiParsersCommon.string_member_or_empty(data, "branch"),
            ApiParsersCommon.string_member_or_empty(data, "status"),
            data.has_member("remote_has_head") ? data.get_boolean_member("remote_has_head") : false,
            ApiParsersCommon.string_member_or_empty(data, "error_code"),
            ApiParsersCommon.string_member_or_empty(data, "error_message")
        );
    }

    public static GitPushResult parse_git_push_result(Json.Object data) {
        return new GitPushResult(
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

    public static Gee.ArrayList<GitProviderCatalogEntry> parse_git_provider_catalog(Json.Object root) throws Error {
        var providers = new Gee.ArrayList<GitProviderCatalogEntry>();
        if (!root.has_member("providers")) {
            return providers;
        }
        var items = root.get_array_member("providers");
        for (uint i = 0; i < items.get_length(); i++) {
            var item = items.get_object_element(i);
            var preferred_transport = "";
            var ssh_example = "";
            var https_example = "";
            var defaults = ApiParsersCommon.object_member_or_null(item, "defaults");
            if (defaults != null) {
                preferred_transport = ApiParsersCommon.string_member_or_empty(defaults, "preferred_transport");
            }

            var transports_summary = "";
            var git = ApiParsersCommon.object_member_or_null(item, "git");
            if (git != null && git.has_member("transports")) {
                var transports = git.get_array_member("transports");
                var sb = new StringBuilder();
                for (uint idx = 0; idx < transports.get_length(); idx++) {
                    if (idx > 0) {
                        sb.append(", ");
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

            providers.add(new GitProviderCatalogEntry(
                ApiParsersCommon.string_member_or_empty(item, "id"),
                ApiParsersCommon.string_member_or_empty(item, "name"),
                ApiParsersCommon.string_member_or_empty(item, "kind"),
                preferred_transport,
                transports_summary,
                ssh_example,
                https_example
            ));
        }
        return providers;
    }
}

}
