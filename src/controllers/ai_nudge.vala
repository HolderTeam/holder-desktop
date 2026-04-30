namespace HolderLinux {

public class AiNudgeController : Object {
    private MainController owner; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public signal void debug_log_requested(string message);
    public signal void nudges_refresh_requested(string? project_id, string? card_id);

    public AiNudgeController(MainController owner) {
        this.owner = owner;
    }

    public async void evaluate_candidate(NudgeCandidate candidate) {
        var api = owner.get_api_client();
        if (api == null) {
            return;
        }
        log_candidate(candidate);
        try {
            var result = yield api.evaluate_nudge_candidate(
                candidate.kind,
                candidate.project_id,
                candidate.card_id,
                candidate.created_at,
                candidate.facts,
                candidate.basis_fingerprint,
                candidate.basis_commit
            );
            debug_log_requested(
                "NUDGE_EVAL %s accepted=%s should_nudge=%s reason=%s".printf(
                    result.kind,
                    result.accepted ? "true" : "false",
                    result.should_nudge ? "true" : "false",
                    result.reason
                )
            );
            if (result.nudge != null) {
                nudges_refresh_requested(candidate.project_id, candidate.card_id);
            }
        } catch (Error e) {
            debug_log_requested("NUDGE_EVAL_ERROR %s %s".printf(candidate.kind, e.message));
        }
    }

    public async void evaluate_title_suggestion_for_current_card() {
        var candidate = build_title_suggestion_candidate_for_current_card();
        if (candidate == null) {
            return;
        }
        yield evaluate_candidate((!) candidate);
    }

    public async void apply_title_suggestion(string nudge_id, string card_id, string title_text) {
        var api = owner.get_api_client();
        var card = owner.get_current_card();
        var title = title_text.strip();
        if (api == null || card == null || card.card_id != card_id || title.length == 0) {
            debug_log_requested("TITLE_SUGGESTION_APPLY_SKIPPED stale_or_missing_context");
            return;
        }

        var updated_content = replace_card_title_line(card.content, title);
        var updated_at = owner.now_epoch_seconds();
        try {
            yield api.update_card(card_id, title, updated_content, updated_at);
            card.title = title;
            card.content = updated_content;
            card.updated_at = updated_at;
            owner.set_loaded_card_editor_state(card);
            owner.update_selected_card_summary(title, updated_at);
            owner.window_title_changed(title);
            owner.editor_save_state_changed("Saved");
            yield api.dismiss_ai_nudge(nudge_id);
            nudges_refresh_requested(owner.selected_project_id(), owner.selected_card_id());
            owner.emit_activity(
                "result.card.title_suggestion_apply",
                "Applied title suggestion: %s".printf(title),
                card.project_id,
                card.card_id
            );
        } catch (Error e) {
            owner.error_reported("Title suggestion failed", e.message);
            debug_log_requested("TITLE_SUGGESTION_APPLY_ERROR %s".printf(e.message));
        }
    }

    private void log_candidate(NudgeCandidate candidate) {
        var parts = new Gee.ArrayList<string>();
        parts.add("project=%s".printf(candidate.project_id));
        if (candidate.card_id != null && candidate.card_id.strip().length > 0) {
            parts.add("card=%s".printf(candidate.card_id));
        }
        if (candidate.basis_fingerprint != null && candidate.basis_fingerprint.strip().length > 0) {
            parts.add("fingerprint=%s".printf(candidate.basis_fingerprint));
        }
        if (candidate.basis_commit != null && candidate.basis_commit.strip().length > 0) {
            parts.add("commit=%s".printf(candidate.basis_commit));
        }
        var facts_node = new Json.Node(Json.NodeType.OBJECT);
        facts_node.set_object(candidate.facts);
        var generator = new Json.Generator();
        generator.set_root(facts_node);
        var facts_json = generator.to_data(null);
        debug_log_requested(
            "CANDIDATE %s [%s] facts=%s".printf(
                candidate.kind,
                string.joinv(", ", parts.to_array()),
                facts_json
            )
        );
    }

    private NudgeCandidate? build_title_suggestion_candidate_for_current_card() {
        var card = owner.get_current_card();
        if (card == null || owner.get_api_client() == null) {
            return null;
        }
        if (owner.selected_card_id() != card.card_id) {
            return null;
        }
        if (!is_placeholder_title(card.title)) {
            return null;
        }
        var body_text = body_text_from_content(card.content);
        var body_chars = body_text.char_count();
        if (body_text.strip().length == 0 || body_chars < 40) {
            return null;
        }

        var facts = new Json.Object();
        facts.set_string_member("title", card.title);
        facts.set_boolean_member("body_empty", false);
        facts.set_int_member("doc_chars", card.content.char_count());
        facts.set_int_member("body_chars", body_chars);

        return new NudgeCandidate(
            "card.title_suggestion",
            card.project_id,
            card.card_id,
            owner.now_epoch_seconds(),
            facts,
            short_content_fingerprint(card.content),
            null
        );
    }

    private static bool is_placeholder_title(string title) {
        return title.strip().down().has_prefix("untitled");
    }

    private static string body_text_from_content(string content) {
        var newline_index = content.index_of_char('\n');
        if (newline_index < 0 || newline_index + 1 >= content.length) {
            return "";
        }
        return content.substring(newline_index + 1);
    }

    private static string short_content_fingerprint(string content) {
        var digest = Checksum.compute_for_string(ChecksumType.SHA256, content);
        return digest.substring(0, 12);
    }

    private static string replace_card_title_line(string content, string title) {
        var lines = content.split("\n");
        for (int i = 0; i < lines.length; i++) {
            var line = lines[i].strip();
            if (line.length == 0) {
                continue;
            }
            if (line.has_prefix("#")) {
                lines[i] = "# %s".printf(title);
                return string.joinv("\n", lines);
            }
            break;
        }
        return "# %s\n\n%s".printf(title, content);
    }
}

}
