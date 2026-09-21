namespace HolderLinux {

// Same bit values as the matching Gdk.ModifierType masks, so the view can cast its event state
// and the key table stays testable without GTK.
[Flags]
internal enum MarkdownKeyModifiers {
    SHIFT = 1 << 0,
    CONTROL = 1 << 2,
    ALT = 1 << 3,
    SUPER = 1 << 26
}

internal enum MarkdownKeyActionKind {
    NONE,
    INLINE,
    LINE,
    CLEAR_FORMATTING
}

internal class MarkdownKeyAction : Object {
    public MarkdownKeyActionKind kind { get; construct; }
    public MarkdownInlineCommand inline_command { get; construct; }
    public MarkdownLineCommand line_command { get; construct; }

    public MarkdownKeyAction(MarkdownKeyActionKind kind,
                             MarkdownInlineCommand inline_command = MarkdownInlineCommand.BOLD,
                             MarkdownLineCommand line_command = MarkdownLineCommand.INDENT) {
        Object(kind: kind, inline_command: inline_command, line_command: line_command);
    }

    public static MarkdownKeyAction none() {
        return new MarkdownKeyAction(MarkdownKeyActionKind.NONE);
    }

    public static MarkdownKeyAction inline(MarkdownInlineCommand command) {
        return new MarkdownKeyAction(MarkdownKeyActionKind.INLINE, command);
    }

    public static MarkdownKeyAction line(MarkdownLineCommand command) {
        return new MarkdownKeyAction(
            MarkdownKeyActionKind.LINE, MarkdownInlineCommand.BOLD, command
        );
    }

    public static MarkdownKeyAction clear_formatting() {
        return new MarkdownKeyAction(MarkdownKeyActionKind.CLEAR_FORMATTING);
    }
}

internal class MarkdownKeyMap {
    // Gdk keyval values (the Latin-1 ones are their ASCII codes).
    public const uint KEY_RETURN = 0xff0d;
    public const uint KEY_KP_ENTER = 0xff8d;
    public const uint KEY_LOWER_B = 0x62;
    public const uint KEY_UPPER_B = 0x42;
    public const uint KEY_LOWER_I = 0x69;
    public const uint KEY_UPPER_I = 0x49;
    public const uint KEY_LOWER_K = 0x6b;
    public const uint KEY_UPPER_K = 0x4b;
    public const uint KEY_LOWER_L = 0x6c;
    public const uint KEY_UPPER_L = 0x4c;
    public const uint KEY_LOWER_X = 0x78;
    public const uint KEY_UPPER_X = 0x58;
    public const uint KEY_LOWER_C = 0x63;
    public const uint KEY_UPPER_C = 0x43;
    public const uint KEY_BRACKET_LEFT = 0x5b;
    public const uint KEY_BRACKET_RIGHT = 0x5d;
    public const uint KEY_SLASH = 0x2f;
    public const uint KEY_BACKSLASH = 0x5c;
    public const uint KEY_AMPERSAND = 0x26;
    public const uint KEY_ASTERISK = 0x2a;
    public const uint KEY_PAREN_LEFT = 0x28;
    public const uint KEY_GREATER = 0x3e;
    public const uint KEY_PERIOD = 0x2e;
    public const uint KEY_7 = 0x37;
    public const uint KEY_8 = 0x38;
    public const uint KEY_9 = 0x39;

    // Enter continues or ends a list only when pressed with no modifiers at all.
    public static bool is_plain_return(uint keyval, MarkdownKeyModifiers modifiers) {
        if (keyval != KEY_RETURN && keyval != KEY_KP_ENTER) {
            return false;
        }
        return modifiers == 0;
    }

    // Ctrl (without Alt/Super) plus a key is a formatting shortcut; Shift selects the second table.
    public static MarkdownKeyAction resolve(uint keyval, MarkdownKeyModifiers modifiers) {
        var control = (modifiers & MarkdownKeyModifiers.CONTROL) != 0;
        var shift = (modifiers & MarkdownKeyModifiers.SHIFT) != 0;
        var forbidden = modifiers & (MarkdownKeyModifiers.ALT | MarkdownKeyModifiers.SUPER);
        if (!control || forbidden != 0) {
            return MarkdownKeyAction.none();
        }

        if (!shift) {
            if (keyval == KEY_LOWER_B || keyval == KEY_UPPER_B) {
                return MarkdownKeyAction.inline(MarkdownInlineCommand.BOLD);
            }
            if (keyval == KEY_LOWER_I || keyval == KEY_UPPER_I) {
                return MarkdownKeyAction.inline(MarkdownInlineCommand.ITALIC);
            }
            if (keyval == KEY_LOWER_K || keyval == KEY_UPPER_K) {
                return MarkdownKeyAction.inline(MarkdownInlineCommand.LINK);
            }
            if (keyval == KEY_LOWER_L || keyval == KEY_UPPER_L) {
                return MarkdownKeyAction.inline(MarkdownInlineCommand.WIKILINK);
            }
            if (keyval == KEY_BRACKET_LEFT) {
                return MarkdownKeyAction.line(MarkdownLineCommand.OUTDENT);
            }
            if (keyval == KEY_BRACKET_RIGHT) {
                return MarkdownKeyAction.line(MarkdownLineCommand.INDENT);
            }
            if (keyval == KEY_SLASH) {
                return MarkdownKeyAction.line(MarkdownLineCommand.CYCLE_HEADING);
            }
            if (keyval == KEY_BACKSLASH) {
                return MarkdownKeyAction.clear_formatting();
            }
            return MarkdownKeyAction.none();
        }

        if (keyval == KEY_LOWER_X || keyval == KEY_UPPER_X) {
            return MarkdownKeyAction.inline(MarkdownInlineCommand.STRIKETHROUGH);
        }
        if (keyval == KEY_LOWER_C || keyval == KEY_UPPER_C) {
            return MarkdownKeyAction.inline(MarkdownInlineCommand.CODE);
        }
        if (keyval == KEY_AMPERSAND || keyval == KEY_7) {
            return MarkdownKeyAction.line(MarkdownLineCommand.NUMBERED_LIST);
        }
        if (keyval == KEY_ASTERISK || keyval == KEY_8) {
            return MarkdownKeyAction.line(MarkdownLineCommand.BULLETED_LIST);
        }
        if (keyval == KEY_PAREN_LEFT || keyval == KEY_9) {
            return MarkdownKeyAction.line(MarkdownLineCommand.TODO_LIST);
        }
        if (keyval == KEY_GREATER || keyval == KEY_PERIOD) {
            return MarkdownKeyAction.line(MarkdownLineCommand.BLOCKQUOTE);
        }
        return MarkdownKeyAction.none();
    }
}

}
