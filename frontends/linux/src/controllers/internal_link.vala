namespace HolderLinux {

internal class InternalLinkController : Object {
    public Gee.ArrayList<string> extract_internal_links(string text) {
        var results = new Gee.ArrayList<string>();
        if (text == null || text.length == 0) {
            return results;
        }

        var seen = new Gee.HashSet<string>();
        try {
            var regex = new Regex("\\[\\[([^\\]\\n]+)\\]\\]");
            MatchInfo match_info;
            if (!regex.match(text, 0, out match_info)) {
                return results;
            }

            do {
                var target = match_info.fetch(1).strip();
                if (target.length == 0 || seen.contains(target)) {
                    continue;
                }
                seen.add(target);
                results.add(target);
            } while (match_info.next());
        } catch (RegexError e) {
            // Keep UI stable even if regex parsing fails for unexpected input.
        }
        return results;
    }

    public string? extract_target_from_line(string line_text, int cursor_byte_offset) {
        if (line_text.length == 0) {
            return null;
        }

        if (cursor_byte_offset < 0) {
            return null;
        }
        if (cursor_byte_offset > line_text.length) {
            cursor_byte_offset = line_text.length;
        }

        var search_upto = line_text.substring(0, cursor_byte_offset);
        int open_pos = search_upto.last_index_of("[[");
        if (open_pos < 0 && cursor_byte_offset < line_text.length) {
            search_upto = line_text.substring(0, cursor_byte_offset + 1);
            open_pos = search_upto.last_index_of("[[");
        }
        if (open_pos < 0) {
            return null;
        }

        int close_pos = line_text.index_of("]]", open_pos + 2);
        if (close_pos < 0) {
            return null;
        }

        if (cursor_byte_offset < open_pos || cursor_byte_offset > close_pos + 2) {
            return null;
        }

        var raw_target = line_text.substring(open_pos + 2, close_pos - (open_pos + 2));
        var target = raw_target.strip();
        return target.length > 0 ? target : null;
    }

    public string? resolve_target_card_id(string target, Gee.List<CardSummary> project_cards) {
        if (target.length == 0) {
            return null;
        }

        foreach (var card in project_cards) {
            if (card.card_id == target) {
                return card.card_id;
            }
        }

        foreach (var card in project_cards) {
            if (card.title == target) {
                return card.card_id;
            }
        }

        var lowered_target = target.down();
        foreach (var card in project_cards) {
            if (card.title.down() == lowered_target) {
                return card.card_id;
            }
        }

        return null;
    }
}

}
