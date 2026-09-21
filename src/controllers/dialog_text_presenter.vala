namespace HolderLinux {

internal class DialogTextPresenter : Object {
    public static string update_prompt_body(string message, string version, string current_version) {
        return "%s\n\nHolder %s is available. You are running %s.".printf(
            message,
            version,
            current_version
        );
    }

    public static string move_to_trash_body(string card_title) {
        return "Move \"%s\" to Trash?\n\nYou can restore it from the Trash tool.".printf(card_title);
    }

    public static string create_linked_card_body(string target) {
        return "No card matches [[%s]] in this project.".printf(target);
    }
}

}
