namespace HolderLinux {

public class GraphLinkTargetOption : Object {
    public string card_id { get; construct; }
    public string display_text { get; construct; }

    public GraphLinkTargetOption(string card_id, string display_text) {
        Object(card_id: card_id, display_text: display_text);
    }
}

public class ConnectionsLinkAction : Object {
    public bool handled { get; construct; }
    public bool select_card { get; construct; }
    public bool select_project { get; construct; }
    public string target_id { get; construct; }

    public ConnectionsLinkAction(bool handled,
                                 bool select_card = false,
                                 bool select_project = false,
                                 string target_id = "") {
        Object(
            handled: handled,
            select_card: select_card,
            select_project: select_project,
            target_id: target_id
        );
    }
}

public class ConnectionsLinkKindGroup : Object {
    public string kind { get; construct; }
    public Gee.ArrayList<CardLink> links { get; construct; }

    public ConnectionsLinkKindGroup(string kind, Gee.ArrayList<CardLink> links) {
        Object(kind: kind, links: links);
    }
}

public class ConnectionsGraphLoadResult : Object {
    public bool success { get; construct; }
    public Gee.ArrayList<CardLink>? outgoing { get; construct; }
    public Gee.ArrayList<CardLink>? backlinks { get; construct; }
    public string outgoing_empty_text { get; construct; }
    public string backlinks_empty_text { get; construct; }
    public string debug_message { get; construct; }

    public ConnectionsGraphLoadResult(bool success,
                                      Gee.ArrayList<CardLink>? outgoing = null,
                                      Gee.ArrayList<CardLink>? backlinks = null,
                                      string outgoing_empty_text = "",
                                      string backlinks_empty_text = "",
                                      string debug_message = "") {
        Object(
            success: success,
            outgoing: outgoing,
            backlinks: backlinks,
            outgoing_empty_text: outgoing_empty_text,
            backlinks_empty_text: backlinks_empty_text,
            debug_message: debug_message
        );
    }
}

public class ConnectionsMutationResult : Object {
    public bool success { get; construct; }
    public bool ignored { get; construct; }
    public string toast_message { get; construct; }
    public string error_title { get; construct; }
    public string error_details { get; construct; }
    public bool should_refresh { get; construct; }

    public ConnectionsMutationResult(bool success,
                                     bool ignored = false,
                                     string toast_message = "",
                                     string error_title = "",
                                     string error_details = "",
                                     bool should_refresh = false) {
        Object(
            success: success,
            ignored: ignored,
            toast_message: toast_message,
            error_title: error_title,
            error_details: error_details,
            should_refresh: should_refresh
        );
    }
}

public class ConnectionsController : Object {
    internal static int ellipsize_cutoff_override_for_tests = int.MIN;

    private string? normalize_parent(string? parent_card_id) {
        if (parent_card_id == null) {
            return null;
        }
        var trimmed = parent_card_id.strip();
        return trimmed.length == 0 ? null : trimmed;
    }

    private int compare_sibling_order(CardSummary a, CardSummary b) {
        if (a.sort_key < b.sort_key) {
            return -1;
        }
        if (a.sort_key > b.sort_key) {
            return 1;
        }
        if (a.updated_at > b.updated_at) {
            return -1;
        }
        if (a.updated_at < b.updated_at) {
            return 1;
        }
        return strcmp(a.title.down(), b.title.down());
    }

    public string ellipsize_title(string? title) {
        if (title == null) {
            return "";
        }
        if (title.char_count() < 47) {
            return title;
        }
        int cutoff = ellipsize_cutoff_override_for_tests;
        if (cutoff == int.MIN) {
            cutoff = title.index_of_nth_char(44);
        }
        if (cutoff < 0) {
            return title;
        }
        return title.substring(0, cutoff) + "...";
    }

    public Gee.ArrayList<string> list_available_link_kinds(Settings? settings) {
        var values = new Gee.ArrayList<string>();
        values.add("ref");
        values.add("depends_on");
        values.add("example_of");
        values.add("blocks");
        values.add("related_to");

        if (settings == null) {
            return values;
        }

        foreach (var kind in settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS)) {
            var cleaned = kind.strip();
            if (cleaned.length == 0 || cleaned == "custom" || values.contains(cleaned)) {
                continue;
            }
            values.add(cleaned);
        }
        return values;
    }

    public void remember_custom_link_kind(Settings? settings, string kind) {
        if (settings == null) {
            return;
        }
        var cleaned = kind.strip();
        if (cleaned.length == 0 || cleaned == "custom") {
            return;
        }

        var defaults = new Gee.HashSet<string>();
        defaults.add("ref");
        defaults.add("depends_on");
        defaults.add("example_of");
        defaults.add("blocks");
        defaults.add("related_to");
        if (defaults.contains(cleaned)) {
            return;
        }

        var custom = new Gee.ArrayList<string>();
        foreach (var existing in settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS)) {
            var item = existing.strip();
            if (item.length == 0 || item == "custom" || defaults.contains(item) || custom.contains(item)) {
                continue;
            }
            custom.add(item);
        }
        if (custom.contains(cleaned)) {
            return;
        }

        custom.add(cleaned);
        while (custom.size > 20) {
            custom.remove_at(0);
        }

        string[] stored = new string[custom.size];
        for (int i = 0; i < custom.size; i++) {
            stored[i] = custom[i];
        }
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, stored);
    }

    public async ConnectionsGraphLoadResult load_graph_links(IHolderApi? api, CardSummary? selected_card) {
        if (api == null) {
            return new ConnectionsGraphLoadResult(
                false,
                null,
                null,
                "API unavailable.",
                "API unavailable."
            );
        }
        if (selected_card == null) {
            return new ConnectionsGraphLoadResult(
                false,
                null,
                null,
                "Select a card to view graph links.",
                "Select a card to view graph links."
            );
        }
        try {
            var outgoing = yield api.list_card_links(selected_card.card_id);
            var backlinks = yield api.list_card_backlinks(selected_card.card_id);
            return new ConnectionsGraphLoadResult(true, outgoing, backlinks);
        } catch (Error e) {
            return new ConnectionsGraphLoadResult(
                false,
                null,
                null,
                "Failed to load outgoing links.",
                "Failed to load backlinks.",
                "Graph links refresh failed: %s".printf(e.message)
            );
        }
    }

    public async ConnectionsMutationResult update_graph_link_flow(IHolderApi? api,
                                                                  CardLink old_link,
                                                                  string new_kind,
                                                                  string? new_label,
                                                                  bool remember_kind,
                                                                  Settings? settings) {
        if (api == null) {
            return new ConnectionsMutationResult(false, true);
        }
        try {
            var kind_changed = old_link.kind != new_kind;
            if (kind_changed) {
                yield api.create_card_link(old_link.from_card_id, old_link.to_card_id, new_kind, new_label, old_link.to_type);
                yield api.delete_card_link(old_link.from_card_id, old_link.to_card_id, old_link.kind, old_link.to_type);
            } else {
                yield api.create_card_link(old_link.from_card_id, old_link.to_card_id, new_kind, new_label, old_link.to_type);
            }
            if (remember_kind) {
                remember_custom_link_kind(settings, new_kind);
            }
            return new ConnectionsMutationResult(true, false, "Graph link updated.", "", "", true);
        } catch (Error e) {
            return new ConnectionsMutationResult(
                false,
                false,
                "",
                "Failed to edit graph link",
                e.message
            );
        }
    }

    public async ConnectionsMutationResult delete_graph_link_flow(IHolderApi? api, CardLink link) {
        if (api == null) {
            return new ConnectionsMutationResult(false, true);
        }
        try {
            yield api.delete_card_link(link.from_card_id, link.to_card_id, link.kind, link.to_type);
            return new ConnectionsMutationResult(true, false, "Graph link deleted.", "", "", true);
        } catch (Error e) {
            return new ConnectionsMutationResult(
                false,
                false,
                "",
                "Failed to delete graph link",
                e.message
            );
        }
    }

    public bool has_graph_link_targets(CardSummary? selected_card,
                                       Gee.List<CardSummary> cards) {
        if (selected_card == null) {
            return false;
        }
        foreach (var card in cards) {
            if (card.project_id != selected_card.project_id) {
                continue;
            }
            if (card.card_id != selected_card.card_id) {
                return true;
            }
        }
        return false;
    }

    public Gee.ArrayList<GraphLinkTargetOption> build_graph_link_target_options(CardSummary? selected_card,
                                                                                 Gee.List<CardSummary> cards) {
        var options = new Gee.ArrayList<GraphLinkTargetOption>();
        if (selected_card == null) {
            return options;
        }
        foreach (var card in cards) {
            if (card.project_id != selected_card.project_id || card.card_id == selected_card.card_id) {
                continue;
            }
            options.add(new GraphLinkTargetOption(
                card.card_id,
                "%s (%s)".printf(card.title, card.card_id)
            ));
        }
        return options;
    }

    public string title_for_card_id(string card_id, Gee.List<CardSummary> cards) {
        foreach (var card in cards) {
            if (card.card_id == card_id) {
                return card.title;
            }
        }
        return card_id;
    }

    public ConnectionsLinkAction resolve_link_action(string uri,
                                                     string? selected_project_id,
                                                     Gee.List<CardSummary> cards) {
        if (uri == null || uri.length == 0) {
            return new ConnectionsLinkAction(false);
        }

        if (uri.has_prefix("card:")) {
            var encoded = uri.substring("card:".length);
            var card_id = Uri.unescape_string(encoded, null);
            if (card_id != null) {
                return new ConnectionsLinkAction(true, true, false, card_id);
            }
            return new ConnectionsLinkAction(false);
        }

        if (uri.has_prefix("project:")) {
            var encoded = uri.substring("project:".length);
            var project_id = Uri.unescape_string(encoded, null);
            if (project_id != null) {
                return new ConnectionsLinkAction(true, false, true, project_id);
            }
            return new ConnectionsLinkAction(false);
        }

        if (uri.has_prefix("ilink:")) {
            var encoded = uri.substring("ilink:".length);
            var target = Uri.unescape_string(encoded, null);
            if (target != null) {
                var card_id = resolve_internal_link_target_card_id(target, selected_project_id, cards);
                if (card_id != null) {
                    return new ConnectionsLinkAction(true, true, false, card_id);
                }
                return new ConnectionsLinkAction(true);
            }
            return new ConnectionsLinkAction(false);
        }

        return new ConnectionsLinkAction(false);
    }

    public Gee.ArrayList<ConnectionsLinkKindGroup> group_links_by_kind(Gee.ArrayList<CardLink> links) {
        var grouped = new Gee.HashMap<string, Gee.ArrayList<CardLink>>();
        var kind_order = new Gee.ArrayList<string>();
        foreach (var link in links) {
            var kind = (link.kind != null && link.kind.strip().length > 0) ? link.kind.strip() : "ref";
            var bucket = grouped.get(kind);
            if (bucket == null) {
                bucket = new Gee.ArrayList<CardLink>();
                grouped.set(kind, bucket);
                kind_order.add(kind);
            }
            bucket.add(link);
        }

        var out_groups = new Gee.ArrayList<ConnectionsLinkKindGroup>();
        foreach (var kind in kind_order) {
            var bucket = grouped.get(kind);
            if (bucket != null) {
                out_groups.add(new ConnectionsLinkKindGroup(kind, bucket));
            }
        }
        return out_groups;
    }

    public string compact_structure_markup(Project? project,
                                           CardSummary? selected_card,
                                           Gee.List<CardSummary> cards) {
        var lines = new Gee.ArrayList<string>();
        if (project != null) {
            lines.add("Project: %s".printf(link_markup("project", project.project_id, project.name)));
        } else {
            lines.add("Project: None");
        }

        if (selected_card != null) {
            var parent_id = normalize_parent(selected_card.parent_card_id);
            if (parent_id != null) {
                foreach (var maybe_parent in cards) {
                    if (maybe_parent.card_id == parent_id) {
                        lines.add(
                            "Parent: %s".printf(
                                link_markup("card", maybe_parent.card_id, maybe_parent.title)
                            )
                        );
                        break;
                    }
                }
            }
        }

        if (selected_card != null) {
            var siblings = new Gee.ArrayList<CardSummary>();
            var parent_id = normalize_parent(selected_card.parent_card_id);
            foreach (var card in cards) {
                if (card.project_id != selected_card.project_id) {
                    continue;
                }
                if (normalize_parent(card.parent_card_id) == parent_id) {
                    siblings.add(card);
                }
            }
            siblings.sort((a, b) => compare_sibling_order(a, b));

            int selected_index = -1;
            for (int i = 0; i < siblings.size; i++) {
                if (siblings[i].card_id == selected_card.card_id) {
                    selected_index = i;
                    break;
                }
            }

            var sibling_parts = new Gee.ArrayList<string>();
            if (selected_index > 0) {
                sibling_parts.add("Previous: %s".printf(
                    link_markup("card", siblings[selected_index - 1].card_id, siblings[selected_index - 1].title)
                ));
            }
            if (selected_index >= 0 && selected_index < siblings.size - 1) {
                sibling_parts.add("Next: %s".printf(
                    link_markup("card", siblings[selected_index + 1].card_id, siblings[selected_index + 1].title)
                ));
            }
            if (sibling_parts.size > 0) {
                lines.add(string.joinv("   ", sibling_parts.to_array()));
            }

            var children = new Gee.ArrayList<CardSummary>();
            foreach (var card in cards) {
                if (card.project_id != selected_card.project_id) {
                    continue;
                }
                if (normalize_parent(card.parent_card_id) == selected_card.card_id) {
                    children.add(card);
                }
            }
            if (children.size > 0) {
                children.sort((a, b) => compare_sibling_order(a, b));
                var child_links = new StringBuilder();
                for (int i = 0; i < children.size; i++) {
                    if (i > 0) {
                        child_links.append(" ");
                    }
                    child_links.append(link_markup("card", children[i].card_id, children[i].title));
                }
                lines.add("Children: %s".printf(child_links.str));
            }
        }

        return string.joinv("\n", lines.to_array());
    }

    public string? resolve_internal_link_target_card_id(string target,
                                                        string? project_id,
                                                        Gee.List<CardSummary> cards) {
        if (target.length == 0 || project_id == null) {
            return null;
        }

        foreach (var card in cards) {
            if (card.project_id != project_id) {
                continue;
            }
            if (card.card_id == target) {
                return card.card_id;
            }
        }

        foreach (var card in cards) {
            if (card.project_id != project_id) {
                continue;
            }
            if (card.title == target) {
                return card.card_id;
            }
        }

        var lowered_target = target.down();
        foreach (var card in cards) {
            if (card.project_id != project_id) {
                continue;
            }
            if (card.title.down() == lowered_target) {
                return card.card_id;
            }
        }

        return null;
    }

    private string link_markup(string kind, string id, string title) {
        var href = "%s:%s".printf(kind, Uri.escape_string(id, null, false));
        return "<a href=\"%s\">%s</a>".printf(
            Markup.escape_text(href),
            Markup.escape_text(ellipsize_title(title))
        );
    }
}

}
