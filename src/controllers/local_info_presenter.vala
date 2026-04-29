namespace HolderLinux {

public class LocalInfoPresenter : Object {
    public string not_connected_markdown() {
        return "# Local info\n\nAPI client not connected.";
    }

    public string load_error_markdown(string details) {
        return
            "# Local info\n\n" +
            "Could not load `/health`.\n\n" +
            details;
    }

    public string page_title() {
        return "Local info";
    }

    public string loaded_status_text() {
        return "Loaded local info";
    }

    public string failed_status_text() {
        return "Failed to load local info";
    }

    public string error_title() {
        return "Local info failed";
    }
}

}
