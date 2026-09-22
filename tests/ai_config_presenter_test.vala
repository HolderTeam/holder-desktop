using GLib;

namespace HolderLinuxTests {

private string join_parts(string separator, Gee.List<string> parts) {
    var joined = new StringBuilder();
    bool first = true;
    foreach (var part in parts) {
        if (!first) {
            joined.append(separator);
        }
        joined.append(part);
        first = false;
    }
    return joined.str;
}

// ---- Verbatim copies of the logic ai_panel/config.vala used to carry inline ----

private string original_join_list(Gee.ArrayList<string> values) {
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

private string original_runner_model_label(HolderLinux.AiRunnerInfo runner, string model_name) {
    var runner_label = runner.name.strip();
    if (runner_label.length == 0) {
        runner_label = runner.runner_id;
    }
    return "%s / %s".printf(runner_label, model_name);
}

private string original_model_ref_label(string model_ref, Gee.ArrayList<HolderLinux.AiRunnerInfo> runners_cache) {
    var separator = model_ref.index_of("::");
    if (separator < 0) {
        return model_ref;
    }
    var runner_id = model_ref.substring(0, separator);
    var model_name = model_ref.substring(separator + 2);
    foreach (var runner in runners_cache) {
        if (runner.runner_id == runner_id) {
            return original_runner_model_label(runner, model_name);
        }
    }
    return "%s / %s".printf(runner_id, model_name);
}

private string original_pull_target_label(HolderLinux.AiRunnerPullInfo pull,
                                          Gee.ArrayList<HolderLinux.AiRunnerInfo> runners_cache) {
    if (pull.runner_id.strip().length == 0) {
        return pull.model;
    }
    return original_model_ref_label("%s::%s".printf(pull.runner_id, pull.model), runners_cache);
}

private string original_format_status_pull_jobs(Gee.ArrayList<HolderLinux.AiRunnerPullInfo> pulls,
                                                Gee.ArrayList<HolderLinux.AiRunnerInfo> runners_cache) {
    if (pulls.size == 0) {
        return "none";
    }
    var pull_parts = new Gee.ArrayList<string>();
    foreach (var pull in pulls) {
        var target = original_pull_target_label(pull, runners_cache);
        pull_parts.add("%s (%s, %.1f%%)".printf(target, pull.status, pull.percent));
    }
    return original_join_list(pull_parts);
}

// populate_local_model_dropdown(): note the values list is shared by all three dropdowns.
private void original_populate(Gee.ArrayList<HolderLinux.AiRunnerInfo> runners_cache,
                               string? selected_model,
                               Gee.ArrayList<string?> local_model_option_values,
                               Gee.ArrayList<string> labels,
                               out uint selected_index,
                               out bool sensitive) {
    labels.clear();
    local_model_option_values.clear();

    labels.add("(auto)");
    local_model_option_values.add(null);
    selected_index = 0;
    foreach (var runner in runners_cache) {
        for (int i = 0; i < runner.runtime.models.size; i++) {
            var model_name = runner.runtime.models[i];
            var model_ref = "%s::%s".printf(runner.runner_id, model_name);
            labels.add(original_runner_model_label(runner, model_name));
            local_model_option_values.add(model_ref);
            if (selected_model != null && selected_model == model_ref) {
                selected_index = local_model_option_values.size - 1;
            }
        }
    }
    if (selected_model != null && selected_index == 0) {
        labels.add("Missing: %s".printf(original_model_ref_label(selected_model, runners_cache)));
        local_model_option_values.add(selected_model);
        selected_index = local_model_option_values.size - 1;
    }
    sensitive = local_model_option_values.size > 1;
}

private string? original_selected_model(Gee.ArrayList<string?> local_model_option_values, uint selected) {
    if (selected == 0 || selected >= local_model_option_values.size) {
        return null;
    }
    return local_model_option_values[(int) selected];
}

private bool original_models_match(string? a, string? b) {
    if (a == null && b == null) {
        return true;
    }
    if (a == null || b == null) {
        return false;
    }
    return a == b;
}

// The two early returns of schedule_local_model_save() that depend on selection state.
private bool original_save_needed(HolderLinux.AiLocalModelConfigInfo local_model_config,
                                  string? fast_model, string? strong_model, string? deep_model,
                                  bool in_flight, string? pf, string? ps, string? pd) {
    if (original_models_match(local_model_config.fast_model, fast_model) &&
        original_models_match(local_model_config.strong_model, strong_model) &&
        original_models_match(local_model_config.deep_model, deep_model)) {
        return false;
    }
    if (in_flight &&
        original_models_match(pf, fast_model) &&
        original_models_match(ps, strong_model) &&
        original_models_match(pd, deep_model)) {
        return false;
    }
    return true;
}

// ---- Fixtures ----

private HolderLinux.AiRunnerPullInfo make_pull(string runner_id, string model, string status, double percent) {
    return new HolderLinux.AiRunnerPullInfo("job", runner_id, model, status, percent, "download");
}

private Gee.ArrayList<string> strings(string a = "", string b = "", string c = "") {
    var list = new Gee.ArrayList<string>();
    if (a != "") list.add(a);
    if (b != "") list.add(b);
    if (c != "") list.add(c);
    return list;
}

private HolderLinux.AiRunnerInfo make_runner(string runner_id, string name, Gee.ArrayList<string> models,
                                             string? base_url = "http://host:11434", string source = "manual",
                                             bool enabled = true, bool available = true, string version = "0.5",
                                             string error = "",
                                             Gee.ArrayList<HolderLinux.AiRunnerPullInfo>? pulls = null) {
    return new HolderLinux.AiRunnerInfo(
        runner_id, name, "ollama", base_url, source, enabled, 1, 2,
        new HolderLinux.AiRunnerRuntimeInfo(
            true, available, false, 3, version, error, models,
            pulls ?? new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>()
        )
    );
}

private Gee.ArrayList<HolderLinux.AiRunnerInfo> fixture_runners() {
    var runners = new Gee.ArrayList<HolderLinux.AiRunnerInfo>();
    runners.add(make_runner("r1", "Workstation", strings("llama3", "qwen")));
    runners.add(make_runner("r2", "   ", strings("phi")));
    runners.add(make_runner("r3", "Empty", new Gee.ArrayList<string>()));
    return runners;
}

// ---- Tests ----

private void test_join_and_label_helpers_match_the_original() {
    assert(HolderLinux.AiConfigPresenter.join_list(new Gee.ArrayList<string>()) == "none");
    assert(HolderLinux.AiConfigPresenter.join_list(strings("a")) == "a");
    assert(HolderLinux.AiConfigPresenter.join_list(strings("a", "b", "c")) == original_join_list(strings("a", "b", "c")));

    var runners = fixture_runners();
    assert(HolderLinux.AiConfigPresenter.model_ref("r1", "llama3") == "r1::llama3");
    assert(HolderLinux.AiConfigPresenter.runner_model_label(runners[0], "llama3") == "Workstation / llama3");
    assert(HolderLinux.AiConfigPresenter.runner_model_label(runners[1], "phi") == "r2 / phi");

    string[] refs = { "r1::llama3", "r2::phi", "gone::x", "no-separator", "r1::", "::model", "a::b::c" };
    for (int i = 0; i < refs.length; i++) {
        assert(HolderLinux.AiConfigPresenter.model_ref_label(refs[i], runners)
               == original_model_ref_label(refs[i], runners));
    }
    assert(HolderLinux.AiConfigPresenter.model_ref_label("gone::x", runners) == "gone / x");
    assert(HolderLinux.AiConfigPresenter.model_ref_label("no-separator", runners) == "no-separator");
}

private void test_pull_formatting_matches_the_original() {
    var runners = fixture_runners();
    var pulls = new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>();
    assert(HolderLinux.AiConfigPresenter.format_pulls(pulls, runners) == "none");
    assert(HolderLinux.AiConfigPresenter.pull_jobs_summary(pulls, runners) == "Pull jobs: none");

    pulls.add(make_pull("r1", "llama3", "downloading", 42.55));
    pulls.add(make_pull("", "bare-model", "queued", 0.0));
    pulls.add(make_pull("ghost", "m", "done", 100.0));
    assert(HolderLinux.AiConfigPresenter.format_pulls(pulls, runners)
           == original_format_status_pull_jobs(pulls, runners));
    assert(HolderLinux.AiConfigPresenter.pull_jobs_summary(pulls, runners)
           == "Pull jobs: %s".printf(original_format_status_pull_jobs(pulls, runners)));
    assert(HolderLinux.AiConfigPresenter.pull_target_label(pulls[1], runners) == "bare-model");
    assert(HolderLinux.AiConfigPresenter.pull_target_label(pulls[0], runners) == "Workstation / llama3");
}

private void test_runtime_and_activity_summaries_match_the_original() {
    for (int available = 0; available < 2; available++) {
        for (int caste = 0; caste < 2; caste++) {
            for (int version = 0; version < 2; version++) {
                for (int error = 0; error < 2; error++) {
                    var capabilities = new HolderLinux.AiCapabilitiesInfo(
                        available == 1, error == 1 ? "spawn failed" : "  ", 0,
                        version == 1 ? "0.5.1" : "", caste == 1 ? "ollama" : " ",
                        new Gee.ArrayList<string>(), new Gee.ArrayList<string>()
                    );
                    // Original: parts joined by " | ", then the error appended after a newline.
                    var parts = new Gee.ArrayList<string>();
                    parts.add("Runtime: %s".printf(capabilities.runner_available ? "available" : "unavailable"));
                    if (capabilities.caste_name.strip().length > 0) {
                        parts.add("Engine: %s".printf(capabilities.caste_name));
                    }
                    if (capabilities.runner_version.strip().length > 0) {
                        parts.add("Version: %s".printf(capabilities.runner_version));
                    }
                    var expected = join_parts(" | ", parts);
                    if (capabilities.runner_error.strip().length > 0) {
                        expected = "%s\n%s".printf(expected, capabilities.runner_error);
                    }
                    assert(HolderLinux.AiConfigPresenter.runtime_summary(capabilities) == expected);
                }
            }
        }
    }

    assert(HolderLinux.AiConfigPresenter.recommended_installs_text(new Gee.ArrayList<string>())
           == "Recommended installs: none");
    assert(HolderLinux.AiConfigPresenter.recommended_installs_text(strings("a", "b"))
           == "Recommended installs: a, b");

    var status = new HolderLinux.AiStatusInfo(0, true, "", 2, 1, 3, new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>());
    assert(HolderLinux.AiConfigPresenter.activity_summary(status)
           == "Active runs: 2 | Active pulls: 1 | Cloud providers configured: 3");
}

private void test_model_options_match_the_original_populate() {
    var runners = fixture_runners();
    string?[] selections = { null, "r1::llama3", "r1::qwen", "r2::phi", "gone::x", "r2::nope", "bare" };
    for (int i = 0; i < selections.length; i++) {
        var shared = new Gee.ArrayList<string?>();
        var labels = new Gee.ArrayList<string>();
        uint expected_index;
        bool expected_sensitive;
        original_populate(runners, selections[i], shared, labels, out expected_index, out expected_sensitive);

        var options = HolderLinux.AiConfigPresenter.build_model_options(runners, selections[i]);
        assert(options.labels.size == labels.size);
        for (int l = 0; l < labels.size; l++) {
            assert(options.labels[l] == labels[l]);
        }
        assert(options.selected_index == expected_index);
        assert(options.has_choices == expected_sensitive);
        for (uint p = 0; p < labels.size + 2; p++) {
            assert(options.value_at(p) == original_selected_model(shared, p));
        }
    }

    // No runners and nothing saved: only "(auto)", insensitive.
    var empty = HolderLinux.AiConfigPresenter.build_model_options(new Gee.ArrayList<HolderLinux.AiRunnerInfo>(), null);
    assert(empty.labels.size == 1);
    assert(!empty.has_choices);
    assert(empty.value_at(0) == null);
    // A saved preference with no runners still offers its "Missing:" entry.
    var missing_only = HolderLinux.AiConfigPresenter.build_model_options(new Gee.ArrayList<HolderLinux.AiRunnerInfo>(), "gone::x");
    assert(missing_only.labels[1] == "Missing: gone / x");
    assert(missing_only.selected_index == 1);
    assert(missing_only.has_choices);
}

// The original kept ONE values list for all three dropdowns and rebuilt it per dropdown, so it only
// ever described the last (deep) one. A "Missing:" entry on the fast or strong dropdown therefore
// resolved to null, and a save silently reset that preference to (auto).
private void test_a_missing_model_on_an_earlier_dropdown_is_kept() {
    var runners = fixture_runners();
    var shared = new Gee.ArrayList<string?>();
    var labels = new Gee.ArrayList<string>();
    uint fast_index, strong_index, deep_index;
    bool sensitive;
    original_populate(runners, "gone::x", shared, labels, out fast_index, out sensitive);
    original_populate(runners, null, shared, labels, out strong_index, out sensitive);
    original_populate(runners, null, shared, labels, out deep_index, out sensitive);

    // Original behaviour: the fast dropdown shows "Missing: ..." but its value is lost.
    assert(fast_index == 4);
    assert(original_selected_model(shared, fast_index) == null);

    var fast = HolderLinux.AiConfigPresenter.build_model_options(runners, "gone::x");
    assert(fast.selected_index == 4);
    assert(fast.value_at(fast.selected_index) == "gone::x");

    // Two different missing preferences no longer resolve to each other's value.
    var strong = HolderLinux.AiConfigPresenter.build_model_options(runners, "other::y");
    assert(strong.value_at(strong.selected_index) == "other::y");
    assert(fast.value_at(fast.selected_index) == "gone::x");
}

private void test_save_decision_matches_the_original_for_every_combination() {
    string?[] domain = { null, "a", "b" };
    int compared = 0;
    for (int s1 = 0; s1 < 3; s1++) for (int s2 = 0; s2 < 3; s2++) for (int s3 = 0; s3 < 3; s3++) {
        var stored = new HolderLinux.AiLocalModelConfigInfo(domain[s1], domain[s2], domain[s3], 0);
        for (int f = 0; f < 3; f++) for (int g = 0; g < 3; g++) for (int h = 0; h < 3; h++) {
            for (int flight = 0; flight < 2; flight++) {
                for (int p1 = 0; p1 < 3; p1++) for (int p2 = 0; p2 < 3; p2++) for (int p3 = 0; p3 < 3; p3++) {
                    assert(
                        HolderLinux.AiConfigPresenter.local_model_save_needed(
                            stored, domain[f], domain[g], domain[h], flight == 1, domain[p1], domain[p2], domain[p3]
                        ) == original_save_needed(
                            stored, domain[f], domain[g], domain[h], flight == 1, domain[p1], domain[p2], domain[p3]
                        )
                    );
                    compared++;
                }
            }
        }
    }
    assert(compared == 27 * 27 * 2 * 27);
    assert(HolderLinux.AiConfigPresenter.models_match(null, null));
    assert(!HolderLinux.AiConfigPresenter.models_match(null, "a"));
    assert(!HolderLinux.AiConfigPresenter.models_match("a", null));
    assert(HolderLinux.AiConfigPresenter.models_match("a", "a"));
    assert(HolderLinux.AiConfigPresenter.LOCAL_MODEL_SAVE_DELAY_MS == 500);
}

private void test_runner_row_matches_the_original_composition() {
    var runners = fixture_runners();
    string?[] urls = { null, "   ", "http://x:1" };
    for (int u = 0; u < 3; u++) for (int src = 0; src < 2; src++) for (int en = 0; en < 2; en++)
    for (int av = 0; av < 2; av++) for (int ver = 0; ver < 2; ver++) for (int mod = 0; mod < 2; mod++)
    for (int err = 0; err < 2; err++) for (int pl = 0; pl < 2; pl++) {
        var pulls = new Gee.ArrayList<HolderLinux.AiRunnerPullInfo>();
        if (pl == 1) {
            pulls.add(make_pull("r1", "llama3", "downloading", 12.34));
            pulls.add(make_pull("", "bare", "queued", 0.0));
        }
        var runner = make_runner(
            "rx", "Runner X", mod == 1 ? strings("m1", "m2") : new Gee.ArrayList<string>(),
            urls[u], src == 0 ? "manual" : "discovered", en == 1, av == 1,
            ver == 1 ? "1.2" : "  ", err == 1 ? "boom" : " ", pulls
        );

        var summary_parts = new Gee.ArrayList<string>();
        summary_parts.add("%s".printf(runner.runner_id));
        summary_parts.add("%s".printf(runner.kind));
        summary_parts.add("%s".printf(runner.source));
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
        var pull_parts = new Gee.ArrayList<string>();
        foreach (var pull in runner.runtime.pulls) {
            pull_parts.add("%s (%s, %.1f%%)".printf(
                original_pull_target_label(pull, runners), pull.status, pull.percent
            ));
        }

        var row = HolderLinux.AiConfigPresenter.runner_row(runner, runners);
        assert(row.title == runner.name);
        assert(row.summary == join_parts(" | ", summary_parts));
        assert(row.runtime == join_parts(" | ", runtime_parts));
        assert(row.error == (runner.runtime.error.strip().length > 0 ? runner.runtime.error : null));
        assert(row.installed == (runner.runtime.models.size > 0
            ? "Installed: %s".printf(original_join_list(runner.runtime.models)) : null));
        assert(row.pulls == (runner.runtime.pulls.size > 0
            ? "Pulls: %s".printf(original_join_list(pull_parts)) : null));
        assert(row.is_manual == (runner.source == "manual"));
    }
}

private void test_provider_row_matches_the_original_composition() {
    for (int name = 0; name < 2; name++) for (int cred = 0; cred < 4; cred++)
    for (int set = 0; set < 3; set++) for (int prov_enabled = 0; prov_enabled < 2; prov_enabled++)
    for (int setup = 0; setup < 2; setup++) for (int docs = 0; docs < 2; docs++) {
        var provider = new HolderLinux.AiRuntimeProvider(
            "openai", name == 0 ? "  " : "OpenAI", prov_enabled == 1, false,
            setup == 1 ? "https://setup" : " ", docs == 1 ? "https://docs" : ""
        );
        HolderLinux.AiProviderCredentialState? credential = null;
        if (cred == 1) credential = new HolderLinux.AiProviderCredentialState("openai", false, "", 0);
        if (cred == 2) credential = new HolderLinux.AiProviderCredentialState("openai", true, "sk-...abc", 0);
        if (cred == 3) credential = new HolderLinux.AiProviderCredentialState("openai", true, "   ", 0);
        HolderLinux.AiProviderSettingState? setting = null;
        if (set == 1) setting = new HolderLinux.AiProviderSettingState("openai", true, 0);
        if (set == 2) setting = new HolderLinux.AiProviderSettingState("openai", false, 0);

        var row = HolderLinux.AiConfigPresenter.provider_row(provider, credential, setting);
        assert(row.title == (provider.display_name.strip().length > 0 ? provider.display_name : provider.id));
        assert(row.configured_text == "Configured: %s".printf((credential != null && credential.configured) ? "yes" : "no"));
        string expected_placeholder;
        if (credential != null && credential.api_key_preview.strip().length > 0) {
            expected_placeholder = "Saved: %s".printf(credential.api_key_preview);
        } else {
            expected_placeholder = "Paste API key";
        }
        assert(row.key_placeholder == expected_placeholder);
        assert(row.can_remove_key == (credential != null && credential.configured));
        assert(row.enabled == (setting != null ? setting.enabled : provider.enabled));
        assert(row.setup_available == (provider.setup_url.strip().length > 0));
        assert(row.docs_available == (provider.docs_url.strip().length > 0));
    }
}

private void test_drafts_trim_and_validate() {
    var good = new HolderLinux.AiRunnerDraft("  Lab  ", "  http://lab:11434 ");
    assert(good.valid);
    assert(good.name == "Lab");
    assert(good.base_url == "http://lab:11434");
    assert(good.error_message == null);

    string[] blanks = { "", "   ", "\t\n" };
    for (int i = 0; i < blanks.length; i++) {
        var no_name = new HolderLinux.AiRunnerDraft(blanks[i], "http://x");
        var no_url = new HolderLinux.AiRunnerDraft("Lab", blanks[i]);
        assert(!no_name.valid && !no_url.valid);
        assert(no_name.error_message == "Runner name and base URL are required.");
        assert(no_url.error_message == HolderLinux.AiRunnerDraft.REQUIRED_MESSAGE);
    }

    var key = new HolderLinux.AiProviderKeyDraft("  sk-secret \n");
    assert(key.valid);
    assert(key.key == "sk-secret");
    assert(key.error_message == null);
    for (int i = 0; i < blanks.length; i++) {
        var empty = new HolderLinux.AiProviderKeyDraft(blanks[i]);
        assert(!empty.valid);
        assert(empty.error_message == "API key cannot be empty.");
    }
}

private void test_status_messages_are_unchanged() {
    assert(HolderLinux.AiConfigPresenter.CONNECT_MESSAGE == "Connect to holderd to configure AI.");
    assert(HolderLinux.AiConfigPresenter.LOADING_MESSAGE == "Loading AI config...");
    assert(HolderLinux.AiConfigPresenter.LOAD_FAILED_MESSAGE == "Failed to load AI config.");
    assert(HolderLinux.AiConfigPresenter.READY_MESSAGE
           == "Configure model runners, local model preferences, and cloud providers.");
    assert(HolderLinux.AiConfigPresenter.LOCAL_RUNTIME_UNAVAILABLE == "Local runtime unavailable");
    assert(HolderLinux.AiConfigPresenter.NO_RECOMMENDED_INSTALLS_HINT
           == "No local model installs recommended right now.");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/ai-config-presenter/labels", test_join_and_label_helpers_match_the_original);
    Test.add_func("/holder/ai-config-presenter/pulls", test_pull_formatting_matches_the_original);
    Test.add_func("/holder/ai-config-presenter/summaries", test_runtime_and_activity_summaries_match_the_original);
    Test.add_func("/holder/ai-config-presenter/model-options", test_model_options_match_the_original_populate);
    Test.add_func("/holder/ai-config-presenter/missing-model-on-earlier-dropdown",
                  test_a_missing_model_on_an_earlier_dropdown_is_kept);
    Test.add_func("/holder/ai-config-presenter/save-decision", test_save_decision_matches_the_original_for_every_combination);
    Test.add_func("/holder/ai-config-presenter/runner-row", test_runner_row_matches_the_original_composition);
    Test.add_func("/holder/ai-config-presenter/provider-row", test_provider_row_matches_the_original_composition);
    Test.add_func("/holder/ai-config-presenter/drafts", test_drafts_trim_and_validate);
    Test.add_func("/holder/ai-config-presenter/messages", test_status_messages_are_unchanged);
    return Test.run();
}

}
