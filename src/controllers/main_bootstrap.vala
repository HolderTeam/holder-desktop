namespace HolderLinux {

internal class MainBootstrapController : Object {
    private MainController owner;

    public MainBootstrapController(MainController owner) {
        this.owner = owner;
    }

    // Starts the daemon when none is running. Returns false, after telling the user why, when it
    // cannot be started.
    private async bool start_backend() {
        var starter = owner.backend_starter;
        if (starter == null) {
            return true;
        }
        owner.status_changed("Starting Holder...");
        owner.editor_state_changed("# Starting Holder\n\nStarting the local backend...", false);
        string failure;
        try {
            var outcome = yield ((!) starter).ensure();
            if (outcome.ok) {
                return true;
            }
            failure = outcome.message;
        } catch (Error e) {
            failure = e.message;
        }
        owner.status_changed("Holder could not start");
        owner.editor_state_changed(
            "# Holder Could Not Start\n\n" +
            "The local backend could not be started.\n\n" +
            failure,
            false
        );
        owner.error_reported("Holder could not start", failure);
        return false;
    }

    public async void bootstrap() {
        if (!(yield start_backend())) {
            return;
        }
        owner.status_changed("Discovering local server...");
        owner.editor_state_changed("# Loading\n\nDiscovering local server...", false);

        try {
            yield owner.backend_session_controller.connect_from_discovery();
        } catch (Error e) {
            owner.status_changed(e.message);
            owner.editor_state_changed(
                "# Holder Not Found\n\n" +
                "Start the backend first, then reopen this app.\n\n" +
                "Expected file:\n`%s`\n".printf(owner.server_discovery.holder_info_path()),
                false
            );
            return;
        }

        owner.status_changed("Checking API health...");
        owner.editor_state_changed("# Loading\n\nChecking API health...", false);
        try {
            yield owner.backend_session_controller.health_check();
        } catch (Error e) {
            if (yield owner.backend_session_controller.try_reconnect_after_transport_error(e)) {
                owner.status_changed("Checking API health...");
                owner.editor_state_changed("# Loading\n\nChecking API health...", false);
                try {
                    yield owner.backend_session_controller.health_check();
                } catch (Error retry_error) {
                    owner.status_changed("Health check failed");
                    owner.editor_state_changed(
                        "# Health Check Failed\n\n" +
                        "Could not connect to the Holder API.\n\n" +
                        retry_error.message,
                        false
                    );
                    owner.error_reported("Health check failed", retry_error.message);
                    return;
                }
            } else {
                owner.status_changed("Health check failed");
                owner.editor_state_changed(
                    "# Health Check Failed\n\n" +
                    "Could not connect to the Holder API.\n\n" +
                    e.message,
                    false
                );
                owner.error_reported("Health check failed", e.message);
                return;
            }
        }

        var info = owner.backend_session_controller.get_active_server_info();
        // LCOV_EXCL_START
        // GCOVR_EXCL_START
        // Impossible after successful discovery-backed session connect and health check.
        if (info == null) {
            owner.status_changed("Health check failed");
            owner.editor_state_changed(
                "# Health Check Failed\n\n" +
                "Could not connect to the Holder API.\n\n" +
                "Missing active server info.",
                false
            );
            owner.error_reported("Health check failed", "Missing active server info.");
            return;
        }
        // GCOVR_EXCL_STOP
        // LCOV_EXCL_STOP

        owner.status_changed("Connected to %s:%d (API %s)".printf(info.bind, info.port, info.api_version));
        var presence = owner.presence;
        if (presence != null) {
            ((!) presence).start();
        }
        yield owner.ensure_first_project();
        yield owner.reload_everything();
        owner.ai_status_refresh_requested();
    }
}

}
