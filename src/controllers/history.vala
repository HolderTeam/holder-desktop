namespace HolderLinux {

// Read access to what the History tool is currently scoped to. The view backs it with its
// selection models; flows use it to drop results that arrive after the selection moved on.
public interface IHistoryScope : Object {
    public abstract Project? current_project();
    public abstract CardSummary? current_card();
}

public enum HistoryRefreshPlan {
    NO_PROJECT,
    PROJECT_UNAVAILABLE,
    LOAD_PROJECT,
    CARD_UNAVAILABLE,
    LOAD_CARD
}

public class ProjectHistoryLoad : Object {
    public bool stale { get; construct; }
    public string? error_message { get; construct; }
    public ProjectHistoryPage? page { get; construct; }
    public string? debug_line { get; construct; }

    public ProjectHistoryLoad(bool stale,
                              ProjectHistoryPage? page,
                              string? error_message,
                              string? debug_line) {
        Object(stale: stale, page: page, error_message: error_message, debug_line: debug_line);
    }
}

public class CardHistoryLoad : Object {
    public bool stale { get; construct; }
    public string? error_message { get; construct; }
    public CardHistoryPage? page { get; construct; }
    public string? debug_line { get; construct; }

    public CardHistoryLoad(bool stale,
                           CardHistoryPage? page,
                           string? error_message,
                           string? debug_line) {
        Object(stale: stale, page: page, error_message: error_message, debug_line: debug_line);
    }
}

public enum HistoryComparisonKind {
    SKIP,
    CURRENT_VERSION,
    LOAD
}

public class HistoryComparisonPlan : Object {
    public HistoryComparisonKind kind { get; construct; }
    public HistoryComparisonMode mode { get; construct; }
    public string? from_oid { get; construct; }
    public string to_oid { get; construct; }
    public string project_id { get; construct; }
    public string card_id { get; construct; }
    public string head_oid { get; construct; }

    public HistoryComparisonPlan(HistoryComparisonKind kind,
                                 HistoryComparisonMode mode,
                                 string? from_oid,
                                 string to_oid,
                                 string project_id,
                                 string card_id,
                                 string head_oid) {
        Object(
            kind: kind,
            mode: mode,
            from_oid: from_oid,
            to_oid: to_oid,
            project_id: project_id,
            card_id: card_id,
            head_oid: head_oid
        );
    }
}

public class HistoryComparisonLoad : Object {
    public bool stale { get; construct; }
    public CardHistoryComparison? comparison { get; construct; }
    public HistoryDetailText? detail { get; construct; }
    public string? debug_line { get; construct; }
    public bool failed { get; construct; }

    public HistoryComparisonLoad(bool stale,
                                 bool failed,
                                 CardHistoryComparison? comparison,
                                 HistoryDetailText? detail,
                                 string? debug_line) {
        Object(
            stale: stale,
            failed: failed,
            comparison: comparison,
            detail: detail,
            debug_line: debug_line
        );
    }
}

public class HistoryRestorePlan : Object {
    public string project_id { get; construct; }
    public string card_id { get; construct; }
    public string oid { get; construct; }

    public HistoryRestorePlan(string project_id, string card_id, string oid) {
        Object(project_id: project_id, card_id: card_id, oid: oid);
    }
}

public enum HistoryRestoreOutcome {
    RESTORED,
    SELECTION_CHANGED,
    FAILED
}

public class HistoryRestoreResult : Object {
    public HistoryRestoreOutcome outcome { get; construct; }
    public string project_id { get; construct; }
    public string card_id { get; construct; }
    public string? error_message { get; construct; }
    public string? debug_line { get; construct; }
    // For a failed restore: whether the Restore button should be usable again.
    public bool restore_enabled { get; construct; }

    public HistoryRestoreResult(HistoryRestoreOutcome outcome,
                                string project_id,
                                string card_id,
                                string? error_message,
                                string? debug_line,
                                bool restore_enabled) {
        Object(
            outcome: outcome,
            project_id: project_id,
            card_id: card_id,
            error_message: error_message,
            debug_line: debug_line,
            restore_enabled: restore_enabled
        );
    }
}

public class HistoryOlderPlan : Object {
    public string project_id { get; construct; }
    public string card_id { get; construct; }
    public string cursor { get; construct; }
    public uint serial { get; construct; }

    public HistoryOlderPlan(string project_id, string card_id, string cursor, uint serial) {
        Object(project_id: project_id, card_id: card_id, cursor: cursor, serial: serial);
    }
}

public enum HistoryOlderOutcome {
    APPENDED,
    DROPPED,
    FAILED
}

public class HistoryOlderResult : Object {
    public HistoryOlderOutcome outcome { get; construct; }
    public CardHistoryPage? page { get; construct; }
    public string? error_message { get; construct; }
    public string? debug_line { get; construct; }
    // True when the timeline has not been refreshed meanwhile, so the Load older button
    // should be brought back in line with the cursor.
    public bool refresh_button { get; construct; }

    public HistoryOlderResult(HistoryOlderOutcome outcome,
                              CardHistoryPage? page,
                              string? error_message,
                              string? debug_line,
                              bool refresh_button) {
        Object(
            outcome: outcome,
            page: page,
            error_message: error_message,
            debug_line: debug_line,
            refresh_button: refresh_button
        );
    }
}

public class ProjectHistoryOlderResult : Object {
    public ProjectHistoryPage? page { get; construct; }
    public string? error_message { get; construct; }

    public ProjectHistoryOlderResult(ProjectHistoryPage? page, string? error_message) {
        Object(page: page, error_message: error_message);
    }
}

// Owns the History tool's paging cursors, the head it is comparing against, and the serial
// guards that discard answers for a selection or refresh that has since been replaced.
public class HistoryController : Object {
    public const int PAGE_SIZE = 50;

    private uint refresh_serial = 0;
    private uint comparison_serial = 0;

    public string? captured_head_oid { get; private set; default = null; }
    public string? next_cursor { get; private set; default = null; }
    public bool scan_limited { get; private set; default = false; }
    public string? project_next_cursor { get; private set; default = null; }
    public CardHistoryEntry? detail_entry { get; set; default = null; }

    // Invalidates every in-flight load and returns the serial for the refresh about to start.
    public uint begin_refresh() {
        refresh_serial++;
        comparison_serial++;
        return refresh_serial;
    }

    public void reset_card_timeline() {
        captured_head_oid = null;
        next_cursor = null;
        scan_limited = false;
    }

    public void reset_project_timeline() {
        project_next_cursor = null;
    }

    public static HistoryRefreshPlan plan_refresh(Project? project,
                                                  CardSummary? card,
                                                  bool has_history_api,
                                                  bool has_project_history_api) {
        if (project == null) return HistoryRefreshPlan.NO_PROJECT;
        if (card == null || card.project_id != ((!) project).project_id) {
            return has_project_history_api
                ? HistoryRefreshPlan.LOAD_PROJECT
                : HistoryRefreshPlan.PROJECT_UNAVAILABLE;
        }
        return has_history_api ? HistoryRefreshPlan.LOAD_CARD : HistoryRefreshPlan.CARD_UNAVAILABLE;
    }

    public async ProjectHistoryLoad load_project_page(IProjectHistoryApi api,
                                                      string project_id,
                                                      string? kind,
                                                      uint serial) {
        try {
            var page = yield api.list_project_history(project_id, PAGE_SIZE, null, kind);
            if (serial != refresh_serial) return new ProjectHistoryLoad(true, null, null, null);
            project_next_cursor = page.next_cursor;
            return new ProjectHistoryLoad(
                false, page, null, HistoryPresenter.project_loaded_debug(page)
            );
        } catch (Error e) {
            if (serial != refresh_serial) return new ProjectHistoryLoad(true, null, null, null);
            return new ProjectHistoryLoad(false, null, e.message, null);
        }
    }

    public async CardHistoryLoad load_card_page(IHistoryApi api,
                                                string project_id,
                                                string card_id,
                                                uint serial) {
        try {
            var page = yield api.list_card_history(project_id, card_id);
            if (serial != refresh_serial) return new CardHistoryLoad(true, null, null, null);
            captured_head_oid = page.head_oid;
            next_cursor = page.next_cursor;
            scan_limited = page.scan_limited;
            return new CardHistoryLoad(false, page, null, HistoryPresenter.card_loaded_debug(page));
        } catch (Error e) {
            if (serial != refresh_serial) return new CardHistoryLoad(true, null, null, null);
            reset_card_timeline();
            return new CardHistoryLoad(
                false, null, e.message, "History load failed: %s".printf(e.message)
            );
        }
    }

    // ---- comparison ----

    // Remembers the entry being shown and returns the serial for its comparison request.
    public uint begin_comparison(CardHistoryEntry entry) {
        detail_entry = entry;
        comparison_serial++;
        return comparison_serial;
    }

    public HistoryComparisonPlan plan_comparison(IHistoryScope scope,
                                                 bool has_api,
                                                 CardHistoryEntry entry,
                                                 HistoryComparisonMode mode) {
        var project = scope.current_project();
        var card = scope.current_card();
        if (!has_api || project == null || card == null || captured_head_oid == null) {
            return new HistoryComparisonPlan(
                HistoryComparisonKind.SKIP, mode, null, "", "", "", ""
            );
        }
        var head = (!) captured_head_oid;
        var endpoints = HistoryPresenter.endpoints(mode, entry, head);
        var kind = HistoryPresenter.is_current_version(mode, entry, head)
            ? HistoryComparisonKind.CURRENT_VERSION
            : HistoryComparisonKind.LOAD;
        return new HistoryComparisonPlan(
            kind, mode, endpoints.from_oid, endpoints.to_oid,
            ((!) project).project_id, ((!) card).card_id, head
        );
    }

    public async HistoryComparisonLoad load_comparison(IHistoryApi api,
                                                       IHistoryScope scope,
                                                       CardHistoryEntry entry,
                                                       HistoryComparisonPlan plan,
                                                       uint serial) {
        try {
            var comparison = yield api.compare_card_history(
                plan.project_id, plan.card_id, plan.from_oid, plan.to_oid,
                HistoryPresenter.api_mode(plan.mode)
            );
            var current_project = scope.current_project();
            var current_card = scope.current_card();
            if (serial != comparison_serial || captured_head_oid != plan.head_oid ||
                current_project == null || current_card == null ||
                ((!) current_project).project_id != plan.project_id ||
                ((!) current_card).card_id != plan.card_id) {
                return new HistoryComparisonLoad(true, false, null, null, null);
            }
            return new HistoryComparisonLoad(
                false, false, comparison,
                HistoryPresenter.loaded_detail(plan.mode, entry, comparison),
                HistoryPresenter.compared_debug(plan.from_oid, plan.to_oid, plan.mode, comparison)
            );
        } catch (Error e) {
            if (serial != comparison_serial) return new HistoryComparisonLoad(true, false, null, null, null);
            return new HistoryComparisonLoad(
                false, true, null,
                HistoryPresenter.failed_detail(e.message),
                "History comparison failed: %s".printf(e.message)
            );
        }
    }

    // ---- restore ----

    public HistoryRestorePlan? plan_restore(IHistoryScope scope, bool has_api, string oid) {
        var project = scope.current_project();
        var card = scope.current_card();
        if (!has_api || project == null || card == null) return null;
        return new HistoryRestorePlan(((!) project).project_id, ((!) card).card_id, oid);
    }

    public async HistoryRestoreResult restore_version(IHistoryApi api,
                                                      IHistoryScope scope,
                                                      HistoryRestorePlan plan) {
        try {
            yield api.restore_card_history(plan.project_id, plan.card_id, plan.oid);
            var current_project = scope.current_project();
            var current_card = scope.current_card();
            if (current_project == null || current_card == null ||
                ((!) current_project).project_id != plan.project_id ||
                ((!) current_card).card_id != plan.card_id) {
                return new HistoryRestoreResult(
                    HistoryRestoreOutcome.SELECTION_CHANGED,
                    plan.project_id, plan.card_id, null, null, false
                );
            }
            return new HistoryRestoreResult(
                HistoryRestoreOutcome.RESTORED, plan.project_id, plan.card_id, null,
                "History restored %s".printf(HistoryPresenter.short_oid(plan.oid)), false
            );
        } catch (Error e) {
            return new HistoryRestoreResult(
                HistoryRestoreOutcome.FAILED, plan.project_id, plan.card_id, e.message,
                "History restore failed: %s".printf(e.message),
                HistoryPresenter.can_restore(detail_entry, captured_head_oid)
            );
        }
    }

    // ---- older pages ----

    public HistoryOlderPlan? plan_load_older(IHistoryScope scope, bool has_api) {
        var project = scope.current_project();
        var card = scope.current_card();
        var cursor = next_cursor;
        if (!has_api || project == null || card == null || cursor == null) return null;
        return new HistoryOlderPlan(
            ((!) project).project_id, ((!) card).card_id, (!) cursor, refresh_serial
        );
    }

    public async HistoryOlderResult load_older(IHistoryApi api,
                                               IHistoryScope scope,
                                               HistoryOlderPlan plan) {
        try {
            var page = yield api.list_card_history(
                plan.project_id, plan.card_id, PAGE_SIZE, plan.cursor
            );
            var current_project = scope.current_project();
            var current_card = scope.current_card();
            if (plan.serial != refresh_serial || current_project == null || current_card == null ||
                ((!) current_project).project_id != plan.project_id ||
                ((!) current_card).card_id != plan.card_id) {
                return new HistoryOlderResult(
                    HistoryOlderOutcome.DROPPED, null, null, null, plan.serial == refresh_serial
                );
            }
            next_cursor = page.next_cursor;
            scan_limited = page.scan_limited;
            return new HistoryOlderResult(
                HistoryOlderOutcome.APPENDED, page, null,
                HistoryPresenter.older_loaded_debug(page), true
            );
        } catch (Error e) {
            if (plan.serial != refresh_serial) {
                return new HistoryOlderResult(HistoryOlderOutcome.DROPPED, null, null, null, false);
            }
            return new HistoryOlderResult(
                HistoryOlderOutcome.FAILED, null, e.message,
                "History older-page load failed: %s".printf(e.message), true
            );
        }
    }

    public string? plan_load_older_project(bool has_api, Project? project) {
        if (!has_api || project == null) return null;
        return project_next_cursor;
    }

    public async ProjectHistoryOlderResult load_older_project(IProjectHistoryApi api,
                                                              string project_id,
                                                              string cursor,
                                                              string? kind) {
        try {
            var page = yield api.list_project_history(project_id, PAGE_SIZE, cursor, kind);
            project_next_cursor = page.next_cursor;
            return new ProjectHistoryOlderResult(page, null);
        } catch (Error e) {
            return new ProjectHistoryOlderResult(null, e.message);
        }
    }
}

}
