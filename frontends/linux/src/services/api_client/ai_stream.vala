namespace HolderLinux {

public class ApiClientAiStream : Object {
    public static async void run(IApiHttpTransport transport,
                                 string base_url,
                                 string auth_token,
                                 string prompt,
                                 string? project_id,
                                 string? thread_id,
                                 string? context_card_id,
                                 string? context_card_title,
                                 string? context_card_body,
                                 AiRunEventHandler on_event) throws Error {
        var body = new Json.Builder();
        body.begin_object();
        body.set_member_name("prompt");
        body.add_string_value(prompt);
        if (project_id != null && project_id.length > 0) {
            body.set_member_name("project_id");
            body.add_string_value(project_id);
        }
        if (thread_id != null && thread_id.length > 0) {
            body.set_member_name("thread_id");
            body.add_string_value(thread_id);
        }
        if (context_card_id != null || context_card_title != null || context_card_body != null) {
            body.set_member_name("context");
            body.begin_object();
            if (context_card_id != null && context_card_id.length > 0) {
                body.set_member_name("card_id");
                body.add_string_value(context_card_id);
            }
            if (context_card_title != null && context_card_title.length > 0) {
                body.set_member_name("card_title");
                body.add_string_value(context_card_title);
            }
            if (context_card_body != null && context_card_body.length > 0) {
                body.set_member_name("card_body");
                body.add_string_value(context_card_body);
            }
            body.end_object();
        }
        body.end_object();

        var message = new Soup.Message("POST", base_url + "/ai/runs");
        message.request_headers.append("Authorization", "Bearer %s".printf(auth_token));
        message.request_headers.append("Accept", "text/event-stream");
        var body_text = ApiClientTransport.json_string_from_builder(body);
        message.set_request_body_from_bytes("application/json", new Bytes((uint8[]) body_text.data));

        ApiHttpStreamResponse response;
        try {
            response = yield transport.send(message);
        } catch (Error e) {
            throw new ApiError.TRANSPORT("Transport error for POST /ai/runs: %s".printf(e.message));
        }

        var status = response.status;
        if (status < 200 || status >= 300) {
            throw new ApiError.HTTP("HTTP %u for POST /ai/runs".printf((uint) status));
        }

        var stream = response.stream;
        var data_stream = new DataInputStream(stream);
        data_stream.set_newline_type(DataStreamNewlineType.LF);

        string current_event = "message";
        var data_builder = new StringBuilder();
        while (true) {
            size_t line_len = 0;
            string? line;
            try {
                line = yield data_stream.read_line_async(Priority.DEFAULT, null, out line_len);
            } catch (Error e) {
                throw new ApiError.TRANSPORT("SSE read error: %s".printf(e.message));
            }

            if (line == null) {
                if (data_builder.len > 0) {
                    on_event(current_event, ApiClientTransport.json_object_from_text_or_raw(data_builder.str));
                }
                break;
            }

            if (line.length == 0) {
                if (data_builder.len > 0) {
                    on_event(current_event, ApiClientTransport.json_object_from_text_or_raw(data_builder.str));
                }
                current_event = "message";
                data_builder = new StringBuilder();
                continue;
            }

            if (line.has_prefix("event:")) {
                current_event = line.substring("event:".length).strip();
                continue;
            }
            if (line.has_prefix("data:")) {
                if (data_builder.len > 0) {
                    data_builder.append("\n");
                }
                data_builder.append(line.substring("data:".length).strip());
            }
        }
    }
}

}
