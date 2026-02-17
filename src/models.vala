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

public class Project : Object {
    public string project_id { get; construct; }
    public string name { get; set; }
    public string root_path { get; construct; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; set; }

    public Project(string project_id,
                   string name,
                   string root_path,
                   int64 created_at,
                   int64 updated_at) {
        Object(
            project_id: project_id,
            name: name,
            root_path: root_path,
            created_at: created_at,
            updated_at: updated_at
        );
    }
}

public class CardSummary : Object {
    public string card_id { get; construct; }
    public string project_id { get; construct; }
    public string title { get; set; }
    public string rel_path { get; construct; }
    public int64 created_at { get; construct; }
    public int64 updated_at { get; set; }

    public CardSummary(string card_id,
                       string project_id,
                       string title,
                       string rel_path,
                       int64 created_at,
                       int64 updated_at) {
        Object(
            card_id: card_id,
            project_id: project_id,
            title: title,
            rel_path: rel_path,
            created_at: created_at,
            updated_at: updated_at
        );
    }
}

public class CardDetail : Object {
    public string card_id { get; construct; }
    public string project_id { get; construct; }
    public string title { get; set; }
    public string content { get; set; }
    public int64 updated_at { get; set; }

    public CardDetail(string card_id,
                      string project_id,
                      string title,
                      string content,
                      int64 updated_at) {
        Object(
            card_id: card_id,
            project_id: project_id,
            title: title,
            content: content,
            updated_at: updated_at
        );
    }
}

}
