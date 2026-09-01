namespace HolderLinux {

public class TerminalSessionStore : Object {
    private string root_dir;
    private PowerShellTranscriptParser transcript_parser;

    public TerminalSessionStore(string? root_dir = null,
                                PowerShellTranscriptParser? transcript_parser = null) {
        this.root_dir = root_dir ?? Path.build_filename(
            Environment.get_user_cache_dir(), "holder", "terminal-sessions"
        );
        this.transcript_parser = transcript_parser ?? new PowerShellTranscriptParser();
    }

    public TerminalSession create_session(string project_id,
                                           string project_label,
                                           string? card_id,
                                           string? card_label,
                                           string working_directory) throws Error {
        ensure_root_dir();
        var session_id = Uuid.string_random();
        var session_dir = Path.build_filename(root_dir, session_id);
        if (DirUtils.create_with_parents(session_dir, 0700) != 0) {
            throw new IOError.FAILED("Could not create terminal session directory: %s".printf(session_dir));
        }

        var created_at = new DateTime.now_utc().to_unix();
        var session = new TerminalSession(
            session_id,
            project_id,
            project_label,
            card_id,
            card_label,
            working_directory,
            Path.build_filename(session_dir, "transcript.txt"),
            Path.build_filename(session_dir, "bootstrap.ps1"),
            created_at,
            created_at,
            TerminalSessionState.ACTIVE
        );
        write_bootstrap(session.bootstrap_path);
        save_session(session);
        return session;
    }

    public Gee.ArrayList<TerminalSession> load_sessions(string? project_id = null) throws Error {
        var sessions = new Gee.ArrayList<TerminalSession>();
        if (!FileUtils.test(root_dir, FileTest.IS_DIR)) {
            return sessions;
        }

        Dir directory;
        try {
            directory = Dir.open(root_dir);
        } catch (FileError e) {
            throw new IOError.FAILED("Could not read terminal sessions: %s".printf(e.message));
        }

        unowned string? name;
        while ((name = directory.read_name()) != null) {
            var metadata_path = Path.build_filename(root_dir, (!) name, "session.json");
            if (!FileUtils.test(metadata_path, FileTest.IS_REGULAR)) {
                continue;
            }
            try {
                var session = load_session(metadata_path);
                if (project_id != null && session.project_id != project_id) {
                    continue;
                }
                refresh_recovered_state(session);
                sessions.add(session);
            } catch (Error e) {
                // One damaged local transcript must not hide other sessions.
            }
        }
        sessions.sort((a, b) => {
            if (a.created_at == b.created_at) {
                return strcmp(a.session_id, b.session_id);
            }
            return a.created_at > b.created_at ? -1 : 1;
        });
        return sessions;
    }

    public PowerShellTranscriptSnapshot read_transcript(TerminalSession session) throws Error {
        if (!FileUtils.test(session.transcript_path, FileTest.IS_REGULAR)) {
            return transcript_parser.parse("");
        }
        string contents;
        try {
            FileUtils.get_contents(session.transcript_path, out contents);
        } catch (FileError e) {
            throw new IOError.FAILED("Could not read terminal transcript: %s".printf(e.message));
        }
        var snapshot = transcript_parser.parse(contents);
        if (snapshot.completed && session.state != TerminalSessionState.COMPLETED) {
            session.state = TerminalSessionState.COMPLETED;
            session.last_modified_at = file_modified_at(session.transcript_path);
            save_session(session);
        }
        return snapshot;
    }

    public void save_session(TerminalSession session) throws Error {
        var builder = new Json.Builder();
        builder.begin_object();
        add_string(builder, "session_id", session.session_id);
        add_string(builder, "project_id", session.project_id);
        add_string(builder, "project_label", session.project_label);
        add_nullable_string(builder, "card_id", session.card_id);
        add_nullable_string(builder, "card_label", session.card_label);
        add_string(builder, "working_directory", session.working_directory);
        add_string(builder, "transcript_path", session.transcript_path);
        add_string(builder, "bootstrap_path", session.bootstrap_path);
        builder.set_member_name("created_at");
        builder.add_int_value(session.created_at);
        builder.set_member_name("last_modified_at");
        builder.add_int_value(session.last_modified_at);
        add_string(builder, "state", session.state.to_storage_value());
        builder.end_object();

        var generator = new Json.Generator();
        generator.set_root(builder.get_root());
        var metadata_path = Path.build_filename(
            Path.get_dirname(session.transcript_path), "session.json"
        );
        try {
            FileUtils.set_contents(metadata_path, generator.to_data(null));
            FileUtils.chmod(metadata_path, 0600);
        } catch (FileError e) {
            throw new IOError.FAILED("Could not save terminal session: %s".printf(e.message));
        }
    }

    internal static string bootstrap_script() {
        return """param(
    [Parameter(Mandatory = $true)][string]$HolderTranscriptPath,
    [Parameter(Mandatory = $true)][string]$HolderWorkingDirectory
)

if (Test-Path -LiteralPath $HolderWorkingDirectory -PathType Container) {
    Set-Location -LiteralPath $HolderWorkingDirectory
}

Start-Transcript -LiteralPath $HolderTranscriptPath -Force
Write-Host 'Holder is recording this terminal session. Return to Holder to preserve useful output in a card.'
""";
    }

    private void ensure_root_dir() throws Error {
        if (DirUtils.create_with_parents(root_dir, 0700) != 0
            && !FileUtils.test(root_dir, FileTest.IS_DIR)) {
            throw new IOError.FAILED("Could not create terminal session storage: %s".printf(root_dir));
        }
        FileUtils.chmod(root_dir, 0700);
    }

    private static void write_bootstrap(string path) throws Error {
        try {
            FileUtils.set_contents(path, bootstrap_script());
            FileUtils.chmod(path, 0600);
        } catch (FileError e) {
            throw new IOError.FAILED("Could not write terminal bootstrap script: %s".printf(e.message));
        }
    }

    private TerminalSession load_session(string path) throws Error {
        string payload;
        try {
            FileUtils.get_contents(path, out payload);
        } catch (FileError e) {
            throw new IOError.FAILED("Could not read terminal session metadata: %s".printf(e.message));
        }
        var parser = new Json.Parser();
        try {
            parser.load_from_data(payload, payload.length);
        } catch (Error e) {
            throw new IOError.INVALID_DATA("Could not parse terminal session metadata: %s".printf(e.message));
        }
        var root = parser.get_root();
        if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
            throw new IOError.INVALID_DATA("Terminal session metadata is not an object.");
        }
        var object = root.get_object();
        return new TerminalSession(
            object.get_string_member("session_id"),
            object.get_string_member("project_id"),
            object.get_string_member("project_label"),
            nullable_string(object, "card_id"),
            nullable_string(object, "card_label"),
            object.get_string_member("working_directory"),
            object.get_string_member("transcript_path"),
            object.get_string_member("bootstrap_path"),
            object.get_int_member("created_at"),
            object.get_int_member("last_modified_at"),
            TerminalSessionState.from_storage_value(object.get_string_member("state"))
        );
    }

    private void refresh_recovered_state(TerminalSession session) throws Error {
        if (!FileUtils.test(session.transcript_path, FileTest.IS_REGULAR)) {
            if (session.state == TerminalSessionState.ACTIVE) {
                session.state = TerminalSessionState.INTERRUPTED;
                save_session(session);
            }
            return;
        }
        var snapshot = read_transcript(session);
        var next_state = snapshot.completed
            ? TerminalSessionState.COMPLETED
            : TerminalSessionState.INTERRUPTED;
        if (session.state != next_state) {
            session.state = next_state;
            session.last_modified_at = file_modified_at(session.transcript_path);
            save_session(session);
        }
    }

    private static int64 file_modified_at(string path) {
        try {
            var info = File.new_for_path(path).query_info(
                FileAttribute.TIME_MODIFIED,
                FileQueryInfoFlags.NONE,
                null
            );
            return (int64) info.get_attribute_uint64(FileAttribute.TIME_MODIFIED);
        } catch (Error e) {
            return 0;
        }
    }

    private static void add_string(Json.Builder builder, string name, string value) {
        builder.set_member_name(name);
        builder.add_string_value(value);
    }

    private static void add_nullable_string(Json.Builder builder, string name, string? value) {
        builder.set_member_name(name);
        if (value == null) {
            builder.add_null_value();
        } else {
            builder.add_string_value((!) value);
        }
    }

    private static string? nullable_string(Json.Object object, string member_name) {
        if (!object.has_member(member_name)
            || object.get_member(member_name).get_node_type() == Json.NodeType.NULL) {
            return null;
        }
        return object.get_string_member(member_name);
    }
}

}
