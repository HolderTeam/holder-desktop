namespace HolderLinux {

public class TerminalController : Object {
    public string resolve_shell(string? shell_env) { // GCOVR_EXCL_BR_LINE
        if (shell_env == null || shell_env.strip().length == 0) {
            return "/bin/bash";
        }
        return shell_env;
    }

    public string fallback_title_for_index(int index) { // GCOVR_EXCL_BR_LINE
        return "Term %d".printf(index);
    }

    public string title_or_fallback(string? window_title, string fallback_title) { // GCOVR_EXCL_BR_LINE
        if (window_title == null || window_title.strip().length == 0) {
            return fallback_title;
        }
        return window_title;
    }

    public string? selected_text_or_null(string? selected_text) { // GCOVR_EXCL_BR_LINE
        if (selected_text == null || selected_text.strip().length == 0) {
            return null;
        }
        return selected_text;
    }
}

}
