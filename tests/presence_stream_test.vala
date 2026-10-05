using GLib;

namespace HolderLinuxTests {

private class FakeServerDiscovery : Object, HolderLinux.IServerDiscovery {
    public HolderLinux.ServerInfo info = new HolderLinux.ServerInfo(1, "127.0.0.1", 8080, 1, "0.1", "0.1", "token");
    public bool should_fail = false;

    public HolderLinux.ServerInfo discover_server() throws Error {
        if (should_fail) {
            throw new IOError.FAILED("discovery failed");
        }
        return info;
    }

    public string holder_info_path() {
        return "/tmp/holder.json";
    }
}

// A backend that accepts the request and then never answers.
private class HangingTransport : Object, HolderLinux.IApiHttpTransport {
    public async HolderLinux.ApiHttpBytesResponse send_and_read(Soup.Message message) throws Error {
        Timeout.add(5000, () => {
            send_and_read.callback();
            return Source.REMOVE;
        });
        yield;
        throw new IOError.TIMED_OUT("never answered");
    }

    public async HolderLinux.ApiHttpStreamResponse send(Soup.Message message) throws Error {
        throw new IOError.FAILED("not used");
    }
}

private class Fixture : Object {
    public FakeApiHttpTransport transport = new FakeApiHttpTransport();
    public FakeServerDiscovery discovery = new FakeServerDiscovery();
    public TestScheduler scheduler = new TestScheduler();
    public HolderLinux.PresenceStream presence;
    public string[] log = {};
    public int changes = 0;
    public bool last_connected = false;

    public Fixture() {
        presence = new HolderLinux.PresenceStream(transport, discovery, scheduler);
        presence.debug_log_requested.connect((line) => {
            log += line;
        });
        presence.connection_changed.connect((connected) => {
            changes++;
            last_connected = connected;
        });
    }
}

private void test_holds_the_events_stream_with_the_bearer_token() {
    var f = new Fixture();
    f.transport.enqueue_stream(200, ": heartbeat\n\nevent: ready\ndata: {}\n\n");

    f.presence.start();

    // The fake stream ends at once, so the connection came and went.
    assert(wait_for_condition(() => f.scheduler.pending_one_shots() == 1));
    assert(f.transport.last_method == "GET");
    assert(f.transport.last_uri == "http://127.0.0.1:8080/events");
    assert(f.transport.last_accept == "text/event-stream");
    assert(f.transport.last_auth == "Bearer token");
    assert(f.changes == 2);
    assert(!f.last_connected);
    f.presence.stop();
}

private void test_retries_with_a_growing_delay_when_the_connection_fails() {
    var f = new Fixture();
    f.transport.enqueue_stream_throw("refused");
    f.transport.enqueue_stream_throw("refused");
    f.transport.enqueue_stream_throw("refused");

    f.presence.start();
    assert(wait_for_condition(() => f.scheduler.pending_with_delay(1000) == 1));
    f.scheduler.run_due(1000);
    assert(wait_for_condition(() => f.scheduler.pending_with_delay(2000) == 1));
    f.scheduler.run_due(2000);
    assert(wait_for_condition(() => f.scheduler.pending_with_delay(4000) == 1));
    assert(f.changes == 0);
    f.presence.stop();
}

private void test_delay_is_capped() {
    var f = new Fixture();
    for (int i = 0; i < 8; i++) {
        f.transport.enqueue_stream_throw("refused");
    }
    f.presence.start();
    uint[] expected = { 1000, 2000, 4000, 8000, 10000, 10000 };
    foreach (var delay in expected) {
        assert(wait_for_condition(() => f.scheduler.pending_with_delay(delay) == 1));
        f.scheduler.run_due(delay);
    }
    f.presence.stop();
}

private void test_a_failing_status_is_retried_and_not_reported_connected() {
    var f = new Fixture();
    f.transport.enqueue_stream(401, "unauthorized");

    f.presence.start();

    assert(wait_for_condition(() => f.scheduler.pending_one_shots() == 1));
    assert(f.changes == 0);
    f.presence.stop();
}

private void test_looks_the_daemon_up_again_on_each_attempt() {
    var f = new Fixture();
    f.transport.enqueue_stream_throw("refused");
    f.transport.enqueue_stream_throw("refused");

    f.presence.start();
    assert(wait_for_condition(() => f.scheduler.pending_with_delay(1000) == 1));

    // The daemon restarted on another port with a new token.
    f.discovery.info = new HolderLinux.ServerInfo(2, "127.0.0.1", 9090, 2, "0.1", "0.1", "token-2");
    f.scheduler.run_due(1000);
    assert(wait_for_condition(() => f.scheduler.pending_with_delay(2000) == 1));
    assert(f.transport.last_uri == "http://127.0.0.1:9090/events");
    assert(f.transport.last_auth == "Bearer token-2");
    f.presence.stop();
}

private void test_a_missing_daemon_is_retried() {
    var f = new Fixture();
    f.discovery.should_fail = true;

    f.presence.start();

    assert(wait_for_condition(() => f.scheduler.pending_with_delay(1000) == 1));
    f.presence.stop();
}

private void test_stop_cancels_the_retry_and_nothing_follows() {
    var f = new Fixture();
    f.transport.enqueue_stream_throw("refused");
    f.presence.start();
    assert(wait_for_condition(() => f.scheduler.pending_one_shots() == 1));

    f.presence.stop();

    assert(f.scheduler.pending_one_shots() == 0);
    assert(f.scheduler.cancel_calls == 1);
}

private void test_start_twice_connects_once() {
    var f = new Fixture();
    f.transport.enqueue_stream_throw("refused");
    f.presence.start();
    f.presence.start();

    assert(wait_for_condition(() => f.scheduler.pending_one_shots() == 1));
    f.presence.stop();
}

private bool log_has(string[] log, string fragment) {
    foreach (var line in log) {
        if (line.contains(fragment)) {
            return true;
        }
    }
    return false;
}

private void test_logs_what_it_is_doing_for_the_debug_panel() {
    var f = new Fixture();
    f.transport.enqueue_stream(200, "event: ready\ndata: {}\n\n");

    f.presence.start();

    assert(wait_for_condition(() => f.scheduler.pending_one_shots() == 1));
    assert(log_has(f.log, "PRESENCE connecting to http://127.0.0.1:8080/events"));
    assert(log_has(f.log, "PRESENCE connected (HTTP 200)"));
    assert(log_has(f.log, "PRESENCE reconnecting in 1000 ms"));
    f.presence.stop();
}

private int count_lines(string[] log, string fragment) {
    int count = 0;
    foreach (var line in log) {
        if (line.contains(fragment)) {
            count++;
        }
    }
    return count;
}

private void test_logs_once_when_heartbeats_arrive() {
    var f = new Fixture();
    f.transport.enqueue_stream(200, ": heartbeat\n\n: heartbeat\n\n: heartbeat\n\n");

    f.presence.start();

    assert(wait_for_condition(() => f.scheduler.pending_one_shots() == 1));
    assert(count_lines(f.log, "PRESENCE receiving heartbeats") == 1);
    assert(count_lines(f.log, "PRESENCE receiving events") == 0);
    f.presence.stop();
}

private void test_logs_once_when_events_arrive() {
    var f = new Fixture();
    f.transport.enqueue_stream(200, "event: ready\ndata: {}\n\nevent: card.changed\ndata: {}\n\n");

    f.presence.start();

    assert(wait_for_condition(() => f.scheduler.pending_one_shots() == 1));
    assert(count_lines(f.log, "PRESENCE receiving events") == 1);
    assert(count_lines(f.log, "PRESENCE receiving heartbeats") == 0);
    f.presence.stop();
}

private void test_logs_events_and_heartbeats_separately_each_once() {
    var f = new Fixture();
    f.transport.enqueue_stream(
        200,
        "event: ready\ndata: {}\n\n: heartbeat\n\nevent: card.changed\ndata: {}\n\n: heartbeat\n\n");

    f.presence.start();

    assert(wait_for_condition(() => f.scheduler.pending_one_shots() == 1));
    assert(count_lines(f.log, "PRESENCE receiving events") == 1);
    assert(count_lines(f.log, "PRESENCE receiving heartbeats") == 1);
    f.presence.stop();
}

private void test_logs_again_on_a_new_connection() {
    var f = new Fixture();
    f.transport.enqueue_stream(200, "event: ready\ndata: {}\n\n: heartbeat\n\n");
    f.transport.enqueue_stream(200, "event: ready\ndata: {}\n\n: heartbeat\n\n");

    f.presence.start();
    assert(wait_for_condition(() => f.scheduler.pending_with_delay(1000) == 1));
    f.scheduler.run_due(1000);
    assert(wait_for_condition(() => count_lines(f.log, "PRESENCE receiving heartbeats") == 2));

    assert(count_lines(f.log, "PRESENCE receiving events") == 2);
    f.presence.stop();
}

private void test_logs_nothing_about_data_when_the_stream_is_empty() {
    var f = new Fixture();
    f.transport.enqueue_stream(200, "");

    f.presence.start();

    assert(wait_for_condition(() => f.scheduler.pending_one_shots() == 1));
    assert(count_lines(f.log, "PRESENCE connected") == 1);
    assert(count_lines(f.log, "PRESENCE receiving") == 0);
    f.presence.stop();
}

private void test_leaving_posts_a_goodbye_with_the_bearer_token() {
    var f = new Fixture();
    f.transport.enqueue_read(200, "{\"ok\":true}");

    f.presence.leave(1000);

    assert(f.transport.last_method == "POST");
    assert(f.transport.last_uri == "http://127.0.0.1:8080/bye");
    assert(f.transport.last_auth == "Bearer token");
    assert(log_has(f.log, "PRESENCE goodbye sent (HTTP 200)"));
}

private void test_leaving_lets_go_of_the_stream_and_cancels_retries() {
    var f = new Fixture();
    f.transport.enqueue_stream_throw("refused");
    f.transport.enqueue_read(200, "{\"ok\":true}");
    f.presence.start();
    assert(wait_for_condition(() => f.scheduler.pending_one_shots() == 1));

    f.presence.leave(1000);

    assert(f.scheduler.pending_one_shots() == 0);
    assert(!f.presence.is_connected);
}

private void test_leaving_swallows_a_failure() {
    var f = new Fixture();
    f.transport.enqueue_read_throw("connection refused");

    f.presence.leave(1000);

    assert(log_has(f.log, "PRESENCE goodbye not sent: connection refused"));
}

private void test_leaving_swallows_an_old_backend_that_does_not_know_it() {
    var f = new Fixture();
    f.transport.enqueue_read(404, "{\"ok\":false}");

    f.presence.leave(1000);

    assert(log_has(f.log, "PRESENCE goodbye sent (HTTP 404)"));
}

private void test_leaving_without_a_daemon_does_not_fail() {
    var f = new Fixture();
    f.discovery.should_fail = true;

    f.presence.leave(1000);

    assert(log_has(f.log, "PRESENCE goodbye not sent: discovery failed"));
}

private void test_leaving_gives_up_when_the_backend_does_not_answer() {
    var transport = new HangingTransport();
    var discovery = new FakeServerDiscovery();
    var scheduler = new TestScheduler();
    var presence = new HolderLinux.PresenceStream(transport, discovery, scheduler);
    string[] log = {};
    presence.debug_log_requested.connect((line) => {
        log += line;
    });

    var started = get_monotonic_time();
    presence.leave(150);
    var elapsed_ms = (get_monotonic_time() - started) / 1000;

    assert(elapsed_ms >= 100);
    assert(elapsed_ms < 2000);
    assert(log_has(log, "PRESENCE goodbye got no answer within 150 ms"));
}

private void test_leaving_twice_says_goodbye_once() {
    var f = new Fixture();
    f.transport.enqueue_read(200, "{\"ok\":true}");
    f.transport.enqueue_read(200, "{\"ok\":true}");

    f.presence.leave(1000);
    f.presence.leave(1000);

    assert(count_lines(f.log, "PRESENCE goodbye sent") == 1);
}

private void test_logs_why_a_connection_failed() {
    var f = new Fixture();
    f.transport.enqueue_stream_throw("connection refused");
    f.presence.start();

    assert(wait_for_condition(() => f.scheduler.pending_one_shots() == 1));
    assert(log_has(f.log, "PRESENCE stream ended: connection refused"));
    f.presence.stop();
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/presence_stream/holds_the_events_stream", test_holds_the_events_stream_with_the_bearer_token);
    Test.add_func("/presence_stream/retries_with_growing_delay", test_retries_with_a_growing_delay_when_the_connection_fails);
    Test.add_func("/presence_stream/delay_is_capped", test_delay_is_capped);
    Test.add_func("/presence_stream/failing_status_is_retried", test_a_failing_status_is_retried_and_not_reported_connected);
    Test.add_func("/presence_stream/looks_the_daemon_up_again", test_looks_the_daemon_up_again_on_each_attempt);
    Test.add_func("/presence_stream/missing_daemon_is_retried", test_a_missing_daemon_is_retried);
    Test.add_func("/presence_stream/stop_cancels_the_retry", test_stop_cancels_the_retry_and_nothing_follows);
    Test.add_func("/presence_stream/start_twice_connects_once", test_start_twice_connects_once);

    Test.add_func("/presence_stream/logs_what_it_is_doing", test_logs_what_it_is_doing_for_the_debug_panel);
    Test.add_func("/presence_stream/logs_once_when_heartbeats_arrive", test_logs_once_when_heartbeats_arrive);
    Test.add_func("/presence_stream/logs_once_when_events_arrive", test_logs_once_when_events_arrive);
    Test.add_func("/presence_stream/logs_events_and_heartbeats_separately", test_logs_events_and_heartbeats_separately_each_once);
    Test.add_func("/presence_stream/logs_again_on_a_new_connection", test_logs_again_on_a_new_connection);
    Test.add_func("/presence_stream/logs_nothing_for_an_empty_stream", test_logs_nothing_about_data_when_the_stream_is_empty);
    Test.add_func("/presence_stream/leaving_posts_a_goodbye", test_leaving_posts_a_goodbye_with_the_bearer_token);
    Test.add_func("/presence_stream/leaving_lets_go_of_the_stream", test_leaving_lets_go_of_the_stream_and_cancels_retries);
    Test.add_func("/presence_stream/leaving_swallows_a_failure", test_leaving_swallows_a_failure);
    Test.add_func("/presence_stream/leaving_swallows_an_old_backend", test_leaving_swallows_an_old_backend_that_does_not_know_it);
    Test.add_func("/presence_stream/leaving_without_a_daemon", test_leaving_without_a_daemon_does_not_fail);
    Test.add_func("/presence_stream/leaving_gives_up_without_an_answer", test_leaving_gives_up_when_the_backend_does_not_answer);
    Test.add_func("/presence_stream/leaving_twice_says_goodbye_once", test_leaving_twice_says_goodbye_once);
    Test.add_func("/presence_stream/logs_why_a_connection_failed", test_logs_why_a_connection_failed);

    return Test.run();
}

}
