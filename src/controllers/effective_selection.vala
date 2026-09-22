namespace HolderLinux {

// The selection the sidebar should display: the committed snapshot, overridden by the
// pending selection while a navigation transition is in flight.
public class EffectiveSelection : Object {
    public string? project_id { get; construct; }
    public string? card_id { get; construct; }
    public string? ai_thread_id { get; construct; }

    public EffectiveSelection(string? project_id, string? card_id, string? ai_thread_id) {
        Object(project_id: project_id, card_id: card_id, ai_thread_id: ai_thread_id);
    }

    public static EffectiveSelection resolve(AppSelectionSnapshot snapshot,
                                             AppTransitionSnapshot transition,
                                             string? live_project_id) {
        string? effective_project_id = snapshot.project_id;
        string? effective_card_id = snapshot.card_id;
        string? effective_ai_thread_id = snapshot.ai_thread_id;
        if (transition.in_flight) {
            var pending = transition.pending_selection;
            if (pending.project_id != null) {
                effective_project_id = pending.project_id;
            } else if (live_project_id != null) {
                effective_project_id = live_project_id;
            }
            if (pending.project_id != null || pending.card_id != null) {
                effective_card_id = pending.card_id;
            }
            if (pending.ai_thread_id != null || pending.project_id != null) {
                effective_ai_thread_id = pending.ai_thread_id;
            }
        }
        return new EffectiveSelection(
            effective_project_id, effective_card_id, effective_ai_thread_id
        );
    }
}

}
