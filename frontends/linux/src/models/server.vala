namespace HolderLinux {

public class ServerInfo : Object {
    public int pid { get; construct; }
    public string bind { get; construct; }
    public int port { get; construct; }
    public int64 started_at { get; construct; }
    public string api_version { get; construct; }
    public string server_version { get; construct; }
    public string auth_token { get; construct; }

    public ServerInfo(int pid,
                      string bind,
                      int port,
                      int64 started_at,
                      string api_version,
                      string server_version,
                      string auth_token) {
        Object(
            pid: pid,
            bind: bind,
            port: port,
            started_at: started_at,
            api_version: api_version,
            server_version: server_version,
            auth_token: auth_token
        );
    }

    public string base_url() {
        return "http://%s:%d".printf(bind, port);
    }
}

public class HealthInfo : Object {
    public bool db_ok { get; construct; }
    public int64 uptime_ms { get; construct; }
    public string api_version { get; construct; }
    public string server_version { get; construct; }
    public int pid { get; construct; }

    public HealthInfo(bool db_ok,
                      int64 uptime_ms,
                      string api_version,
                      string server_version,
                      int pid) {
        Object(
            db_ok: db_ok,
            uptime_ms: uptime_ms,
            api_version: api_version,
            server_version: server_version,
            pid: pid
        );
    }
}

}
