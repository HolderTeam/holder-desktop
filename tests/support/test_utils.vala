using GLib;

namespace HolderLinuxTests {

public class TestScheduler : Object, HolderLinux.IScheduler {
    private class OneShotTask : Object {
        public uint id;
        public uint delay_ms;
        public SourceFunc callback;

        public OneShotTask(uint id, uint delay_ms, owned SourceFunc callback) {
            this.id = id;
            this.delay_ms = delay_ms;
            this.callback = (owned) callback;
        }
    }

    private class RepeatingTask : Object {
        public uint id;
        public uint interval_ms;
        public SourceFunc callback;

        public RepeatingTask(uint id, uint interval_ms, owned SourceFunc callback) {
            this.id = id;
            this.interval_ms = interval_ms;
            this.callback = (owned) callback;
        }
    }

    private uint next_id = 1;
    private Gee.ArrayList<OneShotTask> one_shots = new Gee.ArrayList<OneShotTask>();
    private Gee.ArrayList<RepeatingTask> repeating = new Gee.ArrayList<RepeatingTask>();
    private bool immediate_once;

    public int repeating_scheduled = 0;
    public int cancel_calls = 0;

    public TestScheduler(bool immediate_once = false) {
        this.immediate_once = immediate_once;
    }

    public uint schedule_once(uint delay_ms, owned SourceFunc callback) {
        var id = next_id++;
        if (immediate_once) {
            Idle.add(() => {
                callback();
                return Source.REMOVE;
            });
            return id;
        }
        one_shots.add(new OneShotTask(id, delay_ms, (owned) callback));
        return id;
    }

    public uint schedule_repeating(uint interval_ms, owned SourceFunc callback) {
        repeating_scheduled++;
        var id = next_id++;
        repeating.add(new RepeatingTask(id, interval_ms, (owned) callback));
        return id;
    }

    public bool cancel(uint source_id) {
        cancel_calls++;
        for (int i = 0; i < repeating.size; i++) {
            if (repeating[i].id == source_id) {
                repeating.remove_at(i);
                return true;
            }
        }
        for (int i = 0; i < one_shots.size; i++) {
            if (one_shots[i].id == source_id) {
                one_shots.remove_at(i);
                return true;
            }
        }
        return true;
    }

    public int pending_repeating() {
        return repeating.size;
    }

    // Runs every pending repeating task once, and drops the ones whose callback asks to be
    // removed (returns Source.REMOVE), like a GLib timeout. Returns how many ran.
    public int tick_repeating() {
        var tasks = new Gee.ArrayList<RepeatingTask>();
        tasks.add_all(repeating);
        foreach (var task in tasks) {
            if (!task.callback()) {
                repeating.remove(task);
            }
        }
        return tasks.size;
    }

    public int pending_one_shots() {
        return one_shots.size;
    }

    // How many pending one-shots were scheduled with exactly this delay.
    public int pending_with_delay(uint delay_ms) {
        int count = 0;
        foreach (var task in one_shots) {
            if (task.delay_ms == delay_ms) {
                count++;
            }
        }
        return count;
    }

    // Runs, and removes, the pending one-shots whose delay is at most max_delay_ms, so a test can
    // fire a short debounce without also firing a longer timer. Returns how many ran.
    public int run_due(uint max_delay_ms) {
        var tasks = new Gee.ArrayList<OneShotTask>();
        foreach (var task in one_shots) {
            if (task.delay_ms <= max_delay_ms) {
                tasks.add(task);
            }
        }
        foreach (var task in tasks) {
            one_shots.remove(task);
        }
        foreach (var task in tasks) {
            task.callback();
        }
        return tasks.size;
    }

    public void run_all_once() {
        var tasks = new Gee.ArrayList<OneShotTask>();
        foreach (var task in one_shots) {
            tasks.add(task);
        }
        one_shots.clear();
        foreach (var task in tasks) {
            task.callback();
        }
    }
}

public delegate bool ConditionFunc();

public bool wait_for_condition(ConditionFunc condition, uint timeout_ms = 1500) {
    var loop = new MainLoop();
    uint timeout_id = 0;
    uint poll_id = 0;
    bool ok = false;

    poll_id = Timeout.add(10, () => {
        if (condition()) {
            ok = true;
            poll_id = 0;
            loop.quit();
            return Source.REMOVE;
        }
        return Source.CONTINUE;
    });
    timeout_id = Timeout.add(timeout_ms, () => {
        timeout_id = 0;
        loop.quit();
        return Source.REMOVE;
    });

    loop.run();
    if (timeout_id != 0) {
        Source.remove(timeout_id);
    }
    if (poll_id != 0) {
        Source.remove(poll_id);
    }
    return ok;
}

}
