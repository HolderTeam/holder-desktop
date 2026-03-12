namespace HolderLinux {

public class ApiParsersAi {
    public static AiCapabilitiesInfo parse_ai_capabilities(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai capabilities response");
        }

        var data = root.get_object_member("data");
        var models = new Gee.ArrayList<string>();
        if (data.has_member("models")) {
            var items = data.get_array_member("models");
            for (uint i = 0; i < items.get_length(); i++) {
                var model = items.get_object_element(i);
                if (model.has_member("name")) {
                    models.add(model.get_string_member("name"));
                }
            }
        }

        var recommended_install = new Gee.ArrayList<string>();
        if (data.has_member("recommended_install")) {
            var items = data.get_array_member("recommended_install");
            for (uint i = 0; i < items.get_length(); i++) {
                var rec = items.get_object_element(i);
                if (rec.has_member("tag")) {
                    recommended_install.add(rec.get_string_member("tag"));
                }
            }
        }

        string caste_name = "";
        var caste = ApiParsersCommon.object_member_or_null(data, "caste");
        if (caste != null) {
            caste_name = ApiParsersCommon.string_member_or_empty(caste, "name");
        }

        return new AiCapabilitiesInfo(
            data.has_member("runner_available") ? data.get_boolean_member("runner_available") : false,
            ApiParsersCommon.string_member_or_empty(data, "error"),
            data.has_member("last_checked") ? data.get_int_member("last_checked") : 0,
            ApiParsersCommon.string_member_or_empty(data, "version"),
            caste_name,
            models,
            recommended_install
        );
    }

    public static AiStatusInfo parse_ai_status(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai status response");
        }

        var data = root.get_object_member("data");
        var pull_jobs = new Gee.ArrayList<string>();
        if (data.has_member("pulls")) {
            var pulls = data.get_array_member("pulls");
            for (uint i = 0; i < pulls.get_length(); i++) {
                var pull = pulls.get_object_element(i);
                var model = pull.has_member("model") ? pull.get_string_member("model") : "unknown";
                var status = pull.has_member("status") ? pull.get_string_member("status") : "unknown";
                double percent = 0.0;
                if (pull.has_member("progress")) {
                    var progress = pull.get_object_member("progress");
                    if (progress != null && progress.has_member("percent")) {
                        percent = progress.get_double_member("percent");
                    }
                }
                pull_jobs.add("%s (%s, %.1f%%)".printf(model, status, percent));
            }
        }

        return new AiStatusInfo(
            data.has_member("checked_at") ? data.get_int_member("checked_at") : 0,
            data.has_member("runner_available") ? data.get_boolean_member("runner_available") : false,
            ApiParsersCommon.string_member_or_empty(data, "runner_error"),
            data.has_member("active_runs") ? data.get_int_member("active_runs") : 0,
            data.has_member("active_pull_jobs") ? data.get_int_member("active_pull_jobs") : 0,
            data.has_member("cloud_configured_providers") ? data.get_int_member("cloud_configured_providers") : 0,
            pull_jobs
        );
    }

    public static Gee.ArrayList<AiThreadSummary> parse_ai_threads(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai threads response");
        }

        var out_list = new Gee.ArrayList<AiThreadSummary>();
        var data = root.get_array_member("data");
        for (uint i = 0; i < data.get_length(); i++) {
            var item = data.get_object_element(i);
            out_list.add(new AiThreadSummary(
                ApiParsersCommon.string_member_or_empty(item, "thread_id"),
                ApiParsersCommon.string_member_or_empty(item, "project_id"),
                ApiParsersCommon.string_member_or_empty(item, "title"),
                item.has_member("created_at") ? item.get_int_member("created_at") : 0,
                item.has_member("updated_at") ? item.get_int_member("updated_at") : 0
            ));
        }
        return out_list;
    }

    public static Gee.ArrayList<AiCatalogProvider> parse_ai_provider_catalog(Json.Object root) throws Error {
        var providers = new Gee.ArrayList<AiCatalogProvider>();
        var models_node = ApiParsersCommon.object_member_or_null(root, "models");
        if (models_node == null) {
            return providers;
        }
        var defaults = ApiParsersCommon.object_member_or_null(models_node, "provider_defaults");
        if (defaults == null) {
            return providers;
        }
        var names = defaults.get_members();
        if (names == null) {
            return providers;
        }
        for (unowned List<weak string>? cursor = names; cursor != null; cursor = cursor.next) {
            unowned string provider_id = cursor.data;
            var node = defaults.get_member(provider_id);
            if (node != null && node.get_node_type() == Json.NodeType.OBJECT) {
                var provider = defaults.get_object_member(provider_id);
                var display_name = ApiParsersCommon.string_member_or_empty(provider, "provider");
                if (display_name.length == 0) {
                    display_name = provider_id;
                }
                providers.add(new AiCatalogProvider(
                    provider_id,
                    display_name,
                    provider.has_member("enabled") ? provider.get_boolean_member("enabled") : false,
                    false,
                    ApiParsersCommon.string_member_or_empty(provider, "setup_url"),
                    ApiParsersCommon.string_member_or_empty(provider, "docs_url")
                ));
            }
        }
        return providers;
    }
}

}
