namespace HolderLinux {

public errordomain ApiError {
    TRANSPORT,
    HTTP,
    PROTOCOL,
    PARSE
}

public interface IApiHttpTransport : Object {
    public abstract async ApiHttpBytesResponse send_and_read(Soup.Message message) throws Error;
    public abstract async ApiHttpStreamResponse send(Soup.Message message) throws Error;
}

public class ApiHttpBytesResponse : Object {
    public uint status { get; construct; }
    public Bytes body { get; construct; }

    public ApiHttpBytesResponse(uint status, Bytes body) {
        Object(status: status, body: body);
    }
}

public class ApiHttpStreamResponse : Object {
    public uint status { get; construct; }
    public InputStream stream { get; construct; }

    public ApiHttpStreamResponse(uint status, InputStream stream) {
        Object(status: status, stream: stream);
    }
}

public class SoupApiHttpTransport : Object, IApiHttpTransport {
    private Soup.Session session;
    private Soup.Session streaming_session;

    public SoupApiHttpTransport(Soup.Session? session = null) {
        this.session = session ?? new Soup.Session.with_options(
            "max-conns", 32,
            "max-conns-per-host", 16
        );
        this.streaming_session = session ?? new Soup.Session.with_options(
            "max-conns", 32,
            "max-conns-per-host", 16
        );
        if (session == null) {
            this.session.proxy_resolver = null;
            this.streaming_session.proxy_resolver = null;
            this.streaming_session.timeout = 0;
            this.streaming_session.idle_timeout = 0;
        }
    }

    public async ApiHttpBytesResponse send_and_read(Soup.Message message) throws Error {
        var body = yield session.send_and_read_async(message, Priority.DEFAULT, null);
        return new ApiHttpBytesResponse(message.get_status(), body);
    }

    public async ApiHttpStreamResponse send(Soup.Message message) throws Error {
        var stream = yield streaming_session.send_async(message, Priority.DEFAULT, null);
        return new ApiHttpStreamResponse(message.get_status(), stream);
    }
}

}
