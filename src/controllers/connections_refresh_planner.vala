namespace HolderLinux {

public delegate ConnectionsGraphRefreshTarget ConnectionsRefreshTargetFactory(uint content_generation);

public enum ConnectionsRefreshOutcome {
    SKIPPED_UNCHANGED,
    SUPPRESSED_HIDDEN_DUPLICATE,
    SUPPRESSED_WHILE_HIDDEN,
    COALESCED_PENDING_DUPLICATE,
    SUPPRESSED_SAME_IN_FLIGHT,
    COALESCED_DUPLICATE_AFTER_FLIGHT,
    COALESCED_AFTER_IN_FLIGHT,
    SCHEDULED
}

// Decides when a Connections graph refresh should actually run: hides while the tool is
// hidden, debounces bursts, allows one refresh in flight and coalesces the rest. The view
// performs the refresh when refresh_dispatched fires and reports back via finish_flight().
public class ConnectionsRefreshPlanner : Object {
    public const uint GRAPH_REFRESH_DEBOUNCE_MS = 100;
    public const uint PROJECT_EMPTY_STATE_DELAY_MS = 250;

    private IScheduler scheduler;
    private ConnectionsRefreshTargetFactory target_factory;
    private uint refresh_serial = 0;
    private uint graph_generation = 0;
    private uint graph_content_generation = 0;
    private bool is_tool_visible = false;
    private bool pending_refresh_when_visible = false;
    private uint pending_refresh_id = 0;
    internal bool refresh_in_flight = false;
    private bool pending_refresh_after_flight = false;
    private ConnectionsGraphRefreshTarget? pending_target = null;
    private ConnectionsGraphRefreshTarget? in_flight_target = null;
    private ConnectionsGraphRefreshTarget? committed_target = null;
    private uint committed_generation = 0;
    private uint pending_empty_state_id = 0;

    public uint content_generation {
        get { return graph_content_generation; }
    }

    public signal void debug_event(string event_name, ConnectionsGraphRefreshTarget target);
    public signal void refresh_dispatched(uint serial,
                                          uint generation,
                                          ConnectionsGraphRefreshTarget target);
    public signal void empty_state_check_due(string project_id);

    public ConnectionsRefreshPlanner(IScheduler scheduler,
                                     owned ConnectionsRefreshTargetFactory target_factory) {
        this.scheduler = scheduler;
        this.target_factory = (owned) target_factory;
    }

    public void note_content_changed() {
        graph_content_generation++;
    }

    public void set_tool_visible(bool visible) {
        if (is_tool_visible == visible) {
            return;
        }
        is_tool_visible = visible;
        if (is_tool_visible && pending_refresh_when_visible) {
            pending_refresh_when_visible = false;
            queue_refresh();
        }
    }

    public ConnectionsRefreshOutcome queue_refresh() {
        var target = target_factory(graph_content_generation);
        var target_key = target.to_key();
        if (!refresh_in_flight
            && pending_refresh_id == 0
            && !pending_refresh_when_visible
            && committed_target != null
            && committed_target.to_key() == target_key
            && committed_generation == graph_generation) {
            debug_event("skipped unchanged target", target);
            return ConnectionsRefreshOutcome.SKIPPED_UNCHANGED;
        }
        if (!is_tool_visible) {
            if (pending_refresh_when_visible
                && pending_target != null
                && pending_target.to_key() == target_key) {
                debug_event("suppressed hidden duplicate", target);
                return ConnectionsRefreshOutcome.SUPPRESSED_HIDDEN_DUPLICATE;
            }
            graph_generation++;
            pending_refresh_when_visible = true;
            pending_target = target;
            debug_event("suppressed while hidden", target);
            return ConnectionsRefreshOutcome.SUPPRESSED_WHILE_HIDDEN;
        }
        pending_refresh_when_visible = false;
        if (pending_refresh_id != 0
            && pending_target != null
            && pending_target.to_key() == target_key) {
            debug_event("coalesced pending duplicate", target);
            return ConnectionsRefreshOutcome.COALESCED_PENDING_DUPLICATE;
        }
        if (refresh_in_flight) {
            if (in_flight_target != null && in_flight_target.to_key() == target_key) {
                debug_event("suppressed same target in flight", target);
                return ConnectionsRefreshOutcome.SUPPRESSED_SAME_IN_FLIGHT;
            }
            if (pending_refresh_after_flight
                && pending_target != null
                && pending_target.to_key() == target_key) {
                debug_event("coalesced duplicate after flight", target);
                return ConnectionsRefreshOutcome.COALESCED_DUPLICATE_AFTER_FLIGHT;
            }
            graph_generation++;
            pending_refresh_after_flight = true;
            pending_target = target;
            debug_event("coalesced after in-flight refresh", target);
            return ConnectionsRefreshOutcome.COALESCED_AFTER_IN_FLIGHT;
        }
        if (pending_refresh_id != 0) {
            scheduler.cancel(pending_refresh_id);
            pending_refresh_id = 0;
        }
        graph_generation++;
        pending_target = target;
        pending_refresh_id = scheduler.schedule_once(GRAPH_REFRESH_DEBOUNCE_MS, () => {
            dispatch(target);
            return Source.REMOVE;
        });
        return ConnectionsRefreshOutcome.SCHEDULED;
    }

    private void dispatch(ConnectionsGraphRefreshTarget fallback_target) {
        var dispatch_target = pending_target;
        pending_refresh_id = 0;
        pending_target = null;
        if (refresh_in_flight) {
            pending_refresh_after_flight = true;
            if (dispatch_target != null) {
                debug_event("coalesced at debounce dispatch", dispatch_target);
            }
            return;
        }
        clear_pending_empty_state();
        refresh_serial++;
        refresh_in_flight = true;
        in_flight_target = dispatch_target;
        refresh_dispatched(refresh_serial, graph_generation, dispatch_target ?? fallback_target);
    }

    public bool drop_if_stale(uint serial,
                              uint generation,
                              ConnectionsGraphRefreshTarget target,
                              string reason) {
        if (serial != refresh_serial || generation != graph_generation) {
            debug_event(reason, target);
            return true;
        }
        return false;
    }

    public void report_dropped(ConnectionsGraphRefreshTarget target, string reason) {
        debug_event(reason, target);
    }

    public void record_committed(ConnectionsGraphRefreshTarget target, uint generation) {
        committed_target = target;
        committed_generation = generation;
    }

    public void finish_flight() {
        refresh_in_flight = false;
        in_flight_target = null;
        if (pending_refresh_after_flight) {
            pending_refresh_after_flight = false;
            queue_refresh();
        }
    }

    public void clear_pending_empty_state() {
        if (pending_empty_state_id != 0) {
            scheduler.cancel(pending_empty_state_id);
            pending_empty_state_id = 0;
        }
    }

    public void schedule_empty_state_check(string project_id) {
        clear_pending_empty_state();
        var expected_generation = graph_generation;
        pending_empty_state_id = scheduler.schedule_once(PROJECT_EMPTY_STATE_DELAY_MS, () => {
            pending_empty_state_id = 0;
            if (expected_generation != graph_generation) {
                return Source.REMOVE;
            }
            empty_state_check_due(project_id);
            return Source.REMOVE;
        });
    }
}

}
