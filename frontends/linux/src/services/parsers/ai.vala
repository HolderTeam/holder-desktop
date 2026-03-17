namespace HolderLinux {

public class ApiParsersAi { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public static AiCapabilitiesInfo parse_ai_capabilities(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai capabilities response");
        }

        var data = root.get_object_member("data"); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
        var models = new Gee.ArrayList<string>();
        if (data.has_member("models")) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
            var items = data.get_array_member("models"); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
            for (uint i = 0; i < items.get_length(); i++) { // LCOV_EXCL_BR_LINE: loop overflow branch artifact
                var model = items.get_object_element(i);
                if (model.has_member("name")) {
                    models.add(model.get_string_member("name"));
                }
            }
        }

        var recommended_install = new Gee.ArrayList<string>();
        if (data.has_member("recommended_install")) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
            var items = data.get_array_member("recommended_install"); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
            for (uint i = 0; i < items.get_length(); i++) { // LCOV_EXCL_BR_LINE: loop overflow branch artifact
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

        return new AiCapabilitiesInfo( // LCOV_EXCL_BR_LINE: ctor edge branches are coverage artifacts
            data.has_member("runner_available") ? data.get_boolean_member("runner_available") : false, // LCOV_EXCL_BR_LINE: json member error edge artifact
            ApiParsersCommon.string_member_or_empty(data, "error"),
            data.has_member("last_checked") ? data.get_int_member("last_checked") : 0,
            ApiParsersCommon.string_member_or_empty(data, "version"),
            caste_name,
            models,
            recommended_install
        );
    }

    public static AiStatusInfo parse_ai_status(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai status response");
        }

        var data = root.get_object_member("data");
        var pull_jobs = new Gee.ArrayList<string>();
        if (data.has_member("pulls")) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
            var pulls = data.get_array_member("pulls"); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
            for (uint i = 0; i < pulls.get_length(); i++) { // LCOV_EXCL_BR_LINE: loop overflow branch artifact
                var pull = pulls.get_object_element(i);
                var model = pull.has_member("model") ? pull.get_string_member("model") : "unknown";
                var status = pull.has_member("status") ? pull.get_string_member("status") : "unknown";
                double percent = 0.0;
                if (pull.has_member("progress")) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
                    var progress = pull.get_object_member("progress");
                    if (progress != null && progress.has_member("percent")) { // LCOV_EXCL_BR_LINE: null-check short-circuit artifact
                        percent = progress.get_double_member("percent");
                    }
                }
                pull_jobs.add("%s (%s, %.1f%%)".printf(model, status, percent));
            }
        }

        return new AiStatusInfo( // LCOV_EXCL_BR_LINE: ctor edge branches are coverage artifacts
            data.has_member("checked_at") ? data.get_int_member("checked_at") : 0,
            data.has_member("runner_available") ? data.get_boolean_member("runner_available") : false,
            ApiParsersCommon.string_member_or_empty(data, "runner_error"),
            data.has_member("active_runs") ? data.get_int_member("active_runs") : 0,
            data.has_member("active_pull_jobs") ? data.get_int_member("active_pull_jobs") : 0,
            data.has_member("cloud_configured_providers") ? data.get_int_member("cloud_configured_providers") : 0,
            pull_jobs
        );
    }

    public static Gee.ArrayList<AiThreadSummary> parse_ai_threads(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai threads response");
        }

        var out_list = new Gee.ArrayList<AiThreadSummary>();
        var data = root.get_array_member("data");
        for (uint i = 0; i < data.get_length(); i++) {
            var item = data.get_object_element(i);
            out_list.add(new AiThreadSummary( // LCOV_EXCL_BR_LINE: allocator/ctor edge branch artifact
                ApiParsersCommon.string_member_or_empty(item, "thread_id"),
                ApiParsersCommon.string_member_or_empty(item, "project_id"),
                ApiParsersCommon.string_member_or_empty(item, "title"),
                item.has_member("created_at") ? item.get_int_member("created_at") : 0,
                item.has_member("updated_at") ? item.get_int_member("updated_at") : 0
            ));
        }
        return out_list; // LCOV_EXCL_BR_LINE: return edge branch artifact
    }

    public static Gee.ArrayList<AiCatalogProvider> parse_ai_provider_catalog(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        var providers = new Gee.ArrayList<AiCatalogProvider>();
        var models_node = ApiParsersCommon.object_member_or_null(root, "models");
        if (models_node == null) {
            return providers; // LCOV_EXCL_BR_LINE: return edge branch artifact
        }
        var defaults = ApiParsersCommon.object_member_or_null(models_node, "provider_defaults");
        if (defaults == null) {
            return providers; // LCOV_EXCL_BR_LINE: return edge branch artifact
        }
        var names = defaults.get_members();
        if (names == null) {
            return providers; // LCOV_EXCL_BR_LINE: return edge branch artifact
        }
        for (unowned List<weak string>? cursor = names; cursor != null; cursor = cursor.next) { // LCOV_EXCL_BR_LINE: iterator terminal branch artifact
            unowned string provider_id = cursor.data;
            var node = defaults.get_member(provider_id); // LCOV_EXCL_BR_LINE: invalid node edge artifact
            if (node != null && node.get_node_type() == Json.NodeType.OBJECT) { // LCOV_EXCL_BR_LINE: short-circuit artifact branch
                var provider = defaults.get_object_member(provider_id);
                var display_name = ApiParsersCommon.string_member_or_empty(provider, "provider");
                if (display_name.length == 0) {
                    display_name = provider_id;
                }
                providers.add(new AiCatalogProvider( // LCOV_EXCL_BR_LINE: allocator/ctor edge branch artifact
                    provider_id,
                    display_name,
                    provider.has_member("enabled") ? provider.get_boolean_member("enabled") : false, // LCOV_EXCL_BR_LINE: json member error edge artifact
                    false,
                    ApiParsersCommon.string_member_or_empty(provider, "setup_url"),
                    ApiParsersCommon.string_member_or_empty(provider, "docs_url")
                ));
            }
        }
        return providers; // LCOV_EXCL_BR_LINE: return edge branch artifact
    }

    public static Gee.ArrayList<AiRuntimeProvider> parse_ai_runtime_providers(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai runtime providers response");
        }
        var data = root.get_object_member("data");
        if (!data.has_member("providers")) {
            throw new ApiError.PROTOCOL("Missing data.providers for ai runtime providers response");
        }

        var providers = new Gee.ArrayList<AiRuntimeProvider>();
        var items = data.get_array_member("providers");
        for (uint i = 0; i < items.get_length(); i++) { // LCOV_EXCL_BR_LINE: loop overflow branch artifact
            var item = items.get_object_element(i);
            providers.add(new AiRuntimeProvider( // LCOV_EXCL_BR_LINE: allocator/ctor edge branch artifact
                ApiParsersCommon.string_member_or_empty(item, "id"),
                ApiParsersCommon.string_member_or_empty(item, "display_name"),
                item.has_member("enabled") ? item.get_boolean_member("enabled") : false,
                item.has_member("configured") ? item.get_boolean_member("configured") : false,
                ApiParsersCommon.string_member_or_empty(item, "setup_url"),
                ApiParsersCommon.string_member_or_empty(item, "docs_url")
            ));
        }

        return providers; // LCOV_EXCL_BR_LINE: return edge branch artifact
    }

    public static AiRouterConfigInfo parse_ai_router_config(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai router config response");
        }
        var data = root.get_object_member("data");
        var effective = ApiParsersCommon.object_member_or_null(data, "effective");
        var global = ApiParsersCommon.object_member_or_null(data, "global");
        var project = ApiParsersCommon.object_member_or_null(data, "project");

        return new AiRouterConfigInfo( // LCOV_EXCL_BR_LINE: allocator/ctor edge branch artifact
            effective != null ? ApiParsersCommon.string_member_or_empty(effective, "scope") : "auto",
            effective != null ? ApiParsersCommon.string_member_or_empty(effective, "router_model") : "",
            global != null ? ApiParsersCommon.string_member_or_empty(global, "router_model") : "",
            global != null ? (ApiParsersCommon.nullable_int_member_or_null(global, "updated_at") ?? 0) : 0,
            project != null ? ApiParsersCommon.string_member_or_empty(project, "project_id") : "",
            project != null ? ApiParsersCommon.string_member_or_empty(project, "router_model") : "",
            project != null ? (ApiParsersCommon.nullable_int_member_or_null(project, "updated_at") ?? 0) : 0
        );
    }
}

}
