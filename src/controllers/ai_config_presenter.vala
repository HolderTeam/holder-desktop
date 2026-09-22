namespace HolderLinux {

// One local-model dropdown's choices: index 0 is "(auto)", then one entry per installed model,
// then a "Missing:" entry when the saved preference no longer matches any runner's model.
public class AiModelOptions : Object {
    private Gee.ArrayList<string> option_labels = new Gee.ArrayList<string>();
    private Gee.ArrayList<string?> option_values = new Gee.ArrayList<string?>();

    public uint selected_index { get; private set; default = 0; }

    public Gee.ArrayList<string> labels {
        get { return option_labels; }
    }

    public bool has_choices {
        get { return option_values.size > 1; }
    }

    internal void add(string label, string? value) {
        option_labels.add(label);
        option_values.add(value);
    }

    internal void select_last() {
        selected_index = option_values.size - 1;
    }

    // The model ref behind a dropdown position; null for "(auto)" or anything out of range.
    public string? value_at(uint index) {
        if (index == 0 || index >= option_values.size) {
            return null;
        }
        return option_values[(int) index];
    }
}

public class AiRunnerRowPresentation : Object {
    public string title { get; construct; }
    public string summary { get; construct; }
    public string runtime { get; construct; }
    public string? error { get; construct; }
    public string? installed { get; construct; }
    public string? pulls { get; construct; }
    public bool is_manual { get; construct; }

    public AiRunnerRowPresentation(string title,
                                   string summary,
                                   string runtime,
                                   string? error,
                                   string? installed,
                                   string? pulls,
                                   bool is_manual) {
        Object(
            title: title,
            summary: summary,
            runtime: runtime,
            error: error,
            installed: installed,
            pulls: pulls,
            is_manual: is_manual
        );
    }
}

public class AiProviderRowPresentation : Object {
    public string title { get; construct; }
    public string configured_text { get; construct; }
    public string key_placeholder { get; construct; }
    public bool can_remove_key { get; construct; }
    public bool enabled { get; construct; }
    public bool setup_available { get; construct; }
    public bool docs_available { get; construct; }

    public AiProviderRowPresentation(string title,
                                     string configured_text,
                                     string key_placeholder,
                                     bool can_remove_key,
                                     bool enabled,
                                     bool setup_available,
                                     bool docs_available) {
        Object(
            title: title,
            configured_text: configured_text,
            key_placeholder: key_placeholder,
            can_remove_key: can_remove_key,
            enabled: enabled,
            setup_available: setup_available,
            docs_available: docs_available
        );
    }
}

// Text and decisions for the AI configuration panel.
public class AiConfigPresenter { // LCOV_EXCL_LINE: declaration-only coverage artifact
    public const string CONNECT_MESSAGE = "Connect to holderd to configure AI.";
    public const string LOADING_MESSAGE = "Loading AI config...";
    public const string LOAD_FAILED_MESSAGE = "Failed to load AI config.";
    public const string READY_MESSAGE =
        "Configure model runners, local model preferences, and cloud providers.";
    public const string LOCAL_RUNTIME_UNAVAILABLE = "Local runtime unavailable";
    public const string NO_RECOMMENDED_INSTALLS_HINT = "No local model installs recommended right now.";
    public const int LOCAL_MODEL_SAVE_DELAY_MS = 500;

    public static string join_list(Gee.ArrayList<string> values) {
        if (values.size == 0) {
            return "none";
        }
        return join_with(", ", values);
    }

    private static string join_with(string separator, Gee.ArrayList<string> values) {
        var builder = new StringBuilder();
        for (int i = 0; i < values.size; i++) {
            if (i > 0) {
                builder.append(separator);
            }
            builder.append(values[i]);
        }
        return builder.str;
    }

    public static string runtime_summary(AiCapabilitiesInfo capabilities) {
        var parts = new Gee.ArrayList<string>();
        parts.add("Runtime: %s".printf(capabilities.runner_available ? "available" : "unavailable"));
        if (capabilities.caste_name.strip().length > 0) {
            parts.add("Engine: %s".printf(capabilities.caste_name));
        }
        if (capabilities.runner_version.strip().length > 0) {
            parts.add("Version: %s".printf(capabilities.runner_version));
        }
        var summary = join_with(" | ", parts);
        if (capabilities.runner_error.strip().length > 0) {
            return "%s\n%s".printf(summary, capabilities.runner_error);
        }
        return summary;
    }

    public static string recommended_installs_text(Gee.ArrayList<string> recommended) {
        if (recommended.size == 0) {
            return "Recommended installs: none";
        }
        return "Recommended installs: %s".printf(join_list(recommended));
    }

    public static string activity_summary(AiStatusInfo status) {
        return ("Active runs: %" + int64.FORMAT
                + " | Active pulls: %" + int64.FORMAT
                + " | Cloud providers configured: %" + int64.FORMAT).printf(
            status.active_runs,
            status.active_pull_jobs,
            status.cloud_configured_providers
        );
    }

    public static string pull_jobs_summary(Gee.ArrayList<AiRunnerPullInfo> pulls,
                                           Gee.ArrayList<AiRunnerInfo> runners) {
        return "Pull jobs: %s".printf(format_pulls(pulls, runners));
    }

    public static string format_pulls(Gee.ArrayList<AiRunnerPullInfo> pulls,
                                      Gee.ArrayList<AiRunnerInfo> runners) {
        if (pulls.size == 0) {
            return "none";
        }
        var parts = new Gee.ArrayList<string>();
        foreach (var pull in pulls) {
            parts.add("%s (%s, %.1f%%)".printf(pull_target_label(pull, runners), pull.status, pull.percent));
        }
        return join_list(parts);
    }

    public static string pull_target_label(AiRunnerPullInfo pull, Gee.ArrayList<AiRunnerInfo> runners) {
        if (pull.runner_id.strip().length == 0) {
            return pull.model;
        }
        return model_ref_label(model_ref(pull.runner_id, pull.model), runners);
    }

    public static string model_ref(string runner_id, string model_name) {
        return "%s::%s".printf(runner_id, model_name);
    }

    public static string runner_model_label(AiRunnerInfo runner, string model_name) {
        var runner_label = runner.name.strip();
        if (runner_label.length == 0) {
            runner_label = runner.runner_id;
        }
        return "%s / %s".printf(runner_label, model_name);
    }

    public static string model_ref_label(string ref_text, Gee.ArrayList<AiRunnerInfo> runners) {
        var separator = ref_text.index_of("::");
        if (separator < 0) {
            return ref_text;
        }
        var runner_id = ref_text.substring(0, separator);
        var model_name = ref_text.substring(separator + 2);
        foreach (var runner in runners) {
            if (runner.runner_id == runner_id) {
                return runner_model_label(runner, model_name);
            }
        }
        return "%s / %s".printf(runner_id, model_name);
    }

    public static AiModelOptions build_model_options(Gee.ArrayList<AiRunnerInfo> runners,
                                                     string? selected_model) {
        var options = new AiModelOptions();
        options.add("(auto)", null);
        foreach (var runner in runners) {
            for (int i = 0; i < runner.runtime.models.size; i++) {
                var model_name = runner.runtime.models[i];
                var ref_text = model_ref(runner.runner_id, model_name);
                options.add(runner_model_label(runner, model_name), ref_text);
                if (selected_model != null && selected_model == ref_text) {
                    options.select_last();
                }
            }
        }
        if (selected_model != null && options.selected_index == 0) {
            options.add("Missing: %s".printf(model_ref_label(selected_model, runners)), selected_model);
            options.select_last();
        }
        return options;
    }

    public static bool models_match(string? a, string? b) {
        if (a == null && b == null) {
            return true;
        }
        if (a == null || b == null) {
            return false;
        }
        return a == b;
    }

    // Whether a change of the three dropdowns needs a save scheduled: skip when nothing differs
    // from the stored preference, or when the very same selection is already being saved.
    public static bool local_model_save_needed(AiLocalModelConfigInfo stored,
                                               string? fast_model,
                                               string? strong_model,
                                               string? deep_model,
                                               bool save_in_flight,
                                               string? pending_fast,
                                               string? pending_strong,
                                               string? pending_deep) {
        if (models_match(stored.fast_model, fast_model)
            && models_match(stored.strong_model, strong_model)
            && models_match(stored.deep_model, deep_model)) {
            return false;
        }
        if (save_in_flight
            && models_match(pending_fast, fast_model)
            && models_match(pending_strong, strong_model)
            && models_match(pending_deep, deep_model)) {
            return false;
        }
        return true;
    }

    public static AiRunnerRowPresentation runner_row(AiRunnerInfo runner, Gee.ArrayList<AiRunnerInfo> runners) {
        var summary_parts = new Gee.ArrayList<string>();
        summary_parts.add(runner.runner_id);
        summary_parts.add(runner.kind);
        summary_parts.add(runner.source);
        summary_parts.add("Enabled: %s".printf(runner.enabled ? "yes" : "no"));
        if (runner.base_url != null && runner.base_url.strip().length > 0) {
            summary_parts.add(runner.base_url);
        }

        var runtime_parts = new Gee.ArrayList<string>();
        runtime_parts.add("Runtime: %s".printf(runner.runtime.available ? "available" : "unavailable"));
        if (runner.runtime.version.strip().length > 0) {
            runtime_parts.add("Version: %s".printf(runner.runtime.version));
        }
        if (runner.runtime.models.size > 0) {
            runtime_parts.add("Models: %d".printf(runner.runtime.models.size));
        }

        return new AiRunnerRowPresentation(
            runner.name,
            join_with(" | ", summary_parts),
            join_with(" | ", runtime_parts),
            runner.runtime.error.strip().length > 0 ? runner.runtime.error : null,
            runner.runtime.models.size > 0
                ? "Installed: %s".printf(join_list(runner.runtime.models))
                : null,
            runner.runtime.pulls.size > 0
                ? "Pulls: %s".printf(format_pulls(runner.runtime.pulls, runners))
                : null,
            runner.source == "manual"
        );
    }

    public static AiProviderRowPresentation provider_row(AiRuntimeProvider provider,
                                                         AiProviderCredentialState? credential,
                                                         AiProviderSettingState? setting) {
        var configured = credential != null && credential.configured;
        var has_saved_preview = credential != null && credential.api_key_preview.strip().length > 0;
        return new AiProviderRowPresentation(
            provider.display_name.strip().length > 0 ? provider.display_name : provider.id,
            "Configured: %s".printf(configured ? "yes" : "no"),
            has_saved_preview
                ? "Saved: %s".printf(credential.api_key_preview)
                : "Paste API key",
            configured,
            setting != null ? setting.enabled : provider.enabled,
            provider.setup_url.strip().length > 0,
            provider.docs_url.strip().length > 0
        );
    }
}

}
