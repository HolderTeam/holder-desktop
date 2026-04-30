namespace HolderLinux {

internal class NewProjectSubmission : Object {
    public string name { get; construct; }
    public string privacy_mode { get; construct; }

    public NewProjectSubmission(string name, string privacy_mode) {
        Object(name: name, privacy_mode: privacy_mode);
    }
}

internal class ProjectCreateController : Object {
    public signal void error_reported(string title, string details);

    public NewProjectSubmission? build_submission(string raw_name, bool is_private_mode) {
        var name = raw_name.strip();
        if (name.length == 0) {
            error_reported("Project name required", "Please enter a non-empty project name.");
            return null;
        }

        var privacy_mode = is_private_mode ? "encrypted_git" : "plain";
        return new NewProjectSubmission(name, privacy_mode);
    }
}

}
