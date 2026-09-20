namespace HolderLinux {

// One relations-panel section: Pango markup for display plus the plain text used as the
// accessible label.
public class ConnectionsRelationsText : Object {
    public string markup { get; construct; }
    public string plain { get; construct; }

    public ConnectionsRelationsText(string markup, string plain) {
        Object(markup: markup, plain: plain);
    }
}

public class ConnectionsRelationsPresentation : Object {
    public ConnectionsRelationsText structure { get; construct; }
    public ConnectionsRelationsText outgoing { get; construct; }
    public ConnectionsRelationsText backlinks { get; construct; }
    public ConnectionsRelationsText internal_links { get; construct; }
    public bool sections_visible { get; construct; }

    public ConnectionsRelationsPresentation(ConnectionsRelationsText structure,
                                            ConnectionsRelationsText outgoing,
                                            ConnectionsRelationsText backlinks,
                                            ConnectionsRelationsText internal_links,
                                            bool sections_visible) {
        Object(
            structure: structure,
            outgoing: outgoing,
            backlinks: backlinks,
            internal_links: internal_links,
            sections_visible: sections_visible
        );
    }
}

public class ConnectionsRelationsPresenter : Object {
    private ConnectionsController controller;

    public ConnectionsRelationsPresenter(ConnectionsController controller) {
        this.controller = controller;
    }

    public ConnectionsRelationsPresentation overview(string text) {
        return new ConnectionsRelationsPresentation(
            new ConnectionsRelationsText(Markup.escape_text(text), text),
            new ConnectionsRelationsText("None", "None"),
            new ConnectionsRelationsText("None", "None"),
            new ConnectionsRelationsText("None", "None"),
            false
        );
    }

    public ConnectionsRelationsPresentation for_card(Project project,
                                                     CardSummary selected_card,
                                                     Gee.ArrayList<CardLink> outgoing,
                                                     Gee.ArrayList<CardLink> backlinks,
                                                     Gee.ArrayList<string> internal_links,
                                                     Gee.ArrayList<CardSummary> cards) {
        return new ConnectionsRelationsPresentation(
            text_for(controller.compact_structure_markup(project, selected_card, cards)),
            text_for(format_link_lines(outgoing, true, cards)),
            text_for(format_link_lines(backlinks, false, cards)),
            text_for(format_internal_lines(internal_links, project.project_id, cards)),
            true
        );
    }

    private static ConnectionsRelationsText text_for(string markup) {
        return new ConnectionsRelationsText(markup, plain_text_from_markup(markup));
    }

    public static string plain_text_from_markup(string markup) {
        var text = new StringBuilder();
        bool in_tag = false;
        for (int i = 0; i < markup.length; i++) {
            char c = markup[i];
            if (c == '<') {
                in_tag = true;
                continue;
            }
            if (c == '>') {
                in_tag = false;
                continue;
            }
            if (!in_tag) {
                text.append_c(c);
            }
        }
        return text.str
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&amp;", "&")
            .replace("&quot;", "\"")
            .replace("&apos;", "'");
    }

    public string format_link_lines(Gee.ArrayList<CardLink> links,
                                    bool outgoing,
                                    Gee.ArrayList<CardSummary> cards) {
        if (links.size == 0) {
            return "None";
        }
        var groups = controller.group_links_by_kind(links);
        var lines = new Gee.ArrayList<string>();
        foreach (var group in groups) {
            var targets = new Gee.ArrayList<string>();
            foreach (var link in group.links) {
                var target_id = outgoing ? link.to_card_id : link.from_card_id;
                if ((outgoing ? link.to_type : "card") == "card") {
                    targets.add(controller.link_markup("card", target_id, controller.title_for_card_id(target_id, cards)));
                } else {
                    targets.add(Markup.escape_text(target_id));
                }
            }
            lines.add("%s: %s".printf(Markup.escape_text(group.kind), string.joinv(", ", targets.to_array())));
        }
        return string.joinv("\n", lines.to_array());
    }

    public string format_internal_lines(Gee.ArrayList<string> internal_links,
                                        string project_id,
                                        Gee.ArrayList<CardSummary> cards) {
        if (internal_links.size == 0) {
            return "None";
        }
        var links = new Gee.ArrayList<string>();
        foreach (var target in internal_links) {
            var card_id = controller.resolve_internal_link_target_card_id(target, project_id, cards);
            if (card_id != null) {
                links.add(controller.link_markup("card", card_id, controller.title_for_card_id(card_id, cards)));
            } else {
                links.add(Markup.escape_text(target));
            }
        }
        return string.joinv("\n", links.to_array());
    }
}

}
