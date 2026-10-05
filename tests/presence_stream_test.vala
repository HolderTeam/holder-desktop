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

private class Fixture : Object {
    public FakeApiHttpTransport transport = new FakeApiHttpTransport();
    public FakeServerDiscovery discovery = new FakeServerDiscovery();
    public TestScheduler scheduler = new TestScheduler();
    public HolderLinux.PresenceStream presence;
    public int changes = 0;
    public bool last_connected = false;

    public Fixture() {
        presence = new HolderLinux.PresenceStream(transport, discovery, scheduler);
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

    return Test.run();
}

}
