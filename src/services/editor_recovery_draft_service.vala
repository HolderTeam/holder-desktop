namespace HolderLinux {

public class EditorRecoveryDraft : Object {
    public string card_id { get; construct; }
    public string project_id { get; construct; }
    public string title { get; construct; }
    public string content { get; construct; }
    public int64 saved_at { get; construct; }

    public EditorRecoveryDraft(string card_id,
                               string project_id,
                               string title,
                               string content,
                               int64 saved_at) {
        Object(
            card_id: card_id,
            project_id: project_id,
            title: title,
            content: content,
            saved_at: saved_at
        );
    }
}

public interface IEditorRecoveryDraftService : Object {
    public abstract void save_draft(EditorRecoveryDraft draft) throws Error;
    public abstract EditorRecoveryDraft? load_draft(string card_id) throws Error;
    public abstract void remove_draft(string card_id) throws Error;
    public abstract string draft_path_for_card_id(string card_id);
}

public class EditorRecoveryDraftService : Object, IEditorRecoveryDraftService {
    private string root_dir;

    public EditorRecoveryDraftService(string? root_dir = null) {
        this.root_dir = root_dir ?? default_root_dir();
    }

    public void save_draft(EditorRecoveryDraft draft) throws Error {
        ensure_root_dir();

        var builder = new Json.Builder();
        builder.begin_object();
        builder.set_member_name("card_id");
        builder.add_string_value(draft.card_id);
        builder.set_member_name("project_id");
        builder.add_string_value(draft.project_id);
        builder.set_member_name("title");
        builder.add_string_value(draft.title);
        builder.set_member_name("content");
        builder.add_string_value(draft.content);
        builder.set_member_name("saved_at");
        builder.add_int_value(draft.saved_at);
        builder.end_object();

        var generator = new Json.Generator();
        generator.set_root(builder.get_root());

        string payload = generator.to_data(null);

        var destination_path = draft_path_for_card_id(draft.card_id);
        try {
            string? new_etag = null;
            var destination = File.new_for_path(destination_path);
            destination.replace_contents(
                payload.data,
                null,
                false,
                FileCreateFlags.PRIVATE | FileCreateFlags.REPLACE_DESTINATION,
                out new_etag,
                null
            );
            if (FileUtils.chmod(destination_path, 0600) != 0) {
                throw new IOError.FAILED("Could not make recovery draft private.");
            }
        } catch (Error e) {
            throw new IOError.FAILED("Could not save recovery draft: %s".printf(e.message));
        }
    }

    public EditorRecoveryDraft? load_draft(string card_id) throws Error {
        var path = draft_path_for_card_id(card_id);
        if (!FileUtils.test(path, FileTest.EXISTS)) {
            return null;
        }

        string payload;
        try {
            FileUtils.get_contents(path, out payload);
        } catch (FileError e) {
            throw new IOError.FAILED("Could not read recovery draft: %s".printf(e.message));
        }

        var parser = new Json.Parser();
        try {
            parser.load_from_data(payload, payload.length);
        } catch (Error e) {
            throw new IOError.FAILED("Could not parse recovery draft: %s".printf(e.message));
        }

        var root = parser.get_root();
        if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
            throw new IOError.FAILED("Recovery draft payload is not an object.");
        }

        var obj = root.get_object();
        return new EditorRecoveryDraft(
            obj.get_string_member("card_id"),
            obj.get_string_member("project_id"),
            obj.get_string_member("title"),
            obj.get_string_member("content"),
            obj.get_int_member("saved_at")
        );
    }

    public void remove_draft(string card_id) throws Error {
        var path = draft_path_for_card_id(card_id);
        if (!FileUtils.test(path, FileTest.EXISTS)) {
            return;
        }
        var file = File.new_for_path(path);
        try {
            file.delete();
        } catch (Error e) {
            throw new IOError.FAILED("Could not remove recovery draft: %s".printf(e.message));
        }
    }

    public string draft_path_for_card_id(string card_id) {
        return Path.build_filename(root_dir, "%s.json".printf(safe_component(card_id)));
    }

    private void ensure_root_dir() throws Error {
        if (DirUtils.create_with_parents(root_dir, 0700) != 0) {
            throw new IOError.FAILED("Could not create recovery draft directory: %s".printf(root_dir));
        }
        if (FileUtils.chmod(root_dir, 0700) != 0) {
            throw new IOError.FAILED("Could not make recovery draft directory private: %s".printf(root_dir));
        }
    }

    private static string default_root_dir() {
        var xdg_state_home = Environment.get_variable("XDG_STATE_HOME");
        if (xdg_state_home == null || xdg_state_home.strip().length == 0) {
            var home = Environment.get_home_dir();
            if (home != null && home.strip().length > 0) {
                xdg_state_home = Path.build_filename(home, ".local", "state");
            } else {
                xdg_state_home = Path.build_filename(Environment.get_tmp_dir(), "holder-state"); // LCOV_EXCL_LINE GCOVR_EXCL_LINE: passwd-backed home makes tmp fallback impractical to force in-process
            }
        }
        return Path.build_filename(xdg_state_home, "holder", "editor-recovery-drafts");
    }

    private static string safe_component(string value) {
        var out = new StringBuilder();
        for (int i = 0; i < value.length; i++) {
            unichar ch = value.get_char(i);
            if ((ch >= 'a' && ch <= 'z')
                || (ch >= 'A' && ch <= 'Z')
                || (ch >= '0' && ch <= '9')
                || ch == '-'
                || ch == '_') {
                out.append_unichar(ch);
            } else {
                out.append_c('_');
            }
        }
        return out.str;
    }
}

}
