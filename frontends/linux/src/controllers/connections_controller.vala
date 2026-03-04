namespace HolderLinux {

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
