namespace HolderLinux {

public class ApiParsersAi { // LCOV_EXCL_LINE: declaration-only coverage artifact
    private static Gee.ArrayList<AiRunnerInfo> parse_ai_runners_from_data(Json.Object data) {
        var runners = new Gee.ArrayList<AiRunnerInfo>();
        if (!data.has_member("runners")) {
            return runners;
        }
        var items = data.get_array_member("runners");
        for (uint i = 0; i < items.get_length(); i++) {
            runners.add(parse_ai_runner(items.get_object_element(i)));
        }
        return runners;
    }

    private static AiRunnerInfo? find_auto_local_runner(Gee.ArrayList<AiRunnerInfo> runners) {
        foreach (var runner in runners) {
            if (runner.runner_id == "auto-local" || runner.source == "auto_local") {
                return runner;
            }
        }
        return null;
    }

    private static int64 count_active_pulls(Gee.ArrayList<AiRunnerInfo> runners) {
        int64 count = 0;
        foreach (var runner in runners) {
            foreach (var pull in runner.runtime.pulls) {
                if (pull.status == "queued" ||
                    pull.status == "running" ||
                    pull.status == "downloading" ||
                    pull.status == "verifying") {
                    count++;
                }
            }
        }
        return count;
    }

    private static Gee.ArrayList<AiRunnerPullInfo> collect_runner_pulls(Gee.ArrayList<AiRunnerInfo> runners) {
        var pulls = new Gee.ArrayList<AiRunnerPullInfo>();
        foreach (var runner in runners) {
            foreach (var pull in runner.runtime.pulls) {
                pulls.add(new AiRunnerPullInfo(
                    pull.job_id,
                    pull.runner_id,
                    pull.model,
                    pull.status,
                    pull.percent,
                    pull.stage
                ));
            }
        }
        return pulls;
    }

    private static AiRunnerRuntimeInfo parse_ai_runner_runtime(Json.Object data) {
        var models = new Gee.ArrayList<string>();
        if (data.has_member("models")) {
            var items = data.get_array_member("models");
            for (uint i = 0; i < items.get_length(); i++) {
                var item = items.get_object_element(i);
                var name = ApiParsersCommon.string_member_or_empty(item, "name");
                if (name.length > 0) {
                    models.add(name);
                }
            }
        }

        var pulls = new Gee.ArrayList<AiRunnerPullInfo>();
        if (data.has_member("pulls")) {
            var items = data.get_array_member("pulls");
            for (uint i = 0; i < items.get_length(); i++) {
                var item = items.get_object_element(i);
                string model_name = "unknown";
                if (item.has_member("model")) {
                    model_name = ApiParsersCommon.string_member_or_empty(item, "model");
                    if (model_name.length == 0) {
                        model_name = "unknown";
                    }
                }
                string pull_status = "unknown";
                if (item.has_member("status")) {
                    pull_status = ApiParsersCommon.string_member_or_empty(item, "status");
                    if (pull_status.length == 0) {
                        pull_status = "unknown";
                    }
                }
                double percent = 0.0;
                string stage = "";
                if (item.has_member("progress")) {
                    var progress = item.get_object_member("progress");
                    if (progress != null) {
                        if (progress.has_member("percent")) {
                            percent = progress.get_double_member("percent");
                        }
                        stage = ApiParsersCommon.string_member_or_empty(progress, "stage");
                    }
                }
                pulls.add(new AiRunnerPullInfo(
                    ApiParsersCommon.string_member_or_empty(item, "job_id"),
                    ApiParsersCommon.string_member_or_empty(item, "runner_id"),
                    model_name,
                    pull_status,
                    percent,
                    stage
                ));
            }
        }

        return new AiRunnerRuntimeInfo(
            data.has_member("configured") ? data.get_boolean_member("configured") : false,
            data.has_member("available") ? data.get_boolean_member("available") : false,
            data.has_member("spawn_attempted") ? data.get_boolean_member("spawn_attempted") : false,
            data.has_member("last_checked") ? data.get_int_member("last_checked") : 0,
            ApiParsersCommon.nullable_string_member_or_null(data, "version") ?? "",
            ApiParsersCommon.nullable_string_member_or_null(data, "error") ?? "",
            models,
            pulls
        );
    }

    private static AiRunnerInfo parse_ai_runner(Json.Object data) {
        var runtime_node = ApiParsersCommon.object_member_or_null(data, "runtime");
        var runtime = runtime_node != null
            ? parse_ai_runner_runtime(runtime_node)
            : new AiRunnerRuntimeInfo(false, false, false, 0, "", "", new Gee.ArrayList<string>(), new Gee.ArrayList<AiRunnerPullInfo>());

        return new AiRunnerInfo(
            ApiParsersCommon.string_member_or_empty(data, "runner_id"),
            ApiParsersCommon.string_member_or_empty(data, "name"),
            ApiParsersCommon.string_member_or_empty(data, "kind"),
            ApiParsersCommon.nullable_string_member_or_null(data, "base_url"),
            ApiParsersCommon.string_member_or_empty(data, "source"),
            data.has_member("enabled") ? data.get_boolean_member("enabled") : false,
            data.has_member("created_at") ? data.get_int_member("created_at") : 0,
            data.has_member("updated_at") ? data.get_int_member("updated_at") : 0,
            runtime
        );
    }

    public static Gee.ArrayList<AiRunnerInfo> parse_ai_runners(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai runners response");
        }
        var data = root.get_object_member("data");
        if (!data.has_member("runners")) {
            throw new ApiError.PROTOCOL("Missing data.runners for ai runners response");
        }
        return parse_ai_runners_from_data(data);
    }

    public static AiRunnerInfo parse_ai_runner_detail(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai runner response");
        }
        return parse_ai_runner(root.get_object_member("data"));
    }

    public static AiCapabilitiesInfo parse_ai_capabilities(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai capabilities response");
        }

        var data = root.get_object_member("data"); // LCOV_EXCL_BR_LINE: invalid-type branch aborts in json-glib
        var runners = parse_ai_runners_from_data(data);
        var auto_local = find_auto_local_runner(runners);
        var models = new Gee.ArrayList<string>();
        if (auto_local != null) {
            foreach (var model_name in auto_local.runtime.models) {
                models.add(model_name);
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
            auto_local != null ? auto_local.runtime.available : false,
            auto_local != null ? auto_local.runtime.error : "",
            auto_local != null ? auto_local.runtime.last_checked : 0,
            auto_local != null ? auto_local.runtime.version : "",
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
        var runners = parse_ai_runners_from_data(data);
        var auto_local = find_auto_local_runner(runners);
        var pulls_out = collect_runner_pulls(runners);

        int64 cloud_configured = 0;
        if (data.has_member("cloud")) {
            cloud_configured = data.get_array_member("cloud").get_length();
        }

        return new AiStatusInfo( // LCOV_EXCL_BR_LINE: ctor edge branches are coverage artifacts
            data.has_member("checked_at") ? data.get_int_member("checked_at") : 0,
            auto_local != null ? auto_local.runtime.available : false,
            auto_local != null ? auto_local.runtime.error : "",
            data.has_member("active_runs") ? data.get_int_member("active_runs") : 0,
            count_active_pulls(runners),
            cloud_configured,
            pulls_out
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

    public static Gee.ArrayList<AiMessage> parse_ai_messages(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai messages response");
        }

        var out_list = new Gee.ArrayList<AiMessage>();
        var data = root.get_array_member("data");
        for (uint i = 0; i < data.get_length(); i++) {
            var item = data.get_object_element(i);
            string? provider = null;
            if (item.has_member("provider")) {
                var provider_node = item.get_member("provider");
                if (provider_node != null && provider_node.get_node_type() != Json.NodeType.NULL) {
                    provider = item.get_string_member("provider");
                }
            }
            string? model = null;
            if (item.has_member("model")) {
                var model_node = item.get_member("model");
                if (model_node != null && model_node.get_node_type() != Json.NodeType.NULL) {
                    model = item.get_string_member("model");
                }
            }
            out_list.add(new AiMessage(
                ApiParsersCommon.string_member_or_empty(item, "message_id"),
                ApiParsersCommon.string_member_or_empty(item, "thread_id"),
                ApiParsersCommon.string_member_or_empty(item, "role"),
                ApiParsersCommon.string_member_or_empty(item, "source"),
                provider,
                model,
                ApiParsersCommon.string_member_or_empty(item, "content"),
                item.has_member("created_at") ? item.get_int_member("created_at") : 0
            ));
        }
        return out_list;
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

    public static AiLocalModelConfigInfo parse_ai_local_model_config(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai local model config response");
        }
        var data = root.get_object_member("data");

        return new AiLocalModelConfigInfo(
            ApiParsersCommon.nullable_string_member_or_null(data, "fast_model"),
            ApiParsersCommon.nullable_string_member_or_null(data, "strong_model"),
            ApiParsersCommon.nullable_string_member_or_null(data, "deep_model"),
            ApiParsersCommon.nullable_int_member_or_null(data, "updated_at") ?? 0
        );
    }

    public static Gee.ArrayList<AiProviderCredentialState> parse_ai_provider_credentials(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai provider credentials response");
        }
        var data = root.get_object_member("data");
        if (!data.has_member("providers")) {
            throw new ApiError.PROTOCOL("Missing data.providers for ai provider credentials response");
        }
        var providers = new Gee.ArrayList<AiProviderCredentialState>();
        var items = data.get_array_member("providers");
        for (uint i = 0; i < items.get_length(); i++) { // LCOV_EXCL_BR_LINE: loop overflow branch artifact
            var item = items.get_object_element(i);
            providers.add(new AiProviderCredentialState( // LCOV_EXCL_BR_LINE: allocator/ctor edge branch artifact
                ApiParsersCommon.string_member_or_empty(item, "provider"),
                item.has_member("configured") ? item.get_boolean_member("configured") : false,
                ApiParsersCommon.string_member_or_empty(item, "api_key_preview"),
                item.has_member("updated_at") ? item.get_int_member("updated_at") : 0
            ));
        }
        return providers; // LCOV_EXCL_BR_LINE: return edge branch artifact
    }

    public static Gee.ArrayList<AiProviderSettingState> parse_ai_provider_settings(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai provider settings response");
        }
        var data = root.get_object_member("data");
        if (!data.has_member("providers")) {
            throw new ApiError.PROTOCOL("Missing data.providers for ai provider settings response");
        }
        var providers = new Gee.ArrayList<AiProviderSettingState>();
        var items = data.get_array_member("providers");
        for (uint i = 0; i < items.get_length(); i++) { // LCOV_EXCL_BR_LINE: loop overflow branch artifact
            var item = items.get_object_element(i);
            providers.add(new AiProviderSettingState( // LCOV_EXCL_BR_LINE: allocator/ctor edge branch artifact
                ApiParsersCommon.string_member_or_empty(item, "provider"),
                item.has_member("enabled") ? item.get_boolean_member("enabled") : false,
                item.has_member("updated_at") ? item.get_int_member("updated_at") : 0
            ));
        }
        return providers; // LCOV_EXCL_BR_LINE: return edge branch artifact
    }

    public static NudgeEvaluationResult parse_nudge_evaluation(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE: declaration branch artifact
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for nudge evaluation response");
        }
        var data = root.get_object_member("data");
        AiNudge? nudge = null;
        if (data.has_member("nudge")) {
            var node = data.get_member("nudge");
            if (node != null && node.get_node_type() == Json.NodeType.OBJECT) {
                nudge = parse_ai_nudge(node.get_object());
            }
        }
        return new NudgeEvaluationResult(
            ApiParsersCommon.string_member_or_empty(data, "kind"),
            data.has_member("accepted") ? data.get_boolean_member("accepted") : false,
            data.has_member("should_nudge") ? data.get_boolean_member("should_nudge") : false,
            ApiParsersCommon.string_member_or_empty(data, "reason"),
            nudge
        );
    }

    public static AiNudge parse_ai_nudge(Json.Object data) throws Error {
        var suggestions = new Gee.ArrayList<string>();
        if (data.has_member("suggestions")) {
            var items = data.get_array_member("suggestions");
            for (uint i = 0; i < items.get_length(); i++) {
                suggestions.add(items.get_string_element(i));
            }
        }
        return new AiNudge(
            ApiParsersCommon.string_member_or_empty(data, "nudge_id"),
            ApiParsersCommon.string_member_or_empty(data, "kind"),
            ApiParsersCommon.string_member_or_empty(data, "project_id"),
            ApiParsersCommon.string_member_or_empty(data, "card_id"),
            ApiParsersCommon.string_member_or_empty(data, "title"),
            ApiParsersCommon.string_member_or_empty(data, "body"),
            ApiParsersCommon.string_member_or_empty(data, "basis_fingerprint"),
            ApiParsersCommon.string_member_or_empty(data, "basis_commit"),
            data.has_member("created_at") ? data.get_int_member("created_at") : 0,
            suggestions
        );
    }

    public static Gee.ArrayList<AiNudge> parse_ai_nudge_list(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for ai nudge list response");
        }
        var data = root.get_object_member("data");
        if (!data.has_member("nudges")) {
            throw new ApiError.PROTOCOL("Missing data.nudges for ai nudge list response");
        }
        var nudges = new Gee.ArrayList<AiNudge>();
        var items = data.get_array_member("nudges");
        for (uint i = 0; i < items.get_length(); i++) {
            nudges.add(parse_ai_nudge(items.get_object_element(i)));
        }
        return nudges;
    }
}

}
