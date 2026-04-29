using GLib;

namespace HolderLinuxTests {

public class TestScheduler : Object, HolderLinux.IScheduler {
    private class OneShotTask : Object {
        public uint id;
        public SourceFunc callback;

        public OneShotTask(uint id, owned SourceFunc callback) {
            this.id = id;
            this.callback = (owned) callback;
        }
    }

    private uint next_id = 1;
    private Gee.ArrayList<OneShotTask> one_shots = new Gee.ArrayList<OneShotTask>();
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
        one_shots.add(new OneShotTask(id, (owned) callback));
        return id;
    }

    public uint schedule_repeating(uint interval_ms, owned SourceFunc callback) {
        repeating_scheduled++;
        return next_id++;
    }

    public bool cancel(uint source_id) {
        cancel_calls++;
        for (int i = 0; i < one_shots.size; i++) {
            if (one_shots[i].id == source_id) {
                one_shots.remove_at(i);
                return true;
            }
        }
        return true;
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
