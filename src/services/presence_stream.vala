namespace HolderLinux {

// Holds the daemon's GET /events stream open for as long as the app runs. The daemon treats an
// open event stream as "a client is here", so a daemon that was started to stop itself when
// unused (holderctl ensure --idle-exit) stays up under an open window and goes away soon after
// the last one closes. Nothing here reads the events; the stream is only held, and read so the
// connection stays healthy. If the connection drops, for example because the daemon restarted
// with a new port and token, it looks the daemon up again and reconnects with a growing delay.
public class PresenceStream : Object, IPresence {
    internal const uint RETRY_MIN_MS = 1000;
    internal const uint RETRY_MAX_MS = 10000;

    private IApiHttpTransport transport;
    private IServerDiscovery discovery;
    private IScheduler scheduler;
    private Cancellable? cancellable = null;
    private uint retry_source = 0;
    private uint retry_delay_ms = RETRY_MIN_MS;
    private bool active = false;

    public bool is_connected { get; private set; default = false; }

    public signal void connection_changed(bool connected);
    // Lines for the debug panel.
    public signal void debug_log_requested(string line);

    public PresenceStream(IApiHttpTransport transport, IServerDiscovery discovery, IScheduler scheduler) {
        this.transport = transport;
        this.discovery = discovery;
        this.scheduler = scheduler;
    }

    public void start() {
        if (active) {
            return;
        }
        active = true;
        cancellable = new Cancellable();
        retry_delay_ms = RETRY_MIN_MS;
        attempt.begin();
    }

    public void stop() {
        active = false;
        if (cancellable != null) {
            ((!) cancellable).cancel();
        }
        if (retry_source != 0) {
            scheduler.cancel(retry_source);
            retry_source = 0;
        }
        set_connected(false);
    }

    // One connection, from connecting to the stream ending, then schedules the next attempt.
    internal async void attempt() {
        var token = cancellable;
        if (token == null) {
            return;
        }
        InputStream? held = null;
        try {
            var info = discovery.discover_server();
            debug_log_requested("PRESENCE connecting to %s/events".printf(info.base_url()));
            var message = new Soup.Message("GET", info.base_url() + "/events");
            message.request_headers.append("Authorization", "Bearer %s".printf(info.auth_token));
            message.request_headers.append("Accept", "text/event-stream");

            var response = yield transport.send(message);
            held = response.stream;
            if (((!) token).is_cancelled()) {
                close_quietly(held);
                return;
            }
            if (response.status < 200 || response.status >= 300) {
                throw new ApiError.HTTP("HTTP %u for GET /events".printf(response.status));
            }

            debug_log_requested("PRESENCE connected (HTTP %u)".printf(response.status));
            set_connected(true);
            retry_delay_ms = RETRY_MIN_MS;
            var lines = new DataInputStream((!) held);
            lines.set_newline_type(DataStreamNewlineType.LF);
            // The first event and the first heartbeat are each logged once per connection, so
            // the debug panel shows that heartbeats keep arriving (the daemon sends one every
            // 15 seconds) without a line for each. The stream opens with a ready event, so an
            // event line alone says nothing about heartbeats.
            bool saw_event = false;
            bool saw_heartbeat = false;
            while (true) {
                size_t length = 0;
                var line = yield lines.read_line_async(Priority.DEFAULT, token, out length);
                if (line == null) {
                    break;
                }
                if (line.has_prefix(":")) {
                    if (!saw_heartbeat) {
                        saw_heartbeat = true;
                        debug_log_requested("PRESENCE receiving heartbeats");
                    }
                } else if (line != "" && !saw_event) {
                    saw_event = true;
                    debug_log_requested("PRESENCE receiving events");
                }
            }
        } catch (Error e) {
            debug("Presence stream ended: %s", e.message);
            if (!((!) token).is_cancelled()) {
                debug_log_requested("PRESENCE stream ended: %s".printf(e.message));
            }
        }
        close_quietly(held);

        if (((!) token).is_cancelled()) {
            return;
        }
        set_connected(false);
        schedule_retry();
    }

    private void schedule_retry() {
        var delay = retry_delay_ms;
        debug_log_requested("PRESENCE reconnecting in %u ms".printf(delay));
        retry_delay_ms = uint.min(retry_delay_ms * 2, RETRY_MAX_MS);
        retry_source = scheduler.schedule_once(delay, () => {
            retry_source = 0;
            if (active) {
                attempt.begin();
            }
            return Source.REMOVE;
        });
    }

    private void set_connected(bool connected) {
        if (is_connected == connected) {
            return;
        }
        is_connected = connected;
        connection_changed(connected);
    }

    private static void close_quietly(InputStream? stream) {
        if (stream == null) {
            return;
        }
        try {
            ((!) stream).close();
        } catch (Error e) {
            debug("Closing the presence stream failed: %s", e.message);
        }
    }
}

}
