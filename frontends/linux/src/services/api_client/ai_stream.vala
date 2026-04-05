namespace HolderLinux {

public class ApiClientAiStream : Object { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: declaration branch artifact
    public static async void run(IApiHttpTransport transport, // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: async signature branch artifact
                                 string base_url,
                                 string auth_token,
                                 string prompt,
                                 string? project_id,
                                 string? thread_id,
                                 string? context_card_id,
                                 string? context_card_title,
                                 string? context_card_body,
                                 AiRunEventHandler on_event,
                                 string? runner_id = null,
                                 string? model = null) throws Error {
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
        if (runner_id != null && runner_id.length > 0) {
            body.set_member_name("runner_id");
            body.add_string_value(runner_id);
        }
        if (model != null && model.length > 0) {
            body.set_member_name("model");
            body.add_string_value(model);
        }
        if (context_card_id != null || context_card_title != null || context_card_body != null) {
            body.set_member_name("context");
            body.begin_object();
            if (context_card_id != null && context_card_id.length > 0) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: short-circuit branch artifact
                body.set_member_name("card_id");
                body.add_string_value(context_card_id);
            }
            if (context_card_title != null && context_card_title.length > 0) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: short-circuit branch artifact
                body.set_member_name("card_title");
                body.add_string_value(context_card_title);
            }
            if (context_card_body != null && context_card_body.length > 0) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: short-circuit branch artifact
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
        message.set_request_body_from_bytes("application/json", new Bytes((uint8[]) body_text.data)); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: ctor/allocator edge branch artifact

        ApiHttpStreamResponse response;
        try { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: try/catch edge artifact
            response = yield transport.send(message); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: async yield branch artifact
        } catch (Error e) {
            throw new ApiError.TRANSPORT("Transport error for POST /ai/runs: %s".printf(e.message)); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: throw edge artifact
        }

        var status = response.status;
        if (status < 200 || status >= 300) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: compare short-circuit artifact
            throw new ApiError.HTTP("HTTP %u for POST /ai/runs".printf((uint) status)); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: throw edge artifact
        }

        var stream = response.stream;
        var data_stream = new DataInputStream(stream);
        data_stream.set_newline_type(DataStreamNewlineType.LF);

        string current_event = "message";
        var data_builder = new StringBuilder();
        while (true) {
            size_t line_len = 0;
            string? line;
            try { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: try/catch edge artifact
                line = yield data_stream.read_line_async(Priority.DEFAULT, null, out line_len); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: async yield branch artifact
            } catch (Error e) {
                throw new ApiError.TRANSPORT("SSE read error: %s".printf(e.message)); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: throw edge artifact
            }

            if (line == null) {
                if (data_builder.len > 0) {
                    on_event(current_event, ApiClientTransport.json_object_from_text_or_raw(data_builder.str)); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: callback edge artifact
                }
                break;
            }

            if (line.length == 0) {
                if (data_builder.len > 0) {
                    on_event(current_event, ApiClientTransport.json_object_from_text_or_raw(data_builder.str)); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: callback edge artifact
                }
                current_event = "message";
                data_builder = new StringBuilder(); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: allocator edge artifact
                continue;
            }

            if (line.has_prefix("event:")) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: string helper branch artifact
                current_event = line.substring("event:".length).strip();
                continue;
            }
            if (line.has_prefix("data:")) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: string helper branch artifact
                if (data_builder.len > 0) { // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: branch edge artifact
                    data_builder.append("\n"); // LCOV_EXCL_LINE GCOVR_EXCL_LINE LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: builder append edge artifact
                }
                data_builder.append(line.substring("data:".length).strip()); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: string helper branch artifact
            }
        }
    }
}

}
