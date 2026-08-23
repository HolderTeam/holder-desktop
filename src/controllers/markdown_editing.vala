namespace HolderLinux {

internal enum MarkdownListAction {
    NONE,
    CONTINUE,
    END
}

internal class MarkdownListDecision : Object {
    public MarkdownListAction action { get; construct; }
    public string continuation { get; construct; }

    public MarkdownListDecision(MarkdownListAction action, string continuation = "") {
        Object(action: action, continuation: continuation);
    }
}

internal class MarkdownEditingController : Object {
    public MarkdownListDecision decide_return(string line_prefix) {
        var task = match_line(
            line_prefix,
            "^([ \\t]*)([-+*])[ \\t]+\\[([ xX])\\][ \\t]*(.*)$"
        );
        if (task != null) {
            if (task.fetch(4).strip().length == 0) {
                return new MarkdownListDecision(MarkdownListAction.END);
            }
            return new MarkdownListDecision(
                MarkdownListAction.CONTINUE,
                "%s%s [ ] ".printf(task.fetch(1), task.fetch(2))
            );
        }

        var ordered = match_line(
            line_prefix,
            "^([ \\t]*)([0-9]+)([.)])[ \\t]+(.*)$"
        );
        if (ordered != null) {
            if (ordered.fetch(4).strip().length == 0) {
                return new MarkdownListDecision(MarkdownListAction.END);
            }
            var next_number = int64.parse(ordered.fetch(2)) + 1;
            return new MarkdownListDecision(
                MarkdownListAction.CONTINUE,
                "%s%s%s ".printf(
                    ordered.fetch(1),
                    next_number.to_string(),
                    ordered.fetch(3)
                )
            );
        }

        var bullet = match_line(
            line_prefix,
            "^([ \\t]*)([-+*])[ \\t]+(.*)$"
        );
        if (bullet != null) {
            if (bullet.fetch(3).strip().length == 0) {
                return new MarkdownListDecision(MarkdownListAction.END);
            }
            return new MarkdownListDecision(
                MarkdownListAction.CONTINUE,
                "%s%s ".printf(bullet.fetch(1), bullet.fetch(2))
            );
        }

        return new MarkdownListDecision(MarkdownListAction.NONE);
    }

    private MatchInfo? match_line(string text, string pattern) {
        try {
            var regex = new Regex(pattern);
            MatchInfo match_info;
            if (regex.match(text, 0, out match_info)) {
                return match_info;
            }
        } catch (RegexError e) {
            // A built-in expression failure should leave normal Return behavior intact.
        }
        return null;
    }
}

}
