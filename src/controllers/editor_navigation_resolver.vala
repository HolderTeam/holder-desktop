namespace HolderLinux {

internal enum EditorNavigationKind {
    NONE,
    OPEN_CARD,
    CREATE_PROMPT,
    RESOURCE_PREVIEW,
    SHOW_TAG,
    OPEN_URI
}

internal class EditorNavigationResult : Object {
    public EditorNavigationKind kind { get; construct; }
    // Card id, create-card target, resource id, tag or URI depending on kind.
    public string? payload { get; construct; }
    public string? toast_message { get; construct; }

    public EditorNavigationResult(EditorNavigationKind kind,
                                  string? payload = null,
                                  string? toast_message = null) {
        Object(kind: kind, payload: payload, toast_message: toast_message);
    }
}

// Decides what a Ctrl+click / Ctrl+Enter in the editor should do. The order matters:
// [[internal link]], then resource image, then #tag (only for a saved card), then external URI.
internal class EditorNavigationResolver : Object {
    public const uint KEYVAL_RETURN = 0xff0d;
    public const uint KEYVAL_KP_ENTER = 0xff8d;

    private InternalLinkController internal_link_controller;
    private TagNavigationController tag_navigation_controller;
    private MarkdownLinkController markdown_link_controller;
    private MarkdownResourceImageController resource_image_controller;

    public EditorNavigationResolver(InternalLinkController internal_link_controller,
                                    TagNavigationController tag_navigation_controller,
                                    MarkdownLinkController markdown_link_controller,
                                    MarkdownResourceImageController resource_image_controller) {
        this.internal_link_controller = internal_link_controller;
        this.tag_navigation_controller = tag_navigation_controller;
        this.markdown_link_controller = markdown_link_controller;
        this.resource_image_controller = resource_image_controller;
    }

    public static bool is_navigation_click(int n_press, bool ctrl_held) {
        return n_press == 1 && ctrl_held;
    }

    public static bool is_navigation_key(uint keyval, bool ctrl_held) {
        return ctrl_held && (keyval == KEYVAL_RETURN || keyval == KEYVAL_KP_ENTER);
    }

    public static Gee.ArrayList<CardSummary> cards_for_project(string? project_id,
                                                               Gee.List<CardSummary> cards) {
        var project_cards = new Gee.ArrayList<CardSummary>();
        if (project_id == null) {
            return project_cards;
        }
        foreach (var card in cards) {
            if (card.project_id == project_id) {
                project_cards.add(card);
            }
        }
        return project_cards;
    }

    public static string launch_failure_message(string details) {
        return "Could not open link: %s".printf(details);
    }

    // line_text is the editor line containing the cursor and line_byte_offset the cursor's byte
    // offset within it; document_byte_offset is the cursor's byte offset within editor_text.
    // tag_occurrences is null when there is no current card.
    public EditorNavigationResult resolve(string editor_text,
                                          int document_byte_offset,
                                          string? line_text,
                                          int line_byte_offset,
                                          Gee.List<CardSummary> project_cards,
                                          bool has_unsaved_changes,
                                          CardTagOccurrence[]? tag_occurrences) {
        string? target = null;
        if (line_text != null && line_text.length > 0) {
            target = internal_link_controller.extract_target_from_line(line_text, line_byte_offset);
        }
        var decision = internal_link_controller.decide_navigation(target, project_cards);
        if (decision.handled) {
            if (decision.open_card_id == null) {
                return new EditorNavigationResult(
                    EditorNavigationKind.CREATE_PROMPT,
                    decision.create_target,
                    decision.toast_message
                );
            }
            return new EditorNavigationResult(EditorNavigationKind.OPEN_CARD, decision.open_card_id);
        }

        var resource_id = resource_image_controller.resource_id_at_byte_offset(
            editor_text,
            document_byte_offset
        );
        if (resource_id != null) {
            return new EditorNavigationResult(EditorNavigationKind.RESOURCE_PREVIEW, resource_id);
        }

        if (!has_unsaved_changes && tag_occurrences != null) {
            var tag = tag_navigation_controller.tag_at_byte_offset(
                editor_text,
                document_byte_offset,
                tag_occurrences
            );
            if (tag != null) {
                return new EditorNavigationResult(EditorNavigationKind.SHOW_TAG, tag);
            }
        }

        var uri = markdown_link_controller.uri_at_byte_offset(editor_text, document_byte_offset);
        if (uri != null) {
            return new EditorNavigationResult(EditorNavigationKind.OPEN_URI, uri);
        }
        return new EditorNavigationResult(EditorNavigationKind.NONE);
    }
}

}
