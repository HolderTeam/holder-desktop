using GLib;

namespace HolderLinuxTests {

public class FakeApiHttpTransport : Object, HolderLinux.IApiHttpTransport {
    private class QueuedResponse : Object {
        public int status;
        public string body;
        public bool should_throw;
        public string throw_message;

        public QueuedResponse(int status, string body) {
            this.status = status;
            this.body = body;
            this.should_throw = false;
            this.throw_message = "";
        }

        public QueuedResponse.throwing(string message) {
            this.status = 0;
            this.body = "";
            this.should_throw = true;
            this.throw_message = message;
        }
    }

    private Gee.ArrayList<QueuedResponse> read_responses = new Gee.ArrayList<QueuedResponse>();
    private Gee.ArrayList<QueuedResponse> stream_responses = new Gee.ArrayList<QueuedResponse>();

    public string last_method = "";
    public string last_uri = "";
    public string last_accept = "";
    public string last_auth = "";
    public string last_content_type = "";

    public void enqueue_read(int status, string body) {
        read_responses.add(new QueuedResponse(status, body));
    }

    public void enqueue_read_throw(string message) {
        read_responses.add(new QueuedResponse.throwing(message));
    }

    public void enqueue_stream(int status, string body) {
        stream_responses.add(new QueuedResponse(status, body));
    }

    public void enqueue_stream_throw(string message) {
        stream_responses.add(new QueuedResponse.throwing(message));
    }

    public async HolderLinux.ApiHttpBytesResponse send_and_read(Soup.Message message) throws Error {
        remember_message(message);
        if (read_responses.size == 0) {
            throw new IOError.FAILED("No queued read response");
        }
        var response = read_responses.remove_at(0);
        if (response.should_throw) {
            throw new IOError.FAILED(response.throw_message);
        }
        return new HolderLinux.ApiHttpBytesResponse(
            (uint) response.status,
            bytes_from_string(response.body)
        );
    }

    public async HolderLinux.ApiHttpStreamResponse send(Soup.Message message) throws Error {
        remember_message(message);
        if (stream_responses.size == 0) {
            throw new IOError.FAILED("No queued stream response");
        }
        var response = stream_responses.remove_at(0);
        if (response.should_throw) {
            throw new IOError.FAILED(response.throw_message);
        }
        return new HolderLinux.ApiHttpStreamResponse(
            (uint) response.status,
            new MemoryInputStream.from_bytes(bytes_from_string(response.body))
        );
    }

    private Bytes bytes_from_string(string text) {
        uint8[] data = new uint8[text.length + 1];
        for (int i = 0; i < text.length; i++) {
            data[i] = ((uint8[]) text.data)[i];
        }
        data[text.length] = 0;
        return new Bytes.take((owned) data);
    }

    private void remember_message(Soup.Message message) {
        last_method = message.get_method();
        last_uri = message.get_uri().to_string();
        last_accept = message.request_headers.get_one("Accept") ?? "";
        last_auth = message.request_headers.get_one("Authorization") ?? "";
        HashTable<string, string>? content_type_params = null;
        var content_type = message.request_headers.get_content_type(out content_type_params);
        last_content_type = content_type ?? "";
    }
}

}
