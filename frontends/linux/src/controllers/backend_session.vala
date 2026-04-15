namespace HolderLinux {

internal class BackendSessionController : Object {
    private MainController owner;
    private ServerInfo? active_server_info = null;
    private bool reconnect_in_flight = false;

    public BackendSessionController(MainController owner) {
        this.owner = owner;
    }

    public ServerInfo? get_active_server_info() {
        return active_server_info;
    }

    public async void connect_from_discovery() throws Error {
        var info = owner.server_discovery.discover_server();
        active_server_info = info;
        owner.api = owner.api_factory.create(info.base_url(), info.auth_token);
        owner.api_client_ready((!) owner.api);
    }

    public async void health_check() throws Error {
        yield ((!) owner.api).health_check();
    }

    public async bool try_reconnect_after_transport_error(Error e) {
        if (!is_transport_error_message(e.message)) {
            return false;
        }
        if (reconnect_in_flight) {
            return false;
        }
        reconnect_in_flight = true;
        try {
            owner.status_changed("Reconnecting to backend...");
            yield connect_from_discovery();
            try {
                yield health_check();
            } catch (Error health_error) {
                warning("Reconnect health-check failed: %s", health_error.message);
                return false;
            }
            var info = active_server_info;
            if (info == null) { // LCOV_EXCL_LINE GCOVR_EXCL_LINE: defensive impossible guard after successful connect_from_discovery()
                return false;
            }
            owner.status_changed("Reconnected to %s:%d".printf(info.bind, info.port));
            owner.ai_status_refresh_requested();
            return true;
        } catch (Error reconnect_error) {
            warning("Reconnect failed: %s", reconnect_error.message);
            return false;
        } finally {
            reconnect_in_flight = false;
        }
    }

    private bool is_transport_error_message(string message) {
        var lower = message.down();
        return lower.contains("connection")
            || lower.contains("connect")
            || lower.contains("refused")
            || lower.contains("timed out")
            || lower.contains("socket")
            || lower.contains("network")
            || lower.contains("http 401")
            || lower.contains("unauthorized")
            || lower.contains("could not resolve")
            || lower.contains("unreachable");
    }
}

}
